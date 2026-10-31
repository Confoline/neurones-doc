---
title: Déployer Neurons sur votre cluster Kubernetes
linkTitle: Kubernetes
lede: Déployer Neurons sur votre propre cluster à partir des images officielles fournies par Confoline, étape par étape, jusqu'à la première connexion.
menus:
  onboarding:
    parent: deployment
    weight: 10
labels:
  prerequis: Prérequis
  fichiers: Fichiers de déploiement
  namespace: Namespace
  registre: Accès aux images
  vertica: Base Vertica
  secrets: Secrets
  postgres: PostgreSQL
  migrations: Structure de la base
  admin: Administrateur
  kafka: Kafka
  applications: Applications
  verifier: Vérifications
  collecteurs: Collecteurs
---

Ce guide permet de déployer **Neurons** sur votre propre serveur et votre propre cluster Kubernetes, à partir des **images officielles fournies par Confoline**. À la fin, Neurons est accessible en HTTPS sur votre domaine, relié à votre base Vertica et prêt à recevoir les traces de vos applications.

{{< callout type="warn" >}}Lancez **toutes les commandes dans le même terminal**, sans le fermer : les valeurs saisies à une étape sont réutilisées aux suivantes. Une commande par bloc : copiez et lancez les blocs un par un.{{< /callout >}}

{{< callout >}}Plus rapide : Confoline peut aussi vous fournir un installateur automatique, `installer-neurones.sh`, qui réalise toutes ces étapes en posant quelques questions.{{< /callout >}}

## Avant de commencer : ce qu'il vous faut {#prerequis}

**Fourni par Confoline :** l'adresse du registre d'images et son identifiant (lecture seule), et la **liste des images** de votre version (backend, frontend, apm-ingest).

**De votre côté :**

- une machine avec **`kubectl`** (administrateur du cluster), **`vsql`** (le client Vertica), **`openssl`** et **`curl`** ;
- un cluster Kubernetes **1.27 ou plus récent**, avec **ingress-nginx** et une **StorageClass** par défaut (Neurons crée deux volumes : 10 Go pour PostgreSQL et 50 Go pour Kafka) ;
- au moins **3,5 cœurs** et **8 Go** de mémoire libres ;
- **aucun autre opérateur Strimzi** (Kafka) dans le cluster : ce guide installe le sien, en version 1.2.0 ;
- un compte **administrateur Vertica** (`dbadmin`), et le port de Vertica (5433) joignable depuis votre machine et depuis les nœuds du cluster ;
- le **domaine** de Neurons, et son **certificat HTTPS** avec sa clé privée (fichiers PEM) ;
- les nœuds du cluster doivent joindre `quay.io` et `docker.io` en HTTPS, en plus du registre de Confoline (images de Kafka, PostgreSQL et Redis).

