---
title: Deploy Neurons on Your Kubernetes Cluster
linkTitle: Kubernetes
lede: Deploy Neurons on your own cluster from the official images provided by Confoline, step by step, up to the first login.
menus:
  onboarding:
    parent: deployment
    weight: 10
labels:
  prerequis: Prerequisites
  fichiers: Deployment files
  namespace: Namespace
  registre: Image access
  vertica: Vertica database
  secrets: Secrets
  postgres: PostgreSQL
  migrations: Database structure
  admin: Administrator
  kafka: Kafka
  applications: Applications
  verifier: Checks
  collecteurs: Collectors
---

This guide deploys **Neurons** on your own server and your own Kubernetes cluster, from the **official images provided by Confoline**. At the end, Neurons is available over HTTPS on your domain, connected to your Vertica database and ready to receive traces from your applications.

{{< callout type="warn" >}}Run **every command in the same terminal**, without closing it: values entered at one step are reused by the next ones. One command per block: copy and run the blocks one at a time.{{< /callout >}}

{{< callout >}}Faster: Confoline can also provide an automatic installer, `installer-neurones.sh`, which performs all these steps by asking a few questions.{{< /callout >}}

## Before you start: what you need {#prerequis}

**Provided by Confoline:** the image registry address and its credentials (read-only), and the **list of images** for your version (backend, frontend, apm-ingest).

**On your side:**

- a machine with **`kubectl`** (cluster administrator), **`vsql`** (the Vertica client), **`openssl`** and **`curl`**;
- a Kubernetes cluster, **version 1.27 or later**, with **ingress-nginx** and a default **StorageClass** (Neurons creates two volumes: 10 Gi for PostgreSQL and 50 Gi for Kafka);
- at least **3.5 CPU cores** and **8 GB** of free memory;
- **no other Strimzi operator** (Kafka) in the cluster: this guide installs its own, version 1.2.0;
- a **Vertica administrator** account (`dbadmin`), and the Vertica port (5433) reachable from your machine and from the cluster nodes;
- the Neurons **domain**, and its **HTTPS certificate** with its private key (PEM files);
- the cluster nodes must reach `quay.io` and `docker.io` over HTTPS, in addition to the Confoline registry (Kafka, PostgreSQL and Redis images).

**Shared cluster:** if port 443 is already used by another application, or if an Ingress of another application already has the annotation `kubernetes.io/ingress.class: nginx`, install a separate ingress-nginx for Neurons, with its own class and a free port. You will give this class and this port at step 10:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace --set controller.service.type=NodePort --set controller.service.nodePorts.https=30443 --set controller.service.nodePorts.http=30080 --set controller.ingressClassResource.name=neurons-nginx --set controller.ingressClassResource.controllerValue=k8s.io/neurons-nginx --set controller.ingressClass=neurons-nginx --set controller.ingressClassResource.default=false --set controller.admissionWebhooks.enabled=false
```

Values to replace are marked **`<TO FILL>`**.

## Step 1 — Download the deployment files {#fichiers}

| File | Content | Step |
|---|---|---|
| [`vertica-migrations.yaml`](../../files/deployment/vertica-migrations.yaml) | creation of the `apm` schema and its tables in Vertica | 4 |
| [`vertica-comptes.sql`](../../files/deployment/vertica-comptes.sql) | the two Neurons Vertica accounts, their privileges and the 4 resource pools | 4 |
| [`postgres.yaml`](../../files/deployment/postgres.yaml) | PostgreSQL | 6 |
| [`migrations.yaml`](../../files/deployment/migrations.yaml) | creation of the PostgreSQL tables | 7 |
| [`strimzi.yaml`](../../files/deployment/strimzi.yaml) | the Kafka operator (Strimzi 1.2.0) | 9 |
| [`kafka.yaml`](../../files/deployment/kafka.yaml) | the Kafka cluster and its 2 topics | 9 |
| [`applications.yaml`](../../files/deployment/applications.yaml) | the 13 applications, their web routes and their autoscalers | 10 |
{mono="1"}

They contain no password: only placeholders (`__DOMAINE__`…) that are automatically replaced with your values at deployment time. Click a file name to view it; the command below downloads all of them to the server.

Create a working directory:

```bash
mkdir neurons-deploiement && cd neurons-deploiement
```

Download the 7 files:

```bash
for f in vertica-migrations.yaml vertica-comptes.sql postgres.yaml migrations.yaml strimzi.yaml kafka.yaml applications.yaml; do curl -fsSLO "https://docs.confoline.com/neurons/files/deployment/$f"; done
```

Check that they are there:

```bash
ls
```

Expected: `applications.yaml  kafka.yaml  migrations.yaml  postgres.yaml  strimzi.yaml  vertica-comptes.sql  vertica-migrations.yaml`

## Step 2 — Create the Neurons namespace {#namespace}

All of Neurons will live in this namespace. Keep the name `neurons`: the deployment files use it.

```bash
kubectl create namespace neurons
```

## Step 3 — Give the cluster access to the images {#registre}

This secret is used to download the images, at installation and on every restart: it **stays** in the cluster. Replace the three values with those provided by Confoline:

```bash
kubectl -n neurons create secret docker-registry neurones-registry --docker-server='<TO FILL: registry>' --docker-username='<TO FILL: username>' --docker-password='<TO FILL: password>'
```

The three Neurons images, from the Confoline list:

```bash
export IMAGE_BACKEND='<TO FILL: backend image>'
```

```bash
export IMAGE_FRONTEND='<TO FILL: frontend image>'
```

```bash
export IMAGE_APM='<TO FILL: apm-ingest image>'
```

## Step 4 — Prepare the Vertica database {#vertica}

### Your Vertica values

```bash
export VERTICA_HOST='<TO FILL: Vertica server>'
```

```bash
export VERTICA_DB='<TO FILL: Vertica database name>'
```

The passwords of the two accounts Neurons will use (nothing is displayed while typing). Avoid the characters `'`, `$`, `\` and the backtick in these passwords: they would break the following commands.

