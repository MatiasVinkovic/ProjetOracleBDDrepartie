-- ============================================================
-- 02_setup_pau.sql
-- Projet SIE / BDDR - GLPI simplifie
-- Site : PAU
-- ============================================================
-- Principe de repartition :
--   Pau possede   : SITE, PERSON_ROLE
--                   + toutes ses tables locales
--   Pau recoit    : MV_DEVICE_TYPE, MV_PERIPHERAL_TYPE,
--                   MV_OS_FAMILY, MV_OS_VERSION (propriete de Cergy)
--   FKs vers DEVICE_TYPE et PERIPHERAL_TYPE supprimees (MV non referençables)
--   Integrite garantie par CK constraints + procedures
-- ============================================================

-- ============================================================
-- 0. NETTOYAGE (optionnel, SYSDBA)
-- ============================================================
-- DROP USER CYTECH_PAU CASCADE;
-- DROP TABLESPACE DATA_PAU INCLUDING CONTENTS AND DATAFILES;
-- DROP TABLESPACE IDX_PAU INCLUDING CONTENTS AND DATAFILES;

-- ============================================================
-- 1. TABLESPACES (SYSDBA)
-- ============================================================
-- CREATE TABLESPACE DATA_PAU
-- DATAFILE 'data_pau.dbf' SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 500M
-- EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

-- CREATE TABLESPACE IDX_PAU
-- DATAFILE 'idx_pau.dbf' SIZE 20M AUTOEXTEND ON NEXT 5M MAXSIZE 200M
-- EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

-- ============================================================
-- 2. UTILISATEUR / SCHEMA (SYSDBA)
-- ============================================================
-- CREATE USER CYTECH_PAU IDENTIFIED BY pau2026
-- DEFAULT TABLESPACE DATA_PAU TEMPORARY TABLESPACE TEMP
-- QUOTA UNLIMITED ON DATA_PAU QUOTA UNLIMITED ON IDX_PAU;

-- GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SYNONYM,
--       CREATE DATABASE LINK, CREATE SEQUENCE, CREATE MATERIALIZED VIEW,
--       CREATE PROCEDURE, CREATE TRIGGER TO CYTECH_PAU;

-- ============================================================
-- 3. CONNEXION
-- ============================================================
-- CONNECT CYTECH_PAU/pau2026;

-- ============================================================
-- 4. TABLES DE REFERENCE — PROPRIETE PAU
-- ============================================================
-- DEVICE_TYPE, PERIPHERAL_TYPE, OS_FAMILY, OS_VERSION appartiennent a Cergy.
-- Pau y accede via MVs (cf. 04_replication.sql).

CREATE TABLE SITE (
  site_id      NUMBER        CONSTRAINT PK_SITE PRIMARY KEY,
  site_code    VARCHAR2(10)  CONSTRAINT UK_SITE_CODE UNIQUE NOT NULL,
  site_name    VARCHAR2(80)  NOT NULL,
  city         VARCHAR2(50)  NOT NULL,
  is_active    CHAR(1)       DEFAULT 'Y' NOT NULL,
  CONSTRAINT CK_SITE_ACTIVE CHECK (is_active IN ('Y','N'))
) TABLESPACE DATA_PAU;

CREATE TABLE PERSON_ROLE (
  role_id      NUMBER        CONSTRAINT PK_PERSON_ROLE PRIMARY KEY,
  role_code    VARCHAR2(20)  CONSTRAINT UK_PERSON_ROLE_CODE UNIQUE NOT NULL,
  role_label   VARCHAR2(80)  NOT NULL
) TABLESPACE DATA_PAU;

-- ============================================================
-- 5. TABLES LOCALES PAU
-- ============================================================
CREATE TABLE BUILDING (
  building_id      NUMBER        CONSTRAINT PK_BUILDING PRIMARY KEY,
  site_id          NUMBER        NOT NULL,
  building_code    VARCHAR2(10)  NOT NULL,
  building_name    VARCHAR2(80)  NOT NULL,
  CONSTRAINT FK_BUILDING_SITE FOREIGN KEY (site_id) REFERENCES SITE(site_id),
  CONSTRAINT UK_BUILDING UNIQUE (site_id, building_code),
  CONSTRAINT CK_BUILDING_SITE CHECK (site_id = 2)
) TABLESPACE DATA_PAU;

