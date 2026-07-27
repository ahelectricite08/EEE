# DVCR — Rationalisation par fonctionnalité

**Date :** 2026-07-26  
**Complément :** [`RATIONALIZATION_AUDIT.md`](./RATIONALIZATION_AUDIT.md)  
**ADR-0005 :** tout ❌ / batch 🔄 = **proposal only**, pas d’exécution sans GO.

### Légende

| ✅ | 🔄 | ⚠️ | ❌ |
|----|----|----|-----|
| Conserver | Fusionner | Vérifier | Candidat suppression |

---

## Auth

**Rôle :** inscription, connexion, reset MDP, session, bridge legacy.

**Fichiers :**
- `lib/features/auth/**` (data/domain/presentation, barrel `auth.dart`)
- Shims : `lib/screens/auth/*`, `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`
- Façade : `lib/services/auth_service.dart`
- Bootstrap : `lib/main.dart` (`watchSession`)
- Tests : `test/features/auth/*`

**Dépendances :** Firebase Auth/Firestore, Riverpod, Freezed, `AppFailure`/`Result`, Referral/Tutorial (register).

**Utilisé :** UI login/register, use cases, repository, `AuthService.errorMessage` (profile / admin_web).

**Inutilisé / dette :** méthodes façade auth peu appelées hors `errorMessage` (voir `AUTH_CLEANUP_PROPOSAL`).

**Reco :**
- ✅ Feature Auth
- 🔄 Imports → barrel ; ❌ shims (`AUTH_CLEANUP` A1)
- 🔄 Amincir / ❌ façade après migration errorMessage (A2)
- 🔄 `UserModel` vs `AuthUser` — différer Profile (A3)
- ⚠️ `FirebaseAuth.instance` hors Auth — modules futurs

---

## Home

**Rôle :** feed Accueil (hero live, sections, actus, résultats, média, dons, mini WC).

**Fichiers :**
- `lib/features/home/**` (repository, Freezed, providers, **UI T2** `presentation/screens` + widgets)
- Shims / placeholders : `lib/screens/home/*`, `lib/screens/home_screen.dart`
- Façades : `lib/services/home_sections_service.dart`, `home_banner_service.dart`
- Backup/outils : `_t2_src_backup/`, `_t2_*.py` (racine)
- Tests : `test/features/home/`

**Dépendances :** Live/Match/Articles services, TournamentService (mini-card), FeatureFlags, WorldCup rollout, widgets MOTM/poll/donation, Auth (encore `FirebaseAuth` par endroits).

**Utilisé :** `HomeScreen` via chaîne re-export ; providers layout/banner/sections ; admin banner via `HomeBannerService`.

**Inutilisé :** `HomeSectionsService` — **0 call site** dans `lib/` (providers remplacent).

**Reco :**
- ✅ Domain/data/providers Home
- ⚠️ **T2 en cours** : syntaxe cassée (`with` dupliqué) dans `home_screen.dart` feature
- ⚠️ UI importe encore `features/home/data/**` — passer par providers
- ❌ `HomeSectionsService` après verify (`HOME_CLEANUP` H1)
- 🔄 puis ❌ placeholders `screens/home/home_feed_*.dart` + shims palette après migration imports externes
- 🔄 DI unique `HomeRepositoryImpl`
- ⛔ mini-card WC — ne pas industrialiser
- ❌ `_t2_*` après GO T2 clos

---

## Prono (championnat + social)

**Rôle :** hub 4 onglets, saisie, progression, duels/ligues/amis, admin saison.

**Fichiers :**
- `lib/features/prono/**` (shell, pages, theme, `FirestorePronoRepository`, models)
- Legacy : `lib/screens/prono/*` (`prono_screen` ~1918 L, social part ~1885 L, shell, palette, extras)
- Services : `prono_social_service`, `match_prono_stats_service`, + **orphelins** `prono_onboarding_service`, `prono_season_service`, `prono_social_activity_service`
- Admin : `screens/admin/tabs/pronos/*`
- Utils : `open_prono_for_match.dart`
- Functions : `prono_scoring.js`

**Dépendances :** Firestore collections prono_*, MatchController/matchs, XP, notifs duels, theme tokens, share/partner widgets.

**Utilisé :** `PronoRootShell` dans `MainNavigation` ; pages feature ; gros `prono_screen` encore importé ; `PronoSocialService`.

