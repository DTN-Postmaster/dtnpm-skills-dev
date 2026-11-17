# DTN Postmaster — Developer Skills (`skills-dev`)

Catalog of skills (`SKILL.md`) intended for developers and AI agents working on the **DTN Postmaster (`dtn-postmaster`)** ecosystem: creating extensions (`dtnpm-app-*`, `dtnpm-mod-*`, `dtnpm-cla-*`), security hardening (CRA / OWASP / BPSec / IAM), E2E testing, and fuzzing.

> For operations, radio configuration, and day-to-day CLI utility usage by operators, see the companion repository **`skills`**.

## Included Skills

| Skill | Directory | Role |
| --- | --- | --- |
| `create-dtnpm-app` | `skills/create-dtnpm-app/SKILL.md` | Instantiating a DTN application (`hardy_bpa::services::Service`) from `template-dtnpm-app` and integrating it into `dtnpm` |
| `create-dtnpm-mod` | `skills/create-dtnpm-mod/SKILL.md` | Instantiating a Web UI module (`dtnpm_web_core::WebModule`, Axum API + React/TypeScript + `SecurityBadge`) from `template-dtnpm-mod` |
| `create-dtnpm-cla` | `skills/create-dtnpm-cla/SKILL.md` | Instantiating a Convergence Layer Adapter (`hardy_bpa::cla::Cla`) and bounded async driver from `template-dtnpm-cla` |
| `dtnpm-security-cra-audit` | `skills/dtnpm-security-cra-audit/SKILL.md` | Security audit and compliance with EU Cyber Resilience Act (CRA), OWASP ASVS/Top 10, BPSec (`VerifyPolicy`), IAM (`DTN-HDY-HAM-IAM`), and zero-unwrap Rust |
| `dtnpm-testing-and-fuzzing` | `skills/dtnpm-testing-and-fuzzing/SKILL.md` | Unit/integration tests (`TestServerBuilder`), E2E radio simulations (`dtnpm/examples/`), Playwright, and `cargo-fuzz` campaigns |

## Installation & Discovery

### In an Antigravity Workspace (`.agents/skills.json` or `skills.json`)

This repository provides `skills.json` and `.agents/skills.json` pointing to `skills/`.

1. Clone as a local catalog or reference the path in your project's `skills.json`:
   ```json
   {
     "entries": [
       { "path": "../skills-dev/skills" }
     ]
   }
   ```
2. Or copy / symlink a given skill into `~/.gemini/antigravity/skills/` or `.agents/skills/` in your target repository.

## Local Validation & CI

Install the Git `pre-commit` hook then run the validator:

```bash
./scripts/install-hooks.sh
./scripts/validate-skills.sh
```

GitHub CI (`.github/workflows/ci.yml`) exclusively uses actions pinned by full SHA-1 and `step-security/harden-runner` with `permissions: contents: read`.

## License

See [LICENSE.md](LICENSE.md).
