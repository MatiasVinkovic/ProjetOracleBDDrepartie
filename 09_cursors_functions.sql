-- ============================================================
-- 09_cursors_functions.sql
<<<<<<< HEAD
<<<<<<< HEAD
-- Projet GLPI BDDR - Curseurs explicites et fonctions PL/SQL
--
-- A executer APRES :
--   01_setup_cergy.sql, 02_setup_pau.sql, 03_replication.sql,
--   06_error_logging.sql, 08_triggers.sql (utilise PROC_LOG_ERROR).
--
-- Contenu :
--   FONCTIONS (utilisables en SELECT / vues / triggers)
--     FCT_DEVICE_AGE              : age d'un device en mois depuis purchase_date
--     FCT_TICKET_DURATION_DAYS    : duree d'un ticket en jours (Cergy uniquement)
--     FCT_DEVICE_HAS_ACTIVE_TICKET: 0/1 si device a un ticket OPEN/IN_PROGRESS
--                                   (retour NUMBER et non BOOLEAN car Oracle
--                                   n'accepte pas BOOLEAN en SQL)
--
--   PROCEDURES A CURSEUR EXPLICITE
--     PROC_REPORT_PARC_BY_BUILDING : rapport hierarchique avec 3 curseurs
--                                    imbriques (BUILDING -> ROOM -> DEVICE).
--     PROC_DETECT_AGING_TICKETS    : curseur parametre sur tickets > N jours,
--                                    chaque ligne loggee dans ERROR_LOG avec
--                                    app_code='TICKET_AGING' (alerte, pas erreur).
--     PROC_CLEANUP_ORPHAN_PERIPH   : curseur FOR UPDATE + WHERE CURRENT OF
--                                    pour liberer les periph dont le device
--                                    est RETIRED ou supprime.
--     PROC_RECONCILE_ASSIGNMENTS   : diagnostic one-shot (redondant en regime
--                                    nominal avec TRG_ASSIGN_RETURN_SYNC, mais
--                                    utile pour verifier l'historique apres
--                                    installation).
--
-- Note : FCT_DEVICE_AGE n'est PAS DETERMINISTIC car elle depend de SYSDATE.
=======
-- curseurs et fonctions PL/SQL : reporting + utilitaires.
-- à exécuter après 06 (proc_log_error).
>>>>>>> users/FA_archi
=======
-- curseurs et fonctions PL/SQL : reporting + utilitaires.
-- à exécuter après 06 (proc_log_error).
>>>>>>> bf885b7 (simplification, partie 1)
-- ============================================================


-- ============================================================
<<<<<<< HEAD
<<<<<<< HEAD
-- PARTIE 1 : CERGY
=======
-- Cergy
>>>>>>> users/FA_archi
=======
-- Cergy
>>>>>>> bf885b7 (simplification, partie 1)
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON


<<<<<<< HEAD
<<<<<<< HEAD
-- ------------------------------------------------------------
-- 1.1 FCT_DEVICE_AGE
--     Renvoie l'age en mois (avec decimale) depuis purchase_date.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FCT_DEVICE_AGE (p_device_id IN NUMBER)
=======
-- âge d'un device en mois depuis purchase_date
CREATE OR REPLACE FUNCTION fct_device_age(p_device_id IN NUMBER)
>>>>>>> bf885b7 (simplification, partie 1)
RETURN NUMBER AS
  v_d DATE;
BEGIN
<<<<<<< HEAD
  SELECT purchase_date INTO v_purchase
  FROM DEVICE
  WHERE device_id = p_device_id;

  IF v_purchase IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_purchase), 1);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/


-- ------------------------------------------------------------
-- 1.2 FCT_TICKET_DURATION_DAYS
--     Duree en jours entre opened_at et closed_at.
--     Si le ticket est encore ouvert, renvoie la duree depuis l'ouverture.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FCT_TICKET_DURATION_DAYS (p_ticket_id IN NUMBER)
RETURN NUMBER AS
  v_open  DATE;
  v_close DATE;
