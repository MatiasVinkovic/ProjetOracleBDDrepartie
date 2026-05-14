-- ============================================================
-- 08_triggers.sql
<<<<<<< HEAD
-- Projet GLPI BDDR - Triggers de validation, controle metier et audit
--
-- A executer APRES :
--   01_setup_cergy.sql, 02_setup_pau.sql, 03_replication.sql (MVs+DBlinks),
--   06_error_logging.sql (PKG_EXCEPTIONS + PROC_LOG_ERROR).
--
-- Trois familles de triggers :
--
--   (1) VALIDATION DES REFERENCES MV
--       Compensent l'impossibilite d'avoir une FK Oracle vers une MV.
--       Sans ces triggers, on peut inserer un role_id / type_id / os_version_id
--       qui n'existe nulle part -> integrite referentielle cassee.
--
--   (2) COHERENCE METIER
--       Regles du domaine GLPI : on ne retire pas un device encore assigne,
--       on ne ferme pas deux fois un ticket, une assignation rendue libere
--       le device, on ne desactive pas une personne qui a encore du materiel,
--       etc.
--
--   (3) AUDIT DEVICE
--       Trace toute modification de DEVICE dans DEVICE_HISTORY pour la
--       tracabilite du parc (attente GLPI). S'aligne sur la philosophie de
--       journalisation de ERROR_LOG.
--
-- Pattern d'erreur uniforme :
--   - Validation : SELECT COUNT dans la MV/table de reference + IF count=0
--     alors PROC_LOG_ERROR puis RAISE_APPLICATION_ERROR(-20xxx, msg).
--   - Le code -20xxx correspond a une exception de PKG_EXCEPTIONS, donc
--     l'appelant peut catcher par nom : WHEN PKG_EXCEPTIONS.EX_INVALID_ROLE_REF.
=======
-- triggers : validation des refs vers MVs (FK impossibles),
-- règles métier, audit sur DEVICE.
-- à exécuter après 06 (utilise proc_log_error).
>>>>>>> users/FA_archi
-- ============================================================


-- ============================================================
<<<<<<< HEAD
-- PARTIE 1 : CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

-- ------------------------------------------------------------
-- 1.0 Table DEVICE_HISTORY + sequence + index
-- ------------------------------------------------------------
-- Audit des modifications de DEVICE. On stocke uniquement les colonnes
-- "metier" (status, assigned_person, room) pour rester compact ; pas la
-- peine de versionner mac_address ou serial_number qui ne changent jamais.
CREATE TABLE DEVICE_HISTORY (
  history_id      NUMBER         CONSTRAINT PK_DEVICE_HISTORY PRIMARY KEY,
  device_id       NUMBER         NOT NULL,
  action          VARCHAR2(10)   NOT NULL,
  old_status      VARCHAR2(20),
  new_status      VARCHAR2(20),
  old_person_id   NUMBER,
  new_person_id   NUMBER,
  old_room_id     NUMBER,
  new_room_id     NUMBER,
  changed_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  changed_by      VARCHAR2(50)   DEFAULT USER NOT NULL,
  CONSTRAINT CK_DEVICE_HISTORY_ACTION CHECK (action IN ('INSERT','UPDATE','DELETE'))
) TABLESPACE DATA_CERGY;

CREATE SEQUENCE SEQ_DEVICE_HISTORY START WITH 1 INCREMENT BY 1 NOCACHE;

-- Index sur (device_id, changed_at DESC) : la requete naturelle est
-- "historique du device X dans l'ordre chronologique inverse".
CREATE INDEX IDX_DEV_HIST_DEVICE ON DEVICE_HISTORY(device_id, changed_at DESC)
  TABLESPACE IDX_CERGY;

GRANT SELECT ON DEVICE_HISTORY     TO R_CERGY_READ;
GRANT SELECT ON SEQ_DEVICE_HISTORY TO R_CERGY_MANAGER;


