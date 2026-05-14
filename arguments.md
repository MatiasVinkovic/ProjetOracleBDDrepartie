# Arguments et justifications des ajouts

Ce document explique pourquoi nous avons ajouté chaque élément des fichiers `06_error_logging.sql`, `07_indexes.sql`, `08_triggers.sql` et `09_cursors_functions.sql`. L'objectif est de pouvoir défendre chaque choix lors de la soutenance et dans le rapport, sans tomber dans le piège du "on a ajouté ça parce qu'on connaissait, sans raison particulière".

Le projet existait déjà dans un état solide : architecture BDDR avec fragmentation horizontale par site, vues matérialisées en remplacement des triggers de réplication, tablespaces dédiés, six rôles applicatifs sur deux sites. Les ajouts décrits ici viennent **compléter** ce socle, pas le refaire.

---

## 1. La table `ERROR_LOG` et le package d'exceptions

### Le constat de départ

Quand on a relu les fichiers `01_setup_cergy.sql`, `02_setup_pau.sql` et `03_replication.sql`, on a remarqué que la gestion d'erreur s'arrêtait à des `RAISE_APPLICATION_ERROR(-20032, '...')` éparpillés un peu partout dans les procédures. Concrètement, si `PROC_CREATE_TICKET` échoue à minuit parce qu'un device a été supprimé entre-temps sur Pau, personne ne le sait. L'erreur remonte à l'appelant, qui voit un message court, et c'est tout. Il n'y a aucune trace persistante de ce qui s'est passé.

Pour un système qui se veut représentatif d'un GLPI d'école, c'est une lacune importante. On a donc décidé d'ajouter une table de journalisation des erreurs.

### Pourquoi une table par site et pas une seule centralisée

C'est la première question qu'on s'est posée. Deux options :

**Option A** — une seule table sur Cergy, Pau loggue à distance via `ERROR_LOG@LNK_CERGY`. Avantage : une seule source de vérité, plus simple à requêter. Inconvénient majeur : si le DB link Pau→Cergy est cassé au moment où on veut logger, on perd justement le log de l'erreur qui nous intéresse — l'erreur arrive sans doute *parce que* le réseau pose problème. Plus largement, faire dépendre la journalisation d'un service distant est exactement l'inverse de ce qu'on veut pour un système de logs.

**Option B retenue** — une table `ERROR_LOG` locale par site. Chaque site écrit dans sa propre table, sans aucune dépendance réseau au moment de l'INSERT. Côté Cergy on a en plus une vue `V_ERROR_LOG_ALL` qui fait un `UNION ALL` entre la table locale et `ERROR_LOG@LNK_PAU`. Cette vue n'est utilisée *qu'en lecture* (pour consultation par l'admin), donc si le DB link est down on lit juste la partie Cergy, sans casser l'écriture.

Cette séparation lecture/écriture est importante. L'écriture (logger une erreur) ne doit jamais échouer à cause du réseau. La lecture (consulter les erreurs des deux sites) peut tolérer une indisponibilité.

### Pourquoi `PRAGMA AUTONOMOUS_TRANSACTION`

C'est le détail technique le plus important du module, et probablement le plus intéressant à présenter en soutenance.

Imaginons une procédure métier qui fait quelque chose comme :

```
BEGIN
  INSERT INTO TICKET ...;        -- réussit
  UPDATE DEVICE ...;             -- échoue (contrainte violée)
EXCEPTION
  WHEN OTHERS THEN
    PROC_LOG_ERROR(...);
    ROLLBACK;                    -- annule tout
END;
```

Sans `PRAGMA AUTONOMOUS_TRANSACTION` dans `PROC_LOG_ERROR`, l'INSERT dans `ERROR_LOG` fait partie de la même transaction que l'INSERT TICKET et l'UPDATE DEVICE. Quand on fait `ROLLBACK`, on annule **tout** — y compris le log. Résultat : la transaction métier est annulée (ce qu'on voulait), mais on n'a aucune trace de pourquoi.

Avec `PRAGMA AUTONOMOUS_TRANSACTION`, l'INSERT dans `ERROR_LOG` se fait dans une **transaction séparée** qui commit immédiatement. Le `ROLLBACK` de la transaction principale ne touche pas le log. C'est exactement le comportement attendu : on annule l'opération métier mais on garde la trace de l'incident.

C'est un cas d'usage classique des transactions autonomes en PL/SQL, et c'est aussi probablement le concept le plus subtil qu'on mobilise sur l'ensemble du projet.

