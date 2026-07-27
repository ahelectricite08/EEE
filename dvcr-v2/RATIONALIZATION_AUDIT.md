# DVCR — Audit de rationalisation (exhaustif)

**Date :** 2026-07-26  
**Workspace :** `C:\Users\axeld\Music\dvcr_appli`  
**Périmètre :** `lib/`, `test/`, `pubspec.yaml`, `functions/` (+ `functions/package.json`)  
**Méthode :** Glob / Grep / Read ciblés + croisement `AUDIT_CURRENT_STATE.md`, `FEATURES.md`, `*_CLEANUP_PROPOSAL.md`, `AUTH_DONE` / `HOME_DONE` / `FOUNDATION_DONE`, ADR-0002 / ADR-0005  
**Livrable :** docs only — **zéro modification de code applicatif**

---

## ADR-0005 — rappel obligatoire

Les items marqués **❌ Candidat à la suppression** (et les batches de fusion **🔄**) sont des **proposals only**.

- **Interdit** de supprimer / fusionner / déplacer du code applicatif sans **GO utilisateur explicite** (item ou batch nommé).
- Voir `dvcr-v2/ADR-0005-cleanup-requires-user-go.md` et les proposals module : `FOUNDATION_CLEANUP_PROPOSAL.md`, `AUTH_CLEANUP_PROPOSAL.md`, `HOME_CLEANUP_PROPOSAL.md`.
- Cet audit **n’exécute aucune suppression**.

### Légende statut (chaque élément listé)

| Symbole | Sens |
|---------|------|
| ✅ | À conserver |
| 🔄 | À fusionner |
| ⚠️ | À vérifier |
| ❌ | Candidat à la suppression (proposal only — ADR-0005) |

---

## 0. Synthèse chiffrée (approx.)

| Métrique | Valeur observée |
|----------|-----------------|
| Fichiers Dart `lib/` | **~404** |
| Lignes Dart `lib/` | **~121 000** |
| Fichiers Dart `test/` | **6** |
| Fichiers JS Functions (hors `node_modules`) | **~31** |
| `lib/screens/` | **~172** |
| `lib/services/` | **61** |
| `lib/features/` | **~93** |
| `lib/widgets/` | **35** |
| `lib/models/` | **11** |
| `lib/core/` | **5** |
| `lib/utils/` | **10** |
| Fichiers `lib/` **> 300 L** | **~115** (inventaire début audit ; Home T2 a depuis transformé `screens/home/*` en shims) |
| Fichiers `lib/` **> 500 L** | **~64** |
| Fichiers `lib/` **> 1000 L** | **~28** |
| Functions **> 500 L** | **6** (`wix_article_webhook`, `live_push`, `fff_sync`, `match_stats`, `prono_scoring`, `lib/push_helpers`) |
| TODO/FIXME littéraux (grep sensible à la casse) | **0** |
| Packages pubspec **0 import** détecté | **4–5** (voir §10) |
| Candidats ❌ forts (hors Esti/WC hors-scope) | **~15–25** items |
| Candidats 🔄 structurants | **~20–30** dualités |
| Items ⚠️ | nombreux (call sites dynamiques / flags / admin) |

Vue par domaine : [`RATIONALIZATION_BY_FEATURE.md`](./RATIONALIZATION_BY_FEATURE.md)  
Synthèse exécutive : [`RATIONALIZATION_SUMMARY.md`](./RATIONALIZATION_SUMMARY.md)

---

## 1. Fonctionnalités (produit × code)

Source produit : `FEATURES.md`. Disposition V2 rappelée.

