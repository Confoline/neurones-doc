---
title: Application Monitoring
part: part1
weight: 2
labels:
  apps: Applications
  services: Services & dependency map
  bt: Business transactions
---

This part covers the screens used day to day to monitor application behavior. These are the functional equivalent of what other APM platforms call "Application Monitoring".

## Applications — overview {#apps}

The "Applications" screen is the home page of the APM module. It lists every application that has recently emitted telemetry, along with its number of distinct services and an overall health indicator. It's the starting point for quickly spotting which application deserves your attention before diving into detail.

{{< callout >}}
If no application appears, the most common cause is that no recent telemetry has been received: widen the time window, or check that the OpenTelemetry Collector is actually sending its data to Neurons.
{{< /callout >}}

## Services and dependency map {#services}

The "Services" screen lists every active service with its **RED** indicators (rate, errors, latency) over the selected time window, along with a live throughput chart and an automatically generated health summary. It's the most-visited screen day to day.

The service dependency map (*Service Map*) is built into this screen: it visually shows which service calls which other, with each link carrying a health indicator (healthy, degraded, critical) based on that call's error rate. Each service can also be opened individually to show:

- the trend of requests per minute,
- the trend of errors per minute,
- latency percentiles (p50, p95, p99…),
- this service's own database calls (call count, total time, average time),
- detail per operation (endpoint), with its own RED indicators,
- an AI-generated health analysis that summarizes in natural language what's happening on the service.

## Traces {#traces}

The "Traces" screen lets you search and inspect individual requests rather than aggregates. Each trace is reconstructed as an enriched service graph that distinguishes the types of calls encountered: calls between internal services, database calls, cache, messaging, RPC calls, external providers, and browser-side (frontend) steps.

This is the screen to use to understand precisely why a given request was slow or failed: you see the exact sequence of steps, their individual duration, and where the time was actually spent.

### Database calls in a trace

Each database call appears in the span waterfall with a database icon, named by its operation and table (for example `SELECT orders`). Click it to open its details:

- **The full SQL query**, with a button to copy it. Long queries are folded: *Show the full query* displays all of it.
- **Three charts for this query** over the selected time window, counting every call of the same query in that service (values differ, the query is the same): **Number of calls**, **Total time** and **Average time**.

If no SQL query appears, the application doesn't send it yet: see [Capturing SQL queries](#otel).

## Business Transactions {#bt}

A business transaction is a named, tracked-over-time application entry point — for example "Login", "Product search", or "Checkout". Unlike services, business transactions aren't declared manually: they are automatically detected by a background job that spots recurring traffic patterns, then registered in a catalog.

For each business transaction, the platform lets you view its own health history, its flow map (the services traversed by traces that start with this transaction), and configure dedicated notifications.

### Detection rules and groups

Detection rules let you refine or prioritize how traffic is recognized as belonging to one transaction or another, and groups let you control how several related transactions are counted together. A business transaction can also be manually removed (sent to trash) with a configurable grace period before permanent deletion.

## Business Journeys {#bj}

Business Journeys are conversion funnels that link several steps together — for example: product page → add to cart → checkout → confirmation. They are reconstructed by combining browser-side page views (RUM) with the associated business transactions, which shows, step by step, exactly where users actually abandon their journey.

## Errors {#errors}

The "Errors" screen groups failing traces by **signature** — meaning by similar error type — rather than listing every occurrence individually. This lets you immediately see which errors are the most frequent over the period, then open a representative example of each signature to investigate it.

## Database {#db}

The "Database" screen groups all outbound database calls by normalized query signature (the same query with different parameters counts as a single signature). It shows call volume, total time spent, and average time per call, which makes it easy to quickly spot the most expensive queries.
