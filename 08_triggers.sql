-- ============================================================
-- 08_triggers.sql
-- triggers : validation des refs vers MVs (FK impossibles),
-- règles métier, audit sur DEVICE.
-- à exécuter après 06 (utilise proc_log_error).
-- ============================================================


-- ============================================================
-- Cergy
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1


-- table d'audit pour DEVICE : trace les modifs métier (statut, salle, personne)
CREATE TABLE DEVICE_HISTORY (
  history_id     NUMBER       CONSTRAINT pk_device_history PRIMARY KEY,
  device_id      NUMBER       NOT NULL,
  action         VARCHAR2(10) NOT NULL,
  old_status     VARCHAR2(20),
  new_status     VARCHAR2(20),
  old_person_id  NUMBER,
  new_person_id  NUMBER,
  old_room_id    NUMBER,
  new_room_id    NUMBER,
  changed_at     TIMESTAMP    DEFAULT SYSTIMESTAMP,
  changed_by     VARCHAR2(50) DEFAULT USER,
  CONSTRAINT ck_dev_hist_action CHECK (action IN ('INSERT','UPDATE','DELETE'))
) TABLESPACE DATA_CERGY;

CREATE SEQUENCE seq_device_history START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE INDEX idx_dev_hist_device ON DEVICE_HISTORY(device_id) TABLESPACE IDX_CERGY;

GRANT SELECT ON DEVICE_HISTORY TO R_CERGY_READ;


-- ------------------------------------------------------------
-- 1. vérif que role_id existe dans MV_PERSON_ROLE
-- (oracle interdit FK vers une MV, donc on compense par trigger)
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_check_role_cergy
BEFORE INSERT OR UPDATE OF role_id ON PERSON
FOR EACH ROW
DECLARE
  v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM MV_PERSON_ROLE WHERE role_id = :NEW.role_id;
  IF v_n = 0 THEN
    raise_application_error(-20110, 'role_id ' || :NEW.role_id || ' inconnu');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_check_role_cergy', 'role_id=' || :NEW.role_id);
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 2. device RETIRED ne doit plus avoir personne assignée
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_device_retired_guard
BEFORE UPDATE OF device_status ON DEVICE
FOR EACH ROW
WHEN (NEW.device_status = 'RETIRED' AND NEW.assigned_person_id IS NOT NULL)
BEGIN
  raise_application_error(-20102,
    'device ' || :NEW.device_id || ' encore assigné, libérer avant de retirer');
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_device_retired_guard', 'device_id=' || :NEW.device_id);
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 3. pas d'assignation à une personne INACTIVE
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_assign_active
BEFORE INSERT OR UPDATE OF assigned_person_id ON DEVICE
FOR EACH ROW
WHEN (NEW.assigned_person_id IS NOT NULL)
DECLARE
  v_st VARCHAR2(20);
BEGIN
  SELECT person_status INTO v_st FROM PERSON WHERE person_id = :NEW.assigned_person_id;
  IF v_st <> 'ACTIVE' THEN
    raise_application_error(-20103,
      'personne ' || :NEW.assigned_person_id || ' INACTIVE');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    proc_log_error('trg_assign_active', 'person_id=' || :NEW.assigned_person_id || ' inexistante');
    raise_application_error(-20103, 'personne ' || :NEW.assigned_person_id || ' inexistante');
  WHEN OTHERS THEN
    proc_log_error('trg_assign_active', 'person_id=' || :NEW.assigned_person_id);
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 4. ticket : auto-set closed_at quand on passe en CLOSED,
--    et refuser toute modif d'un ticket déjà fermé.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ticket_close_auto
BEFORE UPDATE ON MAINTENANCE_TICKET
FOR EACH ROW
BEGIN
  IF :OLD.ticket_status = 'CLOSED' THEN
    raise_application_error(-20105, 'ticket ' || :OLD.ticket_id || ' déjà CLOSED');
  END IF;

  IF :NEW.ticket_status = 'CLOSED' AND :NEW.closed_at IS NULL THEN
    :NEW.closed_at := SYSDATE;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_ticket_close_auto', 'ticket=' || :OLD.ticket_id);
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 5. quand on clôture une affectation, on libère le device
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_assign_return_sync
AFTER UPDATE OF returned_at ON DEVICE_ASSIGNMENT
FOR EACH ROW
WHEN (NEW.returned_at IS NOT NULL AND OLD.returned_at IS NULL)
BEGIN
  UPDATE DEVICE
     SET assigned_person_id = NULL
   WHERE device_id = :NEW.device_id
     AND assigned_person_id = :NEW.person_id;