### Le package `PKG_EXCEPTIONS`

L'autre choix qu'on défend, c'est d'avoir nommé les exceptions au lieu de garder des `RAISE_APPLICATION_ERROR(-20100, ...)` partout dans le code.

Concrètement, ça permet d'écrire :

```
EXCEPTION
  WHEN PKG_EXCEPTIONS.EX_DEVICE_NOT_FOUND THEN ...
  WHEN PKG_EXCEPTIONS.EX_PERSON_INACTIVE THEN ...
```

au lieu de :

```
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20100 THEN ...
    ELSIF SQLCODE = -20103 THEN ...
```

Le premier code est auto-documenté. Le second oblige à se souvenir de chaque code numérique. Sur un projet à plusieurs membres, c'est la différence entre du code maintenable et du code qu'on n'ose pas modifier.

Le mécanisme repose sur `PRAGMA EXCEPTION_INIT` qui associe un nom d'exception à un code Oracle. C'est du PL/SQL standard, vu en CM5/6.

Les codes vont de `-20100` à `-20121`. On a réservé cette plage. Si on a besoin de plus d'exceptions plus tard, on continue dans la même plage.

---

## 2. Les index supplémentaires

### Le vrai argument à mettre en avant : les verrous sur clés étrangères non indexées

C'est de loin le point le plus solide à défendre, et il vient directement du CM3 sur les transactions et les verrous.

En Oracle, quand une colonne FK n'est pas indexée, **toute opération sur la table parent verrouille la table enfant entière** (verrou de mode Share, `LMODE=4`). Si on fait `UPDATE PERSON SET ... WHERE person_id = 5`, et que `MAINTENANCE_TICKET.opened_by_person_id` n'a pas d'index, alors la table `MAINTENANCE_TICKET` est entièrement verrouillée le temps de la transaction. Toutes les autres transactions qui veulent toucher à `MAINTENANCE_TICKET` attendent.

Avec un index sur la FK, ce verrou descend au niveau ligne uniquement. C'est un gain énorme en concurrence.

Quand on a relu les fichiers `01_` et `02_`, on a identifié plusieurs FK déclarées sans index. Pour Cergy :

- `MAINTENANCE_TICKET.opened_by_person_id` → FK vers `PERSON`, pas d'index
- `MAINTENANCE_TICKET.technician_id` → FK vers `PERSON`, pas d'index
- `DEVICE.switch_id`, `DEVICE.vlan_id` → FK vers `NETWORK_SWITCH` et `VLAN`, pas d'index
- `PERIPHERAL.room_id`, `PERIPHERAL.peripheral_type_id` → idem
- `ROOM.building_id`, `OS_VERSION.os_family_id` → idem

Pour chaque cas on a ajouté un index. C'est un peu mécanique mais l'argument est en béton : ce sont des index "anti-verrou", justifiés par le comportement transactionnel d'Oracle, pas par une intuition de performance.

### Les index métier (qui méritent une justification individuelle)

À côté des index FK, on a ajouté quelques index spécifiques justifiés par les requêtes qui existent réellement dans les vues et procédures.

**`IDX_TICKET_STATUS_OPEN(ticket_status, opened_at)`** — la vue `V_ACTIVE_TICKETS` filtre sur `ticket_status IN ('OPEN','IN_PROGRESS')` et trie par `opened_at DESC`. Un index simple sur `ticket_status` couvre le filtre mais oblige Oracle à faire ensuite un `SORT ORDER BY`. L'index composite couvre les deux d'un coup : Oracle lit l'index dans l'ordre demandé et n'a pas besoin de trier après. C'est typiquement le genre d'optimisation où le `EXPLAIN PLAN` montre clairement le gain.

**`IDX_DEVICE_STATUS`** — la cardinalité de `device_status` est faible (4 valeurs : `IN_SERVICE`, `IN_STOCK`, `IN_REPAIR`, `RETIRED`). Avec une distribution biaisée (la plupart des devices sont `IN_SERVICE`), un index B-tree reste efficace pour filtrer les minorités (`IN_REPAIR`, `RETIRED`) qui sont justement les requêtes les plus utiles en exploitation. On a écarté un index bitmap parce que les UPDATE de statut sont fréquents (un ticket fait passer un device en `IN_REPAIR` puis en `IN_SERVICE`), et un bitmap verrouille des segments entiers à chaque update.

