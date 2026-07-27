# DVCR — Audit d’état des lieux (code vérifié)

**Date :** 2026-07-26  
**Workspace :** `C:\Users\axeld\Music\dvcr_appli`  
**Périmètre :** lecture seule du code applicatif — livrable **docs only** (`dvcr-v2/`).  
**App cible modernisation :** `dvcr_appli` (ADR-0004 — in-place).  
**Compléments :** `FEATURES.md`, `SCOPE_V2.md`, `MODERNIZATION_PLAN.md`, `PACKAGE_POLICY.md`, ADR-0001…0004, `modules/FOUNDATION_DONE.md`, `modules/AUTH.md`.  
**Synthèse priorités :** [`MIGRATION_PRIORITIES.md`](./MIGRATION_PRIORITIES.md).

> **Note méthode :** inventaire croisé avec l’arbre `lib/`, `functions/`, `pubspec.yaml` et les docs modules.  
> Un chantier Auth était **en cours sur le disque** pendant cet audit : l’état Auth ci-dessous reflète le code **au moment de la rédaction** (pas `AUTH.md` seul, qui était déjà partiellement obsolète).

---

## 1. Vue d’ensemble

### Produit

**DVCR** (« Drapeau Vert Carton Rouge ») — app communautaire club (référence tenant CSSA / CS Sedan Ardennes).  
Version `pubspec.yaml` : **1.0.6+56**, SDK Flutter `^3.5.0`, package name `dvcr`.

### Stack runtime

| Couche | Technologie | Preuve |
|--------|-------------|--------|
| Client mobile | Flutter (iOS / Android) | `lib/main.dart` → `_AppEntry` → `MainNavigation` |
| Admin web | Flutter Web | `kIsWeb` → `AdminWebScreen` (`lib/main_bootstrap.dart`) |
| Backend | Firebase Auth, Firestore, Storage, Messaging, Cloud Functions | `pubspec.yaml` + `functions/` |
| Functions runtime | Node **22** | `functions/package.json` → `"engines": { "node": "22" }` |
| TV | HTTP `tvApi` + Firestore | `functions/tv_api.js` |

### Point d’entrée

1. `main()` dans `lib/main.dart` : Firebase init, Firestore cache, `ProviderScope` → `DVCRApp`.
2. Parts : `main_bootstrap.dart`, `main_navigation.dart`, `main_shell_widgets.dart`.
3. Bootstrap services critiques via `_bootstrapCriticalServices()` (cache, match controller, FFF, notifs, flags…).
4. Flux phases `_AppEntry` : `loading` → `guest` / `register` / `tutorial` / `app` (voir §13 Auth).

### State management

| Pattern | Où | Commentaire |
|---------|-----|-------------|
| **Riverpod** | `ProviderScope` (`main.dart`), `lib/core/di/core_providers.dart`, `lib/features/auth/presentation/auth_providers.dart` | Introduit (Foundation) ; usage métier encore **limité** à Auth (+ marker `foundationReadyProvider`) |
| **setState / StreamBuilder** | Majorité `lib/screens/` | Dominant |
| **ChangeNotifier** | `MatchController`, `PodcastController`, `AdminController`, `UserPreferencesService` | Controllers legacy |
| **ValueNotifier** | ex. nav scale `MainNavigation`, index Prono | Local UI |
| GetX / Provider package / Bloc / GoRouter | **Absents** du `pubspec.yaml` | GoRouter = cible long terme (PACKAGE_POLICY / Foundation OUT) |

### Routing / navigation

| Mécanisme | Fichier | Détail |
|-----------|---------|--------|
| `MaterialApp` + routes nommées | `lib/app/app_router.dart` | `/register`, `/login`, `/calendar`, `/admin` |
| Shell onglets | `lib/main_navigation.dart` + `lib/navigation/app_shell_navigation.dart` | Accueil, DVCR TV, Calendrier, Actus, Communauté (flag), Pronos (flag) |
| Navigators imbriqués | Home tab `Navigator`, pushes profil / détail | Pattern V1 |
| Deep-links notifs | `handleDvcrNotificationPayload` / `pushScreenForNotificationData` | `app_router.dart` |
| Admin URL | `lib/features/admin/presentation/routing/admin_routes.dart` | `#/admin/<segment>` ; alias esti/cdm → pronos |
| Feature rollouts | `navigation/community_chat_rollout.dart`, `prono_championship_rollout.dart`, **`esti_dvcr_rollout.dart`**, **`world_cup_tab_rollout.dart`** | Deux derniers = hors core ADR-0002 |

**Volume :** ~**354** fichiers Dart sous `lib/` ; ~**115 700** lignes ; `screens/` ≈ **172** fichiers ; `services/` **61** ; `features/` **43+** ; `widgets/` **35** ; `models/` **11** ; `core/` **5**.

---

## 2. Fonctionnalités (inventaire produit)

Source de vérité produit annotée : **`dvcr-v2/FEATURES.md`** (légende ✅ cœur / ⛔ hors core ADR-0002 / ⚠️ à revoir).

Résumé des domaines **présents dans le code** :

