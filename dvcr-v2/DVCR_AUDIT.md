# DVCR — Audit exhaustif (ÉTAPE 1)

> **Cible V2 = Flutter Feature First** (voir `ARCHITECTURE.md`, `MIGRATION_PLAN.md`, `ADR-0001-stack-flutter.md`).  
> Toute mention Next.js / Tailwind / Shadcn / React éventuelle dans d’anciens drafts est **obsolète**.

**Date :** 2026-07-26  
**Périmètre :** monorepo Flutter + Firebase (`C:\Users\axeld\Music\dvcr_appli`)  
**Contrainte :** lecture seule du code existant — aucune modification applicative.  
**Référence :** l’app Flutter actuelle est la **référence fonctionnelle** pour V2. Le code ne doit pas être copié tel quel.

---

## Architecture actuelle

### Vue d’ensemble

DVCR (« Drapeau Vert Carton Rouge ») est une application **communautaire CSSA** (CS Sedan Ardennes) livrée comme monorepo :

| Couche | Technologie | Rôle |
|--------|-------------|------|
| Client mobile | Flutter 3.5+ (iOS / Android) | Accueil, TV, calendrier, actus, chat, pronos, profil |
| Admin web | Flutter Web (`kIsWeb` → `AdminWebScreen`) | Centre d’administration staff |
| Android TV | HTTP `tvApi` + Firestore `tv/` | Catalogue / live pour box TV |
| Backend | Firebase Auth, Firestore, Storage, FCM, Cloud Functions (Node 22) | Auth, data, pushes, sync FFF, scoring |

**Pas de go_router, Provider, Riverpod ni Bloc.** Navigation impérative (`MaterialApp` + onglets + `Navigator` imbriqués). État dominant : `setState`, `StreamBuilder` Firestore, quelques `ChangeNotifier` / `ValueNotifier` / `InheritedWidget`.

### Organisation du code client (`lib/`)

```
lib/
  main.dart (+ parts bootstrap / navigation / shell)
  app/                 → routes nommées, deep-links notifs
  navigation/          → bridge onglets + feature flags (rollouts)
  screens/             → majorité de l’UI (~172 fichiers Dart)
  features/            → migration partielle (prono, admin routing/RBAC, world_cup)
  services/            → ~61 services (accès Firestore / métier)
  models/              → ~11 modèles partagés
  widgets/             → ~35 widgets transverses
  theme/, utils/, constants/
```

**Volume approximatif :** ~115 000 lignes Dart dans `lib/` ; ~6 350 lignes JS dans les fichiers Functions racine (hors `node_modules`).

### Clients et points d’entrée

1. **Mobile** — `MainNavigation` : Accueil, DVCR TV, Calendrier, Actus, Communauté (flag), Pronos (flag) ; mode invité (Actus ouvert).
2. **Web admin** — `AdminWebScreen` → `AdminShell` ; deep-links `#/admin/<segment>` (`docs/admin_access.md`, `features/admin/presentation/routing/admin_routes.dart`).
3. **Route `/admin`** aussi depuis l’app (profil staff).

### Backend Cloud Functions (`functions/`)

Point d’entrée `index.js` (re-exports). Domaines principaux :

| Module | Rôle |
|--------|------|
| `fff_sync.js` | Calendrier / scores / classement DOFA FFF |
| `prono_scoring.js` | Points pronos, duels, stats 1-N-2, reset saison |
| `tournament_scoring.js` | Tournois / Esti’DVCR / CdM |
| `match_stats.js` | Preview / publication fiches stats |
| `live_push.js` | Pushes buts / émission |
| `manual_notifications.js` + `notification_triggers.js` | File notifs + triggers sociaux / actus |
| `match_callables.js` | Rappels match, compositions |
| `youtube_sync.js` | Playlist → `videos` |
| `xp_system.js` | XP, claims `dvcr_admin`, parrainage, archive saison |
| `tv_api.js` | API Android TV + heartbeat présence |
| `wix_article_webhook.js` | Articles depuis Wix |
| `helloasso_webhook.js` | Adhésions / dons |

Helpers partagés : `lib/admin_auth.js`, `lib/push_helpers.js`, `lib/xp_core.js`, `lib/fff_config.js`.

