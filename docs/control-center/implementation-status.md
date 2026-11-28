# Control Center — Suivi d'implémentation

## Incrément 0 — UI foundation

- [x] Navigation et vues principales.
- [x] États d'interface explicites en absence de backend.
- [x] Aucune donnée fictive injectée.
- [x] Architecture cible et sources de vérité documentées.
- [x] Première brique du contexte multi-projets : résolveur explicite framework/projet + tests contractuels écrits (exécution locale encore à faire).
- [x] Lanceur Claude Code : démarrage dans le projet sélectionné, ajout du framework via `--add-dir`, hooks fournis via `--settings` temporaire et chemins historiques raccordés par liens de répertoires.
- [x] Contrôle de racine Git du projet et refus des projets imbriqués dans un dépôt parent.
- [x] Garde anti-worktree : refus des options CLI `--worktree` / `-w` et des agents configurés `isolation: worktree` (framework, projet et configuration utilisateur).
- [x] Workflow GitHub Actions ajouté pour exécuter les tests contractuels sur Ubuntu et Windows à chaque push sur cette branche.
- [x] CI GitHub Actions : tests contractuels réussis sur `ubuntu-latest` et `windows-latest` (run `46144094693`, commit `7a64dca`).
- [ ] Essai réel sur Fedora local et sur le poste Windows cible avec la version Claude Code utilisée.
- [ ] Vérifier les hooks chargés avec `/status` et les événements de session réels.
- [x] Politique sans worktrees appliquée au lanceur (garde statique sur options et frontmatter).
- [ ] Non-régression des sous-agents et vérification qu'aucune isolation indirecte ne crée de worktree.
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
- [x] Intégration du résolveur dans le lanceur.
- [x] Vérification de la racine Git du dépôt sélectionné.
- [ ] Vérification du contexte moteur et des chemins Unreal dans covLab.

## Limites de validation

La prévisualisation HTML peut être ouverte directement dans un navigateur. Les tests contractuels ont réussi dans GitHub Actions sur Ubuntu et Windows. Cela valide les scripts et leurs scénarios simulés, mais pas un lancement avec le vrai Claude Code, ni l'environnement Fedora local. Aucun lancement réel de Claude Code, test Unreal ou test Fedora/Windows n'a été effectué. La politique de travail direct ne sérialise pas encore les écritures concurrentes sur des fichiers qui se chevauchent.