| Domaine | Capacités observées | Disposition V2 |
|---------|---------------------|----------------|
| Auth & compte | Login, register, reset MDP, guest, tutorial, profil, favoris, prefs, RGPD deletion, force update, parrainage | ✅ (Auth en modernisation) |
| Shell / nav | Onglets + flags chat/prono ; rollouts WC/Esti encore dans le repo | ✅ cœur ; ⛔ WC/Esti |
| Home | Hero live/émission, MOTM, notes, sondage, sections média, actus, résultats, dons, partenaire | ✅ |
| Matchs / calendrier / FFF | Calendrier, détail, classement, sync FFF, replays liés | ✅ |
| Direct live | Score live, panel staff, compositions, salon live, Live Activity / sticky (packages) | ✅ / ⚠️ packages |
| DVCR TV / streaming | Playlists YouTube, featured, podcast, API TV | ✅ |
| Stats match | Workbench admin, preview/finalize callables | ✅ |
| Pronos championnat + social | Hub 4 onglets (`PronoRootShell`), duels, ligues, leaderboards | ✅ |
| Tournois / Esti / CdM | Écrans, services, Functions, admin sections | **⛔ ADR-0002** |
| Chat | Salons, réactions, modération | ✅ |
| Articles | Liste, détail, commentaires, éditeur, Wix | ✅ |
| Notifications | FCM, prefs, centre, file manuelle, triggers | ✅ |
| XP / badges | Gains, niveaux, admin XP, referral | ✅ |
| Adhérents / HelloAsso | Webhook, expiration, admin | ✅ |
| Bénévoles | Espace PDF, admin docs | ✅ |
| Sponsors / share | `SponsorService`, `DvcrShareService`, templates | ✅ |
| Admin centre | Shell RBAC multi-onglets + portail web | ✅ |

Détail exhaustif item par item : ne pas dupliquer ici — **renvoi `FEATURES.md`**.

---

## 3. Écrans / pages (chemins réels)

### 3.1 Racine `lib/screens/` — shims / re-exports

Beaucoup de fichiers racine ne font qu’`export` vers un sous-dossier (compat imports historiques) :

| Chemin shim | Cible |
|-------------|--------|
| `lib/screens/home_screen.dart` | `home/home_screen.dart` |
| `lib/screens/live_screen.dart` | `live/live_screen.dart` |
| `lib/screens/matches_screen.dart` | `matches/matches_screen.dart` |
| `lib/screens/match_detail_screen.dart` | `matches/match_detail_screen.dart` |
| `lib/screens/articles_screen.dart` | `articles/articles_screen.dart` |
| `lib/screens/article_editor_screen.dart` | `articles/article_editor_screen.dart` |
| `lib/screens/chat_screen.dart` | `chat/chat_screen.dart` |
| `lib/screens/prono_screen.dart` | `prono/prono_screen.dart` |
| `lib/screens/calendar_screen.dart` | `calendar/calendar_screen.dart` |
| `lib/screens/login_screen.dart` | `auth/login_screen.dart` → **feature Auth** |
| `lib/screens/register_screen.dart` | `auth/register_screen.dart` → **feature Auth** |
| `lib/screens/tutorial_screen.dart` | `tutorial/tutorial_screen.dart` |
| `lib/screens/onboarding_screen.dart` | `onboarding/onboarding_screen.dart` |
| `lib/screens/public_profile_screen.dart` | `profile/public_profile_screen.dart` |
| `lib/screens/notifications_center_screen.dart` | `notifications/…` |
| `lib/screens/global_search_screen.dart` | `search/…` |
| `lib/screens/social_links_screen.dart` | `social/…` |
| `lib/screens/replay_screen.dart` | `replay/…` |
| `lib/screens/admin_web_screen.dart` | `admin_portal/admin_web_screen.dart` |
| `lib/screens/admin_panel.dart` | `admin/admin_shell.dart` (`AdminShell`) |
| `lib/screens/tournament_prono_screen.dart` | `../features/world_cup/tournament_prono_screen.dart` |
| `lib/screens/world_cup_tab.dart` | `world_cup/world_cup_tab.dart` |

**Non-shim notable :** `lib/screens/profile_screen.dart` — fichier **plein** (~1250 lignes), pas un simple export.

### 3.2 Écrans métier (sous-dossiers)

