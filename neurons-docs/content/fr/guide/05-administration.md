---
title: Administration & Exploitation
navTitle: Administration
part: part4
weight: 5
labels:
  settings: Réglages
  otel: Instrumentation OpenTelemetry
  backup: Sauvegarde & restauration
tocLabels:
  otel: Instrumentation OTel
---

Cette partie s'adresse aux personnes responsables du bon fonctionnement de la plateforme elle-même : configuration, rétention des données, instrumentation des applications, intégrations externes, déploiement et sauvegarde.

## Réglages (Settings) {#settings}

La page « Settings » regroupe cinq zones de configuration, chacune sous forme d'une carte cliquable :

| Carte | Rôle |
|---|---|
| **OpenTelemetry Collector** | Gérer les configurations du Collecteur poussées vers les agents installés sur votre infrastructure. |
| **Database Configuration** | Basculer et gérer les sources de données Vertica / PostgreSQL / Oracle actives. |
| **Data Retention** | Configurer la durée de conservation de chaque catégorie de données (détail ci-dessous). |
| **External CMDB Integration** | Connecter et synchroniser les fiches d'actifs avec une CMDB externe. |
| **External Event Management** | Transférer les événements de la plateforme vers un outil externe de gestion d'incidents. |
{firstcol="30"}

## Rétention des données {#retention}

La rétention des données détermine combien de temps chaque catégorie de télémétrie est conservée avant suppression automatique — un arbitrage entre coût de stockage et profondeur d'investigation possible. Elle est configurée séparément pour chaque catégorie, car leur utilité dans le temps n'est pas la même :

| Catégorie | Par défaut | Plage | Pourquoi |
|---|---|---|---|
| Spans (traces brutes) | 30 j | 1–90 j | Volumineuses, surtout utiles les premiers jours/semaines pour investiguer un incident précis. |
| Logs | 30 j | 1–90 j | Même profil que les traces brutes. |
| Métriques — 1 minute | 15 j | 1–30 j | Analyses fines, utilisées au-delà d'une semaine lors d'une investigation approfondie. |
| Métriques — 1 heure | 90 j | 7–180 j | Comparaisons de tendance mois par mois. |
| Métriques — 1 jour | 400 j | 30–730 j | Comparaisons d'une année sur l'autre. |
| Événements résolus | 90 j | 1–730 j | Les événements ouverts ou acquittés ne sont jamais purgés, quel que soit leur âge. |
{mono="2,3"}

Pour chaque zone, la page présente une description pédagogique, un indicateur d'usage réel (lignes et taille estimée), le réglage du nombre de jours, un bouton de purge immédiate (avec confirmation), et un historique des purges passées.

{{< callout >}}
La taille sur le disque est une estimation ; si elle n'est pas disponible pour une table, le nombre de lignes reste affiché, avec une mention explicite que la taille est inconnue plutôt qu'une valeur fausse.
{{< /callout >}}

Une purge automatique passe une fois par jour et applique les réglages configurés pour chaque zone. Une purge peut aussi être déclenchée manuellement à tout moment ; dans les deux cas, l'action est journalisée avec la date, le nombre de lignes supprimées et la source du déclenchement.

## Instrumentation des applications (OpenTelemetry) {#otel}

Pour qu'une application apparaisse dans Neurons, elle doit être instrumentée avec OpenTelemetry et configurée pour exporter ses traces et logs vers le Collecteur. Ce paragraphe couvre un point d'attention fréquent une fois l'instrumentation de base en place : la capture des en-têtes HTTP et, plus rarement, du contenu des requêtes/réponses.

### Capture des en-têtes HTTP

Par sécurité, OpenTelemetry ne capture aucun en-tête HTTP par défaut — les en-têtes contiennent fréquemment des informations sensibles (jetons, cookies de session). La capture doit être explicitement activée, séparément pour les requêtes entrantes et sortantes, et séparément pour la requête et la réponse. Cela se fait par variables d'environnement pour la plupart des langages backend ; côté navigateur, la même liste explicite est déclarée dans la configuration JavaScript de l'instrumentation.

{{< callout type="warn" >}}
Quel que soit le langage, la même règle s'applique : ne jamais capturer « tous les en-têtes » — toujours une liste explicite, en excluant systématiquement les en-têtes d'authentification et les cookies.
{{< /callout >}}

### Capture du corps des requêtes et réponses

OpenTelemetry ne capture pas nativement le contenu (le corps) des requêtes ou réponses — uniquement leur taille en octets. Capturer le contenu réel nécessite une instrumentation personnalisée, activée uniquement pour les routes explicitement choisies, avec deux règles à respecter systématiquement : limiter la taille capturée, et masquer les champs sensibles avant tout envoi — il n'y a pas de retour en arrière possible une fois la donnée exportée.

