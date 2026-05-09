-- ============================================================
--  SCRIPT 1 : SITE CERGY
--  CY Tech - Gestion du Parc Informatique - BDDR
--  Schéma : CYTECH_CERGY
--
--  ORDRE D'EXÉCUTION :
--    1. Sections 1-2  → en tant que SYSDBA
--    2. Section 3     → CONNECT CYTECH_CERGY/cergy2026
--    3. Sections 4+   → en tant que CYTECH_CERGY
-- ============================================================

-- ============================================================
-- 0. NETTOYAGE (SYSDBA uniquement)
-- ============================================================
-- DROP USER CYTECH_CERGY CASCADE;
-- DROP TABLESPACE DATA_CERGY  INCLUDING CONTENTS AND DATAFILES;
-- DROP TABLESPACE IDX_CERGY   INCLUDING CONTENTS AND DATAFILES;
-- DROP TABLESPACE AUDIT_CERGY INCLUDING CONTENTS AND DATAFILES;


-- ============================================================
-- 1. TABLESPACES  (SYSDBA)
-- ============================================================

-- CREATE TABLESPACE DATA_CERGY
--   DATAFILE 'data_cergy.dbf' SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 500M
--   EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
--   SEGMENT SPACE MANAGEMENT AUTO;

-- CREATE TABLESPACE IDX_CERGY
--   DATAFILE 'idx_cergy.dbf' SIZE 20M AUTOEXTEND ON NEXT 5M MAXSIZE 200M
--   EXTENT MANAGEMENT LOCAL UNIFORM SIZE 512K
--   SEGMENT SPACE MANAGEMENT AUTO;

-- CREATE TABLESPACE AUDIT_CERGY
--   DATAFILE 'audit_cergy.dbf' SIZE 20M AUTOEXTEND ON NEXT 5M MAXSIZE 200M
--   EXTENT MANAGEMENT LOCAL UNIFORM SIZE 512K
--   SEGMENT SPACE MANAGEMENT AUTO;


-- ============================================================
-- 2. UTILISATEUR / SCHÉMA  (SYSDBA)
-- ============================================================

-- CREATE USER CYTECH_CERGY IDENTIFIED BY cergy2026
--   DEFAULT TABLESPACE DATA_CERGY
--   TEMPORARY TABLESPACE TEMP
--   QUOTA UNLIMITED ON DATA_CERGY
--   QUOTA UNLIMITED ON IDX_CERGY
--   QUOTA UNLIMITED ON AUDIT_CERGY;

-- GRANT CONNECT, RESOURCE TO CYTECH_CERGY;
-- GRANT CREATE VIEW, CREATE SYNONYM,
--       CREATE DATABASE LINK,
--       CREATE PROCEDURE, CREATE TRIGGER,
--       CREATE SEQUENCE, CREATE TABLE TO CYTECH_CERGY;


-- ============================================================
-- 3. CONNEXION
-- ============================================================
-- CONNECT CYTECH_CERGY/cergy2026;


-- ============================================================
-- 4. SÉQUENCES
--    Référentiels  : démarrent après le max des ID insérés en dur
--    Données locales Cergy : démarrent à 1
-- ============================================================

-- Référentiels (même IDs sur les deux sites — ne jamais appeler NEXTVAL
--               sur ces séquences autrement que depuis la procédure de sync)
CREATE SEQUENCE SEQ_SITE     START WITH 3  INCREMENT BY 1 NOCACHE; -- IDs 1,2 réservés
CREATE SEQUENCE SEQ_ROLE     START WITH 5  INCREMENT BY 1 NOCACHE; -- IDs 1-4 réservés
CREATE SEQUENCE SEQ_MANUF    START WITH 6  INCREMENT BY 1 NOCACHE; -- IDs 1-5 réservés
CREATE SEQUENCE SEQ_ATYPE    START WITH 7  INCREMENT BY 1 NOCACHE; -- IDs 1-6 réservés
CREATE SEQUENCE SEQ_STATE    START WITH 6  INCREMENT BY 1 NOCACHE; -- IDs 1-5 réservés
CREATE SEQUENCE SEQ_MODEL    START WITH 5  INCREMENT BY 1 NOCACHE; -- IDs 1-4 réservés
CREATE SEQUENCE SEQ_OSFAM    START WITH 4  INCREMENT BY 1 NOCACHE; -- IDs 1-3 réservés
CREATE SEQUENCE SEQ_OSVER    START WITH 6  INCREMENT BY 1 NOCACHE; -- IDs 1-5 réservés
CREATE SEQUENCE SEQ_ARCH     START WITH 4  INCREMENT BY 1 NOCACHE; -- IDs 1-3 réservés