```bash
read -rs -p "Password to create for neurones_reader: " LECTEUR_MDP; echo
```

```bash
read -rs -p "Password to create for neurones_writer: " ECRIVAIN_MDP; echo
```

### Create the apm schema and its tables

The tables are created by the migration tool of the apm-ingest image, the same one as in production. It keeps a history (`apm.flyway_schema_history`), so later versions of Neurons only add what is missing.

The tool connects with `dbadmin`. Its password goes into a temporary secret, deleted at the end of this step:

```bash
read -rs -p "dbadmin password: " DBADMIN_MDP; echo
```

```bash
kubectl -n neurons create secret generic vertica-admin --from-literal=VERTICA_ADMIN_PASSWORD="$DBADMIN_MDP"
```

Run the migrations:

```bash
sed -e "s|__IMAGE_APM__|$IMAGE_APM|" -e "s|__VERTICA_HOST__|$VERTICA_HOST|" -e "s|__VERTICA_DB__|$VERTICA_DB|" vertica-migrations.yaml | kubectl -n neurons apply -f -
```

Wait until they finish (a few minutes):

```bash
kubectl -n neurons wait --for=condition=complete job/neurones-vertica-migrations --timeout=1800s
```

Check:

```bash
kubectl -n neurons logs job/neurones-vertica-migrations | tail -5
```

Expected: the applied migrations, and no `ERROR` line.

Delete the temporary secret:

```bash
kubectl -n neurons delete secret vertica-admin
```

### Create the two accounts and the resource pools

A **reader** account and a **writer** account: Neurons never uses `dbadmin`. The same file creates the 4 resource pools, which reserve part of the Vertica memory for Neurons. The `dbadmin` password is requested on each `vsql` command.

```bash
vsql -h "$VERTICA_HOST" -d "$VERTICA_DB" -U dbadmin -v lecteur_mdp="'$LECTEUR_MDP'" -v ecrivain_mdp="'$ECRIVAIN_MDP'" -f vertica-comptes.sql
```

If a pool already exists, Vertica answers `already exists` for that pool: it is kept as it is.

### Check

```bash
vsql -h "$VERTICA_HOST" -d "$VERTICA_DB" -U dbadmin -c "SELECT version FROM apm.flyway_schema_history WHERE success ORDER BY installed_rank DESC LIMIT 1;"
```

Expected: the number of the last migration.

```bash
vsql -h "$VERTICA_HOST" -d "$VERTICA_DB" -U dbadmin -c "SELECT name FROM v_catalog.resource_pools WHERE name LIKE 'apm%';"
```

