---
title: Set Up an OpenTelemetry Collector and Its Agent
linkTitle: Collector & agent
lede: Connect an OpenTelemetry Collector running on a client server to Neurons, so its configuration is managed from the Neurons UI and its health is visible, without SSH.
menus:
  onboarding:
    parent: deployment
    weight: 20
labels:
  how: How it works
  tokens: The three tokens
  platform: Platform prerequisites
  server: Server prerequisites
  scenario-a: "A: existing collector"
  scenario-b: "B: new server"
  change: Changing the config
  status: Statuses
  troubleshooting: Troubleshooting
  done: Definition of Done
---

A Collector is managed by Neurons through a small **agent** installed next to it. The agent calls Neurons every 60 seconds: it reports what runs on the server and fetches any new configuration version you saved. The connection always goes **from the server to Neurons** (outbound HTTPS), so no inbound port, VPN or SSH access is needed.

## How it works {#how}

{{< flow label="Who talks to whom" >}}
server | OpenTelemetry Collector | `otelcol` or `otelcol-contrib`, sends traces and logs with the ingest token
→ OTLP over HTTP
platform | Neurons | Stores every config version, computes the statuses
→ every 60 s: check-in, health, new version (HTTPS, from the server)
server | Collector agent | `otel-collector-agent` service: validates, installs, restarts, rolls back
{{< /flow >}}

| Component | Where | Role |
|---|---|---|
| **Collector** | Client server | Receives telemetry from the applications and exports it to Neurons. |
| **Agent** | Same server, systemd service `otel-collector-agent` | Registers the Collector, applies new config versions safely, reports health. |
| **Neurons** | Platform (served by `apm-query`) | Settings → OpenTelemetry Collectors: versions, statuses, edit and review. |
{firstcol="22"}

There are two ways to start, depending on the server:

