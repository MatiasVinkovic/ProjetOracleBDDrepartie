-- ============================================================
-- 05_generate_data.sql
-- Projet GLPI BDDR - Generation de donnees aleatoires
-- CYTECH_CERGY : 50 personnes, 100 devices, 100 peripheriques, 20 tickets
-- CYTECH_PAU   : 50 personnes, 100 devices, 100 peripheriques
-- ============================================================


-- ============================================================
-- 1. GENERATION CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON

CREATE OR REPLACE PROCEDURE PROC_GENERATE_DATA(
  p_nb_persons IN NUMBER DEFAULT 50,
  p_nb_devices IN NUMBER DEFAULT 100,
  p_nb_tickets IN NUMBER DEFAULT 20
) AS
  v_role_id    NUMBER;
  v_room_id    NUMBER;
  v_dtype_id   NUMBER;
  v_osver_id   NUMBER;
  v_ptype_id   NUMBER;
  v_pers_id    NUMBER;
  v_dev_id     NUMBER;
  v_dev_status VARCHAR2(20);
  v_tkt_status VARCHAR2(20);
  v_open_date  DATE;
BEGIN

  -- ---- PERSONNES ----
  FOR i IN 1..p_nb_persons LOOP
    v_role_id := TRUNC(DBMS_RANDOM.VALUE(1, 5)); -- role 1 a 4
    INSERT INTO PERSON (person_id, site_id, role_id, login, last_name, first_name, email, person_status)
    VALUES (
      100 + i,
      1,
      v_role_id,
      'cgy_' || TO_CHAR(100 + i),
      DBMS_RANDOM.STRING('U', 8),
      DBMS_RANDOM.STRING('U', 6),
      'cgy_' || TO_CHAR(100 + i) || '@cytech.fr',
      CASE WHEN DBMS_RANDOM.VALUE < 0.1 THEN 'INACTIVE' ELSE 'ACTIVE' END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_persons || ' personnes Cergy inserees.');

  -- ---- DEVICES ----
  FOR i IN 1..p_nb_devices LOOP
    v_room_id    := TRUNC(DBMS_RANDOM.VALUE(1, 4));      -- salle 1, 2 ou 3
    v_dtype_id   := TRUNC(DBMS_RANDOM.VALUE(1, 4));      -- type 1, 2 ou 3
    v_osver_id   := TRUNC(DBMS_RANDOM.VALUE(1, 5));      -- os 1 a 4
    v_dev_status := CASE TRUNC(DBMS_RANDOM.VALUE(0, 4))
                      WHEN 0 THEN 'IN_STOCK'
                      WHEN 1 THEN 'IN_REPAIR'
                      WHEN 2 THEN 'RETIRED'
                      ELSE        'IN_SERVICE'
                    END;
    -- personne affectee seulement si le device est IN_SERVICE
    v_pers_id    := CASE
                      WHEN v_dev_status = 'IN_SERVICE' AND DBMS_RANDOM.VALUE < 0.7
                      THEN 100 + TRUNC(DBMS_RANDOM.VALUE(1, p_nb_persons + 1))
                      ELSE NULL
                    END;
    INSERT INTO DEVICE (device_id, site_id, room_id, assigned_person_id, device_type_id,
                        os_version_id, asset_tag, device_name, serial_number, purchase_date, device_status)
    VALUES (
      100 + i, 1, v_room_id, v_pers_id, v_dtype_id, v_osver_id,
      'CGY-' || TO_CHAR(100 + i, 'FM00000'),
      'Device Cergy ' || TO_CHAR(100 + i),
      'SN-CGY-' || TO_CHAR(100 + i, 'FM00000'),
      SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 1500)),
      v_dev_status
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_devices || ' devices Cergy inseres.');

  -- ---- PERIPHERIQUES ----
  FOR i IN 1..p_nb_devices LOOP
    v_ptype_id := TRUNC(DBMS_RANDOM.VALUE(1, 6)); -- type 1 a 5
    v_room_id  := TRUNC(DBMS_RANDOM.VALUE(1, 4));
    INSERT INTO PERIPHERAL (peripheral_id, site_id, room_id, assigned_device_id,
                            peripheral_type_id, peripheral_name, serial_number, peripheral_status)
    VALUES (
      100 + i, 1, v_room_id, 100 + i, v_ptype_id,
      'Periph Cergy ' || TO_CHAR(100 + i),
      'SN-CGY-P-' || TO_CHAR(100 + i, 'FM00000'),
      CASE TRUNC(DBMS_RANDOM.VALUE(0, 3))
        WHEN 0 THEN 'AVAILABLE'
        WHEN 1 THEN 'ASSIGNED'
        ELSE        'BROKEN'
      END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_devices || ' peripheriques Cergy inseres.');

  -- ---- TICKETS DE MAINTENANCE ----
  FOR i IN 1..p_nb_tickets LOOP
    v_tkt_status := CASE TRUNC(DBMS_RANDOM.VALUE(0, 3))
                      WHEN 0 THEN 'OPEN'
                      WHEN 1 THEN 'IN_PROGRESS'
                      ELSE        'CLOSED'
                    END;
    v_dev_id    := 100 + TRUNC(DBMS_RANDOM.VALUE(1, p_nb_devices + 1));
    v_pers_id   := 100 + TRUNC(DBMS_RANDOM.VALUE(1, p_nb_persons + 1));
    v_open_date := SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 365));
    INSERT INTO MAINTENANCE_TICKET (ticket_id, site_id, device_id, opened_by_person_id,
                                    technician_id, issue_label, ticket_status, opened_at, closed_at)
    VALUES (
      SEQ_TICKET_ID.NEXTVAL, 1, v_dev_id, v_pers_id,
      3, -- technicien existant (person_id=3)
      'Incident ' || DBMS_RANDOM.STRING('L', 20),
      v_tkt_status,
      v_open_date,
      CASE WHEN v_tkt_status = 'CLOSED'
           THEN v_open_date + TRUNC(DBMS_RANDOM.VALUE(1, 30))
           ELSE NULL
      END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_tickets || ' tickets Cergy inseres.');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('==> Generation Cergy terminee avec succes.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERREUR : ' || SQLERRM);
    RAISE;
