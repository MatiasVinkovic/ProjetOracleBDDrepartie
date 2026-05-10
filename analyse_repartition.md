# Analyse de la répartition des données
*ProjetOracleBDDrepartie — analyse depuis les scripts*

---

## 1. Ce qui existe — lecture brute des scripts

### Tables locales (correctes, rien à changer)

| Table | Cergy | Pau | Rôle |
|---|---|---|---|
| BUILDING | site_id=1 | site_id=2 | Bâtiments du campus |
| ROOM | via BUILDING | via BUILDING | Salles |
| PERSON | site_id=1 | site_id=2 | Personnel du campus |
| DEVICE | site_id=1 | site_id=2 | Équipements du campus |
| PERIPHERAL | site_id=1 | site_id=2 | Périphériques du campus |
| DEVICE_ASSIGNMENT | locale | locale | Historique d'affectation |
| MAINTENANCE_TICKET | Cergy only | — (vue distante) | Tickets d'intervention |

Ces tables appartiennent à leur site. Chaque site lit et écrit ses propres données. C'est correct — sauf un point.

### MAINTENANCE_TICKET — lacune fonctionnelle

`MAINTENANCE_TICKET` existe uniquement sur Cergy avec `CHECK (site_id = 1)` et une FK vers la table `DEVICE` locale. Concrètement : il est impossible de créer un ticket pour un device Pau. `site_id = 2` est interdit par la contrainte, et `FK_TICKET_DEVICE` ne peut référencer que des device_id présents dans le schéma Cergy.

Pour un système de gestion IT censé couvrir les deux campus, c'est une lacune fonctionnelle directe.

**Correction** : élargir le CHECK à `IN (1, 2)`, supprimer `FK_TICKET_DEVICE` (on ne peut pas FK vers un device distant), et passer par `PROC_CREATE_TICKET` qui valide l'existence du device sur le bon site via DB link avant d'insérer.

### Tables "de référence" — là où est le problème

| Table | Lignes | Qui peut la modifier ? | Fréquence de changement |
|---|---|---|---|
| SITE | 2 | DSI Cergy uniquement | Jamais (2 campus fixes) |
| PERSON_ROLE | 4 | DSI Cergy | Très rare — les 4 rôles ne bougent pas |
| DEVICE_TYPE | 3 | DSI Cergy | Très rare — 3 types de matériel |
| PERIPHERAL_TYPE | 5 | DSI Cergy | Très rare — 5 types de périphériques |
| OS_FAMILY | 4 | DSI Cergy | Rare — nouveau constructeur = exceptionnel |
| OS_VERSION | 4 | DSI Cergy | Quelques fois par an (nouvelles versions OS) |

Toutes ces tables sont actuellement répliquées sur les deux sites avec **12 triggers bidirectionnels** qui se déclenchent à chaque DML.

---

## 2. Le problème — mauvaise granularité de répartition

### Ce que fait le script 04 aujourd'hui

```
INSERT INTO OS_FAMILY (Cergy)
    → trigger TRG_REP_OS_FAMILY se déclenche
    → appelle set_replicating@LNK_PAU(TRUE)
    → INSERT INTO OS_FAMILY@LNK_PAU
    → set_replicating@LNK_PAU(FALSE)

En même temps, si quelqu'un touche quoi que ce soit à Pau
    → TRG_REP_*@PAU se déclenche
    → tente d'appeler LNK_CERGY
    → DEADLOCK possible
```

C'est de la synchronisation **temps-réel** pour des données qui changent **quelques fois par an**. Le coût du mécanisme (complexité, risque, debugging) est sans commune mesure avec le besoin réel.

### Le problème de fond : tout le monde co-possède tout

Avec 12 triggers bidirectionnels, les deux sites sont traités comme co-propriétaires de toutes les tables de référence. Mais ça n't a pas de sens : on peut se dire que **Pau ne décide pas quels OS existent dans le système.** C'est Cergy (sous-entendu le siège), qui gère le référentiel logiciel. Pau subit cette décision ou a des patchs locaux.

