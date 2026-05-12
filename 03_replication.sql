-- ============================================================
-- 04_replication.sql
-- Projet GLPI BDDR - Objets cross-site (MVs, vues distantes, procedures)
--
-- A executer APRES 01_setup_cergy.sql ET 02_setup_pau.sql.
--
-- Choix d'architecture :
--   Les anciens triggers de replication bidirectionnels ont ete supprimes
--   (12 triggers + 2 packages anti-boucle). Raison : synchronisation temps
--   reel pour des donnees qui changent 2-3 fois par an = complexite
--   injustifiee + risque de deadlock.
--
--   Repartition retenue :
--     - Pau possede   : SITE, PERSON_ROLE
--     - Cergy possede : DEVICE_TYPE, PERIPHERAL_TYPE, OS_FAMILY, OS_VERSION
--     - Chaque site dispose de vues materialisees (REFRESH ON DEMAND) pour
--       les tables de reference dont il n'est pas proprietaire.
--     - Les FK vers ces tables distantes sont supprimees (Oracle n'autorise
--       pas de FK vers une MV ni vers une table distante). L'integrite est
--       garantie par les CHECK constraints + les procedures de saisie.
--
--   Refresh des MVs (a faire quand le proprietaire ajoute une ligne) :
--     -- cote Cergy
--     EXEC DBMS_MVIEW.REFRESH('MV_SITE');
--     EXEC DBMS_MVIEW.REFRESH('MV_PERSON_ROLE');
--     -- cote Pau
--     EXEC DBMS_MVIEW.REFRESH('MV_DEVICE_TYPE');
--     EXEC DBMS_MVIEW.REFRESH('MV_PERIPHERAL_TYPE');
--     EXEC DBMS_MVIEW.REFRESH('MV_OS_FAMILY');
--     EXEC DBMS_MVIEW.REFRESH('MV_OS_VERSION');
-- ============================================================


-- ============================================================
-- 1. OBJETS CROSS-SITE COTE CERGY
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1

-- ---- MVs : SITE et PERSON_ROLE appartiennent a Pau ---- done
CREATE MATERIALIZED VIEW MV_SITE
  BUILD IMMEDIATE REFRESH ON DEMAND
AS SELECT site_id, site_code, site_name, city, is_active FROM SITE@LNK_PAU;

CREATE MATERIALIZED VIEW MV_PERSON_ROLE -- done
  BUILD IMMEDIATE REFRESH ON DEMAND
AS SELECT role_id, role_code, role_label FROM PERSON_ROLE@LNK_PAU;

-- ---- Vue devices Pau (acces rapide depuis Cergy) ---- done
CREATE OR REPLACE VIEW V_PAU_DEVICE_MIN AS
SELECT device_id, asset_tag, device_name, device_status
FROM DEVICE@LNK_PAU;

-- ---- Procedure ticket cross-site (Cergy = gestionnaire central) ---- done
-- Valide que le device existe sur le bon site avant d'inserer.
CREATE OR REPLACE PROCEDURE PROC_CREATE_TICKET (
  p_site_id             IN NUMBER,
  p_device_id           IN NUMBER,
  p_opened_by_person_id IN NUMBER,
  p_issue_label         IN VARCHAR2
) AS
  v_device_count NUMBER := 0;
  v_ticket_id    NUMBER;