### Données Firestore (schéma de facto)

**~45 collections top-level** + sous-collections. Axes majeurs :

- **Sport :** `matches`, `match_stats`, `ranking`, `ranking_archive`, `teams`, `live` (+ votes MOTM / notes / sondage)
- **Contenu :** `articles` (+ `comments`), `videos`, `tv`
- **Pronos :** `predictions`, `prono_leaderboard`, `match_prono_stats`, `prono_seasons`, `user_season_stats`, `prono_duels`, `private_leagues`, `friend_requests`, `prono_social_activity`, `season_archives`
- **Tournois :** `tournaments/*`, `esti_dvcr_leagues`
- **Communauté :** `users`, `chat_salons`/`messages`, `reports`, `badges`, `referrals`, `donations`
- **Ops :** `notifications_queue`, `admin_logs`, `admin_audit_logs`, `benevole_documents`, HelloAsso `helloasso_*`
- **Config :** `app_config`, `app_settings`, `config` (`role_permissions`, `sponsors`, `role_badges`)

Règles sophistiquées dans `firestore.rules` (helpers RBAC, updates ciblés live/stats/chat). Indexes dans `firestore.indexes.json`.

### Auth & permissions

- **Auth :** email / mot de passe (`AuthService`) → doc `users/{uid}` avec `role` / `roles[]`.
- **Rôles :** `supporter`, `teamDvcr`, `editor`, `communityManager`, `statisticien`, `admin` (+ legacy `donateur`/`partenaire`).
- **RBAC UI :** `RolePermissionsService` + matrice Firestore `config/role_permissions` ; permissions `admin.*` (dashboard, direct, matches, stats, articles, …, staff).
- **Claims :** `dvcr_admin` synchronisé par `syncDvcrAuthClaims` / `refreshDvcrAuthClaims`.
- **Firestore rules :** `isAdmin()`, `isStaff()`, `canWriteEditorialContent()`, `canWriteMatchOperations()`, `isStatsStaff()`, etc.

### État global & patterns

| Pattern | Usage |
|---------|--------|
| Services statiques | Dominant |
| `MatchController`, `PodcastController`, `AdminController` | ChangeNotifier |
| `FeatureFlagsService.notifier` | Feature flags runtime |
| `AdminControllerProvider`, `PronoThemeScope` | Inherited* |
| Streams Firestore | Temps réel (home live, chat, admin, pronos) |

### Dépendances notables

**Flutter (`pubspec.yaml` v1.0.6+56) :** Firebase suite, YouTube iframe / explode, video_player/chewie, FCM + local notifications, Live Activities, fl_chart, Lottie, markdown/html, share_plus, connectivity.

**Functions :** `firebase-admin`, `firebase-functions`, `axios`, `cheerio` ; `fast-xml-parser` déclaré mais **non utilisé**.

---

## Points forts

1. **Produit riche et cohérent métier** — live match-day, stats, FFF, pronos sociaux, chat, XP, adhérents HelloAsso, bénévoles, TV : couverture rare pour une app club.
2. **Règles Firestore travaillées** — helpers granulaires (stats vs faits de jeu vs fin de live vs réactions chat) plutôt qu’un « admin peut tout ».
3. **Admin structuré** — registre d’onglets (`admin_tab_registry.dart`), univers sidebar, deep-links web, actions sensibles (`admin_actions.dart`), journal d’audit.
4. **RBAC configurable** — permissions surchargeables dans Firestore ; rôles CM / statisticien / admin documentés (`docs/admin_access.md`).
5. **Functions modularisées** — sortie du monolithe `index.js` ; domaines séparés (FFF, prono, live, XP, TV).
6. **Feature flags / rollouts** — chat, hub prono, world cup, esti (`navigation/*_rollout.dart`) permettent un déploiement progressif.
7. **Sync FFF opérationnelle** — calendrier, scores, classement, archive saison ; throttle on-demand.
8. **Expérience live soignée** — Live Activities iOS, sticky score Android, sons d’événements, salon chat live, MOTM, notes, sondage émission.
9. **Documentation opérationnelle existante** — ENVIRONMENT, admin access, workflow stats, prep App Store, spec ligues/duels.
10. **CI de base** — analyze + test sur PR (`.github/workflows`).

