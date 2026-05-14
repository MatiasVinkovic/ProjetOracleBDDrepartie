-- ============================================================
-- 06_error_logging.sql
-- Projet GLPI BDDR - Gestion d'erreurs centralisée
--
-- A executer APRES 01_setup_cergy.sql, 02_setup_pau.sql et 03_replication.sql.
--
-- Contenu (sur chaque site) :
--   1. Table ERROR_LOG + sequence + 3 index
--   2. Package PKG_EXCEPTIONS : exceptions metier nommees
--   3. Procedure PROC_LOG_ERROR avec PRAGMA AUTONOMOUS_TRANSACTION
--      => l'INSERT de log survit au ROLLBACK de la transaction metier
--   4. Cote Cergy uniquement :
--      - vue V_ERROR_LOG_PAU : SELECT sur ERROR_LOG@LNK_PAU (non materialisee,
--        pour consulter les erreurs Pau en temps reel)
--      - vue V_ERROR_LOG_ALL : UNION ALL Cergy + Pau pour requete unifiee
--
-- Justification choix techniques :
--   - Une table par site (pas de centralisation forcee) : pas de dependance
--     reseau au moment du log. Si LNK_PAU tombe, Pau continue de logger
--     localement.
--   - Vue non materialisee : ERROR_LOG n'a pas vocation a etre joint avec
--     une frequence forte, et on veut voir les erreurs Pau en direct sans
--     attendre un refresh.
--   - PRAGMA AUTONOMOUS_TRANSACTION : sans elle, le ROLLBACK de la
--     procedure appelante annule aussi l'INSERT du log. Avec, le log est
--     persiste meme si la transaction metier echoue.
--   - WHEN OTHERS THEN NULL dans PROC_LOG_ERROR : la journalisation ne
--     doit JAMAIS faire echouer la procedure appelante. Si le log echoue
--     (tablespace plein, etc.), on laisse passer.
-- ============================================================


-- ============================================================
-- PARTIE 1 : SITE CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON

-- ---- 1.1 Table ERROR_LOG + sequence ----
CREATE TABLE ERROR_LOG (
  error_id       NUMBER         CONSTRAINT PK_ERROR_LOG PRIMARY KEY,
  error_ts       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  site_id        NUMBER         DEFAULT 1 NOT NULL,
  sql_code       NUMBER,
  sql_errm       VARCHAR2(2000),
  app_code       VARCHAR2(30),                 -- nom symbolique : 'EX_DEVICE_WRONG_SITE'
  module_name    VARCHAR2(80),                 -- procedure/trigger fautif
  user_name      VARCHAR2(50)   DEFAULT USER NOT NULL,
  session_id     NUMBER,                       -- SYS_CONTEXT('USERENV','SESSIONID')
  context_info   VARCHAR2(500),                -- parametres : 'device_id=42, site=2'
  call_stack     VARCHAR2(2000),               -- DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
  CONSTRAINT CK_ERROR_LOG_SITE CHECK (site_id = 1)
) TABLESPACE DATA_CERGY;

CREATE SEQUENCE SEQ_ERROR_LOG START WITH 1 INCREMENT BY 1 NOCACHE;

-- ---- 1.2 Index ----
-- Justification :
--   IDX_ERROR_TS    : consultation chronologique (la requete naturelle).
--   IDX_ERROR_MODULE: "quelle procedure plante le plus" (group by module_name).
--   IDX_ERROR_APP_CODE : filtrage par type d'erreur (EX_DEVICE_*, EX_PERSON_*).
CREATE INDEX IDX_ERROR_TS       ON ERROR_LOG(error_ts)    TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ERROR_MODULE   ON ERROR_LOG(module_name) TABLESPACE IDX_CERGY;
CREATE INDEX IDX_ERROR_APP_CODE ON ERROR_LOG(app_code)    TABLESPACE IDX_CERGY;

