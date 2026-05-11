-- ============================================================
-- 01_setup_cergy.sql
-- Projet SIE / BDDR - GLPI simplifie
-- Site : CERGY
-- ============================================================
-- Principe de repartition :
--   Cergy possede  : DEVICE_TYPE, OS_FAMILY, OS_VERSION, PERIPHERAL_TYPE
--                    + toutes ses tables locales + MAINTENANCE_TICKET
--   Cergy recoit   : MV_SITE, MV_PERSON_ROLE (propriete de Pau)
--   FKs vers SITE et PERSON_ROLE supprimees (MV non referençables)
--   Integrite garantie par CK constraints + procedures
-- ============================================================

-- ============================================================
-- 0. NETTOYAGE (optionnel, SYSDBA)
-- ============================================================
-- DROP USER CYTECH_CERGY CASCADE;
-- DROP TABLESPACE DATA_CERGY INCLUDING CONTENTS AND DATAFILES;
-- DROP TABLESPACE IDX_CERGY INCLUDING CONTENTS AND DATAFILES;

-- ============================================================
-- 1. TABLESPACES (SYSDBA)
-- ============================================================
-- CREATE TABLESPACE DATA_CERGY
-- DATAFILE 'data_cergy.dbf' SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 500M
-- EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

-- CREATE TABLESPACE IDX_CERGY
-- DATAFILE 'idx_cergy.dbf' SIZE 20M AUTOEXTEND ON NEXT 5M MAXSIZE 200M
-- EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

-- ============================================================
-- 2. UTILISATEUR / SCHEMA (SYSDBA)
-- ============================================================
-- CREATE USER CYTECH_CERGY IDENTIFIED BY cergy2026
-- DEFAULT TABLESPACE DATA_CERGY TEMPORARY TABLESPACE TEMP
-- QUOTA UNLIMITED ON DATA_CERGY QUOTA UNLIMITED ON IDX_CERGY;

-- GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SYNONYM,
--       CREATE DATABASE LINK, CREATE SEQUENCE, CREATE MATERIALIZED VIEW,
--       CREATE PROCEDURE, CREATE TRIGGER TO CYTECH_CERGY;

-- ============================================================
-- 3. CONNEXION
-- ============================================================
-- CONNECT CYTECH_CERGY/cergy2026;

-- ============================================================
-- 4. TABLES DE REFERENCE — PROPRIETE CERGY
-- ============================================================
-- SITE et PERSON_ROLE appartiennent a Pau.
-- Cergy y accede via MV_SITE et MV_PERSON_ROLE (cf. 04_replication.sql).

CREATE TABLE DEVICE_TYPE (
  device_type_id   NUMBER        CONSTRAINT PK_DEVICE_TYPE PRIMARY KEY,
  type_code        VARCHAR2(20)  CONSTRAINT UK_DEVICE_TYPE_CODE UNIQUE NOT NULL,
  type_label       VARCHAR2(80)  NOT NULL
) TABLESPACE DATA_CERGY;

CREATE TABLE OS_FAMILY (
  os_family_id   NUMBER        CONSTRAINT PK_OS_FAMILY PRIMARY KEY,
  family_name    VARCHAR2(40)  CONSTRAINT UK_OS_FAMILY_NAME UNIQUE NOT NULL
) TABLESPACE DATA_CERGY;

CREATE TABLE OS_VERSION (
  os_version_id   NUMBER        CONSTRAINT PK_OS_VERSION PRIMARY KEY,
  os_family_id    NUMBER        NOT NULL,
  version_label   VARCHAR2(60)  NOT NULL,
  CONSTRAINT FK_OS_VERSION_FAMILY FOREIGN KEY (os_family_id) REFERENCES OS_FAMILY(os_family_id),
  CONSTRAINT UK_OS_VERSION UNIQUE (os_family_id, version_label)
) TABLESPACE DATA_CERGY;

