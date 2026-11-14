---
name: create-dtnpm-cla
description: >-
  Guides creation of a Convergence Layer Adapter (`dtnpm-cla-*`) from `template-dtnpm-cla`, implementing `hardy_bpa::cla::Cla`, bounded async `Driver` channels, peer resolution, gRPC/UDS BPA registration (`--token-file`), and opt-in unauthenticated safety switches. Use when creating or extending a transport CLA for radio, UDP, serial, or KISS links.
---

# Créer un Convergence Layer Adapter (`dtnpm-cla-*`)

Cette compétence décrit la création d'un adaptateur de couche de convergence (CLA) BPv7 compatible avec le BPA Hardy et `dtnpm`, à partir de `template-dtnpm-cla`.

## Architecture d'un CLA `dtnpm-cla-*`

Un CLA réside dans son propre dépôt (`dtnpm-cla-<protocole>`) et suit le patron hybride `lib.rs` + `main.rs` :
- `src/cla.rs` : implémentation du trait `hardy_bpa::cla::Cla` (`on_register`, `on_unregister`, `forward`) plus méthodes de contrôle (`cla_init`, `register_peer`, `disconnect`, `close`, `peer_resolver`).
- `src/driver.rs` : boucle asynchrone gérant la liaison physique/réseau (UDP, TCP, KISS/TNC, série, AX.25, ARQ) via des canaux bornés `tokio::sync::mpsc`.
- `src/config.rs` : schéma de configuration TOML/YAML avec validation stricte des paramètres et opt-ins explicites.
- `src/error.rs` : énumération d'erreurs typées (`thiserror`) sans panique.
- `src/main.rs` : démon autonome se connectant au BPA via `GrpcBpaClient::with_auth` / `BpaClient::as_registration`.

## Étapes d'instanciation

### 1. Dupliquer `template-dtnpm-cla`

```bash
cp -r ../template-dtnpm-cla dtnpm-cla-<protocole>
cd dtnpm-cla-<protocole>
rm -rf .git target
git init -b main
```

Mettre à jour `Cargo.toml` (`package.name`, `[lib]`, `[[bin]]`) et `src/main.rs`.

### 2. Implémenter le trait `Cla` (`src/cla.rs`)

- Conserver les champs principaux : `config: ClaConfig` et `inner: Arc<RwLock<Option<ClaInner>>>` (stockant `Arc<dyn Sink>`, `Arc<TaskPool>`, `mpsc::Sender<DriverCommand>`, et `JoinHandle<()>`).
- **`cla_init(&self) -> ClaInit`** : définir `address_type`, `lane_count` (`NonZeroU32`), et `max_bundle_size` (`NonZeroU64`).
- **`on_register` / `on_unregister`** : démarrer / arrêter proprement la tâche `Driver` via canal de commande borné.
- **`forward`** :
  - Lire le flux de bundle de façon bornée (`buffer_stream(stream, total_len)` avec contrôle strict <= `max_frame_size` / `max_bundle_size`).
  - Envoyer au driver avec `tokio::time::timeout` pour éviter tout blocage indéfini du BPA, puis renvoyer `ForwardBundleResult`.
- **Réception** : le driver délivre les bundles entrants au BPA via `sink.dispatch(node_id, Some(&cla_addr), &mut bundle_data).await`.

### 3. Sécurité réseau, RF et authentification par défaut

Tout nouveau CLA doit respecter les garde-fous de l'écosystème :
- **Canaux et tampons bornés** : ne jamais utiliser `mpsc::unbounded_channel()`, ni allouer selon une longueur lue sur le fil sans plafond explicite (`max_frame_size` / MTU / taille de segment maximale).
- **Anti-usurpation / migration d'adresse (liens IP/UDP)** :
  - Désactiver par défaut l'apprentissage dynamique ou la migration d'IP sans authentification (`allow_ip_migration = false` par défaut par pair).
  - Si un mode non authentifié existe pour le développement ou des liens déjà chiffrés (WireGuard/VPN), exiger un opt-in explicite (ex. `--allow-unauthenticated-udp` ou `--allow-unauthenticated-bps-opt-in`) accompagné d'un log `warn!` bien visible.
- **Identification radioamateur (liens RF / KISS / AX.25 / ARQ)** :
  - Exiger l'indicatif local (`callsign` / `--require-callsign`) par défaut ; n'autoriser le trafic RF non identifié que via opt-in explicite (modèle `--allow-unidentified-rf` utilisé dans `dtnpm-cla-hqfbp-kiss` et `dtnpm-cla-mercury-arq`).
- **Session & FSM (liens ARQ/LTP)** :
  - Borner le nombre maximal de sessions actives et le temps de vie d'une session orpheline pour prévenir les attaques par épuisement mémoire (DoS).

### 4. Authentification gRPC / UDS vers le BPA (`src/main.rs`)

- Supporter `--socket` / `DTN_HDY_SOCKET` pour Unix Domain Socket.
- Supporter `--token-file` / `DTN_HDY_TOKEN_FILE` en priorité sur `--token`.
- Documenter les décisions de protocole et compromis de sécurité dans `adr/`.

### 5. Fuzzing recommandé

Pour tout CLA parsant des trames binaires (SDNV, KISS, HDLC, en-têtes protocolaires), créer une cible `cargo-fuzz` dans `fuzz/fuzz_targets/` alimentant directement le décodeur avec des octets arbitraires (`&[u8]`) afin de vérifier l'absence de panique, d'overflow arithmétique et de boucle infinie.

### 6. Intégration dans `dtnpm`

Lorsque le CLA est prêt à être embarqué dans le binaire unifié :
- Ajouter une feature `cla-<protocole> = ["node", "dep:dtnpm-cla-<protocole>"]` dans `dtnpm/Cargo.toml`.
- Lier sa configuration sous `[[clas]]` dans `dtnpm`.

## Vérification obligatoire

```bash
./scripts/install-hooks.sh
cargo fmt --all -- --check
cargo clippy --workspace --lib --bins -- -D warnings -D clippy::unwrap_used -D clippy::panic
cargo test --all-targets
./scripts/check-security.sh --strict
```