---

## Points faibles

1. **Architecture hybride inachevée** — `features/` (prono/admin) coexiste avec un océan `screens/` ; imports croisés, shells legacy (`PronoShellScaffold` vs `PronoRootShell`).
2. **Pas de couche domaine claire** — logique métier éparpillée services / widgets / écrans admin ; modèles incomplets (beaucoup de `Map` Firestore bruts).
3. **Navigation fragile** — clés globales, navigateurs imbriqués, deep-links notifs manuels ; difficile à tester et à migrer module par module.
4. **Absence de state management typé** — pas de store prévisible ; risque de rebuilds et de logique dupliquée dans les `StatefulWidget`.
5. **God screens / fichiers part** — home, chat, admin tabs, prono social découpés en `part` mais toujours monolithiques conceptuellement.
6. **Schéma Firestore organique** — champs alias (`score1`/`scoreHome`), collections legacy (`chat`), règles pour `competitions`/`fixtures` jamais utilisées côté code.
7. **Admin = Flutter Web du même codebase** — charge de bundle, UX desktop contrainte, couplage fort mobile/admin.
8. **Dette visuelle / tokens** — palettes prono / admin / live multipliées (`prono_palette` vs `prono_tokens`, etc.).
9. **Tests insuffisants** — peu de tests (`test/` quasi vide hors smoke) face à ~115k LOC.
10. **Dossiers morts dans le repo** — `_backup/`, `trash/`, scripts one-shot à la racine (`fix_*.py`, `add_showstats.py`) polluent la lecture.

---

## Dette technique

| Élément | Impact | Priorité |
|---------|--------|----------|
| Migration `screens/` → `features/` à mi-chemin (prono, admin) | Confusion, double maintenance | Haute |
| Alias de scores / champs match historiques | Bugs sync, règles complexes | Haute |
| Collections / règles orphelines (`competitions`, `fixtures`, `chat` legacy) | Sécurité et lisibilité | Moyenne |
| `vote_history` utilisé sans règle Firestore dédiée | Écritures client potentiellement refusées / trou | Haute |
| Storage : seul `benevole_docs/` règlé ; `home_banner/` non déclaré | Upload bannière fragile | Haute |
| Services « static god » (match, live, prono social) | Couplage, tests impossibles | Haute |
| Feature Esti / tournament / world_cup redondants (routes alias → Pronos) | Code mort ou semi-mort | Moyenne |
| `subscription_screen.dart` orphelin | Bruit | Basse |
| Dep `fast-xml-parser` unused | Bruit supply-chain | Basse |
| Scripts racine non documentés / non outillés | Onboarding | Moyenne |
| `part` / barrels pour masquer la taille des fichiers | Fausse modularité | Moyenne |
| Admin web = même app Flutter | Perf, SEO, DX V2 | Haute (pour V2) |
| Pas de contrats TypeScript partagés client/functions | Drift champs | Haute (V2) |
| Secrets Wix acceptés en query string | Fuite logs | Haute (sécu) |
| Endpoints TV publics sans auth | Abus présence / lecture | Moyenne |

---

## Code dupliqué

| Zone | Manifestation |
|------|----------------|
| **Prono UI** | Hub neuf `features/prono/**` + predict/social encore dans `screens/prono/**` |
| **Thème prono** | `screens/prono/prono_palette.dart` ≈ `features/prono/presentation/theme/prono_tokens.dart` |
| **Shells prono** | `PronoRootShell` actif vs `PronoShellScaffold` legacy |
| **Admin** | UI `screens/admin` + routing/RBAC/theme `features/admin` + re-exports `admin_tabs.dart` |
| **Tournois** | `features/world_cup/tournament_prono_screen.dart` + barrels `screens/` + onglets esti/world_cup |
| **Rôles** | `models/user_role.dart` + helpers legacy `utils/roles.dart` |
| **Share** | `dvcr_share_service.dart`, `share_helper.dart`, templates cache, widgets powered-by / encarts |
| **Live scoring** | Panneau admin (`direct_tab`, `LiveMatchQuickPanel`) vs widgets home live vs Live Activity |
| **Stats** | `match_stats_service` / `sheet_service` / `repository` + miroir sur doc `matches` |
| **Barrels d’écran** | `screens/foo_screen.dart` → `screens/foo/...` (double chemin d’import) |
| **Config TV** | `tv/config` vs legacy `app_config/tv` |

