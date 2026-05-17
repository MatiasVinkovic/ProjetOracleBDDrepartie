# Mini-Projet GLPI — Base de Données Répartie (BDDR)

Projet pédagogique — **ING2 Bases de Données Avancées** (CY Tech).

Ce dépôt contient les scripts Oracle pour déployer une base répartie simplifiée (sites **Cergy** / **Pau**) avec réplication, matérialized views, et gestion de tickets IT distribués.

---

## 📋 Prérequis

- **Oracle Database XE** (docker image: `gvenzl/oracle-xe:21-slim`) ou instance locale
- **SQL*Plus** ou **SQLcl** installé
- PDB cible: `FREEPDB1` (ou ajuster les CONNECT dans les scripts)

---

## 📁 Scripts fournis

| Script | Rôle | Connexion |
|--------|------|-----------|
| `00_to_start.sql` | Tablespaces, users, grants | `SYS AS SYSDBA` |
| `01_setup_cergy.sql` | DDL schéma Cergy (tables, séquences, clusters) | `CYTECH_CERGY` |
| `02_setup_pau.sql` | DDL schéma Pau (tables, séquences, clusters) | `CYTECH_PAU` |
| `03_replication.sql` | DB links, MVs, procédures cross-site | `CYTECH_CERGY` + `CYTECH_PAU` |
| `04_role_gestion.sql` | Rôles applicatifs, grants, comptes de test | `SYS AS SYSDBA` |
| `05_generate_data.sql` | Génération de données aléatoires | `CYTECH_CERGY` |
| `06_error_logging.sql` | Table `ERROR_LOG`, procédure `proc_log_error` | `CYTECH_CERGY` + `CYTECH_PAU` |
| `07_indexes.sql` | Index additionnels, statistiques | `CYTECH_CERGY` + `CYTECH_PAU` |
| `08_triggers.sql` | Triggers métier, audits, replication guards | `CYTECH_CERGY` + `CYTECH_PAU` |
| `09_cursors_functions.sql` | Fonctions, curseurs, procédures utilitaires | `CYTECH_CERGY` |

---

## 🚀 Ordre d'exécution recommandé

1. **`00_to_start.sql`** (en `SYS AS SYSDBA`)
   - Crée tablespaces `DATA_CERGY`, `IDX_CERGY`, `DATA_PAU`, `IDX_PAU`
   - Crée users `CYTECH_CERGY` (pwd: `cergy2026`) et `CYTECH_PAU` (pwd: `pau2026`)
   - À faire **une seule fois**

2. **`01_setup_cergy.sql`** (connecté en `CYTECH_CERGY`)
   - DDL: SITE, PERSON, DEVICE, DEVICE_TYPE, PERIPHERAL, ROOM, OS_FAMILY, OS_VERSION
   - Séquences (début: 100)
   - Cluster `cl_device_periph` sur (site_id=1)
   - Contrainte `CK_SITE_CERGY` : site_id = 1 (fragmenté)

3. **`02_setup_pau.sql`** (connecté en `CYTECH_PAU`)
   - DDL: mêmes tables (site_id=2)
   - Séquences (début: 2000)
   - Cluster `cl_device_periph_pau`
   - Contrainte `CK_SITE_PAU` : site_id = 2 (fragmenté)

4. **`03_replication.sql`**
   - Crée DB links `LNK_PAU@CERGY` et `LNK_CERGY@PAU`
   - Materialized views: `MV_SITE`, `MV_PERSON_ROLE`, `MV_DEVICE_TYPE`, `MV_PERIPHERAL_TYPE`, `MV_OS_FAMILY`, `MV_OS_VERSION`
   - Views: `V_PAU_DEVICE_MIN`, `V_CERGY_TICKET_MIN`
   - Procédures cross-site: `PROC_CREATE_TICKET`, `PROC_OPEN_TICKET_PAU`, `REFRESH_ALL_VIEWS`
   - **Important:** exécuter depuis Cergy et Pau (vérifier les instructions du script)

5. **`04_role_gestion.sql`** (en `SYS AS SYSDBA`)
   - Rôles: `R_CERGY_TECH`, `R_CERGY_MANAGER`, `R_PAU_TECH`, `R_PAU_MANAGER`
   - Grants sur tables, MVs, procédures
   - Comptes test: `U_CERGY_TECH`, `U_CERGY_MGR`, `U_PAU_TECH`, `U_PAU_MGR`