**Cluster partagé :** si le port 443 est déjà pris par une autre application, ou si un Ingress d'une autre application porte déjà l'annotation `kubernetes.io/ingress.class: nginx`, installez un ingress-nginx à part pour Neurons, avec sa propre classe et un port libre. Vous donnerez cette classe et ce port à l'étape 10 :

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace --set controller.service.type=NodePort --set controller.service.nodePorts.https=30443 --set controller.service.nodePorts.http=30080 --set controller.ingressClassResource.name=neurons-nginx --set controller.ingressClassResource.controllerValue=k8s.io/neurons-nginx --set controller.ingressClass=neurons-nginx --set controller.ingressClassResource.default=false --set controller.admissionWebhooks.enabled=false
```

Les valeurs à remplacer sont marquées **`<À REMPLIR>`**.

## Étape 1 — On télécharge les fichiers de déploiement {#fichiers}

| Fichier | Contenu | Étape |
|---|---|---|
| [`vertica-migrations.yaml`](../../files/deployment/vertica-migrations.yaml) | création du schéma `apm` et de ses tables dans Vertica | 4 |
| [`vertica-comptes.sql`](../../files/deployment/vertica-comptes.sql) | les deux comptes Vertica de Neurons, leurs droits et les 4 pools de ressources | 4 |
| [`postgres.yaml`](../../files/deployment/postgres.yaml) | PostgreSQL | 6 |
| [`migrations.yaml`](../../files/deployment/migrations.yaml) | création des tables PostgreSQL | 7 |
| [`strimzi.yaml`](../../files/deployment/strimzi.yaml) | l'opérateur Kafka (Strimzi 1.2.0) | 9 |
| [`kafka.yaml`](../../files/deployment/kafka.yaml) | le cluster Kafka et ses 2 topics | 9 |
| [`applications.yaml`](../../files/deployment/applications.yaml) | les 13 applications, leurs routes web et leurs autoscalers | 10 |
{mono="1"}

Ils ne contiennent aucun mot de passe : seulement des repères (`__DOMAINE__`…) remplacés automatiquement par vos valeurs au moment du déploiement. Cliquez sur un nom de fichier pour le consulter ; la commande ci-dessous les télécharge tous sur le serveur.

On crée un dossier de travail :

```bash
mkdir neurons-deploiement && cd neurons-deploiement
```

On télécharge les 7 fichiers :

```bash
for f in vertica-migrations.yaml vertica-comptes.sql postgres.yaml migrations.yaml strimzi.yaml kafka.yaml applications.yaml; do curl -fsSLO "https://docs.confoline.com/neurons/files/deployment/$f"; done
```

On vérifie qu'ils sont là :

```bash
ls
```

Attendu : `applications.yaml  kafka.yaml  migrations.yaml  postgres.yaml  strimzi.yaml  vertica-comptes.sql  vertica-migrations.yaml`

## Étape 2 — On crée le namespace de Neurons {#namespace}

Tout Neurons vivra dans ce namespace. Gardez le nom `neurons` : les fichiers de déploiement l'utilisent.

```bash
kubectl create namespace neurons
```

## Étape 3 — On donne au cluster l'accès aux images {#registre}

Ce secret sert à télécharger les images, à l'installation et à chaque redémarrage : il **reste** dans le cluster. Remplacez les trois valeurs par celles fournies par Confoline :

```bash
kubectl -n neurons create secret docker-registry neurones-registry --docker-server='<À REMPLIR : registre>' --docker-username='<À REMPLIR : identifiant>' --docker-password='<À REMPLIR : mot de passe>'
```

Les trois images de Neurons, d'après la liste de Confoline :

```bash
export IMAGE_BACKEND='<À REMPLIR : image du backend>'
```

```bash
export IMAGE_FRONTEND='<À REMPLIR : image du frontend>'
```

```bash
export IMAGE_APM='<À REMPLIR : image apm-ingest>'
```

## Étape 4 — On prépare la base Vertica {#vertica}

### Les valeurs de votre Vertica

```bash
export VERTICA_HOST='<À REMPLIR : serveur Vertica>'
```

```bash
export VERTICA_DB='<À REMPLIR : nom de la base Vertica>'
```

Les mots de passe des deux comptes que Neurons va utiliser (rien ne s'affiche pendant la saisie). Évitez les caractères `'`, `$`, `\` et l'apostrophe inversée dans ces mots de passe : ils casseraient les commandes suivantes.

```bash
read -rs -p "Mot de passe a creer pour neurones_reader : " LECTEUR_MDP; echo
```

```bash
read -rs -p "Mot de passe a creer pour neurones_writer : " ECRIVAIN_MDP; echo
```

### On crée le schéma apm et ses tables

Les tables sont créées par l'outil de migration de l'image apm-ingest, le même qu'en production. Il garde un historique (`apm.flyway_schema_history`) : les versions suivantes de Neurons n'ajouteront que ce qui manque.

L'outil se connecte avec `dbadmin`. Son mot de passe va dans un secret provisoire, supprimé à la fin de cette étape :

```bash
read -rs -p "Mot de passe de dbadmin : " DBADMIN_MDP; echo
```

```bash
kubectl -n neurons create secret generic vertica-admin --from-literal=VERTICA_ADMIN_PASSWORD="$DBADMIN_MDP"
```

On lance les migrations :

```bash
sed -e "s|__IMAGE_APM__|$IMAGE_APM|" -e "s|__VERTICA_HOST__|$VERTICA_HOST|" -e "s|__VERTICA_DB__|$VERTICA_DB|" vertica-migrations.yaml | kubectl -n neurons apply -f -
```