| Dossier | Fichiers clés |
|---------|----------------|
| `lib/screens/home/` | `home_screen.dart`, `home_feed_*.dart`, `home_live_widgets.dart`, `home_media_sections.dart`, `home_motion.dart`, `home_palette.dart`, … |
| `lib/screens/live/` | `live_screen.dart`, `live_widgets.dart`, `live_helpers.dart`, `live_palette.dart` |
| `lib/screens/matches/` | `matches_screen.dart`, `matches_feed_tab.dart`, `matches_ranking_tab.dart`, `match_detail_screen.dart`, helpers/palettes |
| `lib/screens/calendar/` | `calendar_screen.dart` + controls/header/list/helpers/palette |
| `lib/screens/articles/` | `articles_screen.dart`, list/detail widgets, `article_editor_screen.dart` |
| `lib/screens/chat/` | `chat_screen.dart`, `chat_ui_parts.dart`, `chat_role_list_utils.dart` |
| `lib/screens/prono/` | `prono_screen.dart` (monolithe + `part` social), `prono_shell.dart`, `prono_palette.dart`, extras |
| `lib/screens/profile/` | `profile_account_screen.dart`, `profile_favorites_screen.dart`, `public_profile_screen.dart`, shell/palette |
| `lib/screens/auth/` | **re-exports** vers `lib/features/auth/presentation/screens/` |
| `lib/screens/tutorial/` | `tutorial_screen.dart` (utilisé par `_AppEntry`) |
| `lib/screens/onboarding/` | `onboarding_screen.dart` (**aucun appelant** trouvé hors définition → suspect code mort) |
| `lib/screens/notifications/` | `notifications_center_screen.dart` |
| `lib/screens/search/` | `global_search_screen.dart` |
| `lib/screens/benevole/` | `benevole_space_screen.dart`, `benevole_pdf_screen.dart` |
| `lib/screens/replay/` | `replay_screen.dart` |
| `lib/screens/social/` | `social_links_screen.dart` |
| `lib/screens/admin_portal/` | `admin_web_screen.dart` |
| Racine vidéo | `native_video_screen.dart`, `video_web_screen*.dart`, `force_update_screen.dart` |

### 3.3 Admin (`lib/screens/admin/`)

Shell : `admin_shell.dart`, `admin_sidebar.dart`, `admin_controller.dart`, `admin_tab_registry.dart`, `admin_nav_model.dart`, composants/dialogs/forms…

**Onglets enregistrés** dans `admin_tab_registry.dart` (ordre UI) :

| Label UI | Builder | Index (`AdminTabIndex`) |
|----------|---------|-------------------------|
| Pilotage | `tabs/dashboard/dashboard_tab.dart` | `dashboard` |
| Direct | `tabs/direct/direct_tab.dart` (+ `direct_live_salon_panel.dart`) | `direct` |
| Matchs | `tabs/matchs/matchs_tab.dart`, `match_editor.dart` | `matchs` |
| Statistiques match | `tabs/stats/*` (workbench, compare, reset Sedan, …) | `stats` |
| Actus | `tabs/articles/*` | `articles` |
| Équipes & stades | `tabs/stades/stades_tab.dart` | `stades` |
| Notifications | `tabs/diffusion/diffusion_tab.dart` | `notifs` |
| Membres | `tabs/users/users_tab.dart` | `users` |
| Chat & modération | `tabs/communaute/communaute_tab.dart` | `communaute` |
| Bénévoles | `tabs/benevoles/*` | `benevoles` |
| Adhérents | `tabs/adherents/adherents_tab.dart` | `adherents` |
| Pronos & jeux | `tabs/pronos/*` | `pronos` |
| XP & Niveaux | `tabs/xp/xp_tab.dart` | `xp` |
| Réglages | `tabs/settings/*` | `settings` |
| Android TV | `tabs/tv/tv_admin_tab.dart` | `tv` |
| Journal | `tabs/logs/logs_tab.dart` | `logs` |
| Staff & permissions | `tabs/staff/*` | `staff` |

**Dossiers admin encore présents mais hors registry principal / legacy événementiel :**

- `tabs/esti_dvcr/` — `esti_dvcr_admin_tab.dart` (**⛔**)
- `tabs/tournament/` — `tournament_tab.dart` (**⛔**)
- `tabs/notifs/` — sous-panels rappel (utilisés via diffusion / alias)
- `tabs/badges/` — dossier présent (alias index `badges` → staff/XP)
- Sous-sections pronos : `world_cup_partner_admin_section.dart`, `esti_dvcr_admin_section.dart` (**⛔**)

### 3.4 Features screens

| Chemin | Rôle |
|--------|------|
| `lib/features/auth/presentation/screens/login_screen.dart` | Login Riverpod (actif via re-export) |
| `lib/features/auth/presentation/screens/register_screen.dart` | Register Riverpod (actif via re-export) |
| `lib/features/prono/presentation/**` | Hub prono moderne (`PronoRootShell` branché dans `MainNavigation`) |
| `lib/features/world_cup/tournament_prono_screen.dart` | Tournoi / CdM (**⛔**) |

### 3.5 Écrans événementiels (toujours dans le repo)

- `lib/screens/esti_dvcr/esti_dvcr_tab.dart`, `esti_dvcr_leaderboard.dart`, `leagues/esti_dvcr_leagues_panel.dart`
- `lib/screens/world_cup/world_cup_tab.dart`
- `lib/features/world_cup/tournament_prono_screen.dart`

→ **Ne pas moderniser en modules cœur** (ADR-0002).

---

## 4. Services / controllers

Tous sous `lib/services/` (61 fichiers `.dart`) — pattern dominant : **classes / méthodes statiques** + accès Firestore/Firebase directs.

### 4.1 Liste complète