-- ------------------------------------------------------------
-- 1.1 TRG_VALIDATE_ROLE_CERGY
--     Compense l'absence de FK PERSON.role_id -> PERSON_ROLE
--     (PERSON_ROLE est sur Pau, lue via MV_PERSON_ROLE).
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDATE_ROLE_CERGY
BEFORE INSERT OR UPDATE OF role_id ON PERSON
FOR EACH ROW
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM MV_PERSON_ROLE
  WHERE role_id = :NEW.role_id;

  IF v_count = 0 THEN
    PROC_LOG_ERROR(
      'EX_INVALID_ROLE_REF',
      'TRG_VALIDATE_ROLE_CERGY',
      'person_id=' || :NEW.person_id || ', role_id=' || :NEW.role_id
    );
    RAISE_APPLICATION_ERROR(-20110,
      'role_id ' || :NEW.role_id || ' inexistant dans MV_PERSON_ROLE');
  END IF;
=======
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
>>>>>>> users/FA_archi
END;
/


-- ------------------------------------------------------------
<<<<<<< HEAD
-- 1.2 TRG_DEVICE_RETIRED_GUARD
--     Refuse de marquer un device RETIRED s'il a encore une affectation.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_DEVICE_RETIRED_GUARD
BEFORE UPDATE OF device_status ON DEVICE
FOR EACH ROW
WHEN (NEW.device_status = 'RETIRED')
BEGIN
  IF :NEW.assigned_person_id IS NOT NULL THEN
    PROC_LOG_ERROR(
      'EX_DEVICE_RETIRED',
      'TRG_DEVICE_RETIRED_GUARD',
      'device_id=' || :NEW.device_id || ', person=' || :NEW.assigned_person_id
    );
    RAISE_APPLICATION_ERROR(-20102,
      'Impossible de retirer le device ' || :NEW.device_id ||
      ' : encore assigne a la personne ' || :NEW.assigned_person_id);
  END IF;
=======
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
>>>>>>> users/FA_archi
END;
/


-- ------------------------------------------------------------
<<<<<<< HEAD
-- 1.3 TRG_DEVICE_ASSIGN_ACTIVE
--     Refuse d'assigner un device a une personne INACTIVE.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_DEVICE_ASSIGN_ACTIVE
=======
-- 3. pas d'assignation à une personne INACTIVE
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_assign_active
>>>>>>> users/FA_archi
BEFORE INSERT OR UPDATE OF assigned_person_id ON DEVICE
FOR EACH ROW
WHEN (NEW.assigned_person_id IS NOT NULL)
DECLARE
<<<<<<< HEAD
  v_status VARCHAR2(20);
BEGIN
  SELECT person_status INTO v_status
  FROM PERSON
  WHERE person_id = :NEW.assigned_person_id;

  IF v_status <> 'ACTIVE' THEN
    PROC_LOG_ERROR(
      'EX_PERSON_INACTIVE',
      'TRG_DEVICE_ASSIGN_ACTIVE',
      'device_id=' || :NEW.device_id || ', person=' || :NEW.assigned_person_id
    );
    RAISE_APPLICATION_ERROR(-20103,
      'Personne ' || :NEW.assigned_person_id ||
      ' INACTIVE : assignation interdite');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    PROC_LOG_ERROR(
      'EX_PERSON_INACTIVE',
      'TRG_DEVICE_ASSIGN_ACTIVE',
      'person_id=' || :NEW.assigned_person_id || ' inexistante'
    );
    RAISE_APPLICATION_ERROR(-20103,
      'Personne ' || :NEW.assigned_person_id || ' inexistante');
=======
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
>>>>>>> users/FA_archi
END;
/


