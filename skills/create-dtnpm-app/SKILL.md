---
name: create-dtnpm-app
description: >-
  Guides creation of a new DTN application service (`dtnpm-app-*`) from `template-dtnpm-app`, implementing `hardy_bpa::services::Service`, strict BPSec verification, CRA-compliant token resolution (`--token-file`), and integration into the `dtnpm` workspace. Use when creating, scaffolding, or wiring a new DTN application service in the `dtn-postmaster` ecosystem.
---

# Creating a DTN Application (`dtnpm-app-*`)

This skill guides instantiating a new standalone DTN application or service in the `dtn-postmaster` ecosystem starting from `template-dtnpm-app`.

## Architectural Prerequisites

A DTN application (`dtnpm-app-*`) follows the `lib.rs` + `main.rs` hybrid pattern:
- **Reusable library** (`src/lib.rs`, `src/service.rs`, `src/config.rs`): exposes business logic and the `hardy_bpa::services::Service` trait implementation (aliased as `BpaService`) to support both standalone execution over gRPC/UDS and direct in-process integration inside `dtnpm`.
- **Standalone binary** (`src/main.rs`): parses CLI arguments with `clap`, reads the TOML/YAML configuration, and registers the service with the BPA daemon (`create_remote_bpa` + `BpaRegistration::register_service`).

## Instantiation Steps

### 1. Clone / Duplicate `template-dtnpm-app`

```bash
cp -r ../template-dtnpm-app dtnpm-app-<service-name>
cd dtnpm-app-<service-name>
rm -rf .git target
git init -b main
```

### 2. Rename the Crate and Binary

Update `Cargo.toml`:
- `package.name = "dtnpm-app-<service-name>"`
- `[lib] name = "dtnpm_app_<service_name>"` (in `snake_case`)
- `[[bin]] name = "<binary-name>"` (e.g., `dtn-<service>` or `dtnpm-app-<service>`)
- Keep workspace/local dependencies on `dtnpm-core`, `hardy-bpa`, `hardy-bpv7`, `clap`, `tokio`, `tracing`.

Update imports in `src/main.rs` to point to the new crate (`use dtnpm_app_<service_name>::{AppConfig, AppService};`) and adjust `#[command(name = "...")]`.

### 3. Adapt the Configuration (`src/config.rs`)

- Support both TOML and YAML formats (`cfg.validate()`).
- Check all bounds in `validate()`:
  - `max_payload_size` strictly bounded (reject `0` or excessive values).
  - If file paths or network addresses are accepted: block path traversal (`..`) and private/loopback IPs by default unless an explicit security opt-in is enabled.
  - Keep the explicit opt-in `allow_unauthenticated: bool` (default `false`) with `warn!` logging when enabled.

### 4. Implement `BpaService` (`src/service.rs`)

The `AppService` struct must implement `#[async_trait] impl BpaService for AppService` (`hardy_bpa::services::Service`):
- `on_register(&self, source: &Eid, sink: Box<dyn ServiceSink>)`: store `ServiceSink` in `OnceCell` (or synchronized state without `unwrap`).
- `on_unregister(&self)`: log unregistration cleanly.
- `on_deliver(&self, id, expiry, total_len, stream)`:
  1. Check **before allocation** that `total_len <= max_size` and return `Err(hardy_bpa::services::Error::PayloadTooLarge { size: total_len, max: max_size })` if exceeded.
  2. Read the stream via `hardy_bpa::stream::buffer_stream(stream, total_len).await?`.
  3. Verify the BPSec signature via `dtnpm_core::cli_security::{KeyStore, VerifyPolicy, VerifyResult, verify_bundle}`:
     - Recommended daemon default: `VerifyPolicy::Strict`.
     - Reject `VerifyResult::Invalid(_)` bundles under `Strict`.
     - Reject `VerifyResult::Unsigned` under `Strict` unless `config.allow_unauthenticated` is `true`.
  4. Process the payload without ever calling `.unwrap()` or `.expect()`.
- `on_status_notify`: log or relay RFC 9171 status reports according to business needs.

### 5. Enforce CLI & CRA Hardening (`src/main.rs`)

Keep the standard options:
- `--socket` / `DTN_HDY_SOCKET`: local UNIX socket recommended in production.
- `--port` / `HARDY_GRPC_PORT` (default `50051`).
- `--token-file` / `DTN_HDY_TOKEN_FILE`: recommended method to avoid token leakage in `/proc/<pid>/cmdline`.
- `--token` / `DTN_HDY_TOKEN`: retained only with a deprecation `warn!`.
- `--keystore`, `--verify-policy` (`strict` by default, `warn`, `ignore`), `--allow-unauthenticated`.

### 6. Document ADRs and Example Configuration

- Add or adapt records in `adr/` for any protocol decision or security trade-off (e.g., opt-in handling, CBOR/JSON message format, size limits).
- Update `examples/` with a minimal valid configuration file (using only fictitious callsigns `F4TEST` / `N0CALL`).

### 7. Optional Integration into `dtnpm`

If the application is to be embedded or listed in `dtnpm`:
- Add the optional dependency in `dtnpm/Cargo.toml` under `[features]` (or a dedicated `emcom` / `amsat` profile depending on the target).
- Do not expose duplicate binaries if its own repository already distributes it.

## Mandatory Verification

```bash
./scripts/install-hooks.sh
cargo fmt --all -- --check
cargo clippy --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo test --all-targets
./scripts/check-security.sh --strict
```
