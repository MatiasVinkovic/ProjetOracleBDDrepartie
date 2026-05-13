# Référentiel des rôles et utilisateurs

## Vue d'ensemble

Le projet repose sur deux schémas principaux, `CYTECH_CERGY` et `CYTECH_PAU`, qui possèdent les objets applicatifs de chaque site, notamment les tables, vues, séquences et procédures créées dans les scripts de setup.[file:2][file:3] Les rôles fonctionnels sont définis dans le script de gestion des droits, avec trois niveaux par site : `READ`, `MANAGER` et `ADMIN`, organisés de manière hiérarchique.[file:4]

Les utilisateurs de test ne remplacent pas les schémas principaux : ils servent à vérifier que les permissions métiers sont bien appliquées, tandis que `CYTECH_CERGY` et `CYTECH_PAU` restent les propriétaires fonctionnels et techniques des objets.[file:2][file:3][file:4] En Oracle, le tablespace par défaut d'un utilisateur sert à définir où ses objets seraient stockés s'il en créait, mais il ne donne pas à lui seul l'accès aux tables ou aux vues d'un autre schéma.[web:23][web:25]

## Architecture des comptes

| Élément | Rôle dans le projet | Détient les objets ? | Utilisation principale |
|---|---|---|---|
| `CYTECH_CERGY` | Schéma principal du site Cergy | Oui, pour les objets Cergy.[file:2] | Création et administration des objets Cergy.[file:2][file:4] |
| `CYTECH_PAU` | Schéma principal du site Pau | Oui, pour les objets Pau.[file:3] | Création et administration des objets Pau.[file:3][file:4] |
| `U_CERGY_READ` | Utilisateur de test Cergy | Non.[file:4] | Vérifier les droits de lecture.[file:4] |
| `U_CERGY_MANAGER` | Utilisateur de test Cergy | Non.[file:4] | Vérifier les droits d'insertion et de mise à jour.[file:4] |
| `U_CERGY_ADMIN` | Utilisateur de test Cergy | Non.[file:4] | Vérifier les droits d'administration locale.[file:4] |
| `U_PAU_READ` | Utilisateur de test Pau | Non.[file:4] | Vérifier les droits de lecture.[file:4] |
| `U_PAU_MANAGER` | Utilisateur de test Pau | Non.[file:4] | Vérifier les droits d'insertion et de mise à jour.[file:4] |
| `U_PAU_ADMIN` | Utilisateur de test Pau | Non.[file:4] | Vérifier les droits d'administration locale.[file:4] |

Les utilisateurs de test peuvent être créés avec `DATA_CERGY` ou `DATA_PAU` comme tablespace par défaut selon leur site logique, ce qui garde une structure cohérente avec l'organisation du projet.[file:2][file:3][web:23] Cela ne change pas le fait qu'ils accèdent aux objets via les rôles attribués et, sans synonyme ni changement de schéma courant, en qualifiant les objets avec `CYTECH_CERGY.` ou `CYTECH_PAU.`.[web:15][web:50]

## Hiérarchie des rôles

Le modèle de sécurité prévoit six rôles applicatifs : `R_CERGY_READ`, `R_CERGY_MANAGER`, `R_CERGY_ADMIN`, `R_PAU_READ`, `R_PAU_MANAGER` et `R_PAU_ADMIN`.[file:4] La hiérarchie est définie par héritage, avec `READ -> MANAGER -> ADMIN` pour chaque site, ce qui signifie qu'un rôle supérieur hérite des droits du rôle inférieur du même site.[file:4]