-- Données locales Cergy (IDs 1 à ~9999, Pau utilise 10001+)
CREATE SEQUENCE SEQ_BUILDING  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_ROOM      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_USER      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_USERROLE  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_ASSET     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_ASSIGN    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_MOVE      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_ASSET_OS  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_VLAN      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SEGMENT   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_PORT      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_PVLAN     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_IP        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_LINK      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_AUDIT_LOG START WITH 1 INCREMENT BY 1 NOCACHE;


-- ============================================================
-- 5. TABLES DE RÉFÉRENTIELS
--    Répliquées manuellement sur CYTECH_PAU avec les mêmes IDs.
--    Toute modification doit être propagée sur les deux sites.
-- ============================================================

CREATE TABLE SITE (
  site_id    NUMBER        CONSTRAINT PK_SITE PRIMARY KEY,
  site_code  VARCHAR2(10)  CONSTRAINT UK_SITE_CODE UNIQUE NOT NULL,
  site_name  VARCHAR2(80)  NOT NULL,
  city       VARCHAR2(50),
  is_active  CHAR(1)       DEFAULT 'Y' CONSTRAINT CK_SITE_ACTIVE CHECK (is_active IN ('Y','N'))
) TABLESPACE DATA_CERGY;

CREATE TABLE APP_ROLE (
  role_id     NUMBER        CONSTRAINT PK_ROLE PRIMARY KEY,
  role_code   VARCHAR2(30)  CONSTRAINT UK_ROLE_CODE UNIQUE NOT NULL,
  role_label  VARCHAR2(80)  NOT NULL,
  scope_level VARCHAR2(20)  CONSTRAINT CK_ROLE_SCOPE CHECK (scope_level IN ('GLOBAL','SITE','LOCAL'))
) TABLESPACE DATA_CERGY;

CREATE TABLE MANUFACTURER (
  manufacturer_id   NUMBER        CONSTRAINT PK_MANUF PRIMARY KEY,
  manufacturer_name VARCHAR2(120) CONSTRAINT UK_MANUF_NAME UNIQUE NOT NULL
) TABLESPACE DATA_CERGY;

CREATE TABLE ASSET_TYPE (
  asset_type_id NUMBER        CONSTRAINT PK_ATYPE PRIMARY KEY,
  type_code     VARCHAR2(30)  CONSTRAINT UK_ATYPE_CODE UNIQUE NOT NULL,
  type_label    VARCHAR2(80)  NOT NULL
) TABLESPACE DATA_CERGY;

CREATE TABLE ASSET_STATE (
  state_id      NUMBER        CONSTRAINT PK_STATE PRIMARY KEY,
  state_code    VARCHAR2(20)  CONSTRAINT UK_STATE_CODE UNIQUE NOT NULL,
  state_label   VARCHAR2(80)  NOT NULL,
  is_assignable CHAR(1)       DEFAULT 'Y' CONSTRAINT CK_STATE_ASSIGN CHECK (is_assignable IN ('Y','N'))
) TABLESPACE DATA_CERGY;

CREATE TABLE ASSET_MODEL (
  model_id        NUMBER        CONSTRAINT PK_MODEL PRIMARY KEY,
  manufacturer_id NUMBER        NOT NULL CONSTRAINT FK_MODEL_MANUF REFERENCES MANUFACTURER(manufacturer_id),
  asset_type_id   NUMBER        NOT NULL CONSTRAINT FK_MODEL_ATYPE REFERENCES ASSET_TYPE(asset_type_id),
  model_name      VARCHAR2(120) NOT NULL,
  product_number  VARCHAR2(80),
  rack_units      NUMBER,
  power_watts     NUMBER,
  depth_cm        NUMBER
) TABLESPACE DATA_CERGY;

CREATE TABLE OS_FAMILY (
  os_family_id NUMBER        CONSTRAINT PK_OSFAM PRIMARY KEY,
  os_name      VARCHAR2(80)  CONSTRAINT UK_OSFAM_NAME UNIQUE NOT NULL
) TABLESPACE DATA_CERGY;

CREATE TABLE OS_VERSION (
  os_version_id NUMBER        CONSTRAINT PK_OSVER PRIMARY KEY,
  os_family_id  NUMBER        NOT NULL CONSTRAINT FK_OSVER_FAM REFERENCES OS_FAMILY(os_family_id),
  version_label VARCHAR2(80)  NOT NULL,
  version_rank  NUMBER        DEFAULT 0
) TABLESPACE DATA_CERGY;

CREATE TABLE CPU_ARCH (
  arch_id    NUMBER        CONSTRAINT PK_ARCH PRIMARY KEY,
  arch_label VARCHAR2(30)  CONSTRAINT UK_ARCH_LABEL UNIQUE NOT NULL,
  bits       NUMBER        DEFAULT 64
) TABLESPACE DATA_CERGY;


-- ============================================================
-- 6. TABLES LOCALES CERGY (fragment horizontal : site_id = 1)
-- ============================================================