Expected: `apm_core_pool`, `apm_loader_pool`, `apm_query_pool`, `apm_worker_pool`.

## Step 5 — Create the application secrets {#secrets}

### Automatically generated values

The PostgreSQL password:

```bash
export POSTGRES_MDP=$(openssl rand -hex 16)
```

The ingestion token, which protects trace reception:

```bash
export JETON=$(openssl rand -hex 32)
```

### The HTTPS certificate of your domain

Give the **path of the file** (for example `/root/neurons.crt`), not its contents.

```bash
export CERTIFICAT='<TO FILL: certificate path, e.g. /root/neurons.crt>'
```

```bash
export CLE='<TO FILL: private key path, e.g. /root/neurons.key>'
```

### Create the 5 secrets

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

## Step 6 — Deploy PostgreSQL {#postgres}

```bash
kubectl -n neurons apply -f postgres.yaml
```

Wait until it is ready. On slow storage (NFS), the first start can take several minutes:

```bash
kubectl -n neurons rollout status statefulset/postgres --timeout=900s
```

## Step 7 — Create the PostgreSQL database structure {#migrations}

```bash
sed -e "s|__IMAGE_BACKEND__|$IMAGE_BACKEND|" -e "s|__VERTICA_HOST__|$VERTICA_HOST|" -e "s|__VERTICA_DB__|$VERTICA_DB|" migrations.yaml | kubectl -n neurons apply -f -
```

Wait until they finish:

```bash
kubectl -n neurons wait --for=condition=complete job/neurones-migrations --timeout=600s
```

Check:

```bash
kubectl -n neurons logs job/neurones-migrations | tail -2
```

Expected: the last line shows the latest migration (`... -> a3d5f7b9c1e2` with the current images).

## Step 8 — Create the administrator and the Vertica connection {#admin}

{{< callout type="warn" >}}Do this **before** step 10: otherwise the application creates an incomplete Vertica connection by itself, and trace reception will not be able to write.{{< /callout >}}

### The first Neurons administrator

```bash
export ADMIN_EMAIL='<TO FILL: administrator email>'
```

Use a validly formed email address: reserved domains (`.test`, `.local`, `.invalid`) are accepted when stored, but **rejected at login**.

```bash
read -rs -p "Neurons administrator password: " ADMIN_MDP; echo
```

