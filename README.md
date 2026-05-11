┌─────────────────────────────────┐        ┌──────────────────────────────────┐
│       CYTECH_CERGY              │        │         CYTECH_PAU               │
│  (tablespace DATA_CERGY)        │        │   (tablespace DATA_PAU)          │
│                                 │◄──────►│                                  │
│  Tables maîtres (propriétaires) │LNK_PAU │  Tables maîtres (propriétaires)  │
│   DEVICE_TYPE                   │LNK_CERGY│  SITE                           │
│   OS_FAMILY                     │        │  PERSON_ROLE                     │
│   OS_VERSION                    │        │                                  │
│   PERIPHERAL_TYPE               │        │  MVs depuis Cergy               │
│                                 │        │   MV_DEVICE_TYPE                 │
│  MVs depuis Pau                 │        │   MV_PERIPHERAL_TYPE             │
│   MV_SITE                       │        │   MV_OS_FAMILY                   │
│   MV_PERSON_ROLE                │        │   MV_OS_VERSION                  │
│                                 │        │                                  │
│  Tables locales                 │        │  Tables locales                  │
│   BUILDING (site_id=1)          │        │   BUILDING (site_id=2)           │
│   ROOM                          │        │   ROOM                           │
│   PERSON                        │        │   PERSON                         │
│   DEVICE                        │        │   DEVICE                         │
│   PERIPHERAL                    │        │   PERIPHERAL                     │
│   DEVICE_ASSIGNMENT             │        │   DEVICE_ASSIGNMENT              │
│   MAINTENANCE_TICKET ◄──────────┼────────┼── (via PROC_OPEN_TICKET_PAU)    │
│                                 │        │                                  │
│  Vues cross-site                │        │  Vues cross-site                 │
│   V_PAU_DEVICE_MIN              │        │   V_CERGY_TICKET_MIN             │
│                                 │        │                                  │
│  Procédure                      │        │  Procédure                       │
│   PROC_CREATE_TICKET            │        │   PROC_OPEN_TICKET_PAU           │
└─────────────────────────────────┘        └──────────────────────────────────┘



La logique de chaque pièce

Référentiels maîtres — Chaque site possède une partie des référentiels.

    Pau est maître de SITE et PERSON_ROLE (les données d'organisation) ;

    Cergy est maître de DEVICE_TYPE, OS_FAMILY, OS_VERSION, PERIPHERAL_TYPE (les données techniques).

Materialized views (REFRESH ON DEMAND) — Chaque site dispose d'une copie locale des référentiels dont il n'est pas propriétaire, pour pouvoir les consulter sans faire un appel distant à chaque requête. Quand un référentiel change, on fait manuellement DBMS_MVIEW.REFRESH('MV_XXX').

Tables locales fragmentées — Les données métier BUILDING, ROOM, PERSON, DEVICE, PERIPHERAL, DEVICE_ASSIGNMENT sont dupliquées structurellement sur les deux sites mais contiennent chacune uniquement les données de leur site (site_id = 1 à Cergy, site_id = 2 à Pau).

Tickets centralisés sur Cergy — MAINTENANCE_TICKET n'existe que sur Cergy. Si Pau veut ouvrir un ticket pour un de ses équipements, il appelle PROC_OPEN_TICKET_PAU qui valide que le device existe localement puis insère le ticket sur Cergy via le DB link. De son côté, Cergy a PROC_CREATE_TICKET qui gère les tickets des deux sites.

Vues distantes — V_PAU_DEVICE_MIN (côté Cergy) et V_CERGY_TICKET_MIN (côté Pau) donnent un accès rapide en lecture à quelques colonnes essentielles de l'autre site, sans rapatrier tout.
