# Auth — livré

**Module :** 1 — Auth  
**Date :** 2026-07-26  
**App :** `dvcr_appli` (`lib/`, `pubspec.yaml`)  
**Statut :** code livré — **Architecture Review PASS** — awaiting **GO user** / **GO Home**  
**Review :** [AUTH_ARCHITECTURE_REVIEW.md](../docs/reviews/AUTH_ARCHITECTURE_REVIEW.md)  
**Spec :** [AUTH.md](./AUTH.md)

---

## Ce qui a été livré

| Brique | Détail |
|--------|--------|
| **Feature First** | `lib/features/auth/{data,domain,presentation}` + barrel `auth.dart` |
| **Repository** | `AuthRepository` (domain) + `AuthRepositoryImpl` + `AuthFirebaseDatasource` |
| **Use cases** | `SignIn`, `RegisterUser`, `ResetPassword`, `SignOut` |
| **Freezed** | `AuthUser`, `AuthSession` (+ codegen) |
| **Erreurs** | `mapAuthException` → `AppFailure` / FR (parité `AuthService.errorMessage`) |
| **Riverpod** | `authRepositoryProvider`, use-case providers, `authSessionProvider` |
| **UI** | Login / Register migrés (Consumer) ; re-exports `lib/screens/auth/*` |
| **Bootstrap** | `_AppEntry` écoute `authRepository.watchSession()` (plus `FirebaseAuth` direct) |
| **Façade** | `AuthService` → délègue au repository (dette consumers hors Auth) |
| **Tests** | Unit mappers/usecases + smoke widget login |
| **Review** | **PASS** |

---

## Arborescence

```
lib/features/auth/
  auth.dart
  data/
    datasources/auth_firebase_datasource.dart
    mappers/auth_error_mapper.dart
    mappers/auth_user_mapper.dart
    repositories/auth_repository_impl.dart
  domain/
    entities/auth_user.dart (+ .freezed.dart)
    entities/auth_session.dart (+ .freezed.dart)
    repositories/auth_repository.dart
    usecases/{sign_in,register_user,reset_password,sign_out}.dart
  presentation/
    auth_providers.dart
    screens/{login_screen,register_screen}.dart
    widgets/{auth_palette,auth_text_field,auth_hero_banner,auth_register_form_body}.dart
```

Import public :

```dart
import 'package:dvcr/features/auth/auth.dart';
```

---

## Comportement conservé

- Login / reset password / register (+ referral silencieux + `markTutorialDone`)
- Messages d’erreur FR identiques
- Flux `_AppEntry` : splash → guest / register / tutorial / app
- Routes `/login` `/register` et re-exports écrans inchangés pour le reste de l’app

---

## Dette restante (hors GO Home)

- `FirebaseAuth.instance` dans chat / home / admin / prono / services…
- `AuthService.errorMessage` encore utilisé (profile / admin web)
- GoRouter non introduit
- Prono hybride (FAILs `-StrictFeatures`) — module Prono ultérieur

---

## Commandes

```powershell
flutter analyze lib/features/auth lib/services/auth_service.dart lib/screens/auth lib/main.dart lib/main_bootstrap.dart
flutter test test/features/auth
cd dvcr-v2
.\scripts\architecture_review.ps1 -AppRoot ..
```

---

## Suite

**STOP** — validation user (checklist non-régression `AUTH.md`) → **GO Home** écrit avant module Home.

> **Update 2026-07-26 :** GO Home reçu — livré en [HOME_DONE.md](./HOME_DONE.md) (tranche 1).
