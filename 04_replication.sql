-- ============================================================
-- 04_replication.sql
-- Projet GLPI BDDR - Replication des tables de reference
-- Tables concernees : SITE, PERSON_ROLE, DEVICE_TYPE,
--                     OS_FAMILY, OS_VERSION, PERIPHERAL_TYPE
--
-- Principe anti-boucle :
--   Avant le DML distant, on appelle set_replicating@LNK_*
--   pour mettre g_replicating=TRUE dans la session distante.
--   Le trigger distant voit g_replicating=TRUE et ne repercute pas.
-- ============================================================


-- ============================================================
-- 1. PKG_REPLICATION sur CYTECH_CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE PKG_REPLICATION AS
  g_replicating BOOLEAN := FALSE;
  PROCEDURE set_replicating(p_val BOOLEAN);
END PKG_REPLICATION;
/

CREATE OR REPLACE PACKAGE BODY PKG_REPLICATION AS
  PROCEDURE set_replicating(p_val BOOLEAN) IS
  BEGIN
    g_replicating := p_val;
  END;
END PKG_REPLICATION;
/


-- ============================================================
-- 2. PKG_REPLICATION sur CYTECH_PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE PKG_REPLICATION AS
  g_replicating BOOLEAN := FALSE;
  PROCEDURE set_replicating(p_val BOOLEAN);
END PKG_REPLICATION;
/

CREATE OR REPLACE PACKAGE BODY PKG_REPLICATION AS
  PROCEDURE set_replicating(p_val BOOLEAN) IS
  BEGIN
    g_replicating := p_val;
  END;
END PKG_REPLICATION;
/


-- ============================================================
-- 3. TRIGGERS CERGY -> PAU (via LNK_PAU)
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