BEGIN
  SELECT opened_at, closed_at INTO v_open, v_close
  FROM MAINTENANCE_TICKET
  WHERE ticket_id = p_ticket_id;

  RETURN ROUND(NVL(v_close, SYSDATE) - v_open);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/


-- ------------------------------------------------------------
-- 1.3 FCT_DEVICE_HAS_ACTIVE_TICKET
--     Retour NUMBER(0/1) plutot que BOOLEAN : permet l'usage en SQL :
--       SELECT asset_tag FROM DEVICE WHERE FCT_DEVICE_HAS_ACTIVE_TICKET(device_id) = 1;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FCT_DEVICE_HAS_ACTIVE_TICKET (p_device_id IN NUMBER)
RETURN NUMBER AS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM MAINTENANCE_TICKET
  WHERE device_id = p_device_id
    AND ticket_status IN ('OPEN', 'IN_PROGRESS');

  RETURN CASE WHEN v_count > 0 THEN 1 ELSE 0 END;
END;
/


-- ------------------------------------------------------------
-- 1.4 PROC_REPORT_PARC_BY_BUILDING
--     3 curseurs explicites imbriques : BUILDING -> ROOM -> DEVICE.
--     Demontre le pattern curseur-dans-curseur (CM6).
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PROC_REPORT_PARC_BY_BUILDING AS
  CURSOR c_building IS
    SELECT building_id, building_code, building_name
    FROM BUILDING ORDER BY building_code;

  CURSOR c_room (p_building NUMBER) IS
    SELECT room_id, room_code, room_name, capacity
    FROM ROOM WHERE building_id = p_building
    ORDER BY room_code;

  CURSOR c_device (p_room NUMBER) IS
    SELECT device_id, asset_tag, device_name, device_status
    FROM DEVICE WHERE room_id = p_room
    ORDER BY asset_tag;

  v_total_devices NUMBER := 0;
  v_room_count    NUMBER;
BEGIN
  FOR b IN c_building LOOP
    DBMS_OUTPUT.PUT_LINE('=== Batiment ' || b.building_code ||
                         ' : ' || b.building_name || ' ===');

    FOR r IN c_room(b.building_id) LOOP
      DBMS_OUTPUT.PUT_LINE('  -- Salle ' || r.room_code ||
                           ' (capacite ' || NVL(r.capacity, 0) || ')');
      v_room_count := 0;

      FOR d IN c_device(r.room_id) LOOP
        DBMS_OUTPUT.PUT_LINE('     ' || d.asset_tag ||
                             ' | ' || d.device_name ||
                             ' [' || d.device_status || ']');
        v_room_count := v_room_count + 1;
      END LOOP;

      DBMS_OUTPUT.PUT_LINE('     -> ' || v_room_count || ' device(s)');
      v_total_devices := v_total_devices + v_room_count;
    END LOOP;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('=== TOTAL Cergy : ' || v_total_devices || ' device(s) ===');
EXCEPTION
  WHEN OTHERS THEN
    PROC_LOG_ERROR('REPORT_FAILURE', 'PROC_REPORT_PARC_BY_BUILDING');
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 1.5 PROC_DETECT_AGING_TICKETS
--     Curseur parametre : tickets ouverts depuis plus de N jours.
--     Logue chaque ligne dans ERROR_LOG avec app_code='TICKET_AGING'
--     pour creer une trace d'alerte historisable.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PROC_DETECT_AGING_TICKETS (
  p_threshold_days IN NUMBER DEFAULT 30
) AS
  CURSOR c_aging IS
    SELECT t.ticket_id, t.opened_at, t.issue_label,
           ROUND(SYSDATE - t.opened_at) AS age_days,
           t.site_id, t.device_id
    FROM MAINTENANCE_TICKET t
    WHERE t.ticket_status IN ('OPEN', 'IN_PROGRESS')
      AND SYSDATE - t.opened_at > p_threshold_days
    ORDER BY t.opened_at;

  v_count NUMBER := 0;
