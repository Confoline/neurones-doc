---
title: Onboarding du RUM navigateur
linkTitle: RUM navigateur
lede: Ajouter le script RUM Neurons à vos sites web pour que Neurons montre ce que vivent les utilisateurs réels — vues de page, Web Vitals, erreurs frontend, sessions, signaux de frustration, champs métier, et les traces backend derrière chaque page.
menus:
  onboarding:
    parent: application-onboarding
    weight: 2
labels:
  install: Installer le script
  enable: Activer le site
  configure: Configurer l'application
  identity: Identité de l'application
  test-traffic: Générer du trafic de test
  verify: Vérifier dans Neurons
  security: Sécurité et confidentialité
  troubleshooting: Dépannage
  rollback: Désactivation / retour arrière
  custom-otel: Instrumentation OpenTelemetry personnalisée
---

## Présentation {#overview}

Le Real User Monitoring (RUM) navigateur mesure ce que les utilisateurs vivent réellement dans leur navigateur. L'instrumentation backend répond à *« que s'est-il passé dans l'application ? »* ; le RUM répond à *« qu'a vu l'utilisateur ? »*. Dans Neurons, la télémétrie navigateur apparaît dans l'écran **Browser Performance** :

| Télémétrie | Ce qu'elle indique |
|---|---|
| Vues de page | Quelles pages sont visitées et combien de temps elles mettent à se charger — pour les chargements complets et pour les changements de route des applications monopages (SPA), avec la décomposition du chargement (réseau, serveur, rendu). |
| Web Vitals | Les indicateurs standards de performance perçue — LCP, INP, CLS, FCP et TTFB — avec percentiles, évaluation bon / à améliorer / mauvais, et un score Apdex. |
| Erreurs frontend | Les erreurs JavaScript survenues dans le navigateur des utilisateurs, regroupées par message. |
| Sessions | La visite de chaque utilisateur sous forme de parcours chronologique entre les pages, et les enchaînements de pages les plus fréquents. |
| Actions utilisateur et signaux de frustration | Clics rageurs, clics morts et clics en erreur — signes d'une expérience dégradée même sans erreur technique visible. |
| Champs métier | Des valeurs comme l'utilisateur, la commande, le panier ou le produit, lues dans la page et attachées à chaque vue de page et appel API. |
| Navigateur, appareil et localisation | Répartitions par navigateur, système d'exploitation, type d'appareil et pays. |
| Corrélation avec le backend | Pour chaque page, les transactions métier backend qu'elle déclenche, et pour chaque trace, les spans navigateur et backend ensemble. |
{firstcol="26"}

Le RUM est **indépendant de l'onboarding backend** : une application peut avoir le traçage backend sans RUM, ou les deux. Activer ou désactiver le RUM ne modifie jamais la configuration backend. La corrélation avec les traces backend nécessite que le backend soit aussi instrumenté — voir les guides [PHP](../php/), [Java](../java/), [.NET](../dotnet/) et [Python](../python/).

**En bref :** vous ajoutez **une ligne de script** à vos pages. Tout le reste — ce qui est collecté, sur quels sites, avec quels champs métier — se règle dans Neurons, sous **APM → Browser apps**, sans retoucher le site.

## Architecture {#architecture}

{{< flow label="Comment la télémétrie navigateur arrive dans Neurons" >}}
app | Votre site web | Charge le script RUM Neurons avec la clé de votre entreprise
→ `GET /rum/config/<clé entreprise>`
platform | Neurons — configuration RUM | Trouve l'application correspondant au domaine du site (ou liste un nouveau site en attente d'approbation) et renvoie ses réglages
→ OTLP sur HTTP (JSON), `?app_id=`, sans jeton
platform | Neurons — entrée publique navigateur | N'accepte les données que des domaines de l'application, applique des limites de débit, résout la localisation du visiteur
→
platform | Browser Performance / RUM | Chargements de page, Web Vitals, erreurs, sessions, frustration, champs métier, traces frontend ↔ backend
{{< /flow >}}

- **Aucun jeton dans le navigateur, aucune route de relais à construire.** Le script ne porte que la **clé de votre entreprise**, publique par nature. Ce qui protège vos données, c'est la liste des **domaines** de chaque application : Neurons refuse les données navigateur de tout autre site.
- **Les nouveaux sites attendent une approbation.** La première fois que le script se charge sur un nouveau site, Neurons le liste dans **Waiting for approval**. Rien de ce qu'il envoie n'est conservé tant qu'un administrateur ne l'a pas activé.
- **Les réglages s'appliquent à chaud.** Le script relit régulièrement ses réglages (toutes les 5 minutes par défaut) : une modification dans Neurons atteint les visiteurs sans redéployer le site.
- **Corrélation des traces :** le script ajoute l'en-tête W3C `traceparent` aux appels vers votre API, de sorte qu'une action utilisateur et le travail backend qu'elle déclenche sont enregistrés dans la même trace distribuée.

## Prérequis {#prerequisites}