CREATE TABLE BUILDING (
  building_id   NUMBER        CONSTRAINT PK_BUILDING PRIMARY KEY,
  site_id       NUMBER        NOT NULL CONSTRAINT FK_BUILD_SITE REFERENCES SITE(site_id),
  building_code VARCHAR2(10)  NOT NULL,
  building_name VARCHAR2(80),
  address_line  VARCHAR2(150),
  CONSTRAINT UK_BUILDING   UNIQUE (site_id, building_code),
  CONSTRAINT CK_BUILD_SITE CHECK  (site_id = 1)
) TABLESPACE DATA_CERGY;

CREATE TABLE ROOM (
  room_id     NUMBER        CONSTRAINT PK_ROOM PRIMARY KEY,
  building_id NUMBER        NOT NULL CONSTRAINT FK_ROOM_BUILD REFERENCES BUILDING(building_id),
  room_code   VARCHAR2(20)  NOT NULL,
  room_name   VARCHAR2(80),
  floor_no    NUMBER,
  room_type   VARCHAR2(30),
  CONSTRAINT UK_ROOM UNIQUE (building_id, room_code)
) TABLESPACE DATA_CERGY;

CREATE TABLE APP_USER (
  user_id      NUMBER        CONSTRAINT PK_USER PRIMARY KEY,
  home_site_id NUMBER        NOT NULL CONSTRAINT FK_USER_SITE REFERENCES SITE(site_id),
  login        VARCHAR2(50)  CONSTRAINT UK_USER_LOGIN UNIQUE NOT NULL,
  last_name    VARCHAR2(80)  NOT NULL,
  first_name   VARCHAR2(80),
  email        VARCHAR2(120) CONSTRAINT UK_USER_EMAIL UNIQUE NOT NULL,
  user_status  VARCHAR2(20)  DEFAULT 'ACTIVE' CONSTRAINT CK_USER_STATUS CHECK (user_status IN ('ACTIVE','INACTIVE','LOCKED')),
  created_at   DATE          DEFAULT SYSDATE,
  CONSTRAINT CK_USER_SITE CHECK (home_site_id = 1)
) TABLESPACE DATA_CERGY;

CREATE TABLE USER_ROLE (
  user_role_id NUMBER  CONSTRAINT PK_USERROLE PRIMARY KEY,
  user_id      NUMBER  NOT NULL CONSTRAINT FK_UR_USER REFERENCES APP_USER(user_id),
  role_id      NUMBER  NOT NULL CONSTRAINT FK_UR_ROLE REFERENCES APP_ROLE(role_id),
  site_id      NUMBER  NOT NULL CONSTRAINT FK_UR_SITE REFERENCES SITE(site_id),
  granted_at   DATE    DEFAULT SYSDATE,
  expires_at   DATE,
  CONSTRAINT UK_USERROLE UNIQUE (user_id, role_id, site_id)
) TABLESPACE DATA_CERGY;

CREATE TABLE ASSET (
  asset_id        NUMBER        CONSTRAINT PK_ASSET PRIMARY KEY,
  site_id         NUMBER        NOT NULL CONSTRAINT FK_ASSET_SITE  REFERENCES SITE(site_id),
  room_id         NUMBER                 CONSTRAINT FK_ASSET_ROOM  REFERENCES ROOM(room_id),
  asset_type_id   NUMBER        NOT NULL CONSTRAINT FK_ASSET_ATYPE REFERENCES ASSET_TYPE(asset_type_id),
  model_id        NUMBER        NOT NULL CONSTRAINT FK_ASSET_MODEL REFERENCES ASSET_MODEL(model_id),
  state_id        NUMBER        NOT NULL CONSTRAINT FK_ASSET_STATE REFERENCES ASSET_STATE(state_id),
  current_user_id NUMBER                 CONSTRAINT FK_ASSET_USR   REFERENCES APP_USER(user_id),
  current_tech_id NUMBER                 CONSTRAINT FK_ASSET_TECH  REFERENCES APP_USER(user_id),
  asset_tag       VARCHAR2(50)  CONSTRAINT UK_ASSET_TAG UNIQUE NOT NULL,
  serial_number   VARCHAR2(80),
  other_serial    VARCHAR2(80),
  purchase_date   DATE,
  warranty_end    DATE,
  is_template     CHAR(1)       DEFAULT 'N' CONSTRAINT CK_ASSET_TPL CHECK (is_template IN ('Y','N')),
  is_deleted      CHAR(1)       DEFAULT 'N' CONSTRAINT CK_ASSET_DEL CHECK (is_deleted  IN ('Y','N')),
  created_at      DATE          DEFAULT SYSDATE,
  updated_at      DATE          DEFAULT SYSDATE,
  CONSTRAINT CK_ASSET_SITE CHECK (site_id = 1)
) TABLESPACE DATA_CERGY;