CREATE TABLE ROOM (
  room_id        NUMBER        CONSTRAINT PK_ROOM PRIMARY KEY,
  building_id    NUMBER        NOT NULL,
  room_code      VARCHAR2(20)  NOT NULL,
  room_name      VARCHAR2(80),
  room_type      VARCHAR2(30)  NOT NULL,
  capacity       NUMBER,
  CONSTRAINT FK_ROOM_BUILDING FOREIGN KEY (building_id) REFERENCES BUILDING(building_id),
  CONSTRAINT UK_ROOM UNIQUE (building_id, room_code)
) TABLESPACE DATA_PAU;

CREATE TABLE PERSON (
  person_id        NUMBER         CONSTRAINT PK_PERSON PRIMARY KEY,
  site_id          NUMBER         NOT NULL,
  role_id          NUMBER         NOT NULL,
  login            VARCHAR2(50)   CONSTRAINT UK_PERSON_LOGIN UNIQUE NOT NULL,
  last_name        VARCHAR2(80)   NOT NULL,
  first_name       VARCHAR2(80)   NOT NULL,
  email            VARCHAR2(120)  CONSTRAINT UK_PERSON_EMAIL UNIQUE NOT NULL,
  person_status    VARCHAR2(20)   DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT FK_PERSON_SITE FOREIGN KEY (site_id) REFERENCES SITE(site_id),
  CONSTRAINT FK_PERSON_ROLE FOREIGN KEY (role_id) REFERENCES PERSON_ROLE(role_id),
  CONSTRAINT CK_PERSON_SITE CHECK (site_id = 2),
  CONSTRAINT CK_PERSON_STATUS CHECK (person_status IN ('ACTIVE','INACTIVE'))
) TABLESPACE DATA_PAU;

CREATE TABLE DEVICE (
  device_id             NUMBER         CONSTRAINT PK_DEVICE PRIMARY KEY,
  site_id               NUMBER         NOT NULL,
  room_id               NUMBER         NOT NULL,
  assigned_person_id    NUMBER,
  device_type_id        NUMBER         NOT NULL,
  os_version_id         NUMBER,
  asset_tag             VARCHAR2(40)   CONSTRAINT UK_DEVICE_ASSET_TAG UNIQUE NOT NULL,
  device_name           VARCHAR2(80)   NOT NULL,
  serial_number         VARCHAR2(80)   CONSTRAINT UK_DEVICE_SERIAL UNIQUE,
  purchase_date         DATE,
  device_status         VARCHAR2(20)   DEFAULT 'IN_SERVICE' NOT NULL,
  CONSTRAINT FK_DEVICE_SITE   FOREIGN KEY (site_id)            REFERENCES SITE(site_id),
  CONSTRAINT FK_DEVICE_ROOM   FOREIGN KEY (room_id)            REFERENCES ROOM(room_id),
  CONSTRAINT FK_DEVICE_PERSON FOREIGN KEY (assigned_person_id) REFERENCES PERSON(person_id),
  -- FK_DEVICE_TYPE supprimee : DEVICE_TYPE est une MV (propriete Cergy)
  -- FK_DEVICE_OS supprimee   : OS_VERSION est une MV (propriete Cergy)
  CONSTRAINT CK_DEVICE_SITE CHECK (site_id = 2),
  CONSTRAINT CK_DEVICE_STATUS CHECK (device_status IN ('IN_SERVICE','IN_STOCK','IN_REPAIR','RETIRED'))
) TABLESPACE DATA_PAU;