## Intégrations externes {#integrations}

Deux intégrations permettent de relier Neurons au reste de l'écosystème d'exploitation :

- **CMDB externe** — synchronise la liste consolidée des applications, services et transactions métier avec une base de gestion de configuration externe.
- **Gestion externe des événements** — transfère les événements générés par Neurons vers un outil externe de gestion d'incidents.

## Déploiement Kubernetes {#k8s}

Neurons se déploie comme trois composants indépendants, chacun avec sa propre image, réunis dans le même espace de noms Kubernetes :

| Composant | Rôle | Mise à l'échelle |
|---|---|---|
| apm-ingest | Reçoit la télémétrie, exécute les workers de calcul et sert l'API de requêtage. | Le service d'ingestion/requêtage se scale horizontalement ; les 3 workers de fond restent à une seule instance. |
| neurones-backend | API de contrôle : authentification, CMDB, administration du Collecteur, événements temps réel. | Une seule instance. |
| neurones-frontend | Application web (dashboards, topologie, réglages), Next.js. | Se scale horizontalement. |
{mono="1"}

Les trois composants s'appuient sur une base Vertica externe et sur une petite base PostgreSQL de contrôle partagée. Les deux doivent exister et être accessibles avant de démarrer le déploiement.

### Points d'attention avant un premier déploiement

- Un StorageClass supportant l'accès **ReadWriteMany** est nécessaire pour le volume partagé de la base GeoIP — de nombreuses classes de stockage cloud par défaut (EBS, par exemple) ne le permettent pas.
- La base GeoIP (MaxMind GeoLite2) n'est pas fournie dans l'image publiée pour des raisons de licence : chaque client doit générer sa propre clé de licence.
- Le schéma PostgreSQL de {{< mono "neurones-backend" >}} n'est pas appliqué automatiquement en production — une migration {{< mono "alembic upgrade head" >}} doit être exécutée explicitement avant le premier démarrage.
- Le schéma Vertica n'est pas non plus appliqué automatiquement : toutes les migrations doivent être appliquées avant le premier démarrage d'apm-ingest.
- {{< mono "neurones-backend" >}} n'accepte que les origines explicitement listées dans sa configuration CORS ; l'oublier se traduit par un frontend qui s'affiche mais dont tous les appels API échouent silencieusement.
- Les URL publiques (API et WebSocket) de {{< mono "neurones-frontend" >}} sont figées au moment de la construction de son image, pas au démarrage du conteneur.
- Le tampon d'ingestion est uniquement en mémoire, sans file d'attente durable derrière lui : dimensionner la mémoire avec une marge, et laisser un délai d'arrêt suffisant lors des mises à jour.
- Le jeton d'ingestion est un secret partagé unique, sans portée par client : à traiter comme une information sensible et à faire tourner s'il est exposé.

Une fois configuré, un script unique ({{< mono "deploy-neurons-apm.sh" >}}) prend en charge l'ensemble du déploiement, puis attend que tout soit prêt. Il peut être relancé sans risque après une modification de configuration.

## Sauvegarde et restauration {#backup}

Neurons conserve ses données à trois endroits. Ils n'ont pas le même rôle, et seuls deux d'entre eux doivent être sauvegardés :

| Stockage | Ce qu'il contient | À sauvegarder ? |
|---|---|---|
| **Vertica** (le « Data Lake ») | Toute la télémétrie : traces, logs, événements navigateur, replays de session, résumés pré-calculés utilisés par les tableaux de bord, points de reprise des workers, historique des alertes et incidents. | **Oui — critique.** C'est la seule copie de votre historique. |
| **PostgreSQL** | La configuration : utilisateurs et accès, réglages, applications, règles de santé et politiques de notification, applications navigateur et leurs champs métier, et la base Vertica utilisée par la plateforme. | **Oui — petite mais critique.** Sans elle, la plateforme ne fonctionne pas correctement, même avec un Vertica intact. |
| **Kafka** (mode Kafka uniquement) | Les dernières heures de trafic entrant, avant leur écriture dans Vertica. | Non — c'est une zone tampon temporaire. Elle aide en revanche après une restauration (voir plus bas). |

Les images des applications et la base de géolocalisation (GeoIP) sont reconstruites à chaque déploiement et n'ont pas besoin de sauvegarde.

### Ce qu'il faut savoir avant de faire confiance à une sauvegarde