La bidirectionnalité n'est pas une propriété fonctionnelle — c'est une erreur de conception.

---

## 3. Analyse table par table — que faut-il vraiment à Pau ?

### SITE — 2 lignes, jamais modifiées

Pau en a besoin uniquement pour la contrainte FK sur BUILDING, PERSON, DEVICE, PERIPHERAL. Mais ces tables ont toutes un `CHECK (site_id = 2)` — la valeur est fixe. La FK vérifie juste que site_id=2 existe dans SITE, ce qui est vrai depuis le setup et le restera toujours.

**Conclusion** : données statiques insérées au setup, aucun trigger nécessaire. Si un 3ème campus ouvre dans 10 ans, l'admin fait un INSERT manuel. Supprimer les 2 triggers SITE.

### PERSON_ROLE, DEVICE_TYPE, PERIPHERAL_TYPE — peu de lignes, très rarement modifiées

Pau en a besoin **localement** pour les JOINs quotidiens :
```sql
SELECT p.last_name, pr.role_label FROM PERSON p JOIN PERSON_ROLE pr ON ...
SELECT d.device_name, dt.type_label FROM DEVICE d JOIN DEVICE_TYPE dt ON ...
```
Ces jointures se font des dizaines de fois par jour. Avoir ces 3 tables localement est justifié.

**Mais** : elles ne changent pas. Les 4 rôles et 3 types de device sont fixés depuis le setup. Un trigger temps-réel pour ça est absurde.

**Conclusion** : garder les tables locales (FK + JOINs quotidiens), supprimer les 6 triggers. Si jamais un nouveau rôle est ajouté, l'admin Cergy lance un INSERT manuel des deux côtés. Ça arrivera peut-être une fois en 5 ans.

### OS_FAMILY + OS_VERSION — candidats à la vue matérialisée

