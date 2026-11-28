# Control Center — Suivi d'implémentation

## Incrément 0 — UI foundation

- [x] Navigation et vues principales.
- [x] États d'interface explicites en absence de backend.
- [x] Aucune donnée fictive injectée.
- [x] Architecture cible et sources de vérité documentées.
- [x] Première brique du contexte multi-projets : résolveur explicite framework/projet + tests contractuels écrits (exécution locale encore à faire).
- [ ] Propagation du contexte dans les hooks, skills, commandes et lanceur Claude Code (runtime encore mono-projet tant que cette intégration n'est pas terminée).
- [ ] Politique sans worktrees appliquée et testée (audit initial effectué ; points d'entrée de lancement/isolation à vérifier).
- [ ] Adaptateur local.
- [ ] Sessions, agents, journaux, validations et Git raccordés.
- [ ] État Unreal MCP raccordé.
- [ ] Tests automatisés et validation Fedora/Windows.

## Audit technique — étape préparatoire

- [x] Vérification de la résolution de racine dans SessionStart et hooks de journalisation.
- [x] Vérification des paramètres `worktree.baseRef` et `.worktreeinclude` : ils ne démontrent pas à eux seuls la création systématique de worktrees.
- [x] Identification du risque de commandes lancées sans racine projet explicite.
- [x] Critères d'acceptation de l'exécution directe documentés dans [direct-execution-audit.md](direct-execution-audit.md).

## Incrément 1 — Project context foundation

- [x] Résolution distincte de la racine framework et de la racine projet.
- [x] Sélection explicite par identifiant ou chemin.
- [x] Refus d'une sélection implicite en workspace multi-projets.
- [x] Contrôle de confinement dans `projects/` après résolution du chemin physique.
- [x] Compatibilité du mode projet historique à la racine.
- [x] Tests contractuels ajoutés pour sélection, ambiguïté, traversal, symlink et mode legacy.
- [ ] Exécution des tests sur Fedora et Windows Git Bash.
- [ ] Intégration du résolveur dans les hooks et le lanceur.
- [ ] Vérification de la racine Git et du contexte moteur.

## Limites de validation

La prévisualisation HTML peut être ouverte directement dans un navigateur. Aucun test d'intégration, lancement Claude Code, test Unreal ou test Fedora/Windows n'a été exécuté dans le cadre de cet incrément.
