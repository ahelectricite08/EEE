# Architecture Review — Module 0 — Foundation

| Champ | Valeur |
|-------|--------|
| Date | 2026-07-26 |
| Auteur review | Auto (Lead Architect gate) |
| Branche / commit | `main` @ `d77d3e0` (+ working tree Foundation) |
| AppRoot | `dvcr_appli` (repo root) |
| Script auto | **PASS heuristique** (`.\scripts\architecture_review.ps1 -AppRoot ..`) |
| Verdict | **PASS** |

#### Corrections obligatoires (si FAIL)
- *(aucune)*

---

#### 1. Conformité ADR-0001 (stack Flutter) + ADR-0004 (in-place)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 1.1 | Stack = Flutter + Dart + Firebase (+ Riverpod / Freezed / etc. selon module Foundation+) | OK | `flutter_riverpod` + Freezed deps préparées |
| 1.2 | Pas de stack Next.js / React séparée pour le core | OK | |
| 1.3 | Modernisation **in-place** dans `lib/` de `dvcr_appli` — pas de second app / pas de dev dans `dvcr_appli_v2` | OK | |
| 1.4 | Refactor du module existant — **pas** de rewrite from scratch de la feature | OK | Bootstrap minimal + `core/` neuf |
| 1.5 | UX / identité inchangées sauf demande explicite documentée | OK | Aucun changement thème / nav / écrans métier |

#### 2. Conformité ADR-0002 (pas d’événements permanents)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 2.1 | Aucune industrialisation core de `world_cup` / `esti` / tournois événementiels | OK | Surfaces legacy = WARN script seulement |
| 2.2 | Aucune **nouvelle** route événementielle permanente | OK | |
| 2.3 | Client core modernisé ne s’accroche pas aux collections / callables événementielles | OK | `core/` sans Firebase métier |
| 2.4 | Pas de portage « au cas où » | OK | |

#### 3. Conformité ARCHITECTURE.md (sur le code touché)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 3.1 | Feature First : seul le module en cours migré / densifié (pas de scaffold massif) | OK | Pas de `features/*` créé |
| 3.2 | Couches : Widget → Provider → UseCase → Repository → Firebase/HTTP | N/A | Pas encore de feature métier |
| 3.3 | Pas d’imports croisés `features/A` → intérieur `features/B` **introduits** | OK | |
| 3.4 | `core` / `shared` n’importent pas `features/*` (code nouveau) | OK | |
| 3.5 | `presentation` du module n’appelle pas Firestore / HTTP directement | N/A | Pas de presentation Foundation |
| 3.6 | `domain` sans widgets ni SDK Firestore | N/A | Erreurs = types purs Dart |
| 3.7 | Fichiers **touchés** ≤ 300 lignes (hors générés) | OK | Tous fichiers `lib/core/` << 300 |
| 3.8 | Pas de God class / singleton métier **nouveau** | OK | `foundationReadyProvider` utilitaire seulement |
| 3.9 | Pas de `Map` Firestore bruts dans l’UI du périmètre modernisé | N/A | |
| 3.10 | Navigation : pas de dette navigation **nouvelle** ; GoRouter seulement si module navigation | OK | **GoRouter refusé** — risque rewrite nav ; phase 2 documentée |
| 3.11 | État métier via Riverpod sur le périmètre (après Foundation) | OK | `ProviderScope` prêt ; pas d’état métier encore |
| 3.12 | Tenant-first : zéro hardcode club **nouveau** | OK | |

#### 4. Conformité SCOPE_V2.md / STRATEGY
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 4.1 | Livrable dans le IN (cœur) ou N/A documenté | OK | Aligné `FOUNDATION.md` |
| 4.2 | Rien de OUT (rewrite séparée, Esti/CdM industrialisé, etc.) | OK | |
| 4.3 | Items `FEATURES.md` du module : comportement ✅ conservé ; ⛔ non industrialisé | N/A | Pas de feature produit |
| 4.4 | Alignement ADR-0004 (in-place) | OK | |

#### 5. Conformité PACKAGE_POLICY.md
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 5.1 | Dépendances = stack de base **ou** package avec ADR + GO | OK | `flutter_riverpod`, Freezed stack = base autorisée |
| 5.2 | Aucun package hors politique « temporaire » sans ADR | OK | Aucun package hors stack **ajouté** ; legacy existants = WARN |
| 5.3 | Pas de Dio pour Firestore | OK | Dio non ajouté |

**Justification deps ajoutées :**

| Package | Pourquoi |
|---------|----------|
| `flutter_riverpod` | DI / state cible (ADR-0001, Foundation DoD) |
| `freezed_annotation` + `json_annotation` | Préparation modèles Auth+ |
| `freezed` + `json_serializable` + `build_runner` (dev) | Codegen Auth+ ; aucun `.freezed.dart` généré ici |

#### 6. Clean Architecture / SOLID
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 6.1 | Use cases petits, une intention | N/A | |
| 6.2 | Repositories : interface domain / impl data | N/A | |
| 6.3 | UI ignorante du stockage | OK | Bootstrap inchangé hors `ProviderScope` |
| 6.4 | Dependency rule (presentation → domain ← data) | N/A | |
| 6.5 | Open/Closed : pas de gonflement God | OK | `core/` mince |
| 6.6 | `setState` : OK UI locale ; **interdit** état métier global | OK | Pas de nouveau setState métier |

#### 7. Tests
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 7.1 | Unit : mappers / use cases (si logique) | OK | `AppFailure`, `Result`, `AppConfig`, overrides Riverpod |
| 7.2 | Widget : smoke si UI livrée | N/A | Pas d’UI Foundation |
| 7.3 | Emulator-ready documenté si data Firebase touchée | N/A | Firebase non touché dans `core/` |
| 7.4 | `flutter analyze` clean sur le périmètre | OK | `flutter analyze lib/core lib/main.dart` → No issues |

#### 8. Dette technique
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 8.1 | Pas de TODO permanents sans note datée | OK | |
| 8.2 | Pas de hacks « module suivant » sur règles dures | OK | |
| 8.3 | Dettes acceptées listées (ex. façade legacy temporaire) | OK | Voir ci-dessous |
| 8.4 | Secrets / IDs sensibles absents | OK | |
| 8.5 | Modules voisins non régressés (smoke parcours critiques) | OK | Diff bootstrap minimal ; checklist manuelle FOUNDATION.md à valider user |

### Dettes acceptées (Foundation)

1. **GoRouter / migration router = Foundation phase 2** (ou module Navigation dédié) — introduire GoRouter maintenant forcerait une rewrite de `MaterialApp` + routes + FCM deep links.
2. Services static / `ChangeNotifier` legacy **non migrés** (Auth = Module 1).
3. Packages media/UI legacy hors liste stack de base (WARN script) — conservés ; pas d’ADR requis pour l’existant.
4. `features/prono` hybride (Firestore en presentation, fichiers > 300) — hors scope Foundation ; script utilise `-StrictFeatures` seulement lors du module Prono.
5. `flutter analyze` repo entier : warnings/infos legacy préexistants (164) — périmètre Foundation clean.

#### Verdict
- [x] **PASS** — zéro FAIL ; prêt pour Validation utilisateur
- [ ] **FAIL** — corrections listées ; review à rejouer

---

**Gate suivante :** Validation utilisateur Foundation → puis **GO Auth** explicite avant Module 1.