CREATE TABLE ASSET_ASSIGNMENT_HISTORY (
  assignment_id NUMBER  CONSTRAINT PK_ASSIGN PRIMARY KEY,
  asset_id      NUMBER  NOT NULL CONSTRAINT FK_ASSIGN_ASSET REFERENCES ASSET(asset_id),
  user_id       NUMBER  NOT NULL CONSTRAINT FK_ASSIGN_USER  REFERENCES APP_USER(user_id),
  assigned_by   NUMBER           CONSTRAINT FK_ASSIGN_BY    REFERENCES APP_USER(user_id),
  assigned_at   DATE    DEFAULT SYSDATE NOT NULL,
  returned_at   DATE,
  usage_type    VARCHAR2(30),
  CONSTRAINT CK_ASSIGN_DATES CHECK (returned_at IS NULL OR returned_at >= assigned_at)
) TABLESPACE AUDIT_CERGY;

CREATE TABLE ASSET_MOVEMENT (
  movement_id     NUMBER        CONSTRAINT PK_MOVE PRIMARY KEY,
  asset_id        NUMBER        NOT NULL CONSTRAINT FK_MOVE_ASSET REFERENCES ASSET(asset_id),
  from_room_id    NUMBER                 CONSTRAINT FK_MOVE_FROM  REFERENCES ROOM(room_id),
  to_room_id      NUMBER                 CONSTRAINT FK_MOVE_TO    REFERENCES ROOM(room_id),
  moved_by        NUMBER                 CONSTRAINT FK_MOVE_BY    REFERENCES APP_USER(user_id),
  moved_at        DATE          DEFAULT SYSDATE NOT NULL,
  movement_reason VARCHAR2(120)
) TABLESPACE AUDIT_CERGY;

CREATE TABLE ASSET_OS (
  asset_os_id   NUMBER  CONSTRAINT PK_ASSET_OS PRIMARY KEY,
  asset_id      NUMBER  NOT NULL CONSTRAINT FK_AOS_ASSET REFERENCES ASSET(asset_id),
  os_family_id  NUMBER  NOT NULL CONSTRAINT FK_AOS_FAM   REFERENCES OS_FAMILY(os_family_id),
  os_version_id NUMBER           CONSTRAINT FK_AOS_VER   REFERENCES OS_VERSION(os_version_id),
  arch_id       NUMBER           CONSTRAINT FK_AOS_ARCH  REFERENCES CPU_ARCH(arch_id),
  install_date  DATE,
  is_main_os    CHAR(1) DEFAULT 'Y' CONSTRAINT CK_AOS_MAIN CHECK (is_main_os IN ('Y','N'))
) TABLESPACE DATA_CERGY;

CREATE TABLE VLAN (
  vlan_id     NUMBER        CONSTRAINT PK_VLAN PRIMARY KEY,
  site_id     NUMBER        NOT NULL CONSTRAINT FK_VLAN_SITE REFERENCES SITE(site_id),
  vlan_number NUMBER        NOT NULL,
  vlan_name   VARCHAR2(80),
  CONSTRAINT UK_VLAN      UNIQUE (site_id, vlan_number),
  CONSTRAINT CK_VLAN_SITE CHECK  (site_id = 1)
) TABLESPACE DATA_CERGY;

CREATE TABLE NETWORK_SEGMENT (
  segment_id  NUMBER        CONSTRAINT PK_SEGMENT PRIMARY KEY,
  site_id     NUMBER        NOT NULL CONSTRAINT FK_SEG_SITE REFERENCES SITE(site_id),
  vlan_id     NUMBER                 CONSTRAINT FK_SEG_VLAN REFERENCES VLAN(vlan_id),
  cidr_block  VARCHAR2(32)  NOT NULL,
  gateway_ip  VARCHAR2(45),
  dns_domain  VARCHAR2(120),
  usage_label VARCHAR2(80),
  CONSTRAINT CK_SEG_SITE CHECK (site_id = 1)
) TABLESPACE DATA_CERGY;


-- ============================================================
-- CLUSTER PORT-IP
--   Objectif : co-localiser NETWORK_PORT et IP_ADDRESS sur port_id
--   pour accélérer la jointure PORT ↔ IP (fréquente dans V_GLOBAL_NETWORK).
--   Les deux tables ci-dessous sont créées DANS le cluster.
-- ============================================================

CREATE CLUSTER CL_PORT_IP (port_id NUMBER)
  SIZE 512 TABLESPACE DATA_CERGY;

CREATE INDEX IDX_CL_PORT_IP ON CLUSTER CL_PORT_IP;

CREATE TABLE NETWORK_PORT (
  port_id         NUMBER        CONSTRAINT PK_PORT PRIMARY KEY,
  asset_id        NUMBER        NOT NULL CONSTRAINT FK_PORT_ASSET REFERENCES ASSET(asset_id),
  port_name       VARCHAR2(50),
  mac_address     VARCHAR2(17)  CONSTRAINT UK_PORT_MAC UNIQUE,
  port_speed_mbps NUMBER,
  port_status     VARCHAR2(20)  DEFAULT 'UP'       CONSTRAINT CK_PORT_STATUS CHECK (port_status IN ('UP','DOWN','UNKNOWN')),
  port_kind       VARCHAR2(20)  DEFAULT 'ETHERNET'
) CLUSTER CL_PORT_IP(port_id);