BEGIN
  FOR t IN c_aging LOOP
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE(
      'AGING ticket=' || t.ticket_id ||
      ' age=' || t.age_days || 'j' ||
      ' site=' || t.site_id ||
      ' device=' || t.device_id);

    -- Trace pour suivi : pas une erreur applicative, mais utile
    -- de retrouver historiquement les alertes detectees.
    PROC_LOG_ERROR(
      'TICKET_AGING',
      'PROC_DETECT_AGING_TICKETS',
      'ticket=' || t.ticket_id ||
      ', age=' || t.age_days || 'j' ||
      ', site=' || t.site_id);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE(v_count || ' ticket(s) ouvert(s) depuis plus de ' ||
                       p_threshold_days || ' jour(s).');
END;
/


-- ------------------------------------------------------------
-- 1.6 PROC_CLEANUP_ORPHAN_PERIPH
--     Curseur explicite FOR UPDATE + WHERE CURRENT OF (CM5/6).
--     Libere les peripheriques dont :
--       - le device referencé est marque RETIRED, ou
--       - le device referencé n'existe plus.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PROC_CLEANUP_ORPHAN_PERIPH AS
  CURSOR c_orphan IS
    SELECT p.peripheral_id, p.assigned_device_id,
           d.device_status AS dev_status
    FROM PERIPHERAL p
    LEFT JOIN DEVICE d ON p.assigned_device_id = d.device_id
    WHERE p.assigned_device_id IS NOT NULL
      AND (d.device_id IS NULL OR d.device_status = 'RETIRED')
    FOR UPDATE OF p.assigned_device_id, p.peripheral_status;

  v_periph_id   NUMBER;
  v_assigned_id NUMBER;
  v_dev_status  VARCHAR2(20);
  v_count       NUMBER := 0;
BEGIN
  OPEN c_orphan;
  LOOP
    FETCH c_orphan INTO v_periph_id, v_assigned_id, v_dev_status;
    EXIT WHEN c_orphan%NOTFOUND;

    UPDATE PERIPHERAL
    SET    assigned_device_id = NULL,
           peripheral_status  = 'AVAILABLE'
    WHERE  CURRENT OF c_orphan;

    PROC_LOG_ERROR(
      'ORPHAN_PERIPH',
      'PROC_CLEANUP_ORPHAN_PERIPH',
      'peripheral_id=' || v_periph_id ||
      ', was_linked_to=' || v_assigned_id ||
      ', dev_status=' || NVL(v_dev_status, 'DELETED'));

    v_count := v_count + 1;
  END LOOP;
  CLOSE c_orphan;
  COMMIT;

  DBMS_OUTPUT.PUT_LINE(v_count || ' peripherique(s) orphelin(s) libere(s).');
EXCEPTION
  WHEN OTHERS THEN
    IF c_orphan%ISOPEN THEN CLOSE c_orphan; END IF;
    ROLLBACK;
    PROC_LOG_ERROR('CLEANUP_FAILED', 'PROC_CLEANUP_ORPHAN_PERIPH');
    RAISE;
END;
/


-- ------------------------------------------------------------
-- 1.7 PROC_RECONCILE_ASSIGNMENTS
--     Outil de diagnostic one-shot : verifie que DEVICE.assigned_person_id
--     correspond bien a l'affectation active dans DEVICE_ASSIGNMENT.
--     En regime nominal (avec TRG_ASSIGN_RETURN_SYNC), retourne toujours 0.
--     Utile apres migration ou pour valider l'integrite historique.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PROC_RECONCILE_ASSIGNMENTS AS
  CURSOR c_active IS
    SELECT da.assignment_id, da.device_id, da.person_id,
           d.assigned_person_id AS device_person_id
    FROM DEVICE_ASSIGNMENT da
    JOIN DEVICE d ON d.device_id = da.device_id
    WHERE da.returned_at IS NULL;

  v_mismatch NUMBER := 0;
