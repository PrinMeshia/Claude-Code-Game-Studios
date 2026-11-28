# Control Center — Architecture cible

## Décision de périmètre

Le Control Center est une couche de présentation et de pilotage au-dessus de Claude Code Game Studios. Il ne remplace ni ne réimplémente l'orchestrateur, la délégation des agents, les skills, les hooks, les règles de gouvernance ou l'intégration Unreal MCP.

## Flux cible

    Browser UI
       | HTTP / WebSocket (contrat local à définir et versionner)
       v
    Local Control Adapter
       |-- Workspace / project context
       |-- Claude Code CLI session launcher
       |-- Existing hooks and session logs
       |-- Existing skill/workflow entrypoints
       |-- Git status / diff / checkpoints
       +--> Existing Unreal MCP integration (through adapter only)

Le navigateur ne doit jamais recevoir de credentials, ouvrir de shell arbitraire, ni communiquer directement avec le serveur MCP Unreal. Le serveur local doit écouter sur loopback par défaut, valider les origines/jetons de session et limiter les actions à une liste explicite.

## Sources de vérité

| Information | Source |
|---|---|
| Projets et racines | Workspace configuré + project.yaml du projet sélectionné |
| Agents et sessions | Claude Code + hooks/journaux existants |
| Chantiers et tâches | Artefacts de production existants (epics/stories) |
| Décisions | Workflows et journaux de décision existants |
| Modifications | Git du dépôt sélectionné |
| État Unreal | Intégration Unreal MCP existante + inspection de l'éditeur |

L'interface ne doit pas inventer d'état lorsque la source est indisponible : afficher inconnu, non connecté ou un état vide.

## Contexte multi-projets

Le workspace peut contenir plusieurs projets indépendants sous projects/, mais le runtime multi-projets est explicitement incomplet. Les hooks inspectés choisissent encore leur racine à partir du répertoire courant, puis de CLAUDE_PROJECT_DIR, avec un fallback vers l'emplacement du script. Le résolveur YAML suit cette même logique. Ajouter un dossier projects/covLab ne redirige donc pas les workflows de façon sûre.

Une première brique est maintenant présente dans `.claude/scripts/project-context.sh`. Elle expose séparément `CCGS_FRAMEWORK_ROOT`, `CCGS_PROJECT_ROOT` et `CCGS_PROJECT_ID`, accepte une sélection explicite, conserve le mode mono-projet à la racine et refuse les sélections ambiguës ou les chemins qui sortent de `projects/`. Des tests contractuels sont ajoutés dans `.claude/scripts/tests/project-context.test.sh`.

Le lanceur `.claude/scripts/launch-project.sh` est maintenant ajouté. Il démarre Claude Code depuis le projet sélectionné, vérifie que celui-ci est bien la racine de son dépôt Git, ajoute le framework comme répertoire de ressources et fournit les hooks via un fichier `--settings` temporaire. Pour que les scripts historiques conservent leurs chemins relatifs, il crée des liens de répertoire `project/.claude/hooks` et `project/.claude/scripts` vers les répertoires partagés. Il refuse de remplacer des répertoires projet déjà présents. Il bloque aussi les options CLI `--worktree` / `-w` et les agents dont le frontmatter déclare `isolation: worktree` (framework, projet ou configuration utilisateur).
 
Le lanceur et ses tests contractuels sont écrits, mais pas encore exécutés sur Fedora ou Windows Git Bash. L'intégration des hooks doit donc être considérée comme implémentée sur le plan du code, pas encore validée en environnement réel. Le chargement des instructions additionnelles dépend de `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`.

Chaque invocation de workflow doit recevoir le contexte sélectionné. Ne pas s'appuyer uniquement sur le répertoire courant implicite. Voir [l'audit d'exécution directe](direct-execution-audit.md) pour les constats et critères d'acceptation.

## Contraintes de chargement Claude Code (vérifiées dans la documentation officielle)

Le lancement depuis la racine du projet sélectionné est nécessaire pour que ce répertoire soit le working directory principal. Le framework partagé peut être ajouté avec `claude --add-dir <framework-root>` : Claude Code charge alors les skills, commandes et subagents de ce répertoire additionnel.