CREATE TABLE PERIPHERAL_TYPE (
  peripheral_type_id   NUMBER        CONSTRAINT PK_PERIPHERAL_TYPE PRIMARY KEY,
  type_code            VARCHAR2(20)  CONSTRAINT UK_PERIPHERAL_TYPE_CODE UNIQUE NOT NULL,
  type_label           VARCHAR2(80)  NOT NULL
) TABLESPACE DATA_CERGY;

-- A. LES SÉQUENCES (Ajoutées pour être comme Pau)
CREATE SEQUENCE SEQ_PERSON_CERGY  START WITH 100 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_DEVICE_CERGY  START WITH 100 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_PERIPH_CERGY  START WITH 100 INCREMENT BY 1 NOCACHE;
-- (Garde la SEQ_TICKET_ID qui est dans ta section 6)

-- Création du Cluster pour Cergy
CREATE CLUSTER cl_device_periph (id_appareil NUMBER) 
SIZE 512 
TABLESPACE DATA_CERGY;

-- L'index de cluster est OBLIGATOIRE avant toute insertion
CREATE INDEX idx_cl_device_periph ON CLUSTER cl_device_periph TABLESPACE IDX_CERGY;

-- ============================================================
-- 5. TABLES LOCALES CERGY
-- ============================================================
CREATE TABLE BUILDING (
  building_id      NUMBER        CONSTRAINT PK_BUILDING PRIMARY KEY,
  site_id          NUMBER        NOT NULL,
  building_code    VARCHAR2(10)  NOT NULL,
  building_name    VARCHAR2(80)  NOT NULL,
  CONSTRAINT UK_BUILDING UNIQUE (site_id, building_code),
  CONSTRAINT CK_BUILDING_SITE CHECK (site_id = 1)
) TABLESPACE DATA_CERGY;

CREATE TABLE ROOM (
  room_id        NUMBER        CONSTRAINT PK_ROOM PRIMARY KEY,
  building_id    NUMBER        NOT NULL,
  room_code      VARCHAR2(20)  NOT NULL,
  room_name      VARCHAR2(80),
  room_type      VARCHAR2(30)  NOT NULL,
  capacity       NUMBER,
  CONSTRAINT FK_ROOM_BUILDING FOREIGN KEY (building_id) REFERENCES BUILDING(building_id),
  CONSTRAINT UK_ROOM UNIQUE (building_id, room_code)
) TABLESPACE DATA_CERGY;

CREATE TABLE PERSON (
  person_id        NUMBER         CONSTRAINT PK_PERSON PRIMARY KEY,
  site_id          NUMBER         NOT NULL,
  role_id          NUMBER         NOT NULL,
  login            VARCHAR2(50)   CONSTRAINT UK_PERSON_LOGIN UNIQUE NOT NULL,
  last_name        VARCHAR2(80)   NOT NULL,
  first_name       VARCHAR2(80)   NOT NULL,
  email            VARCHAR2(120)  CONSTRAINT UK_PERSON_EMAIL UNIQUE NOT NULL,
  person_status    VARCHAR2(20)   DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT CK_PERSON_SITE CHECK (site_id = 1),
  CONSTRAINT CK_PERSON_STATUS CHECK (person_status IN ('ACTIVE','INACTIVE'))
) TABLESPACE DATA_CERGY;

CREATE TABLE DEVICE (
  device_id             NUMBER,
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
  CONSTRAINT FK_DEVICE_ROOM   FOREIGN KEY (room_id)            REFERENCES ROOM(room_id),
  CONSTRAINT FK_DEVICE_PERSON FOREIGN KEY (assigned_person_id) REFERENCES PERSON(person_id),
  CONSTRAINT FK_DEVICE_TYPE   FOREIGN KEY (device_type_id)     REFERENCES DEVICE_TYPE(device_type_id),
  CONSTRAINT FK_DEVICE_OS     FOREIGN KEY (os_version_id)      REFERENCES OS_VERSION(os_version_id),
  CONSTRAINT CK_DEVICE_SITE CHECK (site_id = 1),
  CONSTRAINT CK_DEVICE_STATUS CHECK (device_status IN ('IN_SERVICE','IN_STOCK','IN_REPAIR','RETIRED'))
) 
CLUSTER cl_device_periph(device_id);