BEGIN
  FOR r IN c_active LOOP
    IF r.device_person_id IS NULL OR r.device_person_id <> r.person_id THEN
      v_mismatch := v_mismatch + 1;
      DBMS_OUTPUT.PUT_LINE(
        'MISMATCH device=' || r.device_id ||
        ' assignment.person=' || r.person_id ||
        ' device.person=' || NVL(TO_CHAR(r.device_person_id), 'NULL'));
    END IF;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(v_mismatch || ' incoherence(s) detectee(s).');
END;
/


-- ------------------------------------------------------------
-- 1.8 GRANTS Cergy
-- ------------------------------------------------------------
GRANT EXECUTE ON FCT_DEVICE_AGE               TO R_CERGY_READ;
GRANT EXECUTE ON FCT_TICKET_DURATION_DAYS     TO R_CERGY_READ;
GRANT EXECUTE ON FCT_DEVICE_HAS_ACTIVE_TICKET TO R_CERGY_READ;
GRANT EXECUTE ON PROC_REPORT_PARC_BY_BUILDING TO R_CERGY_READ;
GRANT EXECUTE ON PROC_DETECT_AGING_TICKETS    TO R_CERGY_MANAGER;
GRANT EXECUTE ON PROC_CLEANUP_ORPHAN_PERIPH   TO R_CERGY_MANAGER;
GRANT EXECUTE ON PROC_RECONCILE_ASSIGNMENTS   TO R_CERGY_READ;


-- ============================================================
-- PARTIE 2 : PAU
-- ============================================================
-- Sur Pau on n'a pas MAINTENANCE_TICKET (table sur Cergy), donc :
--   - PAS de FCT_TICKET_DURATION_DAYS
--   - PAS de FCT_DEVICE_HAS_ACTIVE_TICKET
--   - PAS de PROC_DETECT_AGING_TICKETS
-- Le reste est dupliqué (identique).
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON


-- 2.1 FCT_DEVICE_AGE
CREATE OR REPLACE FUNCTION FCT_DEVICE_AGE (p_device_id IN NUMBER)
RETURN NUMBER AS
  v_purchase DATE;
BEGIN
  SELECT purchase_date INTO v_purchase
  FROM DEVICE WHERE device_id = p_device_id;
  IF v_purchase IS NULL THEN RETURN NULL; END IF;
  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_purchase), 1);
=======
-- âge d'un device en mois depuis purchase_date
CREATE OR REPLACE FUNCTION fct_device_age(p_device_id IN NUMBER)
RETURN NUMBER AS
  v_d DATE;
BEGIN
  SELECT purchase_date INTO v_d FROM DEVICE WHERE device_id = p_device_id;
  IF v_d IS NULL THEN RETURN NULL; END IF;
  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_d), 1);
>>>>>>> users/FA_archi
=======
  SELECT purchase_date INTO v_d FROM DEVICE WHERE device_id = p_device_id;
  IF v_d IS NULL THEN RETURN NULL; END IF;
  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_d), 1);
>>>>>>> bf885b7 (simplification, partie 1)
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
/


<<<<<<< HEAD
<<<<<<< HEAD
-- 2.2 PROC_REPORT_PARC_BY_BUILDING (Pau)
CREATE OR REPLACE PROCEDURE PROC_REPORT_PARC_BY_BUILDING AS
  CURSOR c_building IS
    SELECT building_id, building_code, building_name
    FROM BUILDING ORDER BY building_code;
  CURSOR c_room (p_building NUMBER) IS
    SELECT room_id, room_code, room_name, capacity
    FROM ROOM WHERE building_id = p_building ORDER BY room_code;
  CURSOR c_device (p_room NUMBER) IS
    SELECT device_id, asset_tag, device_name, device_status
    FROM DEVICE WHERE room_id = p_room ORDER BY asset_tag;
  v_total NUMBER := 0;
  v_rcnt  NUMBER;
