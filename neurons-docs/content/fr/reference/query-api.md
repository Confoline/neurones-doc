---
title: Référence de l'API de requêtage Neurons APM (Swagger)
linkTitle: Référence de l'API
lede: L'API HTTP du service d'ingestion et de requêtage Neurons APM — comment s'authentifier, comment lire la documentation Swagger interactive, et chaque endpoint avec son rôle.
menus:
  ref:
    weight: 10
labels:
  api-overview: Présentation
  api-swagger: Swagger / OpenAPI
  api-auth: Authentification
  api-conventions: Conventions
---

## Présentation {#api-overview}

Le service Neurons APM (`apm-ingest`) expose une seule API HTTP, qui joue deux rôles :

- **Ingestion** — le Collecteur OpenTelemetry envoie traces, logs et métriques vers `/v1/*` au format OTLP/HTTP JSON.
- **Requêtage** — l'interface Neurons lit tout ce qu'elle affiche depuis `/api/*` : applications, services, traces, logs, RUM, transactions métier, événements, alerting, rétention, etc.

L'API expose **166 opérations** : 145 endpoints distincts, plus 21 alias `/rum/*` des endpoints `/api/rum/*` (voir [Conventions](#api-conventions)).

Cette page est une vue d'ensemble. Le contrat de référence, toujours à jour — paramètres, corps de requête et schémas de réponse — est la documentation Swagger générée par le service lui-même.

## Swagger / OpenAPI {#api-swagger}

| Chemin | Contenu |
|---|---|
| /docs | Swagger UI interactif : parcourir chaque endpoint, ses paramètres et son schéma de réponse, et tester des appels. |
| /redoc | Le même contrat au format ReDoc. |
| /openapi.json | Le document OpenAPI brut, à importer dans un générateur de client ou un outil d'API. |
{mono="1"}

Ces chemins sont relatifs à l'URL de base du service APM, par exemple `https://<APM_HOST>/docs`. Utiliser l'URL de base fournie par l'équipe plateforme Neurons pour votre environnement.

## Authentification {#api-auth}

Les appels sont authentifiés par un jeton dans un en-tête HTTP :

