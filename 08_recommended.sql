-- ============================================================
-- 08_recommended.sql
-- Fortement recommande : vues globales, procedures, fonction,
-- curseur rapport, synonymes.
-- A executer APRES 04_setup_admin.sql.
-- ============================================================


-- ============================================================
-- 1. VUES GLOBALES + PL/SQL (CYTECH_CERGY)
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/XEPDB1

-- ---- Vues globales consolidees (Cergy + Pau via LNK_PAU) ----

CREATE OR REPLACE VIEW V_GLOBAL_DEVICE AS
SELECT device_id, site_id, asset_tag, device_name, device_status, 'CERGY' AS site_label
FROM   DEVICE
UNION ALL
SELECT device_id, site_id, asset_tag, device_name, device_status, 'PAU'   AS site_label
FROM   DEVICE@LNK_PAU;

CREATE OR REPLACE VIEW V_GLOBAL_PERSON AS
SELECT person_id, site_id, login, last_name, first_name, email, person_status, 'CERGY' AS site_label
FROM   PERSON
UNION ALL
SELECT person_id, site_id, login, last_name, first_name, email, person_status, 'PAU'   AS site_label
FROM   PERSON@LNK_PAU;


-- ---- Procedure : transfert d'un equipement entre les deux sites ----
-- Parametres :
--   p_device_id      : ID du device a transferer
--   p_source_site    : site actuel du device (1 = Cergy, 2 = Pau)
--   p_target_room_id : ID d'une salle valide sur le site de destination
--
-- Comportement : copie le device sur le site cible (statut IN_STOCK),
--   puis passe l'original en RETIRED pour conserver l'historique.

CREATE OR REPLACE PROCEDURE PROC_TRANSFER_DEVICE (
  p_device_id      IN NUMBER,
  p_source_site    IN NUMBER,
  p_target_room_id IN NUMBER
) AS
  v_new_id    NUMBER;
  v_type_id   NUMBER;
  v_os_id     NUMBER;
  v_asset_tag VARCHAR2(40);
  v_name      VARCHAR2(80);
  v_serial    VARCHAR2(80);
  v_pdate     DATE;
BEGIN
  IF p_source_site = 1 THEN
    SELECT device_type_id, os_version_id, asset_tag, device_name,
           serial_number, purchase_date
    INTO   v_type_id, v_os_id, v_asset_tag, v_name, v_serial, v_pdate
    FROM   DEVICE
    WHERE  device_id = p_device_id AND site_id = 1;

    SELECT SEQ_DEVICE_PAU.NEXTVAL@LNK_PAU INTO v_new_id FROM DUAL;

    INSERT INTO DEVICE@LNK_PAU (
      device_id, site_id, room_id, device_type_id, os_version_id,
      asset_tag, device_name, serial_number, purchase_date, device_status
    ) VALUES (
      v_new_id, 2, p_target_room_id, v_type_id, v_os_id,
      v_asset_tag, v_name || ' (transfere)', v_serial, v_pdate, 'IN_STOCK'
    );

    UPDATE DEVICE SET device_status = 'RETIRED'
    WHERE  device_id = p_device_id;

  ELSIF p_source_site = 2 THEN
    SELECT device_type_id, os_version_id, asset_tag, device_name,
           serial_number, purchase_date
    INTO   v_type_id, v_os_id, v_asset_tag, v_name, v_serial, v_pdate
    FROM   DEVICE@LNK_PAU
    WHERE  device_id = p_device_id AND site_id = 2;

    SELECT SEQ_DEVICE_CERGY.NEXTVAL INTO v_new_id FROM DUAL;

    INSERT INTO DEVICE (
      device_id, site_id, room_id, device_type_id, os_version_id,
      asset_tag, device_name, serial_number, purchase_date, device_status
    ) VALUES (
      v_new_id, 1, p_target_room_id, v_type_id, v_os_id,
      v_asset_tag, v_name || ' (transfere)', v_serial, v_pdate, 'IN_STOCK'
    );

    UPDATE DEVICE@LNK_PAU SET device_status = 'RETIRED'
    WHERE  device_id = p_device_id;

  ELSE
    RAISE_APPLICATION_ERROR(-20040, 'site_source invalide : ' || p_source_site);
  END IF;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE(
    'Device ' || p_device_id || ' (site ' || p_source_site ||
    ') transfere. Nouveau ID sur site cible : ' || v_new_id
  );
EXCEPTION WHEN OTHERS THEN
  ROLLBACK;
  RAISE_APPLICATION_ERROR(-20041, 'PROC_TRANSFER_DEVICE : ' || SQLERRM);
END;
/


-- ---- Fonction : nombre d'equipements IN_SERVICE par site ----

CREATE OR REPLACE FUNCTION FCT_COUNT_DEVICES_BY_SITE (
  p_site_id IN NUMBER
) RETURN NUMBER AS
  v_count NUMBER;
BEGIN
  IF p_site_id = 1 THEN
    SELECT COUNT(*) INTO v_count
    FROM   DEVICE
    WHERE  device_status = 'IN_SERVICE';
  ELSIF p_site_id = 2 THEN
    SELECT COUNT(*) INTO v_count
    FROM   DEVICE@LNK_PAU
    WHERE  device_status = 'IN_SERVICE';
  ELSE
    RAISE_APPLICATION_ERROR(-20042, 'site_id invalide : ' || p_site_id);
  END IF;
  RETURN v_count;
