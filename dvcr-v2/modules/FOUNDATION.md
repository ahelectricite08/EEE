# Module 0 — Foundation

**Statut :** livré (code) — awaiting GO Auth  
**Date :** 2026-07-26  
**App :** `dvcr_appli` (`lib/`, `pubspec.yaml`)  
**Plan :** [MODERNIZATION_PLAN.md](../MODERNIZATION_PLAN.md) · [STRATEGY.md](../STRATEGY.md) · [ADR-0004](../ADR-0004-progressive-modernization-in-place.md)  
**Done :** [FOUNDATION_DONE.md](./FOUNDATION_DONE.md) · Review : [FOUNDATION_ARCHITECTURE_REVIEW.md](../docs/reviews/FOUNDATION_ARCHITECTURE_REVIEW.md)

---

## Intent

Poser les **briques réutilisables** de l’architecture cible **sans** migrer de feature métier.  
Sans Foundation, Auth (et tout module suivant) ne peut pas être Feature First + Riverpod de façon cohérente.

---

## IN scope

| Zone | Contenu |
|------|---------|
| **Deps** | `flutter_riverpod` (+ codegen Freezed / `build_runner` si retenu pour le module suivant) |
| **Bootstrap** | `ProviderScope` autour de l’app (smoke démarrage inchangé) |
| **`lib/core/`** | Socle minimal : erreurs app typées (ou façade), éventuelle façade Firebase Auth/Firestore **non métier**, conventions DI |
| **`lib/shared/`** | Placeholders / helpers non métier seulement si déjà besoin immédiat (sinon ne pas inventer) |
| **Conventions** | Feature First documentée ; règle d’import ; pattern Repository + providers |
| **Qualité** | Script Architecture Review branché sur racine `dvcr_appli` ; analyze clean |
| **Tests** | Smoke / override Riverpod de base (pas de couverture métier) |

## OUT of scope

- Toute migration d’écran ou service métier (Auth, Sponsors, Prono, Home…)
- Changement UX / thème produit / navigation produit (GoRouter = plus tard)
- Introduction massive de packages hors stack cible
- Refactor « en passant » de `main_bootstrap` au-delà du strict nécessaire pour `ProviderScope`
- Touch à `dvcr_appli_v2`

---

## Couches / livrables attendus

```
lib/
  core/           # errors, éventuellement firebase facades, result types
  shared/         # uniquement si utile dès Foundation
  main.dart / main_bootstrap.dart  # ProviderScope ; comportement inchangé
```

Pas de `features/*` métier dans ce module.

---

## Definition of Done

- [x] `flutter_riverpod` dans `pubspec` ; analyze clean (périmètre `lib/core` + `main.dart`)
- [x] `ProviderScope` au bootstrap **sans** régression splash / guest / app (diff minimal ; checklist manuelle user)
- [x] `lib/core/` minimal documenté (erreurs et/ou facades) — pas de God object
- [x] Conventions Feature First + Riverpod rappelées dans docs / commentaires ciblés
- [x] Script review : AppRoot = racine `dvcr_appli`
- [x] **Aucune** feature métier migrée « en passant »
- [x] **Architecture Review PASS**
- [ ] **GO user** écrit (validation manuelle non-régression)

## Non-régression (checklist manuelle)

- [ ] Lancement app (splash → guest ou app selon session)
- [ ] Mode invité actus accessible
- [ ] Session Firebase existante toujours reconnue au cold start
- [ ] Thème / identité visuelle inchangés
- [ ] Routes nommées existantes toujours joignables

---

## Risques

| Risque | Mitigation |
|--------|------------|
| `ProviderScope` casse le bootstrap | Diff minimal ; smoke launch ; pas de providers métier encore |
| Scope qui dérive vers Auth | Gate stricte OUT ; Auth = Module 1 séparé |
| Sur-ingénierie `core/` | Minimal viable ; enrichir au besoin des modules suivants |

---

*Docs only — aucun code applicatif dans ce fichier.*