6. **`06_error_logging.sql`**, **`07_indexes.sql`**, **`08_triggers.sql`**, **`09_cursors_functions.sql`**
   - À exécuter dans cet ordre après les schémas de base
   - `08_triggers.sql` crée package `PKG_REPLICATION` (garde contre boucles infinies)

7. **`05_generate_data.sql`** (après les index/triggers)
   - Procédure `PROC_GENERATE_DATA` : insère données aléatoires via `DBMS_RANDOM`
   - Vérifier la PDB dans les lignes `CONNECT` avant exécution

---

## ⚠️ Avertissement important : PDB

Certains scripts utilisent **`FREEPDB1`**, d'autres **`XEPDB1`**. Avant d'exécuter :
- Vérifier toutes les lignes `CONNECT ...@//localhost:1521/<PDB>`
- Harmoniser vers une seule PDB cible (par défaut: `FREEPDB1`)
- Adapter les mots de passe si nécessaire

---

## 🛠️ Démarrage rapide (Docker)

```bash
# 1. Lancer Oracle XE (port 1521, mot de passe par défaut: oracle)
docker run -d --name oracle-xe -p 1521:1521 -e ORACLE_PASSWORD=oracle gvenzl/oracle-xe:21-slim
sleep 30  # Attendre le démarrage complet

# 2. Bootstrap SYSDBA (tablespaces + users)
docker exec -it oracle-xe sqlplus sys/oracle@//localhost:1521/FREEPDB1 as sysdba @/tmp/00_to_start.sql

# 3. Exécuter scripts Cergy
docker cp 01_setup_cergy.sql oracle-xe:/tmp/
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/01_setup_cergy.sql

# 4. Exécuter scripts Pau
docker cp 02_setup_pau.sql oracle-xe:/tmp/
docker exec -it oracle-xe sqlplus CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1 @/tmp/02_setup_pau.sql

# 5. Replication et objets cross-site
docker cp 03_replication.sql 04_role_gestion.sql oracle-xe:/tmp/
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/03_replication.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/04_role_gestion.sql

# 6. Index, triggers, data generation
docker cp 06_error_logging.sql 07_indexes.sql 08_triggers.sql 09_cursors_functions.sql 05_generate_data.sql oracle-xe:/tmp/
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/06_error_logging.sql
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/07_indexes.sql
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/08_triggers.sql
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/09_cursors_functions.sql
docker exec -it oracle-xe sqlplus CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1 @/tmp/05_generate_data.sql
```

---

## ✅ Vérification rapide

```sql
-- Connecté en CYTECH_CERGY@FREEPDB1
SELECT COUNT(*) as nb_tables FROM user_tables;        -- Doit retourner 10 ou plus
SELECT COUNT(*) as nb_sequences FROM user_sequences;  -- Doit retourner 10 ou plus
SELECT * FROM user_tables ORDER BY table_name;

-- Matérialized views
SELECT * FROM user_mviews;

-- Vérifier réplication : insérer une ligne SITE sur Cergy, puis vérifier sur Pau
BEGIN
  INSERT INTO SITE (site_name, site_location) VALUES ('TEST_SITE', 'Toulouse');
  COMMIT;
END;
/

-- Sur Pau : EXEC DBMS_MVIEW.REFRESH('MV_SITE'); puis SELECT * FROM MV_SITE;
```

---

## 📊 Architecture

- **Fragmentation:** Tables fragmentées par `site_id` (1 = Cergy, 2 = Pau)
- **Réplication:** Objets de référence (SITE, PERSON_ROLE, etc.) via MVs
- **Cross-site:** Procédures et triggers via DB links
- **Audits:** Triggers pour tracking, table `DEVICE_HISTORY`, view `V_ERROR_LOG_ALL`
- **Sécurité:** Rôles applicatifs, grants granulaires

---

## 📝 Notes techniques

- **PKG_REPLICATION :** flag de session pour éviter boucles infinies lors de la réplication
- **REFRESH ON DEMAND :** MVs ne se mettent à jour que sur ordre (voir `REFRESH_ALL_VIEWS`)
- **Séquences :** Cergy (100–1999), Pau (2000–9999)
- **Clusters :** `cl_device_periph*` sur (site_id, device_id) pour optimiser jointures locales
- **PL/SQL :** Fonctions age équipement, durée ticket, procédures rapports et nettoyage

---

## 👥 Contributeurs

- **Matias VINKOVIC**
- **Faïkidine AHMED**
- **Louaye SAGHIR**
- **Ayman OUGUERD**