# Esti DVCR + Coupe du Monde — Removal DONE

**Date :** 2026-07-26  
**GO :** ADR-0005 explicite (« supression » après confirmation présence Esti + CdM)  
**Alignement :** ADR-0002 (pas de modules permanents pour événements ponctuels)

---

## Objectif

Retirer du produit V1 toute surface UI / admin / nav / client liée à **Esti’DVCR** et **Coupe du Monde / World Cup**, sans casser Prono championnat, Auth, Home (hors CdM), Sponsors.

---

## Fichiers / dossiers supprimés

### Esti
- `lib/screens/esti_dvcr/` (tab, leaderboard, leagues)
- `lib/navigation/esti_dvcr_rollout.dart`
- `lib/services/esti_dvcr_league_service.dart`
- `lib/screens/admin/tabs/esti_dvcr/`
- `lib/screens/admin/tabs/pronos/esti_dvcr_admin_section.dart`

### World Cup / tournoi événementiel
- `lib/features/world_cup/` (`tournament_prono_screen.dart`)
- `lib/screens/world_cup/`
- `lib/screens/world_cup_tab.dart` (barrel)
- `lib/screens/tournament_prono_screen.dart` (barrel)
- `lib/navigation/world_cup_tab_rollout.dart`
- `lib/services/tournament_service.dart`
- `lib/screens/admin/tabs/tournament/`
- `lib/screens/admin/tabs/pronos/world_cup_partner_admin_section.dart`
- `lib/features/home/presentation/screens/parts/home_secondary_tournament.dart`
- `lib/widgets/powered_by_partner_encart.dart` (seul consommateur = CdM)

### Cloud Functions
- `functions/tournament_scoring.js`  
  Exports retirés : `recalculateTournamentMatchScoring`, `recalculateWorldCupLeaderboard`, `undoWorldCupMatchScoring`, `fixEstiDvcrMatchDays`  
  Module retiré de `functions/index.js` (+ note dans `tools/split_index.js`)

---

## Nettoyages associés (fichiers conservés, code branché)

| Zone | Changement |
|------|------------|
| Home | Mini-carte CdM + imports rollout / `TournamentService` retirés |
| Admin Settings | Section « Coupe du monde » / `WorldCupTabAdminSection` retirée |
| Admin routes | Alias URL `esti-dvcr`, `estidvcr`, `tournament`, `cdm`, `coupe-du-monde` retirés |
| Admin barrel | Export `tournament_tab` retiré |
| `PoweredByPartnerSettings` | Champs `worldCup*` retirés (partenaire prono conservé) |
| Prono history | Champ `isWorldCup` retiré de `RecentPronoRow` |
| Notifs prefs | Clé `tournamentPronoPoints` retirée |
| Docs | `README.md`, `docs/admin_access.md`, `FEATURES.md`, `HOME_CLEANUP_PROPOSAL.md` |

**Conservé volontairement :** `AdminTabIndex.estiDvcr` / `tournament` (indices stables + redirect soft vers Pronos si deep-link numérique legacy).

---

## Pushback Functions (prod)

- Le **client** ne consomme plus ces callables.
- Les fonctions **déjà déployées** sur Firebase peuvent rester actives jusqu’à undeploy manuel (`firebase functions:delete …`).  
  Ne pas les re-déployer depuis ce monolithe : elles ne sont plus dans le bundle d’export.
- Collections Firestore `tournaments/*`, `esti_dvcr_leagues` : **non migrées / non purgées** (data legacy inerte).

---

## Non touché (hors périmètre)

- Prono championnat (`prono_scoring.js`, UI prono)
- Sponsors / Soutenez DVCR
- Auth, Home cœur (hors mini-carte CdM)
- `dvcr_appli_v2`

---

## Statut

**DONE côté code monorepo.**  
Review : `dvcr-v2/docs/reviews/ESTI_WC_REMOVAL_REVIEW.md`  
**STOP** — pas Sponsors. Awaiting next GO.