Ces deux tables sont différentes des autres : elles changent plus souvent (nouvelles versions d'OS) ET **Pau n'en a pas un besoin opérationnel critique**.

Ce que Pau fait avec OS_VERSION : afficher "Windows 11" dans un rapport ou une interface. Ce n'est pas une donnée dont Pau a besoin à la milliseconde pour faire son travail quotidien. Un technicien qui déplace un device d'une salle à une autre n'a pas besoin de savoir que Windows 11 s'appelle "Windows 11".

**Cergy est l'autorité logicielle.** Quand l'école décide de passer à Windows 12, c'est le DSI de Cergy qui enregistre ça. Pau le saura quand ça se mettra à jour.

**Conclusion** : supprimer les 4 triggers. Sur Pau :
- Supprimer les tables OS_FAMILY et OS_VERSION
- Supprimer la FK `FK_DEVICE_OS` sur DEVICE (Oracle n'autorise pas de FK vers une vue matérialisée)
- Créer des **vues matérialisées ON DEMAND** depuis Cergy
- Les rapports Pau qui veulent l'info OS joignent avec la MV

---

## 4. Architecture cible

```
╔══════════════════════════════════════════════════════════╗
║  CYTECH_CERGY — siège, autorité logicielle               ║
║                                                          ║
║  Référentiel (propriétaire, modifié par DSI)             ║
║  SITE · PERSON_ROLE · DEVICE_TYPE                        ║
║  PERIPHERAL_TYPE · OS_FAMILY · OS_VERSION                ║
║                                                          ║
║  Données locales Cergy                                   ║
║  BUILDING · ROOM · PERSON · DEVICE                       ║
║  PERIPHERAL · DEVICE_ASSIGNMENT · MAINTENANCE_TICKET     ║
╚════════════════════╤═════════════════════════════════════╝
                     │
       ┌─────────────┴──────────────────────┐
       │ MV refresh ON DEMAND               │ DB link (lecture)
       │ (quand un nouvel OS sort)           │ V_CERGY_TICKET_MIN
       ▼                                    ▼
╔══════════════════════════════════════════════════════════╗
║  CYTECH_PAU — site opérationnel                          ║
║                                                          ║
║  Référentiel local STATIQUE (seeded au setup)            ║
║  SITE · PERSON_ROLE · DEVICE_TYPE · PERIPHERAL_TYPE      ║
║  → pas de triggers, pas de réplication temps-réel        ║
║  → INSERT manuel si jamais un rôle ou type change        ║
║                                                          ║
║  Vues matérialisées ON DEMAND (depuis Cergy)             ║
║  MV_OS_FAMILY ←── REFRESH ──── OS_FAMILY@LNK_CERGY      ║
║  MV_OS_VERSION ←── REFRESH ─── OS_VERSION@LNK_CERGY     ║
║  → FK_DEVICE_OS supprimée sur DEVICE                     ║
║  → jointures OS dans les rapports utilisent la MV        ║
║                                                          ║
║  Données locales Pau                                     ║
║  BUILDING · ROOM · PERSON · DEVICE                       ║
║  PERIPHERAL · DEVICE_ASSIGNMENT                          ║
╚══════════════════════════════════════════════════════════╝
```

---

## 5. Ce qui change concrètement

### 04_replication.sql
Supprimer :
- `PKG_REPLICATION` sur les deux sites
- Les 12 triggers (6 Cergy→Pau, 6 Pau→Cergy)

### 02_setup_pau.sql
Supprimer :
- `CREATE TABLE OS_FAMILY` et `CREATE TABLE OS_VERSION`
- Les `INSERT INTO OS_FAMILY` et `INSERT INTO OS_VERSION`
- La contrainte `FK_DEVICE_OS` dans `CREATE TABLE DEVICE`

Ajouter (après le DB link LNK_CERGY) :
```sql
-- Vues matérialisées OS depuis Cergy (refresh à la demande)
CREATE MATERIALIZED VIEW MV_OS_FAMILY
  REFRESH ON DEMAND
AS SELECT os_family_id, family_name FROM OS_FAMILY@LNK_CERGY;

CREATE MATERIALIZED VIEW MV_OS_VERSION
  REFRESH ON DEMAND
AS SELECT os_version_id, os_family_id, version_label FROM OS_VERSION@LNK_CERGY;
```

Refresh déclenché par l'admin Pau (ou Cergy via DB link) quand un nouvel OS sort :
```sql
EXEC DBMS_MVIEW.REFRESH('MV_OS_FAMILY');
EXEC DBMS_MVIEW.REFRESH('MV_OS_VERSION');
```

### 01_setup_cergy.sql
Rien à changer.

### Rapports Pau qui veulent l'info OS
Remplacer `JOIN OS_VERSION ov` par `JOIN MV_OS_VERSION ov` dans les requêtes de rapport.

---

## 6. Bilan

| | Avant | Après |
|---|---|---|
| Triggers de réplication | 12 | 0 |
| Packages PKG_REPLICATION | 2 | 0 |
| Risque de deadlock sur référentiel | Oui | Non |
| SITE, PERSON_ROLE, DEVICE_TYPE, PERIPHERAL_TYPE sur Pau | Copies répliquées | Copies statiques (seeded) |
| OS_FAMILY, OS_VERSION sur Pau | Copies répliquées (triggers) | Vues matérialisées ON DEMAND |
| FK OS_VERSION sur DEVICE (Pau) | Présente | Supprimée (MV non référençable) |
| Données locales BUILDING/ROOM/PERSON/DEVICE | Inchangées | Inchangées |
| Info OS dans rapports Pau | JOIN OS_VERSION | JOIN MV_OS_VERSION |
| Mise à jour référentiel OS | Automatique à chaque DML | Refresh explicite quand un OS sort |