CREATE TABLE PERIPHERAL (
  peripheral_id         NUMBER,
  site_id               NUMBER         NOT NULL,
  room_id               NUMBER         NOT NULL,
  assigned_device_id    NUMBER,
  peripheral_type_id    NUMBER         NOT NULL,
  peripheral_name       VARCHAR2(80)   NOT NULL,
  serial_number         VARCHAR2(80),
  peripheral_status     VARCHAR2(20)   DEFAULT 'AVAILABLE' NOT NULL,
  CONSTRAINT FK_PERIPHERAL_ROOM   FOREIGN KEY (room_id)           REFERENCES ROOM(room_id),
  CONSTRAINT FK_PERIPHERAL_DEVICE FOREIGN KEY (assigned_device_id) REFERENCES DEVICE(device_id),
  CONSTRAINT FK_PERIPHERAL_TYPE   FOREIGN KEY (peripheral_type_id) REFERENCES PERIPHERAL_TYPE(peripheral_type_id),
  CONSTRAINT CK_PERIPHERAL_SITE CHECK (site_id = 1),
  CONSTRAINT CK_PERIPHERAL_STATUS CHECK (peripheral_status IN ('AVAILABLE','ASSIGNED','BROKEN'))
)
CLUSTER cl_device_periph(assigned_device_id);

CREATE TABLE DEVICE_ASSIGNMENT (
  assignment_id        NUMBER        CONSTRAINT PK_DEVICE_ASSIGNMENT PRIMARY KEY,
  device_id            NUMBER        NOT NULL,
  person_id            NUMBER        NOT NULL,
  assigned_at          DATE          NOT NULL,
  returned_at          DATE,
  CONSTRAINT FK_ASSIGN_DEVICE FOREIGN KEY (device_id) REFERENCES DEVICE(device_id),
  CONSTRAINT FK_ASSIGN_PERSON FOREIGN KEY (person_id) REFERENCES PERSON(person_id),
  CONSTRAINT CK_ASSIGN_DATES CHECK (returned_at IS NULL OR returned_at >= assigned_at)
) TABLESPACE DATA_CERGY;

-- site_id = site du device concerne (1=Cergy, 2=Pau)
-- device_id sans FK declarative : device Pau inaccessible en FK cross-site
-- FK_TICKET_SITE supprimee : SITE est une MV
-- Validation assuree par PROC_CREATE_TICKET
CREATE TABLE MAINTENANCE_TICKET (
  ticket_id             NUMBER         CONSTRAINT PK_MAINTENANCE_TICKET PRIMARY KEY,
  site_id               NUMBER         NOT NULL,
  device_id             NUMBER         NOT NULL,
  opened_by_person_id   NUMBER         NOT NULL,
  technician_id         NUMBER,
  issue_label           VARCHAR2(150)  NOT NULL,
  ticket_status         VARCHAR2(20)   DEFAULT 'OPEN' NOT NULL,
  opened_at             DATE           NOT NULL,
  closed_at             DATE,
  CONSTRAINT FK_TICKET_OPENED_BY FOREIGN KEY (opened_by_person_id) REFERENCES PERSON(person_id),
  CONSTRAINT FK_TICKET_TECH      FOREIGN KEY (technician_id)       REFERENCES PERSON(person_id),
  CONSTRAINT CK_TICKET_SITE   CHECK (site_id IN (1, 2)),
  CONSTRAINT CK_TICKET_STATUS CHECK (ticket_status IN ('OPEN','IN_PROGRESS','CLOSED')),
  CONSTRAINT CK_TICKET_DATES  CHECK (closed_at IS NULL OR closed_at >= opened_at)
) TABLESPACE DATA_CERGY;

