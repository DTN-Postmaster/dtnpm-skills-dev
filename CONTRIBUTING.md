# Contribuer à `skills-dev`

Merci de contribuer aux compétences développeurs de l'écosystème `dtn-postmaster`.

## Ajouter ou modifier une skill

1. Créez un répertoire en `kebab-case` sous `skills/<nom-skill>/` contenant un fichier `SKILL.md`.
2. Vérifiez que le frontmatter YAML contient `name` (= nom du dossier) et `description` (clair, concis, 3e personne, déclencheurs explicites).
3. Vérifiez chaque nom de trait, chemin de template, flag CLI ou cible fuzz directement dans le dépôt concerné (`template-dtnpm-*`, `dtnpm-core`, `dtnpm-web-core`, `dtnpm`, `dtnpm-cla-*`) avant de le documenter.
4. Évitez les fichiers temporaires et les marqueurs de tâches inachevées.
5. Exécutez `./scripts/validate-skills.sh` et vérifiez que toutes les vérifications passent avant d'ouvrir une Pull Request.
