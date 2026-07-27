# Point d’état — Administration DVCR (app + web)

**Date :** 2026-07-26  
**Périmètre :** monolithe Flutter `dvcr_appli` (code vivant) + hosting Firebase `drapeau-vert-app.web.app`  
**Méthode :** lecture code / docs ADR & FEATURES ; probe HTTP public (pas de login). **Aucune modification applicative** dans ce chantier.  
**Références :** `docs/admin_access.md`, `FEATURES.md` §20–21, ADR-0002, ADR-0005, `modules/ESTI_WC_REMOVAL_DONE.md`

---

## 1. Accès (app / web / URL)

### Deux portes, un seul panel

| Canal | Entrée | Comportement |
|-------|--------|--------------|
| **Web** | `https://drapeau-vert-app.web.app/` | `main_bootstrap.dart` : si `kIsWeb` → `home: AdminWebScreen` — **l’admin est l’écran d’accueil** du site Flutter Web. |
| **App mobile** | Profil → carte « Admin » | `Navigator.push` → `AdminWebScreen` (même widget), toolbar `embeddedFromApp` (retour profil). |
| **Route nommée** | `/admin` | `lib/app/app_router.dart` → `AdminWebScreen` (Navigator classique, **pas de GoRouter**). |

Chaîne UI : `AdminWebScreen` → gate auth/RBAC → `AdminPanel` (= `AdminShell`) → sidebar / tabs via `adminTabDefs`.

### Deep-links web

- Canonique documenté : `#/admin/<segment>` (ex. `/#/admin/direct`).
- Parse aussi path `/admin/<segment>` (`AdminRoutes.tabIndexFromLocation`).
- Sync URL au changement d’onglet : `history.replaceState` (`admin_browser_history_web.dart`).
- Deep-link **appliqué seulement si** l’index est dans `allowedIndices` (permission).

Aliases historiques encore mappés dans `AdminRoutes.segmentToTab` :

| Segment | Cible |
|---------|--------|
| `rappel-match` | Diffusion → sous-onglet rappel (`matchReminder`) |
| `chat` | Communauté |
| `equipes-stades` | Stades |
| `prono` / `jeux` | Pronos |
| `tv` / `android-tv` | TV |
| `permissions` / `badges` | Staff |
| `esti-*` / `cdm` / `tournament` (URL texte) | **retirés** (ADR-0002 / removal DONE) |

Indices numériques legacy `AdminTabIndex.estiDvcr` / `tournament` / `badges` / `matchReminder` : **conservés** pour stabilité ; soft-redirect vers Pronos / Staff / Diffusion.

### Hosting / build

`firebase.json` :

- `hosting.public` = `build/web`
- rewrite `**` → `/index.html` (SPA Flutter)
- redirect 301 `/admin.html` → `/`
- projet Firebase : `drapeau-vert-app` (aligné target `drapeau-vert-app.web.app`)

### Observation URL publique (sans login)

- HTTP **200**, shell HTML Flutter (`<title>dvcr_appli</title>`, `base href="/"`, meta générique « A new Flutter project »).
- `/admin/dashboard` et `/#/admin/dashboard` renvoient le **même** `index.html` (rewrite SPA).
- Surface publique visible : écran de login « **DVCR Administration** » (email / mot de passe) — pas de contenu staff sans auth. (Browser MCP indisponible ici ; constat via fetch HTTP + code `_LoginGate`.)

---

## 2. Auth & permissions

### Gate d’entrée

`AdminWebScreen` :

1. Pas de session Firebase → `_LoginGate` (email/password).
2. Session OK → `RolePermissionsService.hasPermission(..., admin.access, config)`.
3. Si OK → callable `refreshDvcrAuthClaims` + `getIdToken(true)` (claim `dvcr_admin` pour règles Firestore).
4. Puis `AdminPanel` / `AdminShell`.

### RBAC