CREATE TABLE PORT_VLAN (
  port_vlan_id NUMBER  CONSTRAINT PK_PVLAN PRIMARY KEY,
  port_id      NUMBER  NOT NULL CONSTRAINT FK_PV_PORT REFERENCES NETWORK_PORT(port_id),
  vlan_id      NUMBER  NOT NULL CONSTRAINT FK_PV_VLAN REFERENCES VLAN(vlan_id),
  vlan_mode    VARCHAR2(10) DEFAULT 'ACCESS' CONSTRAINT CK_PV_MODE   CHECK (vlan_mode IN ('ACCESS','TRUNK')),
  is_native    CHAR(1)      DEFAULT 'N'      CONSTRAINT CK_PV_NATIVE CHECK (is_native  IN ('Y','N')),
  CONSTRAINT UK_PVLAN UNIQUE (port_id, vlan_id)
) TABLESPACE DATA_CERGY;

-- port_id nullable : les IPs libres/réservées (sans port) vont dans le bucket NULL du cluster.
-- Cela reste valide ; les IPs affectées à un port sont co-localisées avec leur PORT.
CREATE TABLE IP_ADDRESS (
  ip_id             NUMBER        CONSTRAINT PK_IP PRIMARY KEY,
  segment_id        NUMBER        NOT NULL CONSTRAINT FK_IP_SEG  REFERENCES NETWORK_SEGMENT(segment_id),
  port_id           NUMBER                 CONSTRAINT FK_IP_PORT REFERENCES NETWORK_PORT(port_id),
  ip_value          VARCHAR2(45)  CONSTRAINT UK_IP_VAL UNIQUE NOT NULL,
  dns_name          VARCHAR2(120),
  is_static         CHAR(1)       DEFAULT 'Y'    CONSTRAINT CK_IP_STATIC CHECK (is_static         IN ('Y','N')),
  allocation_status VARCHAR2(20)  DEFAULT 'USED' CONSTRAINT CK_IP_STATUS CHECK (allocation_status IN ('USED','FREE','RESERVED'))
) CLUSTER CL_PORT_IP(port_id);

CREATE TABLE PORT_LINK (
  link_id        NUMBER  CONSTRAINT PK_LINK PRIMARY KEY,
  src_port_id    NUMBER  NOT NULL CONSTRAINT FK_LINK_SRC REFERENCES NETWORK_PORT(port_id),
  dst_port_id    NUMBER  NOT NULL CONSTRAINT FK_LINK_DST REFERENCES NETWORK_PORT(port_id),
  link_type      VARCHAR2(20),
  bandwidth_mbps NUMBER,
  link_status    VARCHAR2(20) DEFAULT 'ACTIVE' CONSTRAINT CK_LINK_STATUS CHECK (link_status IN ('ACTIVE','INACTIVE')),
  CONSTRAINT CK_LINK_NOSELF CHECK (src_port_id <> dst_port_id)
) TABLESPACE DATA_CERGY;

-- Table de traçabilité — alimentée par les triggers PL/SQL (cf. TODO.md)
CREATE TABLE AUDIT_LOG (
  log_id      NUMBER          CONSTRAINT PK_AUDIT_LOG PRIMARY KEY,
  log_time    TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  schema_user VARCHAR2(50)    DEFAULT SYS_CONTEXT('USERENV','SESSION_USER') NOT NULL,
  table_name  VARCHAR2(50)    NOT NULL,
  operation   VARCHAR2(10)    NOT NULL CONSTRAINT CK_LOG_OP CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  record_id   NUMBER,
  old_value   VARCHAR2(4000),
  new_value   VARCHAR2(4000)
) TABLESPACE AUDIT_CERGY;


-- ============================================================
-- 7. INDEX
-- ============================================================

-- ASSET
CREATE INDEX IDX_ASSET_SITE_STATE ON ASSET(site_id, state_id)         TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ASSET_SITE_TYPE  ON ASSET(site_id, asset_type_id)    TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ASSET_MODEL      ON ASSET(model_id)                   TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ASSET_USER       ON ASSET(current_user_id)            TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ASSET_DATES      ON ASSET(purchase_date, warranty_end) TABLESPACE IDX_CERGY;

-- ASSET_OS
CREATE INDEX IDX_AOS_ASSET        ON ASSET_OS(asset_id)               TABLESPACE IDX_CERGY;
CREATE INDEX IDX_AOS_OSVER        ON ASSET_OS(os_version_id)          TABLESPACE IDX_CERGY;

