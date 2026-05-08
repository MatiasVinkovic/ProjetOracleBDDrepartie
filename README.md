# ProjetOracleBDDrepartie
## CY Tech — Gestion du parc informatique (GLPI simplifié) — BDDR

Simulation d'une base Oracle répartie entre deux sites : **Cergy** et **Pau**.

---

## Architecture

| Schéma | Rôle |
|---|---|
| `CYTECH_CERGY` | Instance principale — héberge les vues fédérées |
| `CYTECH_PAU`   | Instance secondaire — reliée par DB Link |

**Fragmentation horizontale** : chaque site stocke uniquement ses propres données locales (bâtiments, salles, utilisateurs, assets, réseau) via une contrainte `CHECK (site_id = N)`.

**Référentiels** (SITE, APP_ROLE, ASSET_TYPE, ASSET_STATE, MANUFACTURER, OS_FAMILY, OS_VERSION, CPU_ARCH, ASSET_MODEL) : identiques sur les deux sites, insérés avec des IDs hardcodés. Toute modification doit être propagée manuellement sur les deux schémas.

---

## Fichiers

| Fichier | Contenu |
|---|---|
| `01_setup_cergy.sql` | Tablespaces, schéma, tables, cluster, index, données, DB link, vues fédérées |
| `02_setup_pau.sql`   | Idem pour Pau |
| `03_roles_grants.sql`| Rôles Oracle, privilèges, utilisateurs d'accès, synonymes publics |
| `TODO.md`            | Travaux PL/SQL à implémenter |

---

## Ordre d'exécution

### Prérequis
- Oracle XE (ou équivalent) avec deux PDBs ou deux schémas distincts sur la même instance.
- Adapter le nom de service dans les DB Links (`XEPDB1` par défaut).

### Étape 1 — Cergy (sections 1-2 en SYSDBA)
```sql
-- En tant que SYSDBA :
@01_setup_cergy.sql  -- sections 1 et 2 seulement (CREATE TABLESPACE / CREATE USER)
```

### Étape 2 — Cergy (sections 3+ en CYTECH_CERGY)
```sql
CONNECT CYTECH_CERGY/cergy2026@XEPDB1
-- Exécuter le reste du script 01 (séquences, tables, index, données, vues)
```

### Étape 3 — Pau (même principe)
```sql
-- En tant que SYSDBA :
@02_setup_pau.sql    -- sections 1 et 2

CONNECT CYTECH_PAU/pau2026@XEPDB1
-- Exécuter le reste du script 02
```

### Étape 4 — Rôles (SYSDBA)
```sql
@03_roles_grants.sql
```

### Étape 5 — Vérification
```sql
-- Connecté en ADMIN_CYTECH :
SELECT * FROM GLOBAL_ASSET;        -- doit retourner les assets Cergy + Pau
SELECT * FROM GLOBAL_NETWORK;
SELECT * FROM GLOBAL_ASSIGNMENT;
```

---

## Modèle de données simplifié

```
SITE
 └─ BUILDING ──── ROOM
                    └─ ASSET ─── ASSET_OS
                    │              └─ OS_VERSION ── OS_FAMILY
                    │              └─ CPU_ARCH
                    │
                    ├─ ASSET_ASSIGNMENT_HISTORY
                    ├─ ASSET_MOVEMENT
                    └─ ASSET_MODEL ── MANUFACTURER
                                   └─ ASSET_TYPE

APP_USER ── USER_ROLE ── APP_ROLE

VLAN ── NETWORK_SEGMENT ── IP_ADDRESS ──┐
                                        │ [CLUSTER CL_PORT_IP]
        ASSET ─────────── NETWORK_PORT ─┘
                               └─ PORT_VLAN ── VLAN
                               └─ PORT_LINK
```

---

## Règle IDs

| Espace | Plage |
|---|---|
| Référentiels (les deux sites) | 1 – 99 |
| Données locales Cergy         | 1 – 9 999 |
| Données locales Pau           | 10 001 + |
