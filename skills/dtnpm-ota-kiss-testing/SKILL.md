---
name: dtnpm-ota-kiss-testing
description: >-
  Covers running dual-station (`STATA`/`STATB`) over-the-air KISS TCP tests with `dtnpm` for LTP and HQFBP CLAs over `esp-pdu-tnc` (ESP-NOW 250-byte MTU, ports `18001`/`18011`), Direwolf, and Mercury, including link-layer MTU sizing, channel-matched FEC pipelines, sequential BPA startup to avoid RF collisions, incompressible multi-segment verification, and log diagnostics. Use when validating LTP or HQFBP CLAs over real or simulated KISS TNCs.
---

# Over-the-Air KISS Testing (`STATA` / `STATB` Dual-Launch)

This skill documents verified procedures for testing `dtnpm` Convergence Layer Adapters (`ltp` and `hqfbp`) over real RF or simulated KISS TCP TNCs, with emphasis on ESP-NOW links via `esp-pdu-tnc`.

## 1. Pre-Flight Checks

Before starting `STATA` and `STATB`:

1. **Verify KISS TCP listeners are up** (e.g., `18001` for `STATA` and `18011` for `STATB` on `esp-pdu-tnc`):
   ```bash
   ss -tlnp | grep -E "18001|18011"
   nc -z 127.0.0.1 18001 && nc -z 127.0.0.1 18011
   ```
   Pure KISS CLA tests do **not** require a CAT (`rigctld`) server.
2. **Check for port conflicts with existing `dtnpm` instances**:
   ```bash
   ps aux | grep dtnpm
   ss -tlnp | grep -E "3050|3051|8081|8082"
   ```
   Ensure gRPC (`3050`/`3051`) and Web API (`8081`/`8082`) ports are free before starting the test pair.
3. **Use the `dtnpm` binary and CLI flags**:
   The current binary is `dtnpm/target/debug/dtnpm` (replacing legacy `dtn-hdy-ham` references in older scripts) and takes `-c <FILE>` (or `--config <FILE>`).

## 2. Channel Model, MTU & Encoding Selection

### ESP-NOW (`esp-pdu-tnc`, 802.11b DSSS 1 Mbps)
- **Channel characteristics**: Built-in 7-bit scrambler and hardware 4-byte IEEE 802.11 CRC-32 FCS, turning the link into a **250-byte packet-erasure channel** (`MAX_ESPNOW_PDU_LEN = 250` bytes; oversized frames are silently dropped by `esp-pdu-tnc`) fed over a 115200-baud (~11.5 KB/s) USB UART.
- **LTP (`dtnpm-cla-ltp-kiss`)**:
  - `dtnpm-cla-ltp-kiss/src/config.rs` defaults `max-segment-payload-len` to `1400` bytes (`default_mtu()`). Over ESP-NOW, small bundles fit, but multi-segment bundles exceed 250 bytes and fail silently.
  - Set `max-segment-payload-len: 200` (leaving headroom for LTP headers inside the 250-byte PDU), with `half-duplex: true`, `turnaround-mode: "wait-for-report"`, `turnaround-timeout: "3s"`, `min-frame-len: 15`, `rate-limit-bytes-per-sec: 1200`, `burst-capacity-bytes: 1024`.
  - Verified example configs: `dtnpm/examples/stata-esp-ltp.yaml` and `dtnpm/examples/statb-esp-ltp.yaml`.
- **HQFBP (`dtnpm-cla-hqfbp-kiss`)**:
  - **Do not** reuse Direwolf's `rs(255, 233)` pipeline over ESP-NOW: `255 > 250` bytes exceeds the MTU, and intra-frame RS is ineffective when 802.11 hardware FCS already drops corrupted MPDUs.
  - Use `hailing-encodings: "h"` and `default-bundle-encodings: "gzip, crc32, rq(dlen, 140, 2), h"`: `140`-byte RaptorQ symbols + 4-byte `PayloadId` + ~65–80 B CBOR header stay under 250 bytes while providing 2 erasure-repair symbols per bundle, with self-describing symbols (no post-`h` FEC).
  - Pace UART writes with `rate-limit-bytes-per-sec: 4000` and `burst-capacity-bytes: 512`.
  - Verified example configs: `dtnpm/examples/stata-esp-hqfbp.yaml` and `dtnpm/examples/statb-esp-hqfbp.yaml`.

