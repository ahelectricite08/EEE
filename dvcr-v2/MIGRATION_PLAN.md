# DVCR V2 — Plan de migration (Flutter)

> ## SUPERSEDED — 2026-07-26
>
> Ce document décrit l’ancienne stratégie **rewrite V2 séparée** (`dvcr-v2/app/`, second codebase).
>
> **Remplacé par :**
> - [`ADR-0004-progressive-modernization-in-place.md`](./ADR-0004-progressive-modernization-in-place.md)
> - [`MODERNIZATION_PLAN.md`](./MODERNIZATION_PLAN.md)
> - [`STRATEGY.md`](./STRATEGY.md)
>
> Ne plus exécuter ce plan. Conservé pour historique uniquement.

---

**Objectif (historique) :** reconstruire DVCR **from scratch** sur Flutter (Feature First), en reproduisant le **cœur fonctionnel** (pas les événements ponctuels), avec une base industrialisable, multi-club (tenant-ready) et commercialisable.  
**Référence fonctionnelle :** l’app Flutter actuelle + `FEATURES.md` (annotations ✅ / ⛔ / ⚠️). **Ne pas copier le code** — en extraire parcours, règles métier et contrats data du cœur.  
**Périmètre :** `SCOPE_V2.md` + `ADR-0002-no-permanent-event-modules.md`.  
**Gate fin de module :** `ARCHITECTURE_REVIEW.md` + `ADR-0003-architecture-review-gate.md` (PASS obligatoire).  
**Base de code V2 :** nouvelle arborescence sous `dvcr-v2/` (projet Flutter à créer **après** validation de l’architecture ; racine documentée : `dvcr-v2/app/`).  
**Date :** 2026-07-26  
**Principe :** un module à la fois ; **validation utilisateur obligatoire** avant le module suivant.

> **Obsolète :** toute mention Next.js / Tailwind / Shadcn / React Query / Zustand dans d’anciens drafts. La stack imposée est **Flutter + Firebase**. Voir `ARCHITECTURE.md` et `ADR-0001-stack-flutter.md`.  
> **Aussi obsolète (ADR-0004) :** rewrite séparée / `dvcr-v2/app` comme root applicatif.

---

## 1. Stack cible (imposée)

| Couche | Choix | Rôle |
|--------|-------|------|
| Framework | **Flutter** (dernière stable) | Clients iOS / Android / Web (admin) |
| Langage | **Dart** | Contrats, UI, tests |
| Backend | **Firebase** (Auth, Firestore, Storage, FCM, Cloud Functions existantes) | Compatibilité données ; Functions conservées en phase 1 |
| State | **Riverpod** | DI + état ; providers par couche |
| Navigation | **GoRouter** | Routes déclaratives, deep-links, guards |
| HTTP externe | **Dio** | FFF / YouTube / APIs hors Firestore uniquement |
| Modèles | **Freezed** + **json_serializable** | DTO immuables, unions, codegen |
| Qualité | **flutter_lints**, **build_runner** | Lint + génération |
| Design | **Material 3** | Thème tenant-driven (couleurs, logos) |
| CI | **GitHub Actions** | analyze, tests, (plus tard) build |
| Tests | Unit + widget + **Firebase Emulator** | Parité qualité vs dette V1 |

### Couches obligatoires

```
Widget → Provider (Riverpod) → UseCase → Repository → Firebase / Dio
```

### Interdits (non négociables)

- `setState` global / état métier dans les widgets
- God classes / services statiques métier
- Singletons métier
- `Map` Firestore bruts dans l’UI
- Logique métier dans les widgets
- `Navigator.push` dispersé (tout passe par GoRouter)
- Imports croisés entre features
- Fichiers > **300 lignes** (hors générés)
- Modules permanents World Cup / Esti / tournois temporaires
- Routes historiques « compat only »
- Scaffold de **toutes** les features vides

### Hors scope immédiat

- Génération du projet Flutter (`flutter create`) **avant** validation archi utilisateur
- Rewrite destructif des collections Firestore
- Refonte UX marketing (mêmes parcours cœur / mêmes infos)
- Portage Esti / CdM / tournois « au cas où » (ADR-0002)

---

## 2. Architecture Feature First — arborescence cible

> Documenter la structure **cible**. **Ne pas** créer tous les dossiers `features/*` vides au Module 0.