**`IDX_ASSIGN_ACTIVE`** — c'est un index fonctionnel un peu astucieux. La requête naturelle est "trouve l'affectation active pour ce device", soit `WHERE device_id = ? AND returned_at IS NULL`. Les `NULL` ne sont normalement pas stockés dans un index B-tree standard, donc un index sur `returned_at` seul ne sert à rien. On a donc créé un index sur l'expression `CASE WHEN returned_at IS NULL THEN device_id END`. Conséquence : l'index ne contient que les lignes pour lesquelles `returned_at IS NULL`, c'est-à-dire les affectations actives — qui sont une petite minorité des lignes totales (typiquement quelques dizaines sur des milliers). L'index est cinq à dix fois plus petit qu'un index complet sur `device_id`, et il répond exactement à la requête.

**`IDX_PERSON_STATUS_ROLE`** — composite, justifié par les requêtes du genre "lister les profs ACTIVE" qu'on utilisera dans les rapports.

### Ce qu'on n'a pas ajouté volontairement

Trois pièges qu'on a évités, et qui méritent d'être mentionnés parce qu'ils montrent qu'on a réfléchi :

- Pas d'index sur les colonnes `UNIQUE` (`asset_tag`, `serial_number`, `mac_address`, `email`, `login`). Oracle crée déjà un index unique implicite avec chaque contrainte `UNIQUE`. Ajouter un index manuel par-dessus serait un doublon qui ralentit les INSERT pour rien.

- Pas d'index sur `site_id` seul. La contrainte `CHECK (site_id = 1)` (ou `= 2`) garantit que toutes les lignes ont la même valeur sur une table donnée. Un index avec une cardinalité de 1 ne sert à rien : un `INDEX RANGE SCAN` retournerait toutes les lignes, ce qui équivaut à un `FULL TABLE SCAN`. Sauf que la passe d'index coûte en plus la maintenance à chaque INSERT.

- Pas d'index bitmap sur `device_status` ou `ticket_status` (cf. paragraphe précédent).

Ces choix négatifs sont aussi importants à expliquer que les positifs.

---

## 3. Les triggers

### La famille validation : compenser ce qu'Oracle ne sait pas faire

Le projet utilise des vues matérialisées (`MV_PERSON_ROLE`, `MV_DEVICE_TYPE`, `MV_OS_VERSION`, `MV_PERIPHERAL_TYPE`) pour répliquer en lecture les tables de référence appartenant à l'autre site. C'est un choix architectural défendu dans `analyse_repartition.md` : ces données changent quelques fois par an, donc une réplication par MV en mode `REFRESH ON DEMAND` est largement suffisante.

Le problème, c'est qu'**Oracle n'autorise pas de clé étrangère pointant vers une vue matérialisée**. Concrètement, on peut écrire `INSERT INTO PERSON (..., role_id) VALUES (..., 999)` sur Cergy sans aucune erreur, même si `role_id=999` n'existe pas dans `MV_PERSON_ROLE`. L'intégrité référentielle est cassée pour toutes les références vers les MVs.

Le fichier `constat.md` mentionne d'ailleurs : "Integrite garantie par CK constraints + procedures". Sauf que dans les faits, aucune procédure ne vérifie ça pour les INSERT directs. Bug latent.

Les triggers de validation comblent ce trou. Ils ressemblent tous à la même structure :

1. `BEFORE INSERT OR UPDATE OF <colonne>` sur la table concernée.
2. Un `SELECT COUNT(*)` dans la MV pour vérifier que la valeur existe.
3. Si elle n'existe pas, on lève l'exception nommée correspondante et on logge dans `ERROR_LOG` via `PROC_LOG_ERROR`.

C'est une compensation logique de l'absence de FK. Le coût à l'exécution est faible : les MVs sont petites (4 à 20 lignes), et le `COUNT(*)` est servi par l'index PK de la MV.

Triggers concernés : `TRG_VALIDATE_ROLE_CERGY` (pour `PERSON.role_id` côté Cergy), `TRG_VALIDATE_DEVICE_TYPE_PAU`, `TRG_VALIDATE_DEVICE_OS_PAU`, `TRG_VALIDATE_PERIPH_TYPE_PAU`.

### La famille cohérence métier : règles qui ne tiennent pas dans une CHECK constraint

Les contraintes `CHECK` d'Oracle peuvent vérifier une condition simple sur une ligne donnée. Elles ne peuvent pas vérifier des règles multi-tables, multi-lignes ou conditionnelles complexes. C'est là que les triggers prennent le relais.