Same rule: no `'`, `$`, `\` or backtick in this password.

### Store them in PostgreSQL

Copy this block **as a whole**: it is a single call to PostgreSQL.

```bash
kubectl -n neurons exec -i postgres-0 -- psql -U postgres -d neurones -v ON_ERROR_STOP=1 <<EOF
CREATE EXTENSION IF NOT EXISTS pgcrypto;
INSERT INTO users (id, email, hashed_password, is_active, is_admin) VALUES (gen_random_uuid(), '$ADMIN_EMAIL', crypt('$ADMIN_MDP', gen_salt('bf', 12)), true, true);
INSERT INTO databases_config (name, db_type, host, port, username, password, database, is_active) VALUES ('neurones', 'postgresql', 'postgres', 5432, 'postgres', '$POSTGRES_MDP', 'neurones', true);
INSERT INTO databases_config (name, db_type, host, port, username, password, database, reader_username, reader_password, writer_username, writer_password, is_active) VALUES ('$VERTICA_DB', 'vertica', '$VERTICA_HOST', 5433, 'neurones_reader', '$LECTEUR_MDP', '$VERTICA_DB', 'neurones_reader', '$LECTEUR_MDP', 'neurones_writer', '$ECRIVAIN_MDP', true);
EOF
```

Expected: `CREATE EXTENSION`, then `INSERT 0 1` three times.

## Step 9 — Deploy Kafka {#kafka}

Trace reception places every request in Kafka, and the loaders write it to Vertica. Kafka keeps 24 hours of data: nothing is lost if Vertica slows down. It must be ready before the applications.

### The Kafka operator

Strimzi manages Kafka in Kubernetes. It is installed in the `neurons` namespace and watches only that namespace.

```bash
kubectl apply --server-side -f strimzi.yaml
```

```bash
kubectl -n neurons rollout status deployment/strimzi-cluster-operator --timeout=300s
```

### The Kafka cluster and its topics

```bash
kubectl -n neurons apply -f kafka.yaml
```

Wait until Kafka is ready (a few minutes, the time to create its volume):

```bash
kubectl -n neurons wait kafka/neurons-kafka --for=condition=Ready --timeout=600s
```

```bash
kubectl -n neurons wait kafkatopic --all --for=condition=Ready --timeout=180s
```

Expected: `neurons-kafka condition met`, then the two topics `otlp.traces.raw` and `otlp.logs.raw`.

## Step 10 — Deploy the Neurons applications {#applications}

### Your domain and its web access

```bash
export DOMAINE='<TO FILL: domain, e.g. neurons.your-domain.com>'
```

The IngressClass of your ingress-nginx (`nginx` in most cases, `neurons-nginx` with the separate controller of the prerequisites):

```bash
export INGRESS_CLASS='nginx'
```

Its HTTPS port (`443`, or `30443` with the separate controller):

```bash
export HTTPS_PORT='443'
```

The Neurons address, built from these values:

```bash
if [ "$HTTPS_PORT" = 443 ]; then export ADRESSE="https://$DOMAINE"; else export ADRESSE="https://$DOMAINE:$HTTPS_PORT"; fi; echo "$ADRESSE"
```

### Deploy

```bash
sed -e "s|__DOMAINE__|$DOMAINE|g" -e "s|__ADRESSE__|$ADRESSE|g" -e "s|__INGRESS_CLASS__|$INGRESS_CLASS|g" -e "s|__VERTICA_HOST__|$VERTICA_HOST|g" -e "s|__VERTICA_DB__|$VERTICA_DB|g" -e "s|__IMAGE_BACKEND__|$IMAGE_BACKEND|g" -e "s|__IMAGE_FRONTEND__|$IMAGE_FRONTEND|g" -e "s|__IMAGE_APM__|$IMAGE_APM|g" applications.yaml | kubectl -n neurons apply -f -
```

Wait until the applications are ready:

```bash
kubectl -n neurons wait --for=condition=available deployment --all --timeout=600s
```

Each application starts with **1 pod**. The autoscalers add pods when CPU usage goes above 70 %: apm-ingest up to 4, apm-query, backend and frontend up to 3.

## Step 11 — Check that Neurons is running {#verifier}

The pods:

```bash
kubectl -n neurons get pods
```

Expected in `Running`: the 13 applications (`apm-ingest`, `apm-query`, `apm-loader`, `apm-worker`, `apm-worker-families`, `apm-trace-graph-worker`, `apm-canonicalization-worker`, `platform-health-checker`, `neurons-automation`, `neurones-backend`, `neurones-backend-jobs`, `neurones-frontend`, `neurones-redis`), `postgres-0`, and the Kafka pods (`neurons-kafka-dual-role-0`, `neurons-kafka-entity-operator`, `strimzi-cluster-operator`). The two migration jobs are `Completed`.

The web routes:

```bash
kubectl -n neurons get ingress
```

Expected: the 6 routes, on your domain and your IngressClass.

If one of the following checks returns `503` or `404`, the routes are not active yet: wait a minute, then run it again.

The home page:

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' "$ADRESSE/"
```

Expected: `200`.

The administration API, without logging in:

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' "$ADRESSE/api/admin/databases/connected"
```

Expected: `401` (closed).

Trace reception, without a token:

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' -X POST "$ADRESSE/v1/traces"
```

Expected: `401` (closed).

Finally, open the Neurons address (`echo "$ADRESSE"`) and log in with the administrator from step 8.

## Step 12 — Connect the OpenTelemetry collectors {#collecteurs}

The ingestion token (keep it secret):

```bash
echo "$JETON"
```

Add this exporter to your collectors' configuration, then restart them. The endpoint is the Neurons address (with its port if it is not 443):

```yaml
exporters:
  otlphttp/neurones:
    endpoint: https://<your domain>
    encoding: json                 # required: Neurons only reads JSON
    compression: none              # required: Neurons does not read gzip (the collector's default)
    headers:
      X-Neurones-Token: <ingestion token>
```

To find the token again later, from another terminal:

```bash
kubectl -n neurons get secret apm-secret -o jsonpath='{.data.NEURONES_INGEST_TOKEN}' | base64 -d; echo
```
