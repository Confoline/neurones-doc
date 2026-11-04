---
title: Installer un Collecteur OpenTelemetry et son agent
linkTitle: Collecteur & agent
lede: Raccorder à Neurons un Collecteur OpenTelemetry installé sur un serveur client, pour gérer sa configuration depuis l'interface Neurons et voir son état, sans SSH.
menus:
  onboarding:
    parent: deployment
    weight: 20
labels:
  how: Fonctionnement
  tokens: Les trois jetons
  platform: Prérequis plateforme
  server: Prérequis serveur
  scenario-a: "A : Collecteur existant"
  scenario-b: "B : nouveau serveur"
  change: Modifier la config
  status: Statuts
  troubleshooting: Dépannage
  done: Définition de terminé
---

Neurons gère un Collecteur grâce à un petit **agent** installé à côté de lui. L'agent appelle Neurons toutes les 60 secondes : il indique ce qui tourne sur le serveur et récupère toute nouvelle version de configuration enregistrée. La connexion part toujours **du serveur vers Neurons** (HTTPS sortant) : aucun port entrant, VPN ou accès SSH n'est nécessaire.

## Fonctionnement {#how}

{{< flow label="Qui parle à qui" >}}
server | Collecteur OpenTelemetry | `otelcol` ou `otelcol-contrib`, envoie traces et logs avec le jeton d'ingestion
→ OTLP sur HTTP
platform | Neurons | Conserve chaque version de config, calcule les statuts
→ toutes les 60 s : check-in, santé, nouvelle version (HTTPS, depuis le serveur)
server | Agent du Collecteur | Service `otel-collector-agent` : valide, installe, redémarre, revient en arrière
{{< /flow >}}

| Composant | Où | Rôle |
|---|---|---|
| **Collecteur** | Serveur client | Reçoit la télémétrie des applications et l'exporte vers Neurons. |
| **Agent** | Même serveur, service systemd `otel-collector-agent` | Enregistre le Collecteur, applique les nouvelles versions de config sans risque, remonte la santé. |
| **Neurons** | Plateforme (servi par `apm-query`) | Paramètres → OpenTelemetry Collectors : versions, statuts, édition et revue. |
{firstcol="22"}

Deux façons de démarrer, selon le serveur :

