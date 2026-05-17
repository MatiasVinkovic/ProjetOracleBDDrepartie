-- ============================================================
-- 06_error_logging.sql
<<<<<<< HEAD
<<<<<<< HEAD
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
=======
-- petite table de log pour les erreurs métier + helper PL/SQL.
-- inspiré du pattern ligne_erreur du TP7.
-- à exécuter après 04_role_gestion.sql.
>>>>>>> users/FA_archi
=======
-- petite table de log pour les erreurs métier + helper PL/SQL.
-- inspiré du pattern ligne_erreur du TP7.
-- à exécuter après 04_role_gestion.sql.
>>>>>>> bf885b7 (simplification, partie 1)
-- ============================================================


-- ============================================================
<<<<<<< HEAD
<<<<<<< HEAD
-- PARTIE 1 : SITE CERGY
=======
-- côté Cergy
>>>>>>> bf885b7 (simplification, partie 1)
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

CREATE TABLE ERROR_LOG (
  error_id      NUMBER        CONSTRAINT pk_error_log PRIMARY KEY,
  error_ts      TIMESTAMP     DEFAULT SYSTIMESTAMP,
  site_id       NUMBER        DEFAULT 1,
  err_code      NUMBER,                       -- SQLCODE
  err_msg       VARCHAR2(500),                -- SQLERRM tronqué
  module_name   VARCHAR2(80),                 -- ex: trg_check_role_cergy
  context_info  VARCHAR2(300)                 -- ex: 'role_id=999'
) TABLESPACE DATA_CERGY;

CREATE SEQUENCE seq_error_log START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE INDEX idx_error_ts ON ERROR_LOG(error_ts) TABLESPACE IDX_CERGY;


-- helper : pose une ligne dans ERROR_LOG même si la transaction parente
-- fait ROLLBACK. pattern du TP7 (cf. inserer_ligne_erreur).
-- note : SQLCODE et SQLERRM doivent être assignés à des variables avant
-- d'être utilisés dans un INSERT (sinon ORA-00984).
CREATE OR REPLACE PROCEDURE proc_log_error(
  p_module   IN VARCHAR2,
  p_context  IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_code NUMBER;
  v_msg  VARCHAR2(500);
BEGIN
  v_code := SQLCODE;
  v_msg  := SUBSTR(SQLERRM, 1, 500);
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, v_code, v_msg, p_module, p_context);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;   -- le log doit jamais casser l'appelant
END;
/

GRANT SELECT  ON ERROR_LOG       TO R_CERGY_READ;
GRANT EXECUTE ON proc_log_error  TO R_CERGY_MANAGER;


-- ============================================================
-- côté Pau (idem)
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

CREATE TABLE ERROR_LOG (
  error_id      NUMBER        CONSTRAINT pk_error_log PRIMARY KEY,
  error_ts      TIMESTAMP     DEFAULT SYSTIMESTAMP,
  site_id       NUMBER        DEFAULT 2,
  err_code      NUMBER,
  err_msg       VARCHAR2(500),
  module_name   VARCHAR2(80),
  context_info  VARCHAR2(300)
) TABLESPACE DATA_PAU;

CREATE SEQUENCE seq_error_log START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE INDEX idx_error_ts ON ERROR_LOG(error_ts) TABLESPACE IDX_PAU;


