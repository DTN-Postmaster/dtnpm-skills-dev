---
name: dtnpm-security-cra-audit
description: >-
  Performs a comprehensive security and EU Cyber Resilience Act (CRA) / OWASP ASVS / BPSec / HAM IAM audit across DTN Postmaster repositories. Use when reviewing Rust, TypeScript, systemd, or CI changes, auditing security defaults, verifying VEX exclusions, or validating zero-unwrap and strict policy requirements.
---

# Security Audit & CRA / OWASP / BPSec Compliance (`dtnpm`)

This skill structures an in-depth security audit of any repository in the `dtn-postmaster` ecosystem (core, web-core, CLAs, Web modules, applications, and templates).

## Applicable Standards

1. **EU Cyber Resilience Act (CRA)**:
   - *Secure by Default*: listening services on `127.0.0.1` or Unix Domain Socket (`0660`), strict BPSec policies enabled by default, no default secrets or passwords.
   - Vulnerability management and SBOM / VEX: `cargo-audit`, `cargo-deny`, and explicit VEX declarations (`.cargo/audit.toml`, `deny.toml`, e.g., `RUSTSEC-2026-0459` justification when the SQLite session extension is unused).
   - Minimal attack surface: CI actions pinned by 40-character SHA-1, `permissions: contents: read`, `step-security/harden-runner`.
2. **OWASP Top 10 & ASVS**:
   - **A01 Broken Access Control**: PBAC verified on every Axum route in `dtnpm-web-core` and `dtnpm-mod-*`, path traversal blocking in file-handling services (`dtnfiles`, `dtnbasket`), private IP blocking (SSRF) unless opted in (`allow_private_ips`), blocking *third-party reply-to/report-to* by default (`allow_third_party_reply_to`, `--allow-third-party-report-to`).
   - **A02 Cryptographic Failures**: no secrets in `cmdline` (`--token-file` and `--password-stdin` preferred), no naive comparison on secrets, `0600` permissions on keys/configs.
   - **A03 Injection**: 100% parameterized SQLite queries, no shell invocation in `dtntrigger` (using `Command::new` with vectorized arguments), allowlist and rejection of leading dashes (`-`) on unit names in `hdy-stats`, anti-XSS and anti-ReDoS Markdown sanitization in `ui/src/utils/markdown.ts`.
   - **A04 Insecure Design / DoS**: pre-check of `total_len` before `buffer_stream`, bounded `mpsc` channels, timeouts on async I/O and gRPC, strict bounds on `--limit`, BPv7/LTP/SDNV/HQFBP decoders protected against giant allocations.
3. **BPSec (RFC 9172) & IAM (`DTN-HDY-HAM-IAM`)**:
   - Tested `VerifyPolicy::{Strict, Warn, Ignore}` verification.
   - Any dangerous exemption (e.g., `--allow-unauthenticated`, `--allow-unauthenticated-udp`, `--allow-unidentified-rf`, `allow_ip_migration`) must be **disabled by default**, require an explicit opt-in, log a `warn!`, and be documented in an ADR (`adr/`).

## Step-by-Step Audit Checklist

### 1. Hunting Panics and Undefined Behavior (Rust)

Search in production code (`src/`, excluding `#[cfg(test)]` and `tests/`):
```bash
rg -n '\.(unwrap|expect)\(|panic!\(|todo!\(|unimplemented!\(|unsafe\s*\{' src/
```
Every `.unwrap()` or `.expect()` in production code must be replaced with typed error propagation (`?`, `map_err`, `ok_or_else`) or verified via `clippy::unwrap_used` and `clippy::panic`.

### 2. Auditing Input Boundaries and Memory Bounds

Systematically inspect:
- All frame/packet parsers (direct slice indexing vs `.get()`, arithmetic operations `checked_add` / `saturating_*`).
- All HTTP / gRPC / WebSocket calls: maximum body sizes, timeouts, SQL query limits.
- Frontend rendering: no `dangerouslySetInnerHTML` outside hardened `renderMarkdown`, presence of `SecurityBadge`.

### 3. Checking Dangerous Opt-Ins and Secrets

- Verify that inline `--token` and `--password` emit a warning and that `--token-file` / `--password-stdin` work.
- Inspect `examples/`, `config.example.toml`, `adr/`, and `.gitleaks.toml` to ensure no real tokens, private keys, or cleartext passwords exist.

### 4. Automated Security Tooling Execution

```bash
./scripts/check-security.sh --strict
```
Or manually if needed offline:
```bash
cargo fmt --all -- --check
cargo clippy --offline --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo audit --no-fetch
cargo deny --offline check
```
If `ui/package.json` exists:
```bash
(cd ui && pnpm audit --audit-level=high)
```

### 5. CI/CD & Systemd Validation

- Verify that all `.github/workflows/*.yml` workflows pin their `uses:` to a 40-character hexadecimal SHA-1 and enable `step-security/harden-runner`.
- Verify that systemd units (`dtnpm.service`) retain `User=dtnpm`, `ProtectSystem=strict`, `ProtectHome=true`, `NoNewPrivileges=true`.

## Expected Audit Deliverable

For each finding, record:
- Severity (`Critical`, `High`, `Medium`, `Low`, `Info`) and reference (CRA / OWASP / RFC 9172).
- Exact file and line numbers observed.
- Concrete fix adhering to the safeguards and associated ADRs.