| Fichier | Domaine approximatif |
|---------|----------------------|
| `account_deletion_service.dart` | RGPD / suppression compte |
| `admin_user_firebase_actions_service.dart` | Actions Auth admin |
| `app_cache_service.dart` | Cache app |
| `app_settings_service.dart` | Réglages / settings Firestore |
| `app_update_dismiss_service.dart` | Bannière update optionnelle |
| `app_version_policy_service.dart` | Force / optional update |
| `article_comment_service.dart` | Commentaires actus |
| `article_service.dart` | Articles CRUD / lecture |
| `auth_service.dart` | **Façade legacy** → `AuthRepositoryImpl` (voir §13) |
| `benevole_space_service.dart` | Espace bénévoles |
| `dvcr_share_service.dart` | Partage natif |
| `emission_poll_service.dart` | Sondage émission |
| `esti_dvcr_league_service.dart` | **⛔ Esti** |
| `favorites_service.dart` | Favoris user |
| `fcm_token_service.dart` | Tokens FCM |
| `feature_flags_service.dart` | Flags runtime |
| `fff_sync_service.dart` | Sync FFF client |
| `global_search_service.dart` | Recherche globale |
| `helloasso_adhesion_service.dart` | Adhésions |
| `home_banner_service.dart` | Bannière home |
| `home_sections_service.dart` | Sections home configurables |
| `live_activity_push_sync.dart` | Sync Live Activity |
| `live_banner_format.dart` | Formats bannière live |
| `live_event_sound_service.dart` | Sons événements |
| `live_match_activity_service.dart` | Live Activity match |
| `live_match_phase.dart` | Phases chronomètre |
| `live_score_sticky_service.dart` | Sticky Android |
| `live_start_service.dart` | Démarrage direct |
| `live_state_service.dart` | État live courant |
| `live_team_logo_resolver.dart` | Logos équipes live |
| `match_controller.dart` | **ChangeNotifier** calendrier/matchs |
| `match_lineup_service.dart` | Compositions |
| `match_prono_stats_service.dart` | Stats 1-N-2 |
| `match_rating_service.dart` | Notes de match |
| `match_service.dart` | CRUD / lecture matchs |
| `match_stats_repository.dart` | Repo stats (nom « repository » legacy) |
| `match_stats_service.dart` | Stats match |
| `match_stats_sheet_service.dart` | Sheet stats UI/data |
| `motm_vote_service.dart` | Homme du match |
| `notification_prefs_service.dart` | Préférences canaux |
| `notification_service.dart` | Notifs locales / FCM wiring |
| `podcast_controller.dart` | **ChangeNotifier** audio |
| `prono_onboarding_service.dart` | Onboarding équipe favorite prono |
| `prono_season_service.dart` | Saison prono |
| `prono_social_activity_service.dart` | Feed social prono |
| `prono_social_service.dart` | Amis / duels / ligues |
| `referral_service.dart` | Parrainage |
| `role_permissions_service.dart` | Matrice RBAC admin |
| `season_config_service.dart` | Config saison |
| `season_lifecycle_service.dart` | Hors-saison / messages |
| `seed_service.dart` | Seed live / données |
| `share_templates_cache.dart` | Cache templates partage |
| `sponsor_service.dart` | Sponsors |
| `team_dvcr_members_service.dart` | Membres Team DVCR |
| `tournament_service.dart` | **⛔ Tournois** |
| `user_preferences_service.dart` | **ChangeNotifier** prefs |
| `user_service.dart` | Profils users |
| `video_featured_service.dart` | Vidéo mise en avant |
| `vote_history_service.dart` | Historique votes |
| `xp_service.dart` | XP client |
| `youtube_playlist_service.dart` | Playlists YouTube |

### 4.2 Controllers hors `services/`

- `lib/screens/admin/admin_controller.dart` — `ChangeNotifier` shell admin.

---

## 5. Modèles

### 5.1 `lib/models/` (legacy Map / fromMap)

| Fichier | Rôle |
|---------|------|
| `article_model.dart` | Article |
| `benevole_document.dart` | Doc bénévole |
| `benevole_space_config.dart` | Config espace |
| `fff_season_config.dart` | Saison FFF |
| `match_lineup.dart` | Compositions |
| `match_model.dart` | Match |
| `match_stats_schema.dart` | Schéma stats |
| `season_lifecycle_config.dart` | Lifecycle saison |
| `user_model.dart` | User profil |
| `user_role.dart` | Enum / helpers rôles |
| `video_model.dart` | Vidéo / replay |

### 5.2 Domain Auth (Freezed **déclaré**, codegen **absent**)

| Fichier | Annotation |
|---------|------------|
| `lib/features/auth/domain/entities/auth_user.dart` | `@freezed` + `part 'auth_user.freezed.dart'` |
| `lib/features/auth/domain/entities/auth_session.dart` | `@freezed` + `part 'auth_session.freezed.dart'` |

**Constat audit :** aucun `*.freezed.dart` / `*.g.dart` sous `lib/` au moment de la rédaction → **codegen Freezed non généré** (module Auth non clos côté build).

### 5.3 Domain Prono (partiel)

- `lib/features/prono/domain/models/prono_match_list_item.dart`
- `lib/features/prono/domain/repositories/prono_repository.dart`
- Impl : `lib/features/prono/data/firestore_prono_repository.dart`

---

## 6. Providers / state

### 6.1 Riverpod

