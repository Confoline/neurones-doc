---
title: AQL — langage de requête avancé pour les logs
linkTitle: AQL pour les logs
lede: Rechercher dans les logs applicatifs avec des conditions sur le niveau, le service, le message, l'heure, la trace et les attributs, combinées avec AND, OR, NOT et des parenthèses, depuis le mode Requête AQL de l'écran Logs.
menus:
  ref:
    weight: 20
labels:
  aql-overview: Présentation
  aql-start: Premiers pas
  aql-fields: Champs
  aql-operators: Opérateurs
  aql-values: Valeurs
  aql-attributes: Attributs
  aql-combine: Combiner des conditions
  aql-filters: Filtres de la page
  aql-examples: Exemples
  aql-errors: Erreurs
  aql-limits: Limites et performances
  aql-api: API
---

## Présentation {#aql-overview}

L'écran Logs propose deux modes de recherche :

| Mode | À utiliser pour |
|---|---|
| **Basic search** | Une recherche texte, avec les filtres Level et Service. |
| **AQL query** | Plusieurs conditions à la fois, des alternatives (`OR`), des exclusions (`NOT`), des jokers, des bornes de temps et les attributs des logs ou des ressources. |
{firstcol="18"}

Le flux de logs, les compteurs (lignes trouvées, erreurs, warnings, services) et le graphique de volume affichent toujours le résultat de la **dernière requête exécutée**.

## Premiers pas {#aql-start}

1. Ouvrir **Logs** et choisir **AQL query** dans le sélecteur de mode.
2. Saisir une requête, par exemple :

   ```
   level IN (ERROR, WARN) AND service = "checkout" AND message CONTAINS "timeout"
   ```

3. Cliquer sur **Run query** ou appuyer sur **Ctrl + Entrée** (**Cmd + Entrée** sur macOS).