| Site | Rôle | Hérite de | Finalité |
|---|---|---|---|
| Cergy | `R_CERGY_READ` | Aucun.[file:4] | Consultation des objets autorisés.[file:4] |
| Cergy | `R_CERGY_MANAGER` | `R_CERGY_READ`.[file:4] | Gestion locale des données opérationnelles.[file:4] |
| Cergy | `R_CERGY_ADMIN` | `R_CERGY_MANAGER`.[file:4] | Administration locale et suppressions.[file:4] |
| Pau | `R_PAU_READ` | Aucun.[file:4] | Consultation des objets autorisés.[file:4] |
| Pau | `R_PAU_MANAGER` | `R_PAU_READ`.[file:4] | Gestion locale des données opérationnelles.[file:4] |
| Pau | `R_PAU_ADMIN` | `R_PAU_MANAGER`.[file:4] | Administration locale et suppressions.[file:4] |

## Droits côté Cergy

Le rôle `R_CERGY_READ` possède les droits `SELECT` sur les tables de référence locales, les tables opérationnelles locales, certaines vues locales et certains objets répliqués ou matérialisés, notamment `DEVICE_TYPE`, `OS_FAMILY`, `OS_VERSION`, `PERIPHERAL_TYPE`, `BUILDING`, `ROOM`, `PERSON`, `VLAN`, `NETWORK_SWITCH`, `DEVICE`, `PERIPHERAL`, `DEVICE_ASSIGNMENT`, `MAINTENANCE_TICKET`, `V_NETWORK_TOPOLOGY`, `V_ACTIVE_TICKETS`, `MV_SITE`, `MV_PERSON_ROLE` et `V_PAU_DEVICE_MIN`.[file:4] Cela signifie que les trois utilisateurs Cergy peuvent tous consulter ces objets, puisque `MANAGER` et `ADMIN` héritent de `READ`.[file:4]

Le rôle `R_CERGY_MANAGER` ajoute des droits `INSERT` et `UPDATE` sur les objets locaux de gestion comme `BUILDING`, `ROOM`, `PERSON`, `VLAN`, `NETWORK_SWITCH`, `DEVICE`, `PERIPHERAL`, `DEVICE_ASSIGNMENT` et `MAINTENANCE_TICKET`.[file:4] Il possède aussi `SELECT` sur `SEQ_PERSON_CERGY`, `SEQ_DEVICE_CERGY`, `SEQ_PERIPH_CERGY` et `SEQ_TICKET_ID`, ainsi que `EXECUTE` sur `PROC_CREATE_TICKET`.[file:2][file:4]

Le rôle `R_CERGY_ADMIN` ajoute enfin les droits `INSERT`, `UPDATE`, `DELETE` sur les tables de référence propriétaires de Cergy, à savoir `DEVICE_TYPE`, `OS_FAMILY`, `OS_VERSION` et `PERIPHERAL_TYPE`, ainsi que `DELETE` sur les principales tables locales du site.[file:4] Ce rôle permet donc la gestion complète des données Cergy dans le périmètre prévu par le projet.[file:4]

### Matrice Cergy

| Objet Cergy | READ | MANAGER | ADMIN |
|---|---|---|---|
| Tables de référence locales (`DEVICE_TYPE`, `OS_FAMILY`, `OS_VERSION`, `PERIPHERAL_TYPE`) | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] | `INSERT`, `UPDATE`, `DELETE` + héritage `SELECT`.[file:4] |
| Tables métier locales (`BUILDING`, `ROOM`, `PERSON`, `VLAN`, `NETWORK_SWITCH`, `DEVICE`, `PERIPHERAL`, `DEVICE_ASSIGNMENT`, `MAINTENANCE_TICKET`) | `SELECT`.[file:4] | `INSERT`, `UPDATE` + héritage `SELECT`.[file:4] | `DELETE` + héritage complet `READ` et `MANAGER`.[file:4] |
| Vues (`V_NETWORK_TOPOLOGY`, `V_ACTIVE_TICKETS`, `V_PAU_DEVICE_MIN`) | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] |
| Objets répliqués (`MV_SITE`, `MV_PERSON_ROLE`) | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] |
| Séquences (`SEQ_PERSON_CERGY`, `SEQ_DEVICE_CERGY`, `SEQ_PERIPH_CERGY`, `SEQ_TICKET_ID`) | Aucun droit explicite.[file:4] | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] |
| Procédure `PROC_CREATE_TICKET` | Aucun droit explicite.[file:4] | `EXECUTE`.[file:4] | Hérite de `EXECUTE`.[file:4] |

