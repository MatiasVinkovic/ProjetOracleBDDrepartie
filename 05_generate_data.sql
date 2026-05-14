-- ============================================================
-- 05_generate_data.sql
-- Projet GLPI BDDR - Generation de donnees aleatoires
-- Version 100% securisee avec adresses IP/MAC liees a la sequence
-- ============================================================

-- ============================================================
-- 1. GENERATION CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/XEPDB1

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
  
  v_new_device_id NUMBER;
  v_assigned_pers NUMBER;
  
  v_dev_status VARCHAR2(20);
  v_tkt_status VARCHAR2(20);
  v_open_date  DATE;
BEGIN

  -- ---- PERSONNES ----
  FOR i IN 1..p_nb_persons LOOP
    v_role_id := TRUNC(DBMS_RANDOM.VALUE(1, 5));
    
    INSERT INTO PERSON (person_id, site_id, role_id, login, last_name, first_name, email, person_status)
    VALUES (
      SEQ_PERSON_CERGY.NEXTVAL, 1, v_role_id,
      'cgy_' || SEQ_PERSON_CERGY.CURRVAL,
      DBMS_RANDOM.STRING('U', 8),
      DBMS_RANDOM.STRING('U', 6),
      'cgy_' || SEQ_PERSON_CERGY.CURRVAL || '@cytech.fr',
      CASE WHEN DBMS_RANDOM.VALUE < 0.1 THEN 'INACTIVE' ELSE 'ACTIVE' END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_persons || ' personnes Cergy inserees.');

  -- ---- DEVICES AVEC RESEAU ----
  FOR i IN 1..p_nb_devices LOOP
    v_room_id    := TRUNC(DBMS_RANDOM.VALUE(1, 4));
    v_dtype_id   := TRUNC(DBMS_RANDOM.VALUE(1, 4));
    v_osver_id   := TRUNC(DBMS_RANDOM.VALUE(1, 5));
    v_dev_status := CASE TRUNC(DBMS_RANDOM.VALUE(0, 4))
                      WHEN 0 THEN 'IN_STOCK'
                      WHEN 1 THEN 'IN_REPAIR'
                      WHEN 2 THEN 'RETIRED'
                      ELSE        'IN_SERVICE'
                    END;
                    
    -- Selection infaillible d'une personne reelle et active
    IF v_dev_status = 'IN_SERVICE' AND DBMS_RANDOM.VALUE < 0.7 THEN
      SELECT person_id INTO v_assigned_pers 
      FROM (SELECT person_id FROM PERSON WHERE person_status = 'ACTIVE' ORDER BY DBMS_RANDOM.VALUE) 
      WHERE ROWNUM = 1;
    ELSE
      v_assigned_pers := NULL;
    END IF;
                       
    SELECT SEQ_DEVICE_CERGY.NEXTVAL INTO v_new_device_id FROM DUAL;

    INSERT INTO DEVICE (device_id, site_id, room_id, assigned_person_id, device_type_id,
                        os_version_id, switch_id, vlan_id, asset_tag, device_name, serial_number, 
                        ip_address, mac_address, purchase_date, device_status)
    VALUES (
      v_new_device_id, 1, v_room_id, v_assigned_pers, v_dtype_id, v_osver_id,
      TRUNC(DBMS_RANDOM.VALUE(1, 3)), 
      TRUNC(DBMS_RANDOM.VALUE(1, 4)), 
      'CGY-AUTO-' || v_new_device_id,
      'Device Cergy ' || v_new_device_id,
      'SN-CGY-' || v_new_device_id,
      -- Generation mathematique de l'IP (garantie unique)
      '10.1.' || TO_CHAR(100 + MOD(TRUNC(v_new_device_id / 250), 100), 'FM999') || '.' || TO_CHAR(MOD(v_new_device_id, 250) + 1, 'FM999'),
      -- Generation mathematique de la MAC (garantie unique)
      '00:1A:2B:A1:' || LPAD(TO_CHAR(MOD(TRUNC(v_new_device_id / 256), 256), 'FMXX'), 2, '0') || ':' || LPAD(TO_CHAR(MOD(v_new_device_id, 256), 'FMXX'), 2, '0'), 
      SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 1500)),
      v_dev_status
    );
    
    IF v_assigned_pers IS NOT NULL THEN
      INSERT INTO DEVICE_ASSIGNMENT (assignment_id, device_id, person_id, assigned_at)
      VALUES (100000 + v_new_device_id, v_new_device_id, v_assigned_pers, SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 300)));
    END IF;

    -- ---- PERIPHERIQUES ----
    v_ptype_id := TRUNC(DBMS_RANDOM.VALUE(1, 6)); 
    INSERT INTO PERIPHERAL (peripheral_id, site_id, room_id, assigned_device_id,
                            peripheral_type_id, peripheral_name, serial_number, peripheral_status)
    VALUES (
      SEQ_PERIPH_CERGY.NEXTVAL, 1, v_room_id, v_new_device_id, v_ptype_id,
      'Periph Cergy ' || v_new_device_id,
      'SN-CGY-P-' || v_new_device_id,
      CASE WHEN v_dev_status = 'IN_SERVICE' THEN 'ASSIGNED' ELSE 'AVAILABLE' END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_devices || ' devices Cergy inseres.');

  -- ---- TICKETS DE MAINTENANCE ----
  FOR i IN 1..p_nb_tickets LOOP
    v_tkt_status := CASE TRUNC(DBMS_RANDOM.VALUE(0, 3))
                      WHEN 0 THEN 'OPEN'
                      WHEN 1 THEN 'IN_PROGRESS'
                      ELSE        'CLOSED'
                    END;
                    
    SELECT device_id INTO v_new_device_id 
    FROM (SELECT device_id FROM DEVICE ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
    
    SELECT person_id INTO v_assigned_pers 
    FROM (SELECT person_id FROM PERSON ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
    
    v_open_date := SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 365));
    
    INSERT INTO MAINTENANCE_TICKET (ticket_id, site_id, device_id, opened_by_person_id,
                                    technician_id, issue_label, ticket_status, opened_at, closed_at)
    VALUES (
      SEQ_TICKET_ID.NEXTVAL, 1, v_new_device_id, v_assigned_pers,
      3, 
      'Incident automatique ' || DBMS_RANDOM.STRING('L', 10),
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
    DBMS_OUTPUT.PUT_LINE('ERREUR CERGY : ' || SQLERRM);
    RAISE;
END PROC_GENERATE_DATA;
/

BEGIN
  PROC_GENERATE_DATA(50, 100, 20);
END;
/


-- ============================================================
-- 2. GENERATION PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/XEPDB1

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
  
  v_new_device_id NUMBER;
  v_assigned_pers NUMBER;
  
  v_dev_status VARCHAR2(20);
BEGIN

  -- ---- PERSONNES ----
  FOR i IN 1..p_nb_persons LOOP
    v_role_id := TRUNC(DBMS_RANDOM.VALUE(1, 5));
    
    INSERT INTO PERSON (person_id, site_id, role_id, login, last_name, first_name, email, person_status)
    VALUES (
      SEQ_PERSON_PAU.NEXTVAL, 2, v_role_id,
      'pau_' || SEQ_PERSON_PAU.CURRVAL,
      DBMS_RANDOM.STRING('U', 8),
      DBMS_RANDOM.STRING('U', 6),
      'pau_' || SEQ_PERSON_PAU.CURRVAL || '@cytech.fr',
      CASE WHEN DBMS_RANDOM.VALUE < 0.1 THEN 'INACTIVE' ELSE 'ACTIVE' END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_persons || ' personnes Pau inserees.');

  -- ---- DEVICES AVEC RESEAU ----
  FOR i IN 1..p_nb_devices LOOP
    v_room_id    := 1001 + TRUNC(DBMS_RANDOM.VALUE(0, 3)); 
    v_dtype_id   := TRUNC(DBMS_RANDOM.VALUE(1, 4));
    v_osver_id   := TRUNC(DBMS_RANDOM.VALUE(1, 5));
    v_dev_status := CASE TRUNC(DBMS_RANDOM.VALUE(0, 4))
                      WHEN 0 THEN 'IN_STOCK'
                      WHEN 1 THEN 'IN_REPAIR'
                      WHEN 2 THEN 'RETIRED'
                      ELSE        'IN_SERVICE'
                    END;
                    
    IF v_dev_status = 'IN_SERVICE' AND DBMS_RANDOM.VALUE < 0.7 THEN
      SELECT person_id INTO v_assigned_pers 
      FROM (SELECT person_id FROM PERSON WHERE person_status = 'ACTIVE' ORDER BY DBMS_RANDOM.VALUE) 
      WHERE ROWNUM = 1;
    ELSE
      v_assigned_pers := NULL;
    END IF;
                       
    SELECT SEQ_DEVICE_PAU.NEXTVAL INTO v_new_device_id FROM DUAL;

    INSERT INTO DEVICE (device_id, site_id, room_id, assigned_person_id, device_type_id,
                        os_version_id, switch_id, vlan_id, asset_tag, device_name, serial_number, 
                        ip_address, mac_address, purchase_date, device_status)
    VALUES (
      v_new_device_id, 2, v_room_id, v_assigned_pers, v_dtype_id, v_osver_id,
      TRUNC(DBMS_RANDOM.VALUE(2000, 2002)), 
      TRUNC(DBMS_RANDOM.VALUE(2000, 2003)), 
      'PAU-AUTO-' || v_new_device_id,
      'Device Pau ' || v_new_device_id,
      'SN-PAU-' || v_new_device_id,
      '10.2.' || TO_CHAR(100 + MOD(TRUNC(v_new_device_id / 250), 100), 'FM999') || '.' || TO_CHAR(MOD(v_new_device_id, 250) + 1, 'FM999'), 
      '00:2A:2B:B1:' || LPAD(TO_CHAR(MOD(TRUNC(v_new_device_id / 256), 256), 'FMXX'), 2, '0') || ':' || LPAD(TO_CHAR(MOD(v_new_device_id, 256), 'FMXX'), 2, '0'), 
      SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 1500)),
      v_dev_status
    );
    
    IF v_assigned_pers IS NOT NULL THEN
      INSERT INTO DEVICE_ASSIGNMENT (assignment_id, device_id, person_id, assigned_at)
      VALUES (200000 + v_new_device_id, v_new_device_id, v_assigned_pers, SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 300)));
    END IF;

    -- ---- PERIPHERIQUES ----
    v_ptype_id := TRUNC(DBMS_RANDOM.VALUE(1, 6));
    INSERT INTO PERIPHERAL (peripheral_id, site_id, room_id, assigned_device_id,
                            peripheral_type_id, peripheral_name, serial_number, peripheral_status)
    VALUES (
      SEQ_PERIPH_PAU.NEXTVAL, 2, v_room_id, v_new_device_id, v_ptype_id,
      'Periph Pau ' || v_new_device_id,
      'SN-PAU-P-' || v_new_device_id,
      CASE WHEN v_dev_status = 'IN_SERVICE' THEN 'ASSIGNED' ELSE 'AVAILABLE' END
    );
  END LOOP;
  DBMS_OUTPUT.PUT_LINE(p_nb_devices || ' devices et peripheriques Pau inseres.');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('==> Generation Pau terminee avec succes.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERREUR PAU : ' || SQLERRM);
    RAISE;
END PROC_GENERATE_DATA;
/

BEGIN
  PROC_GENERATE_DATA(50, 100);
END;
/