-- Un seul OS principal par asset : index unique fonctionnel sur la valeur non-NULL
CREATE UNIQUE INDEX UQ_ASSET_MAIN_OS
  ON ASSET_OS (CASE WHEN is_main_os = 'Y' THEN asset_id ELSE NULL END)
  TABLESPACE IDX_CERGY;

-- USER_ROLE
CREATE INDEX IDX_UR_USER_SITE     ON USER_ROLE(user_id, site_id)      TABLESPACE IDX_CERGY;
CREATE INDEX IDX_UR_ROLE          ON USER_ROLE(role_id)               TABLESPACE IDX_CERGY;

-- RÉSEAU (PORT_VLAN, SEGMENT)
CREATE INDEX IDX_PORT_ASSET       ON NETWORK_PORT(asset_id)           TABLESPACE IDX_CERGY;
CREATE INDEX IDX_IP_SEGMENT       ON IP_ADDRESS(segment_id)           TABLESPACE IDX_CERGY;
CREATE INDEX IDX_PVLAN_VLAN       ON PORT_VLAN(vlan_id)               TABLESPACE IDX_CERGY;

-- HISTORIQUE
CREATE INDEX IDX_ASSIGN_ASSET     ON ASSET_ASSIGNMENT_HISTORY(asset_id, assigned_at) TABLESPACE IDX_CERGY;
CREATE INDEX IDX_MOVE_ASSET       ON ASSET_MOVEMENT(asset_id, moved_at)              TABLESPACE IDX_CERGY;

-- USERS
CREATE INDEX IDX_USER_SITE        ON APP_USER(home_site_id)           TABLESPACE IDX_CERGY;

-- AUDIT
CREATE INDEX IDX_AUDIT_TABLE_TIME ON AUDIT_LOG(table_name, log_time)  TABLESPACE IDX_CERGY;


-- ============================================================
-- 8. DONNÉES DE RÉFÉRENCE (IDs identiques sur les deux sites)
-- ============================================================

INSERT INTO SITE VALUES (1, 'CERGY', 'CY Tech Cergy', 'Cergy', 'Y');
INSERT INTO SITE VALUES (2, 'PAU',   'CY Tech Pau',   'Pau',   'Y');

INSERT INTO APP_ROLE VALUES (1, 'ADMIN_GLOBAL', 'Administrateur Global',       'GLOBAL');
INSERT INTO APP_ROLE VALUES (2, 'IT_SITE',      'Technicien SI Site',          'SITE');
INSERT INTO APP_ROLE VALUES (3, 'USER_SITE',    'Utilisateur Site',            'LOCAL');
INSERT INTO APP_ROLE VALUES (4, 'AUDITEUR',     'Auditeur / Reporting Global', 'GLOBAL');

INSERT INTO ASSET_TYPE VALUES (1, 'PC',      'Ordinateur fixe');
INSERT INTO ASSET_TYPE VALUES (2, 'LAPTOP',  'Ordinateur portable');
INSERT INTO ASSET_TYPE VALUES (3, 'SERVER',  'Serveur');
INSERT INTO ASSET_TYPE VALUES (4, 'SWITCH',  'Commutateur réseau');
INSERT INTO ASSET_TYPE VALUES (5, 'ROUTER',  'Routeur');
INSERT INTO ASSET_TYPE VALUES (6, 'PRINTER', 'Imprimante');

INSERT INTO ASSET_STATE VALUES (1, 'IN_USE',    'En service',    'Y');
INSERT INTO ASSET_STATE VALUES (2, 'STOCK',     'En stock',      'Y');
INSERT INTO ASSET_STATE VALUES (3, 'REPAIR',    'En réparation', 'N');
INSERT INTO ASSET_STATE VALUES (4, 'DISCARDED', 'Mis au rebut',  'N');
INSERT INTO ASSET_STATE VALUES (5, 'LOST',      'Perdu / Volé',  'N');

INSERT INTO MANUFACTURER VALUES (1, 'Dell');
INSERT INTO MANUFACTURER VALUES (2, 'HP');
INSERT INTO MANUFACTURER VALUES (3, 'Lenovo');
INSERT INTO MANUFACTURER VALUES (4, 'Cisco');
INSERT INTO MANUFACTURER VALUES (5, 'Apple');

INSERT INTO OS_FAMILY VALUES (1, 'Windows');
INSERT INTO OS_FAMILY VALUES (2, 'Linux');
INSERT INTO OS_FAMILY VALUES (3, 'macOS');

INSERT INTO OS_VERSION VALUES (1, 1, 'Windows 11',    3);
INSERT INTO OS_VERSION VALUES (2, 1, 'Windows 10',    2);
INSERT INTO OS_VERSION VALUES (3, 2, 'Ubuntu 24.04',  3);
INSERT INTO OS_VERSION VALUES (4, 2, 'Debian 12',     2);
INSERT INTO OS_VERSION VALUES (5, 3, 'macOS Sequoia', 3);