=======
-- durée d'un ticket en jours.
-- si encore ouvert, on renvoie la durée courante depuis l'ouverture.
CREATE OR REPLACE FUNCTION fct_ticket_duration_days(p_ticket_id IN NUMBER)
RETURN NUMBER AS
  v_o DATE;
  v_c DATE;
>>>>>>> bf885b7 (simplification, partie 1)
BEGIN
  SELECT opened_at, closed_at INTO v_o, v_c
  FROM MAINTENANCE_TICKET WHERE ticket_id = p_ticket_id;
  RETURN ROUND(NVL(v_c, SYSDATE) - v_o);
EXCEPTION
<<<<<<< HEAD
  WHEN OTHERS THEN
    PROC_LOG_ERROR('REPORT_FAILURE', 'PROC_REPORT_PARC_BY_BUILDING');
    RAISE;
=======
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
>>>>>>> users/FA_archi
=======
  WHEN NO_DATA_FOUND THEN RETURN NULL;
>>>>>>> bf885b7 (simplification, partie 1)
END;
/


<<<<<<< HEAD
<<<<<<< HEAD
-- 2.3 PROC_CLEANUP_ORPHAN_PERIPH (Pau)
CREATE OR REPLACE PROCEDURE PROC_CLEANUP_ORPHAN_PERIPH AS
  CURSOR c_orphan IS
    SELECT p.peripheral_id, p.assigned_device_id,
           d.device_status AS dev_status
=======
=======
>>>>>>> bf885b7 (simplification, partie 1)
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
<<<<<<< HEAD
>>>>>>> users/FA_archi
=======
>>>>>>> bf885b7 (simplification, partie 1)
    FROM PERIPHERAL p
    LEFT JOIN DEVICE d ON p.assigned_device_id = d.device_id
    WHERE p.assigned_device_id IS NOT NULL
      AND (d.device_id IS NULL OR d.device_status = 'RETIRED')
<<<<<<< HEAD
<<<<<<< HEAD
    FOR UPDATE OF p.assigned_device_id, p.peripheral_status;
  v_periph_id   NUMBER;
  v_assigned_id NUMBER;
  v_dev_status  VARCHAR2(20);
  v_count       NUMBER := 0;
BEGIN
  OPEN c_orphan;
  LOOP
    FETCH c_orphan INTO v_periph_id, v_assigned_id, v_dev_status;
    EXIT WHEN c_orphan%NOTFOUND;
=======
  ) LOOP
>>>>>>> bf885b7 (simplification, partie 1)
    UPDATE PERIPHERAL
       SET assigned_device_id = NULL,
           peripheral_status  = 'AVAILABLE'
     WHERE peripheral_id = o.peripheral_id;
    v_n := v_n + 1;
  END LOOP;
  COMMIT;
<<<<<<< HEAD
  DBMS_OUTPUT.PUT_LINE(v_count || ' peripherique(s) orphelin(s) libere(s).');
EXCEPTION
  WHEN OTHERS THEN
    IF c_orphan%ISOPEN THEN CLOSE c_orphan; END IF;
    ROLLBACK;
    PROC_LOG_ERROR('CLEANUP_FAILED', 'PROC_CLEANUP_ORPHAN_PERIPH');
    RAISE;
=======
  ) LOOP
    UPDATE PERIPHERAL
       SET assigned_device_id = NULL,
           peripheral_status  = 'AVAILABLE'
     WHERE peripheral_id = o.peripheral_id;
    v_n := v_n + 1;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE(v_n || ' périphérique(s) libéré(s)');
>>>>>>> users/FA_archi
=======
  DBMS_OUTPUT.PUT_LINE(v_n || ' périphérique(s) libéré(s)');
>>>>>>> bf885b7 (simplification, partie 1)
END;
/


