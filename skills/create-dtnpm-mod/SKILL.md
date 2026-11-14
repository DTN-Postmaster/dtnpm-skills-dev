---
name: create-dtnpm-mod
description: >-
  Guides creation of a fullstack WebUI module (`dtnpm-mod-*`) from `template-dtnpm-mod`, implementing `dtnpm_web_core::WebModule`, Axum API routes under `/api/<id>/v1`, SQLite migrations, strict BPSec service handling, and Preact UI with anti-XSS Markdown and `SecurityBadge`. Use when adding a new web module or dashboard feature to DTN Postmaster.
---

# Créer un module WebUI DTN (`dtnpm-mod-*`)

Cette compétence guide la création d'un module fullstack (backend Rust/Axum + service BPv7 + stockage SQLite + frontend Preact/TypeScript) destiné à s'intégrer dans `dtnpm-web-core` et `dtnpm`.

## Architecture cible (`WebModule`)

Un module `dtnpm-mod-*` implémente le trait `dtnpm_web_core::WebModule` :
- Enregistrement d'un ou plusieurs endpoints DTN auprès du BPA via `ModuleContext`.
- Stockage partagé SQLite via `ctx.internal_storage.connection().lock()`.
- Exposition de routes REST Axum montées automatiquement sous `/api/<id>/v1/...`.
- Interface frontend Preact/Tailwind affichant l'état d'authenticité BPSec (`SecurityBadge`) et rendant le texte de façon immunisée contre le XSS.

## Étapes d'instanciation

### 1. Dupliquer `template-dtnpm-mod`

```bash
cp -r ../template-dtnpm-mod dtnpm-mod-<nom>
cd dtnpm-mod-<nom>
rm -rf .git target
git init -b main
```

### 2. Mettre à jour les identifiants du paquet

- **`Cargo.toml`** : `name = "dtnpm-mod-<nom>"`, dépendance vers `dtnpm-web-core`.
- **`ui/package.json`** : adapter le champ `"name"`.
- **`src/lib.rs`** :
  - Renommer `TemplateModule` en `<Nom>Module`.
  - Définir `fn id(&self) -> &'static str` (identifiant court `snake_case`, utilisé dans `/api/<id>/v1`).
  - Définir `fn name(&self) -> &'static str` et `fn services(&self) -> Vec<String>`.

### 3. Concevoir les migrations SQLite (`migrations/`)

- Ajouter `migrations/0001_initial_schema.sql` avec tables préfixées par l'identifiant du module (ex. `<id>_items`) pour éviter toute collision dans la base partagée de `dtnpm-web-core`.
- Intégrer via `include_str!("../migrations/0001_initial_schema.sql")` dans `migrate(&self, conn: &Connection)`.
- Toujours utiliser des requêtes préparées paramétrées (`params![...]`) dans `src/routes.rs` et `src/service.rs`.

### 4. Implémenter les routes Axum (`src/routes.rs`)

- Déclarer les routes dans `fn api_routes(&self, ctx: &ModuleContext) -> Router<()>`.
- Contrôler les permissions PBAC / authentification selon les conventions `dtnpm-web-core` : les vérifications de session et d'autorisation s'appuient sur la passerelle de `dtnpm-web-core`.
- Valider et borner toutes les entrées JSON / query params (taille maximale, caractères autorisés, pagination `limit` bornée).
- Manipuler le `Mutex` SQLite sans `.unwrap()` : convertir les erreurs de verrouillage ou SQL en `axum::http::StatusCode::INTERNAL_SERVER_ERROR` ou erreur métier typée.

### 5. Implémenter le service DTN (`src/service.rs`)

- Enregistrer le service dans `register_bpa(&self, ctx: &ModuleContext)` via `ctx.service_tracker.register_service_with_type(Service::Dtn("<service>".into()), ..., "<Description>")`.
- Vérifier systématiquement la signature BPSec des bundles entrants avec `ctx.keystore` et stocker l'état de confiance (`bpsec_verified`, émetteur vérifié) en base pour affichage UI.
- Appliquer les limites de taille (`max_payload_size`) avant allocation mémoire.

### 6. Développer le frontend Preact sécurisé (`ui/`)

- Conserver l'architecture Vite + Preact + Tailwind de `ui/`.
- **Anti-XSS obligatoire** : réutiliser l'utilitaire durci `ui/src/utils/markdown.ts` (suppression des octets nuls `\x00`, génération de nonce aléatoire via `crypto.getRandomValues`, expressions régulières linéaires contre ReDoS, échappement HTML avant injection et blocage strict des schémas `javascript:` / `data:`).
- **Indicateur de confiance** : afficher `SecurityBadge` pour refléter l'état de signature BPSec de chaque message/objet reçu.

### 7. Tester via `TestServerBuilder` (`tests/`)

Écrire des tests d'intégration hors-ligne s'appuyant sur `dtnpm_web_core::TestServerBuilder` :
- `build()` pour démarrer une instance en mémoire ou temporaire isolée.
- `get()`, `post_json()`, `oneshot()` pour valider les codes HTTP, l'isolation PBAC, les limites de charge utile et le stockage SQLite.

### 8. Câbler dans `dtnpm` (feature Cargo)

Dans `dtnpm/Cargo.toml` :
- Ajouter une feature `mod-<nom> = ["web-core", "dep:dtnpm-mod-<nom>"]`.
- Enregistrer l'instance de `<Nom>Module::new()` dans le registre des `WebModule` de `dtnpm` lorsque `#[cfg(feature = "mod-<nom>")]` est actif.

## Vérification obligatoire

```bash
./scripts/install-hooks.sh
cargo fmt --all -- --check
cargo clippy --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo test --all-targets
./scripts/check-security.sh --strict
```