On attend qu'elles se terminent (quelques minutes) :

```bash
kubectl -n neurons wait --for=condition=complete job/neurones-vertica-migrations --timeout=1800s
```

On vérifie :

```bash
kubectl -n neurons logs job/neurones-vertica-migrations | tail -5
```

Attendu : les migrations appliquées, et aucune ligne `ERROR`.

On supprime le secret provisoire :

```bash
kubectl -n neurons delete secret vertica-admin
```

### On crée les deux comptes et les pools de ressources

Un compte **lecteur** et un compte **écrivain** : Neurons n'utilise jamais `dbadmin`. Le même fichier crée les 4 pools de ressources, qui réservent une part de la mémoire de Vertica à Neurons. Le mot de passe de `dbadmin` est demandé à chaque commande `vsql`.

```bash
vsql -h "$VERTICA_HOST" -d "$VERTICA_DB" -U dbadmin -v lecteur_mdp="'$LECTEUR_MDP'" -v ecrivain_mdp="'$ECRIVAIN_MDP'" -f vertica-comptes.sql
```

Si un pool existe déjà, Vertica répond `already exists` pour ce pool : il est gardé tel quel.

### On vérifie

```bash
vsql -h "$VERTICA_HOST" -d "$VERTICA_DB" -U dbadmin -c "SELECT version FROM apm.flyway_schema_history WHERE success ORDER BY installed_rank DESC LIMIT 1;"
```

Attendu : le numéro de la dernière migration.

```bash
vsql -h "$VERTICA_HOST" -d "$VERTICA_DB" -U dbadmin -c "SELECT name FROM v_catalog.resource_pools WHERE name LIKE 'apm%';"
```

Attendu : `apm_core_pool`, `apm_loader_pool`, `apm_query_pool`, `apm_worker_pool`.

## Étape 5 — On crée les secrets des applications {#secrets}

### Les valeurs générées automatiquement

Le mot de passe de PostgreSQL :

```bash
export POSTGRES_MDP=$(openssl rand -hex 16)
```

Le jeton d'ingestion, qui protège la réception des traces :

```bash
export JETON=$(openssl rand -hex 32)
```

### Le certificat HTTPS de votre domaine

Donnez le **chemin du fichier** (par exemple `/root/neurons.crt`), pas son contenu.

```bash
export CERTIFICAT='<À REMPLIR : chemin du certificat, ex. /root/neurons.crt>'
```

```bash
export CLE='<À REMPLIR : chemin de la clé privée, ex. /root/neurons.key>'
```

### On crée les 5 secrets

```bash
kubectl -n neurons create secret generic postgres-secret --from-literal=POSTGRES_DB=neurones --from-literal=POSTGRES_USER=postgres --from-literal=POSTGRES_PASSWORD="$POSTGRES_MDP"
```

```bash
kubectl -n neurons create secret generic apm-secret --from-literal=VERTICA_PASSWORD="$ECRIVAIN_MDP" --from-literal=NEURONES_INGEST_TOKEN="$JETON" --from-literal=APM_ALERT_EMAIL_PASSWORD=''
```

```bash
kubectl -n neurons create secret generic neurones-backend-secret --from-literal=SECRET_KEY="$(openssl rand -hex 32)" --from-literal=CMDB_SECRET_KEYS="$(openssl rand -base64 32 | tr '+/' '-_')" --from-literal=VERTICA_PASSWORD="$LECTEUR_MDP"
```

```bash
kubectl -n neurons create secret generic neurones-frontend-secret --from-literal=APM_TOKEN="$JETON" --from-literal=GEMINI_API_KEY=''
```

```bash
kubectl -n neurons create secret tls neurones-tls --cert="$CERTIFICAT" --key="$CLE"
```

## Étape 6 — On déploie PostgreSQL {#postgres}

```bash
kubectl -n neurons apply -f postgres.yaml
```

On attend qu'il soit prêt. Sur un stockage lent (NFS), le premier démarrage peut prendre plusieurs minutes :

```bash
kubectl -n neurons rollout status statefulset/postgres --timeout=900s
```