La requête est vérifiée pendant la saisie : une requête valide affiche **Valid query · N conditions** ; une requête invalide est soulignée et expliquée (voir [Erreurs](#aql-errors)). La requête exécutée est conservée dans l'URL de la page, qui peut donc être mise en favori ou partagée.

{{< callout >}}
**Edit as AQL** (en Basic search) écrit les filtres Basic actuels sous forme de requête AQL. Revenir à **Basic search** conserve la requête AQL : il suffit de rebasculer pour la reprendre.
{{< /callout >}}

## Champs {#aql-fields}

| Champ | Signification | Opérateurs |
|---|---|---|
| `service` | Nom du service | `=` `!=` `IN` `CONTAINS` |
| `application` | Application | `=` `!=` `IN` `CONTAINS` |
| `environment` | Environnement (prod, stg…) | `=` `!=` `IN` `CONTAINS` |
| `level` | `ERROR`, `WARN`, `INFO` ou `DEBUG` | `=` `!=` `IN` |
| `message` | Texte du message | `CONTAINS` `=` `!=` |
| `timestamp` | Heure du log | `>` `>=` `<` `<=` |
| `trace_id` | Identifiant de trace | `=` `!=` `IN` |
| `span_id` | Identifiant de span | `=` `!=` `IN` |
| `attr.<clé>` | Attribut du log (voir [Attributs](#aql-attributes)) | `=` `!=` `IN` `CONTAINS` |
| `resource.<clé>` | Attribut de la ressource (voir [Attributs](#aql-attributes)) | `=` `!=` `IN` `CONTAINS` |
{firstcol="22" mono="1"}

`level` couvre les écritures habituelles de chaque niveau : `ERROR` trouve aussi `ERR`, `FATAL`, `CRITICAL`, `SEVERE`…, ainsi que les logs qui ne portent qu'un numéro de sévérité OpenTelemetry (17 à 24 pour ERROR).

## Opérateurs {#aql-operators}

| Opérateur | Exemple | Trouve |
|---|---|---|
| `=` | `service = "checkout"` | Exactement cette valeur. Avec `*` : un joker (`service = "pay*"`). |
| `!=` | `environment != stg` | Toute autre valeur, **y compris les logs sans valeur**. |
| `IN ( , )` | `level IN (ERROR, WARN)` | Une des valeurs de la liste (50 au maximum). |
| `CONTAINS` | `message CONTAINS "timeout"` | Le texte apparaît n'importe où, sans tenir compte de la casse. Le texte doit être entre guillemets. |
| `>` `>=` `<` `<=` | `timestamp >= now-15m` | Logs après / avant une heure. Uniquement pour timestamp. |
{firstcol="16" mono="1"}

## Valeurs {#aql-values}

- **Avec ou sans guillemets** : `service = checkout` et `service = "checkout"` sont identiques. Les guillemets sont nécessaires pour les espaces et autres caractères spéciaux : `message CONTAINS "connection refused"`. Dans des guillemets, écrire `\"` pour un guillemet.
- **Joker** : `*` remplace n'importe quel texte (`service = "ms-vision*"`), sans tenir compte de la casse. `%` et `_` n'ont pas de rôle particulier.
- **Égalité exacte** (`=` sans `*`) : la casse compte ; utiliser le nom exact, ou le choisir dans les suggestions.
- **Heure** : `now`, `now-30s`, `now-15m`, `now-2h`, `now-1d`, ou une date et heure UTC `2026-11-05T14:30`.
- **Mots-clés** (`AND`, `OR`, `NOT`, `IN`, `CONTAINS`) et niveaux : la casse ne compte pas.

## Attributs {#aql-attributes}

Les conditions peuvent porter sur les attributs envoyés avec chaque log :

- `attr.<clé>` — attributs du log, par exemple `attr.exception.type`.
- `resource.<clé>` — attributs de la ressource qui l'a émis, par exemple `resource.service.version`, `resource.telemetry.sdk.language`.

| Requête | Trouve |
|---|---|
| `attr.exception.type = "ResourceExhausted"` | Cette valeur. |
| `attr.http.status_code IN (500, 503)` | Une de ces valeurs. |
| `resource.service.version = "1.*"` | Les versions 1.x. |
| `attr.exception.type CONTAINS "exhausted"` | La valeur contient ce texte. |
| `attr.user_id = *` | Les logs **qui ont** l'attribut. |
| `NOT attr.user_id = *` | Les logs **sans** l'attribut. |
{firstcol="44" mono="1"}

Les clés s'écrivent comme l'application les envoie (la casse compte) et peuvent contenir lettres, chiffres, `_`, `.` et `-` (128 caractères au maximum). Les valeurs d'attributs sont comparées comme du texte : `>` et `<` ne sont pas disponibles.

## Combiner des conditions {#aql-combine}

- `AND` : les deux conditions. `OR` : l'une ou l'autre. `NOT` : le contraire de la condition ou du groupe qui suit.
- Les parenthèses regroupent des conditions : `service = checkout AND (level = ERROR OR message CONTAINS "timeout")`.
- `AND` doit être écrit : `level = ERROR service = checkout` est une erreur (`AND` / `OR` manquant).
- Sans parenthèses, `NOT` s'applique d'abord, puis `AND`, puis `OR`.

## Filtres de la page {#aql-filters}

En mode AQL, la requête remplace les filtres Level et Service de Basic search. Ces éléments s'appliquent toujours, combinés à la requête par `AND` :

- la **plage de temps** (et une barre sélectionnée dans le graphique de volume) ;
- les sélecteurs **Application** et **Environnement** en haut de la page.

Les boutons de niveau du graphique de volume sont inactifs en mode AQL : mettre les niveaux dans la requête.

## Exemples {#aql-examples}

| Objectif | Requête |
|---|---|
| Erreurs et warnings qui parlent d'un timeout | `level IN (ERROR, WARN) AND message CONTAINS "timeout"` |
| Un service, sans les health checks | `service = "checkout" AND NOT message CONTAINS "health"` |
| Erreurs des 15 dernières minutes | `level = ERROR AND timestamp >= now-15m` |
| Tous les services dont le nom commence par « pay » | `service = "pay*"` |
| Problèmes de paiement, tous services | `service = "pay*" OR (message CONTAINS "payment" AND level != INFO)` |
| Tous les logs d'une trace | `trace_id = "4bf92f3577b34da6a3ce929d0e0e4736"` |
| Erreurs avec un type d'exception | `level = ERROR AND attr.exception.type = *` |
| Logs d'une ancienne version | `resource.service.version = "1.*" AND level = ERROR` |
{firstcol="40"}

Les boutons **Examples** sous l'éditeur insèrent et exécutent des requêtes toutes prêtes ; **Syntax help** ouvre un résumé des champs et opérateurs.

### Autocomplétion

Pendant la saisie, l'éditeur propose la suite possible : un champ, un opérateur adapté au champ, `AND` / `OR`, les niveaux, des heures relatives, et les vrais noms de **service**, **application** et **environnement** de la plage de temps avec leur nombre de lignes de logs. **↑ ↓** pour se déplacer, **Entrée** ou **Tab** pour insérer, **Échap** pour fermer, **Ctrl + Espace** pour ouvrir les suggestions. Éditeur vide : les suggestions listent vos requêtes récentes.

## Erreurs {#aql-errors}

Une requête invalide n'est **jamais exécutée** : la partie fautive est soulignée, le message dit ce qui ne va pas et à quelle colonne, et **Run query** reste désactivé.

| Message | Correction |
|---|---|
| Missing AND / OR before "…" | Ajouter `AND` ou `OR` entre les deux conditions. |
| Unknown field "…" | Utiliser un champ de la liste [Champs](#aql-fields), ou `attr.` / `resource.` pour un attribut. |
| Expected an operator after … | Ajouter `=`, `!=`, `IN`, `CONTAINS`… après le champ. |
| Level must be ERROR, WARN, INFO or DEBUG | Utiliser un des quatre niveaux. |
| Put the text in quotes | `CONTAINS` demande un texte entre guillemets : `message CONTAINS "timeout"`. |
| Unclosed quote / Missing closing parenthesis | Fermer le `"` ou la `(`. |
| > only works on timestamp | Les comparaisons sont réservées à `timestamp` ; ailleurs, utiliser `=` ou `IN`. |
| Write the time as "2026-11-05T14:30" (UTC) or now-15m | Utiliser un de ces formats d'heure. |
| Too many … (max …) | Voir [Limites](#aql-limits). |
{firstcol="40"}

## Limites et performances {#aql-limits}

| Limite | Valeur |
|---|---|
| Longueur de la requête | 2 000 caractères |
| Conditions | 30 |
| Parenthèses imbriquées | 10 niveaux |
| Valeurs dans une liste `IN` | 50 |
| Recherches sur le message ou les attributs (`message …`, `attr.…`, `resource.…`) | 5 |
{firstcol="50"}

La rapidité dépend de ce que lit la requête :

- **service, application, environment, level** uniquement : réponse à partir de comptages précalculés, en général bien en dessous d'une seconde, même sur 7 jours.
- **message** et **attributs** : chaque ligne de log de la période est lue. Sur 24 h, une à trois secondes environ ; sur 7 jours, plusieurs secondes. Les résultats les plus récents s'affichent d'abord, les plus anciens se chargent au défilement. Réduire la période ou ajouter une condition `service` / `level` accélère la recherche.

{{< callout type="warn" >}}
Les compteurs d'une recherche sur le message ou les attributs lisent les logs en direct, alors que les totaux d'une recherche simple viennent de comptages rafraîchis périodiquement. Les deux peuvent différer de quelques lignes pendant l'arrivée des logs.
{{< /callout >}}

## API {#aql-api}

Le même langage est disponible dans l'API de requêtage (voir la [référence de l'API](../query-api/)) :

| Endpoint | Chemin | Rôle |
|---|---|---|
| GET | `/api/logs?aql=…` | Lignes de logs qui correspondent à la requête (avec les paramètres habituels de période, de pagination et de rafraîchissement). |
| GET | `/api/logs/metrics?aql=…` | Comptages et volume pour la requête. |
| POST | `/api/logs/aql/validate` | Vérifie une requête sans l'exécuter : `{"query": "…"}` → `{valid, conditions, error}`. |
| GET | `/api/logs/aql/suggest` | Autocomplétion : noms de champs, ou valeurs de `field` avec leurs comptages. |
{mono="2"}

Un paramètre `aql` invalide renvoie **HTTP 400** avec `{"code", "message", "position", "length"}`, et la requête n'est pas exécutée.
