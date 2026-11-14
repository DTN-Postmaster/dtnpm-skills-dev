---
name: create-dtnpm-app
description: >-
  Guides creation of a new DTN application service (`dtnpm-app-*`) from `template-dtnpm-app`, implementing `hardy_bpa::services::Service`, strict BPSec verification, CRA-compliant token resolution (`--token-file`), and integration into the `dtnpm` workspace. Use when creating, scaffolding, or wiring a new DTN application service in the `dtn-postmaster` ecosystem.
---

# Créer une application DTN (`dtnpm-app-*`)

Cette compétence encadre l'instanciation d'une nouvelle application ou service DTN autonome dans l'écosystème `dtn-postmaster` en partant de `template-dtnpm-app`.

## Prérequis architecturaux

Une application DTN (`dtnpm-app-*`) suit le patron hybride `lib.rs` + `main.rs` :
- **Bibliothèque réutilisable** (`src/lib.rs`, `src/service.rs`, `src/config.rs`) : expose la logique métier et l'implémentation du trait `hardy_bpa::services::Service` (alias `BpaService`) pour permettre à la fois l'exécution autonome via gRPC/UDS et l'intégration directe (in-process) dans `dtnpm`.
- **Binaire autonome** (`src/main.rs`) : parse les arguments CLI avec `clap`, lit la configuration TOML/YAML et enregistre le service auprès du daemon BPA (`create_remote_bpa` + `BpaRegistration::register_service`).

## Étapes d'instanciation

### 1. Cloner / dupliquer `template-dtnpm-app`

```bash
cp -r ../template-dtnpm-app dtnpm-app-<nom-service>
cd dtnpm-app-<nom-service>
rm -rf .git target
git init -b main
```

### 2. Renommer la crate et le binaire

Mettre à jour `Cargo.toml` :
- `package.name = "dtnpm-app-<nom-service>"`
- `[lib] name = "dtnpm_app_<nom_service>"` (en `snake_case`)
- `[[bin]] name = "<nom-binaire>"` (ex. `dtn-<service>` ou `dtnpm-app-<service>`)
- Conserver les dépendances workspace/locales vers `dtnpm-core`, `hardy-bpa`, `hardy-bpv7`, `clap`, `tokio`, `tracing`.

Mettre à jour les imports dans `src/main.rs` pour pointer vers la nouvelle crate (`use dtnpm_app_<nom_service>::{AppConfig, AppService};`) et ajuster `#[command(name = "...")]`.

### 3. Adapter la configuration (`src/config.rs`)

- Supporter les deux formats TOML et YAML (`cfg.validate()`).
- Vérifier toutes les bornes dans `validate()` :
  - `max_payload_size` strictement borné (rejeter `0` ou des valeurs excessives).
  - Si des chemins de fichiers ou adresses réseau sont acceptés : bloquer par défaut le traversal (`..`) et les IPs privées/loopback sauf opt-in explicite de sécurité.
  - Conserver l'opt-in explicite `allow_unauthenticated: bool` (défaut `false`) avec journalisation `warn!` lorsqu'il est activé.

### 4. Implémenter `BpaService` (`src/service.rs`)

Le struct `AppService` doit implémenter `#[async_trait] impl BpaService for AppService` (`hardy_bpa::services::Service`) :
- `on_register(&self, source: &Eid, sink: Box<dyn ServiceSink>)` : enregistrer le `ServiceSink` dans `OnceCell` (ou état synchronisé sans `unwrap`).
- `on_unregister(&self)` : journaliser le désenregistrement proprement.
- `on_deliver(&self, id, expiry, total_len, stream)` :
  1. Contrôler **avant allocation** que `total_len <= max_size` et retourner `Err(hardy_bpa::services::Error::PayloadTooLarge { size: total_len, max: max_size })` en cas de dépassement.
  2. Lire le flux via `hardy_bpa::stream::buffer_stream(stream, total_len).await?`.
  3. Vérifier la signature BPSec via `dtnpm_core::cli_security::{KeyStore, VerifyPolicy, VerifyResult, verify_bundle}` :
     - Défaut recommandé en démon : `VerifyPolicy::Strict`.
     - Rejeter les bundles `VerifyResult::Invalid(_)` sous `Strict`.
     - Rejeter `VerifyResult::Unsigned` sous `Strict` sauf si `config.allow_unauthenticated` est `true`.
  4. Traiter la charge utile sans jamais appeler `.unwrap()` ni `.expect()`.
- `on_status_notify` : journaliser ou relayer les rapports d'état RFC 9171 selon les besoins métier.

### 5. Respecter le durcissement CLI & CRA (`src/main.rs`)

Conserver les options standards :
- `--socket` / `DTN_HDY_SOCKET` : socket UNIX local recommandé en production.
- `--port` / `HARDY_GRPC_PORT` (défaut `50051`).
- `--token-file` / `DTN_HDY_TOKEN_FILE` : méthode recommandée pour éviter la fuite de jeton dans `/proc/<pid>/cmdline`.
- `--token` / `DTN_HDY_TOKEN` : conservé uniquement avec `warn!` de dépréciation.
- `--keystore`, `--verify-policy` (`strict` par défaut, `warn`, `ignore`), `--allow-unauthenticated`.

### 6. Documenter les ADRs et l'exemple de configuration

- Ajouter ou adapter les fiches dans `adr/` pour toute décision protocolaire ou compromis sécurité (ex. gestion d'opt-in, format de message CBOR/JSON, limites de taille).
- Mettre à jour `examples/` avec un fichier de configuration minimal valide (utilisant uniquement des indicatifs fictifs `F4TEST` / `N0CALL`).

### 7. Intégration optionnelle dans `dtnpm`

Si l'application doit être embarquée ou listée dans `dtnpm` :
- Ajouter la dépendance optionnelle dans `dtnpm/Cargo.toml` sous `[features]` (ou profil dédié `emcom` / `amsat` selon la cible).
- Ne pas exposer le binaire en double si son propre dépôt le distribue déjà.

## Vérification obligatoire

```bash
./scripts/install-hooks.sh
cargo fmt --all -- --check
cargo clippy --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo test --all-targets
./scripts/check-security.sh --strict
```