- **Le point de restauration est celui de la dernière sauvegarde réussie.** Choisissez la fréquence selon la quantité de données que vous pouvez vous permettre de perdre : une fois par nuit est un bon défaut, toutes les 4 à 6 heures si vous avez besoin de plus.
- **Sauvegardez les deux bases au même moment** (dans la même fenêtre de maintenance), pour que la configuration corresponde aux données.
- **Mode direct :** tout ce qui a été ingéré après la dernière sauvegarde Vertica est perdu, ainsi que les quelques secondes encore en mémoire si le service d'ingestion s'arrête brutalement.
- **Mode Kafka :** les données ingérées après la sauvegarde Vertica sont encore dans Kafka pendant sa durée de rétention (24 h par défaut). La position du loader dans la file est enregistrée *dans* Vertica : après une restauration, il reprend donc automatiquement à la position de la sauvegarde et recharge ce qui est arrivé ensuite. Les données plus anciennes que la rétention Kafka sont perdues.
- **Gardez les sauvegardes hors de la machine.** Trois destinations sont possibles pour Vertica : un stockage objet compatible S3 (recommandé en production), un partage réseau NFS ou un disque local — les sauvegardes locales doivent alors être copiées sur une autre machine, sinon elles ne protègent pas contre la perte du serveur.

### Mettre en place les sauvegardes

**Vertica** se sauvegarde avec `vbr`, l'outil de sauvegarde de Vertica, depuis le serveur Vertica :

```bash
vbr --setupconfig                          # une fois
vbr -t backup -c backup_config.ini         # une sauvegarde (à planifier)
vbr -t listbackup -c backup_config.ini     # lister les sauvegardes
```

Dans la configuration générée, `restorePointLimit` fixe le nombre de sauvegardes conservées (par exemple `14` pour deux semaines de sauvegardes nocturnes).

**PostgreSQL** se sauvegarde avec `pg_dump`. En production, un CronJob Kubernetes (`postgres-backup`) le lance chaque nuit à 02h30 (heure de Paris), vérifie que le fichier n'est pas vide et qu'il est lisible, et garde 7 jours de sauvegardes sur son propre volume. Ce volume est sur le même serveur que la base : copiez aussi ses fichiers sur une autre machine.

{{< callout type="warn" >}}
Assurez-vous que quelqu'un est prévenu quand une sauvegarde échoue ou quand la dernière est trop ancienne (par exemple plus de 26 heures pour une sauvegarde nocturne). Le découvrir pendant un incident, c'est trop tard.
{{< /callout >}}

### Procédure de restauration

1. **Évaluer les dégâts.** Dommage partiel (une table, une période) ou perte totale ? En cas de doute, considérez qu'il s'agit d'une perte totale.
2. **Arrêter tout ce qui écrit :** le service d'ingestion, le loader (mode Kafka) et tous les workers. Dans Kubernetes :

   ```bash
   kubectl -n <namespace> scale deployment apm-ingest apm-loader apm-worker \
     apm-trace-graph-worker apm-canonicalization-worker --replicas=0
   ```

3. **Restaurer PostgreSQL d'abord** — la plateforme en a besoin pour trouver sa base Vertica :

   ```bash
   gunzip -c neurones-<date>.sql.gz | psql -h <hôte> -U <utilisateur> -d <base>
   ```

4. **Restaurer Vertica** à partir de la dernière sauvegarde valide (ou d'une sauvegarde nommée) :

   ```bash
   vbr -t restore -c backup_config.ini --archive <nom-de-la-sauvegarde>
   ```

5. **Vérifier les versions.** Les bases restaurées doivent correspondre à la version de Neurons déployée : la dernière migration Vertica (`SELECT version FROM apm.flyway_schema_history ORDER BY installed_rank DESC LIMIT 1;`) et la migration PostgreSQL (`alembic current` dans le backend). Si la sauvegarde est plus ancienne que la version déployée, lancez les migrations avant de redémarrer.
6. **Valider les données** avant de rouvrir le trafic :

   ```sql
   SELECT MAX(start_time) FROM apm.spans;
   SELECT MAX(start_time) FROM apm.rum_events;
   SELECT worker_name, checkpoint_name, last_bucket_time FROM apm.worker_checkpoints ORDER BY 1, 2;
   ```

   Les heures les plus récentes indiquent exactement où s'arrête la sauvegarde.
7. **Redémarrer** le service d'ingestion, le loader et les workers (`--replicas` remis à leurs valeurs habituelles). Chaque worker reprend à son propre point de reprise. En mode Kafka, suivez le rattrapage du loader sur ce que Kafka contient encore.
8. **Reconstruire** ce qui peut l'être pour la période manquante, si les données brutes existent : la carte des dépendances entre services et le registre des transactions métier.
9. **Communiquer** la période exacte qui manque, pour que personne ne confonde des données absentes avec une période calme.
{.steps}

{{< callout type="warn" >}}
Une sauvegarde qui n'a jamais été restaurée n'est pas une sauvegarde vérifiée. Restaurez les dernières sauvegardes dans un environnement de test chaque mois, et faites un exercice complet et chronométré au moins une fois par an — il vous donne un vrai temps de restauration au lieu d'un temps supposé.
{{< /callout >}}
