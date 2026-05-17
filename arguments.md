# Pourquoi on a ajouté ça

Notes pour préparer la soutenance et les questions du jury. On reste sur du factuel, court, défendable.

## 1. La table ERROR_LOG (06)

**Idée :** une petite table par site qui garde une trace des erreurs métier (et de quelques événements "alerte" type ticket en retard).

**Pourquoi :** sans ça, quand une procédure ou un trigger lève une `raise_application_error`, l'erreur remonte à l'appelant et c'est tout. Aucune trace dans la base. Pour un GLPI on veut au moins savoir ce qui a planté.

**Pattern du TP7 :** c'est exactement le mécanisme de `ligne_erreur` du TP7. On a une procédure `proc_log_error` qui pose une ligne, et on l'appelle depuis les triggers avant le `raise_application_error`. Rien d'exotique.

**Le seul point un peu subtil :** la procédure est en `PRAGMA AUTONOMOUS_TRANSACTION` — c'est le mot-clé vu en TP7. Ça veut dire que l'`INSERT` dans ERROR_LOG se fait dans une mini-transaction séparée. Si la transaction parente fait `ROLLBACK` (parce qu'on a `raise`), le log reste quand même. Sans ça on perdrait justement les traces qu'on veut garder.

**Une par site (pas centralisée) :** Cergy a sa table, Pau a la sienne. On ne dépend pas du DB link au moment où on écrit le log. Pour la consultation, on a quand même une vue `V_ERROR_LOG_ALL` côté Cergy qui fait `UNION ALL` avec `ERROR_LOG@LNK_PAU` — comme ça depuis Cergy on voit les 2 sites d'un coup.

## 2. Les index ajoutés (07)

**Idée :** la plupart des FK du projet n'ont pas d'index explicite. Or quand on fait une jointure du genre `SELECT ... FROM DEVICE d JOIN PERSON p ON d.assigned_person_id = p.person_id`, sans index sur `assigned_person_id`, Oracle fait un FULL SCAN.

**Ce qu'on ajoute :**
- Index sur les FK des tables `DEVICE`, `PERIPHERAL`, `MAINTENANCE_TICKET`, `ROOM`, etc.
- Index composite `(ticket_status, opened_at)` sur `MAINTENANCE_TICKET` : la vue `V_ACTIVE_TICKETS` filtre sur le statut **et** trie par date, donc le composite sert les 2 en une passe.
- Index sur `device_status` : on filtre souvent dessus dans les rapports.

**Màj des stats :** on fait `DBMS_STATS.GATHER_SCHEMA_STATS` à la fin. Sans ça, le planificateur Oracle peut ne pas voir les nouveaux index et continuer à faire des FULL SCAN.

**Comment montrer le gain :** `EXPLAIN PLAN` avant/après. Exemple dans le commentaire à la fin du fichier.

## 3. Les triggers (08)

On les a regroupés en 3 familles.

**(a) Triggers de "vérif" des refs vers les MVs.** Oracle interdit les FK qui pointent vers une vue matérialisée. Or côté Cergy, `PERSON.role_id` est censé pointer vers `MV_PERSON_ROLE` (qui vient de Pau). Sans trigger, rien n'empêche d'insérer un `role_id = 999` bidon. Le trigger vérifie que la valeur existe vraiment dans la MV avant l'INSERT. Pareil côté Pau pour `device_type_id`, `os_version_id`, `peripheral_type_id`.

**(b) Triggers métier.** Petites règles bon sens qui ne tiennent pas dans une `CHECK` constraint :
- `trg_device_retired_guard` : on ne peut pas passer un device en RETIRED s'il a encore une personne assignée. Faut d'abord libérer.
- `trg_assign_active` : on n'assigne pas un device à une personne marquée INACTIVE.
- `trg_ticket_close_auto` : quand un ticket passe à CLOSED, on auto-remplit `closed_at`. En plus on bloque toute modif d'un ticket déjà CLOSED (un ticket fermé est immuable).
- `trg_assign_return_sync` : quand on clôture une affectation (`returned_at` renseigné), le pointeur `DEVICE.assigned_person_id` est mis à NULL automatiquement. Sinon les deux tables peuvent se désynchroniser.
- `trg_person_deactivate` : on refuse de désactiver une personne qui a encore des devices assignés. On force l'admin à libérer manuellement avant. Choix volontaire : pas de cascade silencieuse, pour éviter qu'un admin perde de vue ce qu'il libère.

**(c) Audit.** `trg_audit_device` trace toutes les modifs (INSERT/UPDATE/DELETE) sur `DEVICE` dans une table `DEVICE_HISTORY`. C'est ce qu'on attend d'un GLPI : pouvoir reconstruire l'historique d'un équipement.

## 4. Les curseurs et fonctions (09)

**Fonctions :**
- `fct_device_age(id)` : âge du device en mois depuis `purchase_date`.
- `fct_ticket_duration_days(id)` : durée du ticket en jours (fermé ou en cours).
- `fct_device_has_ticket(id)` : renvoie 1 si le device a un ticket actif, 0 sinon.

Note sur la dernière : on renvoie `NUMBER` et pas `BOOLEAN` parce qu'Oracle interdit `BOOLEAN` dans les requêtes SQL (limitation connue). Avec `NUMBER` on peut faire `WHERE fct_device_has_ticket(device_id) = 1`.

**Procédures avec curseurs :**
- `proc_report_parc` : 3 curseurs imbriqués (bâtiment → salle → device). C'est le pattern du `reporting_recoltes` du TP6.
- `proc_detect_aging_tickets(p_days)` : curseur paramétré sur les tickets ouverts depuis plus de N jours, chaque ligne loggée dans ERROR_LOG comme alerte.
- `proc_cleanup_orphan_periph` : libère les périphériques rattachés à un device RETIRED ou disparu.

## 5. Ce qu'on a évité

Pour ne pas en faire trop :
- Pas de package d'exceptions custom. On utilise `raise_application_error(-20XXX, '...')` direct, comme dans les TPs.
- Pas d'index fonctionnel compliqué (CASE WHEN dans l'index, etc.). Que du B-tree classique.
- Pas de curseur explicite avec `OPEN/FETCH/CLOSE` et `%ISOPEN` partout. On reste sur du `FOR x IN (...) LOOP` simple, lisible.
- Pas de `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` ou `SYS_CONTEXT` dans le log. Juste `SQLCODE` et `SQLERRM`.

## 6. Récap pour la soutenance

On peut présenter ça comme : "le projet initial était bien structuré sur la partie BDDR, mais on a vu 3 choses qu'on pouvait améliorer."

1. **Pas de traçabilité des erreurs** → table `ERROR_LOG` + helper `proc_log_error` avec `PRAGMA AUTONOMOUS_TRANSACTION` (pattern TP7).
2. **Des jointures qui faisaient FULL SCAN** → index supplémentaires sur les FK + `gather_schema_stats`.
3. **Quelques règles métier qui n'étaient pas garanties** → triggers de vérif et de cohérence + audit sur DEVICE.

Et en bonus quelques curseurs/fonctions pour montrer le PL/SQL CM5/6.