**Inutilisé :** 3 services prono listés (classes sans référence).

**Reco :**
- ✅ Hub feature + scoring Functions
- 🔄 Fusionner monolithe `screens/prono` → feature (module Prono)
- 🔄 Palette screens ↔ theme feature
- ❌ 3 services orphelins (GO + verify prefs keys)
- ⚠️ Hybride architecture (pas encore domain Freezed complet)

---

## Matchs / Calendrier / FFF

**Rôle :** calendrier, détail, classement, sync FFF.

**Fichiers :**
- `lib/screens/matches/**` (dont `match_detail_screen` ~3352 L, feed ~1793, ranking)
- `lib/screens/calendar/**` + route `/calendar`
- Services : `match_service`, `match_controller`, `fff_sync_service`, lineup/rating liés
- Models : `match_model`, `match_lineup`, `fff_season_config`
- Utils : `match_calendar_filter`, `match_competition`
- Widgets : `match_card*` (~2163)
- Admin : `tabs/matchs/*`, stades
- Functions : `fff_sync.js`, `match_callables.js`

**Dépendances :** Firestore matches/ranking, Live, Prono open, Share, YouTube replay.

**Utilisé :** onglet Matchs + route calendar + admin éditeur.

**Inutilisé :** ⚠️ redondance `CalendarScreen` vs onglet — fusion UX à trancher.

**Reco :**
- ✅ domaine cœur
- ⚠️ split monolithes detail/feed/card (module Matchs)
- 🔄 éventuel merge calendar route
- ❌ aucun service match clairement mort

---

## Live (direct / score / interactions)

**Rôle :** état live, panel staff, MOTM, notes, sondage, Live Activity, sticky.

**Fichiers :**
- Services : `live_state_service`, `live_start_service`, `live_match_phase`, `live_banner_format`, `live_match_activity_service`, `live_activity_push_sync`, `live_score_sticky_service`, `live_event_sound_service`, `live_team_logo_resolver`, `motm_vote_service`, `match_rating_service`, `emission_poll_service`, `seed_service`
- Widgets : `live_match_quick_panel`, `live_interaction_*`, `motm_vote_home_card`, `match_rating_*`, `emission_poll_home_card`, `live_stats_sheet`
- Admin : `tabs/direct/*` (~3167 L)
- Functions : `live_push.js`

**Dépendances :** `live_activities`, notifs, Home, Matchs, Chat salon live.

**Utilisé :** Accueil + Admin Direct + packages live.

**Reco :**
- ✅ cœur match-day
- ⚠️ taille Direct/quick_panel — split module Live
- ⚠️ packages Live Activity = platform-specific

---

## Streaming / DVCR TV

**Rôle :** onglet TV, playlists YouTube, featured, podcast, API box.

**Fichiers :**
- `lib/screens/live/*` (catalogue TV), `replay_screen`, `native_video_screen`, `video_web_screen*`
- Services : `youtube_playlist_service`, `video_featured_service`, `podcast_controller`
- Models : `video_model`
- Admin : `tabs/tv`, settings TV panels
- Functions : `youtube_sync.js`, `tv_api.js`

**Dépendances :** `webview_flutter`, `video_player`, `chewie`, `youtube_explode_dart`, `audio_service`/`audioplayers`.

**Inutilisé package :** `youtube_player_iframe` ❌ 0 import ; `lottie` ❌.

**Reco :**
- ✅ TV / streaming
- ❌ candidats packages non importés (GO + smoke)
- ⚠️ podcast controller volumineux

---

## Stats match

**Rôle :** saisie / preview / finalize stats, compare, historique votes.

**Fichiers :**
- Admin `tabs/stats/**` (editor ~2152, compare, workbench…)
- Services : `match_stats_*`, `vote_history_service`
- Model : `match_stats_schema` (~501 L)
- Functions : `match_stats.js`

**Reco :**
- ✅
- ⛔ `migrateMatchStatsFromMatches` one-shot
- ⚠️ `resetSedanSeasonStats` / card Sedan — hardcode tenant
- ⚠️ split editors

---

## Chat / Communauté

**Rôle :** salons, réactions, modération admin.