## Droits côté Pau

Le rôle `R_PAU_READ` possède les droits `SELECT` sur `SITE`, `PERSON_ROLE`, `BUILDING`, `ROOM`, `PERSON`, `VLAN`, `NETWORK_SWITCH`, `DEVICE`, `PERIPHERAL`, `DEVICE_ASSIGNMENT`, `V_NETWORK_TOPOLOGY`, `MV_DEVICE_TYPE`, `MV_PERIPHERAL_TYPE`, `MV_OS_FAMILY`, `MV_OS_VERSION` et `V_CERGY_TICKET_MIN`.[file:4] Comme pour Cergy, les rôles `MANAGER` et `ADMIN` de Pau héritent de ces droits de lecture.[file:4]

Le rôle `R_PAU_MANAGER` ajoute `INSERT` et `UPDATE` sur `BUILDING`, `ROOM`, `PERSON`, `VLAN`, `NETWORK_SWITCH`, `DEVICE`, `PERIPHERAL` et `DEVICE_ASSIGNMENT`.[file:4] Il reçoit aussi `SELECT` sur `SEQ_PERSON_PAU`, `SEQ_DEVICE_PAU` et `SEQ_PERIPH_PAU`, ainsi que `EXECUTE` sur `PROC_OPEN_TICKET_PAU`.[file:3][file:4]

Le rôle `R_PAU_ADMIN` ajoute `INSERT`, `UPDATE`, `DELETE` sur `SITE` et `PERSON_ROLE`, qui sont les tables de référence propriétaires de Pau, ainsi que `DELETE` sur les tables locales du site.[file:3][file:4] Cela correspond au partage de responsabilités décrit dans les scripts de setup, où Pau possède `SITE` et `PERSON_ROLE`, tandis que Cergy possède les types d'équipements et versions d'OS.[file:2][file:3]

### Matrice Pau

| Objet Pau | READ | MANAGER | ADMIN |
|---|---|---|---|
| Tables de référence locales (`SITE`, `PERSON_ROLE`) | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] | `INSERT`, `UPDATE`, `DELETE` + héritage `SELECT`.[file:4] |
| Tables métier locales (`BUILDING`, `ROOM`, `PERSON`, `VLAN`, `NETWORK_SWITCH`, `DEVICE`, `PERIPHERAL`, `DEVICE_ASSIGNMENT`) | `SELECT`.[file:4] | `INSERT`, `UPDATE` + héritage `SELECT`.[file:4] | `DELETE` + héritage complet `READ` et `MANAGER`.[file:4] |
| Vues et objets répliqués (`V_NETWORK_TOPOLOGY`, `MV_DEVICE_TYPE`, `MV_PERIPHERAL_TYPE`, `MV_OS_FAMILY`, `MV_OS_VERSION`, `V_CERGY_TICKET_MIN`) | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] |
| Séquences (`SEQ_PERSON_PAU`, `SEQ_DEVICE_PAU`, `SEQ_PERIPH_PAU`) | Aucun droit explicite.[file:4] | `SELECT`.[file:4] | Hérite du `SELECT`.[file:4] |
| Procédure `PROC_OPEN_TICKET_PAU` | Aucun droit explicite.[file:4] | `EXECUTE`.[file:4] | Hérite de `EXECUTE`.[file:4] |

## Ce que voient les utilisateurs

