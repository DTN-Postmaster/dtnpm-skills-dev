# AGENTS.md — DTN Postmaster (`skills-dev`)

This document governs the work of AI agents and contributors on the `skills-dev` repository.

## Documentation Language

English must be used as the language for all documentation, unless the file is suffixed with `.fr.md` or another language is explicitly requested in the prompt.

## `SKILL.md` Design Rules

1. **Strict Antigravity format**:
   - Each skill lives in `skills/<kebab-case-name>/SKILL.md`.
   - YAML frontmatter is mandatory and must declare:
     - `name`: identical to the directory name (`^[a-z0-9]+(-[a-z0-9]+)*$`).
     - `description`: in the third person, describing **what the skill does** and **when to activate it** (precise keywords: Rust traits, templates, commands, compliance frameworks), not exceeding 1024 characters.
2. **Ground truth (Zero Hallucination)**:
   - Every Rust signature, HTTP route, CLI flag, environment variable, fuzzing target, or file path cited in a skill must come directly from verified source code in the `dtn-postmaster` organization.
   - Never invent non-existent commands, options, or files.
3. **Secure-by-Default**:
   - Development instructions must promote compliance with the EU Cyber Resilience Act (CRA), OWASP ASVS, strict/warn BPSec, zero `.unwrap()` / `.expect()` in production Rust code, gRPC authenticated via UDS + token (`--token-file`), and explicit opt-in with `warn!` logging for any degraded behavior.
4. **CI & Repository Hygiene**:
   - GitHub Actions must be pinned by full SHA-1 (40 characters) with `permissions: contents: read` and `step-security/harden-runner`.
   - No real secrets or keys; only amateur radio test callsigns (`F*TEST`, `N0CALL`) are allowed in examples.

## Mandatory Verification Before Commit

```bash
./scripts/install-hooks.sh
./scripts/validate-skills.sh
```
