---
title: Monitoring applicatif
part: part1
weight: 2
labels:
  apps: Applications
  services: Services & carte de dépendance
  bt: Transactions métier
---

Cette partie couvre les écrans utilisés au quotidien pour surveiller le comportement des applications. Ce sont les équivalents fonctionnels de ce que d'autres plateformes d'APM appellent « Application Monitoring ».

## Applications — vue d'ensemble {#apps}

L'écran « Applications » est la page d'accueil du module APM. Il liste chaque application qui a émis de la télémétrie récemment, avec son nombre de services distincts et un indicateur de santé global. C'est le point de départ pour repérer rapidement quelle application mérite votre attention avant d'aller regarder le détail.

{{< callout >}}
Si aucune application n'apparaît, la cause la plus fréquente est qu'aucune télémétrie récente n'a été reçue : élargir la fenêtre de temps ou vérifier que le Collecteur OpenTelemetry envoie bien ses données vers Neurons.
{{< /callout >}}

## Services et carte de dépendance {#services}

L'écran « Services » liste tous les services actifs avec leurs indicateurs **RED** (débit, erreurs, latence) sur la fenêtre de temps sélectionnée, ainsi qu'un graphique de débit en direct et un résumé de santé généré automatiquement. C'est l'écran le plus consulté au quotidien.

La carte de dépendance des services (*Service Map*) est intégrée à cet écran : elle représente visuellement quel service appelle quel autre, avec pour chaque lien un indicateur de santé (sain, dégradé, critique) basé sur le taux d'erreur de l'appel. Chaque service peut aussi être ouvert individuellement pour afficher :

- l'évolution du débit de requêtes par minute,
- l'évolution des erreurs par minute,
- les percentiles de latence (p50, p95, p99…),
- les appels vers la base de données propres à ce service (nombre d'appels, temps total, temps moyen),
- le détail par opération (endpoint), avec ses propres indicateurs RED,
- une analyse de santé générée par IA, qui résume en langage naturel ce qui se passe sur le service.

## Traces {#traces}

L'écran « Traces » permet de rechercher et d'inspecter des requêtes individuelles plutôt que des agrégats. Chaque trace est reconstituée comme un graphe de services enrichi, qui distingue les types d'appels rencontrés : appels entre services internes, appels base de données, cache, messagerie, appels RPC, fournisseurs externes, et étapes côté navigateur (frontend).

C'est l'écran à utiliser pour comprendre précisément pourquoi une requête donnée a été lente ou a échoué : on y voit l'enchaînement exact des étapes, leur durée individuelle, et où le temps a réellement été consommé.

### Appels à la base de données dans une trace

Chaque appel à une base de données apparaît dans la cascade des spans avec une icône de base de données, nommé par son opération et sa table (par exemple `SELECT orders`). Cliquez dessus pour ouvrir son détail :

- **La requête SQL complète**, avec un bouton pour la copier. Les longues requêtes sont repliées : *Show the full query* l'affiche en entier.
- **Trois graphiques pour cette requête** sur la période sélectionnée, en comptant tous les appels de la même requête dans ce service (les valeurs changent, la requête est la même) : **nombre d'appels**, **temps total** et **temps moyen**.

Si aucune requête SQL n'apparaît, l'application ne l'envoie pas encore : voir [Capture des requêtes SQL](#otel).

## Transactions métier (Business Transactions) {#bt}

Une transaction métier est un point d'entrée applicatif nommé et suivi dans la durée — par exemple « Connexion », « Recherche produit » ou « Paiement ». Contrairement aux services, les transactions métier ne sont pas déclarées manuellement : elles sont détectées automatiquement par une tâche de fond qui repère les schémas de trafic récurrents, puis inscrites dans un registre.

Pour chaque transaction métier, la plateforme permet de consulter son propre historique de santé, sa carte de flux (les services traversés par les traces qui commencent par cette transaction), et de configurer des notifications dédiées.

### Règles de détection et groupes

Des règles de détection permettent d'affiner ou de prioriser la façon dont le trafic est reconnu comme appartenant à telle ou telle transaction, et des groupes permettent de régler la façon dont plusieurs transactions proches sont comptabilisées ensemble. Une transaction métier peut également être retirée manuellement (mise à la corbeille) avec une période de grâce configurable avant suppression définitive.

## Business Journeys {#bj}

Les Business Journeys sont des entonnoirs de conversion qui relient plusieurs étapes entre elles — par exemple : page produit → ajout au panier → paiement → confirmation. Ils sont reconstitués en combinant les pages vues côté navigateur (RUM) et les transactions métier associées, ce qui permet de voir, étape par étape, où les utilisateurs abandonnent réellement leur parcours.

## Erreurs {#errors}

L'écran « Errors » regroupe les traces en erreur par **signature** — c'est-à-dire par type d'erreur similaire — plutôt que de lister chaque occurrence individuellement. Cela permet de voir immédiatement quelles sont les erreurs les plus fréquentes sur la période, puis d'ouvrir un exemple représentatif de chaque signature pour l'investiguer.

## Base de données {#db}

L'écran « Database » regroupe tous les appels sortants vers une base de données par signature de requête normalisée (la même requête avec des paramètres différents est comptée comme une seule signature). Il affiche le volume d'appels, le temps total consommé et le temps moyen par appel, ce qui permet d'identifier rapidement les requêtes les plus coûteuses.
