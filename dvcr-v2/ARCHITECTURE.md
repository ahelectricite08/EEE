# DVCR — Architecture cible (modernisation in-place)

**Statut :** document directeur — aligné [ADR-0004](./ADR-0004-progressive-modernization-in-place.md)  
**Date :** 2026-07-26 (révisé : plus de rewrite séparée)  
**Compléments :** `STRATEGY.md`, `SCOPE_V2.md`, `MODERNIZATION_PLAN.md`, `ADR-0001` … `ADR-0004`, `ARCHITECTURE_REVIEW.md`, `PACKAGE_POLICY.md`, `FEATURES.md`, `DVCR_AUDIT.md`.

> **V2 = architecture cible dans `dvcr_appli`**, pas un second repo.  
> App de vérité : racine du monorepo (`lib/`, `pubspec.yaml`).  
> `dvcr-v2/` = **docs uniquement**. `dvcr_appli_v2` = **gelé**.

---

## 1. Vision

Moderniser progressivement l’app DVCR **existante** pour atteindre une base industrialisable (Feature First, couches strictes, testabilité), **sans** casser l’UX ni l’identité.

| Capacité | Intention |
|----------|-----------|
| Continuité produit | Même app prod ; refactor interne module par module |
| Tenant | Club = config — zéro hardcode **dans le code nouveau / refactoré** |
| Parité fonctionnelle | `FEATURES.md` ✅ — comportement conservé |
| Industrialisation | Riverpod, Repository, Freezed, CI, emulators — **introduction progressive** |
| Données | Firebase via ACL / mappers — pas de big-bang |
| Extensions | Événements ponctuels hors core (ADR-0002) |

### Multi-club (règle dure sur le code touché)

- CSSA / Sedan = premier tenant de référence.
- Changement de club = `TenantConfig`, pas un fork.
- Ne pas **étendre** la dette hardcode historique.

---

## 2. Principes

1. **Refactor, pas rewrite** — conserver comportement ; transformer structure (ADR-0004).
2. **SOLID** — use cases petits, repositories injectés, UI ignorante du stockage.
3. **Open/Closed** — étendre par features / adapters, pas God services.
4. **Feature isolation** — bounded context ; pas d’imports croisés internes.
5. **Dependency rule** — `presentation` → `domain` ← `data`.
6. **Explicit over clever** — pas de singletons métier ; DI Riverpod.
7. **Tenant-first** — sur le périmètre modernisé.
8. **Compatibilité data** — modèles propres + mappers legacy.
9. **Fichiers ≤ 300 lignes** — hors générés ; découper le code **touché**.
10. **Core mince** — pas de modules permanents événementiels (ADR-0002).
11. **Un module à la fois** — Architecture Review PASS avant GO user.

### Couche applicative (cible)

```
Widget (presentation)
  → Provider / Notifier (Riverpod)
  → UseCase (domain)
    → Repository (interface domain / impl data)
      → Firebase | HTTP externe
```

Stack : Flutter / Firebase / Riverpod / (GoRouter en cible long terme) / Freezed / flutter_lints / build_runner / Material 3 — ADR-0001 + `PACKAGE_POLICY.md`.  
**État 2026-07 :** Riverpod et Freezed **pas encore** dans le `pubspec` → Module Foundation (`MODERNIZATION_PLAN.md`).

---

## 3. Structure des dossiers & règles d’import

### Arborescence `lib/` — cible **progressive**

> Ne **pas** créer tous les `features/*` vides.  
> Migrer depuis `screens/` + `services/` + `models/` **au moment** du module.

```
lib/                          # dvcr_appli — SOURCE DE VÉRITÉ
  main.dart
  main_bootstrap.dart
  core/                       # densifier progressivement
  shared/
  theme/                      # identité existante — conserver
  navigation/                 # actuel ; GoRouter = module dédié plus tard
  features/
    sponsors/                 # 1er feature proposé
    prono/                    # déjà amorcé
    admin/                    # partiel
    auth/ …
  screens/                    # legacy — migrer vers features/*/presentation
  services/                   # legacy — migrer vers data/domain
  models/                     # legacy — migrer vers domain + Freezed
  widgets/
```

**Hors industrialisation core :** `world_cup`, `esti`, tournois événementiels — ADR-0002.

### Convention interne d’une feature

```
features/<module>/
  data/
  domain/
  presentation/
  <module>.dart               # exports publics minimaux
```

### Règles d’import

| Depuis → Vers | Autorisé ? |
|---------------|------------|
| `features/A` → `core`, `shared`, `theme`, navigation (types) | Oui |
| `features/A` → intérieur `features/B` | **Non** |
| `features/A` → barrel `features/B/<b>.dart` | Oui, **rare** |
| `shared` / `core` → `features/*` | **Non** |
| `presentation` → Firestore / HTTP directement | **Non** (cible sur code touché) |
| `domain` → widgets / SDK Firestore | **Non** |

Pendant la transition, du code legacy hors module ouvert peut encore violer ces règles — **interdit d’aggraver** ; le module en cours doit **converger**.

### Pattern : contrats + API publique minimale

Home / Admin = compositeurs via providers / barrels, pas imports profonds.

---

## 4. State management — Riverpod (cible)

Introduit au **Module Foundation**. Ensuite, tout nouvel état métier du module ouvert passe par Riverpod.

| Besoin | Type typique |
|--------|----------------|
| Use case / repository | `Provider` |
| Session / config | `StreamProvider` / `AsyncNotifier` |
| UI éphémère | `Notifier` local |
| Liste + filtres | `AsyncNotifier` feature-scoped |

### Règles