- Source : `RolePermissionsService` + doc Firestore `config/role_permissions` (merge soft des defaults).
- Helpers domaine : `lib/features/admin/domain/admin_rbac.dart` (plein admin / UI access / editorial / match-ops).
- Filtrage onglets : `allowedTabIndices` + `adminTabDefs.permission`.
- Actions sensibles (`AdminAction`) : promotion staff, delete Auth, XP manuel, matrice RBAC, pilot live, notifs bénévoles — gated dans `AdminController.canAction`.
- **Statisticien** : `admin.direct` en **lecture seule** (`isDirectReadOnly`) si pas admin/CM.

Defaults client (surchargeables) :

| Rôle | Accès admin typique |
|------|---------------------|
| `admin` | Toutes permissions `admin.*` |
| `community_manager` | access, dashboard, direct, matches, community, pronos |
| `statisticien` | access, stats, direct (RO) |
| `editor` | access, articles |
| supporter / team_dvcr | pas d’`admin.access` |

### Vigilance entrée mobile

Sur **Profil**, le raccourci Admin n’est affiché que pour `admin` / `communityManager` / `editor` — **pas** pour `statisticien`, alors que le web login + `admin.access` leur ouvre le panel. Accès stats mobile possible via route `/admin` ou bookmark web, pas via la carte Profil.

---

## 3. Cartographie des modules / onglets

**Source de vérité UI :** `lib/screens/admin/admin_tab_registry.dart` → `adminTabDefs` (17 onglets vivants).

Légende : ✅ vivant (registry + builder) · ⚠️ orphelin / alias / dette · ❌ legacy retiré

| Onglet (label) | Index | Permission | Statut | Notes |
|----------------|-------|------------|--------|-------|
| Pilotage | 0 | `admin.dashboard` | ✅ | Dashboard KPIs / health |
| Direct | 1 | `admin.direct` | ✅ | Match-day ; fichier **>3k L** |
| Actus | 2 | `admin.articles` | ✅ | |
| Matchs | 3 | `admin.matches` | ✅ | + `match_editor` >2k L |
| Statistiques match | 4 | `admin.stats` | ✅ | workbench + callables stats |
| Notifications (Diffusion) | 5 | `admin.notifs` | ✅ | `DiffusionTab` = push + rappel ; label sidebar « Notifications » |
| Membres | 6 | `admin.users` | ✅ | delete Auth via CF |
| Chat & modération | 7 | `admin.community` | ✅ | |
| Équipes & stades | 8 | `admin.stades` | ✅ | |
| XP & Niveaux | 10 | `admin.xp` | ✅ | |
| Réglages | 11 | `admin.settings` | ✅ | FFF, lifecycle, version, bannières… |
| Journal | 12 | `admin.logs` | ✅ | audit |
| Android TV | 15 | `admin.tv` | ✅ | |
| Bénévoles | 16 | `admin.benevoles` | ✅ | notifs sous-perm `admin.benevoles.notifs` |
| Adhérents | 17 | `admin.adherents` | ✅ | HelloAsso ; admin-only |
| Pronos & jeux | 18 | `admin.pronos` | ✅ | Championnat / Duels / Visibilité — **sans** Esti/CdM |
| Staff & permissions | 20 | `admin.staff` | ✅ | Permissions / Badges / Sponsors |
| Rappel match (index 14) | — | via notifs | ⚠️ | Pas d’entrée sidebar ; deep-link `rappel-match` → sous-tab Diffusion |
| Badges (index 9) | — | `admin.badges` ⚠️ | ⚠️ | Permission encore listée ; pas d’onglet dédié — redirect Staff |
| Esti / Tournament (19 / 13) | — | — | ❌→⚠️ | UI/tabs **supprimés** ; indices + soft-redirect Pronos seulement |
| `NotifsTab` standalone | — | — | ⚠️ | Encore fichier + export barrel `features/admin` ; **consommé** via `DiffusionTab`, pas registry direct |
| `tabs/esti_dvcr/`, `tabs/tournament/`, WC partner | — | — | ❌ | Absents du disque (removal DONE) |

Univers sidebar : Pilotage → Match Day → Contenu & diffusion → Communauté → Jeux → Système.

---

## 4. Architecture & dette

### Feature First vs monolithe

