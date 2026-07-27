# Cleanup Proposal — Module : Foundation

**Module :** 0 — Foundation  
**Date :** 2026-07-26  
**Review liée :** [`docs/reviews/FOUNDATION_ARCHITECTURE_REVIEW.md`](../docs/reviews/FOUNDATION_ARCHITECTURE_REVIEW.md)  
**Done :** [`FOUNDATION_DONE.md`](./FOUNDATION_DONE.md)  
**ADR :** [ADR-0005](../ADR-0005-cleanup-requires-user-go.md)  
**Statut global :** **Awaiting user GO** — **aucune suppression effectuée**

---

## Contexte

Foundation a introduit `ProviderScope`, `lib/core/` (config, `AppFailure` / `Result`, conventions DI) et les deps Freezed — **sans** feature métier. Peu de doublons internes ; la dette restante est surtout hors périmètre (services static, GoRouter, `features/prono` hybride). Cleanup = affiner le socle, pas supprimer de feature.

---

## Candidats

| Item | Type | Chemins | Risque | Recommandation | Statut |
|------|------|---------|--------|----------------|--------|
| `foundationReadyProvider` (marqueur smoke / override only) | mort (prod) | `lib/core/di/core_providers.dart` ; usage réel = `test/core/foundation_core_test.dart` | Faible | **garder façade** (utile tests / convention) ou **différer** suppression tant que smoke Foundation utile | **Awaiting user GO** |
| Absence volontaire `lib/shared/` | legacy (non-créé) | — | Nul | **différer** — créer seulement au 1er besoin partagé réel | **Awaiting user GO** |
| GoRouter non introduit | legacy (nav) | `lib/main.dart` / `lib/app/app_router.dart` (named routes) | Élevé si forcé | **différer** — module Navigation (dette acceptée Foundation) | **Awaiting user GO** |
| Sibling `dvcr_appli_v2` (hors monorepo) | legacy / mort (stratégie) | `C:\Users\axeld\Music\dvcr_appli_v2` (sibling) | Moyen (ops) | **différer** — suppression repo uniquement sur GO user (ADR-0004) | **Awaiting user GO** |
| Deps Freezed sans modèle Foundation | doublon apparent | `pubspec.yaml` (`freezed*`, `json_*`, `build_runner`) | Faible | **garder façade** — prep Auth+ déjà consommée ; ne pas retirer | **Awaiting user GO** |
| Packages media/UI legacy hors stack de base | legacy | `pubspec.yaml` (WARN script review) | Moyen | **différer** — hors Foundation ; ADR si un jour on retire | **Awaiting user GO** |
| Services static / ChangeNotifier pré-Auth | legacy | `lib/services/*` | Élevé | **différer** — migration module par module (Auth déjà partiel) | **Awaiting user GO** |

---

## Batches GO suggérés

| Batch | Items | Prérequis |
|-------|-------|-----------|
| F0 — aucun delete immédiat | — | Validation fonctionnelle Foundation suffit |
| F1 — optionnel | Retirer `foundationReadyProvider` si jugé bruit | GO écrit + tests core adaptés |
| F2 — ops | Décision sur sibling `dvcr_appli_v2` | GO user explicite hors app |

---

## Rappel

**Zéro suppression effectuée** dans ce chantier docs. Objectif : une seule implémentation par brique — Foundation n’a quasiment rien à delete aujourd’hui.

*Proposal only — pas de code applicatif modifié.*
