-- ============================================================
-- 09_cursors_functions.sql
-- curseurs et fonctions PL/SQL : reporting + utilitaires.
-- à exécuter après 06 (proc_log_error).
-- ============================================================


-- ============================================================
-- Cergy
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON


-- âge d'un device en mois depuis purchase_date
CREATE OR REPLACE FUNCTION fct_device_age(p_device_id IN NUMBER)
RETURN NUMBER AS
  v_d DATE;
BEGIN
  SELECT purchase_date INTO v_d FROM DEVICE WHERE device_id = p_device_id;
  IF v_d IS NULL THEN RETURN NULL; END IF;
  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_d), 1);
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
/


-- durée d'un ticket en jours.
-- si encore ouvert, on renvoie la durée courante depuis l'ouverture.
CREATE OR REPLACE FUNCTION fct_ticket_duration_days(p_ticket_id IN NUMBER)
RETURN NUMBER AS
  v_o DATE;
  v_c DATE;
BEGIN
  SELECT opened_at, closed_at INTO v_o, v_c
  FROM MAINTENANCE_TICKET WHERE ticket_id = p_ticket_id;
  RETURN ROUND(NVL(v_c, SYSDATE) - v_o);
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
/


-- 1 si le device a un ticket OPEN/IN_PROGRESS, 0 sinon.
-- (on renvoie NUMBER et pas BOOLEAN : oracle interdit BOOLEAN en SQL.)
CREATE OR REPLACE FUNCTION fct_device_has_ticket(p_device_id IN NUMBER)
RETURN NUMBER AS
  v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n
  FROM MAINTENANCE_TICKET
  WHERE device_id = p_device_id
    AND ticket_status IN ('OPEN', 'IN_PROGRESS');
  RETURN CASE WHEN v_n > 0 THEN 1 ELSE 0 END;
END;
/


-- rapport hiérarchique : bâtiment -> salle -> device.
-- curseurs imbriqués (pattern reporting_recoltes du TP6).
CREATE OR REPLACE PROCEDURE proc_report_parc AS
  CURSOR c_b IS
    SELECT building_id, building_code, building_name
    FROM BUILDING ORDER BY building_code;

  CURSOR c_r(p_b NUMBER) IS
    SELECT room_id, room_code
    FROM ROOM WHERE building_id = p_b ORDER BY room_code;

  CURSOR c_d(p_r NUMBER) IS
    SELECT asset_tag, device_status
    FROM DEVICE WHERE room_id = p_r ORDER BY asset_tag;

  v_total NUMBER := 0;
  v_n NUMBER;
BEGIN
  FOR b IN c_b LOOP
    DBMS_OUTPUT.PUT_LINE('bâtiment ' || b.building_code || ' : ' || b.building_name);
    FOR r IN c_r(b.building_id) LOOP
      DBMS_OUTPUT.PUT_LINE('  salle ' || r.room_code);
      v_n := 0;
      FOR d IN c_d(r.room_id) LOOP
        DBMS_OUTPUT.PUT_LINE('    ' || d.asset_tag || ' [' || d.device_status || ']');
        v_n := v_n + 1;
      END LOOP;
      DBMS_OUTPUT.PUT_LINE('    => ' || v_n || ' device(s)');
      v_total := v_total + v_n;
    END LOOP;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('total : ' || v_total);
END;
/


-- tickets ouverts depuis plus de N jours -> log dans ERROR_LOG
CREATE OR REPLACE PROCEDURE proc_detect_aging_tickets(p_days IN NUMBER DEFAULT 30) AS
  v_n NUMBER := 0;
BEGIN
  FOR t IN (
    SELECT ticket_id, ROUND(SYSDATE - opened_at) age
    FROM MAINTENANCE_TICKET
    WHERE ticket_status IN ('OPEN', 'IN_PROGRESS')
      AND SYSDATE - opened_at > p_days
  ) LOOP
    DBMS_OUTPUT.PUT_LINE('ticket ' || t.ticket_id || ' : ' || t.age || ' jours');
    proc_log_error('proc_detect_aging_tickets',
                   'ticket=' || t.ticket_id || ' age=' || t.age);
    v_n := v_n + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(v_n || ' ticket(s) en retard');
END;
/


-- libère les périphériques reliés à un device RETIRED ou inexistant
CREATE OR REPLACE PROCEDURE proc_cleanup_orphan_periph AS
  v_n NUMBER := 0;