### Direwolf & Mercury Reference Limits
- **Direwolf (`9600` baud G3RUH / AFSK)**: bit-error channel — use `gzip, chunk(150), crc32, h, rs(255, 233)` for HQFBP (`stata-dw-hqfbp.yaml` / `statb-dw-hqfbp.yaml`), or `min-frame-len: 15` + half-duplex turnaround for LTP (`stata-dw-ltp.yaml` / `statb-dw-ltp.yaml`).
- **Mercury HF (`8100`/`8500`)**: narrowband — set `max-segment-payload-len: 80` for LTP (`stata-ltp.yaml` / `statb-ltp.yaml`).

## 3. Sequential Dual-Station Launch & Collision Avoidance

Over real half-duplex RF channels (e.g., ESP-NOW), connect and transmit sequentially to avoid on-air collisions:

1. Clean `/tmp/dtn-stata` and `/tmp/dtn-statb`, and install an `EXIT INT TERM` trap to terminate both `dtnpm` PIDs.
2. Start **STATA first**, wait until `http://127.0.0.1:8081/api/v1/config` responds, then `sleep 1`.
3. Start **STATB second**, wait until `http://127.0.0.1:8082/api/v1/config` responds, then `sleep 1`.
4. Pause (`sleep 1`) between each test transfer so trailing RaptorQ repair symbols or LTP report ACKs finish draining before the reverse direction transmits.

## 4. Required Verification Matrix

Run all four checks sequentially via the Web API (`/api/v1/bundles`):

1. **STATA → STATB (small chat bundle, ~60–70 B)**:
   `POST http://127.0.0.1:8081/api/v1/bundles` with `{"destination": "dtn://statb.ampr.org/chat", "payload": "..."}` → verify delivery under `/tmp/dtn-statb/`.
2. **STATB → STATA (small chat bundle, ~60–70 B)**:
   `POST http://127.0.0.1:8082/api/v1/bundles` with `{"destination": "dtn://stata.ampr.org/chat", "payload": "..."}` → verify delivery under `/tmp/dtn-stata/`.
3. **STATA → STATB (multi-segment / multi-symbol ~1500 B incompressible payload)**:
   Generate pseudo-random incompressible ASCII (`python3` `random.Random(seed)` with distinct start and end markers) to force multiple LTP segments / RaptorQ source symbols.
4. **STATB → STATA (multi-segment / multi-symbol ~1500 B incompressible payload)**:
   Repeat with an incompressible payload in the reverse direction.

> **Pitfall**: Never use repetitive payloads like `'A'*1500` to test HQFBP multi-symbol fragmentation — `gzip` compresses them to ~20 bytes (a single symbol) and hides MTU overflows.

## 5. Log Diagnostics

- **LTP** (launch with `dtnpm -v -c ...`):
  - Healthy session: `Half-duplex: Checkpoint emitted, pausing transmission queue` → `Report Segment received, unpausing transmission queue immediately` → `transmission session ... completed` → `forwarded` / `delivered`.
  - Repeated `Half-duplex: pacer turnaround deadline elapsed, unpausing` without a `Report Segment received` indicates either an oversized segment (`max-segment-payload-len` exceeding link MTU) or RF frame loss.
- **HQFBP** (launch with `RUST_LOG=info,dtnpm_cla_hqfbp_kiss=debug,dtnpm_mod_chat=debug dtnpm -c ...`):
  - Healthy session: `Buffering bundle ... for HQFBP broadcast` on sender, followed by `Reassembled HQFBP bundle (...) from sender` and `Stored new inbound chat message` on receiver.
