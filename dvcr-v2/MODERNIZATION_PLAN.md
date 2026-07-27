# DVCR — Plan de modernisation progressive (in-place)

**Statut :** plan directeur post–[ADR-0004](./ADR-0004-progressive-modernization-in-place.md)  
**Date :** 2026-07-26 (**amendé** — ordre Foundation → Auth → Accueil)  
**Remplace :** `MIGRATION_PLAN.md` (rewrite V2 séparée — superseded)  
**App cible :** `dvcr_appli` (`lib/`, `functions/`)  
**Docs :** `STRATEGY.md`, `ARCHITECTURE.md`, `SCOPE_V2.md`, `ARCHITECTURE_REVIEW.md`, `PACKAGE_POLICY.md`, `FEATURES.md`, [ADR-0005](./ADR-0005-cleanup-requires-user-go.md)  
**Modules :** [`modules/FOUNDATION.md`](./modules/FOUNDATION.md) · [`modules/AUTH.md`](./modules/AUTH.md) · [`modules/HOME.md`](./modules/HOME.md)

---

## 0. Intent

Moderniser l’**architecture interne** de l’app existante — **refactoring, pas rewrite**.

- **Conserver** comportement UX, identité, features production.
- **Transformer** structure dossiers, couches, state, modèles, testabilité.
- **Un module à la fois** ; ne pas casser les voisins.
- **Ne jamais** repartir de zéro sur une feature qui marche.

---

## 1. Principes — Refactor vs Rewrite

| Refactor (retenu) | Rewrite (abandonné) |
|-------------------|---------------------|
| Même `lib/`, même package `dvcr` | Nouveau projet Flutter (`dvcr-v2/app` / `dvcr_appli_v2`) |
| Comportement figé, structure qui bouge | Recréer écrans « propres » |
| Extraire Repository / Domain autour de l’UI existante | Copier FEATURES.md dans une UI neuve |
| Cutover inexistant (déjà en prod) | Double app + cutover |
| Preuve par tests + parité manuelle | Preuve par reconstruction complète |

### Interdits (non négociables)

- Réécrire une feature from scratch « pour faire propre »
- Changer l’UX / le design sans demande explicite
- Migrer plusieurs modules en parallèle
- Big-bang Firestore destructif
- God services / Maps UI **dans le code nouvellement touché** (dette historique = planifiée, pas étendue)
- Modules événementiels permanents World Cup / Esti / tournois (ADR-0002) — ne pas les « industrialiser » dans le core
- Développer dans `dvcr_appli_v2` (gelé)

### Stack cible (inchangée vs ADR-0001 — introduction progressive)

| Couche | Cible | Note actuelle (2026-07) |
|--------|-------|-------------------------|
| Framework | Flutter + Firebase | Déjà en place |
| State / DI | **Riverpod** | **Absent** du `pubspec` actuel → Module Foundation |
| Modèles | **Freezed** + json_serializable | À introduire |
| Navigation | GoRouter (cible long terme) | Navigation actuelle conservée jusqu’à module dédié |
| HTTP externe | Dio (ou conserver `http` tant que non touché) | Pas de Dio pour Firestore |
| Qualité | flutter_lints, tests, CI | Renforcer par module |

---

## 2. Architecture cible **dans** `lib/` existant

Migration **progressive** des dossiers — ne pas créer toutes les features vides.

```
lib/                          # package dvcr (prod)
  main.dart
  main_bootstrap.dart         # (existant — évolue progressivement)
  core/                       # Module Foundation : errors, facades, DI conventions
  shared/                     # widgets / formatters non métier
  theme/                      # déjà présent — conserver identité
  navigation/                 # actuel — GoRouter plus tard si module dédié
  features/                   # Feature First (cible)
    auth/                     # ← premier module fonctionnel (après Foundation)
      data/
      domain/
      presentation/
    home/                     # composition — après Auth
    sponsors/                 # pattern « petit » une fois Auth validé
    prono/                    # déjà amorcé (data/domain/presentation)
    admin/                    # partiel
    matches/
    …
  screens/                    # legacy UI — migre vers features/*/presentation
  services/                   # legacy — migre vers repositories / use cases
  models/                     # legacy — migre vers domain + Freezed
  widgets/                    # transverse → shared/ ou feature owner
```

### Convention interne d’une feature (cible)

```
features/<module>/
  data/         # datasources, dto, mappers, repositories impl
  domain/       # entities, repository interfaces, usecases
  presentation/ # providers Riverpod, pages, widgets
  <module>.dart # API publique minimale (exports contrôlés)
```

**Règle d’import :** une feature n’importe pas l’intérieur d’une autre. Voir `ARCHITECTURE.md`.

