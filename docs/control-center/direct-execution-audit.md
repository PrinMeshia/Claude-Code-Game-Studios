# Audit — exécution directe et worktrees

**Branche examinée :** `feat/control-center-foundation`  
**Référence fonctionnelle :** `feature/unreal-mcp-integration`  
**Portée :** inspection statique du dépôt GitHub. Aucun lancement local de Claude Code ni test sur Fedora/Windows n'a été effectué.

## Constats vérifiés

### 1. Le dépôt ne fournit pas encore un runtime multi-projets

`docs/architecture/multi-project-workspace.md` indique explicitement que l'implémentation runtime est incomplète et que le workflow supporté reste le projet unique à la racine.

Le document identifie les exigences manquantes : découverte, sélection explicite, résolution du contexte, sécurité des chemins, isolation des moteurs, couverture de toutes les commandes et tests d'isolation entre deux projets.

### 2. Les hooks déduisent encore le projet depuis le répertoire courant

Dans `.claude/hooks/session-start.sh`, `.claude/hooks/log-agent.sh` et `.claude/hooks/log-agent-stop.sh`, la racine est choisie dans cet ordre :
1. le répertoire courant s'il contient `project.yaml` ou `.claude/` ;
2. `CLAUDE_PROJECT_DIR` ;
3. le répertoire du script.

Le hook SessionStart effectue ensuite plusieurs lectures relatives à cette racine : Git, configuration, production, tests et racine du code. Ce mécanisme est cohérent pour un projet unique, mais il ne constitue pas un contexte multi-projets explicite.

Le résolveur `.claude/hooks/yaml-helper.sh` suit également une logique de racine fondée sur le répertoire courant et `CLAUDE_PROJECT_DIR`. Les skills et scripts ne peuvent donc pas être redirigés de façon sûre en ajoutant simplement `projects/covLab/`.

### 3. Les paramètres worktree ne prouvent pas qu'un worktree est créé

- `.claude/settings.json` contient `worktree.baseRef: head`. Ce paramètre désigne une référence de base pour le mécanisme worktree ; il ne prouve pas qu'une session ou un agent crée systématiquement un worktree.
- `.worktreeinclude` documente les fichiers ignorés copiés dans un worktree **lorsqu'un worktree est créé**. Il ne constitue pas un déclencheur.
- Les hooks inspectés journalisent les événements et résolvent une racine ; ils ne créent pas eux-mêmes de worktree.

À ce stade, il serait donc incorrect de prétendre que le dépôt force tous les agents à travailler dans des worktrees. Il faut encore auditer les points d'entrée de lancement Claude Code et les options d'isolation déclarées par les agents/équipes avant de modifier la configuration.

### 4. Un risque concret existe avec les commandes lancées depuis le mauvais répertoire

`.claude/scripts/one-shot-run.sh` résout son `ROOT` depuis un argument explicite, sinon depuis le répertoire du script. Une commande appelée sans racine explicite peut donc viser la racine du framework au lieu du projet enfant.

Le risque ne se corrige pas en changeant uniquement le répertoire de la session : les skills, hooks et scripts doivent tous consommer le même contexte de projet.

## Décision technique proposée

Ne pas supprimer `.worktreeinclude` ni `worktree.baseRef` comme première action.

La prochaine tranche doit introduire un contrat de contexte explicite et testable, séparant :
- la racine du framework (agents, skills, hooks et règles partagés) ;
- la racine du projet sélectionné (dépôt Git, `project.yaml`, moteur et fichiers du jeu) ;
- le répertoire de travail effectif de chaque session.

Le lancement direct doit ensuite garantir que le processus Claude Code travaille dans la racine réelle du projet choisi, sans `--worktree` ni isolation worktree implicite. Les hooks doivent continuer à retrouver les ressources du framework tout en lisant/écrivant uniquement dans le projet sélectionné.

Toute résolution absente, ambiguë, hors du workspace autorisé ou incohérente avec la racine Git doit bloquer les opérations d'écriture. Aucun fallback silencieux vers la racine du framework.

## Critères d'acceptation avant branchement du Control Center

- Deux projets de test indépendants sont détectés et sélectionnables sans ambiguïté.
- Une session lancée pour le projet A a son working directory dans A ; idem pour B.
- Les hooks, skills, commandes et journaux identifient le même projet actif.
- Les commandes de configuration ne modifient jamais le `project.yaml` du framework par erreur.
- Aucun lancement du Control Center ne crée ou ne sélectionne un worktree.
- Les chemins relatifs et les liens symboliques qui sortent de la racine autorisée sont rejetés.
- Les tâches concurrentes avec périmètres d'écriture qui se chevauchent sont sérialisées.
- Le workflow historique à projet unique à la racine reste fonctionnel.