INSERT INTO CPU_ARCH VALUES (1, 'x86_64', 64);
INSERT INTO CPU_ARCH VALUES (2, 'ARM64',  64);
INSERT INTO CPU_ARCH VALUES (3, 'x86',    32);

INSERT INTO ASSET_MODEL VALUES (1, 1, 1, 'OptiPlex 7090',        'OP7090',  4, 180, 40);
INSERT INTO ASSET_MODEL VALUES (2, 3, 2, 'ThinkPad X1 Carbon',   'TPXC',    0,  65, 18);
INSERT INTO ASSET_MODEL VALUES (3, 2, 3, 'ProLiant DL380 Gen10', 'DL380',   2, 800, 74);
INSERT INTO ASSET_MODEL VALUES (4, 4, 4, 'Catalyst 2960X',       'C2960X',  1,  60, 44);

COMMIT;


-- ============================================================
-- 9. DONNÉES LOCALES CERGY
-- ============================================================

INSERT INTO BUILDING VALUES (SEQ_BUILDING.NEXTVAL, 1, 'A', 'Bâtiment A - Informatique', '2 Av. Adolphe Chauvin, Cergy');
INSERT INTO BUILDING VALUES (SEQ_BUILDING.NEXTVAL, 1, 'B', 'Bâtiment B - Sciences',     '2 Av. Adolphe Chauvin, Cergy');

INSERT INTO ROOM VALUES (SEQ_ROOM.NEXTVAL, 1, 'A101', 'Salle TP Réseau',   1, 'LAB');
INSERT INTO ROOM VALUES (SEQ_ROOM.NEXTVAL, 1, 'A102', 'Salle Serveurs',    1, 'DATACENTER');
INSERT INTO ROOM VALUES (SEQ_ROOM.NEXTVAL, 2, 'B201', 'Salle TP Générale', 2, 'LAB');

INSERT INTO APP_USER VALUES (SEQ_USER.NEXTVAL, 1, 'admin.cergy',  'Admin',  'Cergy', 'admin.cergy@cytech.fr',  'ACTIVE', SYSDATE);
INSERT INTO APP_USER VALUES (SEQ_USER.NEXTVAL, 1, 'it.cergy',     'IT',     'Cergy', 'it.cergy@cytech.fr',     'ACTIVE', SYSDATE);
INSERT INTO APP_USER VALUES (SEQ_USER.NEXTVAL, 1, 'dupont.marie', 'Dupont', 'Marie', 'm.dupont@cytech.fr',     'ACTIVE', SYSDATE);
INSERT INTO APP_USER VALUES (SEQ_USER.NEXTVAL, 1, 'martin.paul',  'Martin', 'Paul',  'p.martin@cytech.fr',     'ACTIVE', SYSDATE);

-- user_id 1=admin.cergy, 2=it.cergy, 3=dupont.marie, 4=martin.paul
INSERT INTO USER_ROLE VALUES (SEQ_USERROLE.NEXTVAL, 1, 1, 1, SYSDATE, NULL); -- admin.cergy → ADMIN_GLOBAL
INSERT INTO USER_ROLE VALUES (SEQ_USERROLE.NEXTVAL, 2, 2, 1, SYSDATE, NULL); -- it.cergy    → IT_SITE
INSERT INTO USER_ROLE VALUES (SEQ_USERROLE.NEXTVAL, 3, 3, 1, SYSDATE, NULL); -- dupont.marie→ USER_SITE
INSERT INTO USER_ROLE VALUES (SEQ_USERROLE.NEXTVAL, 4, 3, 1, SYSDATE, NULL); -- martin.paul → USER_SITE

-- asset_id 1,2 = PC salle A101 ; asset_id 3 = serveur salle A102
INSERT INTO ASSET VALUES (SEQ_ASSET.NEXTVAL, 1, 1, 1, 1, 1, 3, 2, 'CY-CGY-0001',    'SN-CRG-001', NULL, DATE '2023-09-01', DATE '2026-09-01', 'N', 'N', SYSDATE, SYSDATE);
INSERT INTO ASSET VALUES (SEQ_ASSET.NEXTVAL, 1, 1, 1, 1, 1, 4, 2, 'CY-CGY-0002',    'SN-CRG-002', NULL, DATE '2023-09-01', DATE '2026-09-01', 'N', 'N', SYSDATE, SYSDATE);
INSERT INTO ASSET VALUES (SEQ_ASSET.NEXTVAL, 1, 2, 3, 3, 1, 2, 2, 'CY-CGY-SRV-001', 'SN-SRV-001', NULL, DATE '2022-01-15', DATE '2027-01-15', 'N', 'N', SYSDATE, SYSDATE);

