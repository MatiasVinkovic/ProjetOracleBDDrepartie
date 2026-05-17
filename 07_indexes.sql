-- ============================================================
-- 07_indexes.sql
<<<<<<< HEAD
<<<<<<< HEAD
-- Projet GLPI BDDR - Index supplementaires
--
-- A executer APRES 01_setup_cergy.sql et 02_setup_pau.sql.
-- (Aucune dependance avec 06_error_logging.sql)
--
-- Justification globale
-- ---------------------
-- En Oracle, une colonne FK NON indexee provoque un verrou LMODE=4 (Share)
-- sur la table ENFANT a chaque DML sur la table PARENT. Resultat :
-- mise a jour d'une ligne PERSON => verrou sur toute la table TICKET le
-- temps de la transaction (vu en CM3 sur les verrous et niveaux d'isolation).
-- L'index sur la FK fait passer ce verrou au niveau ligne uniquement.
--
-- On distingue 2 categories d'index ajoutes :
--   (A) Index sur FK : evitent les verrous table sur le parent.
--       => SAUF quand le parent est une table statique (SITE) : aucun DML
--          ne se produit jamais sur SITE, donc le risque ne se materialise
--          pas et un index sur DEVICE.site_id (cardinalite=1 par site grace
--          au CHECK) serait inutile.
--   (B) Index "metier" : justifies par des requetes existantes dans les
--       vues V_NETWORK_TOPOLOGY, V_ACTIVE_TICKETS et les procedures
--       PROC_CREATE_TICKET / PROC_OPEN_TICKET_PAU.
--
-- Ce qui N'EST PAS ajoute (anti-pattern) :
--   - Pas d'index sur les colonnes UNIQUE (asset_tag, serial_number,
--     mac_address, ip_address, email, login) : Oracle cree deja l'index
--     unique implicite avec la contrainte UNIQUE.
--   - Pas d'index sur site_id seul : cardinalite=1 (CHECK constraint), un
--     range scan sur cet index serait equivalent a un full table scan.
--   - Pas d'index BITMAP sur device_status / ticket_status : meme si la
--     cardinalite est faible (3-4 valeurs), les modifications de statut
--     sont frequentes (ticket OPEN -> IN_PROGRESS -> CLOSED). Un bitmap
--     locke un segment entier a chaque update => bottleneck. B-tree mieux
--     adapte ici.
=======
-- index supplémentaires : sur les FK non indexées (jointures
-- fréquentes) + quelques filtres métier.
>>>>>>> users/FA_archi
=======
-- index supplémentaires : sur les FK non indexées (jointures
-- fréquentes) + quelques filtres métier.
>>>>>>> bf885b7 (simplification, partie 1)
-- ============================================================


-- ============================================================
<<<<<<< HEAD
<<<<<<< HEAD
-- PARTIE 1 : SITE CERGY
=======
-- Cergy
>>>>>>> bf885b7 (simplification, partie 1)
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


<<<<<<< HEAD
-- B.4 -- Reports "personnes actives par role"
-- Composite : permet filter + group by sans full scan.
CREATE INDEX IDX_PERSON_STATUS_ROLE
  ON PERSON(person_status, role_id)
  TABLESPACE IDX_CERGY;

-- ----------------------------------------------------------------
-- Statistiques apres creation (pour le planificateur de requetes)
-- ----------------------------------------------------------------
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(USER, cascade => TRUE);
END;
=======
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
>>>>>>> users/FA_archi
=======
-- màj des stats (sinon le planificateur peut ignorer les nouveaux index)
BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(USER); END;
>>>>>>> bf885b7 (simplification, partie 1)
/


-- ============================================================
<<<<<<< HEAD
<<<<<<< HEAD
-- PARTIE 2 : SITE PAU
=======
-- Pau (mêmes index sur les tables locales)
>>>>>>> bf885b7 (simplification, partie 1)
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

<<<<<<< HEAD
-- B.2 -- Devices in repair / retired (V_NETWORK_TOPOLOGY)
CREATE INDEX IDX_DEVICE_STATUS ON DEVICE(device_status) TABLESPACE IDX_PAU;

-- B.3 -- Affectation active
CREATE INDEX IDX_ASSIGN_ACTIVE
  ON DEVICE_ASSIGNMENT(CASE WHEN returned_at IS NULL THEN device_id END)
  TABLESPACE IDX_PAU;

-- B.4 -- Personnes actives par role
CREATE INDEX IDX_PERSON_STATUS_ROLE
  ON PERSON(person_status, role_id)
  TABLESPACE IDX_PAU;

-- ----------------------------------------------------------------
-- Statistiques
-- ----------------------------------------------------------------
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(USER, cascade => TRUE);
END;
=======
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
>>>>>>> users/FA_archi
=======
BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(USER); END;
>>>>>>> bf885b7 (simplification, partie 1)
/


-- ============================================================
<<<<<<< HEAD
<<<<<<< HEAD
-- VERIFICATION
-- ============================================================
-- Lister tous les index utilisateur de chaque site :
--   SELECT index_name, table_name, uniqueness, status
--   FROM user_indexes
--   ORDER BY table_name, index_name;
=======
-- vérif rapide :
--   SELECT index_name, table_name FROM user_indexes ORDER BY table_name;
>>>>>>> bf885b7 (simplification, partie 1)
--
-- test EXPLAIN PLAN avant/après pour le rapport :
--   EXPLAIN PLAN FOR
--     SELECT * FROM MAINTENANCE_TICKET
--      WHERE ticket_status IN ('OPEN','IN_PROGRESS')
--      ORDER BY opened_at DESC;
--   SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
<<<<<<< HEAD
--   -- On doit voir : INDEX RANGE SCAN IDX_TICKET_STATUS_OPEN
=======
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
>>>>>>> users/FA_archi
=======
-- ============================================================
>>>>>>> bf885b7 (simplification, partie 1)
