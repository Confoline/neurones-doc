---
title: Introduction
part: intro
weight: 1
labels:
  flow: Comment les données arrivent
---

## Qu'est-ce que Neurons ? {#quest}

Neurons est une plateforme de surveillance de performance applicative (Application Performance Monitoring). Elle collecte automatiquement les traces, les journaux (logs) et les mesures de performance émis par vos applications, les stocke dans un entrepôt de données unique, puis les transforme en tableaux de bord exploitables : santé des services, transactions métier, expérience des utilisateurs finaux, et alertes.

L'objectif est de répondre à trois questions que toute équipe qui exploite une application se pose en permanence : est-ce que ça fonctionne normalement en ce moment, qu'est-ce qui a changé quand un problème est apparu, et jusqu'où puis-je remonter dans le temps pour comprendre un incident passé.

## Comment les données arrivent dans la plateforme {#flow}

Neurons reçoit deux types de télémétrie, par deux entrées : le **backend** (vos applications et services, instrumentés avec OpenTelemetry) et les **navigateurs** des personnes qui utilisent vos sites web (Browser RUM). Les deux aboutissent dans le même entrepôt de données.

### Depuis vos applications

{{< flow label="Comment la télémétrie backend arrive dans Neurons" >}}
app | Votre application | SDK ou agent OpenTelemetry : traces et logs
→ OTLP
platform | Collecteur OpenTelemetry Neurons | Regroupe les données, réessaie si besoin, ajoute le jeton d'ingestion
→ OTLP en HTTPS
platform | Service d'ingestion | Vérifie le jeton, normalise les noms de champs, repère les données navigateur
→ directement, ou via une file Kafka (voir plus bas)
platform | Entrepôt de données (Vertica) | Traces et logs bruts, enregistrés presque tels quels
{{< /flow >}}

