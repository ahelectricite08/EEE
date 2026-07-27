# Cleanup Proposal — Module : Admin Workflows Phase 1

**Module :** Admin — navigation par flux  
**Date :** 2026-07-26  
**Review liée :** `docs/reviews/ADMIN_WORKFLOWS_PHASE1_ARCHITECTURE_REVIEW.md`  
**ADR :** [ADR-0005](../ADR-0005-cleanup-requires-user-go.md)  
**Statut global :** **Awaiting user GO** — **aucune suppression effectuée**

---

## Contexte

Phase 1 ajoute une couche **flux** (jobs) au-dessus de la couche **outils** (17 onglets). Les 6 `AdminUniverse` sidebar restent dans le modèle / palette mais ne pilotent plus la navigation primaire. Doublons conceptuels possibles — à traiter seulement après GO.

---

## Candidats

| Item | Type | Chemins | Risque | Recommandation | Statut |
|------|------|---------|--------|----------------|--------|
| Groupes `AdminUniverse` comme nav primaire | doublon | `admin_palette.dart`, `admin_nav_model.dart`, anciens labels sidebar | Faible | différer — garder couleurs/icônes pour chips outils | **Awaiting user GO** |
| Dead helpers Direct (`_GoalFeed`, `_SBarRow`, …) | mort | `direct_tab.dart` | Moyen (fichier monolithe) | supprimer après audit call sites | **Awaiting user GO** |
| `_createLiveSalon` / `_archiveLiveSalon` orphelins | mort | `direct_tab.dart` | Faible | vérifier `DirectLiveSalonPanel` puis supprimer | **Awaiting user GO** |
| Mode « classique » 6 univers toggle | legacy | n/a (non livré) | — | différer — Phase 1 garde « Tous les outils » | **Awaiting user GO** |

---

## Batches GO suggérés

| Batch | Items | Prérequis |
|-------|-------|-----------|
| A | Dead code Direct (helpers non référencés) | Smoke Direct + analyze |
| B | Documenter / éventuellement retirer labels univers orphelins | Adoption flux confirmée |

---

*Proposal only — pas de suppression dans ce chantier.*