-- ------------------------------------------------------------
<<<<<<< HEAD
-- 1.4 TRG_TICKET_CLOSE_AUTO
--     - Auto-renseigne closed_at quand status passe a CLOSED.
--     - Interdit toute modification d'un ticket deja CLOSED.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_TICKET_CLOSE_AUTO
BEFORE UPDATE ON MAINTENANCE_TICKET
FOR EACH ROW
BEGIN
  -- Verrou : un ticket CLOSED ne peut plus etre modifie.
  IF :OLD.ticket_status = 'CLOSED' THEN
    PROC_LOG_ERROR(
      'EX_TICKET_ALREADY_CLOSED',
      'TRG_TICKET_CLOSE_AUTO',
      'ticket_id=' || :OLD.ticket_id
    );
    RAISE_APPLICATION_ERROR(-20105,
      'Ticket ' || :OLD.ticket_id || ' deja CLOSED : modification interdite');
  END IF;

  -- Auto-fermeture : si passage a CLOSED sans closed_at, on date.
  IF :NEW.ticket_status = 'CLOSED' AND :NEW.closed_at IS NULL THEN
    :NEW.closed_at := SYSDATE;
  END IF;
END;
/


-- ------------------------------------------------------------
-- 1.5 TRG_ASSIGN_RETURN_SYNC
--     Quand returned_at est renseigne sur DEVICE_ASSIGNMENT, on libere
--     le device dans DEVICE (assigned_person_id := NULL).
--     Pas de mutating table : trigger sur DEVICE_ASSIGNMENT modifie DEVICE.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ASSIGN_RETURN_SYNC
AFTER UPDATE OF returned_at ON DEVICE_ASSIGNMENT
FOR EACH ROW
WHEN (NEW.returned_at IS NOT NULL AND OLD.returned_at IS NULL)
BEGIN
  UPDATE DEVICE
  SET    assigned_person_id = NULL
  WHERE  device_id = :NEW.device_id
    AND  assigned_person_id = :NEW.person_id;
EXCEPTION
  WHEN OTHERS THEN
    PROC_LOG_ERROR(
      'ASSIGN_SYNC_FAILED',
      'TRG_ASSIGN_RETURN_SYNC',
      'device_id=' || :NEW.device_id || ', person_id=' || :NEW.person_id
    );
=======
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
>>>>>>> users/FA_archi
    RAISE;
END;
/


-- ------------------------------------------------------------
<<<<<<< HEAD
-- 1.6 TRG_PERSON_DEACTIVATE  (Option B : bloque la desactivation)
--     Refuse de passer une PERSON a INACTIVE tant qu'elle a :
--       - des devices assignes (DEVICE.assigned_person_id = :OLD.person_id), ou
--       - des assignations actives (DEVICE_ASSIGNMENT WHERE returned_at IS NULL).
--     L'admin doit d'abord rendre/transferer le materiel.
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_PERSON_DEACTIVATE
BEFORE UPDATE OF person_status ON PERSON
FOR EACH ROW
WHEN (OLD.person_status = 'ACTIVE' AND NEW.person_status = 'INACTIVE')
DECLARE
  v_dev    NUMBER;
  v_assign NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_dev
  FROM DEVICE
  WHERE assigned_person_id = :OLD.person_id;

  IF v_dev > 0 THEN
    PROC_LOG_ERROR(
      'EX_ASSIGNMENT_CONFLICT',
      'TRG_PERSON_DEACTIVATE',
      'person_id=' || :OLD.person_id || ', devices=' || v_dev
    );
    RAISE_APPLICATION_ERROR(-20121,
      'Personne ' || :OLD.person_id || ' : ' || v_dev ||
      ' device(s) encore assigne(s). Liberer avant desactivation.');
  END IF;

  SELECT COUNT(*) INTO v_assign
  FROM DEVICE_ASSIGNMENT
  WHERE person_id = :OLD.person_id AND returned_at IS NULL;

  IF v_assign > 0 THEN
    PROC_LOG_ERROR(
      'EX_ASSIGNMENT_CONFLICT',
      'TRG_PERSON_DEACTIVATE',
      'person_id=' || :OLD.person_id || ', active_assignments=' || v_assign
    );
    RAISE_APPLICATION_ERROR(-20121,
      'Personne ' || :OLD.person_id || ' : ' || v_assign ||
      ' assignation(s) active(s). Clore les assignations avant desactivation.');
  END IF;