| Provider | Fichier |
|----------|---------|
| `foundationReadyProvider` | `lib/core/di/core_providers.dart` |
| `authFirebaseDatasourceProvider` | `lib/features/auth/presentation/auth_providers.dart` |
| `authRepositoryProvider` | idem |
| `signInProvider` / `registerUserProvider` / `resetPasswordProvider` / `signOutProvider` | idem |
| `authSessionProvider` (`StreamProvider`) | idem |

Barrel public : `lib/features/auth/auth.dart`.

### 6.2 Hors Riverpod (toujours majoritaire)

- `FirebaseAuth.instance` / `authStateChanges` : **~50+ fichiers** hors datasource Auth (home, chat, admin, prono, widgets votes, services…).
- Streams Firestore inline dans les écrans.
- Controllers `ChangeNotifier` listés §4.
- `FeatureFlagsService` + rollouts navigation.

### 6.3 Pas de dossier `lib/providers/`

DI modernisée = providers **dans** `core/` et `features/*/presentation/`.

---

## 7. Widgets réutilisables

### 7.1 `lib/widgets/` (35)

`admin_bounded_image_preview.dart`, `app_update_hero_image.dart`, `app_update_optional_banner.dart`, `article_row.dart`, `chat_sticker_image.dart`, `cssa_favorite_ranking_share_button.dart`, `donation_banner.dart`, `dvcr_action_button.dart`, `dvcr_card.dart`, `dvcr_member_role_badge.dart`, `dvcr_reveal.dart`, `dvcr_share_favorite_controls.dart`, `dvcr_skeleton.dart`, `emission_poll_home_card.dart`, `empty_state_panel.dart`, `favorite_team_picker_sheet.dart`, `live_interaction_card_ui.dart`, `live_interaction_home_slot.dart`, `live_match_quick_panel.dart`, `live_start_match_picker.dart`, `live_stats_sheet.dart`, `match_card.dart`, `match_card_bottom_panel.dart`, `match_lineup_editor_sheet.dart`, `match_lineups_detail_card.dart`, `match_rating_home_card.dart`, `match_rating_summary.dart`, `member_badge_info.dart`, `member_role_badges_preview.dart`, `motm_vote_home_card.dart`, `network_banner.dart`, `powered_by_partner_encart.dart`, `powered_by_partner_image.dart`, `prono_leaderboard_style.dart`, `section_header.dart`.

### 7.2 Widgets Auth feature

`lib/features/auth/presentation/widgets/` : `auth_palette.dart`, `auth_text_field.dart`, `auth_hero_banner.dart`, `auth_register_form_body.dart`.

### 7.3 Widgets Prono feature

`prono_gamified_encart.dart`, `prono_tab_hero_sliver.dart`, + pages presentation.

### 7.4 Theme / constants / utils

- Theme : `lib/theme/dvcr_theme.dart`, `app_colors.dart`, `dvcr_page_transitions.dart`
- Constants : `lib/constants/club_branding.dart` (**hardcode CSSA/Sedan**), `notification_channels.dart`
- Utils : `lib/utils/` — `match_calendar_filter.dart`, `share_helper.dart`, `roles.dart`, `youtube_parser.dart`, `open_prono_for_match.dart`, etc.

**Pas de `lib/shared/`** (volontaire Foundation — `FOUNDATION_DONE.md`).

---

## 8. Dépendances `pubspec.yaml` vs `PACKAGE_POLICY.md`

### 8.1 Stack de base (politique) — statut dans le repo

| Autorisé sans ADR (policy) | Présent ? | Note |
|----------------------------|-----------|------|
| Flutter SDK | ✅ | |
| Firebase (Auth, Firestore, Storage, Messaging, Functions) | ✅ | + `firebase_core` |
| Riverpod (`flutter_riverpod`) | ✅ | Foundation |
| GoRouter | ❌ | Non introduit (OUT Foundation ; phase Navigation) |
| Dio | ❌ | `http` utilisé à la place |
| Freezed + json_serializable + build_runner | ✅ deps | **codegen Auth manquant** |
| flutter_lints | ✅ | `^6.0.0` |
| Material 3 / tests Flutter | ✅ | |

### 8.2 Dépendances présentes — hors stack de base (legacy V1 / ADR requis pour « revalidation » V2)

D’après `PACKAGE_POLICY.md` (exemples typiques nécessitant ADR) :

| Package | Usage typique observé |
|---------|----------------------|
| `google_fonts` | Typo app / auth / prono |
| `cupertino_icons` | Icônes |
| `shared_preferences` | Prefs locales / tutorial / dismiss |
| `youtube_player_iframe`, `webview_flutter`, `video_player`, `chewie`, `youtube_explode_dart` | Lecteurs / TV |
| `http`, `url_launcher`, `share_plus`, `package_info_plus` | Réseau / liens / partage / version |
| `intl` | Dates FR |
| `lottie` | Animations |
| `audioplayers`, `audio_service` | Podcast / sons |
| `fl_chart` | Graphiques |
| `connectivity_plus` | Bannière réseau |
| `flutter_local_notifications`, `timezone` | Notifs locales |
| `flutter_markdown`, `flutter_html` | Contenu riche actus |
| `live_activities` | Live Activity iOS |
| `cloud_functions` | Callables client |