```
dvcr-v2/
  ADR-0001-stack-flutter.md
  ADR-0002-no-permanent-event-modules.md
  ADR-0003-architecture-review-gate.md
  ARCHITECTURE.md
  ARCHITECTURE_REVIEW.md
  SCOPE_V2.md
  DVCR_AUDIT.md
  FEATURES.md
  MIGRATION_PLAN.md
  PACKAGE_POLICY.md
  scripts/
    architecture_review.ps1
    architecture_review_checklist.md
  (futur) app Flutter — racine documentée : dvcr-v2/app/
  lib/
    main.dart
    bootstrap.dart
    core/
    shared/
    router/
    theme/
    features/          # ajoutés module par module — pas en masse vide
      auth/
      profile/
      home/
      matches/
      clubs/
      live/
      stats/
      articles/
      streaming/
      notifications/
      chat/
      pronos/
      xp/
      sponsors/
      share/
      benevoles/
      adherents/
      admin/
  test/
  integration_test/
  .github/workflows/
```

### Convention interne d’une feature

```
features/<module>/
  data/
    datasources/
    dto/
    mappers/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
  presentation/
    providers/
    pages/
    widgets/
  <module>.dart
```

**Règle d’import :** une feature **n’importe pas** l’intérieur d’une autre. Voir `ARCHITECTURE.md`.

**Extensions événementielles** (si un jour) : package / feature optionnelle **hors** cette liste cœur — jamais `features/world_cup` ni `features/esti` dans le socle.

---

## 3. Modules indépendants & dépendances

| Module V2 | Couvre (réf. `FEATURES.md` ✅) | Dépend de |
|-----------|-------------------------------|-----------|
| **0 — Scaffold + Core** | Bootstrap Firebase, tenant config, theme M3, GoRouter shell, Riverpod DI, lints, CI, emulators | — |
| **Auth** | Login, register, guest, session, guards, claims refresh | Core |
| **Profile** | Profil, public, favorites, account deletion, prefs | Auth |
| **Clubs** | Teams, stades, logos (lecture / admin plus tard) | Core |
| **Matches** | Calendrier, détail, classement, sync FFF client | Clubs, Core |
| **Articles** | Liste, détail, commentaires, guest Actus | Auth (commentaires) |
| **Home** | Feed, hero live/émission/bannière, sections | Matches, Live lecture, Articles, Sponsors |
| **Streaming** | DVCR TV, videos, featured | Core |
| **Live** | Conso `live/current`, MOTM, notes, lien salon | Matches, Auth |
| **Stats** | Affichage stats publiées (+ admin workbench plus tard) | Matches, Auth |
| **Notifications** | Prefs, centre, FCM | Auth |
| **Pronos** | Hub championnat, predict, leaderboard, saison, social amis/duels/ligues | Matches, Auth |
| **XP** | Niveaux, badges, referral UI | Auth |
| **Chat** | Salons, messages, modération light | Auth |
| **Sponsors / Share** | Encars, templates partage | Core |
| **Benevoles / Adherents** | PDF Team DVCR, statut adhérent | Auth |
| **Admin** | Shell RBAC + onglets composés depuis features cœur | Auth + modules métier |

L’admin **compose** les features ; il ne re-implémente pas la logique métier.

### Explicitement hors roadmap core

| Exclu | Traitement |
|-------|------------|
| World Cup / Coupe du Monde | Extension éventuelle (ADR-0002) — **pas** un module N |
| Esti’DVCR | Idem |
| Tournois temporaires | Idem |
| Alias routes esti/cdm | Non portés |

---

## 4. Cycle obligatoire par module

```
Analyse → Conception → Architecture fine → Développement
  → Tests → Architecture Review (obligatoire)
  → Corrections si FAIL → (rejouer Review jusqu’à PASS)
  → Validation utilisateur → Documentation
  → module suivant (seulement après GO utilisateur)
```

| Étape | Livrable |
|-------|----------|
| **Analyse** | Parcours UX (`FEATURES.md` ✅), collections, rules, Functions touchées |
| **Conception** | Entités Freezed, mappers legacy, use cases, critères d’acceptation |
| **Architecture** | Providers Riverpod, routes GoRouter, boundaries imports |
| **Développement** | Feature isolée + ACL data (pas de big-bang DB) |
| **Tests** | Unit (mappers/usecases), widget (pages critiques), emulator (repo) |
| **Architecture Review** | Checklist `ARCHITECTURE_REVIEW.md` + script `scripts/architecture_review.ps1` (filet) — **PASS obligatoire** (ADR-0003) |
| **Corrections** | Toute dérive ADR / archi / SCOPE / packages / Clean Architecture corrigée **avant** PASS |
| **Validation** | Démo utilisateur / staff — **GO / NO-GO** écrit (uniquement après Review PASS) |
| **Documentation** | Notes module (mapping, flags, dettes acceptées) + entrée historique review |

**Un module n’est JAMAIS « terminé » sans Architecture Review PASS.**  
Sans PASS → pas de Validation utilisateur conclusive, pas de module suivant.

**Un module à la fois.** Interdit de scaffolder toutes les features vides « pour gagner du temps ».

---