## Étape 7 — On crée la structure de la base PostgreSQL {#migrations}

```bash
sed -e "s|__IMAGE_BACKEND__|$IMAGE_BACKEND|" -e "s|__VERTICA_HOST__|$VERTICA_HOST|" -e "s|__VERTICA_DB__|$VERTICA_DB|" migrations.yaml | kubectl -n neurons apply -f -
```

On attend qu'elles se terminent :

```bash
kubectl -n neurons wait --for=condition=complete job/neurones-migrations --timeout=600s
```

On vérifie :

```bash
kubectl -n neurons logs job/neurones-migrations | tail -2
```

Attendu : la dernière ligne indique la dernière migration (`... -> a3d5f7b9c1e2` avec les images actuelles).

## Étape 8 — On crée l'administrateur et la connexion à Vertica {#admin}

{{< callout type="warn" >}}À faire **avant** l'étape 10 : sinon l'application crée d'elle-même une connexion Vertica incomplète, et la réception des traces ne pourra pas écrire.{{< /callout >}}

### Le premier administrateur de Neurons

```bash
export ADMIN_EMAIL='<À REMPLIR : e-mail de l administrateur>'
```

Utilisez une adresse e-mail valide : les domaines réservés (`.test`, `.local`, `.invalid`) sont acceptés à l'enregistrement, mais **refusés à la connexion**.

```bash
read -rs -p "Mot de passe de l'administrateur de Neurons : " ADMIN_MDP; echo
```