-- ============================================================
-- 6. INDEX
-- ============================================================
CREATE INDEX IDX_PERSON_ROLE      ON PERSON(role_id)                       TABLESPACE IDX_CERGY;
CREATE INDEX IDX_DEVICE_ROOM      ON DEVICE(room_id)                       TABLESPACE IDX_CERGY;
CREATE INDEX IDX_DEVICE_PERSON    ON DEVICE(assigned_person_id)            TABLESPACE IDX_CERGY;
CREATE INDEX IDX_DEVICE_TYPE      ON DEVICE(device_type_id)                TABLESPACE IDX_CERGY;
CREATE INDEX IDX_PERIPHERAL_DEVICE ON PERIPHERAL(assigned_device_id)       TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ASSIGN_DEVICE    ON DEVICE_ASSIGNMENT(device_id)          TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ASSIGN_PERSON    ON DEVICE_ASSIGNMENT(person_id)          TABLESPACE IDX_CERGY;
CREATE INDEX IDX_TICKET_STATUS    ON MAINTENANCE_TICKET(ticket_status)     TABLESPACE IDX_CERGY;
CREATE INDEX IDX_TICKET_SITE      ON MAINTENANCE_TICKET(site_id)           TABLESPACE IDX_CERGY;

CREATE SEQUENCE SEQ_TICKET_ID START WITH 100 INCREMENT BY 1 NOCACHE;

-- ============================================================
-- 7. DONNEES DE REFERENCE — PROPRIETE CERGY
-- ============================================================
-- SITE et PERSON_ROLE : pas d'INSERT ici, gerees par Pau.
-- Cergy les lira via MV_SITE et MV_PERSON_ROLE (cf. 04_replication.sql).

INSERT INTO DEVICE_TYPE VALUES (1, 'DESKTOP', 'Ordinateur fixe');
INSERT INTO DEVICE_TYPE VALUES (2, 'LAPTOP',  'Ordinateur portable');
INSERT INTO DEVICE_TYPE VALUES (3, 'TABLET',  'Tablette');

INSERT INTO OS_FAMILY VALUES (1, 'Windows');
INSERT INTO OS_FAMILY VALUES (2, 'Linux');
INSERT INTO OS_FAMILY VALUES (3, 'iPadOS');
INSERT INTO OS_FAMILY VALUES (4, 'Android');

INSERT INTO OS_VERSION VALUES (1, 1, 'Windows 11');
INSERT INTO OS_VERSION VALUES (2, 2, 'Ubuntu 24.04');
INSERT INTO OS_VERSION VALUES (3, 3, 'iPadOS 18');
INSERT INTO OS_VERSION VALUES (4, 4, 'Android 15');

INSERT INTO PERIPHERAL_TYPE VALUES (1, 'SCREEN',   'Ecran');
INSERT INTO PERIPHERAL_TYPE VALUES (2, 'MOUSE',    'Souris');
INSERT INTO PERIPHERAL_TYPE VALUES (3, 'KEYBOARD', 'Clavier');
INSERT INTO PERIPHERAL_TYPE VALUES (4, 'STYLUS',   'Stylet');
INSERT INTO PERIPHERAL_TYPE VALUES (5, 'DOCK',     'Station d''accueil');

-- ============================================================
-- 8. DONNEES LOCALES CERGY
-- ============================================================
INSERT INTO BUILDING VALUES (1, 1, 'A', 'Batiment A');
INSERT INTO BUILDING VALUES (2, 1, 'B', 'Batiment B');

INSERT INTO ROOM VALUES (1, 1, 'A101', 'Salle TP Informatique', 'LAB', 28);
INSERT INTO ROOM VALUES (2, 1, 'A202', 'Salle Tablettes', 'LAB', 20);
INSERT INTO ROOM VALUES (3, 2, 'B015', 'Bureau Enseignants', 'OFFICE', 8);

