-- ============================================================
-- 07_indexes.sql
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
-- ============================================================


-- ============================================================
-- PARTIE 1 : SITE CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

-- ----------------------------------------------------------------
-- (A) Index sur FK non indexees
-- ----------------------------------------------------------------
-- MAINTENANCE_TICKET : 3 FK / colonnes referencees sans index
--   - opened_by_person_id : FK_TICKET_OPENED_BY vers PERSON
--   - technician_id        : FK_TICKET_TECH vers PERSON
--   - device_id            : pas de FK declaree (cross-site) mais
--                            filtree par PROC_CREATE_TICKET ligne 65
CREATE INDEX IDX_TICKET_OPENED_BY ON MAINTENANCE_TICKET(opened_by_person_id) TABLESPACE IDX_CERGY;
CREATE INDEX IDX_TICKET_TECH      ON MAINTENANCE_TICKET(technician_id)       TABLESPACE IDX_CERGY;
CREATE INDEX IDX_TICKET_DEVICE    ON MAINTENANCE_TICKET(device_id)           TABLESPACE IDX_CERGY;

-- DEVICE : 3 FK / refs sans index (switch, vlan, os_version)
--   Note : on N'indexe PAS device_id (PK -> deja indexe par le cluster)
--   ni room_id (deja IDX_DEVICE_ROOM dans 01_setup_cergy.sql).
CREATE INDEX IDX_DEVICE_SWITCH ON DEVICE(switch_id)     TABLESPACE IDX_CERGY;
CREATE INDEX IDX_DEVICE_VLAN   ON DEVICE(vlan_id)       TABLESPACE IDX_CERGY;
CREATE INDEX IDX_DEVICE_OS     ON DEVICE(os_version_id) TABLESPACE IDX_CERGY;

-- PERIPHERAL : 2 FK sans index (room, peripheral_type)
--   Note : assigned_device_id est deja indexe (IDX_PERIPHERAL_DEVICE)
CREATE INDEX IDX_PERIPH_ROOM ON PERIPHERAL(room_id)            TABLESPACE IDX_CERGY;
CREATE INDEX IDX_PERIPH_TYPE ON PERIPHERAL(peripheral_type_id) TABLESPACE IDX_CERGY;

-- ROOM, NETWORK_SWITCH, OS_VERSION : 1 FK chacune sans index
CREATE INDEX IDX_ROOM_BUILDING    ON ROOM(building_id)         TABLESPACE IDX_CERGY;
CREATE INDEX IDX_SWITCH_ROOM      ON NETWORK_SWITCH(room_id)   TABLESPACE IDX_CERGY;
CREATE INDEX IDX_OS_VERSION_FAM   ON OS_VERSION(os_family_id)  TABLESPACE IDX_CERGY;

-- ----------------------------------------------------------------
-- (B) Index metier (justifies par requetes existantes)
-- ----------------------------------------------------------------

-- B.1 -- V_ACTIVE_TICKETS (01_setup_cergy.sql:249-264) :
--   WHERE site_id=1 AND ticket_status IN ('OPEN','IN_PROGRESS')
--   ORDER BY opened_at DESC
-- IDX_TICKET_STATUS existe deja mais ne couvre que le filtre.
-- Composite (status, opened_at) => Oracle peut servir filtre + tri
-- sans operation SORT additionnelle.
CREATE INDEX IDX_TICKET_STATUS_OPEN
  ON MAINTENANCE_TICKET(ticket_status, opened_at)
  TABLESPACE IDX_CERGY;

-- B.2 -- Reports "devices in repair / retired"
-- Cardinalite = 4 valeurs mais distribution biaisee (la plupart IN_SERVICE).
-- Un index B-tree standard suffit pour les queries qui filtrent les
-- minorites (IN_REPAIR, RETIRED).
CREATE INDEX IDX_DEVICE_STATUS ON DEVICE(device_status) TABLESPACE IDX_CERGY;

-- B.3 -- Trouver l'affectation active courante d'un device
-- Index fonctionnel : NULL exclu du B-tree standard, donc en indexant
-- (CASE WHEN returned_at IS NULL THEN device_id END) on obtient un
-- index ne contenant QUE les affectations actives (≈ nb de devices
-- en service), 5 a 10x plus petit qu'un index plein.
CREATE INDEX IDX_ASSIGN_ACTIVE
  ON DEVICE_ASSIGNMENT(CASE WHEN returned_at IS NULL THEN device_id END)
  TABLESPACE IDX_CERGY;

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
/


-- ============================================================
-- PARTIE 2 : SITE PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

-- ----------------------------------------------------------------
-- (A) Index sur FK non indexees
-- ----------------------------------------------------------------
-- DEVICE : meme cas que Cergy + on garde la coherence
CREATE INDEX IDX_DEVICE_SWITCH ON DEVICE(switch_id)     TABLESPACE IDX_PAU;
CREATE INDEX IDX_DEVICE_VLAN   ON DEVICE(vlan_id)       TABLESPACE IDX_PAU;
CREATE INDEX IDX_DEVICE_OS     ON DEVICE(os_version_id) TABLESPACE IDX_PAU;

-- PERIPHERAL : 2 FK sans index
CREATE INDEX IDX_PERIPH_ROOM ON PERIPHERAL(room_id)            TABLESPACE IDX_PAU;
CREATE INDEX IDX_PERIPH_TYPE ON PERIPHERAL(peripheral_type_id) TABLESPACE IDX_PAU;

-- ROOM, NETWORK_SWITCH
CREATE INDEX IDX_ROOM_BUILDING ON ROOM(building_id)       TABLESPACE IDX_PAU;
CREATE INDEX IDX_SWITCH_ROOM   ON NETWORK_SWITCH(room_id) TABLESPACE IDX_PAU;

-- ----------------------------------------------------------------
-- (B) Index metier
-- ----------------------------------------------------------------
-- B.1 -- Pas de MAINTENANCE_TICKET local sur Pau (table sur Cergy)
--        donc pas d'index ticket cote Pau.

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
/


-- ============================================================
-- VERIFICATION
-- ============================================================
-- Lister tous les index utilisateur de chaque site :
--   SELECT index_name, table_name, uniqueness, status
--   FROM user_indexes
--   ORDER BY table_name, index_name;
--
-- Verifier l'index fonctionnel :
--   SELECT index_name, column_expression
--   FROM user_ind_expressions
--   WHERE index_name = 'IDX_ASSIGN_ACTIVE';
--
-- Verifier qu'un index est bien utilise (apres GATHER_STATS) :
--   EXPLAIN PLAN FOR
--     SELECT * FROM MAINTENANCE_TICKET
--     WHERE ticket_status IN ('OPEN','IN_PROGRESS')
--     ORDER BY opened_at DESC;
--   SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
--   -- On doit voir : INDEX RANGE SCAN IDX_TICKET_STATUS_OPEN
