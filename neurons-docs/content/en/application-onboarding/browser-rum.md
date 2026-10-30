---
title: Browser RUM Onboarding
linkTitle: Browser RUM
lede: Add the Neurons RUM script to your websites so Neurons shows what real users experience — page views, Web Vitals, frontend errors, sessions, frustration signals, business fields, and the backend traces behind each page.
menus:
  onboarding:
    parent: application-onboarding
    weight: 2
labels:
  install: Install the script
  enable: Enable the site
  configure: Configure the application
  identity: Application identity
  test-traffic: Generate test traffic
  verify: Verify in Neurons
  security: Security & privacy
  troubleshooting: Troubleshooting
  rollback: Disable / rollback
  custom-otel: Custom OpenTelemetry instrumentation
---

## Overview {#overview}

Browser Real User Monitoring (RUM) measures what users actually experience in their browser. Backend instrumentation answers *"what happened inside the application?"*; RUM answers *"what did the user see?"*. In Neurons, browser telemetry appears in the **Browser Performance** screen:

| Telemetry | What it tells you |
|---|---|
| Page views | Which pages are visited and how long they take to load — for full page loads and for single-page-app (SPA) route changes, with a breakdown of the load (network, server, rendering). |
| Web Vitals | The standard perceived-performance indicators — LCP, INP, CLS, FCP and TTFB — with percentiles, a good / needs improvement / poor rating, and an Apdex score. |
| Frontend errors | JavaScript errors raised in users' browsers, grouped by message. |
| Sessions | Each user's visit as a chronological journey across pages, and the most common page-to-page paths. |
| User actions and frustration signals | Rage clicks, dead clicks and error clicks — signs of a degraded experience even without a visible technical error. |
| Business fields | Values such as the user, order, cart or product, read from the page and attached to every page view and API call. |
| Browser, device and location | Breakdowns by browser, operating system, device type and country. |
| Correlation with the backend | For each page, the backend business transactions it triggers, and for each trace, the browser and backend spans together. |
{firstcol="26"}

RUM is **independent of backend onboarding**: an application can have backend tracing without RUM, or both. Enabling or disabling RUM never changes the backend configuration. Correlation with backend traces requires the backend to be instrumented too — see the [PHP](../php/), [Java](../java/), [.NET](../dotnet/) and [Python](../python/) guides.

**How it works in short:** you add **one script line** to your pages. Everything else — what is collected, on which sites, with which business fields — is set in Neurons, under **APM → Browser apps**, without touching the site again.

## Architecture {#architecture}

{{< flow label="How browser telemetry reaches Neurons" >}}
app | Your website | Loads the Neurons RUM script with your company key
→ `GET /rum/config/<company key>`
platform | Neurons — RUM configuration | Finds the application for the site's domain (or lists a new site as waiting for approval) and returns its settings
→ OTLP over HTTP (JSON), `?app_id=`, no token
platform | Neurons — public browser intake | Accepts data only from the application's domains, applies rate limits, resolves the visitor's location
→
platform | Browser Performance / RUM | Page loads, Web Vitals, errors, sessions, frustration, business fields, frontend ↔ backend traces
{{< /flow >}}

- **No token in the browser, no forwarding route to build.** The script carries only your **company key**, which is public by design. What protects your data is the list of **domains** of each application: Neurons refuses browser data from any other site.
- **New sites wait for approval.** The first time the script loads on a new site, Neurons lists it under **Waiting for approval**. Nothing it sends is stored until an administrator enables it.
- **Settings are live.** The script re-reads its settings regularly (every 5 minutes by default), so a change in Neurons reaches visitors without redeploying the site.
- **Trace correlation:** the script adds the W3C `traceparent` header to the calls made to your API, so a user action and the backend work it triggers are recorded in the same distributed trace.

## Prerequisites {#prerequisites}