- Pas de logique métier lourde dans `build()`.
- `ref.watch` UI ; `ref.read` actions.
- Overrides en tests.
- Interdit d’**étendre** Controllers ChangeNotifier / services static métier sur le périmètre modernisé.

---

## 5. Navigation

- **Court terme :** conserver la navigation existante (`main_navigation`, shells) pour ne pas mixer risques.
- **Cible :** GoRouter centralisé (`lib/router/` ou évolution de `navigation/`) — module dédié, pas un side-effect d’un autre module.
- Pas de nouvelles routes événementielles permanentes (ADR-0002).

---

## 6. Data layer

### DTO Freezed / entities

- DTO = wire ; Entity = canon métier.
- Codegen ; ne pas éditer `*.freezed.dart` / `*.g.dart` à la main.

### Mappers (ACL)

```
Firestore / JSON → Dto → Mapper.toDomain() → Entity
Entity → Mapper.toLegacyWrite() → Map (Functions-compatible)
```

### Repositories / Use cases

- Interface `domain/` ; impl `data/`.
- Streams typés vers l’UI — pas de `QuerySnapshot` / `DocumentSnapshot` dans le **contrat domain** du code modernisé.
- Use case = une intention ; pas de `BuildContext`.

### HTTP

- SDK Firebase pour Auth / Firestore / Functions.
- HTTP externe seulement pour FFF / APIs hors Firebase.

---

## 7. Config tenant

`TenantConfig` (cible Freezed) agrège branding, sport, flags, RBAC, sponsors…  
Flags événementiels V1 ≠ modules core (ADR-0002).

---

## 8. Tests, Emulators, CI

| Niveau | Contenu |
|--------|---------|
| Unit | Mappers, use cases |
| Widget | Smoke pages du module |
| Emulator | Repos si data touchée |
| CI | format/analyze/test — renforcer progressivement |

DoD module : analyze clean, tests exigés, **Architecture Review PASS**, GO user.

---

## 9. Definition of Done / Architecture Review

Un module est **terminé** seulement si :

1. Comportement `FEATURES.md` ✅ du périmètre **inchangé** (parité).
2. Couches respectées sur le code **touché**.
3. Pas d’import croisé illégal introduit.
4. Fichiers touchés ≤ 300 L (hors codegen) ou plan de découpe immédiat.
5. Tests verts.
6. Critères `MODERNIZATION_PLAN.md` passés.
7. **Architecture Review PASS** (`ARCHITECTURE_REVIEW.md`, ADR-0003) ; script sur **racine `dvcr_appli`**.
8. **GO utilisateur** après PASS.
9. Pas de hardcode tenant **nouveau**.
10. Pas d’événementiel permanent « au cas où ».
11. Dettes acceptées consignées.

Sans Review PASS → pas terminé. Sans GO → pas de module suivant.

---

## 10. Cycle de travail

```
Analyse → Conception → Refactor
  → Tests → Architecture Review
  → Corrections si FAIL
  → Cleanup Proposal (ADR-0005 — proposals only)
  → Validation suppressions (optionnel, GO item/batch)
  → Validation utilisateur → Documentation
  → module suivant (après GO)
```

L’architecte refuse rewrite séparée, redesign UX non demandé, scaffold massif, et tout ce qui dégrade Feature First / couches / ADR-0002.  
**Cleanup :** ne jamais supprimer / fusionner du code applicatif sans GO user explicite ([ADR-0005](./ADR-0005-cleanup-requires-user-go.md)).

---

## 11. Hors scope / Extensions

| Exclu | Raison |
|-------|--------|
| Second app / `dvcr-v2/app` / dev dans `dvcr_appli_v2` | ADR-0004 |
| World Cup / Esti / tournois permanents | ADR-0002 |
| Scaffold features vides | Anti-pattern |
| Code refactor avant GO ADR-0004 | Gate |
| Redesign UX non demandé | Parité |

Pattern extension : package / flag hors core — ADR-0002.

---

## 12. Règles d’exclusion legacy

1. Comportement cœur utile → **conserver** (refactor autour).
2. Surface morte / événementielle → **ne pas industrialiser**.
3. Doute → ⚠️ dans FEATURES ; défaut = ne pas étendre.
4. Functions événementielles → ne pas brancher le client core modernisé dessus.

---

## 13. Pushbacks architecturaux

| Tentation | Décision | Alternative |
|-----------|----------|-------------|
| Rewrite / second repo | **Refusé** | In-place (ADR-0004) |
| Développer dans `dvcr_appli_v2` | **Refusé** | Gelé |
| Réécrire une feature from scratch | **Refusé** | Refactor couches |
| Toutes les features vides | **Refusé** | Un module à la fois |
| Esti / CdM « au cas où » | **Refusé** | ADR-0002 |
| Module terminé sans Review PASS | **Refusé** | ADR-0003 |
| Next.js | **Refusé** | Flutter |
| Dio pour Firestore | **Refusé** | SDK Firebase |
| Maps Firestore dans UI **nouvelle** | **Refusé** | DTO + Entity |
| Singletons métier **nouveaux** | **Refusé** | Riverpod |
| Fichiers > 300 L sur code touché | **Refusé** | Découpage |
| Redesign UX non demandé | **Refusé** | Parité |
| Secrets / club en dur (nouveau) | **Refusé** | Config |

Écart durable → ADR daté.

---

## 14. Relation docs / code

| Artefact | Rôle |
|----------|------|
| `lib/` + `functions/` | **Source de vérité** produit |
| `dvcr-v2/*.md` | Spec architecture + gates |
| `dvcr-v2/app/` | **Ne pas créer** comme app V2 |
| `dvcr_appli_v2` | Gelé / abandonné |

---

*Architecture — pas de code applicatif dans ce document.*