Home / Admin restent **compositeurs** : orchestration via API publiques / providers app, pas imports profonds.

---

## 3. Analyse auth + choix d’ordre (amendement)

### Constats transverses (lecture seule, 2026-07-26)

| Zone | État |
|------|------|
| `lib/screens/` | Monolithe UI historique (home, live, admin, auth, chat…) |
| `lib/services/` | ~60 services, souvent **statiques** + `Map` Firestore |
| `lib/features/prono/` | **Amorcé** Feature First mais incomplet |
| `lib/features/admin/` | Partiel — shell encore dans `screens/admin/` |
| `lib/features/auth/` | **Absent** |
| Riverpod / Freezed / `lib/core/` | **Absents** |
| State management | Pas GetX / Provider package ; `setState` + quelques `ChangeNotifier` |

### Auth — dette **élevée** (détail : [`modules/AUTH.md`](./modules/AUTH.md))

| Signal | Détail |
|--------|--------|
| Service static | `AuthService` (Firebase Auth + Firestore users + messages FR) |
| Bypass | `LoginScreen` → `FirebaseAuth.instance.signIn…` direct (pas `AuthService.signIn`) |
| Couplage | `FirebaseAuth.instance` / `authStateChanges` dans bootstrap, home, chat, admin, prono, dizaines de services |
| Session | Phases `_AppEntry` (`guest` / `register` / `tutorial` / `app`) couplées au SDK |
| Modèles | `UserModel` Map-based ; pas de Session domain ; pas Freezed |
| DI / Riverpod | Aucun |

**Conclusion :** Auth n’est **pas** « déjà propre Feature First ». Exception Sponsors-first **non applicable**.

### Pourquoi Sponsors n’est plus Module 1

La reco initiale « Sponsors = Module 1 » visait un **petit terrain pédagogique** (faible risque, ROI pattern). Elle est **révisée** :

1. Préférence produit / archi : **Foundation → Auth → Accueil** puis modules du simple au complexe.
2. Auth est la **racine de session** de toute l’app ; la moderniser tôt évite de propager le pattern static/`FirebaseAuth.instance` dans les features suivantes.
3. Sponsors reste un excellent **module de validation méthode** *après* Auth (surface petite, isolée) — pas un substitut à Auth tant que celle-ci est en dette élevée.
4. Si un jour Auth était déjà Feature First + Riverpod propre, Sponsors pourrait redeviver le 1er chantier fonctionnel — **ce n’est pas le cas aujourd’hui**.

### Amendement ADR-0004 (ordre)

> **Premier chantier fonctionnel = Auth**, immédiatement après **Foundation**.  
> Sponsors n’est plus le Module 1 recommandé. Voir aussi note en bas d’[ADR-0004](./ADR-0004-progressive-modernization-in-place.md).

---

## 4. Ordre des modules recommandé (ordre final)

| # | Module | Objectif | Risque | Doc |
|---|--------|----------|--------|-----|
| **0** | **Foundation** | Riverpod (+ Freezed si retenu), `ProviderScope`, `core/` minimal, conventions, script review → racine `dvcr_appli` — **sans** feature métier | Faible | [FOUNDATION.md](./modules/FOUNDATION.md) |
| **1** | **Auth** | `features/auth` : Repository, providers, User/Session, erreurs FR, écrans login/register/reset ; UX **identique** ; façade `AuthService` si besoin | Moyen–Élevé | [AUTH.md](./modules/AUTH.md) |
| **2** | **Home** (composition) | Orchestration Accueil via providers / APIs auth + lectures déjà stables ; pas de redesign | Moyen | [HOME.md](./modules/HOME.md) · [HOME_DONE.md](./modules/HOME_DONE.md) |
| **3** | **Sponsors** | Pattern complet sur surface petite ; valider cycle Feature First post-Auth | Faible | — |
| **4** | **Articles** (lecture) / **Prono** (tranche) | Du plus simple au plus complexe selon GO ; Prono déjà amorcé mais dualité `screens`/`features` | Faible→Moyen | — |
| **5+** | Matches / Clubs, Live, Notifs, Chat, XP, Profile élargi, Admin… | Un à la fois ; écritures admin en dernier dans chaque domaine | Élevé | — |

> **Logique figée :** Foundation avant tout feature ; **Auth** = premier feature ; **Home** ensuite (cœur app) ; puis Sponsors et le reste du simple → complexe. Un module à la fois.

### Hors file core (ADR-0002)

World Cup / Esti / tournois temporaires : **ne pas** moderniser comme modules cœur.

---

## 5. Cycle obligatoire par module

