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

## À réaliser avant utilisation opérationnelle

1. Adaptateur local sécurisé entre l'interface et les mécanismes existants.
2. Découverte et sélection d'un projet local, avec résolution de sa racine absolue.
3. Lecture des sessions, hooks, journaux, décisions et résultats réels.
4. Lancement contrôlé des skills/workflows existants.
5. Raccordement de l'intégration Unreal MCP existante via le backend local.
6. Tests d'intégration et de non-régression sur Fedora et Windows.

Les compteurs « — » et les panneaux vides signalent volontairement l'absence de backend.