CREATE TABLE PERIPHERAL (
  peripheral_id         NUMBER         CONSTRAINT PK_PERIPHERAL PRIMARY KEY,
  site_id               NUMBER         NOT NULL,
  room_id               NUMBER         NOT NULL,
  assigned_device_id    NUMBER,
  peripheral_type_id    NUMBER         NOT NULL,
  peripheral_name       VARCHAR2(80)   NOT NULL,
  serial_number         VARCHAR2(80),
  peripheral_status     VARCHAR2(20)   DEFAULT 'AVAILABLE' NOT NULL,
  CONSTRAINT FK_PERIPHERAL_SITE   FOREIGN KEY (site_id)           REFERENCES SITE(site_id),
  CONSTRAINT FK_PERIPHERAL_ROOM   FOREIGN KEY (room_id)           REFERENCES ROOM(room_id),
  CONSTRAINT FK_PERIPHERAL_DEVICE FOREIGN KEY (assigned_device_id) REFERENCES DEVICE(device_id),
  -- FK_PERIPHERAL_TYPE supprimee : PERIPHERAL_TYPE est une MV (propriete Cergy)
  CONSTRAINT CK_PERIPHERAL_SITE CHECK (site_id = 2),
  CONSTRAINT CK_PERIPHERAL_STATUS CHECK (peripheral_status IN ('AVAILABLE','ASSIGNED','BROKEN'))
) TABLESPACE DATA_PAU;

CREATE TABLE DEVICE_ASSIGNMENT (
  assignment_id        NUMBER        CONSTRAINT PK_DEVICE_ASSIGNMENT PRIMARY KEY,
  device_id            NUMBER        NOT NULL,
  person_id            NUMBER        NOT NULL,
  assigned_at          DATE          NOT NULL,
  returned_at          DATE,
  CONSTRAINT FK_ASSIGN_DEVICE FOREIGN KEY (device_id) REFERENCES DEVICE(device_id),
  CONSTRAINT FK_ASSIGN_PERSON FOREIGN KEY (person_id) REFERENCES PERSON(person_id),
  CONSTRAINT CK_ASSIGN_DATES CHECK (returned_at IS NULL OR returned_at >= assigned_at)
) TABLESPACE DATA_PAU;

-- ============================================================
-- 6. INDEX
-- ============================================================
CREATE INDEX IDX_PERSON_ROLE      ON PERSON(role_id)                   TABLESPACE IDX_PAU;
CREATE INDEX IDX_DEVICE_ROOM      ON DEVICE(room_id)                   TABLESPACE IDX_PAU;
CREATE INDEX IDX_DEVICE_PERSON    ON DEVICE(assigned_person_id)        TABLESPACE IDX_PAU;
CREATE INDEX IDX_DEVICE_TYPE      ON DEVICE(device_type_id)            TABLESPACE IDX_PAU;
CREATE INDEX IDX_PERIPHERAL_DEVICE ON PERIPHERAL(assigned_device_id)   TABLESPACE IDX_PAU;
CREATE INDEX IDX_ASSIGN_DEVICE    ON DEVICE_ASSIGNMENT(device_id)      TABLESPACE IDX_PAU;
CREATE INDEX IDX_ASSIGN_PERSON    ON DEVICE_ASSIGNMENT(person_id)      TABLESPACE IDX_PAU;

-- ============================================================
-- 7. DONNEES DE REFERENCE — PROPRIETE PAU
-- ============================================================
INSERT INTO SITE VALUES (1, 'CERGY', 'CY Tech Cergy', 'Cergy', 'Y');
INSERT INTO SITE VALUES (2, 'PAU',   'CY Tech Pau',   'Pau',   'Y');

INSERT INTO PERSON_ROLE VALUES (1, 'PROF',    'Professeur');
INSERT INTO PERSON_ROLE VALUES (2, 'TECH',    'Technicien');
INSERT INTO PERSON_ROLE VALUES (3, 'ADMIN',   'Administrateur de site');
INSERT INTO PERSON_ROLE VALUES (4, 'STUDENT', 'Etudiant');

-- DEVICE_TYPE, PERIPHERAL_TYPE, OS_FAMILY, OS_VERSION :
-- pas d'INSERT local, donnees geries par Cergy (MVs dans 04_replication.sql).

-- ============================================================
-- 8. DONNEES LOCALES PAU
-- ============================================================
INSERT INTO BUILDING VALUES (1001, 2, 'P1', 'Batiment P1');
INSERT INTO BUILDING VALUES (1002, 2, 'P2', 'Batiment P2');