| Zone | État |
|------|------|
| `lib/screens/admin/**` | **Monolithe dominant** (~81 fichiers Dart) — shell, tabs, widgets, setState |
| `lib/features/admin/**` | **Façade partielle** (8 fichiers) : routes, browser history, theme, RBAC, audit logger, barrel d’exports vers `screens/` |
| Pattern cible V2 | Admin = **compositeur** des features métier (ADR / MIGRATION_PLAN) — **pas encore** atteint |

Verdict : **pas Feature First**. Migration progressive amorcée (routing + RBAC domain) ; UI et logique métier encore dans `screens/admin/`.

### Fichiers volumineux (>500 L) — top dette

| Lignes (approx.) | Fichier |
|------------------|---------|
| ~3167 | `tabs/direct/direct_tab.dart` |
| ~2343 | `tabs/matchs/match_editor.dart` |
| ~2152 | `tabs/stats/match_stats_editor.dart` |
| ~1621 | `tabs/users/users_tab.dart` |
| ~1403 | `tabs/notifs/notifs_tab.dart` |
| ~1376 | `widgets/motm_vote_admin_panel.dart` |
| ~1365 | `tabs/stats/stats_tab.dart` |
| +12 autres | community, xp, benevoles, settings, shell, etc. |

### Dette technique (observée)

- **Maps / Firestore bruts** + `setState` massifs dans les gros tabs (peu d’entities / usecases).
- **Services static** transverses (`RolePermissionsService`, `UserService`, `AppSettingsService`, SeedService, match stats sheet…).
- **Doublons / façades** : `admin_panel.dart` shim, barrel `admin_tabs.dart` incomplet vs registry, permission `admin.badges` sans onglet.
- **Copy legacy CDM** encore dans Settings « PROPULSÉ PAR (PRONO & CDM) » + mention Coupe du monde (produit WC retiré — dette libellés).
- **Conditionnels web** : `home_banner_section` stub/web, `stats_export` stub/web.
- **Pas de GoRouter** : MaterialApp + hash history manuelle — fragile pour deep-links avancés / guards déclaratifs.
- **Profil vs web** : asymétrie statisticien (cf. §2).

### Esti / World Cup (état observé)

Aligné **ADR-0002** + `ESTI_WC_REMOVAL_DONE` / Review **PASS** :

- Dossiers admin Esti / tournament / sections WC **absents**.
- Alias URL esti/cdm **retirés** ; indices soft-redirect seulement.
- Functions `tournament_scoring` hors export client ; **undeploy prod** et purge Firestore = candidats ADR-0005 (ops / GO data).
- Mentions textuelles CDM résiduelles dans Settings = cleanup copy, pas module.

---

## 5. Dépendances Cloud Functions

Callables / effets backend **touchés depuis l’admin** (direct ou via services admin) :

| Callable / mécanisme | Usage admin |
|----------------------|-------------|
| `refreshDvcrAuthClaims` | Gate web |
| `adminDeleteAuthUser` | Membres |
| `getMatchReminderCandidates` / `sendMatchReminderManual` | Diffusion rappel |
| `notifications_queue` (écriture Firestore) | Push manuelles (worker Functions) |
| `testFffSeasonConfig` / `syncFffDataManual` | Réglages FFF |
| `archiveClubRankingSeason` | Season lifecycle |
| `resetPronoSeason` | Pronos |
| `adminRecomputeLeaguePowerRankings` | Maintenance |
| `setTvStreamConfig` | TV |
| `syncMatchStatsPreviewManual`, `finalizeMatchStats`, `reopenMatchStats`, `setMatchStatsPublicationState`, `migrateMatchStatsFromMatches`, `resetSedanSeasonStats` | Stats (via `MatchStatsSheetService`) |
| `syncYoutubeVideosManual` | Sync YT (settings / TV context) |
| Seed / live helpers (`notifyHalftime`, etc.) | Direct |

Claims : sync `dvcr_admin` (écriture users + refresh client) — critique pour règles Firestore.

---

## 6. Risques (web vs mobile)