INSERT INTO VLAN VALUES (SEQ_VLAN.NEXTVAL, 1, 10,  'VLAN-ADMIN-CGY');
INSERT INTO VLAN VALUES (SEQ_VLAN.NEXTVAL, 1, 20,  'VLAN-USERS-CGY');
INSERT INTO VLAN VALUES (SEQ_VLAN.NEXTVAL, 1, 100, 'VLAN-SERVERS-CGY');

-- segment_id 1=admin, 2=users, 3=servers (correspond aux vlan_id 1,2,3)
INSERT INTO NETWORK_SEGMENT VALUES (SEQ_SEGMENT.NEXTVAL, 1, 1, '10.1.10.0/24',  '10.1.10.1',  'cytech.cergy.local', 'Administration');
INSERT INTO NETWORK_SEGMENT VALUES (SEQ_SEGMENT.NEXTVAL, 1, 2, '10.1.20.0/24',  '10.1.20.1',  'cytech.cergy.local', 'Utilisateurs');
INSERT INTO NETWORK_SEGMENT VALUES (SEQ_SEGMENT.NEXTVAL, 1, 3, '10.1.100.0/24', '10.1.100.1', 'cytech.cergy.local', 'Serveurs');

COMMIT;


-- ============================================================
-- 10. DATABASE LINK vers PAU
--     Remplacer 'XEPDB1' par le nom réel de votre service Oracle
-- ============================================================

CREATE DATABASE LINK LNK_PAU
  CONNECT TO CYTECH_PAU IDENTIFIED BY pau2026
  USING '//localhost:1521/FREEPDB1';

-- ============================================================
-- 11. VUES GLOBALES FÉDÉRÉES
-- ============================================================

-- Les deux branches utilisent la table SITE locale (répliquée = identique sur les deux sites).
-- Cela évite un JOIN distant supplémentaire pour récupérer le nom du site.
CREATE OR REPLACE VIEW V_GLOBAL_ASSET AS
  SELECT a.asset_id, a.asset_tag, a.serial_number,
         a.site_id,  s.site_name,
         t.type_label   AS asset_type,
         st.state_label AS asset_state,
         a.purchase_date, a.warranty_end,
         a.is_deleted
  FROM   ASSET a
  JOIN   SITE       s  ON s.site_id       = a.site_id
  JOIN   ASSET_TYPE t  ON t.asset_type_id = a.asset_type_id
  JOIN   ASSET_STATE st ON st.state_id    = a.state_id
  WHERE  a.is_deleted = 'N'
  UNION ALL
  SELECT a.asset_id, a.asset_tag, a.serial_number,
         a.site_id,  s.site_name,
         t.type_label,
         st.state_label,
         a.purchase_date, a.warranty_end,
         a.is_deleted
  FROM   ASSET@LNK_PAU      a
  JOIN   SITE                s  ON s.site_id       = a.site_id   -- SITE local, répliqué
  JOIN   ASSET_TYPE@LNK_PAU  t  ON t.asset_type_id = a.asset_type_id
  JOIN   ASSET_STATE@LNK_PAU st ON st.state_id     = a.state_id
  WHERE  a.is_deleted = 'N';

CREATE OR REPLACE VIEW V_GLOBAL_NETWORK AS
  SELECT n.port_id, n.mac_address, n.port_status, n.port_kind,
         a.asset_tag, a.site_id, 'CERGY' AS site_code,
         i.ip_value,  i.dns_name
  FROM   NETWORK_PORT n
  JOIN   ASSET        a ON a.asset_id = n.asset_id
  LEFT JOIN IP_ADDRESS i ON i.port_id = n.port_id
  UNION ALL
  SELECT n.port_id, n.mac_address, n.port_status, n.port_kind,
         a.asset_tag, a.site_id, 'PAU' AS site_code,
         i.ip_value,  i.dns_name
  FROM   NETWORK_PORT@LNK_PAU n
  JOIN   ASSET@LNK_PAU        a ON a.asset_id = n.asset_id
  LEFT JOIN IP_ADDRESS@LNK_PAU i ON i.port_id = n.port_id;

CREATE OR REPLACE VIEW V_GLOBAL_ASSIGNMENT AS
  SELECT h.assignment_id, h.asset_id, h.assigned_at, h.returned_at,
         u.login, u.last_name, u.first_name,
         'CERGY' AS site_code
  FROM   ASSET_ASSIGNMENT_HISTORY h
  JOIN   APP_USER u ON u.user_id = h.user_id
  UNION ALL
  SELECT h.assignment_id, h.asset_id, h.assigned_at, h.returned_at,
         u.login, u.last_name, u.first_name,
         'PAU' AS site_code
  FROM   ASSET_ASSIGNMENT_HISTORY@LNK_PAU h
  JOIN   APP_USER@LNK_PAU                 u ON u.user_id = h.user_id;

COMMIT;

-- ============================================================
-- FIN DU SCRIPT CERGY
-- ============================================================
