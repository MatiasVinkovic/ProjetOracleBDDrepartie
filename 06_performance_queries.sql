-- ============================================================
-- 06_performance_queries.sql
-- Projet GLPI BDDR - Requetes de performance + EXPLAIN PLAN
-- A executer connecte en CYTECH_CERGY
-- ============================================================

CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

SET LINESIZE 200
SET PAGESIZE 50
SET SERVEROUTPUT ON


-- ============================================================
-- Q1 : Tickets ouverts avec device et personne (index sur ticket_status)
-- ============================================================
-- Utilise : IDX_TICKET_STATUS sur MAINTENANCE_TICKET
--           IDX_DEVICE_PERSON sur DEVICE

PROMPT === Q1 : Tickets ouverts - avec index ===

EXPLAIN PLAN SET STATEMENT_ID = 'Q1_AVEC_INDEX' FOR
SELECT t.ticket_id, t.ticket_status, t.issue_label,
       d.asset_tag, d.device_name,
       p.last_name || ' ' || p.first_name AS technicien
FROM MAINTENANCE_TICKET t
JOIN DEVICE d ON t.device_id = d.device_id
JOIN PERSON p ON t.technician_id = p.person_id
WHERE t.ticket_status IN ('OPEN', 'IN_PROGRESS')
ORDER BY t.opened_at DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q1_AVEC_INDEX', 'BASIC ROWS COST'));

-- Meme requete forcee en FULL SCAN (sans index) pour comparaison
PROMPT === Q1 : Tickets ouverts - FULL SCAN force (pour comparaison) ===

EXPLAIN PLAN SET STATEMENT_ID = 'Q1_FULL_SCAN' FOR
SELECT /*+ FULL(t) FULL(d) */
       t.ticket_id, t.ticket_status, t.issue_label,
       d.asset_tag, d.device_name,
       p.last_name || ' ' || p.first_name AS technicien
FROM MAINTENANCE_TICKET t
JOIN DEVICE d ON t.device_id = d.device_id
JOIN PERSON p ON t.technician_id = p.person_id
WHERE t.ticket_status IN ('OPEN', 'IN_PROGRESS')
ORDER BY t.opened_at DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q1_FULL_SCAN', 'BASIC ROWS COST'));

-- Execution reelle
PROMPT === Q1 : Resultat reel ===
SELECT t.ticket_id, t.ticket_status, d.asset_tag, p.last_name AS technicien
FROM MAINTENANCE_TICKET t
JOIN DEVICE d ON t.device_id = d.device_id
JOIN PERSON p ON t.technician_id = p.person_id
WHERE t.ticket_status IN ('OPEN', 'IN_PROGRESS')
ORDER BY t.opened_at DESC
FETCH FIRST 10 ROWS ONLY;


-- ============================================================
-- Q2 : Jointure multi-tables locale - devices actifs avec contexte complet
-- ============================================================
-- Utilise : IDX_DEVICE_ROOM, IDX_DEVICE_TYPE, IDX_DEVICE_PERSON

PROMPT === Q2 : Jointure multi-tables (Cergy) - avec index ===

EXPLAIN PLAN SET STATEMENT_ID = 'Q2_AVEC_INDEX' FOR
SELECT p.last_name, p.first_name, pr.role_label,
       d.asset_tag, d.device_name, d.device_status,
       dt.type_label, ov.version_label,
       r.room_name, b.building_name
FROM DEVICE d
JOIN PERSON       p  ON d.assigned_person_id = p.person_id
JOIN PERSON_ROLE  pr ON p.role_id            = pr.role_id
JOIN DEVICE_TYPE  dt ON d.device_type_id     = dt.device_type_id
JOIN OS_VERSION   ov ON d.os_version_id      = ov.os_version_id
JOIN ROOM         r  ON d.room_id            = r.room_id
JOIN BUILDING     b  ON r.building_id        = b.building_id
WHERE d.device_status = 'IN_SERVICE'
ORDER BY b.building_name, r.room_name, d.asset_tag;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q2_AVEC_INDEX', 'BASIC ROWS COST'));

-- Execution reelle
PROMPT === Q2 : Resultat reel (10 premieres lignes) ===
SELECT p.last_name, d.asset_tag, dt.type_label, r.room_name
FROM DEVICE d
JOIN PERSON p ON d.assigned_person_id = p.person_id
JOIN DEVICE_TYPE dt ON d.device_type_id = dt.device_type_id
JOIN ROOM r ON d.room_id = r.room_id
WHERE d.device_status = 'IN_SERVICE'
FETCH FIRST 10 ROWS ONLY;


-- ============================================================
-- Q3 : Requete distribuee - tous les devices des 2 sites (DB link)
-- ============================================================
-- Montre la transparence de la BDDR : une seule requete, 2 sites

PROMPT === Q3 : Requete distribuee UNION ALL (Cergy + Pau via LNK_PAU) ===