**`TRG_DEVICE_RETIRED_GUARD`** — interdit qu'un device passe en `RETIRED` s'il a encore une personne assignée. La logique est triviale mais nécessaire : retirer un équipement implique d'avoir d'abord fait la procédure de retour. Sans ce trigger, on peut très bien marquer un device comme retiré tout en gardant `assigned_person_id` rempli — c'est incohérent. Le trigger force le bon ordre des opérations.

**`TRG_DEVICE_ASSIGN_ACTIVE`** — interdit d'assigner un device à une personne dont `person_status = 'INACTIVE'`. C'est une règle métier simple : on ne donne pas de matériel à quelqu'un qui a quitté l'école.

À noter qu'on avait initialement envisagé un trigger plus ambitieux, `TRG_DEVICE_PERSON_SITE`, qui aurait aussi vérifié que `PERSON.site_id = DEVICE.site_id`. On l'a abandonné parce que c'est déjà garanti par les contraintes `CK_PERSON_SITE` et `CK_DEVICE_SITE` (les deux à 1 ou les deux à 2 sur un même schéma). Le trigger aurait fait du travail redondant. Garder seulement la vérification ACTIVE est plus propre.

**`TRG_TICKET_CLOSE_AUTO`** (Cergy uniquement) — deux comportements en un :
1. Si on bascule un ticket en `CLOSED` sans renseigner `closed_at`, le trigger le fait automatiquement (`closed_at := SYSDATE`). Ça évite les tickets fermés sans date de fermeture, qui font planter les rapports de durée.
2. Si on essaie de modifier un ticket déjà `CLOSED` (peu importe la modification), le trigger refuse. Un ticket fermé est immuable. Cohérent avec un système qui sert aussi de trace pour la facturation interne ou les statistiques de SAV.

**`TRG_ASSIGN_RETURN_SYNC`** — synchronisation entre `DEVICE_ASSIGNMENT` et `DEVICE`. Aujourd'hui, ces deux tables peuvent diverger : on peut renseigner `DEVICE_ASSIGNMENT.returned_at` (clôture d'une affectation) sans toucher `DEVICE.assigned_person_id`. Le device se retrouve marqué comme assigné à quelqu'un qui l'a rendu. Le trigger répare ça automatiquement : dès qu'on clôture une affectation, le pointeur sur le device est libéré.

Pas de risque de mutating table parce que le trigger est sur `DEVICE_ASSIGNMENT` mais modifie `DEVICE`, donc deux tables différentes.

**`TRG_PERSON_DEACTIVATE`** — interdit de passer une personne en `INACTIVE` si elle a encore des devices ou des affectations actives. Deux options étaient possibles ici, et c'est probablement le choix le plus discutable du projet.

*Option A (cascade automatique)* : quand on désactive une personne, le trigger libère automatiquement tous ses devices (`assigned_person_id := NULL`) et clôt toutes ses affectations actives (`returned_at := SYSDATE`). Avantage : un seul UPDATE à faire pour l'admin, le système se débrouille. Inconvénient : c'est du comportement "magique". L'admin clique sur "désactiver Untel", et 15 devices se libèrent silencieusement. Aucune trace de ce qui s'est passé pour l'admin.

*Option B (blocage)* : le trigger refuse la désactivation tant qu'il reste des affectations. L'admin doit d'abord libérer manuellement, ticket par ticket, puis désactiver. Plus lourd, mais explicite. L'admin voit exactement ce qu'il fait.

**On a retenu l'option B**, par cohérence avec la philosophie globale du projet : pas de cascade silencieuse, on préfère une erreur explicite qui force à comprendre ce qu'on fait. C'est aussi plus défendable en soutenance — quelqu'un peut nous poser la question, et "on a fait exprès de bloquer pour éviter une perte d'information silencieuse" est une réponse claire.

### La famille audit : `DEVICE_HISTORY`

Le trigger `TRG_AUDIT_DEVICE` enregistre dans `DEVICE_HISTORY` toute modification de `DEVICE` : `INSERT`, `UPDATE`, `DELETE`, avec l'ancien et le nouveau statut, l'ancienne et la nouvelle personne assignée, l'ancienne et la nouvelle salle. C'est de la traçabilité classique d'un GLPI : on doit pouvoir reconstruire "qui a touché à ce device, quand, et pour faire quoi".

Un choix de conception à expliciter : le trigger est en **mode best-effort**. Si l'INSERT dans `DEVICE_HISTORY` échoue pour une raison ou une autre (tablespace plein, contrainte violée, etc.), le trigger n'interrompt pas le DML métier. Il logge juste l'échec dans `ERROR_LOG` (qui est autonome, donc qui survit même si le reste rollback) et laisse passer l'opération sur `DEVICE`.

