# Architecture Review — Module 1 — Auth

| Champ | Valeur |
|-------|--------|
| Date | 2026-07-26 |
| Auteur review | Auto (Lead Architect gate) |
| Branche / commit | `main` @ `d77d3e0` (+ working tree Auth) |
| AppRoot | `dvcr_appli` (repo root) |
| Script auto | **PASS heuristique** (`.\scripts\architecture_review.ps1 -AppRoot ..`) ; `-StrictFeatures` : **0 FAIL Auth** (FAIL restants = hybride `features/prono/*` préexistant, hors module) |
| Verdict | **PASS** |

#### Corrections obligatoires (si FAIL)
- *(aucune sur le périmètre Auth)*

---

#### 1. Conformité ADR-0001 (stack Flutter) + ADR-0004 (in-place)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 1.1 | Stack = Flutter + Dart + Firebase (+ Riverpod / Freezed / etc. selon module Foundation+) | OK | Freezed `AuthUser` / `AuthSession` ; Riverpod providers |
| 1.2 | Pas de stack Next.js / React séparée pour le core | OK | |
| 1.3 | Modernisation **in-place** dans `lib/` de `dvcr_appli` — pas de second app / pas de dev dans `dvcr_appli_v2` | OK | |
| 1.4 | Refactor du module existant — **pas** de rewrite from scratch de la feature | OK | Logique `AuthService` + écrans déplacée / branchée |
| 1.5 | UX / identité inchangées sauf demande explicite documentée | OK | Mêmes écrans, copy, flux guest/tutorial |

#### 2. Conformité ADR-0002 (pas d’événements permanents)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 2.1 | Aucune industrialisation core de `world_cup` / `esti` / tournois événementiels | OK | |
| 2.2 | Aucune **nouvelle** route événementielle permanente | OK | |
| 2.3 | Client core modernisé ne s’accroche pas aux collections / callables événementielles | OK | |
| 2.4 | Pas de portage « au cas où » | OK | |

#### 3. Conformité ARCHITECTURE.md (sur le code touché)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 3.1 | Feature First : seul le module en cours migré / densifié (pas de scaffold massif) | OK | `lib/features/auth/` uniquement |
| 3.2 | Couches : Widget → Provider → UseCase → Repository → Firebase/HTTP | OK | |
| 3.3 | Pas d’imports croisés `features/A` → intérieur `features/B` **introduits** | OK | |
| 3.4 | `core` / `shared` n’importent pas `features/*` (code nouveau) | OK | |
| 3.5 | `presentation` du module n’appelle pas Firestore / HTTP directement | OK | Via providers / use cases |
| 3.6 | `domain` sans widgets ni SDK Firestore | OK | |
| 3.7 | Fichiers **touchés** ≤ 300 lignes (hors générés) | OK | Auth screens / widgets / data ≤ 300 |
| 3.8 | Pas de God class / singleton métier **nouveau** | OK | Façade `AuthService` = legacy documentée |
| 3.9 | Pas de `Map` Firestore bruts dans l’UI du périmètre modernisé | OK | |
| 3.10 | Navigation : pas de dette navigation **nouvelle** ; GoRouter seulement si module navigation | OK | Named routes conservées (WARN script attendu) |
| 3.11 | État métier via Riverpod sur le périmètre (après Foundation) | OK | Session + actions via providers |
| 3.12 | Tenant-first : zéro hardcode club **nouveau** | OK | Copy register via `ClubBranding.shortName` |

#### 4. Conformité SCOPE_V2.md / STRATEGY
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 4.1 | Livrable dans le IN (cœur) ou N/A documenté | OK | Aligné `AUTH.md` |
| 4.2 | Rien de OUT (rewrite séparée, Esti/CdM industrialisé, etc.) | OK | |
| 4.3 | Items `FEATURES.md` du module : comportement ✅ conservé ; ⛔ non industrialisé | OK | Parité login/register/reset/session |
| 4.4 | Alignement ADR-0004 (in-place) | OK | |

#### 5. Conformité PACKAGE_POLICY.md
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 5.1 | Dépendances = stack de base **ou** package avec ADR + GO | OK | Aucun package ajouté (Freezed déjà Foundation) |
| 5.2 | Aucun package hors politique « temporaire » sans ADR | OK | |
| 5.3 | Pas de Dio pour Firestore | OK | |

**Justification deps ajoutées :** aucune.

#### 6. Clean Architecture / SOLID
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 6.1 | Use cases petits, une intention | OK | SignIn / RegisterUser / ResetPassword / SignOut |
| 6.2 | Repositories : interface domain / impl data | OK | |
| 6.3 | UI ignorante du stockage | OK | |
| 6.4 | Dependency rule (presentation → domain ← data) | OK | |
| 6.5 | Open/Closed : pas de gonflement God | OK | |
| 6.6 | `setState` : OK UI locale ; **interdit** état métier global | OK | loading/error/showPwd locaux |

#### 7. Tests
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 7.1 | Unit : mappers / use cases (si logique) | OK | `test/features/auth/auth_domain_test.dart` |
| 7.2 | Widget : smoke si UI livrée | OK | `login_screen_smoke_test.dart` |
| 7.3 | Emulator-ready documenté si data Firebase touchée | N/A | Repo fake en unit ; pas d’emulator requis DoD Auth |
| 7.4 | `flutter analyze` clean sur le périmètre | OK | `lib/features/auth` + façade + main |

#### 8. Dette technique
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 8.1 | Pas de TODO permanents sans note datée | OK | |
| 8.2 | Pas de hacks « module suivant » sur règles dures | OK | |
| 8.3 | Dettes acceptées listées (ex. façade legacy temporaire) | OK | Voir ci-dessous |
| 8.4 | Secrets / IDs sensibles absents | OK | |
| 8.5 | Modules voisins non régressés (smoke parcours critiques) | OK | Checklist manuelle AUTH.md à valider user |

### Dettes acceptées (Auth)

1. **`AuthService` static façade** — consumers hors périmètre (`errorMessage` profile/admin) ; une seule impl = `AuthRepositoryImpl`.
2. **`FirebaseAuth.instance` hors Auth** — chat, home, admin, prono, services… (OUT `AUTH.md`).
3. **GoRouter** — non introduit ; named routes + `Navigator` conservés (module Navigation).
4. **Referral / Tutorial** — encore appelés depuis presentation register (pas refactorés).
5. **`-StrictFeatures` FAILs prono** — dette hybride préexistante ; hors chantier Auth.

### Commandes

```powershell
flutter analyze lib/features/auth lib/services/auth_service.dart lib/screens/auth lib/main.dart lib/main_bootstrap.dart
flutter test test/features/auth
cd dvcr-v2
.\scripts\architecture_review.ps1 -AppRoot ..
```

---

**Verdict final : PASS** — awaiting **GO user** puis **GO Home**.
