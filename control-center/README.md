# Control Center — UI foundation

Première fondation de l'interface graphique Claude Game Studios.

## État actuel

Cette livraison est volontairement une coquille d'interface sans backend :
- navigation entre Vue générale, Projets, Chantiers, Agents & sessions, Validations, Unreal Engine, Historique et Paramètres ;
- états vides explicites ;
- aucune donnée d'agent, de projet ou de session simulée ;
- aucune commande Claude Code ou opération Unreal déclenchée depuis le navigateur.

## Prévisualisation

Ouvrir directement index.html dans un navigateur. Aucun build ni dépendance npm n'est requis pour cette première prévisualisation.

## Lancer Claude Code sur un projet existant

Le lanceur expérimental est disponible depuis la racine du framework :

```bash
bash .claude/scripts/launch-project.sh covLab
```

Sous Windows, depuis PowerShell :

```powershell
.\.claude\scripts\launch-project.ps1 covLab
```

Ou depuis l'invite de commandes (CMD) :

```bat
.claude\scripts\launch-project.cmd covLab
```

Les deux points d'entrée Windows délèguent au même lanceur Bash. **Git for Windows (Git Bash) est donc requis** ; cela évite de maintenir deux implémentations divergentes des contrôles de sécurité.

Il démarre Claude Code avec `projects/covLab` comme répertoire de travail principal, ajoute le framework comme répertoire de ressources et fournit les hooks CCGS via une configuration temporaire de session. Les chemins historiques `.claude/hooks` et `.claude/scripts` sont raccordés au framework par liens de répertoire dans le projet.

Préconditions et garde-fous :
- `projects/covLab/project.yaml` doit exister.
- `projects/covLab` doit être la racine de son propre dépôt Git ou d'un submodule.
- Le système de fichiers doit permettre les liens symboliques ou jonctions de répertoire.
- Les répertoires projet `.claude/hooks` et `.claude/scripts` existants ne sont jamais remplacés : en cas de conflit, le lanceur s'arrête.
- Les options `--worktree` / `-w` et les agents déclarant `isolation: worktree` sont refusés.

Les tests contractuels sont écrits, mais cette intégration n'a pas encore été exécutée sur Fedora ou Windows Git Bash. Après lancement, vérifier `/status` et les événements de hooks avant toute tâche qui modifie le projet.

## À réaliser avant utilisation opérationnelle

1. Adaptateur local sécurisé entre l'interface et les mécanismes existants.
2. Découverte et sélection d'un projet local, avec résolution de sa racine absolue.
3. Lecture des sessions, hooks, journaux, décisions et résultats réels.
4. Lancement contrôlé des skills/workflows existants.
5. Raccordement de l'intégration Unreal MCP existante via le backend local.
6. Tests d'intégration et de non-régression sur Fedora et Windows.

Les compteurs « — » et les panneaux vides signalent volontairement l'absence de backend.