1. Les applications génèrent des **traces** (le détail d'une requête, étape par étape) et des **logs**.
2. Le Collecteur OpenTelemetry les regroupe et les transmet au service d'ingestion de Neurons avec le jeton d'ingestion. Toute requête sans jeton valide est refusée.
3. Le service d'ingestion vérifie, nettoie et enregistre ces données presque telles quelles — très peu de transformation à ce stade, pour ne rien perdre et rester rapide.
{.steps}

### Depuis vos sites web (Browser RUM)

Les sites web ne passent pas par le Collecteur. La page charge le script RUM de Neurons (une ligne dans son `<head>`) et le navigateur envoie ses événements **directement** à une entrée publique du service d'ingestion. Comme cette entrée est accessible depuis internet, elle applique ses propres contrôles :

- **Le site doit être connu et activé.** Le script porte la clé de votre entreprise ; l'adresse de la page doit faire partie des domaines d'une application navigateur *activée*. Un nouveau site apparaît « en attente d'approbation » et rien de ce qu'il envoie n'est conservé tant que vous ne l'avez pas activé.
- **Des limites de débit**, par application et par visiteur, protègent la plateforme d'une page qui s'emballe ou d'un abus.
- **La localisation** (pays, ville) est calculée à partir de l'adresse IP du visiteur, prise uniquement auprès des proxys de confiance de la plateforme.
- **Les replays de session** et **la découverte de champs** (les noms des champs qu'une page expose, jamais leurs valeurs) arrivent par la même entrée.

Les événements navigateur sont enregistrés dans leur propre table, à côté des traces backend, et les appels d'API faits par la page sont reliés aux traces backend qu'ils ont déclenchées. L'installation est décrite dans [Browser RUM](application-onboarding/browser-rum/).

### Deux façons d'écrire dans l'entrepôt

La façon dont le service d'ingestion écrit dans l'entrepôt dépend du déploiement :

| | Mode direct | Mode Kafka |
|---|---|---|
| **Fonctionnement** | Le service d'ingestion garde les données quelques secondes en mémoire, puis les écrit par lots. | Le service d'ingestion dépose chaque requête dans une file Kafka et ne la confirme qu'une fois enregistrée par Kafka. Un *loader* écrit ensuite de Kafka vers l'entrepôt. |
| **Si l'entrepôt est lent ou arrêté** | La mémoire tampon se remplit ; les émetteurs sont invités à réessayer plus tard (HTTP 429). | Les données attendent dans Kafka ; le loader rattrape son retard quand l'entrepôt revient. |
| **Si le service d'ingestion plante** | Les quelques secondes de données encore en mémoire sont perdues. | Rien n'est perdu : les données sont déjà dans Kafka. |
| **Doublons** | — | Aucun : chaque lot chargé et sa position dans la file sont enregistrés ensemble, dans une seule transaction. |
| **Historique récent** | — | Kafka conserve les dernières heures de trafic (24 h par défaut). Elles peuvent être rejouées après une restauration de la base (voir [Sauvegarde et restauration](#backup)). |

{{< callout >}}
Le mode est un réglage de déploiement du service d'ingestion (`INGEST_MODE` : `buffer` ou `kafka`). Le mode Kafka est recommandé pour les volumes de production.
{{< /callout >}}

### Après l'enregistrement : les tâches de fond

4. Des tâches de fond (*workers*) relisent en continu les données enregistrées pour calculer tout ce qui est affiché dans les tableaux de bord : taux de requêtes, taux d'erreur, temps de réponse, carte des dépendances entre services, transactions métier et indicateurs d'expérience utilisateur.
5. Les tableaux de bord interrogent ces résultats déjà calculés plutôt que de recalculer à chaque affichage, ce qui les garde rapides même sur de longues périodes.
{.steps}

Chaque worker retient exactement où il s'est arrêté. Après un redémarrage ou une panne, il reprend à ce point et rattrape son retard progressivement : rien n'est compté deux fois ni sauté. Un worker attend aussi quelques secondes après la fin d'une minute avant de la calculer, pour inclure les données légèrement en retard ; des données qui arrivent beaucoup plus tard sont conservées mais peuvent manquer dans les résumés déjà calculés.

{{< callout >}}
La quasi-totalité des courbes et tendances affichées dans les écrans (trafic, latence, erreurs dans le temps) proviennent de ces calculs pré-agrégés, pas d'un recalcul sur les données brutes à chaque ouverture d'écran. C'est ce qui permet à la plateforme de rester réactive même avec des mois d'historique.
{{< /callout >}}

### Quand la plateforme est sous pression

- **Les émetteurs sont invités à réessayer, jamais ignorés en silence.** Quand le service d'ingestion ne peut momentanément plus accepter de données, il répond HTTP 429 ou 503 avec un délai *Retry-After*. Les Collecteurs doivent garder leur file d'envoi et leurs nouvelles tentatives activées (c'est le cas du Collecteur Neurons).
- **La taille des requêtes est limitée** (environ 16 Mo par requête) ; au-delà, la requête est refusée avec HTTP 413. Les Collecteurs découpent leurs lots bien en dessous.
- **Les navigateurs qui dépassent leur limite** reçoivent HTTP 429 : ces événements sont abandonnés, et le reste du site continue de fonctionner normalement.

### Vérifier que les données arrivent

- **Platform health** montre l'état du service d'ingestion, du loader et des workers.
- En mode Kafka, le **retard du loader** (messages en attente dans Kafka) doit rester proche de zéro ; un retard qui ne cesse d'augmenter signifie que l'entrepôt ne suit pas.
- Les dernières données enregistrées indiquent immédiatement si quelque chose arrive :

```sql
SELECT MAX(start_time) FROM apm.spans;      -- traces backend
SELECT MAX(start_time) FROM apm.rum_events; -- événements navigateur
```

## Concepts clés {#concepts}

Quelques termes reviennent dans toute la plateforme et sont utiles à bien distinguer avant de parcourir les écrans :

| Terme | Signification |
|---|---|
| **Application** | Un logiciel instrumenté dans son ensemble (ex. « VisionApp »). Regroupe un ou plusieurs services. |
| **Service** | Un composant applicatif individuel qui reçoit des requêtes (une API, un microservice). |
| **Trace** | Le parcours complet d'une requête, de son point d'entrée jusqu'à tous les appels qu'elle déclenche. |
| **Span** | Une étape individuelle à l'intérieur d'une trace (un appel HTTP, une requête base de données, etc.). |
| **Transaction métier** | Un point d'entrée métier nommé et suivi dans la durée (ex. « Connexion », « Paiement »), détecté automatiquement à partir du trafic récurrent. |
| **Business Journey** | Un entonnoir de conversion qui relie plusieurs pages et transactions métier entre elles, pour suivre un parcours utilisateur de bout en bout. |
| **Événement** | Une alerte ou un signal généré par la plateforme, avec un cycle de vie (ouvert, acquitté, résolu). |
| **Métrique** | Une mesure agrégée dans le temps — calculée par les workers, pas envoyée directement par les applications. |
| **RED** | Les trois indicateurs de base surveillés pour chaque service : Rate (débit), Errors (erreurs), Duration (durée/latence). |
| **RUM** | Real User Monitoring — la mesure de l'expérience réelle des utilisateurs dans leur navigateur ou application mobile. |
{firstcol="26"}