-- ---- 1.3 Package des exceptions metier ----
CREATE OR REPLACE PACKAGE PKG_EXCEPTIONS AS
  -- Devices
  EX_DEVICE_NOT_FOUND       EXCEPTION;
  EX_DEVICE_WRONG_SITE      EXCEPTION;
  EX_DEVICE_RETIRED         EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_DEVICE_NOT_FOUND,  -20100);
  PRAGMA EXCEPTION_INIT(EX_DEVICE_WRONG_SITE, -20101);
  PRAGMA EXCEPTION_INIT(EX_DEVICE_RETIRED,    -20102);

  -- Personnes
  EX_PERSON_INACTIVE        EXCEPTION;
  EX_PERSON_WRONG_SITE      EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_PERSON_INACTIVE,   -20103);
  PRAGMA EXCEPTION_INIT(EX_PERSON_WRONG_SITE, -20104);

  -- Tickets
  EX_TICKET_ALREADY_CLOSED  EXCEPTION;
  EX_TICKET_NO_TECHNICIAN   EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_TICKET_ALREADY_CLOSED, -20105);
  PRAGMA EXCEPTION_INIT(EX_TICKET_NO_TECHNICIAN,  -20106);

  -- Integrite referentielle vers MVs (FK impossibles)
  EX_INVALID_ROLE_REF       EXCEPTION;
  EX_INVALID_TYPE_REF       EXCEPTION;
  EX_INVALID_OS_REF         EXCEPTION;
  EX_INVALID_PERIPH_TYPE    EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_INVALID_ROLE_REF,    -20110);
  PRAGMA EXCEPTION_INIT(EX_INVALID_TYPE_REF,    -20111);
  PRAGMA EXCEPTION_INIT(EX_INVALID_OS_REF,      -20112);
  PRAGMA EXCEPTION_INIT(EX_INVALID_PERIPH_TYPE, -20113);

  -- Coherence metier
  EX_PERIPH_DEVICE_MISMATCH EXCEPTION;
  EX_ASSIGNMENT_CONFLICT    EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_PERIPH_DEVICE_MISMATCH, -20120);
  PRAGMA EXCEPTION_INIT(EX_ASSIGNMENT_CONFLICT,    -20121);
END PKG_EXCEPTIONS;
/

-- ---- 1.4 Procedure de journalisation autonome ----
-- Appelable dans tout WHEN OTHERS pour persister le contexte de l'erreur
-- avant de RAISE. Grace a PRAGMA AUTONOMOUS_TRANSACTION, l'INSERT survit
-- au ROLLBACK de la transaction principale.
CREATE OR REPLACE PROCEDURE PROC_LOG_ERROR (
  p_app_code     IN VARCHAR2,
  p_module_name  IN VARCHAR2,
  p_context_info IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_sqlcode NUMBER         := SQLCODE;
  v_sqlerrm VARCHAR2(2000) := SUBSTR(SQLERRM, 1, 2000);
  v_stack   VARCHAR2(2000) := SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 2000);
BEGIN
  INSERT INTO ERROR_LOG (
    error_id, error_ts, site_id, sql_code, sql_errm, app_code,
    module_name, user_name, session_id, context_info, call_stack
  ) VALUES (
    SEQ_ERROR_LOG.NEXTVAL, SYSTIMESTAMP, 1, v_sqlcode, v_sqlerrm,
    p_app_code, p_module_name, USER,
    SYS_CONTEXT('USERENV','SESSIONID'), p_context_info, v_stack
  );
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    -- Le logging ne doit jamais faire echouer l'appelant.
    ROLLBACK;
    NULL;
END PROC_LOG_ERROR;
/


-- ============================================================
-- PARTIE 2 : SITE PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON

