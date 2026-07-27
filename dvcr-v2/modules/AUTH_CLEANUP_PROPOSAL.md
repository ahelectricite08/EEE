# Cleanup Proposal — Module : Auth

**Module :** 1 — Auth  
**Date :** 2026-07-26  
**Review liée :** [`docs/reviews/AUTH_ARCHITECTURE_REVIEW.md`](../docs/reviews/AUTH_ARCHITECTURE_REVIEW.md)  
**Done :** [`AUTH_DONE.md`](./AUTH_DONE.md)  
**ADR :** [ADR-0005](../ADR-0005-cleanup-requires-user-go.md)  
**Statut global :** **Awaiting user GO** — **aucune suppression effectuée**

---

## Contexte

Auth est Feature First sous `lib/features/auth/` (Repository, Freezed `AuthUser` / `AuthSession`, Riverpod, use cases). L’UI login/register vit dans `features/auth/presentation` ; une **chaîne de re-exports** conserve les anciens chemins `screens/`. `AuthService` est une **façade static** sur le repository (une seule impl). Hors Auth, `FirebaseAuth.instance` et `UserModel` restent massifs.

---

## Candidats

| Item | Type | Chemins | Risque | Recommandation | Statut |
|------|------|---------|--------|----------------|--------|
| Chaîne re-exports login/register | doublon | `lib/screens/login_screen.dart` → `lib/screens/auth/login_screen.dart` → `features/auth/.../login_screen.dart` (idem register) | Moyen | **fusionner** : pointer imports (`app_router`, prono shell, bootstrap) vers `package:dvcr/features/auth/auth.dart` puis **supprimer** les re-exports | **Awaiting user GO** |
| `AuthService` façade static | legacy | `lib/services/auth_service.dart` | Moyen | **garder façade** tant que profile / admin_web utilisent `errorMessage` ; migrer call sites → puis supprimer | **Awaiting user GO** |
| Méthodes façade `signIn` / `register` / `signOut` / `resetPassword` / `getCurrentUser` / streams | mort (call sites app) | `lib/services/auth_service.dart` — hors app, seuls `errorMessage` semblent consommés (`profile_account_screen`, `admin_web_screen`) | Faible–Moyen | **fusionner** / amincir : garder `errorMessage` (+ helpers FR) ou migrer vers `mapAuthExceptionToFr` ; **différer** delete total façade | **Awaiting user GO** |
| Dual `AuthUser` (Freezed) vs `UserModel` (Map) | doublon | `lib/features/auth/domain/entities/auth_user.dart` ; `lib/models/user_model.dart` ; bridge dans `AuthService` | Élevé | **différer** — `UserModel` encore admin/users ; fusion au module Profile / Users | **Awaiting user GO** |
| `AuthService.errorMessage` vs `mapAuthExceptionToFr` | doublon | `lib/services/auth_service.dart` ; `lib/features/auth/data/mappers/auth_error_mapper.dart` | Faible | **fusionner** : call sites → mapper (ou export barrel) ; façade mince ou supprimer après | **Awaiting user GO** |
| `FirebaseAuth.instance` hors périmètre Auth | legacy | chat, home, admin, prono, services… (nombreux) | Élevé | **différer** — tranche consumers / modules propriétaires (OUT Auth) | **Awaiting user GO** |
| Referral / `markTutorialDone` encore depuis presentation register | legacy | `features/auth/presentation/screens/register_screen.dart` (+ services referral / tutorial) | Moyen | **différer** — extraire use cases dédiés si module Onboarding / Referral | **Awaiting user GO** |
| Instance datasource/repo **hors** Riverpod dans façade | doublon (DI) | `AuthService` static `_datasource` / `_repository` vs `authRepositoryProvider` | Moyen | **garder façade** court terme ; long terme : façade qui lit le même provider / singleton DI | **Awaiting user GO** |

---

## Batches GO suggérés

| Batch | Items | Prérequis |
|-------|-------|-----------|
| A1 — imports auth | Migrer imports → barrel `features/auth` ; supprimer `lib/screens/auth/*` + `lib/screens/login_screen.dart` / `register_screen.dart` | GO + analyze + smoke login/register |
| A2 — errorMessage | Remplacer `AuthService.errorMessage` profile/admin → mapper ; amincir ou supprimer façade | GO A1 recommandé |
| A3 — UserModel | Hors Auth ; attendre Profile | — |

---

## Rappel

**Zéro suppression effectuée.** Une seule impl auth métier = `AuthRepositoryImpl` ; le reste est pont temporaire.

*Proposal only — pas de code applicatif modifié.*
