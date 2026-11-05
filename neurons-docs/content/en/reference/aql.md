---
title: AQL — Advanced Query Language for Logs
linkTitle: AQL for logs
lede: Search application logs with conditions on level, service, message, time, trace and attributes, combined with AND, OR, NOT and parentheses, from the AQL query mode of the Logs screen.
menus:
  ref:
    weight: 20
labels:
  aql-overview: Overview
  aql-start: Getting started
  aql-fields: Fields
  aql-operators: Operators
  aql-values: Values
  aql-attributes: Attributes
  aql-combine: Combining conditions
  aql-filters: Page filters
  aql-examples: Examples
  aql-errors: Errors
  aql-limits: Limits and performance
  aql-api: API
---

## Overview {#aql-overview}

The Logs screen has two search modes:

| Mode | Use it for |
|---|---|
| **Basic search** | A text search plus the Level and Service filters. |
| **AQL query** | Several conditions at once, alternatives (`OR`), exclusions (`NOT`), wildcards, time limits and log or resource attributes. |
{firstcol="18"}

The log stream, the counters (matching lines, errors, warnings, services) and the volume chart always show the result of the **last query run**.

## Getting started {#aql-start}

1. Open **Logs** and select **AQL query** in the mode switch.
2. Type a query, for example:

   ```
   level IN (ERROR, WARN) AND service = "checkout" AND message CONTAINS "timeout"
   ```

3. Click **Run query** or press **Ctrl + Enter** (**Cmd + Enter** on macOS).

