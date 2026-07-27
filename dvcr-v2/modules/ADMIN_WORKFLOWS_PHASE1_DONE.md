# Admin Workflows — Phase 1 DONE

**Date :** 2026-07-26  
**Statut :** **DONE** — livraison code Phase 1  
**Cadre :** ADR-0004 (in-place), ADR-0005 (pas de delete), ADR-0002 (pas Esti/WC)  
**Docs parents :** [`ADMIN_WORKFLOWS.md`](../ADMIN_WORKFLOWS.md) · [`ADMIN_UX_ROADMAP.md`](../ADMIN_UX_ROADMAP.md)  
**Review :** [`docs/reviews/ADMIN_WORKFLOWS_PHASE1_ARCHITECTURE_REVIEW.md`](../docs/reviews/ADMIN_WORKFLOWS_PHASE1_ARCHITECTURE_REVIEW.md)  
**Cleanup (Awaiting GO) :** [`ADMIN_WORKFLOWS_PHASE1_CLEANUP_PROPOSAL.md`](./ADMIN_WORKFLOWS_PHASE1_CLEANUP_PROPOSAL.md)

---

## Objectif livré

Navigation primaire Admin par **4 flux de travail**, sans retirer d’onglet ni changer permissions / deep-links.

| Flux | Comportement Phase 1 |
|------|----------------------|
| 🟢 Préparation match | Hub raccourcis → onglets existants |
| 🔴 Match en direct | Cockpit Direct réorganisé (sticky + Pilotage / Studio) |
| 🔵 Après-match | Hub raccourcis → stats / MOTM / matchs / actus / notifs |
| 🟣 Administration | Hub raccourcis → users / staff / settings / TV / logs |

Les **17 onglets** restent accessibles via **Tous les outils** (sidebar) / **Outils** (mobile) / deep-links `#/admin/<segment>`.

---

## Ce qui change pour le staff

1. Sidebar (web) et barre basse (mobile) : **4 flux** en entrée, plus les 6 univers comme nav primaire.
2. Prépa / Après / Admin ouvr pages hub avec raccourcis filtrés par permissions.
3. Direct = **vue match-day** :
   - bandeau sticky (score aperçu, START/STOP, chips Stats / Push / Modo, switch Pilotage|Studio) ;
   - **Pilotage** : URL + `LiveMatchQuickPilotageBody` (score/chrono/buts/cartons) + stats + votes ;
   - **Studio** : salon live + émission/sondage (plus sous le même scroll que le pilotage chaud).
4. Aucune feature métier retirée ; callables / Firestore inchangés.

---

## Chemins clés

| Zone | Fichiers |
|------|----------|
| Modèle flux | `lib/screens/admin/workflows/admin_workflow_model.dart` |
| Hubs | `lib/screens/admin/workflows/admin_workflow_hub.dart` |
| Sidebar flux | `lib/screens/admin/workflows/admin_sidebar_workflow_nav.dart` |
| Mobile bar | `lib/screens/admin/workflows/admin_mobile_workflow_bar.dart` |
| État nav | `lib/screens/admin/admin_controller.dart` (`selectWorkflow`, `openToolFromHub`, `navSurface`) |
| Shell | `lib/screens/admin/admin_shell.dart`, `admin_sidebar.dart` |
| Direct cockpit | `lib/screens/admin/tabs/direct/direct_tab.dart`, `direct_sticky_actions.dart` |
| Smoke | `test/screens/admin/admin_workflows_smoke_test.dart` |

---

## Hors Phase 1 (Phase 2+)

- Sticky hot controls **inline** (but/chrono) sans scroll interne du pilotage — densification `LiveMatchQuickPilotageBody`.
- Latéral stats / split workbench dans Direct.
- Checklist Prépa / Après avec match sélectionné + bandeau contexte global.
- Brancher `DashboardMatchDayCard` comme pont de flux.
- Raccourcis clavier web.
- Suppression doublons nav (univers vs flux) — **uniquement après GO** cleanup.

---

## Vérifications

- `flutter analyze` sur shell / workflows / sticky / controller : **0 issue**
- Smoke workflows : **4 tests PASS**
- Registry `adminTabDefs` : 17 onglets inchangés ; indices `AdminTabIndex` stables

---

## STOP

**Awaiting validation utilisateur avant Phase 2.**