Les utilisateurs `U_CERGY_READ`, `U_CERGY_MANAGER` et `U_CERGY_ADMIN` accèdent aux objets du schéma `CYTECH_CERGY` via les rôles qui leur sont attribués, mais ils n'en deviennent pas propriétaires.[file:2][file:4] Par défaut, sans synonyme privé ni `ALTER SESSION SET CURRENT_SCHEMA`, ils doivent viser les objets avec leur nom qualifié, par exemple `CYTECH_CERGY.DEVICE` ou `CYTECH_CERGY.V_NETWORK_TOPOLOGY`.[web:15][web:50]

Les utilisateurs `U_PAU_READ`, `U_PAU_MANAGER` et `U_PAU_ADMIN` suivent la même logique avec le schéma `CYTECH_PAU`.[file:3][file:4] Les vues sont déjà gérées dans le référentiel de rôles, car les `GRANT SELECT` ont été posés explicitement sur les vues et vues matérialisées concernées.[file:4][web:63]

## Répartition synthétique par utilisateur

| Utilisateur | Site logique | Rôle attribué | Peut lire les tables locales | Peut lire les vues autorisées | Peut insérer / modifier | Peut supprimer | Peut exécuter la procédure locale |
|---|---|---|---|---|---|---|---|
| `U_CERGY_READ` | Cergy | `R_CERGY_READ`.[file:4] | Oui.[file:4] | Oui.[file:4] | Non.[file:4] | Non.[file:4] | Non.[file:4] |
| `U_CERGY_MANAGER` | Cergy | `R_CERGY_MANAGER`.[file:4] | Oui.[file:4] | Oui.[file:4] | Oui, sur les objets de gestion locale.[file:4] | Non.[file:4] | Oui, `PROC_CREATE_TICKET`.[file:4] |
| `U_CERGY_ADMIN` | Cergy | `R_CERGY_ADMIN`.[file:4] | Oui.[file:4] | Oui.[file:4] | Oui.[file:4] | Oui, dans le périmètre prévu.[file:4] | Oui par héritage.[file:4] |
| `U_PAU_READ` | Pau | `R_PAU_READ`.[file:4] | Oui.[file:4] | Oui.[file:4] | Non.[file:4] | Non.[file:4] | Non.[file:4] |
| `U_PAU_MANAGER` | Pau | `R_PAU_MANAGER`.[file:4] | Oui.[file:4] | Oui.[file:4] | Oui, sur les objets de gestion locale.[file:4] | Non.[file:4] | Oui, `PROC_OPEN_TICKET_PAU`.[file:4] |
| `U_PAU_ADMIN` | Pau | `R_PAU_ADMIN`.[file:4] | Oui.[file:4] | Oui.[file:4] | Oui.[file:4] | Oui, dans le périmètre prévu.[file:4] | Oui par héritage.[file:4] |

## Vérifications recommandées

Pour vérifier techniquement la configuration, il est pertinent d'interroger `DBA_ROLES`, `DBA_ROLE_PRIVS` et `DBA_TAB_PRIVS` après exécution du script de gestion des rôles, car ces vues système permettent de confirmer l'existence des rôles, leur attribution aux utilisateurs et les privilèges objets réellement accordés.[web:15] Les tests fonctionnels les plus parlants consistent ensuite à se connecter avec un compte `READ`, `MANAGER` puis `ADMIN` et à vérifier qu'un `SELECT` fonctionne, qu'un `INSERT` ou `UPDATE` n'est autorisé que pour `MANAGER` et plus, et qu'un `DELETE` n'est autorisé que pour `ADMIN` sur le périmètre prévu.[file:4]

## Points d'attention

Le référentiel de rôles couvre uniquement les objets explicitement mentionnés dans le script de gestion des droits, donc toute nouvelle vue, séquence, procédure ou table ajoutée plus tard devra recevoir de nouveaux `GRANT` si elle doit être accessible aux utilisateurs de test.[file:4] Un synonyme peut simplifier l'écriture des requêtes, mais il ne remplace jamais les privilèges Oracle sur l'objet cible.[web:50][web:53]