C'est un choix philosophique. L'alternative serait d'annuler le DML métier quand l'audit échoue, mais ça pénalise les utilisateurs pour un problème d'infrastructure qui ne les concerne pas. On a préféré : "l'audit est utile, pas critique". L'admin peut surveiller la table `ERROR_LOG` pour repérer les `AUDIT_FAILURE`.

---

## 4. Les curseurs et fonctions PL/SQL

### Pourquoi avoir gardé un curseur explicite (`OPEN`/`FETCH`/`CLOSE`)

Dans `PROC_CLEANUP_ORPHAN_PERIPH`, on a délibérément utilisé la forme explicite du curseur avec `FOR UPDATE OF ... WHERE CURRENT OF`. C'est la forme qui demande le plus de code (déclaration, OPEN, boucle FETCH, EXIT WHEN NOTFOUND, CLOSE, gestion du %ISOPEN en cas d'erreur), et c'est rarement la plus pratique en production où la forme `FOR ... LOOP` suffit.

Sauf qu'on voulait quand même la démontrer parce que :

- C'est le mécanisme sous-jacent que la forme `FOR ... LOOP` cache. Comprendre l'un aide à comprendre l'autre.
- Le pattern `FOR UPDATE OF ... WHERE CURRENT OF` n'existe qu'avec un curseur explicite. C'est la façon classique en PL/SQL de boucler sur des lignes en les modifiant au passage, en gardant un verrou ligne pendant la transaction.
- Sur l'oral, ça démontre qu'on connaît la palette complète des curseurs.

### Le rapport hiérarchique avec curseurs imbriqués

`PROC_REPORT_PARC_BY_BUILDING` est l'exemple typique du curseur dans un curseur (CM6). Trois niveaux : bâtiments, salles, devices. Chaque niveau passe son `id` comme paramètre au curseur du niveau suivant (`c_room(p_building)`, `c_device(p_room)`).

C'est un pattern à la fois pédagogique et utile en pratique pour générer des rapports textuels. La sortie est en `DBMS_OUTPUT.PUT_LINE`, donc utilisable depuis SQL*Plus ou SQLcl avec `SET SERVEROUTPUT ON`.

### Le curseur paramétré

`PROC_DETECT_AGING_TICKETS(p_threshold_days)` montre la troisième forme : un curseur paramétré, où le seuil de jours est passé à l'appel. On peut donc demander "tickets ouverts depuis plus de 30 jours" ou "plus de 7 jours" selon le contexte.

Détail intéressant : chaque ticket détecté est loggé dans `ERROR_LOG` avec `app_code='TICKET_AGING'`. C'est délibéré, même si techniquement ce n'est pas une "erreur". On utilise `ERROR_LOG` comme un système de journalisation général d'événements applicatifs, pas seulement des erreurs Oracle. La requête `SELECT * FROM ERROR_LOG WHERE app_code='TICKET_AGING' ORDER BY error_ts DESC` devient un historique des alertes "tickets en retard" pour le SAV.

### Pourquoi `FCT_DEVICE_HAS_ACTIVE_TICKET` retourne `NUMBER` et pas `BOOLEAN`

Détail technique qui mérite une mention rapide : en Oracle, **on ne peut pas appeler une fonction PL/SQL retournant `BOOLEAN` depuis une requête SQL**. C'est une limitation historique. Si on écrit :

```sql
SELECT * FROM DEVICE WHERE FCT_DEVICE_HAS_ACTIVE_TICKET(device_id) = TRUE;
```

Oracle renvoie `ORA-00904`. La seule façon d'utiliser une telle fonction est de l'appeler depuis du PL/SQL.

Or l'intérêt principal de cette fonction est précisément d'être utilisée dans des `SELECT` ad-hoc et dans des vues. On a donc choisi le pattern classique : retour `NUMBER(1)` avec convention `0 = faux, 1 = vrai`. Ça permet :

```sql
SELECT asset_tag FROM DEVICE WHERE FCT_DEVICE_HAS_ACTIVE_TICKET(device_id) = 1;
```

C'est une petite contrainte d'Oracle qu'il faut connaître. À mentionner en soutenance si la question est posée.

### `FCT_DEVICE_AGE` et `FCT_TICKET_DURATION_DAYS`