**Override :** `path_provider_foundation: 2.5.1` (commentaire App Store / FFI dans `pubspec.yaml`).

**Écart policy ↔ réalité :** la politique décrit la **discipline d’ajout V2** ; le `pubspec` actuel est un **héritage V1 complet**. Aucun ADR package individuel inventorié pour chaque dep legacy — à traiter module par module (ne pas « nettoyer » le pubspec en big-bang).

---

## 9. Cloud Functions — aperçu

**Entrée :** `functions/index.js`  
- `Object.assign(exports, require(mod))` pour la liste `MODULES`  
- Re-exports explicites Wix + HelloAsso  

### 9.1 Modules chargés via `MODULES`

| Fichier | Exports / rôle (vérifiés) |
|---------|---------------------------|
| `notification_triggers.js` | `notifyArticlePublished`, `notifyTeamDvcrPdfUpdated`, `notifyChatMention`, `notifyDuelCreated`, `notifyFriendRequest`, `notifyDuelResolved`, `notifyMatchRecap`, `cleanOldChatMessages`, `cleanArchivedLiveSalons` |
| `youtube_sync.js` | `syncYoutubeVideos`, `syncYoutubeVideosManual` |
| `fff_sync.js` | `syncFffData`, `syncFffDataOnCalendarOpen`, `syncFffDataManual`, `testFffSeasonConfig`, `archiveClubRankingSeason` |
| `match_callables.js` | `getMatchReminderCandidates`, `sendMatchReminderManual`, `notifyLineups` |
| `prono_scoring.js` | `calculatePronoPoints`, `syncMatchPronoOutcomeStats`, `ensurePronoSeasonBootstrap`, `notifyRankingMotivation`, `resetPronoSeason` |
| `live_push.js` | `notifyEmission`, `notifyGoal` |
| `manual_notifications.js` | `sendManualNotification` |
| `xp_system.js` | `awardXp`, `onMatchFinished`, `onXpUpdate`, `onUserDocCreated`, `useReferralCode`, `getReferralStats`, `weeklyXpLeaderboard`, `adminRecomputeLeaguePowerRankings`, `syncDvcrAuthClaims`, `refreshDvcrAuthClaims`, `adminDeleteAuthUser`, `archiveCompetitionSeason` |
| `tv_api.js` | `tvLiveHeartbeat`, `tvApi`, `setTvStreamConfig` |
| `match_stats.js` | `syncMatchStatsPreview`, `syncMatchStatsPreviewManual`, `finalizeMatchStats`, `setMatchStatsPublicationState`, `reopenMatchStats`, `migrateMatchStatsFromMatches`, `resetSedanSeasonStats` |
| `tournament_scoring.js` | **⛔** `recalculateTournamentMatchScoring`, `recalculateWorldCupLeaderboard`, `undoWorldCupMatchScoring`, `fixEstiDvcrMatchDays` |

### 9.2 Autres fichiers racine

| Fichier | Note |
|---------|------|
| `wix_article_webhook.js` | `wixArticleWebhook`, `enrichWixArticleFromSite` (exportés dans `index.js`) |
| `helloasso_webhook.js` | `helloAssoWebhook`, `expireHelloAssoAdherents` |
| `notification_push.js` | Helpers FCM (`module.exports` utilitaires — pas forcément des Functions déployées) |
| `admin_app.js` | Module utilitaire admin |
| Scripts one-shot | `addFakePronoData.js`, `cleanup2024.js`, `import2024.js`, `trigger_sync.js`, … |
| `functions/lib/` | `admin_auth.js`, `app_brand.js`, `fff_config.js`, `format_utils.js`, `push_helpers.js`, `xp_core.js` |

**Deps Functions :** `firebase-admin`, `firebase-functions`, `axios`, `fast-xml-parser`, `cheerio`.

---

## 10. Doublons / dualités structurelles

| Dualité | Chemins | État |
|---------|---------|------|
| Auth screens legacy vs feature | `screens/auth/*` = **re-export** → `features/auth/presentation/screens/*` | Dualité **résolue en shim** (plus deux implémentations UI) |
| AuthService vs AuthRepository | `services/auth_service.dart` façade sur repo | Dette acceptée documentée dans le service |
| Prono hub feature vs monolithe screens | `features/prono/.../PronoRootShell` **et** `screens/prono/prono_screen.dart` (+ social part) | Coexistence : shell feature importe encore `screens/prono` |
| Prono palette / theme | `screens/prono/prono_palette.dart` + `features/prono/presentation/theme/*` | Duplication tokens / couleurs |
| Profile | `profile_screen.dart` (racine pleine) + `screens/profile/*` | Split incomplet |
| Articles / calendar / etc. | shim racine + dossier | Pattern normal de migration |
| Admin routing | `features/admin/presentation/routing/*` + shell `screens/admin/*` | Admin partiel Feature First |
| World Cup | `screens/world_cup/` + `features/world_cup/` | **⛔** — ne pas unifier en core |
| Esti admin | `tabs/esti_dvcr/` + section dans `tabs/pronos/` | Redondance legacy |
| Alias routes admin | `coupe-du-monde`, `esti-dvcr`, `tournament` → tab pronos | Compat ; pas à industrialiser |

