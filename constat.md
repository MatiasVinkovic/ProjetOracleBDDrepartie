# Problème réplication

On avait mis en place une synchronisation automatique entre Cergy et Pau pour six tables de référence (types d'OS, types de matériel, rôles...). Le problème c'est que ces données changent deux ou trois fois par an au grand maximum, et on avait quand même mis 12 triggers qui tournent en permanence pour les maintenir à jour en temps réel sur les deux sites. C'est clairement surdimensionné pour ce que ça fait réellement.

En plus, la synchronisation était bidirectionnelle — les deux sites pouvaient modifier le référentiel et se propager mutuellement — ce qui n'a aucun sens métier. C'est Cergy le siège, c'est lui qui décide quels OS ou quels types d'équipements existent dans le système. Pau n'a pas à pousser ces infos vers Cergy. Cette symétrie artificielle crée un risque de deadlock et rend le code difficile à maintenir pour pas grand chose.

Ce qu'on fait à la place : les données de référence courantes (rôles, types de matériel) restent en local sur les deux sites mais sans synchronisation automatique — un INSERT manuel si jamais quelque chose change, ce qui sera rare. Pour les données OS, on les garde uniquement sur Cergy et Pau utilise une vue matérialisée qu'on refresh à la demande. Simple, explicite, et adapté à la vraie fréquence des changements.

Il y avait aussi un autre problème : les tickets de maintenance étaient bloqués sur Cergy uniquement, avec une contrainte qui interdisait explicitement les devices Pau. Résultat : impossible de déclarer une panne sur un équipement Pau dans le système. On a corrigé ça en élargissant la contrainte aux deux sites et en passant par une procédure qui valide le device sur le bon site avant d'insérer, puisqu'on ne peut pas avoir de clé étrangère vers un équipement distant.
