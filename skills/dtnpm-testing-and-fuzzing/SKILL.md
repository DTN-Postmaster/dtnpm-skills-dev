---
name: dtnpm-testing-and-fuzzing
description: >-
  Guides execution and authoring of unit tests, integration tests (`TestServerBuilder`, `iam_integration_test`, `bpsec_chat_files_test`), offline feature matrix checks, Playwright E2E UI tests, radio and ESP-NOW over-the-air KISS E2E simulation scripts (`dtnpm/examples/`), and `cargo-fuzz` targets. Use when validating changes, debugging CI, or running fuzzing campaigns.
---

# Testing, E2E Simulations, Playwright, and Fuzzing (`dtnpm`)

This skill brings together verified procedures for testing, coverage, E2E radio simulation, and fuzzing across the `dtn-postmaster` ecosystem.

## 1. Offline Rust Test Suite and Feature Matrix

All unit and integration tests must pass in offline mode (`--offline`).

### Standard Validation of a Rust Repository

```bash
cargo fmt --all -- --check
cargo clippy --offline --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo clippy --offline --workspace --tests -- -W clippy::all
cargo test --offline --all-targets
```

### Cargo Profile Matrix (in `dtnpm/`)

Validate that the following feature combinations compile without regression:
```bash
cargo check --offline --no-default-features --features "amsat"
cargo check --offline --no-default-features --features "node-headless"
cargo check --offline --no-default-features --features "webui-remote"
```

### Critical Integration Tests (in `dtnpm/` and `dtnpm-web-core/`)

- `dtnpm/tests/iam_integration_test.rs`: PBAC, users, sessions, gRPC/UDS.
- `dtnpm/tests/bpsec_chat_files_test.rs`: BPSec signing and verification on chat and files.
- `dtnpm/tests/ham_server_test.rs`: TOML/YAML parity and CLA initialization.
- `dtnpm/tests/bundle_inspector_test.rs`: in-memory and SQLite inspection.
- `dtnpm-web-core/tests/iam_pbac_test.rs`: WebUI HTTP PBAC with `TestServerBuilder`.

## 2. Code Coverage (`cargo-llvm-cov`)

In any repository equipped with `scripts/check-coverage.sh`:
```bash
./scripts/check-coverage.sh --summary-only   # Console summary
./scripts/check-coverage.sh --html           # HTML report under target/llvm-cov/html/index.html
./scripts/check-coverage.sh --lcov           # CI export (do not commit lcov.info)
```

## 3. WebUI E2E Tests with Playwright (`dtnpm-web-core/ui/`)

Playwright specs cover `bundles.spec.ts`, `chat.spec.ts`, `files.spec.ts`, `logs.spec.ts`, `markdown.spec.ts`, `pwa.spec.ts`, `security.spec.ts`, `send-bundle.spec.ts`, `station-overview.spec.ts` on `http://127.0.0.1:8899`.

```bash
cd dtnpm-web-core/ui
pnpm install
pnpm build

# Standard mode (playwright.config.ts)
pnpm test:e2e

# Standalone / desktop mode (playwright.standalone.config.ts)
npx playwright test -c playwright.standalone.config.ts
```

Note: the standalone/desktop server must listen on `http://127.0.0.1:8899` (or `playwright.standalone.config.ts` must be used depending on the defined startup configuration).

## 4. Multi-Node & Amateur Radio E2E Simulations (`dtnpm/examples/`)

Demonstration and end-to-end validation scripts are located in `dtnpm/examples/`:
- **Hardy Duo**: `dtnpm/examples/run_e2e_hardy_duo.sh` / `dtnpm/examples/test_e2e_hardy_duo.py`
- **Direwolf Software Modem (HQFBP / KISS)**: `dtnpm/examples/launch_dual_direwolf.sh`, `dtnpm/examples/test_direwolf_hqfbp.sh`, `dtnpm/examples/test_bidirectional_direwolf.sh`
- **Mercury Modem (ARQ / LTP)**: `dtnpm/examples/launch_dual_mercury.sh`, `dtnpm/examples/test_simplex_mercury_ltp.sh`
- **ESP-NOW Over-the-Air KISS (`esp-pdu-tnc`)**: `dtnpm/examples/stata-esp-ltp.yaml`, `dtnpm/examples/statb-esp-ltp.yaml`, `dtnpm/examples/stata-esp-hqfbp.yaml`, `dtnpm/examples/statb-esp-hqfbp.yaml` targeting TCP KISS ports `18001` / `18011` (no CAT server required; 250-byte ESP-NOW MTU).
- **Application Services**: `dtnpm/examples/test_basket.py`, `dtnpm/examples/test_bib.py`, `dtnpm/examples/test_forward.py`

Notes for running dual-station (`STATA`/`STATB`) KISS tests:
- The BPA binary is `dtnpm/target/debug/dtnpm` (`dtnpm -c <CONFIG>`, replacing legacy `dtn-hdy-ham` references in older scripts).
- Check for port conflicts with any already-running `dtnpm` instance (`3050`/`3051` gRPC, `8081`/`8082` Web) before launching.
- For full over-the-air (`esp-pdu-tnc`, Direwolf, Mercury) channel tuning, sequential startup, and multi-segment verification procedures, see the `dtnpm-ota-kiss-testing` skill.

Run from `dtnpm/` after building the binaries (`cargo build --workspace`).

## 5. Fuzzing Campaigns (`cargo-fuzz`)

The verified fuzz targets in the ecosystem target critical binary decoders and state engines:

- **`dtnpm-cla-hqfbp-kiss`**:
  - `cla_stream` (`fuzz/fuzz_targets/cla_stream.rs`)
- **`dtnpm-cla-ltp-kiss`**:
  - `cla_packet` (`fuzz/fuzz_targets/cla_packet.rs`)
- **`dtnpm-cla-ltp-kiss/ltp`**:
  - `engine_ops` (`ltp/fuzz/fuzz_targets/engine_ops.rs`)
  - `sdnv_kiss` (`ltp/fuzz/fuzz_targets/sdnv_kiss.rs`)
  - `segment_decode` (`ltp/fuzz/fuzz_targets/segment_decode.rs`)

Run a time-bounded campaign (e.g., 10 minutes = `600` seconds per target) with the nightly toolchain:

```bash
# Example in dtnpm-cla-hqfbp-kiss
cargo +nightly fuzz run cla_stream -- -max_total_time=600

# Example in dtnpm-cla-ltp-kiss
cargo +nightly fuzz run cla_packet -- -max_total_time=600

# Example in dtnpm-cla-ltp-kiss/ltp
cd dtnpm-cla-ltp-kiss/ltp
for target in engine_ops sdnv_kiss segment_decode; do
  cargo +nightly fuzz run "$target" -- -max_total_time=600
done
```

Do not leave unwanted `fuzz/corpus/` or `fuzz/artifacts/` directories in the Git tree if `.gitignore` does not exclude them; if a crash is found, extract a minimal regression unit test in `tests/`.