| Domaine | Disposition | Statut rationalisation |
|---------|-------------|------------------------|
| Auth & compte | ✅ cœur | ✅ Feature First livré (`AUTH_DONE`) ; 🔄 façades / re-exports / `UserModel` |
| Foundation / core | ✅ | ✅ Livré ; peu à supprimer (`FOUNDATION_CLEANUP`) |
| Home / Accueil | ✅ | 🔄 **Home T2 en cours** (voir §2.1) ; data T1 ✅ |
| Matchs / calendrier / FFF | ✅ | ✅ logique ; ❌ monolithes UI à découper plus tard |
| Direct live | ✅ / ⚠️ packages | ✅ ; ⚠️ Live Activity / sticky / sons |
| DVCR TV / streaming | ✅ | ✅ ; ⚠️ `youtube_player_iframe` **non importé** |
| Stats match | ✅ | ✅ ; ⛔ migrate one-shot |
| Pronos championnat + social | ✅ | 🔄 dualité `features/prono` + `screens/prono` |
| Chat | ✅ | ✅ ; monolithe `chat_ui_parts` |
| Articles | ✅ | ✅ |
| Notifications | ✅ | ✅ |
| XP / badges / referral | ✅ | ✅ |
| Adhérents / HelloAsso | ✅ | ✅ |
| Bénévoles | ✅ | ✅ |
| Sponsors / share | ✅ | ✅ ; ⚠️ admin share templates section déjà absente (git D) |
| Admin centre | ✅ | ✅ shell ; 🔄 routing partiel `features/admin` |
| Profile / prefs / favoris | ✅ | 🔄 `profile_screen` racine + `screens/profile/` |
| Recherche / social links | ⚠️ | ✅ présents ; prioriser plus tard |
| Tutorial | ✅ | ✅ `TutorialScreen` utilisé |
| Onboarding legacy | — | ❌ `OnboardingScreen` sans call site |
| Subscription stub | — | ❌ `subscription_screen.dart` orphelin |
| Esti / World Cup / tournois | ⛔ ADR-0002 | ❌ ne pas industrialiser ; isolation / delete futur = GO produit |

---

## 2. Écrans

### 2.1 Home — dualité T2 (état observé **2026-07-26**)

**Constat :** Home T2 **amorcé / quasi branché** sur le disque, **pas encore clos** (docs `HOME_DONE` = T1 ; `HOME_CLEANUP_PROPOSAL` dit « compléter après T2 »).

| Élément | Observation | Statut |
|---------|-------------|--------|
| `lib/features/home/presentation/screens/home_screen.dart` | `ConsumerStatefulWidget` + `part` mixins | ✅ cible |
| `lib/screens/home_screen.dart` | `export 'home/home_screen.dart'` | 🔄 shim à pointer barrel feature |
| `lib/screens/home/home_screen.dart` | `export package:…/features/home/…/home_screen.dart` | 🔄 shim temporaire |
| `lib/screens/home/home_palette.dart` etc. | re-exports → `features/home/presentation/widgets/*` | 🔄 puis ❌ après migration imports externes |
| `lib/screens/home/home_feed_*.dart` (certains) | **placeholders commentaires** (« Moved to features… ») | ❌ après GO T2 + verify |
| `main.dart` / `main_navigation.dart` | import encore `screens/home_screen.dart` | ⚠️ OK via chaîne de re-exports |
| `home_screen.dart` feature | **syntaxe cassée** : double `with SingleTickerProviderStateMixin {` (l.107–109) | ⚠️ **bloquant compile** — corriger hors cet audit |
| Presentation → `features/home/data/**` | imports data depuis UI (`adapters`, datasources) | ⚠️ violation Feature First (adapter via providers) |
| `_t2_*.py`, `_t2_src_backup/` (racine repo) | outils / backup migration | ❌ candidature ops après GO T2 |
| Mini-card World Cup dans body Home | encore présente (flag rollout) | ⚠️ garder comportement ; ⛔ ne pas industrialiser (ADR-0002) |

### 2.2 Auth

