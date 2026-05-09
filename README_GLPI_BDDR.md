# Mini-Projet GLPI — Base de Données Répartie (BDDR)
## ING2 — Bases de Données Avancées | CY Tech | 2025–2026

---

## Table des matières

1. [Présentation du projet](#1-présentation-du-projet)
2. [Architecture générale](#2-architecture-générale)
3. [Structure des schémas](#3-structure-des-schémas)
4. [Tables : répliquées vs fragmentées vs locales](#4-tables--répliquées-vs-fragmentées-vs-locales)
5. [Détail des tables](#5-détail-des-tables)
6. [Base de données répartie (BDDR)](#6-base-de-données-répartie-bddr)
7. [Sécurité : users, rôles, tablespaces](#7-sécurité--users-rôles-tablespaces)
8. [Vues](#8-vues)
9. [Index](#9-index)
10. [PL/SQL — Triggers de réplication](#10-plsql--triggers-de-réplication)
11. [Scripts fournis](#11-scripts-fournis)
12. [Ce qui est fait](#12-ce-qui-est-fait)
13. [Ce qu'il reste à faire](#13-ce-quil-reste-à-faire)
14. [Instructions d'installation](#14-instructions-dinstallation)

---

## 1. Présentation du projet

Ce projet repense une partie de la base de données de **GLPI** (Gestionnaire Libre de Parc Informatique) pour CY Tech, en prenant en compte l'aspect multi-sites (Cergy et Pau). L'objectif est de concevoir une architecture Oracle performante intégrant :

- Une **base de données répartie (BDDR)** avec fragmentation horizontale par site
- Une **gestion fine des accès** via users, rôles et tablespaces dédiés
- Des **optimisations** par index, clusters et plans de requêtes
- Du **PL/SQL** : triggers de réplication, procédures, fonctions et curseurs
- Des **vues** simplifiant l'accès aux données multi-sites

---

## 2. Architecture générale

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Oracle FREEPDB1                               │
│                                                                     │
│   ┌──────────────────────┐        ┌──────────────────────┐          │
│   │    CYTECH_CERGY       │        │     CYTECH_PAU        │          │
│   │  Schéma site Cergy    │        │  Schéma site Pau      │          │
│   │                      │        │                      │          │
│   │  13 tables           │◄──────►│  12 tables           │          │
│   │  1 DB link → PAU     │DB LINK │  1 DB link → CERGY   │          │
│   │  1 vue distante      │        │  1 vue distante      │          │
│   │  13 index functiels  │        │  12 index fonctionels│          │
│   │  MAINTENANCE_TICKET  │        │  V_CERGY_TICKET_MIN  │          │
│   └──────────────────────┘        └──────────────────────┘          │
│              ▲                               ▲                       │
│              │   GRANT SELECT/DML            │                       │
│              └─────────────┬─────────────────┘                       │
│                            │                                         │
│                   ┌────────▼────────┐                                │
│                   │  CYTECH_ADMIN   │                                │
│                   │  (user global)  │                                │
│                   │  CYTECH_ADMIN_ROLE                               │
│                   │  └ CYTECH_READER│                                │
│                   └─────────────────┘                                │
└─────────────────────────────────────────────────────────────────────┘
```

### Principe de la BDDR

La distribution repose sur la **fragmentation horizontale** par `site_id` :

```
Table DEVICE complète = CYTECH_CERGY.DEVICE (site_id=1)
                      ∪ CYTECH_PAU.DEVICE   (site_id=2)
```

Chaque site ne stocke que ses propres données locales, et peut interroger l'autre site via un **Database Link Oracle**.

---

## 3. Structure des schémas

### CYTECH_CERGY (site_id = 1)

| Élément | Détail |
|---|---|
| Tablespace données | `DATA_CERGY` |
| Tablespace index | `IDX_CERGY` |
| Tables | 13 (dont `MAINTENANCE_TICKET`) |
| Vues | `V_PAU_DEVICE_MIN` |
| DB Link | `LNK_PAU` → `CYTECH_PAU@FREEPDB1` |
| Index | 32 (PKs, UKs, index fonctionnels) |

### CYTECH_PAU (site_id = 2)

| Élément | Détail |
|---|---|
| Tablespace données | `DATA_PAU` |
| Tablespace index | `IDX_PAU` |
| Tables | 12 (sans `MAINTENANCE_TICKET`) |
| Vues | `V_CERGY_TICKET_MIN` |
| DB Link | `LNK_CERGY` → `CYTECH_CERGY@FREEPDB1` |
| Index | 30 (PKs, UKs, index fonctionnels) |

### CYTECH_ADMIN

| Élément | Détail |
|---|---|
| Tablespace | `USERS` (système, pas de stockage propre) |
| Tables | Aucune — accès via GRANT sur Cergy/Pau |
| Rôle | `CYTECH_ADMIN_ROLE` ⊇ `CYTECH_READER` |

---

## 4. Tables : répliquées vs fragmentées vs locales

```
┌────────────────────┬──────────────┬────────────┬─────────────────────────┐
│ Table              │ Type         │ Cergy      │ Pau                     │
├────────────────────┼──────────────┼────────────┼─────────────────────────┤
│ SITE               │ Répliquée    │ ✅ identique│ ✅ identique             │
│ PERSON_ROLE        │ Répliquée    │ ✅ identique│ ✅ identique             │
│ DEVICE_TYPE        │ Répliquée    │ ✅ identique│ ✅ identique             │
│ OS_FAMILY          │ Répliquée    │ ✅ identique│ ✅ identique             │
│ OS_VERSION         │ Répliquée    │ ✅ identique│ ✅ identique             │
│ PERIPHERAL_TYPE    │ Répliquée    │ ✅ identique│ ✅ identique             │
├────────────────────┼──────────────┼────────────┼─────────────────────────┤
│ BUILDING           │ Fragmentée H.│ site_id=1  │ site_id=2               │
│ ROOM               │ Fragmentée H.│ site_id=1  │ site_id=2               │
│ PERSON             │ Fragmentée H.│ site_id=1  │ site_id=2               │
│ DEVICE             │ Fragmentée H.│ site_id=1  │ site_id=2               │
│ PERIPHERAL         │ Fragmentée H.│ site_id=1  │ site_id=2               │
│ DEVICE_ASSIGNMENT  │ Fragmentée H.│ site_id=1  │ site_id=2               │
├────────────────────┼──────────────┼────────────┼─────────────────────────┤
│ MAINTENANCE_TICKET │ Locale Cergy │ ✅ présente │ ❌ absente (vue distante)│
└────────────────────┴──────────────┴────────────┴─────────────────────────┘
```

### Fragmentation horizontale

La fragmentation est garantie par des contraintes `CHECK` directement dans le DDL :

```sql
-- Sur CYTECH_CERGY
CONSTRAINT CK_DEVICE_SITE CHECK (site_id = 1)

-- Sur CYTECH_PAU
CONSTRAINT CK_DEVICE_SITE CHECK (site_id = 2)
```

Cette contrainte rend toute insertion de données d'un autre site impossible, garantissant l'intégrité de la fragmentation sans logique applicative.

### Tables répliquées

Les tables de référence ont **les mêmes lignes exactes** sur les deux sites. La cohérence est assurée (ou à assurer) par les triggers de réplication PL/SQL. Exemple pour `SITE` :

```
CYTECH_CERGY.SITE          CYTECH_PAU.SITE
─────────────────          ──────────────────
1 | CERGY | Cergy | Y  ==  1 | CERGY | Cergy | Y
2 | PAU   | Pau   | Y  ==  2 | PAU   | Pau   | Y
```

---

## 5. Détail des tables

### Modèle relationnel simplifié (Cergy, idem Pau sauf MAINTENANCE_TICKET)

```
SITE ──────────────────┐
                       │
PERSON_ROLE ───┐       │
               │       │
BUILDING ──────────────┤
    │                  │
ROOM ──────────────────┤
    │                  │
PERSON ──────────────SITE
    │
DEVICE ──────────────ROOM
    │    │            │
    │   OS_VERSION    │
    │    │            │
PERIPHERAL            │
    │                 │
PERIPHERAL_TYPE       │
                      │
DEVICE_ASSIGNMENT ────┘
    │
   DEVICE + PERSON

MAINTENANCE_TICKET ── DEVICE + PERSON (Cergy uniquement)
```

### Clés de conception

- Tous les IDs de Pau commencent à **1001** pour éviter les collisions de PK si les données sont un jour consolidées.
- La contrainte `CHECK (site_id = N)` garantit la fragmentation au niveau SGBD.
- `DEVICE_ASSIGNMENT` historise toutes les affectations avec `assigned_at` / `returned_at`.
- `MAINTENANCE_TICKET` gère le cycle de vie `OPEN → IN_PROGRESS → CLOSED`.

---

## 6. Base de données répartie (BDDR)

### Database Links

```sql
-- Depuis CYTECH_CERGY : accès à Pau
CREATE DATABASE LINK LNK_PAU
CONNECT TO CYTECH_PAU IDENTIFIED BY pau2026
USING '//localhost:1521/FREEPDB1';

-- Depuis CYTECH_PAU : accès à Cergy
CREATE DATABASE LINK LNK_CERGY
CONNECT TO CYTECH_CERGY IDENTIFIED BY cergy2026
USING '//localhost:1521/FREEPDB1';
```

### Vues distantes

Ces vues permettent à chaque site de consulter les données clés de l'autre, de façon transparente pour l'utilisateur :

```sql
-- Sur CYTECH_CERGY : voir les équipements de Pau
CREATE OR REPLACE VIEW V_PAU_DEVICE_MIN AS
SELECT device_id, asset_tag, device_name, device_status
FROM DEVICE@LNK_PAU;

-- Sur CYTECH_PAU : voir les tickets de maintenance de Cergy
CREATE OR REPLACE VIEW V_CERGY_TICKET_MIN AS
SELECT ticket_id, device_id, ticket_status, opened_at, closed_at
FROM MAINTENANCE_TICKET@LNK_CERGY;
```

### Requête transparente multi-sites (exemple)

```sql
-- Depuis CYTECH_CERGY : vue complète de tous les équipements des 2 sites
SELECT 'CERGY' AS site, asset_tag, device_name, device_status
FROM DEVICE
UNION ALL
SELECT 'PAU', asset_tag, device_name, device_status
FROM DEVICE@LNK_PAU
ORDER BY site, asset_tag;
```

---

## 7. Sécurité : users, rôles, tablespaces

### Utilisateurs Oracle

| User | Schéma | Tablespace | Rôle |
|---|---|---|---|
| `CYTECH_CERGY` | Site Cergy | `DATA_CERGY` / `IDX_CERGY` | Propriétaire |
| `CYTECH_PAU` | Site Pau | `DATA_PAU` / `IDX_PAU` | Propriétaire |
| `CYTECH_ADMIN` | Aucun (accès via GRANT) | `USERS` (système) | `CYTECH_ADMIN_ROLE` |

### Hiérarchie des rôles

```
CYTECH_ADMIN_ROLE
    │
    ├── CYTECH_READER
    │       ├── SELECT sur toutes les tables CYTECH_CERGY.*
    │       └── SELECT sur toutes les tables CYTECH_PAU.*
    │
    ├── INSERT, UPDATE, DELETE sur tables métier CYTECH_CERGY.*
    ├── INSERT, UPDATE, DELETE sur tables métier CYTECH_PAU.*
    └── INSERT, UPDATE (sans DELETE) sur tables de référence
```

Le choix de **refuser le DELETE sur les tables de référence** (`SITE`, `DEVICE_TYPE`, etc.) protège l'intégrité référentielle : on peut ajouter un type de device, mais pas supprimer un type utilisé par des équipements existants.

### Tablespaces

| Tablespace | Site | Taille initiale | Autoextend |
|---|---|---|---|
| `DATA_CERGY` | Cergy | 50 Mo | +10 Mo (max 500 Mo) |
| `IDX_CERGY` | Cergy | 20 Mo | +5 Mo (max 200 Mo) |
| `DATA_PAU` | Pau | 50 Mo | +10 Mo (max 500 Mo) |
| `IDX_PAU` | Pau | 20 Mo | +5 Mo (max 200 Mo) |

---

## 8. Vues

| Vue | Schéma | Description |
|---|---|---|
| `V_PAU_DEVICE_MIN` | CYTECH_CERGY | Équipements Pau vus depuis Cergy (via DB link) |
| `V_CERGY_TICKET_MIN` | CYTECH_PAU | Tickets Cergy vus depuis Pau (via DB link) |

### À créer (CYTECH_ADMIN)

Des vues globales consolidant les données des deux sites restent à créer, par exemple :

```sql
-- Vue globale consolidée (à créer sur CYTECH_ADMIN ou CYTECH_CERGY)
CREATE OR REPLACE VIEW V_GLOBAL_DEVICE AS
SELECT d.device_id, d.asset_tag, d.device_name, d.device_status,
       'CERGY' AS site
FROM CYTECH_CERGY.DEVICE d
UNION ALL
SELECT d.device_id, d.asset_tag, d.device_name, d.device_status,
       'PAU' AS site
FROM CYTECH_PAU.DEVICE d;
```

---

## 9. Index

Chaque table dispose d'index automatiques (PKs et UKs) plus des **index fonctionnels** sur les colonnes fréquemment filtrées :

| Index | Table | Colonne(s) | Objectif |
|---|---|---|---|
| `IDX_PERSON_ROLE` | PERSON | `role_id` | Filtres par rôle |
| `IDX_DEVICE_ROOM` | DEVICE | `room_id` | Jointures salle→équipement |
| `IDX_DEVICE_PERSON` | DEVICE | `assigned_person_id` | Équipements par personne |
| `IDX_DEVICE_TYPE` | DEVICE | `device_type_id` | Filtres par type |
| `IDX_PERIPHERAL_DEVICE` | PERIPHERAL | `assigned_device_id` | Périphériques par équipement |
| `IDX_ASSIGN_DEVICE` | DEVICE_ASSIGNMENT | `device_id` | Historique d'affectation |
| `IDX_TICKET_STATUS` | MAINTENANCE_TICKET | `ticket_status` | Tickets ouverts/en cours |

---

## 10. PL/SQL — Triggers de réplication

### Objectif

Garantir que les **tables répliquées** restent identiques sur les deux sites sans intervention manuelle. Toute modification sur `SITE`, `PERSON_ROLE`, etc. côté Cergy est automatiquement propagée vers Pau, et vice versa.

### Problème : boucle infinie

Sans garde, le trigger Cergy déclenche une écriture sur Pau → trigger Pau → écriture sur Cergy → trigger Cergy → boucle infinie. La solution est un **flag de session** via un package PL/SQL :

```
INSERT sur SITE (Cergy)
    → TRG_REPLICATE_SITE déclenché
    → flag g_replicating = TRUE
    → INSERT sur SITE@LNK_PAU
        → TRG_REPLICATE_SITE déclenché (Pau)
        → flag g_replicating = TRUE → rien ne se passe
    → flag g_replicating = FALSE
```

### Package de contrôle (à créer sur les 2 sites)

```sql
CREATE OR REPLACE PACKAGE PKG_REPLICATION AS
  g_replicating BOOLEAN := FALSE;
END PKG_REPLICATION;
/
```

### Trigger de réplication (exemple sur SITE, côté Cergy)

```sql
CREATE OR REPLACE TRIGGER TRG_REPLICATE_SITE
AFTER INSERT OR UPDATE OR DELETE ON SITE
FOR EACH ROW
BEGIN
  IF NOT PKG_REPLICATION.g_replicating THEN
    PKG_REPLICATION.g_replicating := TRUE;

    IF INSERTING THEN
      INSERT INTO SITE@LNK_PAU (site_id, site_code, site_name, city, is_active)
      VALUES (:NEW.site_id, :NEW.site_code, :NEW.site_name, :NEW.city, :NEW.is_active);

    ELSIF UPDATING THEN
      UPDATE SITE@LNK_PAU
      SET site_code = :NEW.site_code,
          site_name = :NEW.site_name,
          city      = :NEW.city,
          is_active = :NEW.is_active
      WHERE site_id = :OLD.site_id;

    ELSIF DELETING THEN
      DELETE FROM SITE@LNK_PAU WHERE site_id = :OLD.site_id;
    END IF;

    PKG_REPLICATION.g_replicating := FALSE;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    PKG_REPLICATION.g_replicating := FALSE;
    RAISE_APPLICATION_ERROR(-20001, 'Erreur réplication SITE : ' || SQLERRM);
END;
/
```

### Tables à couvrir

Ce trigger est à dupliquer (en version miroir) pour les 6 tables répliquées :

| Table | Trigger Cergy → Pau | Trigger Pau → Cergy |
|---|---|---|
| `SITE` | À créer | À créer |
| `PERSON_ROLE` | À créer | À créer |
| `DEVICE_TYPE` | À créer | À créer |
| `OS_FAMILY` | À créer | À créer |
| `OS_VERSION` | À créer | À créer |
| `PERIPHERAL_TYPE` | À créer | À créer |

---

## 11. Scripts fournis

| Fichier | Connexion requise | Contenu |
|---|---|---|
| `01_setup_cergy.sql` | `SYS AS SYSDBA` puis `CYTECH_CERGY` | Tablespaces, user, tables, index, données, DB link, vue |
| `02_setup_pau.sql` | `SYS AS SYSDBA` puis `CYTECH_PAU` | Idem pour Pau |
| `03_setup_admin.sql` | `SYS AS SYSDBA` dans `FREEPDB1` | Rôles `CYTECH_READER` et `CYTECH_ADMIN_ROLE`, user `CYTECH_ADMIN` |

---

## 12. Ce qui est fait

- [x] Modélisation complète du parc informatique (13 tables)
- [x] Fragmentation horizontale par `site_id` avec contraintes `CHECK`
- [x] 6 tables de référence répliquées avec mêmes données sur les 2 sites
- [x] 1 table locale exclusive à Cergy (`MAINTENANCE_TICKET`)
- [x] Tablespaces dédiés par site (`DATA_*`, `IDX_*`)
- [x] Users Oracle isolés par schéma (`CYTECH_CERGY`, `CYTECH_PAU`)
- [x] Database Links bidirectionnels (`LNK_PAU`, `LNK_CERGY`)
- [x] Vues distantes fonctionnelles (`V_PAU_DEVICE_MIN`, `V_CERGY_TICKET_MIN`)
- [x] Index fonctionnels sur colonnes de jointure et filtrage
- [x] User admin sans tablespace dédié (`CYTECH_ADMIN`)
- [x] Rôles hiérarchiques (`CYTECH_READER` ⊆ `CYTECH_ADMIN_ROLE`)
- [x] Données de test insérées sur les 2 sites
- [x] Vérification complète de l'installation (0 objet invalide, 0 pollution SYS)

---

## 13. Ce qu'il reste à faire

### Obligatoire (critères d'évaluation)

- [ ] **Triggers de réplication PL/SQL** : package `PKG_REPLICATION` + 6 paires de triggers (une par table répliquée, sur les 2 sites)
- [ ] **Génération d'un jeu de test conséquent** en PL/SQL (procédure qui insère N personnes, M équipements, K tickets de façon automatique avec `DBMS_RANDOM`)
- [ ] **Requêtes complexes de test de performance** : jointures multi-tables, requêtes distribuées avec `@LNK_*`, comparaison avec/sans index
- [ ] **Plan de requêtes** : `EXPLAIN PLAN FOR` + `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY)` sur les requêtes clés
- [ ] **Rapport** : reverse engineering GLPI, modélisation UML/schéma relationnel, résultats de performance avec graphiques

### Fortement recommandé

- [ ] **Vues globales consolidées** (`V_GLOBAL_DEVICE`, `V_GLOBAL_PERSON`) accessibles depuis `CYTECH_ADMIN`
- [ ] **Procédures PL/SQL** : ex. `PROC_TRANSFER_DEVICE(device_id, new_site_id)` pour déplacer un équipement d'un site à l'autre
- [ ] **Fonction PL/SQL** : ex. `FCT_COUNT_DEVICES_BY_SITE(site_id)` retournant le nombre d'équipements actifs
- [ ] **Curseur** : ex. rapport PL/SQL listant tous les équipements en réparation sur les 2 sites
- [ ] **Synonymes** sur `CYTECH_ADMIN` pour accéder à `CYTECH_CERGY.DEVICE` simplement via `DEVICE_CERGY`

### Optionnel (bonus)

- [ ] Cluster sur `DEVICE` et `PERIPHERAL` (co-localisation par `device_id`)
- [ ] Partitionnement par `device_status` ou `purchase_date`
- [ ] Trigger d'audit des modifications sur `DEVICE`

---

## 14. Instructions d'installation

### Prérequis

- Oracle Database 21c+ avec une PDB nommée `FREEPDB1`
- Accès `SYSDBA`
- SQL*Plus ou SQLcl installé

### Lancement

```bash
# 1. Script Cergy (crée tablespace, user, tables, données)
sqlplus / as sysdba
ALTER SESSION SET CONTAINER = FREEPDB1;
@/tmp/01_setup_cergy.sql

# 2. Script Pau (même structure, données Pau)
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = FREEPDB1;
@/tmp/02_setup_pau.sql

# 3. Script Admin (rôles et user global)
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = FREEPDB1;
@/tmp/03_setup_admin.sql
```

### Vérification rapide

```sql
-- En SYS dans FREEPDB1
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT username FROM dba_users
WHERE username IN ('CYTECH_CERGY','CYTECH_PAU','CYTECH_ADMIN');
-- Doit retourner 3 lignes

-- En CYTECH_CERGY
CONNECT CYTECH_CERGY/cergy2026@//localhost:1521/FREEPDB1
SELECT COUNT(*) FROM user_tables;        -- 13
SELECT * FROM V_PAU_DEVICE_MIN;          -- 4 équipements Pau

-- En CYTECH_PAU
CONNECT CYTECH_PAU/pau2026@//localhost:1521/FREEPDB1
SELECT COUNT(*) FROM user_tables;        -- 12
SELECT * FROM V_CERGY_TICKET_MIN;        -- 2 tickets Cergy
```

### Nettoyage complet (reset)

```sql
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = FREEPDB1;

DROP USER CYTECH_CERGY CASCADE;
DROP USER CYTECH_PAU CASCADE;
DROP USER CYTECH_ADMIN CASCADE;
DROP ROLE CYTECH_READER;
DROP ROLE CYTECH_ADMIN_ROLE;

-- En SYSDBA hors PDB pour les tablespaces
ALTER SESSION SET CONTAINER = CDB$ROOT;
DROP TABLESPACE DATA_CERGY INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE IDX_CERGY  INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE DATA_PAU   INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE IDX_PAU    INCLUDING CONTENTS AND DATAFILES;
```

---

*Date de rendu : dimanche 17 mai 2026 — Présentations : semaine du 18 mai 2026*
