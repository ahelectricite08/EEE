# Foundation — livré

**Module :** 0 — Foundation  
**Date :** 2026-07-26  
**App :** `dvcr_appli` (`lib/`, `pubspec.yaml`)  
**Statut :** code livré — **awaiting GO Auth** (ne pas démarrer Auth sans GO user)

---

## Ce qui a été livré

| Brique | Détail |
|--------|--------|
| **Riverpod** | `flutter_riverpod` dans `pubspec.yaml` |
| **Bootstrap** | `ProviderScope` autour de `DVCRApp` dans `lib/main.dart` |
| **`lib/core/`** | Config, erreurs typées, `Result`, providers utilitaires |
| **Freezed prep** | `freezed_annotation` / `json_annotation` + `build_runner` / `freezed` / `json_serializable` (dev) — **pas** de modèle généré Foundation |
| **GoRouter** | **Non introduit** (OUT Foundation ; migration = phase 2 / module Navigation ou Auth si besoin) |
| **Tests** | `test/core/foundation_core_test.dart` |
| **Review script** | `dvcr-v2/scripts/architecture_review.ps1` — AppRoot = racine `dvcr_appli` ; FAIL ciblés `core/`/`shared/` |

---

## Arborescence

```
lib/core/
  core.dart                 # barrel public
  config/app_config.dart    # constantes non-secrètes (appName, packageName)
  di/core_providers.dart    # conventions DI + foundationReadyProvider
  errors/app_failure.dart   # sealed AppFailure (+ Network/Auth/…)
  errors/result.dart        # Result<T> = Success | Failure
```

Import recommandé :

```dart
import 'package:dvcr/core/core.dart';
```

---

## Comment réutiliser (modules suivants)

1. **DI** — déclarer repositories / use cases via Riverpod dans `features/<m>/presentation/*_providers.dart`. Pas de nouveaux singletons métier.
2. **Erreurs** — mapper SDK → `AppFailure` en data ; retourner `Result<T>` depuis domain/data ; UI lit `messageFr` (ou message feature).
3. **Freezed** — premier modèle typé au module Auth :  
   `dart run build_runner build --delete-conflicting-outputs`
4. **Overrides tests** — `ProviderContainer(overrides: [...])` / `ProviderScope(overrides: ...)`.
5. **Navigation** — conserver `MaterialApp` + routes nommées actuelles jusqu’au module Navigation (GoRouter).

### Règles d’import (rappel)

| Depuis → Vers | OK ? |
|---------------|------|
| `features/A` → `core` | Oui |
| `core` → `features/*` | **Non** |
| `features/A` → intérieur `features/B` | **Non** (barrel public rare OK) |

---

## Hors scope (volontaire)

- Auth / Home / Sponsors / Prono non migrés
- Pas de changement UX / thème / splash / guest flow
- Pas de `lib/shared/` inventé (pas de besoin immédiat)
- Pas de touch `dvcr_appli_v2`

---

## Commandes utiles

```powershell
flutter pub get
flutter analyze lib/core lib/main.dart
flutter test test/core/foundation_core_test.dart
cd dvcr-v2
.\scripts\architecture_review.ps1 -AppRoot ..
```

---

## Suite

Attendre **GO Auth** écrit → [`modules/AUTH.md`](./AUTH.md).