---

## Mauvaises pratiques

1. **Logique métier dans les widgets** — transactions MOTM/notes, filtres calendrier, formatage live souvent inline.
2. **Maps non typées** partout — parsing ad hoc (`data['score1'] ?? data['scoreHome']`).
3. **Permissions vérifiées surtout côté UI** — les rules couvrent beaucoup, mais certaines collections config / historique restent floues.
4. **Callables qui throw `Error` brut** (ex. referral) au lieu d’`HttpsError` homogènes.
5. **FFF sync avec User-Agent navigateur** — contournement WAF fragile (ToS / brittle).
6. **Écriture présence TV sans auth** — surface d’abus.
7. **Fichiers massifs** — difficulté revue de code / conflits git.
8. **Absence de couches anti-corruption** — client écrit directement la forme Firestore « historique ».
9. **Feature flags par défaut parfois permissifs** — dépend du doc `app_config/feature_flags`.
10. **Mélange langues / naming** — `team_dvcr` vs `teamDvcr`, FR/EN dans les mêmes APIs.

---

## Performance

| Sujet | Constat |
|-------|---------|
| **Streams Firestore** | Nombreux listeners simultanés (home + live + chat + admin) ; pas toujours de désabonnement explicite hors cycle widget |
| **Admin web** | Bundle Flutter Web lourd pour un back-office |
| **Listes** | Peu d’évidence de pagination agressive sur chat / articles / users |
| **Images** | Logos équipes, bannières, YouTube thumbs — caching partiel (`app_cache_service`) |
| **FFF sync** | Fenêtre large (~21j passé / 120j futur) ; cron 6h + on-demand (throttle 30 min) |
| **MatchController** | Cache ChangeNotifier utile mais risque de stale si invalidation partielle |
| **Live Activity / FCM** | Chemin critique match-day ; dépend de la qualité des payloads |
| **YouTube** | Players iframe / explode — coût mémoire mobile |
| **Indexes** | Présents pour requêtes clés ; collectionGroup `messages` pour centre notifs |

**Risques V2 :** rejouer les mêmes listeners naïfs côté Flutter sans providers scoped / dispose (Riverpod) reproduirait les coûts.

---

## Sécurité

### Points positifs

- Rules Firestore détaillées (rôles, updates différentiels, sous-collections votes).
- Callables admin via `_requireAdminCall` / rôles étendus stats.
- Secrets Functions documentés (`docs/ENVIRONMENT.md`) : YouTube, Wix, HelloAsso.
- HelloAsso : fail-closed si secret absent ; HMAC préféré.
- `awardXp` : whitelist d’événements client.
- Claims `dvcr_admin` + refresh token.
- Audit logs admin (`admin_audit_logs`).
- Compte suppression / GDPR (`account_deletion_service`).

### Risques / écarts (sans exposer de secrets)

| Risque | Détail |
|--------|--------|
| **Storage incomplet** | Seul `benevole_docs/` ; `home_banner/` non couvert → deny par défaut ou config hors repo |
| **`vote_history` sans rules** | Collection lue/écrite côté client admin |
| **HTTP public** | `tvApi`, `tvLiveHeartbeat`, webhooks Wix/HelloAsso |
| **Wix secret en query** | Fuite via logs / referrers |
| **Présence TV** | Écriture `live_presence` / viewers sans Auth utilisateur |
| **Lecture publique large** | `matches`, `articles`, `videos`, `live` en `read: if true` (volontaire mais exposé) |
| **FFF on-demand** | Tout user authentifié peut déclencher (throttle global) |
| **Matrice permissions client** | Contournement UI possible si rules trop larges sur une collection |
| **Keystore / fastlane** | Secrets locaux / CI — s’assurer qu’ils restent gitignored (vérifié pattern docs) |
| **Admin web** | Surface d’attaque auth email ; dépend du durcissement Firebase Auth |

