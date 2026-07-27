# ADR-0002 — Pas de modules permanents pour événements ponctuels

**Statut :** Accepté  
**Date :** 2026-07-26  
**Décideurs :** Lead Architect DVCR V2  
**Compléments :** `SCOPE_V2.md`, `ARCHITECTURE.md` § Hors scope / Extensions, `FEATURES.md` (annotations ⛔)

---

## Contexte

La V1 embarque dans le monolithe des surfaces liées à des **événements ponctuels** ou des expérimentations produit :

- Coupe du Monde / World Cup (`features/world_cup/`, rollouts, admin partenaire)
- Esti’DVCR (`esti_dvcr`, ligues, callables `fixEstiDvcrMatchDays`)
- Tournois temporaires (`tournaments/{id}/…`, `tournament_scoring.js`)
- Routes / alias admin historiques (esti/cdm → Pronos & jeux)
- Code « compat only » semi-mort (barrels, redirections)

Porter ces modules « au cas où » dans le **core V2** reconstituerait de la dette, diluerait le produit commercialisable (plateforme multi-club), et figerait des chemins legacy dans la structure Feature First.

La plateforme V2 doit rester centrée sur le **cœur club** : matchs, direct, stats, pronos championnat, communauté, bénévoles, adhérents, streaming, admin, notifications, sponsors (+ features cœur futures).

---

## Décision

1. **Exclure du core V2** tout module permanent World Cup, Esti’DVCR, tournois temporaires, routes historiques inutiles, et code legacy « compat only ».
2. Les événements ponctuels, s’ils reviennent, sont des **extensions indépendantes** :
   - package optionnel / feature isolée hors `features/` cœur, **ou**
   - activation via **feature flag / plugin** tenant, sans couplage au graphe d’imports cœur.
3. Les Functions / collections Firestore legacy (ex. `tournaments`, `esti_dvcr_leagues`) restent côté backend tant que non purgées ; le client ne les consomme plus (GO removal 2026-07-26 — `ESTI_WC_REMOVAL_DONE.md`). Les exports `tournament_scoring` ont été retirés du monolithe Functions.
4. Toute demande de « porter Esti / CdM / tournoi dans V2 core » est **refusée** (pushback architecte) — proposer une extension datée + ADR dédié si le besoin produit est réel.

---

## Conséquences

### Positives

- Core lisible, commercialisable, multi-tenant sans branches événementielles.
- Roadmap migration plus courte et prévisible (`MIGRATION_PLAN.md`).
- Moins de surface admin / flags / routes à maintenir.

### Négatives / coûts

- Pas de parité 1:1 avec **toutes** les surfaces V1 (volontaire — voir `SCOPE_V2.md`).
- Un futur événement mondial / tournoi club nécessitera un package / flag dédié (effort isolé, pas un fork du core).

### Suivi

- Annoter `FEATURES.md` en ⛔ pour les items concernés.
- Ne **pas** créer de dossiers `features/world_cup`, `features/esti`, `features/tournaments` dans le scaffold Module 0.
- Réviser cet ADR uniquement si un produit « events » devient une ligne commerciale permanente (alors : package nommé, pas fusion dans Matches/Pronos cœur).