| Élément | Statut |
|---------|--------|
| `features/auth/presentation/screens/{login,register}` | ✅ |
| `screens/auth/*` + `screens/login_screen.dart` / `register_screen.dart` | 🔄 re-exports → fusion imports puis ❌ shims (`AUTH_CLEANUP` batch A1) |
| `TutorialScreen` | ✅ |
| `OnboardingScreen` | ❌ suspect mort (aucun `OnboardingScreen(` hors définition) |

### 2.3 Prono

| Élément | Statut |
|---------|--------|
| `PronoRootShell` (`features/prono/...`) branché `MainNavigation` | ✅ |
| `screens/prono/prono_screen.dart` (~1918 L) + `prono_social_pages.dart` part | 🔄 encore importé par shell / social hub |
| `screens/prono/prono_shell.dart`, palette | 🔄 theme déjà en `features/prono/presentation/theme` |
| Pages feature (home/matches/progress/social/history) | ✅ partiel |

### 2.4 Autres écrans métier (conserver, découper plus tard)

| Zone | Fichiers clés | Statut |
|------|---------------|--------|
| Matchs | `matches_screen`, `matches_feed_tab` (~1793), `matches_ranking_tab`, **`match_detail_screen` (~3352)** | ✅ / ⚠️ taille |
| Live / TV | `live_screen`, `live_widgets` (~1120) | ✅ |
| Chat | `chat_screen` (~1305), **`chat_ui_parts` (~2721)** | ✅ / ⚠️ |
| Articles | `articles_screen` (~1622), list/detail widgets | ✅ |
| Calendar | `calendar_screen` + parts ; route `/calendar` | ⚠️ redondance vs onglet Matchs |
| Profile | **`profile_screen.dart` racine (~1206)** + `screens/profile/*` | 🔄 |
| Notifs centre | `notifications_center_screen` | ✅ |
| Search / social / replay / benevole / force_update / video_* | présents | ✅ / ⚠️ |
| `subscription_screen.dart` (racine `lib/`) | ❌ orphelin |
| Admin portal web | `admin_web_screen` | ✅ |

### 2.5 Admin tabs

**Registry actif** (`admin_tab_registry.dart`) : dashboard, direct, matchs, stats, articles, stades, diffusion/notifs, users, communauté, bénévoles, adhérents, pronos, xp, settings, tv, logs, staff.

| Hors registry / événementiel | Statut |
|------------------------------|--------|
| `tabs/esti_dvcr/` | ⛔ / ❌ industrialisation ; ⚠️ encore référencé via sections pronos |
| `tabs/tournament/` | ⛔ ; encore export `features/admin/presentation/admin_tabs.dart` + `esti_dvcr_admin_section` |
| `tabs/pronos/world_cup_partner_admin_section.dart`, `esti_dvcr_admin_section.dart` | ⛔ |
| Monolithes admin Direct / match_editor / stats_editor / users | ✅ / ⚠️ taille |

### 2.6 Esti / World Cup (écrans)

| Chemin | Statut |
|--------|--------|
| `screens/esti_dvcr/*` | ⛔ |
| `screens/world_cup/*` | ⛔ |
| `features/world_cup/tournament_prono_screen.dart` (~2282 L) | ⛔ |
| Rollouts `esti_dvcr_rollout.dart`, `world_cup_tab_rollout.dart` | ⛔ (garder jusqu’à GO produit isolation) |

---

## 3. Services (`lib/services/` — 61)

Pattern dominant : **static / singleton** + Firestore.

### 3.1 Cœur — conserver (moderniser module par module)

✅ Auth façade, match/live/article/notif/xp/sponsor/share/FFF/season/flags/cache/user/prefs/favorites/admin actions/seed/MOTM/rating/lineup/stats/podcast/video/youtube/helloasso/benevole/referral/vote history/app version… (liste complète dans `AUDIT_CURRENT_STATE` §4).

### 3.2 Façades Feature First

