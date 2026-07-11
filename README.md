# DVCR — Drapeau Vert Carton Rouge

Application mobile et admin web pour la communauté du **CS Sedan Ardennes (CSSA)** : actus, calendrier, direct live, replays YouTube, pronos, chat et espace bénévoles.

Monorepo **Flutter + Firebase** (pas de repos séparés).

## Architecture

```
lib/                    App Flutter (iOS, Android, admin web embarqué)
  main.dart             Bootstrap mobile + AdminWebScreen (kIsWeb)
  screens/              UI mobile + admin (lib/screens/admin/)
  services/             Firestore, auth, FCM, sync FFF…
  features/             Modules isolés (world_cup, prono…)
functions/              Cloud Functions Node 22
  index.js              Point d'entrée (~25 lignes, re-exports)
  fff_sync.js           Sync calendrier / classement FFF
  live_push.js          Notifications direct & Live Activity
  prono_scoring.js      Points pronos championnat
  tournament_scoring.js ESTI'DVCR / Coupe du monde
  xp_system.js          XP, badges, parrainage
  lib/                  Helpers partagés (auth, push, xp…)
firestore.rules         Règles de sécurité Firestore
.github/workflows/      CI (analyze + test)
docs/ENVIRONMENT.md     Secrets et déploiement
```

| Client | Cible | Entrée |
|--------|--------|--------|
| Mobile | iOS / Android | `MainNavigation` |
| Admin web | Navigateur | `AdminWebScreen` (`kIsWeb`) |
| Android TV | Firestore `tv/` | API `tvApi` (Functions) |

## Prérequis

- Flutter SDK ^3.5 (`flutter doctor`)
- Node.js 22 (Cloud Functions)
- Firebase CLI (`npm i -g firebase-tools`)
- Compte Firebase du projet DVCR

## Démarrage local

```bash
# Dépendances Flutter
flutter pub get

# Lancer l'app (mobile ou Chrome pour l'admin web)
flutter run

# Functions (émulateur ou deploy)
cd functions && npm install
firebase emulators:start --only functions,firestore
```

Configuration Firebase : `lib/firebase_options.dart` (généré par FlutterFire CLI).

## Tests & qualité

```bash
flutter analyze lib
flutter test
```

La CI GitHub exécute analyze + test sur chaque PR (`.github/workflows/pr_checks.yml`).

## Déploiement

```bash
# Backend + règles Firestore
firebase deploy --only functions,firestore:rules,firestore:indexes

# Admin web (hosting)
flutter build web && firebase deploy --only hosting
```

Secrets Functions : voir [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

## Sécurité (Phase 0)

- Callables admin protégées (`_requireAdminCall`)
- `awardXp` : whitelist d'événements côté client
- Rules Firestore : lecture `users` / `predictions` restreinte
- HelloAsso webhook : fail-closed si secret absent

## Structure admin

L'admin est intégré dans Flutter (`lib/screens/admin/`), accessible sur web via `AdminWebScreen`. Onglets principaux : matchs, direct, stats, pronos, users, réglages.

## Scripts utilitaires

| Script | Usage |
|--------|--------|
| `tools/split_dart_parts.ps1` | Découper un gros fichier Dart en `part` (une section à la fois) |
| `functions/tools/split_index.js` | Régénérer les modules Functions depuis `index.js` monolithique |

## Licence

Projet privé — usage interne DVCR / CSSA.
