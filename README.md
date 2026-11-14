# DTN Postmaster — Developer Skills (`skills-dev`)

Catalogue de compétences (`SKILL.md`) destiné aux développeurs et aux agents IA travaillant sur l'écosystème **DTN Postmaster (`dtn-postmaster`)** : création d'extensions (`dtnpm-app-*`, `dtnpm-mod-*`, `dtnpm-cla-*`), durcissement sécurité (CRA / OWASP / BPSec / IAM), tests E2E et fuzzing.

> Pour l'exploitation, la configuration radio et l'usage quotidien des utilitaires CLI par les opérateurs, consultez le dépôt compagnon **`skills`**.

## Skills inclus

| Skill | Dossier | Rôle |
| --- | --- | --- |
| `create-dtnpm-app` | `skills/create-dtnpm-app/SKILL.md` | Instanciation d'une application DTN (`hardy_bpa::services::Service`) à partir de `template-dtnpm-app` et intégration dans `dtnpm` |
| `create-dtnpm-mod` | `skills/create-dtnpm-mod/SKILL.md` | Instanciation d'un module Web UI (`dtnpm_web_core::WebModule`, API Axum + React/TypeScript + `SecurityBadge`) depuis `template-dtnpm-mod` |
| `create-dtnpm-cla` | `skills/create-dtnpm-cla/SKILL.md` | Instanciation d'un Convergence Layer Adapter (`hardy_bpa::cla::Cla`) et driver async borné depuis `template-dtnpm-cla` |
| `dtnpm-security-cra-audit` | `skills/dtnpm-security-cra-audit/SKILL.md` | Audit sécurité et conformité EU Cyber Resilience Act (CRA), OWASP ASVS/Top 10, BPSec (`VerifyPolicy`), IAM (`DTN-HDY-HAM-IAM`) et zéro-unwrap Rust |
| `dtnpm-testing-and-fuzzing` | `skills/dtnpm-testing-and-fuzzing/SKILL.md` | Tests unitaires/intégration (`TestServerBuilder`), simulations radio E2E (`dtnpm/examples/`), Playwright et campagnes `cargo-fuzz` |

## Installation & découverte

### Dans un espace Antigravity (`.agents/skills.json` ou `skills.json`)

Ce dépôt fournit `skills.json` et `.agents/skills.json` pointant sur `skills/`.

1. Cloner en tant que catalogue local ou référencer le chemin dans le `skills.json` de votre projet :
   ```json
   {
     "entries": [
       { "path": "../skills-dev/skills" }
     ]
   }
   ```
2. Ou copier / lier symboliquement une skill donnée dans `~/.gemini/antigravity/skills/` ou `.agents/skills/` de votre dépôt cible.

## Validation locale & CI

Installer le hook Git `pre-commit` puis exécuter le validateur :

```bash
./scripts/install-hooks.sh
./scripts/validate-skills.sh
```

La CI GitHub (`.github/workflows/ci.yml`) utilise exclusivement des actions épinglées par SHA-1 complet et `step-security/harden-runner` avec `permissions: contents: read`.

## Licence

Voir [LICENSE.md](LICENSE.md).
