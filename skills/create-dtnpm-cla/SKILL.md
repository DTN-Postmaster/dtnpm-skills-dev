---
name: create-dtnpm-cla
description: >-
  Guides creation of a Convergence Layer Adapter (`dtnpm-cla-*`) from `template-dtnpm-cla`, implementing `hardy_bpa::cla::Cla`, bounded async `Driver` channels, peer resolution, gRPC/UDS BPA registration (`--token-file`), and opt-in unauthenticated safety switches. Use when creating or extending a transport CLA for radio, UDP, serial, or KISS links.
---

# Creating a Convergence Layer Adapter (`dtnpm-cla-*`)

This skill describes creating a BPv7 Convergence Layer Adapter (CLA) compatible with the Hardy BPA and `dtnpm`, starting from `template-dtnpm-cla`.

## Architecture of a `dtnpm-cla-*` CLA

A CLA lives in its own repository (`dtnpm-cla-<protocol>`) and follows the `lib.rs` + `main.rs` hybrid pattern:
- `src/cla.rs`: implementation of the `hardy_bpa::cla::Cla` trait (`on_register`, `on_unregister`, `forward`) plus control methods (`cla_init`, `register_peer`, `disconnect`, `close`, `peer_resolver`).
- `src/driver.rs`: asynchronous loop managing the physical/network link (UDP, TCP, KISS/TNC, serial, AX.25, ARQ) via bounded `tokio::sync::mpsc` channels.
- `src/config.rs`: TOML/YAML configuration schema with strict parameter validation and explicit opt-ins.
- `src/error.rs`: typed error enum (`thiserror`) without panics.
- `src/main.rs`: standalone daemon connecting to the BPA via `GrpcBpaClient::with_auth` / `BpaClient::as_registration`.

## Instantiation Steps

### 1. Duplicate `template-dtnpm-cla`

```bash
cp -r ../template-dtnpm-cla dtnpm-cla-<protocol>
cd dtnpm-cla-<protocol>
rm -rf .git target
git init -b main
```

Update `Cargo.toml` (`package.name`, `[lib]`, `[[bin]]`) and `src/main.rs`.

### 2. Implement the `Cla` Trait (`src/cla.rs`)

- Keep the core fields: `config: ClaConfig` and `inner: Arc<RwLock<Option<ClaInner>>>` (storing `Arc<dyn Sink>`, `Arc<TaskPool>`, `mpsc::Sender<DriverCommand>`, and `JoinHandle<()>`).
- **`cla_init(&self) -> ClaInit`**: set `address_type`, `lane_count` (`NonZeroU32`), and `max_bundle_size` (`NonZeroU64`).
- **`on_register` / `on_unregister`**: cleanly start / stop the `Driver` task via a bounded command channel.
- **`forward`**:
  - Read the bundle stream in a bounded manner (`buffer_stream(stream, total_len)` with strict check <= `max_frame_size` / `max_bundle_size`).
  - Send to the driver with `tokio::time::timeout` to prevent indefinite blocking of the BPA, then return `ForwardBundleResult`.
- **Reception**: the driver delivers incoming bundles to the BPA via `sink.dispatch(node_id, Some(&cla_addr), &mut bundle_data).await`.

### 3. Network, RF, and Default Authentication Security

Every new CLA must adhere to the ecosystem's safeguards:
- **Bounded channels and buffers**: never use `mpsc::unbounded_channel()`, nor allocate based on a wire-read length without an explicit ceiling (`max_frame_size` / MTU / max segment size).
- **Anti-spoofing / address migration (IP/UDP links)**:
  - Disable dynamic learning or unauthenticated IP migration by default (`allow_ip_migration = false` by default per peer).
  - If an unauthenticated mode exists for development or already-encrypted links (WireGuard/VPN), require an explicit opt-in (e.g., `--allow-unauthenticated-udp` or `--allow-unauthenticated-bps-opt-in`) accompanied by a clearly visible `warn!` log.
- **Amateur radio identification (RF / KISS / AX.25 / ARQ links)**:
  - Require the local callsign (`callsign` / `--require-callsign`) by default; only allow unidentified RF traffic via an explicit opt-in (`--allow-unidentified-rf` pattern used in `dtnpm-cla-hqfbp-kiss` and `dtnpm-cla-mercury-arq`).
- **Session & FSM (ARQ/LTP links)**:
  - Bound the maximum number of active sessions and the lifetime of an orphaned session to prevent memory exhaustion (DoS) attacks.

### 4. gRPC / UDS Authentication to the BPA (`src/main.rs`)

- Support `--socket` / `DTN_HDY_SOCKET` for Unix Domain Socket.
- Support `--token-file` / `DTN_HDY_TOKEN_FILE` with priority over `--token`.
- Document protocol decisions and security trade-offs in `adr/`.

### 5. Recommended Fuzzing

For any CLA parsing binary frames (SDNV, KISS, HDLC, protocol headers), create a `cargo-fuzz` target in `fuzz/fuzz_targets/` feeding arbitrary bytes (`&[u8]`) directly to the decoder to verify the absence of panics, arithmetic overflows, and infinite loops.

### 6. Integration into `dtnpm`

When the CLA is ready to be embedded in the unified binary:
- Add a feature `cla-<protocol> = ["node", "dep:dtnpm-cla-<protocol>"]` in `dtnpm/Cargo.toml`.
- Wire its configuration under `[[clas]]` in `dtnpm`.

## Mandatory Verification

```bash
./scripts/install-hooks.sh
cargo fmt --all -- --check
cargo clippy --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo test --all-targets
./scripts/check-security.sh --strict
```