| Situation | Use |
|---|---|
| A Collector already runs on the server | [Scenario A](#scenario-a): the agent adopts the existing config. |
| New server, no Collector yet | [Scenario B](#scenario-b): you write the config in Neurons first. |
{firstcol="34"}

## The three tokens {#tokens}

| Token | Created by | Lifetime | Where it goes | Used for |
|---|---|---|---|---|
| **Registration token** (`nrt_…`) | You: *Add collector* → *Generate token* | 24 h, single use, bound to one collector name | `REGISTER_TOKEN` in the agent settings | First registration of an existing Collector ([A](#scenario-a)) |
| **Agent token** | Neurons, at registration or when you create the Collector ([B](#scenario-b)) | Until the Collector is deleted | Agent state file (automatic), or `AGENT_TOKEN` ([B](#scenario-b)) | Every check-in, report and heartbeat |
| **Ingest token** (`X-Neurones-Token`) | Platform settings | Until rotated | Collector config, exporter headers | Sending telemetry to Neurons |
{firstcol="20"}

{{< callout >}}
The registration token only lets an agent introduce itself **once**. After that it is dead, and the agent uses its own agent token. This keeps the platform's permanent ingest token out of the agent settings.
{{< /callout >}}

{{< callout type="warn" >}}
Do not leave the ingest token or other credentials in clear text in the Collector YAML. Use `${env:NEURONES_TOKEN}` in the config and set the variable on the server.
{{< /callout >}}

## Platform prerequisites {#platform}

Done once per Neurons installation:

1. **neurones-backend** deployed with the Collector migrations (tables `otel_collector_config_versions` and `otel_registration_tokens`). The migration job log must end with the upgrade to the latest head, with no "Multiple head revisions" error.
2. **apm-query** deployed with the agent endpoints and the agent package.
3. **Ingress** routing the agent endpoints to `apm-query` (port 8000), exact paths:
   `/api/otel-collectors/agent/current`, `/report`, `/heartbeat`, `/register`, `/package`.

Check from a client server:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<NEURONS_URL>/api/otel-collectors/agent/current
```

| Result | Meaning |
|---|---|
| `401` | Route open, token missing: correct. |
| `404` | The ingress rule is missing: agents cannot reach Neurons. |
| Timeout | Firewall: outbound HTTPS from the server to Neurons is blocked. |
{firstcol="14"}

## Server prerequisites {#server}

- Linux with systemd, `sudo` access.
- Python 3.6 or later: `python3 --version`.
- Outbound HTTPS to Neurons (see the check above).
- Know which Collector distribution runs (or will run):

```bash
systemctl list-units | grep otel
```

| Distribution | Service | Config file |
|---|---|---|
| Core | `otelcol` | `/etc/otelcol/config.yaml` |
| Contrib | `otelcol-contrib` | `/etc/otelcol-contrib/config.yaml` |
{firstcol="18"}

## Scenario A: the client already runs a Collector {#scenario-a}

The agent registers the Collector **with the config it finds on the server**. That config becomes version 1 in Neurons; nothing is changed or restarted.

**1. In Neurons:** Settings → OpenTelemetry Collectors → *Add collector* → *Install the agent on the server*. Enter the name (`collector-<hostname>`) and the environment (`prod`, `stg`…), then click **Generate token**. Copy the token: it is shown only once.

**2. On the server, download and install the agent:**

```bash
mkdir -p /tmp/apm-agent && cd /tmp/apm-agent
curl -fsSL https://<NEURONS_URL>/api/otel-collectors/agent/package | tar xz
sudo sh install.sh
```

**3. On the server, write the settings** in `/etc/default/otel-collector-agent` (the *Add collector* page generates this block for you):

```bash
BACKEND_URL=https://<NEURONS_URL>
REGISTER_TOKEN=nrt_xxxxxxxxxxxxxxxx
COLLECTOR_NAME=collector-<hostname>
COLLECTOR_ENVIRONMENT=stg
COLLECTOR_CONFIG_PATH=/etc/otelcol/config.yaml
RELOAD_COMMAND=systemctl restart otelcol
STATE_FILE=/etc/otelcol/.apm_agent_state.json
```

For the contrib distribution, use `/etc/otelcol-contrib/…` and `otelcol-contrib`.

**4. Start the agent:**

```bash
sudo systemctl enable --now otel-collector-agent
```

**5. What happens next:** the agent reads the current config, registers it (the registration token is consumed), receives its permanent agent token and starts checking in. The *Add collector* page moves through *Registered* → *First check-in* → *First data* and then opens the Collector.

{{< callout >}}
Recommended first change: in *Edit*, add the `health_check` extension (needed for automatic rollback) and move secrets to `${env:…}`, then save version 2.
{{< /callout >}}

## Scenario B: new server, config prepared in Neurons {#scenario-b}

**1. In Neurons:** *Add collector* → *Write the config here first*. Start from the Neurons template (traces and logs to Neurons, `health_check`, `memory_limiter`), then click **Create**. Copy the **agent token** shown once.

**2. On the server, install the Collector** package (`otelcol` or `otelcol-contrib`). It starts with its default config.

**3. On the server, download and install the agent** as in [scenario A, step 2](#scenario-a).

**4. On the server, write the settings** as in scenario A, but with `AGENT_TOKEN` instead of `REGISTER_TOKEN`:

```bash
BACKEND_URL=https://<NEURONS_URL>
AGENT_TOKEN=<agent token from step 1>
COLLECTOR_CONFIG_PATH=/etc/otelcol/config.yaml
RELOAD_COMMAND=systemctl restart otelcol
STATE_FILE=/etc/otelcol/.apm_agent_state.json
```

**5. Start the agent:** `sudo systemctl enable --now otel-collector-agent`

**6. What happens next:** at its first check-in the agent receives version 1, validates it, backs up the default config, installs version 1, restarts the Collector and waits for the health check. If the Collector does not come back healthy, the default config is restored.

## Changing the config {#change}

Always change the config from Neurons, never by editing the file on the server: the agent would overwrite local edits with the version stored in Neurons.

1. Open the Collector → *Edit* (Form or YAML tab).
2. Click **Review changes**: the diff (secrets masked) and the checks are shown. Structure errors block the save.
3. Click **Save version N**. The status becomes *Config pending*.
4. Within 60 seconds the agent fetches the version, runs `otelcol validate`, backs up the current config, installs the new one, restarts the Collector and waits for the health check.
5. The status becomes *Config in sync*, or *Rolled back* with the reason. In that case the previous version is running again and the failed version is not retried.

*Versions* lists every change with compare and restore (a restore creates a new version). **Re-apply** sends the current version again.

## Statuses {#status}

| Status | Values | Meaning |
|---|---|---|
| **Agent** | Online · Late · Offline · Never seen | Based on the last check-in (late after 3 missed polls, offline after 10). |
| **Config** | In sync · Pending · Failed · Rolled back | Whether the version running on the server is the latest one saved in Neurons. |
| **Data** | Receiving · No recent data · Not tracked | Whether Neurons received telemetry from this Collector in the last 5 minutes. |
{firstcol="12"}

The detail panel explains each status and the next action.

## Troubleshooting {#troubleshooting}

| Symptom | Likely cause | Action |
|---|---|---|
| Agent *Never seen* | Agent not started, or cannot reach Neurons | `journalctl -u otel-collector-agent -n 50`; run the [platform check](#platform). |
| `404` from the agent endpoints | Ingress rule missing | Add the agent routes to the ingress ([platform prerequisites](#platform)). |
| `401` at registration | Registration token wrong, already used, expired, or name mismatch | Generate a new token; `COLLECTOR_NAME` must match the name entered in Neurons. |
| *Generate token* returns `405` | Backend version without registration tokens | Deploy neurones-backend with the Collector migrations. |
| Migration job: "Multiple head revisions" | Two Alembic heads in the backend image | Fix the migration chain (one head), rebuild and redeploy. |
| *Config pending* stays | Agent offline or agent v1 | Check the agent version in the detail panel; install agent 2.x. |
| *Rolled back* | New version failed validation or health check | Read the reason in the detail panel, fix in *Edit*, save a new version. |
| *No recent data* | Exporter without `X-Neurones-Token`, or config never re-applied since the upgrade | Check the exporter headers; click **Re-apply** once. |

## Definition of Done {#done}

A Collector is onboarded when:

- the agent endpoints answer `401` from the server (not `404` or a timeout)
- `otel-collector-agent` is enabled and running
- the Collector shows **Agent online**, **Config in sync** and **Receiving data**
- the config has the `health_check` extension
- no credentials are in clear text in the YAML (`${env:…}` instead)
- a test change saved from Neurons was applied, with no SSH