| Endpoints | En-tête | Jeton |
|---|---|---|
| `/api/*` (endpoints de requêtage), sauf ceux listés ci-dessous | `X-Neurones-Token` | Jeton de requêtage |
| `/v1/traces`, `/v1/logs`, `/v1/metrics` | `X-Neurones-Token` | Jeton d'ingestion |
| `/api/otel-collectors/agent/current`, `/api/otel-collectors/agent/report` | `X-Otel-Agent-Token` | Jeton propre à l'agent, renvoyé à l'enregistrement |
| `/api/webhooks/apm/transaction-alerts` | En-têtes de signature | Vérifié par la signature de la requête |
| `/api/`, `/api/health`, `/health`, `/metrics` | — | Aucun jeton (endpoints d'état et de supervision) |
{firstcol="30"}

`/api/otel-collectors/{config_id}/push` est une action d'administration interne, déclenchée depuis les écrans d'administration de Neurons.

Un jeton absent ou invalide renvoie **401**. Ne jamais placer un jeton dans une URL, dans le code source ou dans une application navigateur.

## Conventions {#api-conventions}

- **Chemin de base.** Les endpoints de requêtage sont sous `/api` ; les endpoints d'ingestion sous `/v1`.
- **Fenêtre de temps.** La plupart des endpoints de lecture prennent `minutes` (profondeur de la fenêtre) et `offset_minutes` (décalage de la fenêtre dans le passé). Certains endpoints de troubleshooting acceptent aussi des bornes de début/fin explicites. Les valeurs par défaut varient selon l'endpoint — voir Swagger.
- **Fenêtres longues.** Sur de longues périodes, les endpoints lisent des données pré-agrégées à l'heure ou au jour plutôt que les données brutes, ce qui les garde rapides.
- **Alias RUM.** Chaque endpoint `/api/rum/<chemin>` est aussi servi à `/rum/<chemin>`, avec le même comportement et la même authentification.
- **Erreurs.** Les erreurs sont renvoyées en JSON `{"detail": "..."}`. Des paramètres invalides renvoient **422** avec la liste des erreurs de validation. Lorsque le tampon d'ingestion est plein, les endpoints `/v1/*` renvoient **429** `{"error": "ingest buffer full"}` avec un en-tête `Retry-After: 1` : l'émetteur doit réessayer.

## État {#api-status}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/ | Description statique de l'API de requêtage. |
| GET | /api/health | Vérifie que la base analytique est joignable. |
{mono="2"}

## Catalogue {#api-catalog}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/apps | Applications vues dans la fenêtre, avec nombre de services, nombre de spans et dernière activité. |
| GET | /api/environments | Environnements vus dans la fenêtre, avec nombre de services et de requêtes. |
| GET | /api/apps/metrics | Débit, erreurs et latence moyenne par application. |
| GET | /api/apps/{application}/metrics/timeseries | Débit, erreurs et latence dans le temps pour une application. |
{mono="2"}

## Services {#api-services}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/services | Débit, erreurs, latence et dernière activité par service. |
| GET | /api/services/{service}/metrics | Débit, erreurs et latence dans le temps pour un service, par opération. |
| GET | /api/service-map | Dépendances entre services, avec nombre d'appels, taux d'erreur et latence. |
{mono="2"}

## Traces {#api-traces}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/traces | Recherche paginée de traces, avec filtres service, application, environnement, erreurs et texte. |
| GET | /api/traces/timeseries | Nombre de traces, erreurs et latence dans le temps, plus un histogramme des durées. |
| GET | /api/traces/filter-options | Valeurs disponibles pour les filtres de recherche de traces. |
| GET | /api/traces/{trace_id} | Une trace avec tous ses spans (vue en cascade). |
| GET | /api/traces/service-map | Graphe de dépendances des services, bases de données, hôtes externes, messagerie et caches. |
| GET | /api/traces/service-map/readiness | Niveau de complétude des données du graphe de dépendances pour la fenêtre. |
| GET | /api/traces/service-map/rules | Règles de résolution des services utilisées pour construire le graphe. |
| GET | /api/traces/service-map/visual-rules | Règles d'icône, de catégorie et de couleur appliquées aux nœuds du graphe. |
{mono="2"}

## Logs {#api-logs}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/logs | Recherche de logs, du plus récent au plus ancien, avec filtres service, trace, sévérité et texte. |
| GET | /api/logs/metrics | Volume de logs dans le temps, par sévérité. |
| POST | /api/logs/aql/validate | Vérifie une requête AQL sans l'exécuter (voir [AQL pour les logs](../aql/)). |
| GET | /api/logs/aql/suggest | Autocomplétion AQL : noms de champs, ou valeurs d'un champ avec leurs comptages de logs. |
{mono="2"}

## Base de données {#api-database}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/db-stats | Appels sortants vers les bases de données, regroupés par requête normalisée, avec nombre d'appels et durées. |
| GET | /api/db-metrics | Volume, latence et erreurs des appels base de données dans le temps. |
{mono="2"}

## Transactions métier {#api-bt}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/transactions/catalog | Transactions métier avec leurs réglages, leur groupe et leurs métriques sur la fenêtre. |
| GET | /api/transactions/entries | Opérations d'entrée vues dans la fenêtre. |
| GET | /api/transactions/flow-map | Services traversés par les traces d'une transaction métier. |
| POST | /api/transactions/bt-config | Renommer, exclure, mettre à la corbeille ou grouper une transaction métier. |
| POST | /api/transactions/bt-config/bulk | Appliquer la même modification à plusieurs transactions métier. |
| POST | /api/transactions/bt-config/purge | Supprimer définitivement les transactions métier mises à la corbeille. |
| GET | /api/transactions/config | Surcharges d'opérations par application (modèle de configuration antérieur). |
| POST | /api/transactions/config | Créer ou modifier une surcharge d'opération par application. |
| POST | /api/transactions/config/bulk | Appliquer la même surcharge à plusieurs opérations d'une application. |
| POST | /api/transactions/config/purge | Supprimer définitivement les surcharges d'opérations mises à la corbeille. |
| POST | /api/transactions/settings | Définir la durée de conservation de la corbeille d'une application. |
| POST | /api/transaction-groups | Créer un groupe de transactions métier. |
| POST | /api/transaction-groups/update | Renommer un groupe. |
| POST | /api/transaction-groups/delete | Supprimer un groupe et désaffecter ses membres. |
| GET | /api/transactions/{transaction_id}/notification | Réglages de notification d'une transaction métier. |
| POST | /api/transactions/{transaction_id}/notification | Créer les réglages de notification d'une transaction métier. |
| PUT | /api/transactions/{transaction_id}/notification | Remplacer les réglages de notification. |
| PATCH | /api/transactions/{transaction_id}/notification/status | Activer ou désactiver la notification. |
| POST | /api/transactions/{transaction_id}/notification/test | Envoyer une notification de test via le canal configuré. |
| GET | /api/transactions/{transaction_id}/notification/history | Historique d'envoi des notifications. |
{mono="2"}

## Règles de détection des transactions métier {#api-bt-rules}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/bt-detection-rules | Règles de détection, éventuellement pour une application ou un environnement. |
| POST | /api/bt-detection-rules | Créer une règle de détection. |
| POST | /api/bt-detection-rules/update | Modifier une règle de détection. |
| POST | /api/bt-detection-rules/delete | Supprimer une règle de détection. |
| POST | /api/bt-detection-rules/reorder | Définir les priorités des règles à partir d'une liste ordonnée. |
{mono="2"}

## Business Journeys {#api-journeys}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/business-journeys | Toutes les business journeys, avec leur nombre d'étapes. |
| POST | /api/business-journeys | Créer une journey et ses étapes ordonnées. |
| GET | /api/business-journeys/{journey_id} | Une journey avec ses étapes. |
| PUT | /api/business-journeys/{journey_id} | Modifier le nom, la description, l'état et les seuils d'une journey. |
| DELETE | /api/business-journeys/{journey_id} | Supprimer une journey et ses étapes. |
| GET | /api/business-journeys/{journey_id}/funnel | Conversion et abandon à chaque étape d'une journey. |
{mono="2"}

## Real User Monitoring (RUM) {#api-rum}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/rum/apps | Applications navigateur ayant envoyé des vues de page dans la fenêtre. |
| GET | /api/rum/overview | Temps de chargement des pages et statistiques des appels API pour une application. |
| GET | /api/rum/browser-breakdown | Vue d'ensemble enrichie des temps de navigation des applications monopages. |
| GET | /api/rum/web-vitals | Percentiles et évaluations LCP, INP, CLS, FCP et TTFB. |
| GET | /api/rum/page-load-distribution | Histogramme et percentiles des durées de chargement des pages. |
| GET | /api/rum/timeseries | Volume de vues de page et un indicateur vital dans le temps. |
| GET | /api/rum/breakdown | Vues de page et temps de chargement par navigateur, OS, appareil, URL ou pays. |
| GET | /api/rum/geo | Vues de page par localisation géographique. |
| GET | /api/rum/frontend-api-breakdown | Appels fetch/XHR/ressources du frontend, avec volume et latence. |
| GET | /api/rum/api-calls | Identique à `/api/rum/frontend-api-breakdown`. |
| GET | /api/rum/errors | Erreurs JavaScript et mobiles regroupées par message. |
| GET | /api/rum/page-transactions | Transactions métier backend déclenchées depuis une page. |
| GET | /api/rum/transaction-pages | Pages qui déclenchent une opération backend donnée. |
| GET | /api/rum/page-transaction-traces | Traces backend pour une page et une opération. |
| GET | /api/rum/journey | Flux de navigation de page en page à travers les sessions. |
| GET | /api/rum/sessions/{session_id}/journey | Chronologie d'une session utilisateur. |
| GET | /api/rum/frustration/summary | Nombre de clics rageurs, morts et en erreur. |
| GET | /api/rum/frustration/list | Signaux de frustration regroupés par élément de page. |
| POST | /api/rum/replay | Recevoir un lot de session replay depuis le navigateur. |
| GET | /api/rum/replay/list | Sessions utilisateur d'une application vues dans la fenêtre. |
| GET | /api/rum/replay/{session_id} | Événements de replay enregistrés d'une session. |
{mono="2"}

Chacun de ces endpoints est aussi disponible au même chemin sans le préfixe `/api` (`/rum/...`).

## Événements {#api-events}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/events | Recherche d'événements avec filtres application, service, statut, sévérité et période. |
| POST | /api/events | Créer un événement ; les événements identiques répétés sont dédupliqués. |
| GET | /api/events/count | Nombre d'événements correspondant aux filtres. |
| GET | /api/events/breakdown | Nombre d'événements par statut et sévérité. |
| GET | /api/events/monthly-summary | Événements par mois et par application sur une année. |
| GET | /api/events/{event_id} | Un événement. |
| POST | /api/events/{event_id}/ack | Acquitter un événement. |
| POST | /api/events/{event_id}/resolve | Résoudre un événement. |
| POST | /api/events/{event_id}/suppress | Mettre un événement de côté (suppressed). |
| POST | /api/events/bulk-update | Acquitter, résoudre ou mettre de côté plusieurs événements. |
| GET | /api/events/settings | Réglage de rétention des événements résolus. |
| PATCH | /api/events/settings | Modifier la rétention des événements résolus. |
| POST | /api/events/purge | Supprimer les événements résolus plus anciens que la rétention. |
| GET | /api/events/purge/preview | Nombre d'événements que la prochaine purge supprimerait. |
| GET | /api/events/purge/history | Purges passées. |
{mono="2"}

## Gestion d'événements externe {#api-event-management}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/apm/event-management/settings | Cible d'envoi vers l'outil de gestion d'événements externe (identifiants masqués). |
| PATCH | /api/apm/event-management/settings | Modifier la cible d'envoi. |
| POST | /api/apm/event-management/settings/test-draft | Envoyer un événement d'exemple vers une cible non enregistrée. |
{mono="2"}

## Règles de santé {#api-health-rules}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/health-rules | Règles de santé, éventuellement pour une application ou un environnement. |
| POST | /api/health-rules | Créer une règle de santé. |
| GET | /api/health-rules/{rule_id} | Une règle de santé. |
| POST | /api/health-rules/update | Modifier une règle de santé. |
| POST | /api/health-rules/delete | Supprimer une règle de santé. |
| POST | /api/health-rules/{rule_id}/evaluate | Évaluer immédiatement une règle sur une fenêtre de temps. |
| GET | /api/health-rules/{rule_id}/investigation-context | Événements liés à une règle, pour l'investigation. |
{mono="2"}

## Alerting {#api-alerting}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/apm/alerting/overview | Synthèse du tableau de bord d'alerting : règles, alertes actives et notifications. |
| GET | /api/apm/alerting/destinations | Destinations de notification (les secrets ne sont jamais renvoyés). |
| POST | /api/apm/alerting/destinations | Créer une destination : e-mail, webhook, Slack ou Microsoft Teams. |
| GET | /api/apm/alerting/destinations/{destination_id} | Une destination. |
| PATCH | /api/apm/alerting/destinations/{destination_id} | Modifier une destination. |
| DELETE | /api/apm/alerting/destinations/{destination_id} | Supprimer une destination utilisée par aucune politique. |
| POST | /api/apm/alerting/destinations/{destination_id}/test | Envoyer une notification de test vers une destination. |
| POST | /api/apm/alerting/destinations/test-draft | Tester une destination non enregistrée. |
| GET | /api/apm/alerting/templates | Modèles de notification. |
| POST | /api/apm/alerting/templates | Créer un modèle. |
| GET | /api/apm/alerting/templates/{template_id} | Un modèle. |
| PATCH | /api/apm/alerting/templates/{template_id} | Modifier un modèle. |
| DELETE | /api/apm/alerting/templates/{template_id} | Supprimer un modèle utilisé par aucune destination. |
| GET | /api/apm/alerting/policies | Politiques de notification. |
| POST | /api/apm/alerting/policies | Créer une politique reliant des déclencheurs à des destinations. |
| GET | /api/apm/alerting/policies/{policy_id} | Une politique. |
| PATCH | /api/apm/alerting/policies/{policy_id} | Modifier une politique. |
| DELETE | /api/apm/alerting/policies/{policy_id} | Supprimer une politique. |
{mono="2"}

## Incidents {#api-incidents}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/incidents | Incidents, du plus récent au plus ancien, éventuellement par statut. |
| POST | /api/incidents | Ouvrir manuellement un incident. |
| POST | /api/incidents/update | Modifier le statut, les notes ou la date de résolution d'un incident. |
{mono="2"}

## Troubleshoot {#api-troubleshoot}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/troubleshoot/contributors | Principaux services et opérations par traces, erreurs et latence. |
| GET | /api/troubleshoot/compare | Comparer la fenêtre avec la fenêtre précédente de même durée. |
| GET | /api/apm/troubleshoot/compare | Même comparaison, avec un filtre par opération. |
| GET | /api/apm/troubleshoot/slow-response-distribution | Requêtes réparties en normales, lentes, très lentes, bloquées et en erreur, dans le temps. |
| GET | /api/apm/troubleshoot/slow-traces | Traces d'une tranche de temps de réponse. |
| GET | /api/apm/troubleshoot/error-signatures | Erreurs regroupées par message normalisé, avec tendance et contributeurs. |
| GET | /api/apm/troubleshoot/context-drilldown | Filtres prêts à l'emploi pour ouvrir Traces, Errors ou Logs sur le même contexte. |
{mono="2"}

## Webhooks {#api-webhooks}

| Endpoint | Chemin | Rôle |
|---|---|---|
| POST | /api/webhooks/apm/transaction-alerts | Recevoir des alertes de transaction d'un système externe ; les requêtes sont vérifiées par signature. |
{mono="2"}

## Rétention des données {#api-retention}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/settings/retention/{area} | Réglage de rétention d'une zone de données (spans, logs, métriques, RUM, ...). |
| PATCH | /api/settings/retention/{area} | Modifier la rétention d'une zone de données. |
| POST | /api/settings/retention/{area}/purge | Supprimer immédiatement les données de la zone plus anciennes que la rétention. |
| GET | /api/settings/retention/{area}/usage | Nombre de lignes et taille disque estimée de la zone. |
| GET | /api/settings/retention/{area}/purge/history | Purges passées de la zone. |
{mono="2"}

## Source de données {#api-datasource}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /api/internal/datasource | Connexion active à la base analytique (sans mots de passe). |
| POST | /api/internal/datasource/reload | Basculer immédiatement sur la base analytique actuellement configurée. |
{mono="2"}

## Agents du Collecteur OpenTelemetry {#api-otel-collector}

| Endpoint | Chemin | Rôle |
|---|---|---|
| POST | /api/otel-collectors/agent/register | Premier enregistrement d'un agent du Collecteur ; renvoie son jeton d'agent. |
| GET | /api/otel-collectors/agent/current | La configuration du Collecteur que l'agent doit appliquer (jeton d'agent). |
| POST | /api/otel-collectors/agent/report | L'agent rend compte de l'application d'une configuration (jeton d'agent). |
| POST | /api/otel-collectors/{config_id}/push | Demander à un agent d'appliquer sa configuration immédiatement (action d'administration). |
{mono="2"}

## Ingestion (OTLP) {#api-ingest}

| Endpoint | Chemin | Rôle |
|---|---|---|
| POST | /v1/traces | Recevoir les traces du Collecteur OpenTelemetry (OTLP/HTTP JSON). |
| POST | /v1/logs | Recevoir les logs du Collecteur OpenTelemetry (OTLP/HTTP JSON). |
| POST | /v1/metrics | Accepter les exports de métriques ; les données ne sont pas stockées (Neurons calcule les métriques à partir des traces). |
{mono="2"}

{{< callout >}}
Les endpoints d'ingestion sont appelés par le Collecteur OpenTelemetry Neurons, pas par les applications : ils n'acceptent que l'OTLP/HTTP **JSON**. Les applications envoient leur télémétrie au Collecteur — voir les guides d'onboarding des applications.
{{< /callout >}}

## Exploitation du service {#api-ops}

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | /health | État du pipeline d'ingestion lui-même. |
| GET | /metrics | Métriques Prometheus du service d'ingestion. |
{mono="2"}
