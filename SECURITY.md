# Politique de sécurité — `skills-dev`

## Objectif de sécurité

Les skills fournies dans `skills-dev` guident l'écriture de code Rust/TypeScript et la configuration de services réseau et radioamateurs. En conséquence, un mauvais exemple dans une `SKILL.md` introduit directement des vulnérabilités chez les utilisateurs finaux.

Les contributions doivent systématiquement proscrire :
- Les valeurs par défaut non authentifiées ou non chiffrées sans avertissement et drapeau d'opt-in explicite.
- Le passage de secrets via arguments CLI en clair plutôt que `--token-file` ou stdin sécurisé.
- Les appels paniquants en code applicatif Rust (`unwrap()`, `expect()`) et les constructions SQL/HTML non paramétrées (`dangerouslySetInnerHTML` sans assainissement strict).
- L'utilisation d'actions GitHub non épinglées par SHA-1 complet.

## Signaler une vulnérabilité ou une recommandation dangereuse

Si vous identifiez une erreur de sécurité dans une skill ou un workflow de ce dépôt, veuillez ouvrir un signalement privé auprès des mainteneurs (`security@dtn-postmaster.org`) ou via l'onglet GitHub Security Advisories avant toute divulgation publique.