EXPLAIN PLAN SET STATEMENT_ID = 'Q3_DISTRIBUE' FOR
SELECT 'CERGY' AS site, asset_tag, device_name, device_status, device_type_id
FROM DEVICE
UNION ALL
SELECT 'PAU', asset_tag, device_name, device_status, device_type_id
FROM DEVICE@LNK_PAU
ORDER BY site, asset_tag;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q3_DISTRIBUE', 'BASIC ROWS COST'));

-- Execution reelle
PROMPT === Q3 : Nombre de devices par site ===
SELECT site, COUNT(*) AS nb_devices
FROM (
  SELECT 'CERGY' AS site FROM DEVICE
  UNION ALL
  SELECT 'PAU' FROM DEVICE@LNK_PAU
)
GROUP BY site
ORDER BY site;


-- ============================================================
-- Q4 : Agregation - repartition des devices par type sur les 2 sites
-- ============================================================
-- Utilise : IDX_DEVICE_TYPE sur DEVICE

PROMPT === Q4 : Agregation devices par type (2 sites) ===

EXPLAIN PLAN SET STATEMENT_ID = 'Q4_AGREGATION' FOR
SELECT dt.type_label,
       SUM(CASE WHEN d.site = 'CERGY' THEN 1 ELSE 0 END) AS nb_cergy,
       SUM(CASE WHEN d.site = 'PAU'   THEN 1 ELSE 0 END) AS nb_pau,
       COUNT(*) AS total
FROM (
  SELECT device_type_id, 'CERGY' AS site FROM DEVICE
  UNION ALL
  SELECT device_type_id, 'PAU'   FROM DEVICE@LNK_PAU
) d
JOIN DEVICE_TYPE dt ON d.device_type_id = dt.device_type_id
GROUP BY dt.type_label
ORDER BY total DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q4_AGREGATION', 'BASIC ROWS COST'));

-- Execution reelle
PROMPT === Q4 : Resultat reel ===
SELECT dt.type_label,
       SUM(CASE WHEN d.site = 'CERGY' THEN 1 ELSE 0 END) AS nb_cergy,
       SUM(CASE WHEN d.site = 'PAU'   THEN 1 ELSE 0 END) AS nb_pau,
       COUNT(*) AS total
FROM (
  SELECT device_type_id, 'CERGY' AS site FROM DEVICE
  UNION ALL
  SELECT device_type_id, 'PAU' FROM DEVICE@LNK_PAU
) d
JOIN DEVICE_TYPE dt ON d.device_type_id = dt.device_type_id
GROUP BY dt.type_label
ORDER BY total DESC;


-- ============================================================
-- Q5 : Devices en reparation sur les 2 sites (requete distribuee)
-- ============================================================

PROMPT === Q5 : Devices IN_REPAIR sur les 2 sites ===

EXPLAIN PLAN SET STATEMENT_ID = 'Q5_IN_REPAIR' FOR
SELECT 'CERGY' AS site, d.asset_tag, d.device_name, dt.type_label
FROM DEVICE d
JOIN DEVICE_TYPE dt ON d.device_type_id = dt.device_type_id
WHERE d.device_status = 'IN_REPAIR'
UNION ALL
SELECT 'PAU', d.asset_tag, d.device_name, dt.type_label
FROM DEVICE@LNK_PAU d
JOIN DEVICE_TYPE@LNK_PAU dt ON d.device_type_id = dt.device_type_id
WHERE d.device_status = 'IN_REPAIR'
ORDER BY site, asset_tag;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'Q5_IN_REPAIR', 'BASIC ROWS COST'));

-- Execution reelle
PROMPT === Q5 : Resultat reel ===
SELECT 'CERGY' AS site, asset_tag, device_name
FROM DEVICE WHERE device_status = 'IN_REPAIR'
UNION ALL
SELECT 'PAU', asset_tag, device_name
FROM DEVICE@LNK_PAU WHERE device_status = 'IN_REPAIR'
ORDER BY site, asset_tag;


-- ============================================================
-- RECAPITULATIF : stats finales des deux sites
-- ============================================================
PROMPT === RECAP : Comptages par table et par site ===

SELECT 'CERGY' AS site,
       (SELECT COUNT(*) FROM PERSON)             AS nb_persons,
       (SELECT COUNT(*) FROM DEVICE)             AS nb_devices,
       (SELECT COUNT(*) FROM PERIPHERAL)         AS nb_peripherals,
       (SELECT COUNT(*) FROM MAINTENANCE_TICKET) AS nb_tickets
FROM DUAL
UNION ALL
SELECT 'PAU',
       (SELECT COUNT(*) FROM PERSON@LNK_PAU),
       (SELECT COUNT(*) FROM DEVICE@LNK_PAU),
       (SELECT COUNT(*) FROM PERIPHERAL@LNK_PAU),
       0
FROM DUAL;