## 5. Multi-club / white-label

Dès le **Module 0**, aucune valeur club hardcodée (nom, couleurs, logos, IDs compétition, partenaires).

| Concept | Source cible | Usage |
|---------|--------------|-------|
| `TenantConfig` | Firestore config / remote + defaults code | Branding, feature flags, saisons |
| Couleurs / logos | Tenant | `theme/` Material 3 |
| Compétitions / saisons | Config FFF + lifecycle | Matches, Pronos |
| Rôles / permissions | `config/role_permissions` | Auth / Admin |
| Partenaires | `config/sponsors` | Sponsors / Share |

CSSA / Sedan = **premier tenant** de démo, pas le centre du modèle.

---

## 6. Compatibilité données Firebase (ACL)

### Principes

1. **Pas de migration destructive** des collections en production.
2. Modèles domaine V2 **propres** + **mappers** lecture/écriture vers docs legacy **du cœur**.
3. Écriture : une forme canonique choisie + miroir temporaire si Functions attendent l’ancien shape.
4. Functions Node actuelles **conservées** en phase 1 (scoring championnat, FFF, pushes, TV).
5. Collections / Functions **événementielles** (`tournaments`, `esti_dvcr_leagues`, `tournament_scoring`…) : **non consommées** par le client V2 core.

### Mapping (exemples cœur)

| Canon V2 | Legacy Firestore | Stratégie |
|----------|------------------|-----------|
| `score.home` / `score.away` | `score1`/`score2` **ou** `scoreHome`/`scoreAway` | Lecture multi-alias ; écriture contrôlée |
| `roles: List<UserRole>` | `roles[]` + `role` | Parser unique dans Auth/Profile |
| `MatchStatus` | `upcoming` / `live` / `finished` | Enum Freezed |
| `LiveSession` | `live/current`, `live/emission` | Ids stables |
| `StatsSheet` | `match_stats/{matchId}` | Séparé de `Match` |
| `AppConfig` / `TenantConfig` | `app_config/*`, `app_settings`, `config/*` | Façade repository |
| Chat | `chat_salons` / `messages` | Ignorer legacy `chat` |
| Prono season | `prono_seasons/current` | Id `current` conservé |

Correctifs rules/storage (couplés aux modules concernés, sans bloquer le scaffold) :

- Rules `vote_history`
- Storage `home_banner/**`
- Clarifier / retirer rules orphelines `competitions` / `fixtures`

---

## 7. Ordre de migration recommandé

Ordre dicté par **dépendances Flutter/Firebase** et **réduction de risque**.  
**Aucun** module World Cup / Esti / tournois dans cette file.

| # | Module | Pourquoi | Risque |
|---|--------|----------|--------|
| **0** | **Scaffold + Core** (tenant, theme, router shell, Firebase, Riverpod, lints, CI, emulators) | Socle avant tout métier | — |
| **1** | **Auth** (+ guest, guards) | Porte d’entrée gated | Moyen |
| **2** | **Clubs + Matches (lecture)** + classement | Cœur métier lecture | Moyen |
| **3** | **Articles** (lecture + commentaires) | Contenu public / guest | Faible |
| **4** | **Profile** minimal | Compte, prefs | Faible |
| **5** | **Home** (composition) | Agrège live résumé + actus + résultats | Moyen |
| **6** | **Streaming (DVCR TV)** | Peu couplé | Faible |
| **7** | **Live (consommation)** | Temps réel | Moyen |
| **8** | **Notifications** | FCM | Moyen |
| **9** | **Pronos** (championnat + social) | Dépend Matches | Élevé |
| **10** | **XP / Badges / Referral** | Transverse | Moyen |
| **11** | **Chat** | Temps réel + modération | Élevé |
| **12** | **Sponsors / Share / Benevoles / Adherents** | Niche / transverse | Faible–Moyen |
| **13** | **Admin shell + RBAC** | Porte staff | Élevé |
| **14+** | Admin Matches / Direct / Stats / Contenu / Ops | Écritures critiques | Élevé → Très élevé |

### Les 3 premiers modules **feature** (après Module 0)

1. **Auth**  
2. **Clubs + Matches (lecture)**  
3. **Articles**

Puis Profile → Home → Streaming → Live lecture.

**Admin Direct** et **Pronos** uniquement après lecture stable Matches/Live.

### Pattern extension (hors file core)

Si un événement ponctuel est décidé plus tard : livrable **indépendant** (package / flag), hors cette roadmap — voir ADR-0002. **Ne pas** l’insérer comme « Module N » du core.

---

## 8. Critères de validation par module

### Module 0 — Scaffold + Core