**Fichiers :**
- `lib/screens/chat/**` (`chat_ui_parts` ~2721)
- Utils : `chat_reactions.dart`
- Widget : `chat_sticker_image`
- Admin : `tabs/communaute/**`
- Functions : triggers mentions / clean salons

**Reco :**
- ✅
- ⚠️ découper `chat_ui_parts`
- 🔄 Auth session vs `FirebaseAuth` dans chat

---

## Articles / Actus

**Rôle :** liste, détail HTML/Wix, commentaires, éditeur admin, webhook Wix.

**Fichiers :**
- `lib/screens/articles/**`
- Services : `article_service`, `article_comment_service`
- Model : `article_model`
- Admin : `tabs/articles/*`
- Functions : `wix_article_webhook.js` (~1010 L)

**Dépendances :** `flutter_html`, `webview_flutter` (fallback Wix).

**Inutilisé :** `flutter_markdown` ❌.

**Reco :**
- ✅
- ❌ markdown package si confirmé
- ⚠️ taille `articles_screen`

---

## Notifications

**Rôle :** FCM, prefs, centre, file manuelle, reminders.

**Fichiers :**
- `notifications_center_screen`
- Services : `notification_service`, `notification_prefs_service`, `fcm_token_service`
- Admin : `tabs/diffusion`, `tabs/notifs/*`
- Constants : `notification_channels.dart`
- Functions : `notification_triggers.js`, `manual_notifications.js`, `notification_push.js`

**Reco :**
- ✅
- ⚠️ `timezone` utilisé via notification_service

---

## XP / Badges / Referral

**Rôle :** gains XP, leaderboards, parrainage, badges membres.

**Fichiers :**
- Services : `xp_service`, `referral_service`
- Admin : `tabs/xp`
- Widgets : `dvcr_member_role_badge`, `member_badge_info`, `member_role_badges_preview`
- Functions : `xp_system.js`, `lib/xp_core.js`
- Admin settings : `staff_role_badges_panel`

**Reco :**
- ✅
- 🔄 badges index alias admin historiques — ⚠️

---

## Bénévoles

**Rôle :** espace PDF / docs, admin notifs bénévoles.

**Fichiers :**
- `screens/benevole/*`
- Services : `benevole_space_service`, `team_dvcr_members_service`
- Models : `benevole_*`
- Admin : `tabs/benevoles/**`

**Reco :**
- ✅
- ⚠️ panels notifs volumineux (~1000 L)

---

## Adhérents / HelloAsso

**Rôle :** adhésions, expiration, admin liste.

**Fichiers :**
- Service : `helloasso_adhesion_service`
- Admin : `tabs/adherents`
- Functions : `helloasso_webhook.js`

**Reco :**
- ✅

---

## Profile / Settings (user) / Share

**Rôle :** hub profil, compte, favoris, prefs, partage, update app.

**Fichiers :**
- `lib/screens/profile_screen.dart` (~1206) + `screens/profile/*`
- Services : `user_service`, `user_preferences_service`, `favorites_service`, `account_deletion_service`, `dvcr_share_service`, `share_templates_cache`, `app_version_policy_service`, `app_update_dismiss_service`
- Utils : share_*
- Widgets : share/favorite/donation/partner/update banners
- ❌ `subscription_screen.dart` orphelin
- ❌ `OnboardingScreen` (tutorial = autre écran)
- Admin settings share section : déjà retirée côté git (D) — templates Firestore restent via services

**Reco :**
- ✅ domaine
- 🔄 unifier profile hub → `features/profile` futur
- ❌ subscription + onboarding legacy
- ❌ `utils/roles.dart` (doublon string vs `UserRole`)

---

## Sponsors

**Rôle :** partenaires, powered-by, encarts.

**Fichiers :**
- `sponsor_service.dart`
- Widgets : `powered_by_partner_*`
- Admin : `staff_sponsors_section`, banners soutenez / prono

**Reco :**
- ✅
- 🔄 éventuellement module Sponsors dédié plus tard

---

## Admin (shell)

**Rôle :** portail staff RBAC multi-onglets + web.

**Fichiers :**
- `lib/screens/admin/**` (shell, sidebar, controller, registry, tabs…)
- `lib/features/admin/**` (routes, rbac, theme, logger, history)
- `admin_portal/admin_web_screen.dart`
- `admin_user_firebase_actions_service.dart`

