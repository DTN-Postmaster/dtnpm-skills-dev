# AGENTS.md — DTN Postmaster (`skills-dev`)

Ce document encadre le travail des agents IA et contributeurs sur le dépôt `skills-dev`.

## Règles de conception des `SKILL.md`

1. **Format Antigravity strict** :
   - Chaque skill réside dans `skills/<nom-kebab-case>/SKILL.md`.
   - Le frontmatter YAML est obligatoire et doit déclarer :
     - `name` : identique au nom du dossier (`^[a-z0-9]+(-[a-z0-9]+)*$`).
     - `description` : à la troisième personne, décrivant **ce que fait** la skill et **quand l'activer** (mots-clés précis : traits Rust, templates, commandes, frameworks de conformité), sans dépasser 1024 caractères.
2. **Vérité terrain (Zero Hallucination)** :
   - Toute signature Rust, route HTTP, flag CLI, variable d'environnement, cible de fuzzing ou chemin de fichier cité dans une skill doit provenir directement du code source vérifié dans l'organisation `dtn-postmaster`.
   - Ne jamais inventer de commandes, d'options ou de fichiers inexistants.
3. **Sécurité par défaut (Secure-by-Default)** :
   - Les instructions de développement doivent promouvoir le respect du EU Cyber Resilience Act (CRA), OWASP ASVS, BPSec strict/warn, zéro `.unwrap()` / `.expect()` en production Rust, gRPC authentifié par UDS + token (`--token-file`), et opt-in explicite avec journalisation `warn!` pour tout comportement dégradé.
4. **Hygiène CI & Dépôt** :
   - Actions GitHub obligatoirement épinglées par SHA-1 (40 caractères) avec `permissions: contents: read` et `step-security/harden-runner`.
   - Aucun secret ni clé réelle ; seuls les indicatifs de test radioamateur (`F*TEST`, `N0CALL`) sont tolérés dans les exemples.

## Vérification obligatoire avant commit

```bash
./scripts/install-hooks.sh
./scripts/validate-skills.sh
```