BEGIN
  FOR o IN (
    SELECT p.peripheral_id
    FROM PERIPHERAL p
    LEFT JOIN DEVICE d ON p.assigned_device_id = d.device_id
    WHERE p.assigned_device_id IS NOT NULL
      AND (d.device_id IS NULL OR d.device_status = 'RETIRED')
  ) LOOP
    UPDATE PERIPHERAL
       SET assigned_device_id = NULL,
           peripheral_status  = 'AVAILABLE'
     WHERE peripheral_id = o.peripheral_id;
    v_n := v_n + 1;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE(v_n || ' périphérique(s) libéré(s)');
END;
/


GRANT EXECUTE ON fct_device_age              TO R_CERGY_READ;
GRANT EXECUTE ON fct_ticket_duration_days    TO R_CERGY_READ;
GRANT EXECUTE ON fct_device_has_ticket       TO R_CERGY_READ;
GRANT EXECUTE ON proc_report_parc            TO R_CERGY_READ;
GRANT EXECUTE ON proc_detect_aging_tickets   TO R_CERGY_MANAGER;
GRANT EXECUTE ON proc_cleanup_orphan_periph  TO R_CERGY_MANAGER;


-- ============================================================
-- Pau (pas de tickets locaux, donc moins de fonctions)
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON


CREATE OR REPLACE FUNCTION fct_device_age(p_device_id IN NUMBER)
RETURN NUMBER AS
  v_d DATE;
BEGIN
  SELECT purchase_date INTO v_d FROM DEVICE WHERE device_id = p_device_id;
  IF v_d IS NULL THEN RETURN NULL; END IF;
  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_d), 1);
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
/


CREATE OR REPLACE PROCEDURE proc_report_parc AS
  CURSOR c_b IS
    SELECT building_id, building_code, building_name
    FROM BUILDING ORDER BY building_code;

  CURSOR c_r(p_b NUMBER) IS
    SELECT room_id, room_code
    FROM ROOM WHERE building_id = p_b ORDER BY room_code;

  CURSOR c_d(p_r NUMBER) IS
    SELECT asset_tag, device_status
    FROM DEVICE WHERE room_id = p_r ORDER BY asset_tag;

  v_total NUMBER := 0;
  v_n NUMBER;
BEGIN
  FOR b IN c_b LOOP
    DBMS_OUTPUT.PUT_LINE('bâtiment ' || b.building_code || ' : ' || b.building_name);
    FOR r IN c_r(b.building_id) LOOP
      DBMS_OUTPUT.PUT_LINE('  salle ' || r.room_code);
      v_n := 0;
      FOR d IN c_d(r.room_id) LOOP
        DBMS_OUTPUT.PUT_LINE('    ' || d.asset_tag || ' [' || d.device_status || ']');
        v_n := v_n + 1;
      END LOOP;
      DBMS_OUTPUT.PUT_LINE('    => ' || v_n);
      v_total := v_total + v_n;
    END LOOP;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('total : ' || v_total);
END;
/


CREATE OR REPLACE PROCEDURE proc_cleanup_orphan_periph AS
  v_n NUMBER := 0;
BEGIN
  FOR o IN (
    SELECT p.peripheral_id
    FROM PERIPHERAL p
    LEFT JOIN DEVICE d ON p.assigned_device_id = d.device_id
    WHERE p.assigned_device_id IS NOT NULL
      AND (d.device_id IS NULL OR d.device_status = 'RETIRED')
  ) LOOP
    UPDATE PERIPHERAL
       SET assigned_device_id = NULL,
           peripheral_status  = 'AVAILABLE'
     WHERE peripheral_id = o.peripheral_id;
    v_n := v_n + 1;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE(v_n || ' périphérique(s) libéré(s)');
END;
/


GRANT EXECUTE ON fct_device_age              TO R_PAU_READ;
GRANT EXECUTE ON proc_report_parc            TO R_PAU_READ;
GRANT EXECUTE ON proc_cleanup_orphan_periph  TO R_PAU_MANAGER;


-- ============================================================
-- tests rapides
-- ============================================================
-- SELECT asset_tag, fct_device_age(device_id) AS age_mois
--   FROM DEVICE FETCH FIRST 5 ROWS ONLY;
--
-- SELECT asset_tag FROM DEVICE
--  WHERE fct_device_has_ticket(device_id) = 1;
--
-- EXEC proc_report_parc;
-- EXEC proc_detect_aging_tickets(30);
-- EXEC proc_cleanup_orphan_periph;