Deux fonctions simples qui retournent respectivement l'âge d'un device en mois et la durée de vie d'un ticket en jours. Pas d'astuce particulière.

Une remarque sur `FCT_DEVICE_AGE` : elle n'est **pas** marquée `DETERMINISTIC`. C'est volontaire. `DETERMINISTIC` signifie que pour les mêmes paramètres d'entrée, la fonction retournera toujours la même valeur — Oracle peut alors cacher le résultat. Mais notre fonction utilise `SYSDATE` à l'intérieur, donc le résultat change avec le temps. La marquer `DETERMINISTIC` à tort serait un bug subtil.

### `PROC_RECONCILE_ASSIGNMENTS` — l'outil de diagnostic

Cette procédure est un peu spéciale. Elle parcourt les `DEVICE_ASSIGNMENT` actives (`returned_at IS NULL`) et vérifie qu'elles sont cohérentes avec `DEVICE.assigned_person_id`. En théorie, depuis qu'on a `TRG_ASSIGN_RETURN_SYNC` en place, ce ne devrait plus jamais retourner d'incohérence.

Mais on l'a quand même gardée pour deux raisons :

1. C'est utile **après une migration ou un import** de données historiques. Si on charge en masse des données qui contournent les triggers, on peut s'en servir pour valider la cohérence après coup.
2. C'est un cas d'école de curseur explicite avec gestion d'erreur (`IF %ISOPEN THEN CLOSE`) qu'on peut montrer en soutenance.

L'important est qu'elle est **redondante avec `TRG_ASSIGN_RETURN_SYNC`** en régime nominal — et c'est un argument honnête à présenter. La procédure n'est pas là parce qu'on en a besoin tous les jours, elle est là comme garde-fou ponctuel.

---

## 5. Ce qu'on aurait pu faire et qu'on n'a pas fait

Pour anticiper les questions du jury, voici quelques pistes auxquelles on a réfléchi et qu'on a écartées.

**Un trigger d'audit sur toutes les tables**. On l'a fait uniquement sur `DEVICE`. Étendre à `PERSON`, `MAINTENANCE_TICKET`, etc. aurait été cohérent mais aurait beaucoup gonflé le code pour peu d'apport pédagogique (le pattern serait répété). On a préféré faire un cas exemplaire bien fait plutôt que cinq cas dupliqués.

**Un trigger qui rafraîchit automatiquement les MVs**. On y a pensé, mais ça revient à recréer ce que la version initiale du projet avait justement supprimé : la réplication temps-réel des tables de référence. Le rafraîchissement manuel (`DBMS_MVIEW.REFRESH`) est cohérent avec le choix architectural retenu.

**Un partitionnement de la table `DEVICE` par `device_status` ou `purchase_date`**. Ça aurait été techniquement défendable pour de gros volumes, mais sur ce projet avec quelques centaines de lignes, c'est de l'over-engineering. On l'a écarté pour rester proportionné au contexte.

**Une procédure de purge automatique de `ERROR_LOG`**. Sur un système réel, on aurait un job qui supprime les logs de plus de N mois. Sur ce projet, c'est anecdotique — on a juste donné le `GRANT DELETE` au rôle admin pour qu'il puisse purger manuellement si besoin.

---

## 6. Ce que ces ajouts apportent au projet, vu d'ensemble

Si on prend du recul, ces quatre fichiers (`06_` à `09_`) transforment le projet sur trois axes :

**Intégrité**. Avant, plusieurs incohérences étaient possibles (role_id inexistant, device retiré mais assigné, ticket fermé sans date). Maintenant, l'ensemble est verrouillé par des triggers et des contraintes cohérentes. On peut générer 10 000 lignes aléatoires sans craindre de produire des données impossibles.

**Observabilité**. Avant, une erreur dans une procédure laissait à peine une trace dans la console de celui qui l'avait lancée. Maintenant, tout est journalisé dans `ERROR_LOG` avec contexte, stack trace, code applicatif. On peut diagnostiquer après coup ce qui s'est passé pendant la nuit.

**Performance**. Avant, des FK non indexées créaient des risques de verrous sur les tables parents, et plusieurs requêtes des vues faisaient des full scans inutiles. Maintenant, les index FK et les index métier (composite, fonctionnel) permettent à Oracle d'utiliser des `INDEX RANGE SCAN` ciblés.

C'est probablement la trame qu'on peut suivre pour la présentation orale : "voici trois faiblesses du projet initial, voici comment on les a comblées en utilisant des concepts vus en cours, voici les choix qu'on a faits et pourquoi".
