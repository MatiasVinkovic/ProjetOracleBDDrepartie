-- ============================================================
-- 07_audit_trigger.sql
-- Projet GLPI BDDR - Trigger d'audit sur DEVICE (bonus)
-- Trace tous les INSERT/UPDATE/DELETE sur DEVICE
-- Deploye sur les 2 sites (Cergy et Pau)
-- ============================================================


-- ============================================================
-- 1. AUDIT SUR CYTECH_CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/XEPDB1

-- Table de trace
CREATE TABLE DEVICE_AUDIT (
  audit_id          NUMBER          CONSTRAINT PK_DEVICE_AUDIT PRIMARY KEY,
  operation         VARCHAR2(10)    NOT NULL,
  device_id         NUMBER          NOT NULL,
  old_asset_tag     VARCHAR2(40),
  new_asset_tag     VARCHAR2(40),
  old_device_status VARCHAR2(20),
  new_device_status VARCHAR2(20),
  old_person_id     NUMBER,
  new_person_id     NUMBER,
  changed_by        VARCHAR2(50)    NOT NULL,
  changed_at        TIMESTAMP       NOT NULL
) TABLESPACE DATA_CERGY;

-- Sequence pour la PK
CREATE SEQUENCE DEVICE_AUDIT_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

-- Trigger d'audit
CREATE OR REPLACE TRIGGER TRG_AUDIT_DEVICE
AFTER INSERT OR UPDATE OR DELETE ON DEVICE
FOR EACH ROW
DECLARE
  v_op VARCHAR2(10);
BEGIN
  IF    INSERTING THEN v_op := 'INSERT';
  ELSIF UPDATING  THEN v_op := 'UPDATE';
  ELSE                 v_op := 'DELETE';
  END IF;

  INSERT INTO DEVICE_AUDIT (
    audit_id, operation, device_id,
    old_asset_tag,     new_asset_tag,
    old_device_status, new_device_status,
    old_person_id,     new_person_id,
    changed_by,        changed_at
  ) VALUES (
    DEVICE_AUDIT_SEQ.NEXTVAL,
    v_op,
    COALESCE(:NEW.device_id, :OLD.device_id),
    :OLD.asset_tag,          :NEW.asset_tag,
    :OLD.device_status,      :NEW.device_status,
    :OLD.assigned_person_id, :NEW.assigned_person_id,
    SYS_CONTEXT('USERENV', 'SESSION_USER'),
    SYSTIMESTAMP
  );
END;
/


-- ============================================================
-- 2. AUDIT SUR CYTECH_PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/XEPDB1

CREATE TABLE DEVICE_AUDIT (
  audit_id          NUMBER          CONSTRAINT PK_DEVICE_AUDIT PRIMARY KEY,
  operation         VARCHAR2(10)    NOT NULL,
  device_id         NUMBER          NOT NULL,
  old_asset_tag     VARCHAR2(40),
  new_asset_tag     VARCHAR2(40),
  old_device_status VARCHAR2(20),
  new_device_status VARCHAR2(20),
  old_person_id     NUMBER,
  new_person_id     NUMBER,
  changed_by        VARCHAR2(50)    NOT NULL,
  changed_at        TIMESTAMP       NOT NULL
) TABLESPACE DATA_PAU;

CREATE SEQUENCE DEVICE_AUDIT_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER TRG_AUDIT_DEVICE
AFTER INSERT OR UPDATE OR DELETE ON DEVICE
FOR EACH ROW
BEGIN
  INSERT INTO DEVICE_AUDIT (
    audit_id, operation, device_id,
    old_asset_tag,     new_asset_tag,
    old_device_status, new_device_status,
    old_person_id,     new_person_id,
    changed_by,        changed_at
  ) VALUES (
    DEVICE_AUDIT_SEQ.NEXTVAL,
    CASE WHEN INSERTING THEN 'INSERT'
         WHEN UPDATING  THEN 'UPDATE'
         ELSE                'DELETE' END,
    COALESCE(:NEW.device_id, :OLD.device_id),
    :OLD.asset_tag,        :NEW.asset_tag,
    :OLD.device_status,    :NEW.device_status,
    :OLD.assigned_person_id, :NEW.assigned_person_id,
    SYS_CONTEXT('USERENV', 'SESSION_USER'),
    SYSTIMESTAMP
  );
END;
/


-- ============================================================
-- 3. VERIFICATION
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/XEPDB1

-- Test : modifier un device et verifier la trace
UPDATE DEVICE SET device_status = 'IN_REPAIR' WHERE device_id = 1;
COMMIT;

SELECT audit_id, operation, device_id,
       old_device_status, new_device_status,
       changed_by, changed_at
FROM DEVICE_AUDIT
ORDER BY changed_at DESC
FETCH FIRST 5 ROWS ONLY;

-- Remettre en etat
UPDATE DEVICE SET device_status = 'IN_SERVICE' WHERE device_id = 1;
COMMIT;