| Service | Statut |
|---------|--------|
| `auth_service.dart` | 🔄 garder façade courte durée ; amincir (`AUTH_CLEANUP`) |
| `home_banner_service.dart` | 🔄 encore admin settings ; puis ❌ |
| `home_sections_service.dart` | ❌ **aucun call site `HomeSectionsService` dans `lib/`** (seulement `_t2_src_backup`) — Accueil utilise providers ; **vérifier tests** puis GO delete |

### 3.3 Suspects morts / orphelins (classes sans référence externe)

| Service | Preuve | Statut |
|---------|--------|--------|
| `prono_onboarding_service.dart` | Classe seulement dans son fichier | ❌ |
| `prono_season_service.dart` | Idem ; collections lues ailleurs en inline ? (grep classe = 0) | ❌ |
| `prono_social_activity_service.dart` | Classe orpheline ; écriture activité via `PronoSocialService` | ❌ / ⚠️ |

### 3.4 Hors scope ADR-0002

| Service | Statut |
|---------|--------|
| `tournament_service.dart` | ⛔ (encore consommé Home mini-card, Esti, WC, admin) — ❌ core V2, pas delete impulsif |
| `esti_dvcr_league_service.dart` | ⛔ |

---

## 4. Repositories

| Repo | Emplacement | Statut |
|------|-------------|--------|
| `AuthRepository` / `AuthRepositoryImpl` | `features/auth` | ✅ |
| `HomeRepository` / `HomeRepositoryImpl` | `features/home` | ✅ ; ⚠️ **3 instances** (provider + 2 façades static) → 🔄 DI unique |
| `PronoRepository` / `FirestorePronoRepository` | `features/prono` | ✅ partiel (pas Freezed full) |
| `MatchStatsRepository` | `services/match_stats_repository.dart` | ⚠️ nom « repository » legacy hors feature |
| Reste métier | pas de ports domain | ⚠️ dette acceptée (modernisation progressive) |

---

## 5. Providers (Riverpod)

| Provider / fichier | Statut |
|--------------------|--------|
| `foundationReadyProvider` | ⚠️ / ✅ tests — `FOUNDATION_CLEANUP` |
| `auth*` providers + `authSessionProvider` | ✅ ; ⚠️ session encore peu consommée hors Auth UI |
| `homeRepositoryProvider`, layout/config/banner streams, podcast use cases, adapters providers | ✅ |
| Pas de `lib/providers/` | ✅ convention feature-local |
| Majorité app | setState / StreamBuilder / ChangeNotifier | ⚠️ migration progressive |

---

## 6. Modèles

| Modèle | Statut |
|--------|--------|
| `lib/models/*` (11) Map/fromMap | ✅ legacy jusqu’aux modules propriétaires |
| Freezed Auth `AuthUser` / `AuthSession` (+ `.freezed.dart` présents) | ✅ |
| Freezed Home `HomeLayoutHints` / `HomeSectionsConfig` | ✅ |
| Dual `AuthUser` vs `UserModel` | 🔄 différer → Profile/Users (`AUTH_CLEANUP`) |
| `prono_match_list_item.dart` | ✅ |

---

## 7. Widgets réutilisables (`lib/widgets/` — 35)

| Groupe | Statut |
|--------|--------|
| Design system léger (`dvcr_card`, `dvcr_action_button`, `section_header`, `empty_state`, `skeleton`, `reveal`, `network_banner`) | ✅ |
| Live / MOTM / rating / poll / match_card* | ✅ (couplage Home/Matchs) |
| Share / favorites / partner / donation | ✅ |
| Admin preview / badges | ✅ |
| `match_card.dart` (~2163), `live_match_quick_panel` (~2138) | ⚠️ taille — split futur |
| Widgets Auth / Prono / Home feature-local | ✅ |

Aucun widget clairement **0 référence** détecté dans cet audit (heuristique non exhaustive) → pas de ❌ massif ici.

---

## 8. Utilitaires (`lib/utils/`)

