-- Neurons -- les deux comptes Vertica de l'application, leurs droits, et les 4 pools de ressources.
-- Neurons lit avec neurones_reader et ecrit avec neurones_writer, jamais avec dbadmin.
-- A lancer APRES vertica-migrations.yaml (les tables doivent exister).
-- Usage :
--   vsql -h <serveur> -d <base> -U dbadmin -v lecteur_mdp="'<mot de passe>'" -v ecrivain_mdp="'<mot de passe>'" -f vertica-comptes.sql

CREATE USER neurones_reader IDENTIFIED BY :lecteur_mdp;
CREATE USER neurones_writer IDENTIFIED BY :ecrivain_mdp;

GRANT USAGE ON SCHEMA apm TO neurones_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA apm TO neurones_reader;

GRANT USAGE, CREATE ON SCHEMA apm TO neurones_writer;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, ALTER ON ALL TABLES IN SCHEMA apm TO neurones_writer;

-- Les memes droits sur les tables que Neurons creera plus tard.
ALTER SCHEMA apm DEFAULT INCLUDE SCHEMA PRIVILEGES;
GRANT SELECT ON SCHEMA apm TO neurones_reader;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, ALTER ON SCHEMA apm TO neurones_writer;

-- Les pools de ressources : la memoire de Vertica reservee a chaque usage de Neurons,
-- en pourcentage de la memoire de Vertica (memes reglages que la production).
-- Un pool qui existe deja provoque une erreur "already exists" : il est garde tel quel.
CREATE RESOURCE POOL apm_loader_pool MEMORYSIZE '10%' MAXMEMORYSIZE '16%' PLANNEDCONCURRENCY 4 MAXCONCURRENCY 8 RUNTIMECAP NONE QUEUETIMEOUT 120 PRIORITY 60 EXECUTIONPARALLELISM AUTO;
CREATE RESOURCE POOL apm_query_pool MEMORYSIZE '19%' MAXMEMORYSIZE '32%' PLANNEDCONCURRENCY 6 MAXCONCURRENCY 12 RUNTIMECAP '1 minute' QUEUETIMEOUT 30 PRIORITY 80 EXECUTIONPARALLELISM AUTO;
CREATE RESOURCE POOL apm_core_pool MEMORYSIZE '3%' MAXMEMORYSIZE '13%' PLANNEDCONCURRENCY 4 MAXCONCURRENCY 4 RUNTIMECAP '4 minutes' QUEUETIMEOUT 120 PRIORITY 40 EXECUTIONPARALLELISM AUTO;
CREATE RESOURCE POOL apm_worker_pool MEMORYSIZE '0%' MAXMEMORYSIZE '38%' PLANNEDCONCURRENCY 4 MAXCONCURRENCY 6 RUNTIMECAP '30 minutes' QUEUETIMEOUT 1800 PRIORITY 0 EXECUTIONPARALLELISM AUTO;

GRANT USAGE ON RESOURCE POOL apm_loader_pool TO neurones_writer;
GRANT USAGE ON RESOURCE POOL apm_query_pool TO neurones_writer;
GRANT USAGE ON RESOURCE POOL apm_core_pool TO neurones_writer;
GRANT USAGE ON RESOURCE POOL apm_worker_pool TO neurones_writer;
