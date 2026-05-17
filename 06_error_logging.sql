-- ============================================================
-- 06_error_logging.sql
-- petite table de log pour les erreurs métier + helper PL/SQL.
-- inspiré du pattern ligne_erreur du TP7.
-- à exécuter après 04_role_gestion.sql.
-- ============================================================


-- ============================================================
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
CREATE OR REPLACE PROCEDURE proc_log_error(
  p_module   IN VARCHAR2,
  p_context  IN VARCHAR2 DEFAULT NULL
) AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM, 1, 500), p_module, p_context);
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
BEGIN
  INSERT INTO ERROR_LOG(error_id, err_code, err_msg, module_name, context_info)
  VALUES (seq_error_log.NEXTVAL, SQLCODE, SUBSTR(SQLERRM, 1, 500), p_module, p_context);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
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
-- BEGIN
--   RAISE NO_DATA_FOUND;
-- EXCEPTION
--   WHEN OTHERS THEN
--     proc_log_error('test_log', 'depuis bloc anonyme');
-- END;
-- /
-- SELECT * FROM ERROR_LOG ORDER BY error_ts DESC;