| Fichier | Statut |
|---------|--------|
| `share_helper`, `share_template_settings`, `remote_image_url`, `youtube_parser`, `match_calendar_filter`, `match_competition`, `open_prono_for_match`, `chat_reactions`, `version_compare` | ✅ utilisés |
| `roles.dart` (`isAdmin`/`isCM` string helpers) | ❌ **aucun import** ; rôles réels = `models/user_role.dart` |

---

## 9. Cloud Functions

### 9.1 Runtime (`functions/index.js` MODULES + webhooks)

| Module | Statut |
|--------|--------|
| `notification_triggers`, `youtube_sync`, `fff_sync`, `match_callables`, `prono_scoring`, `live_push`, `manual_notifications`, `xp_system`, `tv_api`, `match_stats` | ✅ |
| `wix_article_webhook`, `helloasso_webhook` | ✅ |
| `tournament_scoring.js` | ⛔ ADR-0002 — ❌ core ; garder tant que Esti/WC live |
| `notification_push.js`, `admin_app.js`, `lib/*` | ✅ helpers |

### 9.2 Scripts / one-shot (hors MODULES)

| Fichier | Statut |
|---------|--------|
| `addFakePronoData.js`, `cleanup2024.js`, `import2024.js`, `trigger_sync.js` | ⚠️ ops / ❌ si obsolètes (GO) |
| `functions/scripts/*` (bridge_home_results, migrate_*, patch-*) | ⚠️ ops |
| `functions/tools/split_index.js` | ⚠️ |

### 9.3 Dépendances `functions/package.json`

| Package | Statut |
|---------|--------|
| `firebase-admin`, `firebase-functions` | ✅ |
| `axios`, `cheerio` | ✅ (`wix_article_webhook.js`) |
| `fast-xml-parser` | ❌ **aucun `require` dans sources Functions** (seulement lock / transitive possible) — candidat retrait GO |

---

## 10. Packages `pubspec.yaml`

### 10.1 Imports détectés (fichiers `lib/` contenant `package:<name>/`)

| Package | Fichiers touchés (approx) | Statut |
|---------|---------------------------|--------|
| `google_fonts` | ~156 | ✅ |
| `cloud_firestore` | ~132 | ✅ |
| `firebase_auth` | ~53 | ✅ / ⚠️ hors datasource Auth |
| `flutter_riverpod` | ~7 | ✅ (encore rare) |
| `shared_preferences` | ~17 | ✅ |
| `cloud_functions` | ~17 | ✅ |
| `intl`, `url_launcher`, `flutter_local_notifications`, Firebase core/storage/messaging, `http`, media stack… | >0 | ✅ |
| `freezed_annotation` | 4 | ✅ |
| `json_annotation` | **0** | ⚠️ / ❌ si jamais de `.g.dart` JSON — Freezed actuel sans json |

### 10.2 Heuristique « 0 import » → candidats inutilisés

| Package | Statut |
|---------|--------|
| `lottie` | ❌ 0 import |
| `youtube_player_iframe` | ❌ 0 import (lecteurs = webview / chewie / explode) |
| `flutter_markdown` | ❌ 0 import (`flutter_html` utilisé) |
| `cupertino_icons` | ⚠️ 0 import Dart (souvent asset pubspec iOS — vérifier avant delete) |
| `json_annotation` | ⚠️ 0 import (dev codegen prep) |

**Ne pas big-bang clean du pubspec** (`PACKAGE_POLICY` / Foundation cleanup).

---

## 11. Sections transverses

### 11.1 Doublons

| Doublon | Statut |
|---------|--------|
| Auth UI shims vs feature | 🔄 |
| AuthService vs AuthRepository / error mapper | 🔄 |
| AuthUser vs UserModel | 🔄 |
| Home screens shims/placeholders vs `features/home` | 🔄 / ❌ placeholders |
| HomeSectionsService vs providers | ❌ service si confirmé |
| Double `HomeRepositoryImpl` façades | 🔄 |
| Prono shell feature + `prono_screen` monolithe | 🔄 |
| Prono theme tokens vs `screens/prono/prono_palette` | 🔄 |
| Profile hub dual | 🔄 |
| Admin `features/admin` routing + `screens/admin` | 🔄 partiel |
| Esti admin tab + section dans Pronos | ⛔ / 🔄 isolation |