INSERT INTO ROOM VALUES (1001, 1001, 'P101', 'Salle TP Informatique', 'LAB',    24);
INSERT INTO ROOM VALUES (1002, 1001, 'P201', 'Salle Tablettes',       'LAB',    18);
INSERT INTO ROOM VALUES (1003, 1002, 'P010', 'Bureau Enseignants',    'OFFICE',  6);

INSERT INTO PERSON VALUES (1001, 2, 3, 'admin.pau',    'Admin',  'Pau',   'admin.pau@cytech.fr',        'ACTIVE');
INSERT INTO PERSON VALUES (1002, 2, 1, 'garcia.lucia', 'Garcia', 'Lucia', 'lucia.garcia@cytech.fr',     'ACTIVE');
INSERT INTO PERSON VALUES (1003, 2, 2, 'lebrun.theo',  'Lebrun', 'Theo',  'theo.lebrun@cytech.fr',      'ACTIVE');
INSERT INTO PERSON VALUES (1004, 2, 1, 'morel.nina',   'Morel',  'Nina',  'nina.morel@cytech.fr',       'ACTIVE');

-- device_type_id et os_version_id : valeurs coherentes avec les MVs Cergy (1-3 et 1-4)
INSERT INTO DEVICE VALUES (1001, 2, 1001, 1002, 1, 1, 'PAU-PC-001',  'PC Salle P101-01',        'SN-PAU-PC-001',  DATE '2024-09-01', 'IN_SERVICE');
INSERT INTO DEVICE VALUES (1002, 2, 1001, NULL, 1, 2, 'PAU-PC-002',  'PC Salle P101-02',        'SN-PAU-PC-002',  DATE '2024-09-01', 'IN_SERVICE');
INSERT INTO DEVICE VALUES (1003, 2, 1002, 1004, 3, 3, 'PAU-TAB-001', 'Tablette Salle P201-01',  'SN-PAU-TAB-001', DATE '2025-02-03', 'IN_SERVICE');
INSERT INTO DEVICE VALUES (1004, 2, 1003, 1001, 2, 1, 'PAU-LAP-001', 'Portable Administration', 'SN-PAU-LAP-001', DATE '2023-11-20', 'IN_SERVICE');

-- peripheral_type_id : valeurs coherentes avec MV_PERIPHERAL_TYPE Cergy (1-5)
INSERT INTO PERIPHERAL VALUES (1001, 2, 1001, 1001, 1, 'Ecran 24 pouces P101-01',  'SN-PAU-SCR-001', 'ASSIGNED');
INSERT INTO PERIPHERAL VALUES (1002, 2, 1001, 1002, 3, 'Clavier P101-02',           'SN-PAU-KEY-001', 'ASSIGNED');
INSERT INTO PERIPHERAL VALUES (1003, 2, 1002, 1003, 4, 'Stylet tablette P201-01',   'SN-PAU-STY-001', 'ASSIGNED');
INSERT INTO PERIPHERAL VALUES (1004, 2, 1003, 1004, 5, 'Dock administration Pau',   'SN-PAU-DOC-001', 'ASSIGNED');

INSERT INTO DEVICE_ASSIGNMENT VALUES (1001, 1001, 1002, DATE '2024-09-07', NULL);
INSERT INTO DEVICE_ASSIGNMENT VALUES (1002, 1003, 1004, DATE '2025-02-10', NULL);
INSERT INTO DEVICE_ASSIGNMENT VALUES (1003, 1004, 1001, DATE '2023-11-22', NULL);

COMMIT;

-- ============================================================
-- 9. DB LINK VERS CERGY
-- ============================================================
CREATE DATABASE LINK LNK_CERGY
CONNECT TO CYTECH_CERGY IDENTIFIED BY cergy2026
USING '//localhost:1521/XEPDB1';

-- ============================================================
-- Objets cross-site (MV_DEVICE_TYPE, MV_PERIPHERAL_TYPE,
-- MV_OS_FAMILY, MV_OS_VERSION, V_CERGY_TICKET_MIN,
-- PROC_OPEN_TICKET_PAU) : crees dans 04_replication.sql, une fois
-- que les deux schemas existent (Cergy ET Pau).
-- ============================================================