Même règle : pas de `'`, `$`, `\` ni d'apostrophe inversée dans ce mot de passe.

### On les enregistre dans PostgreSQL

Copiez ce bloc **en entier** : c'est un seul appel à PostgreSQL.

```bash
kubectl -n neurons exec -i postgres-0 -- psql -U postgres -d neurones -v ON_ERROR_STOP=1 <<EOF
CREATE EXTENSION IF NOT EXISTS pgcrypto;
INSERT INTO users (id, email, hashed_password, is_active, is_admin) VALUES (gen_random_uuid(), '$ADMIN_EMAIL', crypt('$ADMIN_MDP', gen_salt('bf', 12)), true, true);
INSERT INTO databases_config (name, db_type, host, port, username, password, database, is_active) VALUES ('neurones', 'postgresql', 'postgres', 5432, 'postgres', '$POSTGRES_MDP', 'neurones', true);
INSERT INTO databases_config (name, db_type, host, port, username, password, database, reader_username, reader_password, writer_username, writer_password, is_active) VALUES ('$VERTICA_DB', 'vertica', '$VERTICA_HOST', 5433, 'neurones_reader', '$LECTEUR_MDP', '$VERTICA_DB', 'neurones_reader', '$LECTEUR_MDP', 'neurones_writer', '$ECRIVAIN_MDP', true);
EOF
```

Attendu : `CREATE EXTENSION`, puis trois fois `INSERT 0 1`.

## Étape 9 — On déploie Kafka {#kafka}

La réception des traces dépose chaque requête dans Kafka, et les loaders l'écrivent dans Vertica. Kafka garde 24 heures de données : rien n'est perdu si Vertica ralentit. Il doit être prêt avant les applications.

### L'opérateur Kafka

Strimzi gère Kafka dans Kubernetes. Il est installé dans le namespace `neurons` et ne surveille que lui.

```bash
kubectl apply --server-side -f strimzi.yaml
```

```bash
kubectl -n neurons rollout status deployment/strimzi-cluster-operator --timeout=300s
```

### Le cluster Kafka et ses topics

```bash
kubectl -n neurons apply -f kafka.yaml
```

On attend que Kafka soit prêt (quelques minutes, le temps de créer son volume) :

```bash
kubectl -n neurons wait kafka/neurons-kafka --for=condition=Ready --timeout=600s
```

```bash
kubectl -n neurons wait kafkatopic --all --for=condition=Ready --timeout=180s
```

Attendu : `neurons-kafka condition met`, puis les deux topics `otlp.traces.raw` et `otlp.logs.raw`.

## Étape 10 — On déploie les applications de Neurons {#applications}

### Votre domaine et son accès web

```bash
export DOMAINE='<À REMPLIR : domaine, ex. neurons.votre-domaine.com>'
```

L'IngressClass de votre ingress-nginx (`nginx` dans la plupart des cas, `neurons-nginx` avec le contrôleur à part des prérequis) :

```bash
export INGRESS_CLASS='nginx'
```

Son port HTTPS (`443`, ou `30443` avec le contrôleur à part) :

```bash
export HTTPS_PORT='443'
```

L'adresse de Neurons, construite à partir de ces valeurs :

```bash
if [ "$HTTPS_PORT" = 443 ]; then export ADRESSE="https://$DOMAINE"; else export ADRESSE="https://$DOMAINE:$HTTPS_PORT"; fi; echo "$ADRESSE"
```

### On déploie

```bash
sed -e "s|__DOMAINE__|$DOMAINE|g" -e "s|__ADRESSE__|$ADRESSE|g" -e "s|__INGRESS_CLASS__|$INGRESS_CLASS|g" -e "s|__VERTICA_HOST__|$VERTICA_HOST|g" -e "s|__VERTICA_DB__|$VERTICA_DB|g" -e "s|__IMAGE_BACKEND__|$IMAGE_BACKEND|g" -e "s|__IMAGE_FRONTEND__|$IMAGE_FRONTEND|g" -e "s|__IMAGE_APM__|$IMAGE_APM|g" applications.yaml | kubectl -n neurons apply -f -
```

On attend que les applications soient prêtes :

```bash
kubectl -n neurons wait --for=condition=available deployment --all --timeout=600s
```

Chaque application démarre avec **1 pod**. Les autoscalers ajoutent des pods quand l'usage du CPU dépasse 70 % : apm-ingest jusqu'à 4, apm-query, backend et frontend jusqu'à 3.

## Étape 11 — On vérifie que Neurons tourne {#verifier}

Les pods :

```bash
kubectl -n neurons get pods
```

Attendu en `Running` : les 13 applications (`apm-ingest`, `apm-query`, `apm-loader`, `apm-worker`, `apm-worker-families`, `apm-trace-graph-worker`, `apm-canonicalization-worker`, `platform-health-checker`, `neurons-automation`, `neurones-backend`, `neurones-backend-jobs`, `neurones-frontend`, `neurones-redis`), `postgres-0`, et les pods de Kafka (`neurons-kafka-dual-role-0`, `neurons-kafka-entity-operator`, `strimzi-cluster-operator`). Les deux jobs de migration sont `Completed`.

Les routes web :

```bash
kubectl -n neurons get ingress
```

Attendu : les 6 routes, sur votre domaine et votre IngressClass.

Si l'une des vérifications suivantes renvoie `503` ou `404`, les routes ne sont pas encore actives : attendez une minute, puis relancez-la.

La page d'accueil :

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' "$ADRESSE/"
```

Attendu : `200`.

L'API d'administration, sans connexion :

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' "$ADRESSE/api/admin/databases/connected"
```

Attendu : `401` (fermée).

La réception des traces, sans jeton :

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' -X POST "$ADRESSE/v1/traces"
```

Attendu : `401` (fermée).

Enfin, ouvrez l'adresse de Neurons (`echo "$ADRESSE"`) et connectez-vous avec l'administrateur de l'étape 8.

## Étape 12 — On relie les collecteurs OpenTelemetry {#collecteurs}

Le jeton d'ingestion (à garder secret) :

```bash
echo "$JETON"
```

Ajoutez cet exportateur à la configuration de vos collecteurs, puis redémarrez-les. L'endpoint est l'adresse de Neurons (avec son port s'il n'est pas 443) :

```yaml
exporters:
  otlphttp/neurones:
    endpoint: https://<votre domaine>
    encoding: json                 # obligatoire : Neurons ne lit que le JSON
    compression: none              # obligatoire : Neurons ne lit pas le gzip (défaut du collecteur)
    headers:
      X-Neurones-Token: <jeton d'ingestion>
```

Pour retrouver le jeton plus tard, depuis un autre terminal :

```bash
kubectl -n neurons get secret apm-secret -o jsonpath='{.data.NEURONES_INGEST_TOKEN}' | base64 -d; echo
```