-- ---- 2.1 Table ERROR_LOG + sequence ----
CREATE TABLE ERROR_LOG (
  error_id       NUMBER         CONSTRAINT PK_ERROR_LOG PRIMARY KEY,
  error_ts       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  site_id        NUMBER         DEFAULT 2 NOT NULL,
  sql_code       NUMBER,
  sql_errm       VARCHAR2(2000),
  app_code       VARCHAR2(30),
  module_name    VARCHAR2(80),
  user_name      VARCHAR2(50)   DEFAULT USER NOT NULL,
  session_id     NUMBER,
  context_info   VARCHAR2(500),
  call_stack     VARCHAR2(2000),
  CONSTRAINT CK_ERROR_LOG_SITE CHECK (site_id = 2)
) TABLESPACE DATA_PAU;

CREATE SEQUENCE SEQ_ERROR_LOG START WITH 1 INCREMENT BY 1 NOCACHE;

-- ---- 2.2 Index (memes 3 que cote Cergy) ----
CREATE INDEX IDX_ERROR_TS       ON ERROR_LOG(error_ts)    TABLESPACE IDX_PAU;
CREATE INDEX IDX_ERROR_MODULE   ON ERROR_LOG(module_name) TABLESPACE IDX_PAU;
CREATE INDEX IDX_ERROR_APP_CODE ON ERROR_LOG(app_code)    TABLESPACE IDX_PAU;

-- ---- 2.3 Package des exceptions metier (identique a Cergy) ----
CREATE OR REPLACE PACKAGE PKG_EXCEPTIONS AS
  EX_DEVICE_NOT_FOUND       EXCEPTION;
  EX_DEVICE_WRONG_SITE      EXCEPTION;
  EX_DEVICE_RETIRED         EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_DEVICE_NOT_FOUND,  -20100);
  PRAGMA EXCEPTION_INIT(EX_DEVICE_WRONG_SITE, -20101);
  PRAGMA EXCEPTION_INIT(EX_DEVICE_RETIRED,    -20102);

  EX_PERSON_INACTIVE        EXCEPTION;
  EX_PERSON_WRONG_SITE      EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_PERSON_INACTIVE,   -20103);
  PRAGMA EXCEPTION_INIT(EX_PERSON_WRONG_SITE, -20104);

  EX_TICKET_ALREADY_CLOSED  EXCEPTION;
  EX_TICKET_NO_TECHNICIAN   EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_TICKET_ALREADY_CLOSED, -20105);
  PRAGMA EXCEPTION_INIT(EX_TICKET_NO_TECHNICIAN,  -20106);

  EX_INVALID_ROLE_REF       EXCEPTION;
  EX_INVALID_TYPE_REF       EXCEPTION;
  EX_INVALID_OS_REF         EXCEPTION;
  EX_INVALID_PERIPH_TYPE    EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_INVALID_ROLE_REF,    -20110);
  PRAGMA EXCEPTION_INIT(EX_INVALID_TYPE_REF,    -20111);
  PRAGMA EXCEPTION_INIT(EX_INVALID_OS_REF,      -20112);
  PRAGMA EXCEPTION_INIT(EX_INVALID_PERIPH_TYPE, -20113);

  EX_PERIPH_DEVICE_MISMATCH EXCEPTION;
  EX_ASSIGNMENT_CONFLICT    EXCEPTION;
  PRAGMA EXCEPTION_INIT(EX_PERIPH_DEVICE_MISMATCH, -20120);
  PRAGMA EXCEPTION_INIT(EX_ASSIGNMENT_CONFLICT,    -20121);
END PKG_EXCEPTIONS;
/

-- ---- 2.4 Procedure de journalisation autonome (site_id=2) ----
CREATE OR REPLACE PROCEDURE PROC_LOG_ERROR (
  p_app_code     IN VARCHAR2,
  p_module_name  IN VARCHAR2,
  p_context_info IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_sqlcode NUMBER         := SQLCODE;
  v_sqlerrm VARCHAR2(2000) := SUBSTR(SQLERRM, 1, 2000);
  v_stack   VARCHAR2(2000) := SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 2000);