END;
/


-- ------------------------------------------------------------
-- 6. bloque la désactivation si la personne a encore des devices.
--    choix : pas de cascade silencieuse, l'admin libère d'abord.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_person_deactivate
BEFORE UPDATE OF person_status ON PERSON
FOR EACH ROW
WHEN (OLD.person_status = 'ACTIVE' AND NEW.person_status = 'INACTIVE')
DECLARE
  v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM DEVICE WHERE assigned_person_id = :OLD.person_id;
  IF v_n > 0 THEN
    raise_application_error(-20121,
      'personne ' || :OLD.person_id || ' a encore ' || v_n || ' device(s) assigné(s)');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_person_deactivate',
                   'person_id=' || :OLD.person_id || ' devices=' || v_n);
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 7. audit DEVICE : trace les modifs dans DEVICE_HISTORY
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_audit_device
AFTER INSERT OR UPDATE OR DELETE ON DEVICE
FOR EACH ROW
DECLARE
  v_act VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_act := 'INSERT';
  ELSIF UPDATING THEN
    v_act := 'UPDATE';
  ELSE
    v_act := 'DELETE';
  END IF;

  INSERT INTO DEVICE_HISTORY(history_id, device_id, action,
                             old_status,    new_status,
                             old_person_id, new_person_id,
                             old_room_id,   new_room_id)
  VALUES (seq_device_history.NEXTVAL,
          NVL(:NEW.device_id, :OLD.device_id),
          v_act,
          :OLD.device_status,    :NEW.device_status,
          :OLD.assigned_person_id, :NEW.assigned_person_id,
          :OLD.room_id,          :NEW.room_id);
END;
/


-- ============================================================
-- Pau
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1


CREATE TABLE DEVICE_HISTORY (
  history_id     NUMBER       CONSTRAINT pk_device_history_pau PRIMARY KEY,
  device_id      NUMBER       NOT NULL,
  action         VARCHAR2(10) NOT NULL,
  old_status     VARCHAR2(20),
  new_status     VARCHAR2(20),
  old_person_id  NUMBER,
  new_person_id  NUMBER,
  old_room_id    NUMBER,
  new_room_id    NUMBER,
  changed_at     TIMESTAMP    DEFAULT SYSTIMESTAMP,
  changed_by     VARCHAR2(50) DEFAULT USER,
  CONSTRAINT ck_dev_hist_action_pau CHECK (action IN ('INSERT','UPDATE','DELETE'))
) TABLESPACE DATA_PAU;

CREATE SEQUENCE seq_device_history START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE INDEX idx_dev_hist_device ON DEVICE_HISTORY(device_id) TABLESPACE IDX_PAU;

GRANT SELECT ON DEVICE_HISTORY TO R_PAU_READ;


-- vérif refs vers MVs (device_type, os_version, peripheral_type)
CREATE OR REPLACE TRIGGER trg_check_devtype_pau
BEFORE INSERT OR UPDATE OF device_type_id ON DEVICE
FOR EACH ROW
DECLARE v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM MV_DEVICE_TYPE WHERE device_type_id = :NEW.device_type_id;
  IF v_n = 0 THEN
    raise_application_error(-20111, 'device_type_id ' || :NEW.device_type_id || ' inconnu');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_check_devtype_pau', 'type=' || :NEW.device_type_id);
    RAISE;
END;
/

CREATE OR REPLACE TRIGGER trg_check_os_pau
BEFORE INSERT OR UPDATE OF os_version_id ON DEVICE
FOR EACH ROW
WHEN (NEW.os_version_id IS NOT NULL)
DECLARE v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM MV_OS_VERSION WHERE os_version_id = :NEW.os_version_id;
  IF v_n = 0 THEN
    raise_application_error(-20112, 'os_version_id ' || :NEW.os_version_id || ' inconnu');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_check_os_pau', 'os=' || :NEW.os_version_id);
    RAISE;
END;
/

CREATE OR REPLACE TRIGGER trg_check_periph_pau
BEFORE INSERT OR UPDATE OF peripheral_type_id ON PERIPHERAL
FOR EACH ROW
DECLARE v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM MV_PERIPHERAL_TYPE WHERE peripheral_type_id = :NEW.peripheral_type_id;
  IF v_n = 0 THEN
    raise_application_error(-20113, 'peripheral_type_id ' || :NEW.peripheral_type_id || ' inconnu');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_check_periph_pau', 'type=' || :NEW.peripheral_type_id);
    RAISE;
END;
/