```
Analyse → Conception → Refactor
  → Tests → Architecture Review (obligatoire)
  → Corrections si FAIL
  → Cleanup Proposal (obligatoire — ADR-0005)
  → Validation suppressions (optionnel, GO item/batch)
  → Validation utilisateur
  → Documentation → Module suivant (seulement après GO)
```

| Étape | Livrable |
|-------|----------|
| **Analyse** | Fichiers touchés, dépendances, risques régression |
| **Conception** | Entités Freezed, interfaces repo, providers, plan de bascule (même UX) |
| **Refactor** | Déplacer / extraire **sans** changer le comportement visible |
| **Tests** | Unit mappers/usecases ; widget smoke si UI ; analyze clean |
| **Architecture Review** | Checklist `ARCHITECTURE_REVIEW.md` + script `-AppRoot` racine `dvcr_appli` — **PASS** (ADR-0003) ; section cleanup candidates |
| **Cleanup Proposal** | `modules/<MODULE>_CLEANUP_PROPOSAL.md` — mort / doublon / legacy ; **Proposed / Awaiting user GO** — **aucune** suppression (ADR-0005) |
| **Validation suppressions** | Optionnel, séparé : GO item ou batch nommé → alors seulement delete/merge |
| **Validation** | GO / NO-GO utilisateur écrit (parité fonctionnelle) |
| **Documentation** | Notes mapping / dettes acceptées + historique review + lien proposal |

**Règle d’or :** UX inchangée. Un module n’est jamais « terminé » sans Architecture Review PASS.  
**Cleanup :** une seule implémentation cible — **proposals only** jusqu’au GO user explicite.

---

## 6. Compatibilité données (ACL)

1. Pas de migration destructive des collections prod.
2. Modèles domain propres + mappers lecture/écriture legacy.
3. Functions Node conservées tant que stables.
4. Ne pas industrialiser les paths événementiels dans le core modernisé.

---

## 7. Critères de validation — exemples

### Module 0 — Foundation

Voir checklist complète : [`modules/FOUNDATION.md`](./modules/FOUNDATION.md).

- [ ] `flutter_riverpod` (+ Freezed si retenu) ; analyze clean
- [ ] `ProviderScope` sans régression démarrage
- [ ] Script review → racine `dvcr_appli`
- [ ] Aucune feature métier migrée « en passant »
- [ ] **Architecture Review PASS**

### Module 1 — Auth

Voir checklist + comportements figés : [`modules/AUTH.md`](./modules/AUTH.md).

- [ ] `lib/features/auth/{data,domain,presentation}`
- [ ] Login / register / reset / session : parité UX
- [ ] Plus d’appel Firebase Auth **direct** depuis les écrans auth
- [ ] Tests error mapping + repo fake
- [ ] **Architecture Review PASS** + GO user

### Module 2 — Home

Critères détaillés en conception. Toujours : composition sans redesign ; Review PASS ; GO user.

### Module 3 — Sponsors (et suivants)

- [ ] `lib/features/sponsors/…` ; plus de `Map` sponsors dans l’UI du périmètre
- [ ] Encars : même rendu / données
- [ ] Review PASS + GO user

---

## 8. Organisation repo

```
dvcr_appli/                 # SOURCE DE VÉRITÉ — app + functions
  lib/ …
  functions/ …
  dvcr-v2/                  # DOCS archi uniquement
    STRATEGY.md
    MODERNIZATION_PLAN.md
    modules/
      FOUNDATION.md
      AUTH.md
    ADR-0001 … ADR-0005
    modules/*_CLEANUP_PROPOSAL.md
    …

dvcr_appli_v2/              # HORS monorepo — GELÉ / ABANDONNÉ
```

---

## 9. Risques & mitigations

| Risque | Mitigation |
|--------|------------|
| Introduction Riverpod casse le bootstrap | Foundation minimal ; smoke launch |
| Auth casse guest / tutorial / cold start | Checklist AUTH.md ; diff bootstrap minimal |
| Refactor qui change l’UI | Checklist parité + refus redesign |
| Remplacer tous les `FirebaseAuth.instance` d’un coup | Hors scope Auth ; dette documentée |
| Tentation Sponsors-first malgré dette Auth | Cet amendement + STRATEGY |
| Tentation `dvcr_appli_v2` | ADR-0004 : gelé |
| Scope multi-modules | Un seul module ouvert à la fois |

---

## 10. Gate avant code

1. Validation utilisateur de **ADR-0004**.
2. Validation de l’ordre : **Foundation → Auth → Home** (puis Sponsors…).
3. GO explicite **Module 0 Foundation**, puis seulement code Foundation.
4. Après Review PASS Foundation : GO **Module 1 Auth**, etc.

---

*Plan de modernisation — aucun code applicatif dans cette étape docs.*