| Situation | À utiliser |
|---|---|
| Un Collecteur tourne déjà sur le serveur | [Scénario A](#scenario-a) : l'agent reprend la config existante. |
| Nouveau serveur, pas encore de Collecteur | [Scénario B](#scenario-b) : vous écrivez d'abord la config dans Neurons. |
{firstcol="34"}

## Les trois jetons {#tokens}

| Jeton | Créé par | Durée de vie | Où il va | Sert à |
|---|---|---|---|---|
| **Jeton d'enregistrement** (`nrt_…`) | Vous : *Add collector* → *Generate token* | 24 h, usage unique, lié à un nom de Collecteur | `REGISTER_TOKEN` dans les paramètres de l'agent | Premier enregistrement d'un Collecteur existant ([A](#scenario-a)) |
| **Jeton d'agent** | Neurons, à l'enregistrement ou à la création du Collecteur ([B](#scenario-b)) | Jusqu'à la suppression du Collecteur | Fichier d'état de l'agent (automatique), ou `AGENT_TOKEN` ([B](#scenario-b)) | Chaque check-in, rapport et heartbeat |
| **Jeton d'ingestion** (`X-Neurones-Token`) | Paramètres de la plateforme | Jusqu'à sa rotation | Config du Collecteur, en-têtes des exporters | Envoyer la télémétrie à Neurons |
{firstcol="20"}

{{< callout >}}
Le jeton d'enregistrement permet seulement à un agent de se présenter **une fois**. Ensuite il ne sert plus, et l'agent utilise son propre jeton d'agent. Le jeton d'ingestion permanent de la plateforme reste ainsi hors des paramètres de l'agent.
{{< /callout >}}

{{< callout type="warn" >}}
Ne laissez pas le jeton d'ingestion ni d'autres identifiants en clair dans le YAML du Collecteur. Utilisez `${env:NEURONES_TOKEN}` dans la config et définissez la variable sur le serveur.
{{< /callout >}}

## Prérequis plateforme {#platform}

Une seule fois par installation de Neurons :

1. **neurones-backend** déployé avec les migrations du Collecteur (tables `otel_collector_config_versions` et `otel_registration_tokens`). Le log du job de migration doit se terminer par la montée vers le dernier head, sans erreur « Multiple head revisions ».
2. **apm-query** déployé avec les endpoints de l'agent et le paquet de l'agent.
3. **Ingress** qui envoie les endpoints de l'agent vers `apm-query` (port 8000), chemins exacts :
   `/api/otel-collectors/agent/current`, `/report`, `/heartbeat`, `/register`, `/package`.

Vérification depuis un serveur client :

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<NEURONS_URL>/api/otel-collectors/agent/current
```

| Résultat | Signification |
|---|---|
| `401` | Route ouverte, jeton absent : correct. |
| `404` | Règle d'ingress manquante : les agents ne peuvent pas joindre Neurons. |
| Timeout | Pare-feu : le HTTPS sortant du serveur vers Neurons est bloqué. |
{firstcol="14"}

## Prérequis serveur {#server}

- Linux avec systemd, accès `sudo`.
- Python 3.6 ou plus récent : `python3 --version`.
- HTTPS sortant vers Neurons (voir la vérification ci-dessus).
- Savoir quelle distribution du Collecteur tourne (ou tournera) :

```bash
systemctl list-units | grep otel
```

| Distribution | Service | Fichier de config |
|---|---|---|
| Core | `otelcol` | `/etc/otelcol/config.yaml` |
| Contrib | `otelcol-contrib` | `/etc/otelcol-contrib/config.yaml` |
{firstcol="18"}

## Scénario A : le client a déjà un Collecteur {#scenario-a}

L'agent enregistre le Collecteur **avec la config qu'il trouve sur le serveur**. Cette config devient la version 1 dans Neurons ; rien n'est modifié ni redémarré.

**1. Dans Neurons :** Paramètres → OpenTelemetry Collectors → *Add collector* → *Install the agent on the server*. Saisissez le nom (`collector-<hostname>`) et l'environnement (`prod`, `stg`…), puis cliquez sur **Generate token**. Copiez le jeton : il n'est affiché qu'une fois.

**2. Sur le serveur, téléchargez et installez l'agent :**

```bash
mkdir -p /tmp/apm-agent && cd /tmp/apm-agent
curl -fsSL https://<NEURONS_URL>/api/otel-collectors/agent/package | tar xz
sudo sh install.sh
```

**3. Sur le serveur, écrivez les paramètres** dans `/etc/default/otel-collector-agent` (la page *Add collector* génère ce bloc pour vous) :

```bash
BACKEND_URL=https://<NEURONS_URL>
REGISTER_TOKEN=nrt_xxxxxxxxxxxxxxxx
COLLECTOR_NAME=collector-<hostname>
COLLECTOR_ENVIRONMENT=stg
COLLECTOR_CONFIG_PATH=/etc/otelcol/config.yaml
RELOAD_COMMAND=systemctl restart otelcol
STATE_FILE=/etc/otelcol/.apm_agent_state.json
```

Pour la distribution contrib, utilisez `/etc/otelcol-contrib/…` et `otelcol-contrib`.

**4. Démarrez l'agent :**

```bash
sudo systemctl enable --now otel-collector-agent
```

**5. Ce qui se passe ensuite :** l'agent lit la config actuelle, l'enregistre (le jeton d'enregistrement est consommé), reçoit son jeton d'agent permanent et commence ses check-ins. La page *Add collector* passe par *Registered* → *First check-in* → *First data*, puis ouvre le Collecteur.

{{< callout >}}
Première modification conseillée : dans *Edit*, ajoutez l'extension `health_check` (nécessaire au retour arrière automatique) et passez les secrets en `${env:…}`, puis enregistrez la version 2.
{{< /callout >}}

## Scénario B : nouveau serveur, config préparée dans Neurons {#scenario-b}

**1. Dans Neurons :** *Add collector* → *Write the config here first*. Partez du modèle Neurons (traces et logs vers Neurons, `health_check`, `memory_limiter`), puis cliquez sur **Create**. Copiez le **jeton d'agent** affiché une seule fois.

**2. Sur le serveur, installez le paquet du Collecteur** (`otelcol` ou `otelcol-contrib`). Il démarre avec sa config par défaut.

**3. Sur le serveur, téléchargez et installez l'agent** comme au [scénario A, étape 2](#scenario-a).

**4. Sur le serveur, écrivez les paramètres** comme au scénario A, mais avec `AGENT_TOKEN` au lieu de `REGISTER_TOKEN` :

```bash
BACKEND_URL=https://<NEURONS_URL>
AGENT_TOKEN=<jeton d'agent de l'étape 1>
COLLECTOR_CONFIG_PATH=/etc/otelcol/config.yaml
RELOAD_COMMAND=systemctl restart otelcol
STATE_FILE=/etc/otelcol/.apm_agent_state.json
```

**5. Démarrez l'agent :** `sudo systemctl enable --now otel-collector-agent`

**6. Ce qui se passe ensuite :** à son premier check-in, l'agent reçoit la version 1, la valide, sauvegarde la config par défaut, installe la version 1, redémarre le Collecteur et attend le health check. Si le Collecteur ne revient pas en bonne santé, la config par défaut est restaurée.

## Modifier la config {#change}

Modifiez toujours la config depuis Neurons, jamais en éditant le fichier sur le serveur : l'agent remplacerait les modifications locales par la version stockée dans Neurons.

1. Ouvrez le Collecteur → *Edit* (onglet Form ou YAML).
2. Cliquez sur **Review changes** : le diff (secrets masqués) et les vérifications s'affichent. Les erreurs de structure bloquent l'enregistrement.
3. Cliquez sur **Save version N**. Le statut passe à *Config pending*.
4. En moins de 60 secondes, l'agent récupère la version, lance `otelcol validate`, sauvegarde la config actuelle, installe la nouvelle, redémarre le Collecteur et attend le health check.
5. Le statut passe à *Config in sync*, ou à *Rolled back* avec la raison. Dans ce cas, la version précédente tourne de nouveau et la version en échec n'est pas retentée.

*Versions* liste chaque modification, avec comparaison et restauration (une restauration crée une nouvelle version). **Re-apply** renvoie la version actuelle.

## Statuts {#status}

| Statut | Valeurs | Signification |
|---|---|---|
| **Agent** | Online · Late · Offline · Never seen | Selon le dernier check-in (en retard après 3 appels manqués, hors ligne après 10). |
| **Config** | In sync · Pending · Failed · Rolled back | Indique si la version qui tourne sur le serveur est la dernière enregistrée dans Neurons. |
| **Données** | Receiving · No recent data · Not tracked | Indique si Neurons a reçu de la télémétrie de ce Collecteur dans les 5 dernières minutes. |
{firstcol="12"}

Le panneau de détail explique chaque statut et l'action à mener.

## Dépannage {#troubleshooting}

| Symptôme | Cause probable | Action |
|---|---|---|
| Agent *Never seen* | Agent non démarré, ou ne joint pas Neurons | `journalctl -u otel-collector-agent -n 50` ; lancez la [vérification plateforme](#platform). |
| `404` sur les endpoints de l'agent | Règle d'ingress manquante | Ajoutez les routes de l'agent à l'ingress ([prérequis plateforme](#platform)). |
| `401` à l'enregistrement | Jeton d'enregistrement faux, déjà utilisé, expiré, ou nom différent | Générez un nouveau jeton ; `COLLECTOR_NAME` doit correspondre au nom saisi dans Neurons. |
| *Generate token* renvoie `405` | Version du backend sans jetons d'enregistrement | Déployez neurones-backend avec les migrations du Collecteur. |
| Job de migration : « Multiple head revisions » | Deux heads Alembic dans l'image du backend | Corrigez la chaîne de migrations (un seul head), reconstruisez et redéployez. |
| *Config pending* persiste | Agent hors ligne ou agent v1 | Vérifiez la version de l'agent dans le panneau de détail ; installez l'agent 2.x. |
| *Rolled back* | La nouvelle version a échoué à la validation ou au health check | Lisez la raison dans le panneau de détail, corrigez dans *Edit*, enregistrez une nouvelle version. |
| *No recent data* | Exporter sans `X-Neurones-Token`, ou config jamais réappliquée depuis la mise à jour | Vérifiez les en-têtes de l'exporter ; cliquez une fois sur **Re-apply**. |

## Définition de terminé {#done}

Un Collecteur est raccordé quand :

- les endpoints de l'agent répondent `401` depuis le serveur (pas `404` ni timeout)
- `otel-collector-agent` est activé et tourne
- le Collecteur affiche **Agent online**, **Config in sync** et **Receiving data**
- la config contient l'extension `health_check`
- aucun identifiant n'est en clair dans le YAML (`${env:…}` à la place)
- une modification de test enregistrée depuis Neurons a été appliquée, sans SSH