---

## 11. Code mort / suspects (non exhaustif — indices de code)

| Suspect | Preuve | Verdict audit |
|---------|--------|---------------|
| `OnboardingScreen` | Aucun `OnboardingScreen(` hors sa définition | **Suspect mort** (tutoriel actif = `TutorialScreen`) |
| Dossiers admin `tabs/esti_dvcr`, `tabs/tournament` | Non listés dans `adminTabDefs` | **Legacy / hors registry** — encore référençables ailleurs ; ⛔ |
| `authSessionProvider` | Défini mais `_AppEntry` souscrit via `authRepo.watchSession()` | Provider **sous-utilisé** (pas mort) |
| Scripts Functions one-shot (`cleanup2024`, `import2024`, `addFakePronoData`) | Hors `MODULES` | Outils ops — pas runtime app |
| `migrateMatchStatsFromMatches` | Callable legacy (FEATURES ⛔) | Outil one-shot |
| Ancien audit `DVCR_AUDIT.md` | Affirme « Pas de Riverpod » | **Doc obsolète** vs code actuel |

> Ne pas supprimer sans vérification d’imports dynamiques / deep-links / flags runtime.

---

## 12. Dette technique (principale)

1. **Monolithe UI** — ~172 fichiers `screens/`, Home/Admin/Prono très denses ; Feature First seulement amorcé (`auth`, `prono`, `admin` partiel, `world_cup` ⛔).
2. **~61 services statiques** — Maps Firestore, peu de ports domain ; anti-pattern à ne plus étendre (ARCHITECTURE / MODERNIZATION_PLAN).
3. **Couplage `FirebaseAuth.instance`** — encore massif hors périmètre Auth (dette acceptée AUTH.md pour consumers).
4. **Hardcode club** — `lib/constants/club_branding.dart` + nombreuses occurrences Sedan/CSSA (calendrier, stats, share, reset saison…).
5. **Pas de GoRouter** — navigators imbriqués + `GlobalKey` ; deep-links notifs custom.
6. **Freezed Auth non généré** — risque compile / CI tant que `build_runner` non exécuté / artefacts non commités.
7. **Tests maigres** — `test/core/foundation_core_test.dart`, `widget_test.dart`, `share_template_settings_test.dart` ; **aucun test auth** trouvé.
8. **Modules événementiels encore dans le graphe** — services, rollouts, Functions `tournament_scoring`, UI — dette produit vs ADR-0002 (ne pas moderniser ; isolation future).
9. **Admin index aliases historiques** — `tournament`, `estiDvcr`, `badges`, `matchReminder` conservés pour URL.
10. **Dualité Prono** — feature shell + monolithe `prono_screen.dart`.
11. **Docs modules** — `AUTH.md` encore rédigé comme « Auth absent » alors que le code a avancé ; pas de `AUTH_DONE.md`.

---

## 13. Modules à refactoriser + état Foundation / Auth

### 13.1 Foundation — **FAIT**

Preuve : `dvcr-v2/modules/FOUNDATION_DONE.md` (2026-07-26).

Livré (vérifié code) :

- `flutter_riverpod` + `ProviderScope` dans `lib/main.dart`
- `lib/core/` : `core.dart`, `config/app_config.dart`, `di/core_providers.dart`, `errors/app_failure.dart`, `errors/result.dart`
- Prep Freezed dans `pubspec.yaml` (dev + annotations)
- GoRouter **non** introduit (conforme OUT)
- Test : `test/core/foundation_core_test.dart`
- Script review : `dvcr-v2/scripts/architecture_review.ps1`

### 13.2 Auth — **EN COURS / NON CLOS** (pas de `AUTH_DONE.md`)

Arbre réel `lib/features/auth/` :

```
auth.dart                          # barrel public
data/datasources/auth_firebase_datasource.dart
data/mappers/auth_error_mapper.dart
data/mappers/auth_user_mapper.dart
data/repositories/auth_repository_impl.dart
domain/entities/auth_session.dart  # Freezed déclaré
domain/entities/auth_user.dart     # Freezed déclaré
domain/repositories/auth_repository.dart
domain/usecases/{sign_in,register_user,reset_password,sign_out}.dart
presentation/auth_providers.dart
presentation/screens/{login,register}_screen.dart
presentation/widgets/{auth_palette,auth_text_field,auth_hero_banner,auth_register_form_body}.dart
```

**Branché :**

- `lib/screens/auth/login_screen.dart` / `register_screen.dart` → export feature
- `lib/main.dart` importe `features/auth/auth.dart`
- `_AppEntry` = `ConsumerStatefulWidget` ; session via `authRepositoryProvider` / `AuthSession`
- `AuthService` = façade documentée sur `AuthRepositoryImpl`

**Manque pour DoD `AUTH.md` :**

