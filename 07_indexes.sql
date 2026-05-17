-- ============================================================
-- 07_indexes.sql
-- index supplémentaires : sur les FK non indexées (jointures
-- fréquentes) + quelques filtres métier.
-- ============================================================


-- ============================================================
-- Cergy
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

-- index sur les FK qui n'en avaient pas. sans ça, les jointures sur ces
-- colonnes font un FULL SCAN.

-- MAINTENANCE_TICKET : FK vers PERSON et référence logique vers DEVICE
CREATE INDEX idx_ticket_opened_by ON MAINTENANCE_TICKET(opened_by_person_id) TABLESPACE IDX_CERGY;
CREATE INDEX idx_ticket_tech      ON MAINTENANCE_TICKET(technician_id)       TABLESPACE IDX_CERGY;
CREATE INDEX idx_ticket_device    ON MAINTENANCE_TICKET(device_id)           TABLESPACE IDX_CERGY;

-- DEVICE : FK réseau (sert dans V_NETWORK_TOPOLOGY)
CREATE INDEX idx_device_switch ON DEVICE(switch_id)     TABLESPACE IDX_CERGY;
CREATE INDEX idx_device_vlan   ON DEVICE(vlan_id)       TABLESPACE IDX_CERGY;
CREATE INDEX idx_device_os     ON DEVICE(os_version_id) TABLESPACE IDX_CERGY;

-- PERIPHERAL : FK vers ROOM et PERIPHERAL_TYPE
CREATE INDEX idx_periph_room ON PERIPHERAL(room_id)            TABLESPACE IDX_CERGY;
CREATE INDEX idx_periph_type ON PERIPHERAL(peripheral_type_id) TABLESPACE IDX_CERGY;

-- autres FK
CREATE INDEX idx_room_building ON ROOM(building_id)        TABLESPACE IDX_CERGY;
CREATE INDEX idx_switch_room   ON NETWORK_SWITCH(room_id)  TABLESPACE IDX_CERGY;
CREATE INDEX idx_osversion_fam ON OS_VERSION(os_family_id) TABLESPACE IDX_CERGY;


-- index "métier" : colonnes souvent filtrées.
-- IDX_TICKET_STATUS existe déjà (cf. 01), on ajoute un composite avec opened_at
-- pour servir le ORDER BY de V_ACTIVE_TICKETS sans trier en plus.
CREATE INDEX idx_device_status      ON DEVICE(device_status)                          TABLESPACE IDX_CERGY;
CREATE INDEX idx_ticket_status_open ON MAINTENANCE_TICKET(ticket_status, opened_at)   TABLESPACE IDX_CERGY;


-- màj des stats (sinon le planificateur peut ignorer les nouveaux index)
BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(USER); END;
/


-- ============================================================
-- Pau (mêmes index sur les tables locales)
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

CREATE INDEX idx_device_switch ON DEVICE(switch_id)     TABLESPACE IDX_PAU;
CREATE INDEX idx_device_vlan   ON DEVICE(vlan_id)       TABLESPACE IDX_PAU;
CREATE INDEX idx_device_os     ON DEVICE(os_version_id) TABLESPACE IDX_PAU;

CREATE INDEX idx_periph_room ON PERIPHERAL(room_id)            TABLESPACE IDX_PAU;
CREATE INDEX idx_periph_type ON PERIPHERAL(peripheral_type_id) TABLESPACE IDX_PAU;

CREATE INDEX idx_room_building ON ROOM(building_id)       TABLESPACE IDX_PAU;
CREATE INDEX idx_switch_room   ON NETWORK_SWITCH(room_id) TABLESPACE IDX_PAU;

CREATE INDEX idx_device_status ON DEVICE(device_status) TABLESPACE IDX_PAU;

BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(USER); END;
/


-- ============================================================
-- vérif rapide :
--   SELECT index_name, table_name FROM user_indexes ORDER BY table_name;
--
-- test EXPLAIN PLAN avant/après pour le rapport :
--   EXPLAIN PLAN FOR
--     SELECT * FROM MAINTENANCE_TICKET
--      WHERE ticket_status IN ('OPEN','IN_PROGRESS')
--      ORDER BY opened_at DESC;
--   SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- ============================================================