- [ ] Projet Flutter analysable (`flutter analyze` CI vert) sous `dvcr-v2/app/`
- [ ] Firebase bootstrap (options par flavor / env documentées)
- [ ] `TenantConfig` chargé sans hardcode club
- [ ] Theme Material 3 dérivé du tenant
- [ ] GoRouter shell (placeholders onglets) + deep-link smoke
- [ ] Riverpod root + overrides test
- [ ] Emulators documentés / scripts
- [ ] Aucune feature métier hors stubs autorisés
- [ ] **Aucun** dossier / route World Cup, Esti, tournois
- [ ] Politique packages respectée (`PACKAGE_POLICY.md`)
- [ ] **Architecture Review PASS** (`ARCHITECTURE_REVIEW.md` + script si applicable)

### Auth

- [ ] Login / register / logout / guest Actus
- [ ] Session persistée ; refresh claims staff si applicable
- [ ] Guards GoRouter user vs admin vs guest
- [ ] Pas de Map Auth/user dans l’UI

### Clubs + Matches (lecture)

- [ ] Calendrier à venir / résultats alignés V1 cœur (mêmes filtres)
- [ ] Détail : score, statut, replay, stats si `showStats`
- [ ] Classement = `ranking`
- [ ] Adapters scores multi-alias
- [ ] Sync on-demand ne régresse pas (throttle)

### Articles

- [ ] Liste / détail / catégories
- [ ] Commentaires user connecté
- [ ] Guest Actus opérationnel
- [ ] Parité contenu déjà en base (Wix)

### Home / Live / Pronos / Admin Direct / Chat / Notifs / RBAC

Critères détaillés en conception de chaque module. Toujours : **pas de régression** vs `FEATURES.md` ✅, tests verts, **Architecture Review PASS**, validation utilisateur écrite. Items ⛔ ignorés volontairement.

### Sécurité transverse (chaque cutover écriture)

- [ ] Pas de secret en clair client
- [ ] Rules emulator pour paths touchés
- [ ] Storage paths couverts

---

## 9. Organisation repo

```
dvcr_appli/                 # monorepo existant
  lib/ …                    # V1 Flutter — INTANGIBLE (réf. fonctionnelle)
  functions/                # Functions partagées phase 1
  dvcr-v2/                  # docs archi + futur projet Flutter V2
```

L’app V1 **reste intacte** jusqu’aux cutovers validés. Ne pas supprimer V1 « pour faire propre ».

---

## 10. Risques & mitigations

| Risque | Mitigation |
|--------|------------|
| Drift champs Firestore | Mappers + tests golden sur fixtures anonymisées |
| Functions shape legacy | Miroir écriture / feature flag write-path |
| Match-day critique | Admin Direct tardif ; checklist staff staging |
| Scope creep redesign | Refuser tout changement UX non demandé |
| Scope creep événements | **Refuser** Esti/CdM/tournois dans le core (ADR-0002) |
| Scaffolding massif features vides | **Refusé** — Module 0 minimal puis un module à la fois |
| Packages hors liste | ADR + `PACKAGE_POLICY.md` |
| Listeners Firestore naïfs | Providers scoped, dispose, pas de stream global unique |
| Hardcode club | Revue Module 0 + lint/convention tenant |
| Code avant GO archi | Gate : pas de `flutter create` sans validation |

---

## 11. Définition de « terminé » V2 (macro)

- [ ] Modules **cœur** `FEATURES.md` ✅ ont une surface Flutter V2 validée
- [ ] Aucun module permanent événementiel (World Cup / Esti / tournois)
- [ ] Admin web peut basculer progressivement vers V2
- [ ] Contrats Freezed pour Match, Live, Prediction, User, Article, TenantConfig
- [ ] Rules/Storage gaps corrigés
- [ ] CI : analyze, unit, widget, emulator smoke
- [ ] Aucune valeur club hardcodée dans `lib/`
- [ ] V1 décommissionnée **uniquement** après validation produit

---

## 12. Méthode de travail (rappel)

1. **Valider l’architecture** (`ARCHITECTURE.md` + `SCOPE_V2.md` + ce plan + `ARCHITECTURE_REVIEW.md`) **avant** `flutter create`.
2. **Module 0** Scaffold + Core — Architecture Review PASS — validation utilisateur — puis Auth — etc.
3. Un module à la fois ; **GO utilisateur** obligatoire ; **Review PASS** avant GO.
4. Cycle complet à chaque module (Analyse → … → Tests → **Architecture Review** → Corrections → Validation → Doc).
5. Même UX fonctionnelle **cœur**, code propre, données compatibles via ACL.
6. Pushbacks : pas de scaffold massif ; pas d’Esti/CdM « au cas où » ; pas de code sans GO archi ; pas de module « terminé » sans Review PASS (ADR-0003).

---

*Document de planification uniquement — aucun code applicatif Flutter V2 dans cette étape.*