**Recommandation V2 :** revoir rules + Storage en même temps que le schéma ; durcir les endpoints TV/admin sensibles (Functions / gateway) ; ne jamais accepter secrets en query.

---

## Structure des dossiers

### Racine (pertinent)

```
android/, ios/, web/, macos/, windows/, linux/
lib/                 → application
functions/           → Cloud Functions
docs/                → runbooks
assets/images/
firestore.rules, storage.rules, firestore.indexes.json
firebase.json, .firebaserc
.github/workflows/
fastlane/
test/                → très léger
_backup/, trash/     → artefacts à exclure mentalement
tools/               → scripts split Dart / etc.
```

### `lib/screens/` (domaines UI)

`home`, `live`, `matches`, `articles`, `chat`, `prono`, `admin` (+ ~20 onglets), `admin_portal`, `auth`, `profile`, `calendar`, `notifications`, `benevole`, `esti_dvcr`, `world_cup`, `replay`, `search`, `social`, `tutorial`, `onboarding`.

### `lib/features/` (émergent)

- `prono/` — data/domain/presentation (hub)
- `admin/` — RBAC, routes, thème, logger
- `world_cup/` — écran tournoi

### Problèmes structurels

- Double hiérarchie screens/features.
- Admin tabs encore sous `screens/admin/tabs/` (pas feature-first).
- Widgets globaux trop « fourre-tout » pour le live et le partage.
- Pas de dossier `core/` / `shared/` formalisé.

---

## Qualité globale

### Synthèse

DVCR est un **produit fonctionnellement mature** pour un club / média communautaire : le match-day, les pronos, l’admin staff et les intégrations (FFF, Wix, HelloAsso, YouTube, TV) forment un système réel en production. En revanche, la **base de code a grossi organiquement** (~115k LOC Dart) avec une modularisation partielle, peu de tests, un schéma Firestore historique, et des écarts de sécurité (Storage, collections non règlées, endpoints publics).

La qualité « produit / métier » est supérieure à la qualité « ingénierie logicielle long terme ».

### Note : **5,5 / 10**

**Justification :**

| Critère | Note indicative | Commentaire |
|---------|-----------------|-------------|
| Couverture fonctionnelle | 8/10 | Très large, pertinente |
| Architecture / modularité | 4/10 | Monolithe + migration inachevée |
| Maintenabilité | 4/10 | God files, duplications, Maps |
| Sécurité | 6/10 | Rules solides mais trous Storage/collections/HTTP |
| Performance / scalabilité code | 5/10 | OK usage club ; fragile à la croissance |
| Tests / CI | 3/10 | CI minimale, tests presque absents |
| Ops / docs | 7/10 | Docs utiles, secrets listés, Functions modulaires |
| Cohérence schéma data | 4/10 | Alias, legacy, gaps rules |

**5,5** = « application de production utile, non encore industrialisée ». Objectif V2 : viser **8+** sur maintenabilité / architecture / tests **sans changer l’UX**.

---

## Annexes rapides

### Services client (`lib/services/`) — familles

- Auth / users / roles / account deletion  
- Matches / FFF / season lifecycle / lineups / stats / ratings / MOTM  
- Live (state, seed, start, activity, sticky, sounds, logos)  
- Articles / YouTube / home sections / banners  
- Prono social / season / onboarding / tournament / esti  
- Notifications / FCM / prefs  
- XP / referrals / favorites / preferences  
- Sponsors / share / bénévoles / HelloAsso / TV / search / feature flags / cache / version policy  

### Onglets admin actifs

Pilotage, Direct, Matchs, Statistiques match, Actus, Équipes & stades, Notifications, Membres, Chat & modération, Bénévoles, Adhérents, Pronos & jeux, XP & Niveaux, Réglages, Android TV, Journal, Staff & permissions.

### Stack cible V2 (rappel — hors scope code)

Flutter (dernière stable), Dart, Firebase, Riverpod, GoRouter, Dio (HTTP externes), Freezed, json_serializable, flutter_lints, build_runner, Material 3, GitHub Actions, tests + Firebase Emulator — voir `ARCHITECTURE.md` et `MIGRATION_PLAN.md`.