BEGIN
  INSERT INTO ERROR_LOG (
    error_id, error_ts, site_id, sql_code, sql_errm, app_code,
    module_name, user_name, session_id, context_info, call_stack
  ) VALUES (
    SEQ_ERROR_LOG.NEXTVAL, SYSTIMESTAMP, 2, v_sqlcode, v_sqlerrm,
    p_app_code, p_module_name, USER,
    SYS_CONTEXT('USERENV','SESSIONID'), p_context_info, v_stack
  );
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    NULL;
END PROC_LOG_ERROR;
/


-- ============================================================
-- PARTIE 3 : VUE UNIFIEE COTE CERGY
-- ============================================================
-- Permet a l'admin Cergy de consulter d'un coup les erreurs des 2 sites
-- sans avoir a se connecter sur Pau.
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

-- ---- 3.1 Vue distante (lecture seule, non materialisee) ----
CREATE OR REPLACE VIEW V_ERROR_LOG_PAU AS
SELECT error_id, error_ts, site_id, sql_code, sql_errm, app_code,
       module_name, user_name, session_id, context_info, call_stack
FROM ERROR_LOG@LNK_PAU;

-- ---- 3.2 Vue UNION ALL : tous les logs des deux sites ----
CREATE OR REPLACE VIEW V_ERROR_LOG_ALL AS
SELECT error_id, error_ts, site_id, sql_code, sql_errm, app_code,
       module_name, user_name, session_id, context_info, call_stack
FROM ERROR_LOG
UNION ALL
SELECT error_id, error_ts, site_id, sql_code, sql_errm, app_code,
       module_name, user_name, session_id, context_info, call_stack
FROM ERROR_LOG@LNK_PAU;

-- ---- 3.3 Grants pour les roles existants ----
GRANT SELECT ON ERROR_LOG       TO R_CERGY_READ;
GRANT SELECT ON V_ERROR_LOG_PAU TO R_CERGY_READ;
GRANT SELECT ON V_ERROR_LOG_ALL TO R_CERGY_READ;
-- Personne ne doit pouvoir modifier ces logs a la main (insertion via
-- PROC_LOG_ERROR uniquement, autonome).
-- Le DELETE reste sur le proprietaire CYTECH_CERGY (purge admin).


-- ============================================================
-- PARTIE 4 : GRANTS COTE PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

GRANT SELECT ON ERROR_LOG TO R_PAU_READ;
-- L'execution de PROC_LOG_ERROR sera donnee dans 08_triggers.sql en meme
-- temps que les triggers qui l'appellent (cf. plan).


COMMIT;

-- ============================================================
-- TESTS RAPIDES (a executer manuellement)
-- ============================================================
-- Test 1 : declenchement controle de PROC_LOG_ERROR
--   BEGIN
--     RAISE NO_DATA_FOUND;
--   EXCEPTION
--     WHEN OTHERS THEN
--       PROC_LOG_ERROR('TEST_NDF', 'BLOC_ANONYME', 'context test');
--   END;
--   /
--   SELECT * FROM ERROR_LOG ORDER BY error_ts DESC;
--
-- Test 2 : verifier la survie au ROLLBACK
--   BEGIN
--     INSERT INTO PERSON VALUES (9999, 1, 1, 'tmp', 'X', 'Y', 'tmp@x', 'ACTIVE');
--     PROC_LOG_ERROR('TEST_AUTONOMOUS', 'BLOC_ANONYME', 'doit survivre');
--     ROLLBACK;
--   END;
--   /
--   SELECT * FROM ERROR_LOG WHERE app_code = 'TEST_AUTONOMOUS';
--   -- Doit retourner 1 ligne malgre le ROLLBACK (preuve de l'autonomie).
--
-- Test 3 : vue unifiee
--   SELECT site_id, app_code, COUNT(*) FROM V_ERROR_LOG_ALL
--   GROUP BY site_id, app_code;
