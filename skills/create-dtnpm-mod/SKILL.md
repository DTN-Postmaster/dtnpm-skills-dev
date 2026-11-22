---
name: create-dtnpm-mod
description: >-
  Guides creation of a fullstack WebUI module (`dtnpm-mod-*`) from `template-dtnpm-mod`, implementing `dtnpm_web_core::WebModule`, Axum API routes under `/api/<id>/v1`, SQLite migrations, strict BPSec service handling, and Preact UI with anti-XSS Markdown and `SecurityBadge`. Use when adding a new web module or dashboard feature to DTN Postmaster.
---

# Creating a DTN WebUI Module (`dtnpm-mod-*`)

This skill guides creating a fullstack module (Rust/Axum backend + BPv7 service + SQLite storage + Preact/TypeScript frontend) designed to integrate into `dtnpm-web-core` and `dtnpm`.

## Target Architecture (`WebModule`)

A `dtnpm-mod-*` module implements the `dtnpm_web_core::WebModule` trait:
- Registering one or more DTN endpoints with the BPA via `ModuleContext`.
- Shared SQLite storage via `ctx.internal_storage.connection().lock()`.
- Exposing Axum REST routes automatically mounted under `/api/<id>/v1/...`.
- Preact/Tailwind frontend UI displaying BPSec authenticity status (`SecurityBadge`) and rendering text in an XSS-immune manner.

## Instantiation Steps

### 1. Duplicate `template-dtnpm-mod`

```bash
cp -r ../template-dtnpm-mod dtnpm-mod-<name>
cd dtnpm-mod-<name>
rm -rf .git target
git init -b main
```

### 2. Update Package Identifiers

- **`Cargo.toml`**: `name = "dtnpm-mod-<name>"`, dependency on `dtnpm-web-core`.
- **`ui/package.json`**: update the `"name"` field.
- **`src/lib.rs`**:
  - Rename `TemplateModule` to `<Name>Module`.
  - Define `fn id(&self) -> &'static str` (short `snake_case` identifier, used in `/api/<id>/v1`).
  - Define `fn name(&self) -> &'static str` and `fn services(&self) -> Vec<String>`.

### 3. Design SQLite Migrations (`migrations/`)

- Add `migrations/0001_initial_schema.sql` with tables prefixed by the module identifier (e.g., `<id>_items`) to avoid any collision in `dtnpm-web-core`'s shared database.
- Embed via `include_str!("../migrations/0001_initial_schema.sql")` in `migrate(&self, conn: &Connection)`.
- Always use parameterized prepared queries (`params![...]`) in `src/routes.rs` and `src/service.rs`.

### 4. Implement Axum Routes (`src/routes.rs`)

- Declare routes in `fn api_routes(&self, ctx: &ModuleContext) -> Router<()>`.
- Enforce PBAC permissions / authentication according to `dtnpm-web-core` conventions: session and authorization checks rely on the `dtnpm-web-core` gateway.
- Validate and bound all JSON inputs / query params (maximum size, allowed characters, bounded `limit` pagination).
- Handle the SQLite `Mutex` without `.unwrap()`: convert lock or SQL errors into `axum::http::StatusCode::INTERNAL_SERVER_ERROR` or a typed business error.

### 5. Implement the DTN Service (`src/service.rs`)

- Register the service in `register_bpa(&self, ctx: &ModuleContext)` via `ctx.service_tracker.register_service_with_type(Service::Dtn("<service>".into()), ..., "<Description>")`.
- Systematically verify the BPSec signature of incoming bundles with `ctx.keystore` and store the trust status (`bpsec_verified`, verified sender) in the database for UI display.
- Enforce size limits (`max_payload_size`) before memory allocation.

### 6. Develop the Secure Preact Frontend (`ui/`)

- Keep the Vite + Preact + Tailwind architecture of `ui/`.
- **100% English UI & Playwright Specs**: All visible text (tab labels, headings, placeholders, buttons, `SecurityBadge` labels/tooltips, `aria-label`s, dialogs, and error banners) and Playwright E2E assertions must be in English. Keep shared components (`SecurityBadge.tsx`, `utils/markdown.ts`) synchronized with `dtnpm-web-core/ui`.
- **Navigation Placement in `dtnpm-web-core`**: Administrative, routing, filtering, security, storage, or diagnostic modules must be wired as sub-tabs under **Station** (`StationSubTab` in `dtnpm-web-core/ui/src/components/ConfigView.tsx`, e.g., `Rego Routing` between `Routing (RIB)` and `BPSec Security`), capability-gated via `enabledModules` (`/api/capabilities`). Do not promote station admin panels to top-level `Navbar.tsx` tabs (reserved for primary operational views such as `Station`, `Chat`, `Files`, `SenML`, `Send Bundle`).
- **Mandatory Anti-XSS**: reuse the hardened utility `ui/src/utils/markdown.ts` (stripping null bytes `\x00`, random nonce generation via `crypto.getRandomValues`, linear regexes against ReDoS, HTML escaping before injection, and strict blocking of `javascript:` / `data:` schemes).
- **Trust indicator**: display `SecurityBadge` to reflect the BPSec signature status of each received message/object.

### 7. Test via `TestServerBuilder` (`tests/`)

Write offline integration tests relying on `dtnpm_web_core::TestServerBuilder`:
- `build()` to start an isolated in-memory or temporary instance.
- `get()`, `post_json()`, `oneshot()` to validate HTTP status codes, PBAC isolation, payload limits, and SQLite storage.

### 8. Wire into `dtnpm` (Cargo Feature)

In `dtnpm/Cargo.toml`:
- Add a feature `mod-<name> = ["web-core", "dep:dtnpm-mod-<name>"]`.
- Register the `<Name>Module::new()` instance in `dtnpm`'s `WebModule` registry when `#[cfg(feature = "mod-<name>")]` is active.

## Mandatory Verification

```bash
./scripts/install-hooks.sh
cargo fmt --all -- --check
cargo clippy --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo test --all-targets
cd ui && pnpm test:e2e
./scripts/check-security.sh --strict
```

When integrating UI changes into `dtnpm-web-core`, also run `cd ../dtnpm-web-core/ui && pnpm build && pnpm test:e2e`.