BEGIN
  IF p_site_id = 1 THEN
    SELECT COUNT(*) INTO v_device_count
    FROM DEVICE WHERE device_id = p_device_id AND site_id = 1;
  ELSIF p_site_id = 2 THEN
    SELECT COUNT(*) INTO v_device_count
    FROM DEVICE@LNK_PAU WHERE device_id = p_device_id AND site_id = 2;
  ELSE
    RAISE_APPLICATION_ERROR(-20032, 'site_id invalide : ' || p_site_id);
  END IF;

  IF v_device_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20033,
      'Device ' || p_device_id || ' introuvable sur site ' || p_site_id);
  END IF;

  SELECT SEQ_TICKET_ID.NEXTVAL INTO v_ticket_id FROM DUAL;

  INSERT INTO MAINTENANCE_TICKET (
    ticket_id, site_id, device_id, opened_by_person_id,
    issue_label, ticket_status, opened_at
  ) VALUES (
    v_ticket_id, p_site_id, p_device_id, p_opened_by_person_id,
    p_issue_label, 'OPEN', SYSDATE
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ticket ' || v_ticket_id || ' cree (site=' || p_site_id || ', device=' || p_device_id || ')');
EXCEPTION WHEN OTHERS THEN
  ROLLBACK;
  RAISE_APPLICATION_ERROR(-20034, 'PROC_CREATE_TICKET : ' || SQLERRM);
END;
/


-- ============================================================
-- 2. OBJETS CROSS-SITE COTE PAU
-- ============================================================
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1

-- ---- MVs : DEVICE_TYPE, PERIPHERAL_TYPE, OS_FAMILY, OS_VERSION appartiennent a Cergy ---- done
CREATE MATERIALIZED VIEW MV_DEVICE_TYPE
  BUILD IMMEDIATE REFRESH ON DEMAND
AS SELECT device_type_id, type_code, type_label FROM DEVICE_TYPE@LNK_CERGY;

CREATE MATERIALIZED VIEW MV_PERIPHERAL_TYPE --done
  BUILD IMMEDIATE REFRESH ON DEMAND
AS SELECT peripheral_type_id, type_code, type_label FROM PERIPHERAL_TYPE@LNK_CERGY;

CREATE MATERIALIZED VIEW MV_OS_FAMILY --done
  BUILD IMMEDIATE REFRESH ON DEMAND
AS SELECT os_family_id, family_name FROM OS_FAMILY@LNK_CERGY;

CREATE MATERIALIZED VIEW MV_OS_VERSION -- done
  BUILD IMMEDIATE REFRESH ON DEMAND
AS SELECT os_version_id, os_family_id, version_label FROM OS_VERSION@LNK_CERGY;

-- ---- Vue acces tickets Cergy depuis Pau ---- done
CREATE OR REPLACE VIEW V_CERGY_TICKET_MIN AS
SELECT ticket_id, site_id, device_id, issue_label, ticket_status, opened_at
FROM MAINTENANCE_TICKET@LNK_CERGY;

-- ---- Procedure ouverture ticket depuis Pau (insere sur Cergy) ---- done
CREATE OR REPLACE PROCEDURE PROC_OPEN_TICKET_PAU (
  p_device_id           IN NUMBER,
  p_opened_by_person_id IN NUMBER,
  p_issue_label         IN VARCHAR2
) AS
  v_device_count NUMBER;
  v_ticket_id    NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_device_count
  FROM DEVICE WHERE device_id = p_device_id AND site_id = 2;

  IF v_device_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20030, 'Device introuvable sur Pau : ' || p_device_id);
  END IF;

  SELECT SEQ_TICKET_ID.NEXTVAL@LNK_CERGY INTO v_ticket_id FROM DUAL;

  INSERT INTO MAINTENANCE_TICKET@LNK_CERGY (
    ticket_id, site_id, device_id, opened_by_person_id,
    issue_label, ticket_status, opened_at
  ) VALUES (
    v_ticket_id, 2, p_device_id, p_opened_by_person_id,
    p_issue_label, 'OPEN', SYSDATE
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ticket ' || v_ticket_id || ' ouvert pour device Pau ' || p_device_id);
EXCEPTION WHEN OTHERS THEN
  ROLLBACK;
  RAISE_APPLICATION_ERROR(-20031, 'PROC_OPEN_TICKET_PAU : ' || SQLERRM);
END;
/


-- ============================================================
-- 3. VERIFICATION
-- ============================================================
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1
SELECT mview_name, refresh_mode FROM user_mviews ORDER BY mview_name;

CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1
SELECT mview_name, refresh_mode FROM user_mviews ORDER BY mview_name;
