# Module 2 — Home / Accueil (modernisation architecture)

**Statut :** code livré — Architecture Review **PASS** (tranche 2) — awaiting GO user  
**Date :** 2026-07-26  
**App :** `dvcr_appli`  
**Dépend de :** [FOUNDATION.md](./FOUNDATION.md), [AUTH.md](./AUTH.md) (GO Auth)  
**Done :** [HOME_DONE.md](./HOME_DONE.md) · Review T2 : [HOME_T2_ARCHITECTURE_REVIEW.md](../docs/reviews/HOME_T2_ARCHITECTURE_REVIEW.md) · Cleanup : [HOME_CLEANUP_PROPOSAL.md](./HOME_CLEANUP_PROPOSAL.md)  
**Plan :** [MODERNIZATION_PLAN.md](../MODERNIZATION_PLAN.md)

---

## Intent

Refactor **interne** du hub Accueil : Feature First + Repository + Riverpod + UI sous `features/home/presentation`, sans changer UX / design / navigations.

Home est un **compositeur** (live, matchs, actus, dons, flags…). Ne pas migrer Live / Matches / Articles dans ce module — **adapters** seulement.

---

## Tranche 2 (cette livraison) — IN

| Brique | Détail |
|--------|--------|
| UI | Move `screens/home` → `features/home/presentation` |
| Split | Fichiers ≤ 300 L (parts + mixins + shell widgets) |
| Adapters | Live hub / Match catalog / Articles feed |
| Datasources | Stadium, match lookup, prediction, prono leaderboard |
| Façades | Re-exports `screens/home/*` (pattern Auth) |
| Tests | Domain + adapters |
| Docs | Review PASS + DONE + CLEANUP_PROPOSAL |

## OUT

- Migrer modules Matchs / Articles / Live entiers
- Industrialiser World Cup / Esti (ADR-0002)
- GoRouter, Sponsors, Prono
- Deletes destructifs (voir CLEANUP_PROPOSAL — GO séparé)

---

## DoD

- [x] UI sous `features/home/presentation`
- [x] Fichiers ≤ 300 L
- [x] Tests périmètre
- [x] `flutter analyze` 0 error périmètre home
- [x] Architecture Review **PASS**
- [x] `HOME_DONE.md` + `HOME_CLEANUP_PROPOSAL.md` + STOP

---

## Checklist validation user (non-régression)

1. Cold start → Accueil : sections visibles, scroll OK  
2. Bannière hero (asset ou photo admin)  
3. Layout hints si live (podcast / TV / don masqués selon config)  
4. Édition date podcast (admin) → sous-titre mis à jour  
5. Next match / actus / résultats / navigations onglets  
6. Pull-to-refresh matchs  
7. Hero profil : guest vs connecté (Auth session)