### 11.2 Anciennes implémentations (`screens/*` vs `features/*`)

| Feature | État |
|---------|------|
| Auth | shims only ✅ |
| Home | **T2 en cours** — UI dans features ; screens = re-export / placeholders |
| Prono | hybride (shell feature + gros legacy screens) |
| Admin | routing/theme/rbac partiel feature ; UI tabs legacy |
| World Cup | volontairement `features/world_cup` mais ⛔ hors core |

### 11.3 Code mort probable

| Item | Statut |
|------|--------|
| `OnboardingScreen` | ❌ |
| `subscription_screen.dart` | ❌ |
| `utils/roles.dart` | ❌ |
| `HomeSectionsService` (call sites app) | ❌ |
| `PronoOnboardingService`, `PronoSeasonService`, `PronoSocialActivityService` | ❌ |
| Placeholders `screens/home/home_feed_*.dart` | ❌ après GO |
| Scripts `_t2_*` + `_t2_src_backup` | ❌ après GO T2 |
| Packages lottie / youtube_player_iframe / flutter_markdown / fast-xml-parser | ❌ |
| Admin tabs Esti/Tournament hors registry | ⛔ / ⚠️ |

### 11.4 Features abandonnées (Esti / WC — ADR-0002)

Ne **pas** créer de modules cœur. Surfaces encore dans le graphe d’imports (Home mini-card, rollouts, Functions `tournament_scoring`, admin sections).  
**Rationalisation :** isolation progressive puis delete **uniquement** sur GO produit — pas sur GO architecture seul.

### 11.5 Fichiers trop volumineux (top)

**> 1000 L (échantillon prioritaire) :**

| Lignes | Fichier | Statut |
|--------|---------|--------|
| ~3352 | `screens/matches/match_detail_screen.dart` | ⚠️ split module Matchs |
| ~3167 | `admin/.../direct_tab.dart` | ⚠️ |
| ~2721 | `chat/chat_ui_parts.dart` | ⚠️ |
| ~2343 | `match_editor.dart` | ⚠️ |
| ~2282 | `features/world_cup/tournament_prono_screen.dart` | ⛔ |
| ~2163 | `widgets/match_card.dart` | ⚠️ |
| ~2152 | `match_stats_editor.dart` | ⚠️ |
| ~2138 | `live_match_quick_panel.dart` | ⚠️ |
| ~1918 / ~1885 | `prono_screen` / `prono_social_pages` | 🔄 |
| … | users_tab, articles_screen, profile*, etc. | ⚠️ |

Home : parties feature désormais **≤ ~300 L** (objectif T2) — ✅ directionnellement.

### 11.6 Dépendances circulaires / couches

| Pattern | Statut |
|---------|--------|
| `features/home` UI → `screens/articles|chat|match_detail|profile|…` | ⚠️ couplage présentation cross-feature |
| `features/home` UI → `features/home/data/**` (adapters/datasources) | ⚠️ inversion de dépendance |
| `features/prono` shell → `screens/prono/prono_screen` | 🔄 |
| `screens/*` → `features/*/theme|tokens` | ⚠️ OK temporaire |
| Widgets live → `screens/home/home_palette` (re-export) | 🔄 migrer vers `features/home` barrel |
| Pas de cycle package Dart formel détecté | ✅ ; dette = **couches** |

### 11.7 Imports inutiles

- Pas de `dart fix` exécuté (interdit).  
- Échantillonnage : Home T2 placeholders ; packages 0-import (§10) ; `utils/roles.dart` non importé.  
- ⚠️ analyzer local recommandé **après** fix syntaxe Home.