-- role_id reference PERSON_ROLE : valeurs 1-4 garanties par Pau (source de verite)
INSERT INTO PERSON VALUES (1, 1, 3, 'admin.cergy',   'Admin',   'Cergy', 'admin.cergy@cytech.fr',   'ACTIVE');
INSERT INTO PERSON VALUES (2, 1, 1, 'martin.alice',  'Martin',  'Alice', 'alice.martin@cytech.fr',  'ACTIVE');
INSERT INTO PERSON VALUES (3, 1, 2, 'dupont.leo',    'Dupont',  'Leo',   'leo.dupont@cytech.fr',    'ACTIVE');
INSERT INTO PERSON VALUES (4, 1, 1, 'bernard.emma',  'Bernard', 'Emma',  'emma.bernard@cytech.fr',  'ACTIVE');

INSERT INTO DEVICE VALUES (1, 1, 1, 2, 1, 1, 'CGY-PC-001',  'PC Salle A101-01',       'SN-CGY-PC-001',  DATE '2024-09-01', 'IN_SERVICE');
INSERT INTO DEVICE VALUES (2, 1, 1, NULL, 1, 1, 'CGY-PC-002','PC Salle A101-02',       'SN-CGY-PC-002',  DATE '2024-09-01', 'IN_REPAIR');
INSERT INTO DEVICE VALUES (3, 1, 2, 4, 3, 3,   'CGY-TAB-001','Tablette Salle A202-01', 'SN-CGY-TAB-001', DATE '2025-01-10', 'IN_SERVICE');
INSERT INTO DEVICE VALUES (4, 1, 3, 1, 2, 1,   'CGY-LAP-001','Portable Administration','SN-CGY-LAP-001', DATE '2023-10-15', 'IN_SERVICE');

INSERT INTO PERIPHERAL VALUES (1, 1, 1, 1, 1, 'Ecran 24 pouces A101-01', 'SN-CGY-SCR-001', 'ASSIGNED');
INSERT INTO PERIPHERAL VALUES (2, 1, 1, 1, 2, 'Souris A101-01',           'SN-CGY-MOU-001', 'ASSIGNED');
INSERT INTO PERIPHERAL VALUES (3, 1, 2, 3, 4, 'Stylet tablette A202-01',  'SN-CGY-STY-001', 'ASSIGNED');
INSERT INTO PERIPHERAL VALUES (4, 1, 3, 4, 5, 'Dock administration',       'SN-CGY-DOC-001', 'ASSIGNED');

INSERT INTO DEVICE_ASSIGNMENT VALUES (1, 1, 2, DATE '2024-09-05', NULL);
INSERT INTO DEVICE_ASSIGNMENT VALUES (2, 3, 4, DATE '2025-01-12', NULL);
INSERT INTO DEVICE_ASSIGNMENT VALUES (3, 4, 1, DATE '2023-10-16', NULL);

INSERT INTO MAINTENANCE_TICKET VALUES (1, 1, 2, 2, 3, 'PC de salle A101 qui ne demarre plus',       'IN_PROGRESS', DATE '2026-05-01', NULL);
INSERT INTO MAINTENANCE_TICKET VALUES (2, 1, 4, 1, 3, 'Changement de batterie du portable admin',   'CLOSED',      DATE '2026-03-10', DATE '2026-03-14');

COMMIT;

-- ============================================================
-- 9. DB LINK VERS PAU
-- ============================================================
CREATE DATABASE LINK LNK_PAU
CONNECT TO CYTECH_PAU IDENTIFIED BY pau2026
USING '//localhost:1521/XEPDB1';

-- ============================================================
-- Objets cross-site (MV_SITE, MV_PERSON_ROLE, V_PAU_DEVICE_MIN,
-- PROC_CREATE_TICKET) : crees dans 04_replication.sql, une fois
-- que les deux schemas existent (Cergy ET Pau).
-- ============================================================
