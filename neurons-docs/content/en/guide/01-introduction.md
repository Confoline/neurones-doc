---
title: Introduction
part: intro
weight: 1
labels:
  flow: How data arrives
---

## What is Neurons? {#quest}

Neurons is an Application Performance Monitoring (APM) platform. It automatically collects the traces, logs, and performance measurements emitted by your applications, stores them in a single data warehouse, and turns them into actionable dashboards: service health, business transactions, end-user experience, and alerts.

The goal is to answer three questions that any team running an application asks constantly: is everything working normally right now, what changed when a problem appeared, and how far back can I go to understand a past incident.

## How data arrives in the platform {#flow}

Neurons receives two kinds of telemetry, through two entrances: the **backend** (your applications and services, instrumented with OpenTelemetry) and the **browsers** of the people using your websites (Browser RUM). Both end up in the same data warehouse.

### From your applications

{{< flow label="How backend telemetry reaches Neurons" >}}
app | Your application | OpenTelemetry SDK or agent: traces and logs
→ OTLP
platform | Neurons OpenTelemetry Collector | Groups the data, retries when needed, adds the ingestion token
→ OTLP over HTTPS
platform | Ingestion service | Checks the token, standardizes field names, tags browser data
→ directly, or through a Kafka queue (see below)
platform | Data warehouse (Vertica) | Raw traces and logs, stored almost as-is
{{< /flow >}}

1. Applications generate **traces** (the step-by-step detail of a request) and **logs**.
2. The OpenTelemetry Collector gathers them and forwards them to the Neurons ingestion service with the ingestion token. Every request without a valid token is refused.
3. The ingestion service validates, cleans, and stores this data almost as-is — very little transformation happens at this stage, to avoid losing anything and to stay fast.
{.steps}

### From your websites (Browser RUM)

Websites don't go through the Collector. The page loads the Neurons RUM script (one line in its `<head>`) and the browser sends its events **directly** to a public entrance of the ingestion service. Because this entrance is reachable from the internet, it applies its own checks:

- **The site must be known and enabled.** The script carries your company key; the page's address must be one of the domains of an *enabled* browser application. A new site is listed as "waiting for approval" and nothing it sends is kept until you enable it.
- **Rate limits** per application and per visitor protect the platform from a runaway page or abuse.
- **Location** (country, city) is computed from the visitor's IP address, taken only from proxies the platform trusts.
- **Session replays** and **field discovery** (the names of fields a page exposes, never their values) arrive through the same entrance.

Browser events are stored in their own table next to the backend traces, and the API calls made by the page are linked to the backend traces they triggered. See [Browser RUM](application-onboarding/browser-rum/) for the installation.

### Two ways of writing to the warehouse

How the ingestion service writes to the warehouse depends on how the platform is deployed:

| | Direct mode | Kafka mode |
|---|---|---|
| **How it works** | The ingestion service keeps the data a few seconds in memory, then writes it in bulk. | The ingestion service puts every request in a Kafka queue and confirms it only once Kafka has stored it. A *loader* then writes from Kafka to the warehouse. |
| **If the warehouse is slow or down** | The memory buffer fills up; senders are told to retry later (HTTP 429). | Data waits in Kafka; the loader catches up when the warehouse is back. |
| **If the ingestion service crashes** | The few seconds of data still in memory are lost. | Nothing is lost: the data is already in Kafka. |
| **Duplicates** | — | None: each loaded batch and its position in the queue are saved together, in one transaction. |
| **Recent history** | — | Kafka keeps the last hours of traffic (24 h by default). It can be replayed after a database restore (see [Backup and Restore](#backup)). |

{{< callout >}}
The mode is a deployment setting of the ingestion service (`INGEST_MODE`: `buffer` or `kafka`). Kafka mode is the recommended choice for production volumes.
{{< /callout >}}

### After storage: the background workers

4. Background jobs (*workers*) continuously read the stored data back to compute everything shown on the dashboards: request rate, error rate, response time, the service dependency map, business transactions, and the user experience indicators.
5. Dashboards query these already-computed results instead of recalculating on every view, which keeps them fast even over long time ranges.
{.steps}

Each worker remembers exactly where it stopped. After a restart or an outage it resumes from that point and catches up gradually, so nothing is counted twice or skipped. A worker also waits a few seconds after a minute ends before computing it, so slightly late data is still included; data arriving much later is kept but may be missing from the summaries already computed.

{{< callout >}}
Nearly all the curves and trends shown on screen (traffic, latency, errors over time) come from these pre-aggregated computations, not from recalculating raw data every time a screen opens. That's what keeps the platform responsive even with months of history.
{{< /callout >}}

### When the platform is under pressure

- **Senders are asked to retry, never silently dropped.** When the ingestion service can't accept more for a moment, it answers HTTP 429 or 503 with a *Retry-After* delay. Collectors must keep their retry and sending queue enabled (the Neurons Collector does).
- **Request size is limited** (about 16 MB per request); larger requests are refused with HTTP 413. Collectors split their batches well below that.
- **Browsers over their rate limit** get HTTP 429: those events are dropped, and the rest of the site keeps working normally.

### Checking that data is flowing

- **Platform health** shows the state of the ingestion service, the loader and the workers.
- In Kafka mode, the **consumer lag** of the loader (messages waiting in Kafka) should stay close to zero; a lag that keeps growing means the warehouse can't keep up.
- The latest data stored tells you immediately whether anything arrives:

```sql
SELECT MAX(start_time) FROM apm.spans;      -- backend traces
SELECT MAX(start_time) FROM apm.rum_events; -- browser events
```

## Key concepts {#concepts}

A few terms recur throughout the platform and are worth telling apart before browsing the screens:

| Term | Meaning |
|---|---|
| **Application** | A fully instrumented piece of software (e.g. "VisionApp"). Groups one or more services. |
| **Service** | An individual application component that receives requests (an API, a microservice). |
| **Trace** | The complete path of a request, from its entry point through every call it triggers. |
| **Span** | A single step inside a trace (an HTTP call, a database query, etc.). |
| **Business transaction** | A named, tracked-over-time business entry point (e.g. "Login", "Checkout"), automatically detected from recurring traffic. |
| **Business Journey** | A conversion funnel that links several pages and business transactions together, to follow a user journey end to end. |
| **Event** | An alert or signal generated by the platform, with a lifecycle (open, acknowledged, resolved). |
| **Metric** | A measurement aggregated over time — computed by the workers, not sent directly by the applications. |
| **RED** | The three baseline indicators monitored for every service: Rate, Errors, Duration (latency). |
| **RUM** | Real User Monitoring — measuring users' actual experience in their browser or mobile app. |
{firstcol="26"}
