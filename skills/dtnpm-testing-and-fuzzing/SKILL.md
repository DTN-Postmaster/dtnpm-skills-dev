---
name: dtnpm-testing-and-fuzzing
description: >-
  Guides execution and authoring of unit tests, integration tests (`TestServerBuilder`, `iam_integration_test`, `bpsec_chat_files_test`), offline feature matrix checks, Playwright E2E UI tests, radio E2E simulation scripts (`dtnpm/examples/`), and `cargo-fuzz` targets. Use when validating changes, debugging CI, or running fuzzing campaigns.
---

# Tests, Simulations E2E, Playwright et Fuzzing (`dtnpm`)

Cette compétence rassemble les procédures vérifiées de test, de couverture, de simulation radio E2E et de fuzzing sur l'écosystème `dtn-postmaster`.

## 1. Suite de tests Rust hors-ligne et matrice de profils

Tous les tests unitaires et d'intégration doivent passer en mode hors-ligne (`--offline`).

### Validation standard d'un dépôt Rust

```bash
cargo fmt --all -- --check
cargo clippy --offline --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo clippy --offline --workspace --tests -- -W clippy::all
cargo test --offline --all-targets
```

### Matrice de profils Cargo (dans `dtnpm/`)

Valider que les combinaisons de features suivantes compilent sans régression :
```bash
cargo check --offline --no-default-features --features "amsat"
cargo check --offline --no-default-features --features "node-headless"
cargo check --offline --no-default-features --features "webui-remote"
```

### Tests d'intégration critiques (dans `dtnpm/` et `dtnpm-web-core/`)

- `dtnpm/tests/iam_integration_test.rs` : PBAC, utilisateurs, sessions, gRPC/UDS.
- `dtnpm/tests/bpsec_chat_files_test.rs` : signature et vérification BPSec sur chat et fichiers.
- `dtnpm/tests/ham_server_test.rs` : parité TOML/YAML et initialisation CLAs.
- `dtnpm/tests/bundle_inspector_test.rs` : inspection en mémoire et SQLite.
- `dtnpm-web-core/tests/iam_pbac_test.rs` : PBAC HTTP WebUI avec `TestServerBuilder`.

## 2. Couverture de code (`cargo-llvm-cov`)

Dans chaque dépôt équipé de `scripts/check-coverage.sh` :
```bash
./scripts/check-coverage.sh --summary-only   # Synthèse console
./scripts/check-coverage.sh --html           # Rapport HTML sous target/llvm-cov/html/index.html
./scripts/check-coverage.sh --lcov           # Export CI (ne pas commiter lcov.info)
```

## 3. Tests E2E WebUI avec Playwright (`dtnpm-web-core/ui/`)

Les specs Playwright couvrent `bundles.spec.ts`, `chat.spec.ts`, `files.spec.ts`, `logs.spec.ts`, `markdown.spec.ts`, `pwa.spec.ts`, `security.spec.ts`, `send-bundle.spec.ts`, `station-overview.spec.ts` sur `http://127.0.0.1:8899`.

```bash
cd dtnpm-web-core/ui
pnpm install
pnpm build

# Mode standard (playwright.config.ts)
pnpm test:e2e

# Mode standalone / desktop (playwright.standalone.config.ts)
npx playwright test -c playwright.standalone.config.ts
```

Note : le serveur standalone/desktop doit écouter sur `http://127.0.0.1:8899` (ou `playwright.standalone.config.ts` doit être utilisé selon la configuration de démarrage définie).

## 4. Simulations E2E multi-nœuds & radioamateur (`dtnpm/examples/`)

Les scripts de démonstration et validation bout-en-bout se trouvent dans `dtnpm/examples/` :
- **Duo Hardy** : `dtnpm/examples/run_e2e_hardy_duo.sh` / `dtnpm/examples/test_e2e_hardy_duo.py`
- **Modem logiciel Direwolf (HQFBP / KISS)** : `dtnpm/examples/launch_dual_direwolf.sh`, `dtnpm/examples/test_direwolf_hqfbp.sh`, `dtnpm/examples/test_bidirectional_direwolf.sh`
- **Modem Mercury (ARQ / LTP)** : `dtnpm/examples/launch_dual_mercury.sh`, `dtnpm/examples/test_simplex_mercury_ltp.sh`
- **Services applicatifs** : `dtnpm/examples/test_basket.py`, `dtnpm/examples/test_bib.py`, `dtnpm/examples/test_forward.py`

Exécuter depuis `dtnpm/` après compilation des binaires (`cargo build --workspace`).

## 5. Campagnes de Fuzzing (`cargo-fuzz`)

Les cibles fuzz vérifiées de l'écosystème ciblent les décodeurs binaires et moteurs d'états critiques :

- **`dtnpm-cla-hqfbp-kiss`** :
  - `cla_stream` (`fuzz/fuzz_targets/cla_stream.rs`)
- **`dtnpm-cla-ltp-kiss`** :
  - `cla_packet` (`fuzz/fuzz_targets/cla_packet.rs`)
- **`dtnpm-cla-ltp-kiss/ltp`** :
  - `engine_ops` (`ltp/fuzz/fuzz_targets/engine_ops.rs`)
  - `sdnv_kiss` (`ltp/fuzz/fuzz_targets/sdnv_kiss.rs`)
  - `segment_decode` (`ltp/fuzz/fuzz_targets/segment_decode.rs`)

Lancer une campagne bornée dans le temps (ex. 10 minutes = `600` secondes par cible) avec la toolchain nightly :

```bash
# Exemple dans dtnpm-cla-hqfbp-kiss
cargo +nightly fuzz run cla_stream -- -max_total_time=600

# Exemple dans dtnpm-cla-ltp-kiss
cargo +nightly fuzz run cla_packet -- -max_total_time=600

# Exemple dans dtnpm-cla-ltp-kiss/ltp
cd dtnpm-cla-ltp-kiss/ltp
for target in engine_ops sdnv_kiss segment_decode; do
  cargo +nightly fuzz run "$target" -- -max_total_time=600
done
```

Ne pas laisser de répertoires `fuzz/corpus/` ou `fuzz/artifacts/` non souhaités dans l'arbre Git si `.gitignore` ne les exclut pas ; en cas de crash trouvé, extraire un test unitaire de non-régression minimal dans `tests/`.