The query is checked while you type: a valid query shows **Valid query · N conditions**; an invalid one is underlined and explained (see [Errors](#aql-errors)). The query that was run is kept in the page URL, so the page can be bookmarked or shared.

{{< callout >}}
**Edit as AQL** (in Basic search) writes the current Basic filters as an AQL query. Switching back to **Basic search** keeps your AQL query: switch again to continue with it.
{{< /callout >}}

## Fields {#aql-fields}

| Field | Meaning | Operators |
|---|---|---|
| `service` | Service name | `=` `!=` `IN` `CONTAINS` |
| `application` | Application | `=` `!=` `IN` `CONTAINS` |
| `environment` | Environment (prod, stg…) | `=` `!=` `IN` `CONTAINS` |
| `level` | `ERROR`, `WARN`, `INFO` or `DEBUG` | `=` `!=` `IN` |
| `message` | Log message text | `CONTAINS` `=` `!=` |
| `timestamp` | Time of the log | `>` `>=` `<` `<=` |
| `trace_id` | Trace identifier | `=` `!=` `IN` |
| `span_id` | Span identifier | `=` `!=` `IN` |
| `attr.<key>` | Log record attribute (see [Attributes](#aql-attributes)) | `=` `!=` `IN` `CONTAINS` |
| `resource.<key>` | Resource attribute (see [Attributes](#aql-attributes)) | `=` `!=` `IN` `CONTAINS` |
{firstcol="22" mono="1"}

`level` covers the usual spellings of each level: `ERROR` also matches `ERR`, `FATAL`, `CRITICAL`, `SEVERE`…, and logs that only carry an OpenTelemetry severity number (17–24 for ERROR).

## Operators {#aql-operators}

| Operator | Example | Matches |
|---|---|---|
| `=` | `service = "checkout"` | Exactly this value. With `*`: a wildcard (`service = "pay*"`). |
| `!=` | `environment != stg` | Any other value, **including logs without a value**. |
| `IN ( , )` | `level IN (ERROR, WARN)` | One of the listed values (up to 50). |
| `CONTAINS` | `message CONTAINS "timeout"` | The text appears anywhere, case-insensitive. The text must be in quotes. |
| `>` `>=` `<` `<=` | `timestamp >= now-15m` | Logs after / before a time. Timestamp only. |
{firstcol="16" mono="1"}

## Values {#aql-values}

- **Quoted or bare**: `service = checkout` and `service = "checkout"` are the same. Quotes are needed for spaces and other special characters: `message CONTAINS "connection refused"`. Inside quotes, write `\"` for a quote.
- **Wildcard**: `*` matches any text (`service = "ms-vision*"`); wildcard matching is case-insensitive. `%` and `_` have no special meaning.
- **Exact match** (`=` without `*`) is case-sensitive: use the exact name, or pick it from the suggestions.
- **Time**: `now`, `now-30s`, `now-15m`, `now-2h`, `now-1d`, or a UTC date and time `2026-11-05T14:30`.
- **Keywords** (`AND`, `OR`, `NOT`, `IN`, `CONTAINS`) and levels are case-insensitive.

## Attributes {#aql-attributes}

Conditions can use the attributes sent with each log:

- `attr.<key>` — attributes of the log record, for example `attr.exception.type`.
- `resource.<key>` — attributes of the resource that emitted it, for example `resource.service.version`, `resource.telemetry.sdk.language`.

| Query | Matches |
|---|---|
| `attr.exception.type = "ResourceExhausted"` | This value. |
| `attr.http.status_code IN (500, 503)` | One of these values. |
| `resource.service.version = "1.*"` | Version 1.x. |
| `attr.exception.type CONTAINS "exhausted"` | The value contains this text. |
| `attr.user_id = *` | Logs **that have** the attribute. |
| `NOT attr.user_id = *` | Logs **without** the attribute. |
{firstcol="44" mono="1"}

Keys are written as sent by the application (case-sensitive) and may contain letters, digits, `_`, `.` and `-` (128 characters at most). Attribute values are compared as text, so `>` and `<` are not available.

## Combining conditions {#aql-combine}

- `AND`: both conditions. `OR`: either. `NOT`: the opposite of the next condition or group.
- Parentheses group conditions: `service = checkout AND (level = ERROR OR message CONTAINS "timeout")`.
- `AND` must be written: `level = ERROR service = checkout` is an error (missing `AND` / `OR`).
- Without parentheses, `NOT` applies first, then `AND`, then `OR`.

## Page filters {#aql-filters}

In AQL mode the query replaces the Level and Service filters of Basic search. These still apply, combined with the query using `AND`:

- the **time range** (and a bar selected in the volume chart);
- the **Application** and **Environment** pickers at the top of the page.

The level buttons of the volume chart are inactive in AQL mode: put levels in the query.

## Examples {#aql-examples}

| Goal | Query |
|---|---|
| Errors and warnings mentioning a timeout | `level IN (ERROR, WARN) AND message CONTAINS "timeout"` |
| One service, without health checks | `service = "checkout" AND NOT message CONTAINS "health"` |
| Errors of the last 15 minutes | `level = ERROR AND timestamp >= now-15m` |
| Every service whose name starts with "pay" | `service = "pay*"` |
| Payment problems, any service | `service = "pay*" OR (message CONTAINS "payment" AND level != INFO)` |
| All logs of one trace | `trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"` |
| Errors with an exception type | `level = ERROR AND attr.exception.type = *` |
| Logs from an old version | `resource.service.version = "1.*" AND level = ERROR` |
{firstcol="40"}

The **Examples** buttons under the editor insert and run ready-made queries; **Syntax help** opens a summary of fields and operators.

### Autocomplete

While you type, the editor suggests what can come next: a field, an operator for that field, `AND` / `OR`, the levels, relative times, and the real **service**, **application** and **environment** names of the selected time range with their number of log lines. Use **↑ ↓** to move, **Enter** or **Tab** to insert, **Esc** to close, **Ctrl + Space** to open the suggestions. With an empty editor, the suggestions list your recent queries.

## Errors {#aql-errors}

An invalid query is **never run**: the faulty part is underlined, the message says what is wrong and at which column, and **Run query** stays disabled.

| Message | Fix |
|---|---|
| Missing AND / OR before "…" | Add `AND` or `OR` between the two conditions. |
| Unknown field "…" | Use a field from [Fields](#aql-fields), or `attr.` / `resource.` for an attribute. |
| Expected an operator after … | Add `=`, `!=`, `IN`, `CONTAINS`… after the field. |
| Level must be ERROR, WARN, INFO or DEBUG | Use one of the four levels. |
| Put the text in quotes | `CONTAINS` needs quoted text: `message CONTAINS "timeout"`. |
| Unclosed quote / Missing closing parenthesis | Close the `"` or the `(`. |
| > only works on timestamp | Comparisons are for `timestamp`; use `=` or `IN` elsewhere. |
| Write the time as "2026-11-05T14:30" (UTC) or now-15m | Use one of these time formats. |
| Too many … (max …) | See [Limits](#aql-limits). |
{firstcol="40"}

## Limits and performance {#aql-limits}

| Limit | Value |
|---|---|
| Query length | 2,000 characters |
| Conditions | 30 |
| Nested parentheses | 10 levels |
| Values in one `IN` list | 50 |
| Message or attribute searches (`message …`, `attr.…`, `resource.…`) | 5 |
{firstcol="50"}

Speed depends on what the query reads:

- **service, application, environment, level** only: answered from precomputed counts, usually well under a second, even over 7 days.
- **message** and **attributes**: every log line of the window is read. Over 24 h this takes about one to three seconds; over 7 days, several seconds. The newest results appear first and older ones load as you scroll. Narrow the time range or add a `service` / `level` condition to make it faster.

{{< callout type="warn" >}}
Counters for a message or attribute search read the live logs, while the totals of a plain search come from counts refreshed periodically. The two can differ by a few lines while logs are arriving.
{{< /callout >}}

## API {#aql-api}

The same language is available on the Query API (see the [Query API reference](../query-api/)):

| Endpoint | Path | Use |
|---|---|---|
| GET | `/api/logs?aql=…` | Log lines matching the query (with the usual window, paging and refresh parameters). |
| GET | `/api/logs/metrics?aql=…` | Counts and volume for the query. |
| POST | `/api/logs/aql/validate` | Checks a query without running it: `{"query": "…"}` → `{valid, conditions, error}`. |
| GET | `/api/logs/aql/suggest` | Autocomplete: field names, or the values of `field` with their counts. |
{mono="2"}

An invalid `aql` parameter returns **HTTP 400** with `{"code", "message", "position", "length"}`, and the query is not executed.
