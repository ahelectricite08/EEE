# Architecture Review — Module 2 — Home (tranche 1)

| Champ | Valeur |
|-------|--------|
| Date | 2026-07-26 |
| Auteur review | Auto (Lead Architect gate) |
| Branche / commit | `main` @ `d77d3e0` (+ working tree Home) |
| AppRoot | `dvcr_appli` (repo root) |
| Script auto | **PASS heuristique périmètre Home** (`.\scripts\architecture_review.ps1 -AppRoot .. -StrictFeatures`) ; **0 FAIL** sous `lib/features/home/**` (FAIL restants = hybride `features/prono/*` préexistant, hors module — même note qu’Auth) |
| Verdict | **PASS** |

#### Corrections obligatoires (si FAIL)
- *(aucune sur le périmètre Home tranche 1)*

---

#### 1. Conformité ADR-0001 (stack Flutter) + ADR-0004 (in-place)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 1.1 | Stack = Flutter + Dart + Firebase (+ Riverpod / Freezed / etc. selon module Foundation+) | OK | Freezed `HomeLayoutHints` / `HomeSectionsConfig` ; Riverpod providers |
| 1.2 | Pas de stack Next.js / React séparée pour le core | OK | |
| 1.3 | Modernisation **in-place** dans `lib/` de `dvcr_appli` — pas de second app / pas de dev dans `dvcr_appli_v2` | OK | |
| 1.4 | Refactor du module existant — **pas** de rewrite from scratch de la feature | OK | UI Accueil réutilisée ; logique sections/bannière extraite |
| 1.5 | UX / identité inchangées sauf demande explicite documentée | OK | Mêmes sections, copy, navigations |

#### 2. Conformité ADR-0002 (pas d’événements permanents)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 2.1 | Aucune industrialisation core de `world_cup` / `esti` / tournois événementiels | OK | UI legacy WC mini-card inchangée ; pas portée en core |
| 2.2 | Aucune **nouvelle** route événementielle permanente | OK | |
| 2.3 | Client core modernisé ne s’accroche pas aux collections / callables événementielles | OK | Repo Home = `config/home_sections` + `app_config/home_banner` |
| 2.4 | Pas de portage « au cas où » | OK | |

#### 3. Conformité ARCHITECTURE.md (sur le code touché)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 3.1 | Feature First : seul le module en cours migré / densifié (pas de scaffold massif) | OK | `lib/features/home/` uniquement |
| 3.2 | Couches : Widget → Provider → UseCase → Repository → Firebase/HTTP | OK | Sur données home-owned |
| 3.3 | Pas d’imports croisés `features/A` → intérieur `features/B` **introduits** | OK | |
| 3.4 | `core` / `shared` n’importent pas `features/*` (code nouveau) | OK | |
| 3.5 | `presentation` du module n’appelle pas Firestore / HTTP directement | OK | `home_providers.dart` via repository |
| 3.6 | `domain` sans widgets ni SDK Firestore | OK | Timestamp mapping en data/mappers |
| 3.7 | Fichiers **touchés** ≤ 300 lignes (hors générés) | OK | Tous fichiers `features/home/**` ≤ 80 L ; UI `screens/home/*` non déplacée (tranche 2) |
| 3.8 | Pas de God class / singleton métier **nouveau** | OK | Façades `HomeSectionsService` / `HomeBannerService` = legacy documentée |
| 3.9 | Pas de `Map` Firestore bruts dans l’UI du périmètre modernisé | OK | Config typée Freezed côté providers |
| 3.10 | Navigation : pas de dette navigation **nouvelle** ; GoRouter seulement si module navigation | OK | |
| 3.11 | État métier via Riverpod sur le périmètre (après Foundation) | OK | Layout / config / banner |
| 3.12 | Tenant-first : zéro hardcode club **nouveau** | OK | Aucun hardcode ajouté dans `features/home` |

#### 4. Conformité SCOPE_V2.md / STRATEGY
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 4.1 | Livrable dans le IN (cœur) ou N/A documenté | OK | Aligné `HOME.md` tranche 1 |
| 4.2 | Rien de OUT (rewrite séparée, Esti/CdM industrialisé, etc.) | OK | |
| 4.3 | Items `FEATURES.md` du module : comportement ✅ conservé ; ⛔ non industrialisé | OK | Parité Accueil |
| 4.4 | Alignement ADR-0004 (in-place) | OK | |

#### 5. Conformité PACKAGE_POLICY.md
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 5.1 | Dépendances = stack de base **ou** package avec ADR + GO | OK | Aucun package ajouté |
| 5.2 | Aucun package hors politique « temporaire » sans ADR | OK | |
| 5.3 | Pas de Dio pour Firestore | OK | |

**Justification deps ajoutées :** aucune.

#### 6. Clean Architecture / SOLID
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 6.1 | Use cases petits, une intention | OK | SetPodcastNextEvent / ClearPodcastNextEvent |
| 6.2 | Repositories : interface domain / impl data | OK | |
| 6.3 | UI ignorante du stockage (périmètre modernisé) | OK | Providers ; écrans legacy composent encore Live/Matchs |
| 6.4 | Dependency rule (presentation → domain ← data) | OK | |
| 6.5 | Open/Closed : pas de gonflement God | OK | |
| 6.6 | `setState` : OK UI locale ; **interdit** état métier global | OK | Live hub local (dette) ; layout/banner via Riverpod |

#### 7. Tests
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 7.1 | Unit : mappers / use cases (si logique) | OK | `test/features/home/home_domain_test.dart` |
| 7.2 | Widget : smoke si UI livrée | N/A | UI non réécrite ; smoke HomeScreen reporté tranche 2 |
| 7.3 | Emulator-ready documenté si data Firebase touchée | N/A | Repo fake en unit |
| 7.4 | `flutter analyze` clean sur le périmètre | OK | `lib/features/home` + façades + `home_screen.dart` |

#### 8. Dette technique
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 8.1 | Pas de TODO permanents sans note datée | OK | |
| 8.2 | Pas de hacks « module suivant » sur règles dures | OK | |
| 8.3 | Dettes acceptées listées | OK | Voir ci-dessous |
| 8.4 | Secrets / IDs sensibles absents | OK | |
| 8.5 | Modules voisins non régressés (smoke parcours critiques) | OK | Checklist manuelle `HOME.md` à valider user |

### Dettes acceptées (Home tranche 1)

1. **UI Accueil encore sous `lib/screens/home/`** — monolithe + parts > 300 L ; move/split Feature First = **tranche 2**.
2. **Composition legacy** — `LiveStateService`, `MatchController`, `ArticleService`, MOTM/sondage widgets, `FirebaseAuth.instance` dans hero ; hors home-owned data.
3. **Façades static** — `HomeSectionsService` / `HomeBannerService` pour admin + call sites.
4. **World Cup mini-card** — conservée telle quelle (ADR-0002 : ne pas industrialiser).
5. **`-StrictFeatures` FAILs prono** — dette hybride préexistante ; hors chantier Home.
6. **GoRouter** — non introduit.

### Verdict final

**PASS** — tranche 1 (shell repository sections + bannière + providers + branchement Accueil).  
Awaiting **GO user** avant module suivant (Sponsors recommandé).

> **Update 2026-07-26 :** tranche 2 livrée — voir [HOME_T2_ARCHITECTURE_REVIEW.md](./HOME_T2_ARCHITECTURE_REVIEW.md) (UI Feature First + split).