CREATE OR REPLACE PROCEDURE proc_log_error(
  p_module   IN VARCHAR2,
  p_context  IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_code NUMBER;
  v_msg  VARCHAR2(500);
BEGIN
<<<<<<< HEAD
<<<<<<< HEAD
  INSERT INTO ERROR_LOG (
    error_id, error_ts, site_id, sql_code, sql_errm, app_code,
    module_name, user_name, session_id, context_info, call_stack
  ) VALUES (
    SEQ_ERROR_LOG.NEXTVAL, SYSTIMESTAMP, 2, v_sqlcode, v_sqlerrm,
    p_app_code, p_module_name, USER,
    SYS_CONTEXT('USERENV','SESSIONID'), p_context_info, v_stack
  );
=======
-- côté Cergy
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

CREATE TABLE ERROR_LOG (
  error_id      NUMBER        CONSTRAINT pk_error_log PRIMARY KEY,
  error_ts      TIMESTAMP     DEFAULT SYSTIMESTAMP,
  site_id       NUMBER        DEFAULT 1,
  err_code      NUMBER,                       -- SQLCODE
  err_msg       VARCHAR2(500),                -- SQLERRM tronqué
  module_name   VARCHAR2(80),                 -- ex: trg_check_role_cergy
  context_info  VARCHAR2(300)                 -- ex: 'role_id=999'
) TABLESPACE DATA_CERGY;

CREATE SEQUENCE seq_error_log START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE INDEX idx_error_ts ON ERROR_LOG(error_ts) TABLESPACE IDX_CERGY;


-- helper : pose une ligne dans ERROR_LOG même si la transaction parente
-- fait ROLLBACK. pattern du TP7 (cf. inserer_ligne_erreur).
-- note : SQLCODE et SQLERRM doivent être assignés à des variables avant
-- d'être utilisés dans un INSERT (sinon ORA-00984).
CREATE OR REPLACE PROCEDURE proc_log_error(
  p_module   IN VARCHAR2,
  p_context  IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_code NUMBER;
  v_msg  VARCHAR2(500);
BEGIN
  v_code := SQLCODE;
  v_msg  := SUBSTR(SQLERRM, 1, 500);
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, v_code, v_msg, p_module, p_context);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;   -- le log doit jamais casser l'appelant
END;
/

GRANT SELECT  ON ERROR_LOG       TO R_CERGY_READ;
GRANT EXECUTE ON proc_log_error  TO R_CERGY_MANAGER;


-- ============================================================
-- côté Pau (idem)
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

CREATE TABLE ERROR_LOG (
  error_id      NUMBER        CONSTRAINT pk_error_log PRIMARY KEY,
  error_ts      TIMESTAMP     DEFAULT SYSTIMESTAMP,
  site_id       NUMBER        DEFAULT 2,
  err_code      NUMBER,
  err_msg       VARCHAR2(500),
  module_name   VARCHAR2(80),
  context_info  VARCHAR2(300)
) TABLESPACE DATA_PAU;

CREATE SEQUENCE seq_error_log START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE INDEX idx_error_ts ON ERROR_LOG(error_ts) TABLESPACE IDX_PAU;


CREATE OR REPLACE PROCEDURE proc_log_error(
  p_module   IN VARCHAR2,
  p_context  IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_code NUMBER;
  v_msg  VARCHAR2(500);
BEGIN
  v_code := SQLCODE;
  v_msg  := SUBSTR(SQLERRM, 1, 500);
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, v_code, v_msg, p_module, p_context);
>>>>>>> users/FA_archi
=======
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM, 1, 500), p_module, p_context);
>>>>>>> bf885b7 (simplification, partie 1)
=======
  v_code := SQLCODE;
  v_msg  := SUBSTR(SQLERRM, 1, 500);
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, v_code, v_msg, p_module, p_context);
>>>>>>> 9d8032a (sql code er eerrm non utilisable sans les assigner à des variables locales)
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
<<<<<<< HEAD
<<<<<<< HEAD
    NULL;
END PROC_LOG_ERROR;
=======
END;
>>>>>>> bf885b7 (simplification, partie 1)
/

GRANT SELECT  ON ERROR_LOG       TO R_PAU_READ;
GRANT EXECUTE ON proc_log_error  TO R_PAU_MANAGER;


-- ============================================================
-- vue UNION ALL côté Cergy : consulter les 2 sites d'un coup
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

CREATE OR REPLACE VIEW V_ERROR_LOG_ALL AS
  SELECT error_id, error_ts, site_id, err_code, err_msg, module_name, context_info
  FROM ERROR_LOG
  UNION ALL
  SELECT error_id, error_ts, site_id, err_code, err_msg, module_name, context_info
  FROM ERROR_LOG@LNK_PAU;

GRANT SELECT ON V_ERROR_LOG_ALL TO R_CERGY_READ;


-- ============================================================
-- test rapide (à exécuter à la main si on veut vérifier)
-- ============================================================
<<<<<<< HEAD
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
=======
END;
/

GRANT SELECT  ON ERROR_LOG       TO R_PAU_READ;
GRANT EXECUTE ON proc_log_error  TO R_PAU_MANAGER;


-- ============================================================
-- vue UNION ALL côté Cergy : consulter les 2 sites d'un coup
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

CREATE OR REPLACE VIEW V_ERROR_LOG_ALL AS
  SELECT error_id, error_ts, site_id, err_code, err_msg, module_name, context_info
  FROM ERROR_LOG
  UNION ALL
  SELECT error_id, error_ts, site_id, err_code, err_msg, module_name, context_info
  FROM ERROR_LOG@LNK_PAU;

GRANT SELECT ON V_ERROR_LOG_ALL TO R_CERGY_READ;


-- ============================================================
-- test rapide (à exécuter à la main si on veut vérifier)
-- ============================================================
=======
>>>>>>> bf885b7 (simplification, partie 1)
-- BEGIN
--   RAISE NO_DATA_FOUND;
-- EXCEPTION
--   WHEN OTHERS THEN
--     proc_log_error('test_log', 'depuis bloc anonyme');
-- END;
-- /
-- SELECT * FROM ERROR_LOG ORDER BY error_ts DESC;
<<<<<<< HEAD
>>>>>>> users/FA_archi
=======
>>>>>>> bf885b7 (simplification, partie 1)
