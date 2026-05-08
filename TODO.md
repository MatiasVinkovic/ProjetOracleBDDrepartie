# TODO — PL/SQL & Tests de performance

Fichier de suivi pour les travaux restants (Étape 1 PL/SQL + Étape 2 validation).
À implémenter dans un fichier `04_plsql.sql` (ou découpé par thème).

---

## Triggers

- [ ] **TRG_ASSET_UPDATED_AT** (BEFORE UPDATE ON ASSET)
  - Met à jour `updated_at = SYSDATE` automatiquement sur chaque UPDATE.
  - À créer sur CYTECH_CERGY et CYTECH_PAU.

- [ ] **TRG_ASSET_AUDIT** (AFTER INSERT OR UPDATE OR DELETE ON ASSET)
  - Insère une ligne dans `AUDIT_LOG` avec : table_name, operation, record_id (asset_id), old_value / new_value (asset_tag + state_id).
  - Justifie l'existence du tablespace AUDIT et de la table AUDIT_LOG.

- [ ] **TRG_ASSIGN_CLOSE_PREVIOUS** (BEFORE INSERT ON ASSET_ASSIGNMENT_HISTORY)
  - Lors d'une nouvelle affectation, clôture automatiquement l'affectation courante ouverte (`returned_at = SYSDATE`) pour le même asset si elle existe.

---

## Procédures

- [ ] **PROC_ASSIGN_ASSET(p_asset_id, p_user_id, p_assigned_by, p_usage_type)**
  - Vérifie que l'asset est dans un état `is_assignable = 'Y'`.
  - Met à jour `ASSET.current_user_id` et `ASSET.state_id`.
  - Insère dans `ASSET_ASSIGNMENT_HISTORY`.
  - Gère les exceptions (asset inexistant, état non affectable, utilisateur inactif).

- [ ] **PROC_RETIRE_ASSET(p_asset_id, p_reason)**
  - Passe l'asset en état DISCARDED.
  - Clôture toute affectation ouverte.
  - Insère dans AUDIT_LOG.

- [ ] **PROC_GENERATE_TEST_DATA(p_nb_assets IN NUMBER)**
  - Génère `p_nb_assets` assets fictifs sur Cergy (et un appel symétrique pour Pau).
  - Utilise `FORALL` / `BULK COLLECT` pour les insertions en masse.
  - Génère aussi des ports réseau, IPs et affectations associées.
  - Objectif : jeu de test pour les mesures de performance (minimum 10 000 assets).

---

## Fonctions

- [ ] **FN_COUNT_ASSETS(p_site_id, p_state_code) RETURN NUMBER**
  - Retourne le nombre d'assets actifs (non supprimés) pour un site et un état donnés.

- [ ] **FN_WARRANTY_STATUS(p_asset_id) RETURN VARCHAR2**
  - Retourne 'OK', 'EXPIRING_SOON' (< 90 jours) ou 'EXPIRED' selon `warranty_end`.

- [ ] **FN_IS_IP_AVAILABLE(p_ip_value) RETURN CHAR**
  - Vérifie si une adresse IP est libre dans la table IP_ADDRESS (allocation_status = 'FREE' ou absente).

---

## Curseurs (à intégrer dans une procédure ou un bloc anonyme)

- [ ] **CUR_EXPIRED_WARRANTIES**
  - Parcourt tous les assets dont `warranty_end < SYSDATE` et génère un rapport (DBMS_OUTPUT).

- [ ] **CUR_UNASSIGNED_ASSETS**
  - Liste les assets en état IN_USE sans `current_user_id` (incohérence de données).

---

## Vues supplémentaires utiles

- [ ] **V_ASSET_WARRANTY_STATUS** — assets avec colonne calculée OK/EXPIRING_SOON/EXPIRED (appelle FN_WARRANTY_STATUS ou expression CASE directe).
- [ ] **V_USER_ASSETS** — liste des assets actuellement affectés par utilisateur (jointure ASSET + APP_USER).
- [ ] **V_NETWORK_MAP** — vue plate : asset_tag, ip_value, mac_address, vlan_name, cidr_block pour tous les assets avec port réseau.

---

## Tests de performance (Étape 2)

- [ ] Générer le jeu de données via `PROC_GENERATE_TEST_DATA` (10 000+ assets par site).
- [ ] Mesurer les requêtes suivantes **avant** et **après** les index :
  - Tous les assets EN_USE d'un site donné (→ IDX_ASSET_SITE_STATE)
  - Tous les assets d'un modèle donné (→ IDX_ASSET_MODEL)
  - Historique d'affectation d'un asset (→ IDX_ASSIGN_ASSET)
  - JOIN NETWORK_PORT / IP_ADDRESS (→ cluster CL_PORT_IP vs tables non clusterisées)
- [ ] Utiliser `EXPLAIN PLAN FOR ...` + `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY)` pour chaque requête.
- [ ] Comparer les plans : Full Table Scan vs Index Range Scan vs Cluster Scan.
- [ ] Documenter les résultats dans le rapport (tableaux + captures EXPLAIN PLAN).

---

## Plan de requêtes à documenter (pour le rapport)

```sql
-- Exemple de structure à utiliser :
EXPLAIN PLAN FOR
  SELECT a.asset_tag, u.login, st.state_label
  FROM   CYTECH_CERGY.ASSET a
  JOIN   CYTECH_CERGY.APP_USER   u  ON u.user_id  = a.current_user_id
  JOIN   CYTECH_CERGY.ASSET_STATE st ON st.state_id = a.state_id
  WHERE  a.site_id = 1 AND a.state_id = 1 AND a.is_deleted = 'N';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

---

## Notes architecture

- Les référentiels (SITE, APP_ROLE, etc.) sont répliqués manuellement. Pour une vraie BDDR, envisager Oracle Advanced Replication ou Streams. Dans le cadre du projet, la réplication manuelle est suffisante.
- Les DB Links `LNK_PAU` / `LNK_CERGY` utilisent `USING 'XEPDB1'` — adapter au service Oracle réel de chaque instance.
- Le cluster `CL_PORT_IP` n'est pertinent qu'à partir de quelques milliers de ports — le démontrer dans les tests de performance.