-- ---------- SITE ----------
CREATE OR REPLACE TRIGGER TRG_REP_SITE
AFTER INSERT OR UPDATE OR DELETE ON SITE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_PAU(TRUE);
    IF INSERTING THEN
      INSERT INTO SITE@LNK_PAU (site_id, site_code, site_name, city, is_active)
      VALUES (:NEW.site_id, :NEW.site_code, :NEW.site_name, :NEW.city, :NEW.is_active);
    ELSIF UPDATING THEN
      UPDATE SITE@LNK_PAU
      SET site_code = :NEW.site_code, site_name = :NEW.site_name,
          city = :NEW.city, is_active = :NEW.is_active
      WHERE site_id = :OLD.site_id;
    ELSIF DELETING THEN
      DELETE FROM SITE@LNK_PAU WHERE site_id = :OLD.site_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_PAU(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_PAU(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20001, 'Replication SITE Cergy->Pau : ' || SQLERRM);
END;
/

-- ---------- PERSON_ROLE ----------
CREATE OR REPLACE TRIGGER TRG_REP_PERSON_ROLE
AFTER INSERT OR UPDATE OR DELETE ON PERSON_ROLE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_PAU(TRUE);
    IF INSERTING THEN
      INSERT INTO PERSON_ROLE@LNK_PAU (role_id, role_code, role_label)
      VALUES (:NEW.role_id, :NEW.role_code, :NEW.role_label);
    ELSIF UPDATING THEN
      UPDATE PERSON_ROLE@LNK_PAU
      SET role_code = :NEW.role_code, role_label = :NEW.role_label
      WHERE role_id = :OLD.role_id;
    ELSIF DELETING THEN
      DELETE FROM PERSON_ROLE@LNK_PAU WHERE role_id = :OLD.role_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_PAU(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_PAU(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20002, 'Replication PERSON_ROLE Cergy->Pau : ' || SQLERRM);
END;
/

-- ---------- DEVICE_TYPE ----------
CREATE OR REPLACE TRIGGER TRG_REP_DEVICE_TYPE
AFTER INSERT OR UPDATE OR DELETE ON DEVICE_TYPE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_PAU(TRUE);
    IF INSERTING THEN
      INSERT INTO DEVICE_TYPE@LNK_PAU (device_type_id, type_code, type_label)
      VALUES (:NEW.device_type_id, :NEW.type_code, :NEW.type_label);
    ELSIF UPDATING THEN
      UPDATE DEVICE_TYPE@LNK_PAU
      SET type_code = :NEW.type_code, type_label = :NEW.type_label
      WHERE device_type_id = :OLD.device_type_id;
    ELSIF DELETING THEN
      DELETE FROM DEVICE_TYPE@LNK_PAU WHERE device_type_id = :OLD.device_type_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_PAU(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_PAU(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20003, 'Replication DEVICE_TYPE Cergy->Pau : ' || SQLERRM);
END;
/

-- ---------- OS_FAMILY ----------
CREATE OR REPLACE TRIGGER TRG_REP_OS_FAMILY
AFTER INSERT OR UPDATE OR DELETE ON OS_FAMILY FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_PAU(TRUE);
    IF INSERTING THEN
      INSERT INTO OS_FAMILY@LNK_PAU (os_family_id, family_name)
      VALUES (:NEW.os_family_id, :NEW.family_name);
    ELSIF UPDATING THEN
      UPDATE OS_FAMILY@LNK_PAU
      SET family_name = :NEW.family_name
      WHERE os_family_id = :OLD.os_family_id;
    ELSIF DELETING THEN
      DELETE FROM OS_FAMILY@LNK_PAU WHERE os_family_id = :OLD.os_family_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_PAU(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_PAU(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20004, 'Replication OS_FAMILY Cergy->Pau : ' || SQLERRM);
END;
/

-- ---------- OS_VERSION ----------
CREATE OR REPLACE TRIGGER TRG_REP_OS_VERSION
AFTER INSERT OR UPDATE OR DELETE ON OS_VERSION FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_PAU(TRUE);
    IF INSERTING THEN
      INSERT INTO OS_VERSION@LNK_PAU (os_version_id, os_family_id, version_label)
      VALUES (:NEW.os_version_id, :NEW.os_family_id, :NEW.version_label);
    ELSIF UPDATING THEN
      UPDATE OS_VERSION@LNK_PAU
      SET os_family_id = :NEW.os_family_id, version_label = :NEW.version_label
      WHERE os_version_id = :OLD.os_version_id;
    ELSIF DELETING THEN
      DELETE FROM OS_VERSION@LNK_PAU WHERE os_version_id = :OLD.os_version_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_PAU(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_PAU(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20005, 'Replication OS_VERSION Cergy->Pau : ' || SQLERRM);
END;
/

-- ---------- PERIPHERAL_TYPE ----------
CREATE OR REPLACE TRIGGER TRG_REP_PERIPHERAL_TYPE
AFTER INSERT OR UPDATE OR DELETE ON PERIPHERAL_TYPE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_PAU(TRUE);
    IF INSERTING THEN
      INSERT INTO PERIPHERAL_TYPE@LNK_PAU (peripheral_type_id, type_code, type_label)
      VALUES (:NEW.peripheral_type_id, :NEW.type_code, :NEW.type_label);
    ELSIF UPDATING THEN
      UPDATE PERIPHERAL_TYPE@LNK_PAU
      SET type_code = :NEW.type_code, type_label = :NEW.type_label
      WHERE peripheral_type_id = :OLD.peripheral_type_id;
    ELSIF DELETING THEN
      DELETE FROM PERIPHERAL_TYPE@LNK_PAU WHERE peripheral_type_id = :OLD.peripheral_type_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_PAU(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_PAU(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20006, 'Replication PERIPHERAL_TYPE Cergy->Pau : ' || SQLERRM);
END;
/


-- ============================================================
-- 4. TRIGGERS PAU -> CERGY (via LNK_CERGY)
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

-- ---------- SITE ----------
CREATE OR REPLACE TRIGGER TRG_REP_SITE
AFTER INSERT OR UPDATE OR DELETE ON SITE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_CERGY(TRUE);
    IF INSERTING THEN
      INSERT INTO SITE@LNK_CERGY (site_id, site_code, site_name, city, is_active)
      VALUES (:NEW.site_id, :NEW.site_code, :NEW.site_name, :NEW.city, :NEW.is_active);
    ELSIF UPDATING THEN
      UPDATE SITE@LNK_CERGY
      SET site_code = :NEW.site_code, site_name = :NEW.site_name,
          city = :NEW.city, is_active = :NEW.is_active
      WHERE site_id = :OLD.site_id;
    ELSIF DELETING THEN
      DELETE FROM SITE@LNK_CERGY WHERE site_id = :OLD.site_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20001, 'Replication SITE Pau->Cergy : ' || SQLERRM);
END;
/

-- ---------- PERSON_ROLE ----------
CREATE OR REPLACE TRIGGER TRG_REP_PERSON_ROLE
AFTER INSERT OR UPDATE OR DELETE ON PERSON_ROLE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_CERGY(TRUE);
    IF INSERTING THEN
      INSERT INTO PERSON_ROLE@LNK_CERGY (role_id, role_code, role_label)
      VALUES (:NEW.role_id, :NEW.role_code, :NEW.role_label);
    ELSIF UPDATING THEN
      UPDATE PERSON_ROLE@LNK_CERGY
      SET role_code = :NEW.role_code, role_label = :NEW.role_label
      WHERE role_id = :OLD.role_id;
    ELSIF DELETING THEN
      DELETE FROM PERSON_ROLE@LNK_CERGY WHERE role_id = :OLD.role_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20002, 'Replication PERSON_ROLE Pau->Cergy : ' || SQLERRM);
END;
/

-- ---------- DEVICE_TYPE ----------
CREATE OR REPLACE TRIGGER TRG_REP_DEVICE_TYPE
AFTER INSERT OR UPDATE OR DELETE ON DEVICE_TYPE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_CERGY(TRUE);
    IF INSERTING THEN
      INSERT INTO DEVICE_TYPE@LNK_CERGY (device_type_id, type_code, type_label)
      VALUES (:NEW.device_type_id, :NEW.type_code, :NEW.type_label);
    ELSIF UPDATING THEN
      UPDATE DEVICE_TYPE@LNK_CERGY
      SET type_code = :NEW.type_code, type_label = :NEW.type_label
      WHERE device_type_id = :OLD.device_type_id;
    ELSIF DELETING THEN
      DELETE FROM DEVICE_TYPE@LNK_CERGY WHERE device_type_id = :OLD.device_type_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20003, 'Replication DEVICE_TYPE Pau->Cergy : ' || SQLERRM);
END;
/

-- ---------- OS_FAMILY ----------
CREATE OR REPLACE TRIGGER TRG_REP_OS_FAMILY
AFTER INSERT OR UPDATE OR DELETE ON OS_FAMILY FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_CERGY(TRUE);
    IF INSERTING THEN
      INSERT INTO OS_FAMILY@LNK_CERGY (os_family_id, family_name)
      VALUES (:NEW.os_family_id, :NEW.family_name);
    ELSIF UPDATING THEN
      UPDATE OS_FAMILY@LNK_CERGY
      SET family_name = :NEW.family_name
      WHERE os_family_id = :OLD.os_family_id;
    ELSIF DELETING THEN
      DELETE FROM OS_FAMILY@LNK_CERGY WHERE os_family_id = :OLD.os_family_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20004, 'Replication OS_FAMILY Pau->Cergy : ' || SQLERRM);
END;
/

-- ---------- OS_VERSION ----------
CREATE OR REPLACE TRIGGER TRG_REP_OS_VERSION
AFTER INSERT OR UPDATE OR DELETE ON OS_VERSION FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_CERGY(TRUE);
    IF INSERTING THEN
      INSERT INTO OS_VERSION@LNK_CERGY (os_version_id, os_family_id, version_label)
      VALUES (:NEW.os_version_id, :NEW.os_family_id, :NEW.version_label);
    ELSIF UPDATING THEN
      UPDATE OS_VERSION@LNK_CERGY
      SET os_family_id = :NEW.os_family_id, version_label = :NEW.version_label
      WHERE os_version_id = :OLD.os_version_id;
    ELSIF DELETING THEN
      DELETE FROM OS_VERSION@LNK_CERGY WHERE os_version_id = :OLD.os_version_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20005, 'Replication OS_VERSION Pau->Cergy : ' || SQLERRM);
END;
/

-- ---------- PERIPHERAL_TYPE ----------
CREATE OR REPLACE TRIGGER TRG_REP_PERIPHERAL_TYPE
AFTER INSERT OR UPDATE OR DELETE ON PERIPHERAL_TYPE FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;
    PKG_REPLICATION.set_replicating@LNK_CERGY(TRUE);
    IF INSERTING THEN
      INSERT INTO PERIPHERAL_TYPE@LNK_CERGY (peripheral_type_id, type_code, type_label)
      VALUES (:NEW.peripheral_type_id, :NEW.type_code, :NEW.type_label);
    ELSIF UPDATING THEN
      UPDATE PERIPHERAL_TYPE@LNK_CERGY
      SET type_code = :NEW.type_code, type_label = :NEW.type_label
      WHERE peripheral_type_id = :OLD.peripheral_type_id;
    ELSIF DELETING THEN
      DELETE FROM PERIPHERAL_TYPE@LNK_CERGY WHERE peripheral_type_id = :OLD.peripheral_type_id;
    END IF;
    PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE);
    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PKG_REPLICATION.g_replicating := FALSE;
  BEGIN PKG_REPLICATION.set_replicating@LNK_CERGY(FALSE); EXCEPTION WHEN OTHERS THEN NULL; END;
  RAISE_APPLICATION_ERROR(-20006, 'Replication PERIPHERAL_TYPE Pau->Cergy : ' || SQLERRM);
END;
/


-- ============================================================
-- 5. VERIFICATION
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE','PACKAGE BODY','TRIGGER')
ORDER BY object_type, object_name;

CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE','PACKAGE BODY','TRIGGER')
ORDER BY object_type, object_name;