Attention : `--add-dir` ne charge pas les hooks ni les paramètres généraux de `.claude/settings.json` depuis le répertoire ajouté. Les hooks et les autres clés de settings sont lus depuis le `.claude/` du working directory courant, sans remontée vers un parent. Les fichiers `CLAUDE.md` et `.claude/rules/` du répertoire additionnel nécessitent en plus `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`.

Conséquence d'architecture : le futur lanceur doit démarrer Claude Code depuis la racine projet, ajouter la racine framework pour les skills/commands/agents, activer explicitement le chargement des instructions additionnelles, et fournir au projet une configuration locale de hooks qui délègue vers les scripts partagés du framework. Il ne faut pas compter sur `--add-dir` pour activer les hooks du framework. Cette configuration locale doit être installée/actualisée sans écraser les réglages propres au projet.

Références : [Claude Code — skills depuis un répertoire additionnel](https://code.claude.com/docs/en/skills#load-skills-from-a-directory-outside-the-project) ; [Claude Code — working directories, additional directories et chargement des hooks](https://code.claude.com/docs/en/permissions#additional-directories-grant-file-access-not-configuration).

## Politique de travail direct (sans worktrees)

Objectif utilisateur : les agents travaillent dans le répertoire local réel du projet, pas dans des Git worktrees.

1. Le backend lance la session avec le répertoire du projet sélectionné comme working directory.
2. Les workflows ne créent pas de worktree et ne basculent pas silencieusement vers un autre répertoire.
3. Les écritures concurrentes sont sérialisées par périmètre de fichiers ; les tâches indépendantes peuvent rester parallèles si leurs périmètres ne se chevauchent pas.
4. Git reste obligatoire pour l'observabilité : état initial, diff et checkpoints/commits selon la politique du projet.
5. Les opérations destructives, changements de schéma et décisions architecturales restent soumises aux validations configurées.
6. Toute erreur de résolution du projet bloque l'écriture ; aucun fallback silencieux vers la racine du framework.

Le lanceur ne passe jamais `--worktree` à Claude Code et refuse les agents configurés avec `isolation: worktree`. Il ne modifie pas `worktree.baseRef`, qui ne suffit pas à lui seul à déclencher la création d'un worktree. Cette garde est un contrôle préventif, pas encore une preuve d'exécution sur les versions Fedora/Windows utilisées. Les tâches parallèles qui écrivent dans des fichiers qui se chevauchent ne sont pas encore verrouillées par un mécanisme de sérialisation ; les scopes de coordination existants doivent être respectés jusqu'à l'ajout et la validation d'un verrou de fichiers.
 
Ne pas simplement supprimer .worktreeinclude ou worktree.baseRef : l'audit statique montre que ces éléments ne prouvent pas à eux seuls la création systématique de worktrees. Il faut d'abord auditer les points d'entrée Claude Code et les options d'isolation des agents, puis garantir et tester qu'aucune invocation du Control Center ne bascule vers un worktree.

## Sécurité et gouvernance

- Loopback par défaut ; pas d'exposition LAN/WAN implicite.
- Authentification locale à durée limitée et validation stricte de l'origine.
- Allowlist de commandes et de skills ; pas d'exécution de shell arbitraire depuis le navigateur.
- Les demandes d'approbation doivent être reliées au mécanisme de validation réel ; aucun bouton actif sans action correspondante.
- Les appels Unreal sont inspectés avant mutation, exécutés séquentiellement, puis vérifiés.
- Journaliser acteur, projet, session, action, horodatage, résultat et référence Git lorsque disponible.

## Étapes d'implémentation

1. Workspace context : contexte multi-projets déterministe et tests.
2. Worktree policy : exécution directe dans la racine sélectionnée, sans worktrees, tests de non-régression.
3. Local adapter : contrat API versionné, découverte, sessions, événements, commandes autorisées.
4. Dashboard live : connecter les vues aux données réelles et gérer reconnexion/erreurs.
5. Unreal panel : état MCP et inspections via intégration existante.
6. Validation : tests Fedora/Windows, sécurité loopback, scénarios multi-projets et vérification éditeur.

## Non-objectifs

- Réécrire Claude Code Game Studios.
- Réimplémenter un moteur multi-agent.
- Exécuter Unreal MCP depuis le navigateur.
- Introduire une base de données parallèle tant que les artefacts et journaux existants suffisent.