END;
/


-- ---- Procedure rapport : curseurs sur les equipements EN REPARATION ----
-- Usage : SET SERVEROUTPUT ON; puis EXEC PROC_RAPPORT_IN_REPAIR;

CREATE OR REPLACE PROCEDURE PROC_RAPPORT_IN_REPAIR AS
  CURSOR cur_cergy IS
    SELECT device_id, asset_tag, device_name
    FROM   DEVICE
    WHERE  device_status = 'IN_REPAIR';
  CURSOR cur_pau IS
    SELECT device_id, asset_tag, device_name
    FROM   DEVICE@LNK_PAU
    WHERE  device_status = 'IN_REPAIR';
  v_total NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Equipements EN REPARATION (tous sites) ===');
  DBMS_OUTPUT.PUT_LINE(
    RPAD('SITE', 8) || RPAD('ID', 8) ||
    RPAD('ASSET TAG', 18) || 'NOM'
  );
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 65, '-'));

  FOR rec IN cur_cergy LOOP
    DBMS_OUTPUT.PUT_LINE(
      RPAD('CERGY', 8) || RPAD(TO_CHAR(rec.device_id), 8) ||
      RPAD(rec.asset_tag, 18) || rec.device_name
    );
    v_total := v_total + 1;
  END LOOP;

  FOR rec IN cur_pau LOOP
    DBMS_OUTPUT.PUT_LINE(
      RPAD('PAU', 8) || RPAD(TO_CHAR(rec.device_id), 8) ||
      RPAD(rec.asset_tag, 18) || rec.device_name
    );
    v_total := v_total + 1;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE(RPAD('-', 65, '-'));
  DBMS_OUTPUT.PUT_LINE('Total : ' || v_total || ' equipement(s) en reparation');
END;
/


-- ============================================================
-- 2. GRANTS SUPPLEMENTAIRES (SYSDBA)
-- ============================================================
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = XEPDB1;

-- Donner acces aux vues globales et aux objets PL/SQL via le role admin
GRANT SELECT  ON CYTECH_CERGY.V_GLOBAL_DEVICE              TO CYTECH_ADMIN_ROLE;
GRANT SELECT  ON CYTECH_CERGY.V_GLOBAL_PERSON              TO CYTECH_ADMIN_ROLE;
GRANT EXECUTE ON CYTECH_CERGY.PROC_TRANSFER_DEVICE         TO CYTECH_ADMIN_ROLE;
GRANT EXECUTE ON CYTECH_CERGY.FCT_COUNT_DEVICES_BY_SITE    TO CYTECH_ADMIN_ROLE;
GRANT EXECUTE ON CYTECH_CERGY.PROC_RAPPORT_IN_REPAIR       TO CYTECH_ADMIN_ROLE;

-- Permettre a CYTECH_ADMIN de creer ses propres synonymes
GRANT CREATE SYNONYM TO CYTECH_ADMIN;


-- ============================================================
-- 3. SYNONYMES (CYTECH_ADMIN)
-- ============================================================
CONNECT CYTECH_ADMIN/admin2026@//localhost:1521/XEPDB1

-- Acces direct aux tables sans prefixer le schema
CREATE SYNONYM DEVICE_CERGY    FOR CYTECH_CERGY.DEVICE;
CREATE SYNONYM DEVICE_PAU      FOR CYTECH_PAU.DEVICE;
CREATE SYNONYM PERSON_CERGY    FOR CYTECH_CERGY.PERSON;
CREATE SYNONYM PERSON_PAU      FOR CYTECH_PAU.PERSON;
CREATE SYNONYM TICKET          FOR CYTECH_CERGY.MAINTENANCE_TICKET;

-- Acces direct aux vues globales
CREATE SYNONYM V_GLOBAL_DEVICE FOR CYTECH_CERGY.V_GLOBAL_DEVICE;
CREATE SYNONYM V_GLOBAL_PERSON FOR CYTECH_CERGY.V_GLOBAL_PERSON;


-- ============================================================
-- 4. VERIFICATION
-- ============================================================

-- Compter les equipements actifs par site (via la fonction)
SELECT CYTECH_CERGY.FCT_COUNT_DEVICES_BY_SITE(1) AS actifs_cergy,
       CYTECH_CERGY.FCT_COUNT_DEVICES_BY_SITE(2) AS actifs_pau
FROM DUAL;

-- Vue globale des equipements depuis CYTECH_ADMIN (via synonyme)
SELECT site_label, device_status, COUNT(*) AS nb
FROM   V_GLOBAL_DEVICE
GROUP  BY site_label, device_status
ORDER  BY site_label, device_status;

-- Vue globale des personnes depuis CYTECH_ADMIN (via synonyme)
SELECT site_label, person_status, COUNT(*) AS nb
FROM   V_GLOBAL_PERSON
GROUP  BY site_label, person_status
ORDER  BY site_label, person_status;

-- Rapport curseur (activer SERVEROUTPUT avant)
-- SET SERVEROUTPUT ON;
-- EXEC CYTECH_CERGY.PROC_RAPPORT_IN_REPAIR;

-- Exemple transfert : device 3 de Cergy vers salle 1001 de Pau
-- EXEC CYTECH_CERGY.PROC_TRANSFER_DEVICE(3, 1, 1001);
