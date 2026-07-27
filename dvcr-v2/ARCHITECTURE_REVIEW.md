# DVCR — Architecture Review (fin de module)

**Statut :** gate obligatoire — un module n’est **jamais** « terminé » sans **PASS**.  
**Date :** 2026-07-26 (révisé : chemins in-place, ADR-0004, ADR-0005 cleanup)  
**Références :** `ADR-0001` … `ADR-0005`, `ARCHITECTURE.md`, `SCOPE_V2.md`, `PACKAGE_POLICY.md`, `FEATURES.md`, `MODERNIZATION_PLAN.md`, `STRATEGY.md`.  
**Filet auto :** `scripts/architecture_review.ps1` — **ne remplace pas** cette review.

> **App sous review = repo `dvcr_appli`** (racine contenant `pubspec.yaml` + `lib/`).  
> **Plus** de cible `dvcr-v2/app` ni `dvcr_appli_v2`.

---

## Quand l’exécuter

Après **Tests**, **avant** Validation utilisateur :

```
… → Tests → Architecture Review (obligatoire) → Corrections si FAIL
  → Cleanup Proposal (obligatoire — ADR-0005)
  → Validation suppressions (optionnel, GO item/batch)
  → Validation utilisateur → Documentation → Module suivant
```

Sans **PASS** → pas de démo GO, pas de module suivant.  
**Cleanup :** proposals only — **aucune** suppression / fusion code sans GO user explicite ([ADR-0005](./ADR-0005-cleanup-requires-user-go.md)).

---

## Comment remplir (par module)

1. Copier le **bloc template** ci-dessous dans « Historique » (ou `reviews/module-N.md`).
2. Lancer le script sur la racine app :

   ```powershell
   cd dvcr-v2
   .\scripts\architecture_review.ps1 -AppRoot ..
   ```

3. Cocher chaque critère : **OK** / **N/A** / **FAIL**.
4. Tout **FAIL** → correction **avant** de rejouer.
5. Verdict **PASS** seulement si zéro FAIL ouvert.
6. Remplir la section **Cleanup candidates** (statut **Proposed (not deleted)**) + fichier `modules/<MODULE>_CLEANUP_PROPOSAL.md`.
7. Joindre le verdict (+ proposal cleanup) à la Validation utilisateur.

---

## Template — à dupliquer par module