| Critère DoD | État observé |
|-------------|--------------|
| Feature First data/domain/presentation | ✅ structure |
| Écrans sans Firebase Auth direct | ✅ (passent providers) |
| AuthService retiré du chemin chaud **ou** façade | ✅ façade |
| Freezed généré + utilisable | ❌ pas de `*.freezed.dart` |
| Tests mappers / repo fake | ❌ absents |
| Architecture Review PASS + `AUTH_DONE.md` + GO user | ❌ |
| Remplacer tous les `FirebaseAuth.instance` app | Hors scope — encore massif |

**Verdict :** Auth = **premier chantier fonctionnel à clôturer** avant Home. Ne pas démarrer Home / Sponsors tant que Auth n’a pas Review PASS + GO (MODERNIZATION_PLAN §4–5).

### 13.3 Autres modules (état)

| Module | État code | Priorité modernisation |
|--------|-----------|------------------------|
| Home | `screens/home/*` monolithique, services home_* | **Après Auth** |
| Sponsors | `sponsor_service.dart` + widgets powered-by / donation | Simple — après Home (plan) |
| Prono | Feature amorcée + screens legacy | Tranche ultérieure |
| Admin | `features/admin` (RBAC, routes, theme) + `screens/admin` | Tardif / par domaine |
| Matches / Live / Chat / Articles / Notifs / XP / Profile / Benevoles / Adherents | Quasi 100 % `screens/` + `services/` | Simple → complexe après Sponsors |
| World Cup / Esti / Tournois | Présents | **⛔ hors file core** (ADR-0002) |

### 13.4 Ordre directeur (rappel)

`MODERNIZATION_PLAN.md` : **Foundation → Auth → Home → Sponsors → …** ; un module à la fois ; UX figée.

---

## 14. Priorités Forte / Moyenne / Faible

Voir aussi synthèse dédiée : [`MIGRATION_PRIORITIES.md`](./MIGRATION_PRIORITIES.md).

### Forte

| # | Priorité | Justification |
|---|----------|---------------|
| F1 | **Clôturer Auth** (codegen Freezed, tests, Review PASS, `AUTH_DONE.md`, GO) | Socle session ; code déjà amorcé mais DoD incomplet ; bloque Home proprement |
| F2 | **Module Home (composition)** après GO Auth | Cœur UX app ; orchestrateur de services live/actus/dons — 2ᵉ module plan |
| F3 | **Respect strict ADR-0002** — ne pas industrialiser Esti / World Cup / tournois dans le core | Code encore présent ; risque de « moderniser au cas où » ; hors scope commercialisable |

### Moyenne

| # | Priorité | Justification |
|---|----------|---------------|
| M1 | **Sponsors** (petit module Feature First post-Home) | Surface isolée ; valide le cycle méthode |
| M2 | **Réduire dualité Prono** (`features/prono` vs `screens/prono`) sans redesign | Déjà amorcé ; dette structurelle |
| M3 | **Articles (lecture)** ou tranche Prono selon GO | Simple → complexe |
| M4 | **Isoler progressivement** imports WC/Esti (flags / package optionnel) sans les porter en core | Dette ADR-0002 côté repo |
| M5 | **TenantConfig** — sortir hardcodes CSSA des zones **nouvellement** touchées | `club_branding.dart` + occurrences |

### Faible (plus tard / ops)

| # | Priorité | Justification |
|---|----------|---------------|
| f1 | GoRouter cutover | Explicitement différé |
| f2 | Remplacer tous les `FirebaseAuth.instance` consumers | Hors Auth DoD ; tranche consumers |
| f3 | Dio vs `http` | Pas bloquant |
| f4 | Nettoyage `OnboardingScreen` / scripts Functions one-shot | Après confirmation |
| f5 | Rewrite admin shell complet | Trop large ; découper par onglet |
| f6 | Live Activity / charts / markdown ADR formels | Quand le module concerné est touché |

---

## 15. Fichiers `features/` — inventaire rapide

```
lib/features/admin/     # application, domain RBAC, presentation (tabs helpers, routing, theme)
lib/features/auth/      # Feature First complet (structure) — module à clôturer
lib/features/prono/     # data/domain/presentation + prono_public.dart
lib/features/world_cup/ # ⛔ tournament_prono_screen.dart
```

---

## 16. Références croisées docs `dvcr-v2/`

| Doc | Rôle |
|-----|------|
| `STRATEGY.md`, `ARCHITECTURE.md` | Principes |
| `SCOPE_V2.md` | IN/OUT |
| `FEATURES.md` | Inventaire fonctionnel ✅/⛔/⚠️ |
| `MODERNIZATION_PLAN.md` | Ordre modules |
| `PACKAGE_POLICY.md` | Dépendances |
| `ADR-0002` | Pas d’Esti/WC en core |
| `ADR-0004` | Modernisation in-place |
| `modules/FOUNDATION_DONE.md` | Foundation livré |
| `modules/AUTH.md` | Spec Auth (mettre à jour après clôture) |
| `DVCR_AUDIT.md` | Audit antérieur — **partiellement obsolète** (Riverpod/core) |

---

*Fin de l’audit d’état des lieux. Aucun fichier sous `lib/`, `test/`, `functions/`, ni `pubspec.yaml` modifié pour produire ce document.*
