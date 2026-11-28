# Control Center — Suivi d'implémentation

## Incrément 0 — UI foundation

- [x] Navigation et vues principales.
- [x] États d'interface explicites en absence de backend.
- [x] Aucune donnée fictive injectée.
- [x] Architecture cible et sources de vérité documentées.
- [ ] Contexte multi-projets (runtime existant encore mono-projet ; audit des hooks et du résolveur effectué).
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

## Limites de validation

La prévisualisation HTML peut être ouverte directement dans un navigateur. Aucun test d'intégration, lancement Claude Code, test Unreal ou test Fedora/Windows n'a été exécuté dans le cadre de cet incrément.