```
### Architecture Review — Module : <nom> (ex. Module 0 — Foundation / Module 1 — Sponsors)

| Champ | Valeur |
|-------|--------|
| Date | YYYY-MM-DD |
| Auteur review | |
| Branche / commit | |
| AppRoot | dvcr_appli (repo root) |
| Script auto | non lancé / PASS heuristique / FAIL heuristique (détails) |
| Verdict | PASS / FAIL |

#### Corrections obligatoires (si FAIL)
- [ ] …
- [ ] …

---

#### 1. Conformité ADR-0001 (stack Flutter) + ADR-0004 (in-place)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 1.1 | Stack = Flutter + Dart + Firebase (+ Riverpod / Freezed / etc. selon module Foundation+) | | |
| 1.2 | Pas de stack Next.js / React séparée pour le core | | |
| 1.3 | Modernisation **in-place** dans `lib/` de `dvcr_appli` — pas de second app / pas de dev dans `dvcr_appli_v2` | | |
| 1.4 | Refactor du module existant — **pas** de rewrite from scratch de la feature | | |
| 1.5 | UX / identité inchangées sauf demande explicite documentée | | |

#### 2. Conformité ADR-0002 (pas d’événements permanents)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 2.1 | Aucune industrialisation core de `world_cup` / `esti` / tournois événementiels | | |
| 2.2 | Aucune **nouvelle** route événementielle permanente | | |
| 2.3 | Client core modernisé ne s’accroche pas aux collections / callables événementielles | | |
| 2.4 | Pas de portage « au cas où » | | |

#### 3. Conformité ARCHITECTURE.md (sur le code touché)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 3.1 | Feature First : seul le module en cours migré / densifié (pas de scaffold massif) | | |
| 3.2 | Couches : Widget → Provider → UseCase → Repository → Firebase/HTTP | | |
| 3.3 | Pas d’imports croisés `features/A` → intérieur `features/B` **introduits** | | |
| 3.4 | `core` / `shared` n’importent pas `features/*` (code nouveau) | | |
| 3.5 | `presentation` du module n’appelle pas Firestore / HTTP directement | | |
| 3.6 | `domain` sans widgets ni SDK Firestore | | |
| 3.7 | Fichiers **touchés** ≤ 300 lignes (hors générés) | | |
| 3.8 | Pas de God class / singleton métier **nouveau** | | |
| 3.9 | Pas de `Map` Firestore bruts dans l’UI du périmètre modernisé | | |
| 3.10 | Navigation : pas de dette navigation **nouvelle** ; GoRouter seulement si module navigation | | |
| 3.11 | État métier via Riverpod sur le périmètre (après Foundation) | | |
| 3.12 | Tenant-first : zéro hardcode club **nouveau** | | |

#### 4. Conformité SCOPE_V2.md / STRATEGY
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 4.1 | Livrable dans le IN (cœur) ou N/A documenté | | |
| 4.2 | Rien de OUT (rewrite séparée, Esti/CdM industrialisé, etc.) | | |
| 4.3 | Items `FEATURES.md` du module : comportement ✅ conservé ; ⛔ non industrialisé | | |
| 4.4 | Alignement ADR-0004 (in-place) | | |

#### 5. Conformité PACKAGE_POLICY.md
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 5.1 | Dépendances = stack de base **ou** package avec ADR + GO | | |
| 5.2 | Aucun package hors politique « temporaire » sans ADR | | |
| 5.3 | Pas de Dio pour Firestore | | |

#### 6. Clean Architecture / SOLID
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 6.1 | Use cases petits, une intention | | |
| 6.2 | Repositories : interface domain / impl data | | |
| 6.3 | UI ignorante du stockage | | |
| 6.4 | Dependency rule (presentation → domain ← data) | | |
| 6.5 | Open/Closed : pas de gonflement God | | |
| 6.6 | `setState` : OK UI locale ; **interdit** état métier global | | |

#### 7. Tests
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 7.1 | Unit : mappers / use cases (si logique) | | |
| 7.2 | Widget : smoke si UI livrée | | |
| 7.3 | Emulator-ready documenté si data Firebase touchée | | |
| 7.4 | `flutter analyze` clean sur le périmètre | | |

#### 8. Dette technique
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 8.1 | Pas de TODO permanents sans note datée | | |
| 8.2 | Pas de hacks « module suivant » sur règles dures | | |
| 8.3 | Dettes acceptées listées (ex. façade legacy temporaire) | | |
| 8.4 | Secrets / IDs sensibles absents | | |
| 8.5 | Modules voisins non régressés (smoke parcours critiques) | | |

#### Verdict
- [ ] **PASS** — zéro FAIL ; prêt pour Cleanup Proposal + Validation utilisateur
- [ ] **FAIL** — corrections listées ; review à rejouer

---

#### 9. Cleanup candidates (dead / duplicate / legacy) — **obligatoire**
> ADR-0005 — **Proposed (not deleted)**. Ne pas supprimer / fusionner ici.
> Détail : `modules/<MODULE>_CLEANUP_PROPOSAL.md` (template `_CLEANUP_PROPOSAL_TEMPLATE.md`).

| Item | Type (mort / doublon / legacy) | Chemins | Risque | Recommandation | Statut |
|------|--------------------------------|---------|--------|----------------|--------|
| … | | | Faible / Moyen / Élevé | supprimer / fusionner / garder façade / différer | **Proposed (not deleted)** |

- [ ] Proposal écrite ; **zéro** suppression effectuée dans ce chantier
```

---

## Nuances

| Signal | Interprétation |
|--------|----------------|
| `setState` local (animation, expansion) | **OK** si pas métier / session / serveur |
| Code legacy hors module encore non conforme | **N/A** — ne pas FAIL tout le repo ; FAIL seulement si le module **aggrave** ou **touche** sans corriger |
| Import barrel public minimal | **OK rare** |
| Fichier > 300 L généré | **OK** |
| Script auto FAIL | Signal fort — arbitrage humain |

---

## Script automatique

| Élément | Valeur |
|---------|--------|
| App Flutter | **Racine `dvcr_appli`** (`pubspec.yaml` + `lib/`) |
| Script | `dvcr-v2/scripts/architecture_review.ps1` |
| Rôle | Filet heuristique — pas un substitut |

```powershell
# Depuis dvcr-v2/
.\scripts\architecture_review.ps1 -AppRoot ..
# équivalent explicite :
.\scripts\architecture_review.ps1 -AppRoot C:\Users\axeld\Music\dvcr_appli
```

---

## Historique des reviews

| Module | Date | Verdict | Commit | Notes |
|--------|------|---------|--------|-------|
| Module 0 — Foundation | 2026-07-26 | **PASS** | `d77d3e0`+ | [`docs/reviews/FOUNDATION_ARCHITECTURE_REVIEW.md`](./docs/reviews/FOUNDATION_ARCHITECTURE_REVIEW.md) ; cleanup → [`modules/FOUNDATION_CLEANUP_PROPOSAL.md`](./modules/FOUNDATION_CLEANUP_PROPOSAL.md) |
| Module 1 — Auth | 2026-07-26 | **PASS** | working tree | [`docs/reviews/AUTH_ARCHITECTURE_REVIEW.md`](./docs/reviews/AUTH_ARCHITECTURE_REVIEW.md) ; cleanup → [`modules/AUTH_CLEANUP_PROPOSAL.md`](./modules/AUTH_CLEANUP_PROPOSAL.md) |
| Module 2 — Home (T1) | 2026-07-26 | **PASS** | working tree | [`docs/reviews/HOME_ARCHITECTURE_REVIEW.md`](./docs/reviews/HOME_ARCHITECTURE_REVIEW.md) ; cleanup → [`modules/HOME_CLEANUP_PROPOSAL.md`](./modules/HOME_CLEANUP_PROPOSAL.md) (compléter après T2) |

---

## Sources de vérité (rappel)

1. `ADR-0001-stack-flutter.md` (stack — rewrite path supersédé)
2. `ADR-0002-no-permanent-event-modules.md`
3. `ADR-0003-architecture-review-gate.md`
4. `ADR-0004-progressive-modernization-in-place.md`
5. `ADR-0005-cleanup-requires-user-go.md`
6. `ARCHITECTURE.md`
7. `SCOPE_V2.md` / `STRATEGY.md`
8. `PACKAGE_POLICY.md`
9. `FEATURES.md`
10. `MODERNIZATION_PLAN.md`

*Review opérationnelle — pas de code applicatif dans ce document.*