**Dépendances :** RolePermissionsService, tous domaines métier.

**Reco :**
- ✅ shell
- 🔄 compléter Feature First admin (tabs restent screens)
- ⛔ / ❌ industrialisation Esti/Tournament tabs
- ⚠️ monolithes Direct/Users/Stats

---

## TV (admin + API) — voir Streaming

Regroupé avec Streaming / DVCR TV ci-dessus.

---

## Esti / World Cup / Tournois (⛔ hors scope)

**Rôle :** événements ponctuels — **ADR-0002**.

**Fichiers :**
- `screens/esti_dvcr/**`, `screens/world_cup/**`
- `features/world_cup/tournament_prono_screen.dart`
- Services : `tournament_service`, `esti_dvcr_league_service`
- Rollouts navigation
- Admin : `tabs/esti_dvcr`, `tabs/tournament`, sections dans pronos
- Functions : `tournament_scoring.js`

**Reco :**
- ⛔ ne pas moderniser en core
- ⚠️ encore dans graphe (Home mini-card, flags)
- ❌ candidature **isolation puis suppression** = **GO produit** uniquement

---

## Core / Foundation

**Rôle :** Riverpod scope, `AppConfig`, `AppFailure`/`Result`, DI marker.

**Fichiers :** `lib/core/**`, `test/core/`, `FOUNDATION_*`

**Reco :**
- ✅
- ⚠️ `foundationReadyProvider` (tests) — garder ou différer delete
- ⚠️ GoRouter non introduit — module Navigation
- ❌ sibling `dvcr_appli_v2` = ops hors repo (GO user)

---

## Navigation / Shell app

**Fichiers :** `main.dart`, `main_navigation.dart`, `main_shell_widgets.dart`, `main_bootstrap.dart`, `app/app_router.dart`, `navigation/*_rollout.dart`

**Reco :**
- ✅ shell cœur
- ⛔ rollouts Esti/WC
- 🔄 deep-links → GoRouter futur
- ⚠️ `main_navigation` ~577 L

---

## Search / Social links / Tutorial

| Zone | Fichiers | Reco |
|------|----------|------|
| Search | `global_search_screen`, `global_search_service` | ✅ / ⚠️ priorité |
| Social links | `social_links_screen` | ✅ / ⚠️ |
| Tutorial | `tutorial_screen` (~902 L) | ✅ |
| Onboarding | `onboarding_screen` | ❌ |

---

## Functions (groupes)

| Groupe | Fichiers | Statut |
|--------|----------|--------|
| Notifs | triggers, manual, push helpers | ✅ |
| FFF / matchs | fff_sync, match_callables | ✅ |
| Prono | prono_scoring | ✅ |
| Live / TV | live_push, tv_api, youtube_sync | ✅ |
| XP / auth claims | xp_system | ✅ |
| Stats | match_stats | ✅ |
| Contenu | wix, helloasso | ✅ |
| Tournois | tournament_scoring | ⛔ |
| One-shots / scripts | import/cleanup/fake/bridge/patch | ⚠️ / ❌ |
| Deps | firebase-* ✅ ; axios/cheerio ✅ ; fast-xml-parser ❌ |

---

## Widgets transverses & Utils

Voir audit §7–8.  
**❌** `utils/roles.dart`  
**⚠️** monolithes widgets match/live  
**✅** design helpers DVCR

---

## Models (legacy)

Tous `lib/models/*` : **✅** jusqu’à migration Freezed module par module.  
**🔄** `UserModel` avec Auth.

---

## Tests

| Suite | Statut |
|-------|--------|
| Foundation / Auth / Home domain | ✅ |
| Share templates | ✅ |
| Couverture écrans legacy | ⚠️ absente |

---

## Synthèse reco globales (par priorité)

1. **R0** Fix compile Home T2 (`with` dupliqué) — ⚠️ bloquant  
2. **GO R1–R2** HomeSectionsService + close T2 placeholders/shims  
3. **GO Auth A1** shims login/register  
4. **GO** services prono orphelins + onboarding/subscription/roles  
5. **GO** packages morts (+ fast-xml-parser)  
6. Module Prono : fusion screens  
7. Splits >1000 L Match/Direct/Chat  
8. **GO produit** Esti/WC isolation  

*Proposal only — ADR-0005.*