- Access to the HTML `<head>` of the site's pages — the page template, the tag manager, or the reverse proxy in front of the site.
- An account on Neurons. Any logged-in user can view **Browser apps**; enabling sites and changing their settings requires an **administrator**.
- If your site has a **Content Security Policy**, permission to add the Neurons address to `script-src` and `connect-src` — or to serve the script from your own domain (see [Serve the script from your own domain](#own-domain)).
- The `application` name and environment used by the backend services, so the frontend and its backend are grouped together (see [Application identity](#identity)).
- An explicit decision on optional features: session replay, user name, business fields that contain personal data.

## Install the script {#install}

### Copy the snippet

1. In Neurons, open **APM → Browser apps**.
2. Scroll to **Your RUM script** and click **Copy snippet**. It looks like this:

   ```html
   <script src="https://<NEURONS_ADDRESS>/rum/v1/sdk.js" data-app-key="<COMPANY_KEY>" async></script>
   ```

3. Add this line to the `<head>` of **every page** of the site — in the page layout or template, so it is on all pages.
4. Deploy the site.
{.steps}

- **The same line for every site of your company.** You do not create the application first: Neurons recognizes each site by its domain when the script loads.
- **Single-page applications:** add it to the `index.html` that loads the application. Route changes are detected automatically.
- **Tag managers** (for example Google Tag Manager): a *Custom HTML* tag firing on all pages works, but the first page views of a visit may be measured later than with the line in the HTML.
- `<NEURONS_ADDRESS>` is the public address of Neurons configured by the platform team (`RUM_PUBLIC_BASE_URL`). If it is not configured, the snippet uses the address you opened Neurons with — check that your visitors can reach it.

{{< callout >}}
The script never breaks the page: if Neurons cannot be reached, if the site is not enabled, or if the browser blocks it, the page keeps working and nothing is sent.
{{< /callout >}}

### Serve the script from your own domain {#own-domain}

Optional. Serving the script through your own site avoids ad-blockers and keeps your Content Security Policy unchanged:

1. On your web server or reverse proxy, forward every request under `/neurons-rum/` to `<NEURONS_ADDRESS>/`.
2. Load the script from `/neurons-rum/rum/v1/sdk.js` instead of the Neurons address. The script then sends its data to the same `/neurons-rum/` path.
{.steps}

Example with nginx:

```nginx
location /neurons-rum/ {
    proxy_pass         https://<NEURONS_ADDRESS>/;
    proxy_set_header   Host              <NEURONS_ADDRESS>;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_ssl_server_name on;
}
```

```html
<script src="/neurons-rum/rum/v1/sdk.js" data-app-key="<COMPANY_KEY>" async></script>
```

{{< callout type="warn" >}}
**Visitor location behind your proxy.** Neurons believes `X-Forwarded-For` only from proxies it trusts. Give the platform team the outgoing IP addresses of your proxy so they are added to the trusted list (`TRUSTED_PROXY_CIDRS`); otherwise every visitor is located at your proxy.
{{< /callout >}}

## Enable the site {#enable}

### Review and enable

1. Open a page of the site in a browser, so the script loads once.
2. In **APM → Browser apps**, the site appears under **Waiting for approval**, with its domain and how many times the script has loaded.
3. Click **Review and enable**.
4. Check the **General** settings — the name and environment are guessed from the domain (for example `staging` for `staging.shop.example.com`). Correct them so they match the backend (see [Application identity](#identity)).
5. Review **Data collection**, and optionally [record a scenario](#business-fields) to choose business fields.
6. Click **Enable RUM on &lt;application&gt;**.
{.steps}

Visitors start sending data **within a few minutes**. Until then — and for every site that is not enabled — the script loads but nothing is stored.

Only an administrator can enable, disable or ignore a site. Use **Ignore** for a site that must never be monitored (a developer's machine, a partner's copy of a page): it is hidden from the list and its data is refused. **Show ignored sites → Review again** brings it back.

### What happens to new sites

Under **Your RUM script → New sites**, an administrator chooses:

| Option | Effect |
|---|---|
| Wait for approval (default) | A new site is listed under **Waiting for approval**; nothing is collected until it is enabled. |
| Start right away | A new site is enabled at once with the default settings: standard RUM only — session replay and business fields stay off until you turn them on. |
{firstcol="26"}

At most 200 sites can wait for approval at the same time; beyond that, new sites are not listed until some are enabled, ignored or deleted.

### Application statuses

| Status | Script on the site | Data |
|---|---|---|
| Waiting for approval | Loads, collects nothing | Not stored |
| Active | Collects according to the settings | Stored |
| Disabled | Loads, collects nothing | Not stored |
| Ignored | Loads, collects nothing | Refused; the site is hidden from the list |
{firstcol="26"}

### Domains

An application accepts data **only from its domains**. Under **General → Domains** you can:

- **Add a domain**: an exact host (`www.shop.example.com`), a host with a port (`shop.example.com:8443`), or a wildcard covering every subdomain (`*.shop.example.com`).
- **Merge** another detected site: adding the domain of a site already listed as another application asks for confirmation, then moves it into this one — for example `shop.example.com` and `www.shop.example.com`.
- **Remove a domain**: an application keeps at least one.

## Configure the application {#configure}

Click **Settings** next to an application. Changes are applied when you click **Save changes** (or **Enable RUM** for a site waiting for approval), and reach visitors within the configuration refresh delay — 5 minutes by default.

### General

| Setting | Use |
|---|---|
| Application name | Groups the frontend with its backend services — use the **same `application` value as the backend**. |
| Environment | `production`, `preprod`, `staging` or `development` — the same value as the backend. |
| Service name | Identifies this frontend in Browser Performance, for example `shop-web`. |
| Domains | The sites the application accepts data from — see [Domains](#enable). |
{firstcol="26"}

### Data collection

| Module | Collects | Default |
|---|---|---|
| Page views and load times | Full loads and in-app navigation, with timings | On |
| Web vitals | LCP, INP, CLS, FCP, TTFB | On |
| API calls | Calls made by the page, linked to backend traces | On |
| JavaScript errors | Uncaught errors and failed promises | On |
| Frustration signals | Rage clicks, dead clicks, clicks followed by an error | On |
| User name | The logged-in user's name — personal data. The user id is always allowed. | Off |
{firstcol="26"}

**Visits monitored** (default 100%) is the share of visits the script follows. Lower it to reduce the volume of data on very busy sites; a visit is either fully monitored or not at all.

### Business fields {#business-fields}

Business fields add values such as `user.id`, `order.id`, `cart.total` or `product.sku` to **every page view and API call** of a visit, so you can filter and break down the experience by customer, order or product. They are shown in the trace detail and sent as `biz.<name>` attributes.

There are three ways to add them, under **Business fields**:

**1. Suggested from your visitors.** Once RUM is enabled, the script reports the **names** of the fields a page exposes — never their values. After 20 visits (every visit is used at first, then 1 in 10), Neurons suggests the useful ones; click **Enable** on those you want. A field must be seen in at least 3 visits to be suggested. An enabled field that visits have not shown for 7 days is flagged: the site may have changed.

**2. Record a scenario.** Click **Record a scenario**, choose the site and the start page, then **Open my site and record**:

1. Neurons opens your site in a new tab, with a one-time link valid 15 minutes.
2. Use the site as a visitor would: log in, browse, add to cart, buy.
3. Back in Neurons, choose the fields to keep, name them and set their privacy.
{.steps}

Recording works even while the site waits for approval, but the site must already load the script, and only the tab Neurons opened is recorded.

**3. Add manually.** Click **Add manually** and choose where the value is read from:

| Read from | You give | Example |
|---|---|---|
| Server response | The API URL (and method), then the field in the JSON response | `/api/carts/:id` → `total` |
| dataLayer event | The event name, then the field in the event | `purchase` → `ecommerce.transaction_id` |
| Page data (schema.org) | The schema.org type and field | `Product.sku` |
| On screen | The element's CSS selector | `.cart-summary .total` |
| Cookie, Local storage, Session storage | The name or key (and a field inside a JSON value) | `profile` → `tier` |
| Login token (JWT claim) | Where the token is, then the claim | `local_storage:token` → `sub` |
| Meta tag | The meta tag name | `shop:country` |
| Page address | The URL parameter | `utm_source` |
| JavaScript variable | The variable path | `shopState.cart.count` |
| Click | The clicked element's CSS selector (and an attribute) | `.add-to-cart` → `data-sku` |
{firstcol="30"}

For each field you also choose:

- **Only on pages** (optional): a page pattern such as `/checkout/*`.
- **Keep for**: *the whole visit* (for example the user) or *the current page* (for example the product being viewed).
- **Privacy**: *Automatic* hashes names that look personal (email, phone, name, address…) and keeps the others; or force *Keep the value*, *Mask* (first character only) or *Hash*.

{{< callout >}}
Passwords, card numbers, tokens and other secrets are **never collected**, whatever a rule says: fields whose name looks like a secret cannot become a business field, and the script refuses values that look like a card number.
{{< /callout >}}

### API calls

| Setting | Use |
|---|---|
| Your API domains | Calls to these origins count as your own API. Calls to the site's own domain always count. |
| API path prefixes | Paths that identify API calls on the site's domain. Default: `/api`. |
| Link to backend traces on | Origins that receive the `traceparent` header, so the browser action and the backend trace are joined. Same-domain calls always get it. |
| Request / response headers to capture | Up to 20 header names each, shown on the API call. Neurons suggests the names seen on your API calls. |
| Body capture | Per route and method: capture the request and/or response body, redacted and cut to a size limit of 1 to 16 KB. |
{firstcol="30"}

{{< callout type="warn" >}}
Add an origin to **Link to backend traces on** only if that API's CORS configuration allows the `traceparent` request header — otherwise the browser blocks the calls. Never captured, whatever the settings: `Authorization`, `Cookie`, `Set-Cookie`, and any header whose name contains *token*, *secret*, *key*, *auth* or *session*.
{{< /callout >}}

### Session replay {#replay}

{{< callout type="warn" >}}
**Session replay is off by default and not part of standard onboarding.** It records what visitors see so a session can be replayed. Applications handling credentials, financial or legal data, identity documents or other sensitive information require a privacy review before it is turned on.
{{< /callout >}}

When turned on:

- **Sessions recorded** (default 10%) — the share of monitored visits that are recorded.
- **Mask all page text** (default on) — replaces every text of the page; turn it off only after the privacy review.
- Form inputs are **always masked**.

### Advanced

| Setting | Use |
|---|---|
| Route patterns | One per line, for example `/products/:slug`. URLs are grouped by these patterns; other URLs are grouped automatically. |
| Name of your API in the service map | The node the browser calls point to. Default: `<application>-api`. |
| Application type | `spa` (single-page application) or `web`. |
| Wait for consent | Nothing starts before the visitor accepts (GDPR). Give the consent cookie and the text it must contain once accepted, for example `cookie_consent` containing `analytics`. |
{firstcol="30"}

**Delete application** (administrators) removes its settings and business fields. Data already collected stays in Neurons. If the script is still on the site, the site reappears under **Waiting for approval** on its next visit.

## Application identity {#identity}

Two values identify browser telemetry, at two levels:

- **Service name identifies the frontend.** Browser Performance lists and filters frontends by service name.
- **Application name groups services.** The same application name on the frontend and on its backend services groups them under one logical application.

```text
Frontend (Browser apps):  application = shop   service name = shop-web   environment = production
Backend (OpenTelemetry):  application = shop   service.name = shop-api   deployment.environment = production
```

Neurons stamps these values on everything the script sends, so a page can never write into another application's data.

## Generate test traffic {#test-traffic}

After enabling the site:

1. Open the site from a real browser and do a full page reload.
2. Navigate between pages (route changes, for an SPA).
3. Perform an action that calls the backend.
4. Trigger a controlled JavaScript error.
5. Click the same spot three times quickly, to produce a rage click.
{.steps}

Telemetry is sent in batches: allow a few seconds before checking Neurons.

## Verify in Neurons {#verify}

1. In **APM → Browser apps**, the application is **Active** and its *Page views, 24 h* increase.
2. In the browser's developer tools (Network), the requests to `/v1/traces` return **2xx** — a 403 means the domain is missing from the application (see [Troubleshooting](#troubleshooting)).
3. The frontend appears in **Browser Performance** under its service name.
4. Page views arrive, for the full reload and for route changes.
5. Web Vitals arrive with their ratings, and the Apdex is calculated.
6. The controlled JavaScript error appears.
7. Sessions show the pages visited, in order.
8. Browser, OS and device are populated, and the location matches the visitor — not a server.
9. The backend call appears in the same trace as the browser action, and the page lists the business transactions it triggers.
10. If configured: business fields appear in the trace detail; frustration signals and session replay appear.
{.steps}

{{< callout >}}
An onboarding is not complete until it has been validated on the deployed environment, not only locally.
{{< /callout >}}

## Security & privacy {#security}

- **The company key is public by design** — it is in every page. It only lets a site *ask* to be monitored; data is stored only from the domains of an **enabled** application, and Neurons applies rate limits per application and per visitor.
- **No Neurons token is ever needed in the browser.** Never put an ingestion or query token in frontend code.
- Passwords, card numbers, tokens and secrets are never collected; sensitive headers are never captured; captured bodies are redacted.
- Business fields whose names look personal are **hashed** unless you choose otherwise; **User name** is off by default.
- Field discovery sends field **names**, never values.
- Use **Wait for consent** where the visitor's consent is required before measuring.
- Review the collection of visitor IP addresses and locations against the application's privacy requirements.
- Session replay stays off unless approved after a privacy review.

## Troubleshooting {#troubleshooting}

| Symptom | Likely cause | Action |
|---|---|---|
| The site never appears under **Waiting for approval** | The script is not on the page, is blocked (ad-blocker, Content Security Policy), or the Neurons address is not reachable from the browser | Check the page source and the browser console; add the Neurons address to the CSP or [serve the script from your own domain](#own-domain). |
| The site does not appear, and other sites already wait | 200 sites already wait for approval | Enable, ignore or delete waiting sites. |
| `/v1/traces` returns **403** | The page's domain is not one of the application's domains | Add the domain, or merge the site into the application. |
| `/v1/traces` returns **202** and nothing appears | The application is not enabled (waiting, disabled or ignored) | Enable RUM on the application. |
| `/v1/traces` returns **429** | Rate limit reached for the application or the visitor | Lower **Visits monitored**; ask the platform team if the limits are too low for the site's traffic. |
| Enabled, but no data after several minutes | Pages opened before enabling keep the old settings until their next refresh | Reload the page; wait up to the configuration refresh delay (5 minutes by default). |
| Two applications for one site | The site is reachable on several domains (`shop.` and `www.shop.`) | Add one domain to the other application to merge them. |
| API calls fail with a CORS error after enabling | An API origin is in **Link to backend traces on** but its CORS does not allow `traceparent` | Allow the header on the API, or remove the origin. |
| Browser and backend spans in separate traces | The API origin is not in **Link to backend traces on**, or the backend is not instrumented | Add the origin (with CORS), and onboard the backend. |
| No business field suggestion | Learning not finished (fewer than 20 visits), or RUM not enabled | Wait for more visits, or record a scenario. |
| A business field is flagged "not seen by recent visits" | The page or API changed | Check the rule's selector, URL or path. |
| Every visitor located in the same place | The script is served through your proxy and its address is not trusted | Ask the platform team to add your proxy's outgoing addresses to `TRUSTED_PROXY_CIDRS`. |
| Users metric empty | No user id business field, or a long time range | Add a `user.id` business field; use a shorter range. |

## Disable / rollback {#rollback}

RUM can be stopped without touching the site or backend tracing:

1. In **Browser apps → Settings**, click **Disable RUM**. Within a few minutes the script stops collecting; data already collected stays in Neurons.
2. To stop loading the script at all, remove the script line from the site and redeploy it.
3. If you served the script from your own domain, remove the `/neurons-rum/` route.
4. Confirm that no new browser telemetry arrives in Neurons, and that backend traces continue normally.
{.steps}

## Custom OpenTelemetry instrumentation {#custom-otel}

**Most sites do not need this section.** It is for frontends that already use their own OpenTelemetry browser instrumentation, or that cannot load the Neurons script. You then build the telemetry yourself, following the contract below, and send it to Neurons through a forwarding route that adds the ingestion token. Applications instrumented this way are not listed in **Browser apps** and are not configured there.
### Install the packages

```bash
npm install \
  @opentelemetry/api \
  @opentelemetry/sdk-trace-web \
  @opentelemetry/sdk-trace-base \
  @opentelemetry/resources \
  @opentelemetry/semantic-conventions \
  @opentelemetry/context-zone \
  @opentelemetry/instrumentation \
  @opentelemetry/instrumentation-fetch \
  @opentelemetry/instrumentation-document-load \
  @opentelemetry/exporter-trace-otlp-http \
  web-vitals
```

| Package | Role |
|---|---|
| @opentelemetry/sdk-trace-web, sdk-trace-base | Tracer provider and batch span processor |
| @opentelemetry/resources, semantic-conventions | Resource attributes (`service.name`, `application`, ...) |
| @opentelemetry/context-zone | Keeps the active span across asynchronous callbacks |
| @opentelemetry/instrumentation-fetch | One span per `fetch` call, and `traceparent` injection |
| @opentelemetry/instrumentation-xml-http-request | The same for `XMLHttpRequest` — add it if the application uses XHR |
| @opentelemetry/instrumentation-document-load | Spans for the initial page load, with navigation timings |
| @opentelemetry/exporter-trace-otlp-http | Sends spans as OTLP/HTTP JSON |
| web-vitals | Measures LCP, INP, CLS, FCP and TTFB |
{firstcol="30" mono="1"}

### Initialize Browser Instrumentation

1. **Initialize first.** Import the RUM setup on the first line of the application entry point, so instrumentation is active before the first network call.
2. **Register the context manager.** Pass `ZoneContextManager` to `provider.register()` — installing `@opentelemetry/context-zone` alone does nothing.
3. **Exclude the telemetry endpoints** from the Fetch/XHR instrumentation, so telemetry uploads do not create spans of their own.
4. **Never break the page.** Wrap initialization — ideally each feature — in its own `try/catch`, and guard `crypto.randomUUID()`, which is unavailable in non-secure (HTTP) contexts. RUM that fails must leave the application working.
5. **One switch.** Make RUM depend on a single build setting, so it can be turned off by rebuilding.
6. **Propagate trace context.** Same-origin API calls get `traceparent` automatically. For an API on another origin, list it in the Fetch instrumentation's `propagateTraceHeaderCorsUrls` and allow the `traceparent` header in that API's CORS configuration.

Minimal initialization, to adapt to your build tool and framework:

```js
// rum.js — imported on the first line of the application entry point
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { DocumentLoadInstrumentation } from '@opentelemetry/instrumentation-document-load';

const RUM_ENDPOINT = '/v1/traces'; // same-origin RUM ingestion endpoint; empty = RUM off

if (RUM_ENDPOINT) {
  try {
    const provider = new WebTracerProvider({
      resource: resourceFromAttributes({
        'service.name': '<FRONTEND_SERVICE_NAME>',
        'application': '<APPLICATION_NAME>',
        'deployment.environment': '<ENVIRONMENT>',
        'telemetry.sdk.language': 'webjs',
      }),
      spanProcessors: [new BatchSpanProcessor(new OTLPTraceExporter({ url: RUM_ENDPOINT }))],
    });
    provider.register({ contextManager: new ZoneContextManager() });

    registerInstrumentations({
      instrumentations: [
        new DocumentLoadInstrumentation(),
        new FetchInstrumentation({ ignoreUrls: [/\/v1\/traces/, /\/v1\/logs/, /\/rum\/replay/] }),
      ],
    });
  } catch (e) {
    // RUM must never break the application
  }
}
```

### Implement Neurons browser telemetry {#implement}

{{< callout type="warn" >}}
**The initialization above is not enough to populate Browser Performance.** The standard OpenTelemetry Web SDK creates generic spans (document load, `fetch` calls). It does not create the Neurons-specific browser telemetry described below — the Neurons RUM script does. With your own instrumentation, these signals must be implemented by the application, following the contract below.
{{< /callout >}}

The application must implement:

| Signal | What to implement |
|---|---|
| Hard page views | Turn the initial page load into a `page-view` span with `nav.type=hard` and the page-load timings. |
| SPA soft page views | Create a new `page-view` span with `nav.type=soft` on every client-side route change, and keep it active while the route's API calls start. |
| Web Vitals | Turn each `web-vitals` measurement into a `web-vital` span with its name, value and rating. |
| Sessions | Generate a `session.id` and set it on every span. |
| Browser errors | Catch JavaScript errors and unhandled promise rejections and record them as spans with `rum.kind=app-error` (or as log records). |
| API-call classification | Mark the application's API `fetch`/XHR spans with `api.kind`, and set a normalized `api.route`. |
| Frustration signals | Detect rage, dead and error clicks and record them as spans with `frustration.type`. |
{firstcol="26"}

### Browser telemetry expected by Neurons {#telemetry}

Neurons fills the Browser Performance screens from specific span names and attributes. A wrong name is not rejected — the data is simply missing from the screens.

#### Page views

| Item | Contract |
|---|---|
| Span name | `page-view` (exact) |
| nav.type | `hard` for a full page load, `soft` for an SPA route change |
| Page | `page.path`, `page.url` |
| Timings | `pl.*` attributes — see [Page-load timings](#page-load-timings) |
{firstcol="26" mono="1"}

- For an SPA, a new `page-view` span must be created for **every route change**, with `nav.type=soft`, `pl.render_ms` (time to the next paint) and `pl.soft_ms`.
- **Route API total, Route backend total and Data wait** are computed by joining a soft `page-view` with the browser API calls **of the same trace**. The soft page-view span must therefore be active — or an ancestor — when the route's API calls start; API calls started outside it are not counted for that route.
- **Data wait** uses `pl.data_wait_ms` or `route.data_wait_ms` when present, and falls back to `pl.backend_ms` otherwise.
- When `pl.total_ms` is absent, the span duration is used.
- Business Journey steps of type `rum_page` are counted from `page-view` spans and their `page.path` — see [Business Journeys](../../#bj).

#### Page-load timings {#page-load-timings}

All values are milliseconds.

| Attribute | Meaning |
|---|---|
| pl.total_ms | Total page-load time |
| pl.backend_ms, pl.frontend_ms | Server part and browser part of the load (`pl.frontend_ms` is derived as total − backend when absent) |
| pl.ttfb_ms, pl.first_byte_ms | Time to first byte (`pl.first_byte_ms` defaults to `pl.ttfb_ms`) |
| pl.dns_ms, pl.tcp_ms, pl.tls_ms | DNS lookup, TCP connection, TLS handshake |
| pl.request_ms, pl.response_download_ms | Request wait, response download |
| pl.dom_interactive_ms, pl.dom_content_loaded_ms, pl.dom_complete_ms | DOM milestones |
| pl.dom_processing_ms | DOM processing (`domComplete − responseEnd` when absent) |
| pl.load_event_ms | `load` event handler duration |
| pl.render_ms | Time to render (`view.render_ms` is also accepted) |
| pl.soft_ms | SPA route-change duration |
| pl.data_wait_ms, route.data_wait_ms | Optional: time an SPA route waits for data |
{firstcol="30" mono="1"}

Instead of computed `pl.*` values, a hard `page-view` span may carry the raw browser **Navigation Timing** fields; Neurons derives the timings from them when the corresponding `pl.*` attribute is absent:

| Raw fields (also accepted with a `navigation.` prefix) | Derived timing |
|---|---|
| loadEventEnd | pl.total_ms |
| domainLookupEnd − domainLookupStart | pl.dns_ms |
| connectEnd − connectStart | pl.tcp_ms |
| connectEnd − secureConnectionStart | pl.tls_ms |
| responseStart − requestStart | pl.request_ms |
| responseEnd − responseStart | pl.response_download_ms |
| responseStart | pl.ttfb_ms |
| domInteractive | pl.dom_interactive_ms |
| domContentLoadedEventEnd | pl.dom_content_loaded_ms |
| domComplete | pl.dom_complete_ms |
| domComplete − responseEnd | pl.dom_processing_ms |
| loadEventEnd − loadEventStart | pl.load_event_ms |
{mono="1,2"}

#### Web Vitals and Apdex

| Item | Contract |
|---|---|
| Span name | `web-vital` (exact) |
| wv.name | `LCP`, `INP`, `CLS`, `FCP` or `TTFB` |
| wv.value | LCP, INP, FCP, TTFB in **milliseconds**; CLS as a **unitless score** |
| wv.rating | Exactly `good`, `needs-improvement` or `poor` — the values emitted by the `web-vitals` library |
{firstcol="26" mono="1"}

{{< callout type="warn" >}}
Without `wv.rating`, the Web Vital values are still shown, but the good / needs improvement / poor distributions stay empty and the Browser Performance **Apdex** is not calculated.
{{< /callout >}}

Browser Performance **Apdex** is calculated from the ratings of **LCP, INP and CLS** only:

```text
Apdex = (good + 0.5 × needs-improvement) / total
```

FCP and TTFB are displayed as Web Vitals but do not contribute to Apdex. Thresholds displayed by Neurons:

| Vital | Good | Needs improvement | Poor | In Apdex |
|---|---|---|---|---|
| LCP | ≤ 2500 ms | ≤ 4000 ms | > 4000 ms | Yes |
| INP | ≤ 200 ms | ≤ 500 ms | > 500 ms | Yes |
| CLS | ≤ 0.1 | ≤ 0.25 | > 0.25 | Yes |
| FCP | ≤ 1800 ms | ≤ 3000 ms | > 3000 ms | No |
| TTFB | ≤ 800 ms | ≤ 1800 ms | > 1800 ms | No |
{mono="1"}

#### API calls

- Only **CLIENT** spans (the `fetch`/XHR spans) count as browser API calls.
- A CLIENT span is classified as an **API call** when it carries `api.kind` (or an explicit `rum.kind=api-call`).
- A CLIENT span with a URL or route but no API classification is treated as a **resource call**.
- The route shown is resolved from `api.route`, then `url.path`, then `http.route`, then `http.target`. Set a normalized `api.route` (identifiers replaced, e.g. `/api/orders/:id`) so calls group correctly.

#### Browser errors

A browser span is counted as a JavaScript error **only when it carries `rum.kind=app-error`**:

- the span name `app.error` alone is **not** sufficient;
- an ERROR span status alone is **not** sufficient;
- `exception.*` attributes are **not** used for browser errors.

| Attribute | Content |
|---|---|
| rum.kind | `app-error` (required) |
| error.type | Error type, e.g. `TypeError` |
| error.message | Error message — if absent, the span name is used as the message |
| error.stack | Stack trace |
| page.path | Page where the error occurred |
{firstcol="26" mono="1"}

Errors can also be sent as **OTLP log records**: a log record is counted as a browser error when it carries `rum.kind=js-error` or `rum.kind=app-error`, with the same `error.*` attributes. This requires a `/v1/logs` forwarding route — see [Forwarding route](#forwarding-route).

#### Frustration signals

| Attribute | Content |
|---|---|
| frustration.type | `rage_click`, `dead_click` or `error_click` |
| target.selector, target.text | The clicked element |
| click.x, click.y | Click coordinates |
| page.url | Current page |
| session.id | Required — signals without it are not recorded |
{firstcol="26" mono="1"}

#### Sessions and users

- `session.id` is **required** for sessions, journeys, replay and frustration signals. Neurons groups telemetry by the value it receives: the application decides the scope (for example one identifier per browser tab, kept in `sessionStorage`).
- The session timeline looks back up to 30 days.
- The **Users** metric counts distinct `user.id` values (or `user.name` when `user.id` is absent) on page views. Without user identification it stays empty. Sessions and Users are not available on long time ranges served from aggregated data.
- `user.id` and `user.name` are personal data — see [Security & privacy](#security).

### Forwarding route {#forwarding-route}

**Why this is needed.** The browser cannot send telemetry straight to Neurons: Neurons requires a token, and anything placed in browser code is visible to every visitor. So the browser sends its telemetry to **your own website**, and your web server passes it on to Neurons, adding the token on the way:

```text
Browser ──POST https://shop.example.com/v1/traces──▶ Your web server ──adds token + visitor IP──▶ Neurons
         (no token, same website)                    (forwarding route)
```

You add this forwarding route once, on the web server or reverse proxy that already serves the frontend.

#### Step 1 — Decide which routes you need

| Route on your website | Needed when | Token to add |
|---|---|---|
| /v1/traces | **Always** | Ingestion token |
| /v1/logs | Only if the application sends JavaScript errors as log records | Ingestion token |
| /rum/replay | Only if session replay is approved | Ingestion token |
{firstcol="26" mono="1"}

Most applications only need `/v1/traces`.

#### Step 2 — Get the values from the Neurons platform team

- `<NEURONES_INGEST_URL>` — the address of the Neurons ingestion service for your environment.
- The **ingestion token** — the same token for every route.

#### Step 3 — Add the forwarding routes to your web server

Each route does three things:

1. **Forward** the request to the same path on `<NEURONES_INGEST_URL>`.
2. **Add the token** in the `X-Neurones-Token` header.
3. **Pass on the visitor's IP address** in `X-Forwarded-For` and `X-Real-IP` — Neurons uses it for the visitor's country and city.

Example with nginx (replace the values in angle brackets; keep the token out of version control, for example by injecting them from the server environment at startup):

```nginx
# Always
location /v1/traces {
    proxy_pass         <NEURONES_INGEST_URL>/v1/traces;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Neurones-Token  <NEURONES_INGEST_TOKEN>;
}

# Only if JavaScript errors are sent as log records
location /v1/logs {
    proxy_pass         <NEURONES_INGEST_URL>/v1/logs;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Neurones-Token  <NEURONES_INGEST_TOKEN>;
}

# Only if session replay is approved
location /rum/replay {
    proxy_pass         <NEURONES_INGEST_URL>/rum/replay;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Neurones-Token  <NEURONES_INGEST_TOKEN>;
}
```

With another web server (Apache, IIS, an API gateway) or a route in your backend application, apply the same three rules.

#### Step 4 — Test the route

From any machine, send an empty trace export to **your website** (not to Neurons). Nothing is stored:

```bash
curl -i -X POST https://<YOUR_FRONTEND_HOST>/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

| Response | Meaning |
|---|---|
| 200 | The route works and the token is accepted. |
| 401 | The route reaches Neurons, but the token is missing or wrong. |
| 404 | The route is not configured on your web server. |
| 502 / 504 | Your web server cannot reach `<NEURONES_INGEST_URL>`. |
{firstcol="26"}

#### Step 5 — Point the browser instrumentation at the route

Use the same-origin path as the exporter URL: `/v1/traces` (as in the initialization example above). The browser never needs the Neurons address or any token.

{{< callout >}}
The forwarding route is needed only for custom instrumentation. The Neurons RUM script sends its data directly to Neurons, without a token — see [Install the script](#install).
{{< /callout >}}

#### Geolocation

There is no client-side geolocation. Neurons resolves country, region, city and coordinates from the visitor's IP address and overwrites any `geo.*` attribute sent by the browser. `X-Forwarded-For` and `X-Real-IP` are believed only when the request comes from a proxy Neurons trusts (`TRUSTED_PROXY_CIDRS`): give the platform team the outgoing addresses of your forwarding server, otherwise every visitor is located at that server.

### Session replay upload {#replay-upload}

Session replay follows the same privacy rules as with the Neurons script — see [Session replay](#replay). When approved, a recorder such as `@rrweb/record` uploads batches to `/rum/replay` (through the forwarding route, with the ingestion token):

| Field | Content |
|---|---|
| app | The **frontend `service.name`** (e.g. `shop-web`) — not the `application` value |
| session_id | Same value as the `session.id` span attribute |
| page_view_id | Page-view identifier |
| sequence_number | Batch counter, starting at 0 |
| compressed_events | Base64 of the gzip-compressed JSON (`{ events, metadata }`, or a plain array of rrweb events) |
| content_encoding | `gzip` or `identity` |
| reason, trigger_reason, trigger_timestamp | Optional: why the batch was sent; first notable event of the session |
{firstcol="26" mono="1"}

Replay sessions are associated with the browser telemetry through the frontend `service.name` and `session.id`: if `app` does not equal the frontend `service.name`, replays are not linked to the sessions and frustration signals of that frontend.

Unknown fields are rejected with **422**. Default size limits: 2 MiB compressed and 25 MiB decompressed per batch. Configure the recorder to mask every input value and to block elements that must never be recorded.

### Resource and span attributes {#otel-attributes}

Resource attributes, set once when the SDK is initialized — `application`, `service.name` and `deployment.environment` follow the same rules as in [Application identity](#identity):

| Attribute | Required | Notes |
|---|---|---|
| telemetry.sdk.language = webjs | **Yes** | Marks the data as browser RUM. Without it, the frontend is not shown in Browser Performance. |
| service.name | Yes | Identifies the frontend in Browser Performance, e.g. `shop-web`. Also the `app` value for session replay. |
| application | Yes | **The same value as the backend services**, so the frontend and its backend are grouped as one application. |
| deployment.environment | Yes | The same value as the backend, e.g. `production`. |
| app.type | No | `spa` or `mpa`. When absent, Neurons infers it from `nav.type`: any soft navigation means SPA, hard-only means MPA. |
{firstcol="30" mono="1"}

#### Attributes on every span

Neurons reads these from each **span**, not from the resource — set them on every span the instrumentation creates or enriches:

| Attribute | Notes |
|---|---|
| session.id | **Required** for sessions, journeys, replay and frustration signals — see [Sessions and users](#telemetry). |
| page.path, page.url | The current page. |
| browser.name, os.name, device.type | Breakdown dimensions — `device.type`: `desktop`, `mobile` or `tablet`. |
| user.id, user.name | Optional, only after login and only if approved — personal data. `user.id` feeds the Users metric. |
{firstcol="30" mono="1"}

### Troubleshooting custom instrumentation

| Symptom | Likely cause | Action |
|---|---|---|
| `/v1/traces` returns 401 | The forwarding route does not add the ingestion token, or adds a wrong one | Check the route's header and the token value. |
| `/rum/replay` returns 401 while traces work | The replay route adds another token than the ingestion token | Use the ingestion token on every route. |
| `/rum/replay` returns 422 | Unknown field, wrong `content_encoding`, or batch too large | Send only the documented fields; use `gzip` or `identity`; keep batches under the limits. |
| Replays not linked to sessions | Replay `app` differs from the frontend `service.name` | Send the frontend `service.name` as `app`. |
| Frontend missing from Browser Performance | `telemetry.sdk.language=webjs` missing, or no `page-view` spans | Check the resource attributes and implement page views (see [Implement Neurons Browser Telemetry](#implement)). |
| JavaScript errors missing | Error spans without `rum.kind=app-error` (an `app.error` name or ERROR status alone is not enough) | Set `rum.kind=app-error` and the `error.*` attributes. |
| Web Vitals shown but no ratings and no Apdex | `wv.rating` missing or not exactly `good` / `needs-improvement` / `poor` | Send the rating emitted by the `web-vitals` library. |
| API calls listed as resource calls | `api.kind` not set on the API spans | Set `api.kind` and a normalized `api.route`. |
| Route API total / backend total / Data wait empty | API calls not in the same trace as the soft `page-view` | Keep the soft page-view span active while the route's API calls start. |
| Sessions, replay or frustration signals empty | `session.id` missing on spans | Set `session.id` on every span. |
| Browser and backend spans in separate traces | `traceparent` not sent, or backend not instrumented | Check the Fetch instrumentation; for a cross-origin API, `propagateTraceHeaderCorsUrls` and CORS. |
| Breakdowns show "unknown" | `browser.name` / `os.name` / `device.type` set only on the resource | Set them on each span. |
| Frontend grouped apart from its backend | Different `application` values | Use the same `application` value on both sides. |
| The page fails to load in production only | Unguarded RUM initialization, e.g. `crypto.randomUUID()` over HTTP | Guard ID generation; wrap each RUM feature in `try/catch`. |
| A package is installed but has no effect | Never imported or registered (e.g. `ZoneContextManager`) | Check the RUM source, not only `package.json`. |

### Disable custom instrumentation

1. Turn the RUM switch off, or remove the RUM import from the application entry point.
2. Rebuild and redeploy the frontend — custom instrumentation is part of the JavaScript bundle, so a server-side change alone does not disable it.
3. Remove the forwarding routes from the web server.
{.steps}
