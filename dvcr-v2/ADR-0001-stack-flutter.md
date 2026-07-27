# ADR-0001 — Stack Flutter (cible architecture)

**Statut :** Accepté (stack) — **partie « rewrite from scratch » supersédée par [ADR-0004](./ADR-0004-progressive-modernization-in-place.md)**  
**Date :** 2026-07-26  
**Décideurs :** Lead Architect DVCR

> **Mise à jour 2026-07-26 :** la **stack** ci-dessous reste la cible.  
> L’organisation « nouveau projet Flutter / V1 intangible » est **abandonnée** au profit de la **modernisation in-place** de `dvcr_appli` (ADR-0004, `MODERNIZATION_PLAN.md`, `STRATEGY.md`).

---

## Contexte

L’application DVCR (Flutter + Firebase) est fonctionnellement riche mais structurellement endettée (voir `DVCR_AUDIT.md`) : architecture hybride inachevée, peu de tests, Maps Firestore dans l’UI, navigation fragile.

Un draft avait envisagé **Next.js** — **rejeté**. La cible reste Flutter mobile-first + admin Flutter Web, Firebase, Feature First industrialisable, multi-club.

---

## Décision (toujours valide)

1. **Stack imposée :** Flutter (dernière stable), Dart, Firebase, Riverpod, GoRouter (cible navigation), Dio ou HTTP pour APIs externes seulement, Freezed, json_serializable, flutter_lints, build_runner, Material 3, GitHub Actions, tests unit/widget + Firebase Emulator.
2. **Architecture :** Feature First ; couches Widget → Provider → UseCase → Repository → Firebase ; tenant-ready sur le code modernisé.
3. **Rejeter** Next.js / React comme stack principale.

## Décision supersédée (voir ADR-0004)

~~Reconstruire from scratch dans `dvcr-v2/app` / second repo ; interdiction de moderniser `lib/` in-place.~~  
→ **Modernisation progressive in-place** de `dvcr_appli`.

Détails d’exécution : `ARCHITECTURE.md`, `MODERNIZATION_PLAN.md`, `SCOPE_V2.md`, `STRATEGY.md`.  
Périmètre événements : `ADR-0002`. Gate : `ADR-0003`. Stratégie repo : `ADR-0004`.

---

## Conséquences

### Positives (stack)

- Une base Flutter iOS / Android / Web admin.
- Réutilisation Functions / Firestore.
- Industrialisation (Riverpod, Freezed, CI) **introduite progressivement** (Module Foundation).

### Coûts (post–ADR-0004)

- Coexistence temporaire `screens/` + `features/` + `services/`.
- Discipline module par module pour ne pas reproduire / étendre la dette.

### Suivi

- Pas de refactor code sans GO ADR-0004 + module (`MODERNIZATION_PLAN.md`).
- Écarts package → ADR + `PACKAGE_POLICY.md`.
- Pas de modules permanents World Cup / Esti / tournois (ADR-0002).
- Fin de chaque module → Architecture Review PASS (ADR-0003).
