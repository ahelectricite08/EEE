# Accès Admin Center DVCR

## Deux portes, un seul code

1. **Web (Firebase Hosting)**  
   URL du build Flutter Web, par exemple `https://drapeau-vert-app.web.app/`.  
   Sur ce dépôt, `main.dart` utilise `home: AdminWebScreen` lorsque `kIsWeb` est vrai : l’admin est l’écran d’accueil du site.

2. **App mobile / desktop (route interne)**  
   Route nommée **`/admin`** déclarée dans `lib/app/app_router.dart` → `AdminWebScreen` / `AdminPanel` → `AdminShell`.

## Deep-links web (bookmark staff)

Après connexion, l’URL peut refléter l’onglet actif sous la forme :

`https://<hôte>/#/admin/<segment>`

Segments pris en charge (voir `lib/features/admin/presentation/routing/admin_routes.dart`) :

| Segment | Onglet |
|---------|--------|
| `dashboard` | Pilotage |
| `direct` | Direct (Match Day) |
| `matchs` | Matchs |
| `stats` | Statistiques match |
| `notifs` | Notifications |
| `rappel-match` | Notifications → rappel match (alias) |
| `articles` | Actus |
| `stades`, `equipes-stades` | Équipes & stades |
| `users` | Membres |
| `communaute`, `chat` | Chat & modération |
| `benevoles` | Bénévoles |
| `adherents` | Adhérents |
| `pronos`, `prono`, `jeux` | Pronos & jeux |
| `xp` | XP & Niveaux |
| `settings` | Réglages |
| `android-tv`, `tv` | Android TV |
| `logs` | Journal |
| `staff`, `permissions` | Staff & permissions |
| `badges` | Staff & permissions (alias historique) |

L’onglet n’est appliqué depuis l’URL que si l’utilisateur a la permission correspondante.

## Claims Firebase (`dvcr_admin`)

Les règles Firestore peuvent traiter les comptes **admin** via le claim booléen `dvcr_admin`, synchronisé par la Cloud Function **`syncDvcrAuthClaims`** (écriture sur `users/{uid}`) et rafraîchi côté client par la callable **`refreshDvcrAuthClaims`** (appelée après vérification des droits sur le portail web).

Après promotion/dépromotion d’un admin, un **nouveau jeton** peut être nécessaire (`getIdToken(true)`) ou reconnexion.

## Rôles par défaut (réorganisation 2026)

- **Community Manager** : dashboard (KPIs), direct (pilotage live), matchs, communauté, pronos.
- **Statisticien** : stats + direct en **lecture seule** (UI bloquée, pas de pilotage).
- **Admin** : accès complet incluant Staff & permissions (`admin.staff`).

Les permissions effectives peuvent être surchargées dans Firestore `config/role_permissions`.