### 11.8 TODO / FIXME

- Grep **case-sensitive** `TODO|FIXME|HACK|XXX` dans `lib/` : **0 match**.  
- (Heuristique PS case-insensitive faussée par `toDouble` contenant `todo`.)

### 11.9 Incohérences d’architecture (Foundation / Auth / Home vs legacy)

| Incohérence | Statut |
|-------------|--------|
| Riverpod seulement Core/Auth/Home ; reste ChangeNotifier/static | ⚠️ attendu ADR-0004 |
| `FirebaseAuth.instance` encore **~50 fichiers** | 🔄 consumers modules futurs |
| Freezed Auth/Home OK ; `AUDIT_CURRENT_STATE` partiellement **obsolète** (disait Freezed absent / Auth non clos) | ⚠️ doc drift |
| `HOME_DONE` = T1 alors que disque = T2 partiel + syntaxe cassée | ⚠️ |
| GoRouter absent | ⚠️ différé Navigation |
| Hardcode club (`club_branding`, Sedan reset stats…) | ⚠️ multi-tenant futur |
| Tests : 6 fichiers seulement (core, auth, home, share, widget) | ⚠️ couverture maigre |
| Prono « feature » sans domain/data complets | ⚠️ hybride |

---

## 12. Tests

| Fichier | Statut |
|---------|--------|
| `test/core/foundation_core_test.dart` | ✅ |
| `test/features/auth/*` | ✅ |
| `test/features/home/home_domain_test.dart` | ✅ |
| `test/share_template_settings_test.dart` | ✅ |
| `test/widget_test.dart` | ⚠️ stub souvent |

Pas de tests écrans Matchs/Chat/Admin/Prono legacy.

---

## 13. Outils hors `lib/` liés à la rationalisation (repo root)

| Item | Statut |
|------|--------|
| `_t2_migrate_home.py`, `_t2_fix_home.py`, `_t2_linecount.py`, `_t2_robust.py` | ❌ après GO T2 |
| `_t2_src_backup/*.dart` | ❌ après GO T2 |
| Docs `dvcr-v2/*` | ✅ hors code app |

---

## 14. Batches GO suggérés (proposals only)

| Batch | Contenu | Prérequis |
|-------|---------|-----------|
| **R0** | Fix compile Home (`with` dupliqué) | Dev — hors cleanup ADR-0005 strict si bug bloquant |
| **R1** | Confirmer + delete `HomeSectionsService` si orphelin | GO + analyze |
| **R2** | Home T2 close : supprimer placeholders `screens/home/*`, migrer imports palette, update `HOME_DONE` / cleanup proposal | GO T2 |
| **R3** | Auth A1 : imports → barrel ; delete shims login/register | `AUTH_CLEANUP` GO |
| **R4** | Services prono orphelins (3 fichiers) | GO + verify SharedPreferences keys |
| **R5** | `OnboardingScreen`, `subscription_screen`, `utils/roles.dart` | GO |
| **R6** | Packages 0-import (+ `fast-xml-parser`) | GO + smoke media/articles |
| **R7** | Isolation Esti/WC (flags off → delete surfaces) | **GO produit** ADR-0002 |
| **R8** | Prono fusion screens → features | module Prono |
| **R9** | Split monolithes >1000 L (Match detail, Direct, Chat, …) | modules dédiés |

---

## 15. Confirmation

- Rapports créés uniquement sous `dvcr-v2/` :  
  - `RATIONALIZATION_AUDIT.md` (ce fichier)  
  - `RATIONALIZATION_BY_FEATURE.md`  
  - `RATIONALIZATION_SUMMARY.md`  
- **Aucune** modification / suppression / rename de code applicatif dans le cadre de cet audit.  
- Candidats ❌ = **proposals** (ADR-0005).

---

*Fin — Audit de rationalisation DVCR.*