END PROC_GENERATE_DATA;
/

-- Execution
BEGIN
  PROC_GENERATE_DATA(50, 100, 20);
END;
/


-- ============================================================
-- 2. GENERATION PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

SET SERVEROUTPUT ON

CREATE OR REPLACE PROCEDURE PROC_GENERATE_DATA(
  p_nb_persons IN NUMBER DEFAULT 50,
  p_nb_devices IN NUMBER DEFAULT 100
) AS
  v_role_id    NUMBER;
  v_room_id    NUMBER;
  v_dtype_id   NUMBER;
  v_osver_id   NUMBER;
  v_ptype_id   NUMBER;
  v_pers_id    NUMBER;
  v_dev_status VARCHAR2(20);
BEGIN

  -- ---- PERSONNES ----
  FOR i IN 1..p_nb_persons LOOP
    v_role_id := TRUNC(DBMS_RANDOM.VALUE(1, 5));
    INSERT INTO PERSON (person_id, site_id, role_id, login, last_name, first_name, email, person_status)
    VALUES (
      2000 + i,
      2,
      v_role_id,
      'pau_' || TO_CHAR(2000 + i),
      DBMS_RANDOM.STRING('U', 8),
      DBMS_RANDOM.STRING('U', 6),
      'pau_' || TO_CHAR(2000 + i) || '@cytech.fr',
      CASE WHEN DBMS_RANDOM.VALUE < 0.1 THEN 'INACTIVE' ELSE 'ACTIVE' END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_persons || ' personnes Pau inserees.');

  -- ---- DEVICES ----
  FOR i IN 1..p_nb_devices LOOP
    v_room_id    := 1001 + TRUNC(DBMS_RANDOM.VALUE(0, 3)); -- salle 1001, 1002 ou 1003
    v_dtype_id   := TRUNC(DBMS_RANDOM.VALUE(1, 4));
    v_osver_id   := TRUNC(DBMS_RANDOM.VALUE(1, 5));
    v_dev_status := CASE TRUNC(DBMS_RANDOM.VALUE(0, 4))
                      WHEN 0 THEN 'IN_STOCK'
                      WHEN 1 THEN 'IN_REPAIR'
                      WHEN 2 THEN 'RETIRED'
                      ELSE        'IN_SERVICE'
                    END;
    v_pers_id    := CASE
                      WHEN v_dev_status = 'IN_SERVICE' AND DBMS_RANDOM.VALUE < 0.7
                      THEN 2000 + TRUNC(DBMS_RANDOM.VALUE(1, p_nb_persons + 1))
                      ELSE NULL
                    END;
    INSERT INTO DEVICE (device_id, site_id, room_id, assigned_person_id, device_type_id,
                        os_version_id, asset_tag, device_name, serial_number, purchase_date, device_status)
    VALUES (
      2000 + i, 2, v_room_id, v_pers_id, v_dtype_id, v_osver_id,
      'PAU-' || TO_CHAR(2000 + i, 'FM00000'),
      'Device Pau ' || TO_CHAR(2000 + i),
      'SN-PAU-' || TO_CHAR(2000 + i, 'FM00000'),
      SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 1500)),
      v_dev_status
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_devices || ' devices Pau inseres.');

  -- ---- PERIPHERIQUES ----
  FOR i IN 1..p_nb_devices LOOP
    v_ptype_id := TRUNC(DBMS_RANDOM.VALUE(1, 6));
    v_room_id  := 1001 + TRUNC(DBMS_RANDOM.VALUE(0, 3));
    INSERT INTO PERIPHERAL (peripheral_id, site_id, room_id, assigned_device_id,
                            peripheral_type_id, peripheral_name, serial_number, peripheral_status)
    VALUES (
      2000 + i, 2, v_room_id, 2000 + i, v_ptype_id,
      'Periph Pau ' || TO_CHAR(2000 + i),
      'SN-PAU-P-' || TO_CHAR(2000 + i, 'FM00000'),
      CASE TRUNC(DBMS_RANDOM.VALUE(0, 3))
        WHEN 0 THEN 'AVAILABLE'
        WHEN 1 THEN 'ASSIGNED'
        ELSE        'BROKEN'
      END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_devices || ' peripheriques Pau inseres.');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('==> Generation Pau terminee avec succes.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERREUR : ' || SQLERRM);
    RAISE;
END PROC_GENERATE_DATA;
/

-- Execution
BEGIN
  PROC_GENERATE_DATA(50, 100);
END;
/
