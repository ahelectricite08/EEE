# Home — livré (tranche 2)

**Module :** 2 — Home / Accueil  
**Date :** 2026-07-26  
**App :** `dvcr_appli` (`lib/`, `pubspec.yaml`)  
**Statut :** code livré — **Architecture Review PASS** — awaiting **GO user**  
**Review T2 :** [HOME_T2_ARCHITECTURE_REVIEW.md](../docs/reviews/HOME_T2_ARCHITECTURE_REVIEW.md)  
**Review T1 :** [HOME_ARCHITECTURE_REVIEW.md](../docs/reviews/HOME_ARCHITECTURE_REVIEW.md)  
**Cleanup (no delete) :** [HOME_CLEANUP_PROPOSAL.md](./HOME_CLEANUP_PROPOSAL.md)  
**Spec :** [HOME.md](./HOME.md)

---

## Ce qui a été livré (T2)

| Brique | Détail |
|--------|--------|
| **UI Feature First** | `lib/features/home/presentation/screens/` + `widgets/` |
| **Split ≤ 300 L** | Parts / mixins sur `_HomeScreenController` ; shell widgets découpés |
| **Adapters hub** | Live / Match catalog / Articles feed (sans migrer ces modules) |
| **Datasources Home** | Stadium, match lookup, prediction, prono leaderboard |
| **Auth hero** | `authSessionProvider` (barrel Auth) pour icône profil |
| **Façades** | `screens/home/*` → re-exports Auth-style ; placeholders anciens parts |
| **Tests** | Domain + smoke adapters |
| **Review** | **PASS** (hardcode copy préexistante documentée ; FAILs prono hors périmètre) |

---

## Arborescence (extrait)

```
lib/features/home/
  home.dart
  data/adapters/          # Live / Match / Articles hub
  data/datasources/       # sections, banner, stadium, lookup, prediction, leaderboard
  data/mappers|repositories/
  domain/…
  presentation/
    home_providers.dart
    screens/home_screen.dart + parts/
    widgets/home_palette|motion|shell_*
lib/screens/home/         # re-exports + placeholders (cleanup GO séparé)
```

---

## Volontairement hors Home

- Modules Matchs / Articles / Live complets (adapters seulement)
- Industrialisation World Cup / Esti (ADR-0002)
- GoRouter, Sponsors, Prono

---

## Dette restante (justifiée)

| Item | Justification |
|------|----------------|
| Placeholders / re-exports `screens/home` | Compat imports — voir cleanup proposal |
| Façades `HomeSectionsService` / `HomeBannerService` | Admin / legacy |
| Copy Sedan/CSSA | Parité UX ; TenantConfig plus tard |
| `FirebaseAuth` dans NextMatchCard | Hors hero ; session partielle |
| WC mini-card | ADR-0002 |

**Dette technique « UI encore sous screens/home » (T1) : soldée** (impl sous features ; façades minces).

---

## Commandes

```powershell
flutter analyze lib/features/home lib/screens/home lib/services/home_sections_service.dart lib/services/home_banner_service.dart
flutter test test/features/home
cd dvcr-v2
.\scripts\architecture_review.ps1 -AppRoot .. -StrictFeatures
```

---

## Suite

**STOP** — validation user (parité Accueil) → **GO Sponsors** (ou GO cleanup Home) écrit avant module suivant.