<<<<<<< HEAD
<<<<<<< HEAD
-- 2.4 PROC_RECONCILE_ASSIGNMENTS (Pau)
CREATE OR REPLACE PROCEDURE PROC_RECONCILE_ASSIGNMENTS AS
  CURSOR c_active IS
    SELECT da.assignment_id, da.device_id, da.person_id,
           d.assigned_person_id AS device_person_id
    FROM DEVICE_ASSIGNMENT da
    JOIN DEVICE d ON d.device_id = da.device_id
    WHERE da.returned_at IS NULL;
  v_mismatch NUMBER := 0;
BEGIN
  FOR r IN c_active LOOP
    IF r.device_person_id IS NULL OR r.device_person_id <> r.person_id THEN
      v_mismatch := v_mismatch + 1;
      DBMS_OUTPUT.PUT_LINE(
        'MISMATCH device=' || r.device_id ||
        ' assignment.person=' || r.person_id ||
        ' device.person=' || NVL(TO_CHAR(r.device_person_id), 'NULL'));
    END IF;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(v_mismatch || ' incoherence(s) detectee(s).');
=======
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
=======
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
>>>>>>> bf885b7 (simplification, partie 1)
  SELECT purchase_date INTO v_d FROM DEVICE WHERE device_id = p_device_id;
  IF v_d IS NULL THEN RETURN NULL; END IF;
  RETURN ROUND(MONTHS_BETWEEN(SYSDATE, v_d), 1);
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
<<<<<<< HEAD
>>>>>>> users/FA_archi
=======
>>>>>>> bf885b7 (simplification, partie 1)
END;
/


<<<<<<< HEAD
<<<<<<< HEAD
-- 2.5 GRANTS Pau
GRANT EXECUTE ON FCT_DEVICE_AGE               TO R_PAU_READ;
GRANT EXECUTE ON PROC_REPORT_PARC_BY_BUILDING TO R_PAU_READ;
GRANT EXECUTE ON PROC_CLEANUP_ORPHAN_PERIPH   TO R_PAU_MANAGER;
GRANT EXECUTE ON PROC_RECONCILE_ASSIGNMENTS   TO R_PAU_READ;
=======
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
>>>>>>> bf885b7 (simplification, partie 1)


-- ============================================================
-- tests rapides
-- ============================================================
-- SELECT asset_tag, fct_device_age(device_id) AS age_mois
--   FROM DEVICE FETCH FIRST 5 ROWS ONLY;
--
-- SELECT asset_tag FROM DEVICE
--  WHERE fct_device_has_ticket(device_id) = 1;
--
<<<<<<< HEAD
-- 3) Tester FCT_DEVICE_HAS_ACTIVE_TICKET (Cergy) :
--    SELECT asset_tag FROM DEVICE
--    WHERE FCT_DEVICE_HAS_ACTIVE_TICKET(device_id) = 1;
--
-- 4) Executer le rapport hierarchique :
--    EXEC PROC_REPORT_PARC_BY_BUILDING;
--
-- 5) Detecter les tickets vieux (Cergy) :
--    EXEC PROC_DETECT_AGING_TICKETS(30);
--    SELECT * FROM ERROR_LOG WHERE app_code = 'TICKET_AGING'
--    ORDER BY error_ts DESC;
--
-- 6) Nettoyer les peripheriques orphelins :
--    EXEC PROC_CLEANUP_ORPHAN_PERIPH;
--    SELECT * FROM ERROR_LOG WHERE app_code = 'ORPHAN_PERIPH'
--    ORDER BY error_ts DESC;
--
-- 7) Verifier la coherence des affectations :
--    EXEC PROC_RECONCILE_ASSIGNMENTS;
=======
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
>>>>>>> users/FA_archi
=======
-- EXEC proc_report_parc;
-- EXEC proc_detect_aging_tickets(30);
-- EXEC proc_cleanup_orphan_periph;
>>>>>>> bf885b7 (simplification, partie 1)