| Risque | Impact |
|--------|--------|
| **Même codebase, UX différente** | Web = fullscreen + sidebar + logout ; mobile = push + bottom tabs étroits — Direct/Stats/Editors peu adaptés au téléphone |
| **Upload / file pickers / `dart:html`** | Branches stub/web ; régressions silencieuses si un chemin mobile manque |
| **Deep-links hash only fiables sur web** | App ignore deep-link URL au démarrage shell (`kIsWeb` guard) |
| **Actions destructives** (reset saison, delete user, finalize stats) | Accessibles web + app si permission — UX confirmation inégale selon tab |
| **Statisticien** | Web OK ; raccourci Profil manquant |
| **Functions legacy WC/Esti encore en prod** | Faible (plus de client) mais surface ops |
| **Gros widgets** | Perf web (compilation / tree) + maintenance ; risque de freeze UI match-day |
| **Meta / SEO hosting** | Title générique `dvcr_appli` — mineur (outil staff) |

Ce qui **marche bien** :

- Un seul `AdminShell` partagé app/web.
- Registry unique + permissions par onglet + univers sidebar clairs.
- Gate claims + login web dédié.
- Deep-links bookmarkables pour le staff.
- Removal Esti/CdM côté UI admin déjà faite (alignement ADR-0002).

---

## 7. Recommandations (sans code)

### Priorité modernisation Admin : **Moyenne** (pas Forte immédiate)

**Pourquoi Moyenne :**

- Auth + Home déjà en chantier Feature First ; Matches / Live / Stats métier devraient précéder un découpage Admin (l’admin **compose** ces domaines — MIGRATION_PLAN phase 13–14+).
- Admin est **critique ops** mais stable en production partagée ; big-bang shell = risque match-day élevé.
- Priorité **Forte** seulement sur des **slices** : Direct / Match editor / Stats editor (fichiers >2k L), ou bugs sécurité RBAC — pas sur « tout Admin Feature First » d’un coup.

### Par quoi commencer (ordre suggéré)

1. **Cleanup docs/copy** (ADR-0005) : libellés CDM Settings ; audits rationalization obsolètes ; undeploy Functions WC/Esti (ops).
2. **Aligner entrée mobile** : raccourci Profil basé sur `admin.access` (incl. statisticien) — petit fix ciblé.
3. **Découper Verticalement par domaine déjà modernisé** : quand Matches/Live/Stats auront des APIs feature, extraire les tabs correspondants hors monolithe (compositeur Admin).
4. **Router déclaratif** (GoRouter) pour web admin + guards — après ou avec Auth V2 routing.
5. **Ne pas** créer de modules permanents Esti/CdM (ADR-0002).

### Quand moderniser le shell global ?

Après (ou en parallèle contrôlée de) Matches + Live + Stats lecture/écriture stables — phase **Admin shell + RBAC** du plan de migration (~module 13), puis onglets écriture un par un.

---

## 8. Lien ADR-0002 / ADR-0005

| ADR | Application Admin |
|-----|-------------------|
| **ADR-0002** | Pas de modules admin permanents pour événements. Esti/CdM UI admin **retirés** ; seuls indices soft-redirect + data/Functions legacy. Pronos admin = cœur championnat uniquement. |
| **ADR-0005** | Toute suppression restante (Functions déployées, collections `tournaments` / `esti_dvcr_leagues`, permission `admin.badges`, copy CDM, barrel orphelin) = **Cleanup Proposal + GO utilisateur** — pas de delete impulsif dans un chantier modernisation. |

---

## Synthèse exécutive

1. **Web = portail admin** (`drapeau-vert-app.web.app` → `AdminWebScreen`) ; **app = même panel** via Profil / route `/admin`.
2. **17 onglets vivants** dans `adminTabDefs` ; Esti/CdM **absents** (redirect soft indices) ; Diffusion unifie notifs + rappel.
3. Architecture encore **`lib/screens/admin/` monolithique** ; `features/admin` = façade routing/RBAC seulement.
4. Dette majeure = **fichiers 1–3k L** (Direct, Match editor, Stats) + Maps/setState + asymétrie statisticien Profil.
5. Modernisation Admin recommandée en priorité **Moyenne** : après domaines métier ; commencer par slices critiques / cleanup ADR-0005, pas un rewrite shell global.

---

*Document de statut — docs only. Prochaine étape produit : GO module Admin ou cleanup items listés §7–8.*