- Un accès au `<head>` HTML des pages du site — le gabarit de page, le gestionnaire de balises, ou le reverse proxy devant le site.
- Un compte Neurons. Tout utilisateur connecté peut consulter **Browser apps** ; activer des sites et modifier leurs réglages nécessite un **administrateur**.
- Si votre site a une **Content Security Policy**, la possibilité d'ajouter l'adresse de Neurons à `script-src` et `connect-src` — ou de servir le script depuis votre propre domaine (voir [Servir le script depuis votre propre domaine](#own-domain)).
- Le nom d'`application` et l'environnement utilisés par les services backend, pour regrouper le frontend avec son backend (voir [Identité de l'application](#identity)).
- Une décision explicite sur les fonctions optionnelles : session replay, nom d'utilisateur, champs métier contenant des données personnelles.

## Installer le script {#install}

### Copier la ligne

1. Dans Neurons, ouvrir **APM → Browser apps**.
2. Descendre jusqu'à **Your RUM script** et cliquer sur **Copy snippet**. La ligne ressemble à ceci :

   ```html
   <script src="https://<NEURONS_ADDRESS>/rum/v1/sdk.js" data-app-key="<COMPANY_KEY>" async></script>
   ```

3. Ajouter cette ligne dans le `<head>` de **toutes les pages** du site — dans le layout ou le gabarit de page, pour qu'elle soit présente partout.
4. Déployer le site.
{.steps}

- **La même ligne pour tous les sites de votre entreprise.** Vous ne créez pas l'application à l'avance : Neurons reconnaît chaque site par son domaine lorsque le script se charge.
- **Applications monopages :** l'ajouter dans l'`index.html` qui charge l'application. Les changements de route sont détectés automatiquement.
- **Gestionnaires de balises** (par exemple Google Tag Manager) : une balise *HTML personnalisé* déclenchée sur toutes les pages fonctionne, mais les premières vues de page d'une visite peuvent être mesurées plus tard qu'avec la ligne dans le HTML.
- `<NEURONS_ADDRESS>` est l'adresse publique de Neurons configurée par l'équipe plateforme (`RUM_PUBLIC_BASE_URL`). Si elle n'est pas configurée, la ligne utilise l'adresse avec laquelle vous avez ouvert Neurons — vérifiez que vos visiteurs peuvent l'atteindre.

{{< callout >}}
Le script ne casse jamais la page : si Neurons est injoignable, si le site n'est pas activé ou si le navigateur le bloque, la page continue de fonctionner et rien n'est envoyé.
{{< /callout >}}

### Servir le script depuis votre propre domaine {#own-domain}

Optionnel. Servir le script via votre propre site évite les bloqueurs de publicité et laisse votre Content Security Policy inchangée :

1. Sur votre serveur web ou reverse proxy, relayer toutes les requêtes sous `/neurons-rum/` vers `<NEURONS_ADDRESS>/`.
2. Charger le script depuis `/neurons-rum/rum/v1/sdk.js` au lieu de l'adresse de Neurons. Le script envoie alors ses données par le même chemin `/neurons-rum/`.
{.steps}

Exemple avec nginx :

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
**Localisation des visiteurs derrière votre proxy.** Neurons ne croit `X-Forwarded-For` que pour les proxys de confiance. Communiquez à l'équipe plateforme les adresses IP sortantes de votre proxy pour qu'elles soient ajoutées à la liste de confiance (`TRUSTED_PROXY_CIDRS`) ; sinon chaque visiteur est localisé à l'adresse de votre proxy.
{{< /callout >}}

## Activer le site {#enable}

### Vérifier et activer

1. Ouvrir une page du site dans un navigateur, pour que le script se charge une fois.
2. Dans **APM → Browser apps**, le site apparaît dans **Waiting for approval**, avec son domaine et le nombre de chargements du script.
3. Cliquer sur **Review and enable**.
4. Vérifier les réglages **General** — le nom et l'environnement sont devinés à partir du domaine (par exemple `staging` pour `staging.shop.example.com`). Les corriger pour qu'ils correspondent au backend (voir [Identité de l'application](#identity)).
5. Vérifier **Data collection**, et éventuellement [enregistrer un scénario](#business-fields) pour choisir des champs métier.
6. Cliquer sur **Enable RUM on &lt;application&gt;**.
{.steps}

Les visiteurs commencent à envoyer des données **en quelques minutes**. D'ici là — et pour tout site non activé — le script se charge mais rien n'est conservé.

Seul un administrateur peut activer, désactiver ou ignorer un site. Utilisez **Ignore** pour un site qui ne doit jamais être surveillé (poste d'un développeur, copie d'une page chez un partenaire) : il est masqué de la liste et ses données sont refusées. **Show ignored sites → Review again** le fait revenir.

### Ce qui arrive aux nouveaux sites

Sous **Your RUM script → New sites**, un administrateur choisit :

| Option | Effet |
|---|---|
| Wait for approval (par défaut) | Un nouveau site est listé dans **Waiting for approval** ; rien n'est collecté avant son activation. |
| Start right away | Un nouveau site est activé immédiatement avec les réglages par défaut : RUM standard uniquement — le session replay et les champs métier restent désactivés jusqu'à ce que vous les activiez. |
{firstcol="26"}

Au plus 200 sites peuvent attendre une approbation en même temps ; au-delà, les nouveaux sites ne sont pas listés tant que certains ne sont pas activés, ignorés ou supprimés.

### Statuts d'une application

| Statut | Script sur le site | Données |
|---|---|---|
| Waiting for approval | Se charge, ne collecte rien | Non conservées |
| Active | Collecte selon les réglages | Conservées |
| Disabled | Se charge, ne collecte rien | Non conservées |
| Ignored | Se charge, ne collecte rien | Refusées ; le site est masqué de la liste |
{firstcol="26"}

### Domaines

Une application n'accepte des données **que de ses domaines**. Sous **General → Domains**, vous pouvez :

- **Ajouter un domaine** : un hôte exact (`www.shop.example.com`), un hôte avec port (`shop.example.com:8443`), ou un joker couvrant tous les sous-domaines (`*.shop.example.com`).
- **Fusionner** un autre site détecté : ajouter le domaine d'un site déjà listé comme autre application demande une confirmation, puis le déplace dans celle-ci — par exemple `shop.example.com` et `www.shop.example.com`.
- **Retirer un domaine** : une application en garde au moins un.

## Configurer l'application {#configure}

Cliquer sur **Settings** à côté d'une application. Les modifications s'appliquent au clic sur **Save changes** (ou **Enable RUM** pour un site en attente d'approbation), et atteignent les visiteurs dans le délai de rafraîchissement de la configuration — 5 minutes par défaut.

### General

| Réglage | Usage |
|---|---|
| Application name | Regroupe le frontend avec ses services backend — utiliser **la même valeur `application` que le backend**. |
| Environment | `production`, `preprod`, `staging` ou `development` — la même valeur que le backend. |
| Service name | Identifie ce frontend dans Browser Performance, par exemple `shop-web`. |
| Domains | Les sites dont l'application accepte les données — voir [Domaines](#enable). |
{firstcol="26"}

### Data collection

| Module | Collecte | Par défaut |
|---|---|---|
| Page views and load times | Chargements complets et navigation dans l'application, avec les timings | Activé |
| Web vitals | LCP, INP, CLS, FCP, TTFB | Activé |
| API calls | Appels effectués par la page, reliés aux traces backend | Activé |
| JavaScript errors | Erreurs non interceptées et promesses rejetées | Activé |
| Frustration signals | Clics rageurs, clics morts, clics suivis d'une erreur | Activé |
| User name | Le nom de l'utilisateur connecté — donnée personnelle. L'identifiant utilisateur est toujours autorisé. | Désactivé |
{firstcol="26"}

**Visits monitored** (100 % par défaut) est la part des visites suivies par le script. La baisser réduit le volume de données sur les sites très fréquentés ; une visite est soit entièrement suivie, soit pas du tout.

### Champs métier {#business-fields}

Les champs métier ajoutent des valeurs comme `user.id`, `order.id`, `cart.total` ou `product.sku` à **chaque vue de page et appel API** d'une visite, pour filtrer et décomposer l'expérience par client, commande ou produit. Ils sont affichés dans le détail des traces et envoyés en attributs `biz.<nom>`.

Trois façons de les ajouter, sous **Business fields** :

**1. Suggérés à partir de vos visiteurs.** Une fois le RUM activé, le script remonte les **noms** des champs exposés par une page — jamais leurs valeurs. Après 20 visites (toutes les visites au début, puis 1 sur 10), Neurons suggère les plus utiles ; cliquez sur **Enable** pour ceux que vous voulez. Un champ doit être vu dans au moins 3 visites pour être suggéré. Un champ activé que les visites n'ont pas montré depuis 7 jours est signalé : le site a peut-être changé.

**2. Enregistrer un scénario.** Cliquer sur **Record a scenario**, choisir le site et la page de départ, puis **Open my site and record** :

1. Neurons ouvre votre site dans un nouvel onglet, avec un lien à usage unique valable 15 minutes.
2. Utiliser le site comme un visiteur : se connecter, naviguer, ajouter au panier, acheter.
3. De retour dans Neurons, choisir les champs à garder, les nommer et régler leur confidentialité.
{.steps}

L'enregistrement fonctionne même pendant que le site attend son approbation, mais le site doit déjà charger le script, et seul l'onglet ouvert par Neurons est enregistré.

**3. Ajouter manuellement.** Cliquer sur **Add manually** et choisir où la valeur est lue :

| Lu depuis | Vous indiquez | Exemple |
|---|---|---|
| Réponse serveur | L'URL de l'API (et la méthode), puis le champ dans la réponse JSON | `/api/carts/:id` → `total` |
| Événement dataLayer | Le nom de l'événement, puis le champ dans l'événement | `purchase` → `ecommerce.transaction_id` |
| Données de page (schema.org) | Le type et le champ schema.org | `Product.sku` |
| À l'écran | Le sélecteur CSS de l'élément | `.cart-summary .total` |
| Cookie, Local storage, Session storage | Le nom ou la clé (et un champ dans une valeur JSON) | `profile` → `tier` |
| Jeton de connexion (claim JWT) | L'emplacement du jeton, puis le claim | `local_storage:token` → `sub` |
| Balise meta | Le nom de la balise meta | `shop:country` |
| Adresse de la page | Le paramètre d'URL | `utm_source` |
| Variable JavaScript | Le chemin de la variable | `shopState.cart.count` |
| Clic | Le sélecteur CSS de l'élément cliqué (et un attribut) | `.add-to-cart` → `data-sku` |
{firstcol="30"}

Pour chaque champ, vous choisissez aussi :

- **Only on pages** (optionnel) : un motif de page comme `/checkout/*`.
- **Keep for** : *toute la visite* (par exemple l'utilisateur) ou *la page en cours* (par exemple le produit consulté).
- **Privacy** : *Automatic* hache les noms qui ressemblent à des données personnelles (e-mail, téléphone, nom, adresse…) et garde les autres ; ou forcer *Keep the value*, *Mask* (premier caractère uniquement) ou *Hash*.

{{< callout >}}
Les mots de passe, numéros de carte, jetons et autres secrets ne sont **jamais collectés**, quelle que soit la règle : un champ dont le nom ressemble à un secret ne peut pas devenir un champ métier, et le script refuse les valeurs qui ressemblent à un numéro de carte.
{{< /callout >}}

### API calls

| Réglage | Usage |
|---|---|
| Your API domains | Les appels vers ces origines comptent comme votre propre API. Les appels vers le domaine du site comptent toujours. |
| API path prefixes | Chemins qui identifient les appels API sur le domaine du site. Par défaut : `/api`. |
| Link to backend traces on | Origines qui reçoivent l'en-tête `traceparent`, pour relier l'action navigateur et la trace backend. Les appels vers le même domaine le reçoivent toujours. |
| Request / response headers to capture | Jusqu'à 20 noms d'en-têtes chacun, affichés sur l'appel API. Neurons suggère les noms vus sur vos appels API. |
| Body capture | Par route et méthode : capturer le corps de la requête et/ou de la réponse, expurgé puis tronqué à une limite de 1 à 16 Ko. |
{firstcol="30"}

{{< callout type="warn" >}}
N'ajoutez une origine à **Link to backend traces on** que si la configuration CORS de cette API autorise l'en-tête de requête `traceparent` — sinon le navigateur bloque les appels. Jamais capturés, quels que soient les réglages : `Authorization`, `Cookie`, `Set-Cookie`, et tout en-tête dont le nom contient *token*, *secret*, *key*, *auth* ou *session*.
{{< /callout >}}

### Session replay {#replay}

{{< callout type="warn" >}}
**Le session replay est désactivé par défaut et ne fait pas partie de l'onboarding standard.** Il enregistre ce que voient les visiteurs pour pouvoir rejouer une session. Les applications traitant des identifiants, des données financières ou juridiques, des documents d'identité ou toute autre information sensible nécessitent une revue de confidentialité avant son activation.
{{< /callout >}}

Une fois activé :

- **Sessions recorded** (10 % par défaut) — la part des visites suivies qui sont enregistrées.
- **Mask all page text** (activé par défaut) — remplace tous les textes de la page ; ne le désactiver qu'après la revue de confidentialité.
- Les champs de saisie sont **toujours masqués**.

### Advanced

| Réglage | Usage |
|---|---|
| Route patterns | Un par ligne, par exemple `/products/:slug`. Les URL sont regroupées selon ces motifs ; les autres sont regroupées automatiquement. |
| Name of your API in the service map | Le nœud vers lequel pointent les appels du navigateur. Par défaut : `<application>-api`. |
| Application type | `spa` (application monopage) ou `web`. |
| Wait for consent | Rien ne démarre avant que le visiteur accepte (RGPD). Indiquer le cookie de consentement et le texte qu'il doit contenir une fois accepté, par exemple `cookie_consent` contenant `analytics`. |
{firstcol="30"}

**Delete application** (administrateurs) supprime ses réglages et ses champs métier. Les données déjà collectées restent dans Neurons. Si le script est toujours sur le site, celui-ci réapparaît dans **Waiting for approval** à sa prochaine visite.

## Identité de l'application {#identity}

Deux valeurs identifient la télémétrie navigateur, à deux niveaux :

- **Le service name identifie le frontend.** Browser Performance liste et filtre les frontends par service name.
- **Le nom d'application regroupe les services.** Le même nom d'application sur le frontend et sur ses services backend les regroupe en une seule application logique.

```text
Frontend (Browser apps) :  application = shop   service name = shop-web   environment = production
Backend (OpenTelemetry) :  application = shop   service.name = shop-api   deployment.environment = production
```

Neurons appose ces valeurs sur tout ce que le script envoie : une page ne peut jamais écrire dans les données d'une autre application.

## Générer du trafic de test {#test-traffic}

Après l'activation du site :

1. Ouvrir le site depuis un vrai navigateur et recharger complètement la page.
2. Naviguer entre les pages (changements de route, pour une SPA).
3. Effectuer une action qui appelle le backend.
4. Déclencher une erreur JavaScript contrôlée.
5. Cliquer trois fois rapidement au même endroit, pour produire un clic rageur.
{.steps}

La télémétrie est envoyée par lots : attendre quelques secondes avant de vérifier dans Neurons.

## Vérifier dans Neurons {#verify}

1. Dans **APM → Browser apps**, l'application est **Active** et ses *Page views, 24 h* augmentent.
2. Dans les outils de développement du navigateur (Réseau), les requêtes vers `/v1/traces` renvoient **2xx** — un 403 signifie que le domaine manque dans l'application (voir [Dépannage](#troubleshooting)).
3. Le frontend apparaît dans **Browser Performance** sous son service name.
4. Les vues de page arrivent, pour le rechargement complet et pour les changements de route.
5. Les Web Vitals arrivent avec leur évaluation, et l'Apdex est calculé.
6. L'erreur JavaScript contrôlée apparaît.
7. Les sessions montrent les pages visitées, dans l'ordre.
8. Navigateur, OS et appareil sont renseignés, et la localisation correspond au visiteur — pas à un serveur.
9. L'appel backend apparaît dans la même trace que l'action navigateur, et la page liste les transactions métier qu'elle déclenche.
10. Si configurés : les champs métier apparaissent dans le détail des traces ; les signaux de frustration et le session replay apparaissent.
{.steps}

{{< callout >}}
Un onboarding n'est pas terminé tant qu'il n'a pas été validé sur l'environnement déployé, pas seulement en local.
{{< /callout >}}

## Sécurité et confidentialité {#security}

- **La clé d'entreprise est publique par nature** — elle figure dans chaque page. Elle permet seulement à un site de *demander* à être surveillé ; les données ne sont conservées que depuis les domaines d'une application **activée**, et Neurons applique des limites de débit par application et par visiteur.
- **Aucun jeton Neurons n'est jamais nécessaire dans le navigateur.** Ne mettez jamais de jeton d'ingestion ou de requêtage dans le code frontend.
- Les mots de passe, numéros de carte, jetons et secrets ne sont jamais collectés ; les en-têtes sensibles ne sont jamais capturés ; les corps capturés sont expurgés.
- Les champs métier dont le nom ressemble à une donnée personnelle sont **hachés** sauf choix contraire ; **User name** est désactivé par défaut.
- La découverte de champs envoie des **noms** de champs, jamais des valeurs.
- Utilisez **Wait for consent** lorsque le consentement du visiteur est requis avant toute mesure.
- Examiner la collecte des adresses IP et de la localisation des visiteurs au regard des exigences de confidentialité de l'application.
- Le session replay reste désactivé sauf approbation après une revue de confidentialité.

## Dépannage {#troubleshooting}

| Symptôme | Cause probable | Action |
|---|---|---|
| Le site n'apparaît jamais dans **Waiting for approval** | Le script n'est pas sur la page, est bloqué (bloqueur de publicité, Content Security Policy), ou l'adresse de Neurons n'est pas joignable depuis le navigateur | Vérifier le code source de la page et la console du navigateur ; ajouter l'adresse de Neurons à la CSP ou [servir le script depuis votre propre domaine](#own-domain). |
| Le site n'apparaît pas, et d'autres sites attendent déjà | 200 sites attendent déjà une approbation | Activer, ignorer ou supprimer des sites en attente. |
| `/v1/traces` renvoie **403** | Le domaine de la page ne fait pas partie des domaines de l'application | Ajouter le domaine, ou fusionner le site dans l'application. |
| `/v1/traces` renvoie **202** et rien n'apparaît | L'application n'est pas activée (en attente, désactivée ou ignorée) | Activer le RUM sur l'application. |
| `/v1/traces` renvoie **429** | Limite de débit atteinte pour l'application ou le visiteur | Baisser **Visits monitored** ; demander à l'équipe plateforme si les limites sont trop basses pour le trafic du site. |
| Activé, mais aucune donnée après plusieurs minutes | Les pages ouvertes avant l'activation gardent les anciens réglages jusqu'à leur prochain rafraîchissement | Recharger la page ; attendre jusqu'au délai de rafraîchissement de la configuration (5 minutes par défaut). |
| Deux applications pour un seul site | Le site est joignable sur plusieurs domaines (`shop.` et `www.shop.`) | Ajouter un domaine à l'autre application pour les fusionner. |
| Les appels API échouent avec une erreur CORS après l'activation | Une origine API est dans **Link to backend traces on** mais son CORS n'autorise pas `traceparent` | Autoriser l'en-tête sur l'API, ou retirer l'origine. |
| Spans navigateur et backend dans des traces séparées | L'origine API n'est pas dans **Link to backend traces on**, ou le backend n'est pas instrumenté | Ajouter l'origine (avec le CORS), et faire l'onboarding du backend. |
| Aucune suggestion de champ métier | Apprentissage non terminé (moins de 20 visites), ou RUM non activé | Attendre davantage de visites, ou enregistrer un scénario. |
| Un champ métier est signalé « Not seen by recent visits » | La page ou l'API a changé | Vérifier le sélecteur, l'URL ou le chemin de la règle. |
| Tous les visiteurs localisés au même endroit | Le script est servi par votre proxy et son adresse n'est pas de confiance | Demander à l'équipe plateforme d'ajouter les adresses sortantes de votre proxy à `TRUSTED_PROXY_CIDRS`. |
| Métrique Users vide | Pas de champ métier `user.id`, ou longue période | Ajouter un champ métier `user.id` ; utiliser une période plus courte. |

## Désactivation / retour arrière {#rollback}

Le RUM peut être arrêté sans toucher au site ni au traçage backend :

1. Dans **Browser apps → Settings**, cliquer sur **Disable RUM**. En quelques minutes le script cesse de collecter ; les données déjà collectées restent dans Neurons.
2. Pour ne plus charger le script du tout, retirer la ligne du site et le redéployer.
3. Si vous serviez le script depuis votre propre domaine, retirer la route `/neurons-rum/`.
4. Confirmer qu'aucune nouvelle télémétrie navigateur n'arrive dans Neurons, et que les traces backend continuent normalement.
{.steps}

## Instrumentation OpenTelemetry personnalisée {#custom-otel}

**La plupart des sites n'ont pas besoin de cette section.** Elle concerne les frontends qui utilisent déjà leur propre instrumentation navigateur OpenTelemetry, ou qui ne peuvent pas charger le script Neurons. Vous construisez alors la télémétrie vous-même, selon le contrat ci-dessous, et l'envoyez à Neurons par une route de relais qui ajoute le jeton d'ingestion. Les applications instrumentées ainsi ne sont pas listées dans **Browser apps** et ne s'y configurent pas.
### Installer les paquets

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

| Paquet | Rôle |
|---|---|
| @opentelemetry/sdk-trace-web, sdk-trace-base | Fournisseur de traceurs et processeur de spans par lots |
| @opentelemetry/resources, semantic-conventions | Attributs de ressource (`service.name`, `application`, ...) |
| @opentelemetry/context-zone | Conserve le span actif à travers les callbacks asynchrones |
| @opentelemetry/instrumentation-fetch | Un span par appel `fetch`, et injection de `traceparent` |
| @opentelemetry/instrumentation-xml-http-request | La même chose pour `XMLHttpRequest` — à ajouter si l'application utilise XHR |
| @opentelemetry/instrumentation-document-load | Spans du chargement initial de la page, avec les timings de navigation |
| @opentelemetry/exporter-trace-otlp-http | Envoie les spans en OTLP/HTTP JSON |
| web-vitals | Mesure LCP, INP, CLS, FCP et TTFB |
{firstcol="30" mono="1"}

### Initialiser l'instrumentation navigateur

1. **Initialiser en premier.** Importer la configuration RUM dès la première ligne du point d'entrée de l'application, pour que l'instrumentation soit active avant le premier appel réseau.
2. **Enregistrer le gestionnaire de contexte.** Passer `ZoneContextManager` à `provider.register()` — installer `@opentelemetry/context-zone` seul ne fait rien.
3. **Exclure les endpoints de télémétrie** de l'instrumentation Fetch/XHR, pour que les envois de télémétrie ne créent pas leurs propres spans.
4. **Ne jamais casser la page.** Encapsuler l'initialisation — idéalement chaque fonctionnalité — dans son propre `try/catch`, et protéger `crypto.randomUUID()`, indisponible dans un contexte non sécurisé (HTTP). Un RUM en échec doit laisser l'application fonctionner.
5. **Un seul interrupteur.** Faire dépendre le RUM d'un seul réglage de build, pour pouvoir le désactiver par une reconstruction.
6. **Propager le contexte de trace.** Les appels API de même origine reçoivent `traceparent` automatiquement. Pour une API sur une autre origine, la lister dans l'option `propagateTraceHeaderCorsUrls` de l'instrumentation Fetch et autoriser l'en-tête `traceparent` dans la configuration CORS de cette API.

Initialisation minimale, à adapter à votre outil de build et à votre framework :

```js
// rum.js — importé dès la première ligne du point d'entrée de l'application
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { DocumentLoadInstrumentation } from '@opentelemetry/instrumentation-document-load';

const RUM_ENDPOINT = '/v1/traces'; // endpoint d'ingestion RUM de même origine ; vide = RUM désactivé

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
    // le RUM ne doit jamais casser l'application
  }
}
```

### Implémenter la télémétrie navigateur Neurons {#implement}

{{< callout type="warn" >}}
**L'initialisation ci-dessus ne suffit pas à alimenter Browser Performance.** Le SDK Web OpenTelemetry standard crée des spans génériques (chargement du document, appels `fetch`). Il ne crée pas la télémétrie navigateur propre à Neurons décrite ci-dessous — le script RUM Neurons, lui, la crée. Avec votre propre instrumentation, ces signaux doivent être implémentés par l'application, en suivant le contrat ci-dessous.
{{< /callout >}}

L'application doit implémenter :

| Signal | À implémenter |
|---|---|
| Vues de page complètes | Transformer le chargement initial de la page en span `page-view` avec `nav.type=hard` et les timings de chargement. |
| Vues de page SPA | Créer un nouveau span `page-view` avec `nav.type=soft` à chaque changement de route côté client, et le garder actif pendant le démarrage des appels API de la route. |
| Web Vitals | Transformer chaque mesure `web-vitals` en span `web-vital` avec son nom, sa valeur et son évaluation. |
| Sessions | Générer un `session.id` et le poser sur chaque span. |
| Erreurs navigateur | Intercepter les erreurs JavaScript et les rejets de promesse non gérés, et les enregistrer en spans avec `rum.kind=app-error` (ou en enregistrements de log). |
| Classification des appels API | Marquer les spans `fetch`/XHR des API de l'application avec `api.kind`, et définir une `api.route` normalisée. |
| Signaux de frustration | Détecter les clics rageurs, morts et en erreur et les enregistrer en spans avec `frustration.type`. |
{firstcol="26"}

### Télémétrie navigateur attendue par Neurons {#telemetry}

Neurons alimente les écrans Browser Performance à partir de noms de spans et d'attributs précis. Un nom erroné n'est pas rejeté — les données manquent simplement dans les écrans.

#### Vues de page

| Élément | Contrat |
|---|---|
| Nom du span | `page-view` (exact) |
| nav.type | `hard` pour un chargement complet, `soft` pour un changement de route SPA |
| Page | `page.path`, `page.url` |
| Timings | Attributs `pl.*` — voir [Timings de chargement](#page-load-timings) |
{firstcol="26" mono="1"}

- Pour une SPA, un nouveau span `page-view` doit être créé à **chaque changement de route**, avec `nav.type=soft`, `pl.render_ms` (temps jusqu'au rendu suivant) et `pl.soft_ms`.
- **Route API total, Route backend total et Data wait** sont calculés en joignant un `page-view` soft avec les appels API navigateur **de la même trace**. Le span page-view soft doit donc être actif — ou un ancêtre — lorsque les appels API de la route démarrent ; les appels API démarrés en dehors ne sont pas comptés pour cette route.
- **Data wait** utilise `pl.data_wait_ms` ou `route.data_wait_ms` s'ils sont présents, et à défaut `pl.backend_ms`.
- Lorsque `pl.total_ms` est absent, la durée du span est utilisée.
- Les étapes de Business Journey de type `rum_page` sont comptées à partir des spans `page-view` et de leur `page.path` — voir [Business Journeys](../../#bj).

#### Timings de chargement {#page-load-timings}

Toutes les valeurs sont en millisecondes.

| Attribut | Signification |
|---|---|
| pl.total_ms | Temps total de chargement de la page |
| pl.backend_ms, pl.frontend_ms | Part serveur et part navigateur du chargement (`pl.frontend_ms` est déduit comme total − backend s'il est absent) |
| pl.ttfb_ms, pl.first_byte_ms | Temps jusqu'au premier octet (`pl.first_byte_ms` reprend `pl.ttfb_ms` par défaut) |
| pl.dns_ms, pl.tcp_ms, pl.tls_ms | Résolution DNS, connexion TCP, négociation TLS |
| pl.request_ms, pl.response_download_ms | Attente de la requête, téléchargement de la réponse |
| pl.dom_interactive_ms, pl.dom_content_loaded_ms, pl.dom_complete_ms | Étapes du DOM |
| pl.dom_processing_ms | Traitement du DOM (`domComplete − responseEnd` s'il est absent) |
| pl.load_event_ms | Durée du gestionnaire de l'événement `load` |
| pl.render_ms | Temps jusqu'au rendu (`view.render_ms` est aussi accepté) |
| pl.soft_ms | Durée d'un changement de route SPA |
| pl.data_wait_ms, route.data_wait_ms | Optionnels : temps d'attente des données d'une route SPA |
{firstcol="30" mono="1"}

Au lieu de valeurs `pl.*` calculées, un span `page-view` complet peut porter les champs bruts **Navigation Timing** du navigateur ; Neurons en déduit les timings lorsque l'attribut `pl.*` correspondant est absent :

| Champs bruts (aussi acceptés avec le préfixe `navigation.`) | Timing déduit |
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

#### Web Vitals et Apdex

| Élément | Contrat |
|---|---|
| Nom du span | `web-vital` (exact) |
| wv.name | `LCP`, `INP`, `CLS`, `FCP` ou `TTFB` |
| wv.value | LCP, INP, FCP, TTFB en **millisecondes** ; CLS en **score sans unité** |
| wv.rating | Exactement `good`, `needs-improvement` ou `poor` — les valeurs émises par la bibliothèque `web-vitals` |
{firstcol="26" mono="1"}

{{< callout type="warn" >}}
Sans `wv.rating`, les valeurs des Web Vitals restent affichées, mais les répartitions bon / à améliorer / mauvais restent vides et l'**Apdex** de Browser Performance n'est pas calculé.
{{< /callout >}}

L'**Apdex** de Browser Performance est calculé à partir des évaluations de **LCP, INP et CLS** uniquement :

```text
Apdex = (good + 0,5 × needs-improvement) / total
```

FCP et TTFB sont affichés comme Web Vitals mais ne contribuent pas à l'Apdex. Seuils affichés par Neurons :

| Indicateur | Bon | À améliorer | Mauvais | Dans l'Apdex |
|---|---|---|---|---|
| LCP | ≤ 2500 ms | ≤ 4000 ms | > 4000 ms | Oui |
| INP | ≤ 200 ms | ≤ 500 ms | > 500 ms | Oui |
| CLS | ≤ 0,1 | ≤ 0,25 | > 0,25 | Oui |
| FCP | ≤ 1800 ms | ≤ 3000 ms | > 3000 ms | Non |
| TTFB | ≤ 800 ms | ≤ 1800 ms | > 1800 ms | Non |
{mono="1"}

#### Appels API

- Seuls les spans **CLIENT** (les spans `fetch`/XHR) comptent comme appels API navigateur.
- Un span CLIENT est classé comme **appel API** lorsqu'il porte `api.kind` (ou un `rum.kind=api-call` explicite).
- Un span CLIENT avec une URL ou une route mais sans classification API est traité comme un **appel de ressource**.
- La route affichée est résolue à partir de `api.route`, puis `url.path`, puis `http.route`, puis `http.target`. Définir une `api.route` normalisée (identifiants remplacés, ex. `/api/orders/:id`) pour que les appels se regroupent correctement.

#### Erreurs navigateur

Un span navigateur est compté comme erreur JavaScript **uniquement lorsqu'il porte `rum.kind=app-error`** :

- le nom de span `app.error` seul ne **suffit pas** ;
- un statut de span ERROR seul ne **suffit pas** ;
- les attributs `exception.*` ne sont **pas** utilisés pour les erreurs navigateur.

| Attribut | Contenu |
|---|---|
| rum.kind | `app-error` (requis) |
| error.type | Type d'erreur, ex. `TypeError` |
| error.message | Message d'erreur — s'il est absent, le nom du span sert de message |
| error.stack | Pile d'appels |
| page.path | Page où l'erreur s'est produite |
{firstcol="26" mono="1"}

Les erreurs peuvent aussi être envoyées en **enregistrements de log OTLP** : un enregistrement de log est compté comme erreur navigateur lorsqu'il porte `rum.kind=js-error` ou `rum.kind=app-error`, avec les mêmes attributs `error.*`. Cela nécessite une route de relais `/v1/logs` — voir [Route de relais](#forwarding-route).

#### Signaux de frustration

| Attribut | Contenu |
|---|---|
| frustration.type | `rage_click`, `dead_click` ou `error_click` |
| target.selector, target.text | L'élément cliqué |
| click.x, click.y | Coordonnées du clic |
| page.url | Page courante |
| session.id | Requis — les signaux sans cet attribut ne sont pas enregistrés |
{firstcol="26" mono="1"}

#### Sessions et utilisateurs

- `session.id` est **requis** pour les sessions, les parcours, le replay et les signaux de frustration. Neurons regroupe la télémétrie selon la valeur reçue : l'application décide de la portée (par exemple un identifiant par onglet, conservé dans `sessionStorage`).
- La chronologie d'une session remonte jusqu'à 30 jours.
- La métrique **Users** compte les valeurs distinctes de `user.id` (ou de `user.name` si `user.id` est absent) sur les vues de page. Sans identification des utilisateurs, elle reste vide. Sessions et Users ne sont pas disponibles sur les longues périodes servies à partir de données agrégées.
- `user.id` et `user.name` sont des données personnelles — voir [Sécurité et confidentialité](#security).

### Route de relais {#forwarding-route}

**Pourquoi c'est nécessaire.** Le navigateur ne peut pas envoyer sa télémétrie directement à Neurons : Neurons exige un jeton, et tout ce qui est placé dans le code du navigateur est visible par chaque visiteur. Le navigateur envoie donc sa télémétrie à **votre propre site web**, et votre serveur web la transmet à Neurons en ajoutant le jeton au passage :

```text
Navigateur ──POST https://shop.example.com/v1/traces──▶ Votre serveur web ──ajoute jeton + IP du visiteur──▶ Neurons
           (sans jeton, même site)                      (route de relais)
```

Cette route de relais s'ajoute une seule fois, sur le serveur web ou le reverse proxy qui sert déjà le frontend.

#### Étape 1 — Choisir les routes nécessaires

| Route sur votre site | Nécessaire quand | Jeton à ajouter |
|---|---|---|
| /v1/traces | **Toujours** | Jeton d'ingestion |
| /v1/logs | Uniquement si l'application envoie les erreurs JavaScript en enregistrements de log | Jeton d'ingestion |
| /rum/replay | Uniquement si le session replay est approuvé | Jeton d'ingestion |
{firstcol="26" mono="1"}

La plupart des applications n'ont besoin que de `/v1/traces`.

#### Étape 2 — Obtenir les valeurs auprès de l'équipe plateforme Neurons

- `<NEURONES_INGEST_URL>` — l'adresse du service d'ingestion Neurons pour votre environnement.
- Le **jeton d'ingestion** — le même jeton pour toutes les routes.

#### Étape 3 — Ajouter les routes de relais à votre serveur web

Chaque route fait trois choses :

1. **Relayer** la requête vers le même chemin sur `<NEURONES_INGEST_URL>`.
2. **Ajouter le jeton** dans l'en-tête `X-Neurones-Token`.
3. **Transmettre l'adresse IP du visiteur** dans `X-Forwarded-For` et `X-Real-IP` — Neurons s'en sert pour le pays et la ville du visiteur.

Exemple avec nginx (remplacer les valeurs entre chevrons ; garder le jeton hors du contrôle de version, par exemple en l'injectant depuis l'environnement du serveur au démarrage) :

```nginx
# Toujours
location /v1/traces {
    proxy_pass         <NEURONES_INGEST_URL>/v1/traces;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Neurones-Token  <NEURONES_INGEST_TOKEN>;
}

# Uniquement si les erreurs JavaScript sont envoyées en logs
location /v1/logs {
    proxy_pass         <NEURONES_INGEST_URL>/v1/logs;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Neurones-Token  <NEURONES_INGEST_TOKEN>;
}

# Uniquement si le session replay est approuvé
location /rum/replay {
    proxy_pass         <NEURONES_INGEST_URL>/rum/replay;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Neurones-Token  <NEURONES_INGEST_TOKEN>;
}
```

Avec un autre serveur web (Apache, IIS, une API gateway) ou une route de votre application backend, appliquer les trois mêmes règles.

#### Étape 4 — Tester la route

Depuis n'importe quelle machine, envoyer un export de traces vide vers **votre site** (pas vers Neurons). Rien n'est enregistré :

```bash
curl -i -X POST https://<YOUR_FRONTEND_HOST>/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

| Réponse | Signification |
|---|---|
| 200 | La route fonctionne et le jeton est accepté. |
| 401 | La route atteint Neurons, mais le jeton est absent ou incorrect. |
| 404 | La route n'est pas configurée sur votre serveur web. |
| 502 / 504 | Votre serveur web ne parvient pas à joindre `<NEURONES_INGEST_URL>`. |
{firstcol="26"}

#### Étape 5 — Pointer l'instrumentation navigateur vers la route

Utiliser le chemin de même origine comme URL de l'exportateur : `/v1/traces` (comme dans l'exemple d'initialisation ci-dessus). Le navigateur n'a jamais besoin de l'adresse de Neurons ni d'aucun jeton.

{{< callout >}}
La route de relais n'est nécessaire que pour une instrumentation personnalisée. Le script RUM Neurons envoie ses données directement à Neurons, sans jeton — voir [Installer le script](#install).
{{< /callout >}}

#### Géolocalisation

Il n'y a pas de géolocalisation côté client. Neurons résout pays, région, ville et coordonnées à partir de l'adresse IP du visiteur, et écrase tout attribut `geo.*` envoyé par le navigateur. `X-Forwarded-For` et `X-Real-IP` ne sont crus que si la requête vient d'un proxy de confiance pour Neurons (`TRUSTED_PROXY_CIDRS`) : communiquez à l'équipe plateforme les adresses sortantes de votre serveur de relais, sinon chaque visiteur est localisé à l'adresse de ce serveur.

### Envoi du session replay {#replay-upload}

Le session replay suit les mêmes règles de confidentialité qu'avec le script Neurons — voir [Session replay](#replay). Une fois approuvé, un enregistreur comme `@rrweb/record` envoie des lots vers `/rum/replay` (par la route de relais, avec le jeton d'ingestion) :

| Champ | Contenu |
|---|---|
| app | Le **`service.name` du frontend** (ex. `shop-web`) — pas la valeur `application` |
| session_id | Même valeur que l'attribut de span `session.id` |
| page_view_id | Identifiant de la vue de page |
| sequence_number | Compteur de lots, à partir de 0 |
| compressed_events | Base64 du JSON compressé en gzip (`{ events, metadata }`, ou tableau simple d'événements rrweb) |
| content_encoding | `gzip` ou `identity` |
| reason, trigger_reason, trigger_timestamp | Optionnels : motif d'envoi du lot ; premier événement notable de la session |
{firstcol="26" mono="1"}

Les sessions de replay sont associées à la télémétrie navigateur par le `service.name` du frontend et le `session.id` : si `app` ne correspond pas au `service.name` du frontend, les replays ne sont pas reliés aux sessions ni aux signaux de frustration de ce frontend.

Les champs inconnus sont rejetés en **422**. Limites de taille par défaut : 2 Mio compressés et 25 Mio décompressés par lot. Configurer l'enregistreur pour masquer la valeur de chaque champ de saisie et bloquer les éléments qui ne doivent jamais être enregistrés.

### Attributs de ressource et de span {#otel-attributes}

Attributs de ressource, définis une seule fois à l'initialisation du SDK — `application`, `service.name` et `deployment.environment` suivent les mêmes règles que dans [Identité de l'application](#identity) :

| Attribut | Requis | Remarques |
|---|---|---|
| telemetry.sdk.language = webjs | **Oui** | Identifie les données comme du RUM navigateur. Sans lui, le frontend n'apparaît pas dans Browser Performance. |
| service.name | Oui | Identifie le frontend dans Browser Performance, ex. `shop-web`. C'est aussi la valeur `app` du session replay. |
| application | Oui | **La même valeur que les services backend**, pour que le frontend et son backend soient regroupés en une seule application. |
| deployment.environment | Oui | La même valeur que le backend, ex. `production`. |
| app.type | Non | `spa` ou `mpa`. S'il est absent, Neurons le déduit de `nav.type` : une navigation soft signifie SPA, des navigations hard uniquement signifient MPA. |
{firstcol="30" mono="1"}

#### Attributs sur chaque span

Neurons les lit sur chaque **span**, pas sur la ressource — les poser sur chaque span créé ou enrichi par l'instrumentation :

| Attribut | Remarques |
|---|---|
| session.id | **Requis** pour les sessions, les parcours, le replay et les signaux de frustration — voir [Sessions et utilisateurs](#telemetry). |
| page.path, page.url | La page courante. |
| browser.name, os.name, device.type | Dimensions de répartition — `device.type` : `desktop`, `mobile` ou `tablet`. |
| user.id, user.name | Optionnels, uniquement après connexion et après approbation — données personnelles. `user.id` alimente la métrique Users. |
{firstcol="30" mono="1"}

### Dépannage de l'instrumentation personnalisée

| Symptôme | Cause probable | Action |
|---|---|---|
| `/v1/traces` renvoie 401 | La route de relais n'ajoute pas le jeton d'ingestion, ou en ajoute un mauvais | Vérifier l'en-tête de la route et la valeur du jeton. |
| `/rum/replay` renvoie 401 alors que les traces fonctionnent | La route de replay ajoute un autre jeton que le jeton d'ingestion | Utiliser le jeton d'ingestion sur toutes les routes. |
| `/rum/replay` renvoie 422 | Champ inconnu, `content_encoding` incorrect, ou lot trop volumineux | N'envoyer que les champs documentés ; utiliser `gzip` ou `identity` ; respecter les limites. |
| Replays non reliés aux sessions | Le `app` du replay diffère du `service.name` du frontend | Envoyer le `service.name` du frontend comme `app`. |
| Frontend absent de Browser Performance | `telemetry.sdk.language=webjs` absent, ou aucun span `page-view` | Vérifier les attributs de ressource et implémenter les vues de page (voir [Implémenter la télémétrie navigateur Neurons](#implement)). |
| Erreurs JavaScript absentes | Spans d'erreur sans `rum.kind=app-error` (un nom `app.error` ou un statut ERROR seuls ne suffisent pas) | Définir `rum.kind=app-error` et les attributs `error.*`. |
| Web Vitals affichés mais sans évaluations ni Apdex | `wv.rating` absent ou différent de `good` / `needs-improvement` / `poor` | Envoyer l'évaluation émise par la bibliothèque `web-vitals`. |
| Appels API listés comme appels de ressource | `api.kind` absent des spans d'API | Définir `api.kind` et une `api.route` normalisée. |
| Route API total / backend total / Data wait vides | Appels API hors de la trace du `page-view` soft | Garder le span page-view soft actif pendant le démarrage des appels API de la route. |
| Sessions, replay ou signaux de frustration vides | `session.id` absent des spans | Poser `session.id` sur chaque span. |
| Spans navigateur et backend dans des traces séparées | `traceparent` non envoyé, ou backend non instrumenté | Vérifier l'instrumentation Fetch ; pour une API cross-origin, `propagateTraceHeaderCorsUrls` et CORS. |
| Répartitions à « unknown » | `browser.name` / `os.name` / `device.type` posés uniquement sur la ressource | Les poser sur chaque span. |
| Frontend regroupé à part de son backend | Valeurs `application` différentes | Utiliser la même valeur `application` des deux côtés. |
| La page ne se charge plus, en production uniquement | Initialisation RUM non protégée, ex. `crypto.randomUUID()` en HTTP | Protéger la génération d'identifiants ; encapsuler chaque fonctionnalité RUM dans un `try/catch`. |
| Un paquet est installé mais sans effet | Jamais importé ou enregistré (ex. `ZoneContextManager`) | Vérifier le code RUM, pas seulement `package.json`. |

### Désactiver l'instrumentation personnalisée

1. Désactiver l'interrupteur RUM, ou retirer l'import RUM du point d'entrée de l'application.
2. Reconstruire et redéployer le frontend — l'instrumentation personnalisée fait partie du bundle JavaScript, une modification côté serveur seule ne la désactive pas.
3. Retirer les routes de relais du serveur web.
{.steps}