-- mêmes règles métier que Cergy
CREATE OR REPLACE TRIGGER trg_device_retired_guard_pau
BEFORE UPDATE OF device_status ON DEVICE
FOR EACH ROW
WHEN (NEW.device_status = 'RETIRED' AND NEW.assigned_person_id IS NOT NULL)
BEGIN
  raise_application_error(-20102, 'device ' || :NEW.device_id || ' encore assigné, libérer avant de retirer');
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_device_retired_guard_pau', 'device_id=' || :NEW.device_id);
    RAISE;
END;
/

CREATE OR REPLACE TRIGGER trg_assign_active_pau
BEFORE INSERT OR UPDATE OF assigned_person_id ON DEVICE
FOR EACH ROW
WHEN (NEW.assigned_person_id IS NOT NULL)
DECLARE v_st VARCHAR2(20);
BEGIN
  SELECT person_status INTO v_st FROM PERSON WHERE person_id = :NEW.assigned_person_id;
  IF v_st <> 'ACTIVE' THEN
    raise_application_error(-20103, 'personne ' || :NEW.assigned_person_id || ' INACTIVE');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    proc_log_error('trg_assign_active_pau', 'person_id=' || :NEW.assigned_person_id || ' inexistante');
    raise_application_error(-20103, 'personne ' || :NEW.assigned_person_id || ' inexistante');
  WHEN OTHERS THEN
    proc_log_error('trg_assign_active_pau', 'person_id=' || :NEW.assigned_person_id);
    RAISE;
END;
/

CREATE OR REPLACE TRIGGER trg_assign_return_sync_pau
AFTER UPDATE OF returned_at ON DEVICE_ASSIGNMENT
FOR EACH ROW
WHEN (NEW.returned_at IS NOT NULL AND OLD.returned_at IS NULL)
BEGIN
  UPDATE DEVICE
     SET assigned_person_id = NULL
   WHERE device_id = :NEW.device_id
     AND assigned_person_id = :NEW.person_id;
END;
/

CREATE OR REPLACE TRIGGER trg_person_deactivate_pau
BEFORE UPDATE OF person_status ON PERSON
FOR EACH ROW
WHEN (OLD.person_status = 'ACTIVE' AND NEW.person_status = 'INACTIVE')
DECLARE v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM DEVICE WHERE assigned_person_id = :OLD.person_id;
  IF v_n > 0 THEN
    raise_application_error(-20121,
      'personne ' || :OLD.person_id || ' a encore ' || v_n || ' device(s)');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    proc_log_error('trg_person_deactivate_pau',
                   'person_id=' || :OLD.person_id || ' devices=' || v_n);
    RAISE;
END;
/

CREATE OR REPLACE TRIGGER trg_audit_device_pau
AFTER INSERT OR UPDATE OR DELETE ON DEVICE
FOR EACH ROW
DECLARE v_act VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_act := 'INSERT';
  ELSIF UPDATING THEN
    v_act := 'UPDATE';
  ELSE
    v_act := 'DELETE';
  END IF;

  INSERT INTO DEVICE_HISTORY(history_id, device_id, action,
                             old_status,    new_status,
                             old_person_id, new_person_id,
                             old_room_id,   new_room_id)
  VALUES (seq_device_history.NEXTVAL,
          NVL(:NEW.device_id, :OLD.device_id),
          v_act,
          :OLD.device_status,    :NEW.device_status,
          :OLD.assigned_person_id, :NEW.assigned_person_id,
          :OLD.room_id,          :NEW.room_id);
END;
/

COMMIT;


-- ============================================================
-- tests rapides (à exécuter à la main)
-- ============================================================
-- role_id inconnu -> ORA-20110 :
--   INSERT INTO PERSON VALUES (999, 1, 99, 'test', 'X', 'Y', 't@x.fr', 'ACTIVE');
--
-- retirer un device assigné -> ORA-20102 :
--   UPDATE DEVICE SET device_status='RETIRED'
--    WHERE device_id = 1 AND assigned_person_id IS NOT NULL;
--
-- auto-clôture ticket :
--   UPDATE MAINTENANCE_TICKET SET ticket_status='CLOSED' WHERE ticket_id = 1;
--   SELECT ticket_id, ticket_status, closed_at FROM MAINTENANCE_TICKET
--    WHERE ticket_id = 1;   -- closed_at doit être SYSDATE
--
-- voir l'audit :
--   UPDATE DEVICE SET device_status='IN_REPAIR' WHERE device_id = 1;
--   SELECT * FROM DEVICE_HISTORY ORDER BY changed_at DESC;
