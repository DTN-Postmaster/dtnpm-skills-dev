---
name: dtnpm-security-cra-audit
description: >-
  Performs a comprehensive security and EU Cyber Resilience Act (CRA) / OWASP ASVS / BPSec / HAM IAM audit across DTN Postmaster repositories. Use when reviewing Rust, TypeScript, systemd, or CI changes, auditing security defaults, verifying VEX exclusions, or validating zero-unwrap and strict policy requirements.
---

# Audit Sécurité & Conformité CRA / OWASP / BPSec (`dtnpm`)

Cette compétence structure l'audit de sécurité approfondi de tout dépôt de l'écosystème `dtn-postmaster` (core, web-core, CLAs, modules Web, applications et templates).

## Référentiels applicables

1. **EU Cyber Resilience Act (CRA)** :
   - Sécurité par défaut (*Secure by Default*) : services d'écoute sur `127.0.0.1` ou Unix Domain Socket (`0660`), politiques BPSec strictes activées par défaut, pas de secrets ou mots de passe par défaut.
   - Gestion des vulnérabilités et SBOM / VEX : contrôle `cargo-audit`, `cargo-deny` et déclarations VEX explicites (`.cargo/audit.toml`, `deny.toml`, ex. justification `RUSTSEC-2026-0459` si l'extension SQLite session est inutilisée).
   - Surface d'exposition minimale : actions CI épinglées par SHA-1 à 40 caractères, `permissions: contents: read`, `step-security/harden-runner`.
2. **OWASP Top 10 & ASVS** :
   - **A01 Broken Access Control** : PBAC vérifié sur chaque route Axum de `dtnpm-web-core` et `dtnpm-mod-*`, blocage de path traversal dans les services manipulant des fichiers (`dtnfiles`, `dtnbasket`), blocage des IPs privées (SSRF) sauf opt-in (`allow_private_ips`), blocage par défaut du *third-party reply-to/report-to* (`allow_third_party_reply_to`, `--allow-third-party-report-to`).
   - **A02 Cryptographic Failures** : pas de secrets dans `cmdline` (`--token-file` et `--password-stdin` privilégiés), pas de comparaison naïve sur secrets, permissions `0600` sur clés/configs.
   - **A03 Injection** : requêtes SQLite 100 % paramétrées, aucune invocation de shell dans `dtntrigger` (passage par `Command::new` avec arguments vectorisés), liste blanche et refus de tirets initiaux (`-`) sur noms d'unités dans `hdy-stats`, assainissement Markdown anti-XSS et anti-ReDoS dans `ui/src/utils/markdown.ts`.
   - **A04 Insecure Design / DoS** : contrôle préalable de `total_len` avant `buffer_stream`, canaux `mpsc` bornés, timeouts sur I/O async et gRPC, bornes strictes sur `--limit`, décodeurs BPv7/LTP/SDNV/HQFBP protégés contre les allocations géantes.
3. **BPSec (RFC 9172) & IAM (`DTN-HDY-HAM-IAM`)** :
   - Vérification `VerifyPolicy::{Strict, Warn, Ignore}` testée.
   - Toute dérogation dangereuse (ex. `--allow-unauthenticated`, `--allow-unauthenticated-udp`, `--allow-unidentified-rf`, `allow_ip_migration`) doit être **désactivée par défaut**, nécessiter un opt-in explicite, journaliser un `warn!`, et être documentée dans un ADR (`adr/`).

## Liste de contrôle d'audit pas à pas

### 1. Chasse aux panics et comportements indéfinis (Rust)

Rechercher dans le code de production (`src/`, hors `#[cfg(test)]` et `tests/`) :
```bash
rg -n '\.(unwrap|expect)\(|panic!\(|todo!\(|unimplemented!\(|unsafe\s*\{' src/
```
Tout `.unwrap()` ou `.expect()` en code de production doit être remplacé par une propagation typée (`?`, `map_err`, `ok_or_else`) ou vérifié via `clippy::unwrap_used` et `clippy::panic`.

### 2. Audit des frontières d'entrée et bornes mémoires

Inspecter systématiquement :
- Tous les parseurs de trames/paquets (`slice` indexation directe vs `.get()`, opérations arithmétiques `checked_add` / `saturating_*`).
- Tous les appels HTTP / gRPC / WebSockets : tailles maximales de corps, timeouts, limites de requêtes SQL.
- Le rendu frontend : absence de `dangerouslySetInnerHTML` hors `renderMarkdown` durci, présence de `SecurityBadge`.

### 3. Vérification des opt-ins dangereux et secrets

- Vérifier que `--token` et `--password` inline affichent un avertissement et que `--token-file` / `--password-stdin` fonctionnent.
- Inspecter `examples/`, `config.example.toml`, `adr/` et `.gitleaks.toml` pour garantir l'absence de vrais jetons, clés privées ou mots de passe en clair.

### 4. Exécution automatisée de l'outillage sécurité

```bash
./scripts/check-security.sh --strict
```
Ou manuellement si besoin hors-ligne :
```bash
cargo fmt --all -- --check
cargo clippy --offline --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo audit --no-fetch
cargo deny --offline check
```
Si `ui/package.json` existe :
```bash
(cd ui && pnpm audit --audit-level=high)
```

### 5. Validation CI/CD & Systemd

- Vérifier que tous les workflows `.github/workflows/*.yml` épinglent leurs `uses:` sur un SHA-1 de 40 caractères hexadécimaux et activent `step-security/harden-runner`.
- Vérifier que les unités systemd (`dtnpm.service`) conservent `User=dtnpm`, `ProtectSystem=strict`, `ProtectHome=true`, `NoNewPrivileges=true`.

## Livrable d'audit attendu

Pour chaque constat, relever :
- Sévérité (`Critique`, `Haute`, `Moyenne`, `Basse`, `Info`) et référence (CRA / OWASP / RFC 9172).
- Fichier et lignes exactes observées.
- Correction concrète respectant les garde-fous et ADRs associés.