=======
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
>>>>>>> users/FA_archi
END;
/


-- ------------------------------------------------------------
<<<<<<< HEAD
-- 1.7 TRG_AUDIT_DEVICE
--     Journalise tout INSERT/UPDATE/DELETE sur DEVICE dans DEVICE_HISTORY.
--     "Best-effort" : si l'audit echoue, on logge dans ERROR_LOG mais on
--     NE bloque PAS le DML metier (philosophie : trace utile, pas bloquante).
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDIT_DEVICE
AFTER INSERT OR UPDATE OR DELETE ON DEVICE
FOR EACH ROW
DECLARE
  v_action VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_action := 'INSERT';
  ELSIF UPDATING THEN
    v_action := 'UPDATE';
  ELSE
    v_action := 'DELETE';
  END IF;

  INSERT INTO DEVICE_HISTORY (
    history_id, device_id, action,
    old_status,     new_status,
    old_person_id,  new_person_id,
    old_room_id,    new_room_id,
    changed_at, changed_by
  ) VALUES (
    SEQ_DEVICE_HISTORY.NEXTVAL,
    NVL(:NEW.device_id, :OLD.device_id),
    v_action,
    CASE WHEN INSERTING THEN NULL ELSE :OLD.device_status      END,
    CASE WHEN DELETING  THEN NULL ELSE :NEW.device_status      END,
    CASE WHEN INSERTING THEN NULL ELSE :OLD.assigned_person_id END,
    CASE WHEN DELETING  THEN NULL ELSE :NEW.assigned_person_id END,
    CASE WHEN INSERTING THEN NULL ELSE :OLD.room_id            END,
    CASE WHEN DELETING  THEN NULL ELSE :NEW.room_id            END,
    SYSTIMESTAMP, USER
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Audit best-effort : on logge l'echec mais on n'interrompt pas le DML.
    PROC_LOG_ERROR(
      'AUDIT_FAILURE',
      'TRG_AUDIT_DEVICE',
      'device_id=' || NVL(:NEW.device_id, :OLD.device_id) ||
      ', action=' || v_action
    );
=======
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
>>>>>>> users/FA_archi
END;
/


-- ============================================================
<<<<<<< HEAD
-- PARTIE 2 : PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

-- ------------------------------------------------------------
-- 2.0 Table DEVICE_HISTORY + sequence + index (identique a Cergy)
-- ------------------------------------------------------------
CREATE TABLE DEVICE_HISTORY (
  history_id      NUMBER         CONSTRAINT PK_DEVICE_HISTORY PRIMARY KEY,
  device_id       NUMBER         NOT NULL,
  action          VARCHAR2(10)   NOT NULL,
  old_status      VARCHAR2(20),
  new_status      VARCHAR2(20),
  old_person_id   NUMBER,
  new_person_id   NUMBER,
  old_room_id     NUMBER,
  new_room_id     NUMBER,
  changed_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  changed_by      VARCHAR2(50)   DEFAULT USER NOT NULL,
  CONSTRAINT CK_DEVICE_HISTORY_ACTION CHECK (action IN ('INSERT','UPDATE','DELETE'))
) TABLESPACE DATA_PAU;

CREATE SEQUENCE SEQ_DEVICE_HISTORY START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE INDEX IDX_DEV_HIST_DEVICE ON DEVICE_HISTORY(device_id, changed_at DESC)
  TABLESPACE IDX_PAU;

GRANT SELECT ON DEVICE_HISTORY     TO R_PAU_READ;
GRANT SELECT ON SEQ_DEVICE_HISTORY TO R_PAU_MANAGER;


-- ------------------------------------------------------------
-- 2.1 TRG_VALIDATE_DEVICE_TYPE_PAU
--     Compense l'absence de FK DEVICE.device_type_id -> DEVICE_TYPE
--     (DEVICE_TYPE est sur Cergy, lue via MV_DEVICE_TYPE).
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDATE_DEVICE_TYPE_PAU
BEFORE INSERT OR UPDATE OF device_type_id ON DEVICE
FOR EACH ROW
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM MV_DEVICE_TYPE
  WHERE device_type_id = :NEW.device_type_id;

  IF v_count = 0 THEN
    PROC_LOG_ERROR(
      'EX_INVALID_TYPE_REF',
      'TRG_VALIDATE_DEVICE_TYPE_PAU',
      'device_id=' || :NEW.device_id || ', type=' || :NEW.device_type_id
    );
    RAISE_APPLICATION_ERROR(-20111,
      'device_type_id ' || :NEW.device_type_id || ' inexistant dans MV_DEVICE_TYPE');
  END IF;
END;
/


-- ------------------------------------------------------------
-- 2.2 TRG_VALIDATE_DEVICE_OS_PAU
--     Compense l'absence de FK DEVICE.os_version_id -> OS_VERSION
--     (OS_VERSION est sur Cergy, lue via MV_OS_VERSION).
--     Tolere NULL (os_version_id facultatif dans 02_setup_pau.sql:154).
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDATE_DEVICE_OS_PAU
BEFORE INSERT OR UPDATE OF os_version_id ON DEVICE
FOR EACH ROW
WHEN (NEW.os_version_id IS NOT NULL)
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM MV_OS_VERSION
  WHERE os_version_id = :NEW.os_version_id;

  IF v_count = 0 THEN
    PROC_LOG_ERROR(
      'EX_INVALID_OS_REF',
      'TRG_VALIDATE_DEVICE_OS_PAU',
      'device_id=' || :NEW.device_id || ', os=' || :NEW.os_version_id
    );
    RAISE_APPLICATION_ERROR(-20112,
      'os_version_id ' || :NEW.os_version_id || ' inexistant dans MV_OS_VERSION');
  END IF;
END;
/


-- ------------------------------------------------------------
-- 2.3 TRG_VALIDATE_PERIPH_TYPE_PAU
--     Compense l'absence de FK PERIPHERAL.peripheral_type_id -> PERIPHERAL_TYPE
--     (PERIPHERAL_TYPE est sur Cergy, lue via MV_PERIPHERAL_TYPE).
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDATE_PERIPH_TYPE_PAU
BEFORE INSERT OR UPDATE OF peripheral_type_id ON PERIPHERAL
FOR EACH ROW
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM MV_PERIPHERAL_TYPE
  WHERE peripheral_type_id = :NEW.peripheral_type_id;

  IF v_count = 0 THEN
    PROC_LOG_ERROR(
      'EX_INVALID_PERIPH_TYPE',
      'TRG_VALIDATE_PERIPH_TYPE_PAU',
      'peripheral_id=' || :NEW.peripheral_id ||
      ', type=' || :NEW.peripheral_type_id
    );
    RAISE_APPLICATION_ERROR(-20113,
      'peripheral_type_id ' || :NEW.peripheral_type_id ||
      ' inexistant dans MV_PERIPHERAL_TYPE');
  END IF;
END;
/


-- ------------------------------------------------------------
-- 2.4 TRG_DEVICE_RETIRED_GUARD_PAU (idem Cergy 1.2)
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_DEVICE_RETIRED_GUARD_PAU
BEFORE UPDATE OF device_status ON DEVICE
FOR EACH ROW
WHEN (NEW.device_status = 'RETIRED')
BEGIN
  IF :NEW.assigned_person_id IS NOT NULL THEN
    PROC_LOG_ERROR(
      'EX_DEVICE_RETIRED',
      'TRG_DEVICE_RETIRED_GUARD_PAU',
      'device_id=' || :NEW.device_id || ', person=' || :NEW.assigned_person_id
    );
    RAISE_APPLICATION_ERROR(-20102,
      'Impossible de retirer le device ' || :NEW.device_id ||
      ' : encore assigne a la personne ' || :NEW.assigned_person_id);
  END IF;
END;
/


-- ------------------------------------------------------------
-- 2.5 TRG_DEVICE_ASSIGN_ACTIVE_PAU (idem Cergy 1.3)
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_DEVICE_ASSIGN_ACTIVE_PAU
BEFORE INSERT OR UPDATE OF assigned_person_id ON DEVICE
FOR EACH ROW
WHEN (NEW.assigned_person_id IS NOT NULL)
DECLARE
  v_status VARCHAR2(20);
BEGIN
  SELECT person_status INTO v_status
  FROM PERSON
  WHERE person_id = :NEW.assigned_person_id;

  IF v_status <> 'ACTIVE' THEN
    PROC_LOG_ERROR(
      'EX_PERSON_INACTIVE',
      'TRG_DEVICE_ASSIGN_ACTIVE_PAU',
      'device_id=' || :NEW.device_id || ', person=' || :NEW.assigned_person_id
    );
    RAISE_APPLICATION_ERROR(-20103,
      'Personne ' || :NEW.assigned_person_id ||
      ' INACTIVE : assignation interdite');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    PROC_LOG_ERROR(
      'EX_PERSON_INACTIVE',
      'TRG_DEVICE_ASSIGN_ACTIVE_PAU',
      'person_id=' || :NEW.assigned_person_id || ' inexistante'
    );
    RAISE_APPLICATION_ERROR(-20103,
      'Personne ' || :NEW.assigned_person_id || ' inexistante');
END;
/


-- ------------------------------------------------------------
-- 2.6 TRG_ASSIGN_RETURN_SYNC_PAU (idem Cergy 1.5)
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ASSIGN_RETURN_SYNC_PAU
AFTER UPDATE OF returned_at ON DEVICE_ASSIGNMENT
FOR EACH ROW
WHEN (NEW.returned_at IS NOT NULL AND OLD.returned_at IS NULL)
BEGIN
  UPDATE DEVICE
  SET    assigned_person_id = NULL
  WHERE  device_id = :NEW.device_id
    AND  assigned_person_id = :NEW.person_id;
EXCEPTION
  WHEN OTHERS THEN
    PROC_LOG_ERROR(
      'ASSIGN_SYNC_FAILED',
      'TRG_ASSIGN_RETURN_SYNC_PAU',
      'device_id=' || :NEW.device_id || ', person_id=' || :NEW.person_id
    );
=======
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
>>>>>>> users/FA_archi
    RAISE;
END;
/


<<<<<<< HEAD
-- ------------------------------------------------------------
-- 2.7 TRG_PERSON_DEACTIVATE_PAU (idem Cergy 1.6, Option B)
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_PERSON_DEACTIVATE_PAU
BEFORE UPDATE OF person_status ON PERSON
FOR EACH ROW
WHEN (OLD.person_status = 'ACTIVE' AND NEW.person_status = 'INACTIVE')
DECLARE
  v_dev    NUMBER;
  v_assign NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_dev
  FROM DEVICE
  WHERE assigned_person_id = :OLD.person_id;

  IF v_dev > 0 THEN
    PROC_LOG_ERROR(
      'EX_ASSIGNMENT_CONFLICT',
      'TRG_PERSON_DEACTIVATE_PAU',
      'person_id=' || :OLD.person_id || ', devices=' || v_dev
    );
    RAISE_APPLICATION_ERROR(-20121,
      'Personne ' || :OLD.person_id || ' : ' || v_dev ||
      ' device(s) encore assigne(s). Liberer avant desactivation.');
  END IF;

  SELECT COUNT(*) INTO v_assign
  FROM DEVICE_ASSIGNMENT
  WHERE person_id = :OLD.person_id AND returned_at IS NULL;

  IF v_assign > 0 THEN
    PROC_LOG_ERROR(
      'EX_ASSIGNMENT_CONFLICT',
      'TRG_PERSON_DEACTIVATE_PAU',
      'person_id=' || :OLD.person_id || ', active_assignments=' || v_assign
    );
    RAISE_APPLICATION_ERROR(-20121,
      'Personne ' || :OLD.person_id || ' : ' || v_assign ||
      ' assignation(s) active(s). Clore les assignations avant desactivation.');
  END IF;
END;
/


-- ------------------------------------------------------------
-- 2.8 TRG_AUDIT_DEVICE_PAU (idem Cergy 1.7)
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDIT_DEVICE_PAU
AFTER INSERT OR UPDATE OR DELETE ON DEVICE
FOR EACH ROW
DECLARE
  v_action VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_action := 'INSERT';
  ELSIF UPDATING THEN
    v_action := 'UPDATE';
  ELSE
    v_action := 'DELETE';
  END IF;

  INSERT INTO DEVICE_HISTORY (
    history_id, device_id, action,
    old_status,    new_status,
    old_person_id, new_person_id,
    old_room_id,   new_room_id,
    changed_at, changed_by
  ) VALUES (
    SEQ_DEVICE_HISTORY.NEXTVAL,
    NVL(:NEW.device_id, :OLD.device_id),
    v_action,
    CASE WHEN INSERTING THEN NULL ELSE :OLD.device_status      END,
    CASE WHEN DELETING  THEN NULL ELSE :NEW.device_status      END,
    CASE WHEN INSERTING THEN NULL ELSE :OLD.assigned_person_id END,
    CASE WHEN DELETING  THEN NULL ELSE :NEW.assigned_person_id END,
    CASE WHEN INSERTING THEN NULL ELSE :OLD.room_id            END,
    CASE WHEN DELETING  THEN NULL ELSE :NEW.room_id            END,
    SYSTIMESTAMP, USER
  );
EXCEPTION
  WHEN OTHERS THEN
    PROC_LOG_ERROR(
      'AUDIT_FAILURE',
      'TRG_AUDIT_DEVICE_PAU',
      'device_id=' || NVL(:NEW.device_id, :OLD.device_id) ||
      ', action=' || v_action
    );
END;
/


-- ============================================================
-- PARTIE 3 : VERIFICATION
-- ============================================================
-- Tous les triggers crees, par site :
--   SELECT trigger_name, table_name, triggering_event, status
--   FROM user_triggers
--   ORDER BY table_name, trigger_name;
--
-- Test rapide de TRG_VALIDATE_ROLE_CERGY (doit echouer avec ORA-20110) :
--   INSERT INTO PERSON (person_id, site_id, role_id, login, last_name,
--     first_name, email, person_status)
--   VALUES (8888, 1, 999, 'tst', 'X', 'Y', 't@x.fr', 'ACTIVE');
--   -- Doit RAISE EX_INVALID_ROLE_REF + log dans ERROR_LOG.
--
-- Test rapide de TRG_AUDIT_DEVICE (doit creer une ligne DEVICE_HISTORY) :
--   UPDATE DEVICE SET device_status = 'IN_REPAIR' WHERE device_id = 1;
--   SELECT * FROM DEVICE_HISTORY ORDER BY changed_at DESC FETCH FIRST 3 ROWS ONLY;
--
-- Test rapide de TRG_TICKET_CLOSE_AUTO (sur Cergy uniquement) :
--   UPDATE MAINTENANCE_TICKET SET ticket_status = 'CLOSED' WHERE ticket_id = 1;
--   SELECT ticket_id, ticket_status, closed_at FROM MAINTENANCE_TICKET WHERE ticket_id = 1;
--   -- closed_at doit etre SYSDATE meme si non specifie.


COMMIT;
=======
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
>>>>>>> users/FA_archi
