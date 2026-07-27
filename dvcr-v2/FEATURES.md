# DVCR — Inventaire fonctionnel complet

**Source de vérité :** comportement de l’app Flutter + Firebase **en production** (`dvcr_appli`).  
**Format :** chaque item = capacité observée + **disposition architecture cible (« V2 »)**.  
**Date :** 2026-07-26 (légende alignée ADR-0004)  
**Périmètre :** `SCOPE_V2.md`, `STRATEGY.md`, `ADR-0002`, `ADR-0004`, `MODERNIZATION_PLAN.md`.

> **ADR-0004 :** « V2 » = architecture cible **in-place** (moderniser l’existant), pas un second repo.  
> Les items ✅ = comportement à **conserver** pendant le refactor. Ne pas réécrire from scratch.

### Légende disposition architecture cible

| Marque | Signification |
|--------|----------------|
| ✅ | **Cœur** — comportement à conserver / moderniser dans la roadmap core |
| ⛔ | **Hors core** — ne pas industrialiser ; extension éventuelle seulement (ADR-0002) |
| ⚠️ | **À revoir** — trancher en conception du module (défaut : ne pas étendre si non cœur) |

> Inventaire du produit actuel. La marque guide la **modernisation**, pas un portage vers une app neuve.

---

## 1. Authentification & compte

- ✅ **Inscription email / mot de passe** — création compte Firebase Auth + doc `users/{uid}` (rôle supporter par défaut).
- ✅ **Connexion** — écran login ; bascule vers l’app après `authStateChanges`.
- ✅ **Mode invité** — accès limité (Actus ouvert) sans compte ; invitation à s’inscrire.
- ✅ **Déconnexion** — via profil / AuthService.
- ✅ **Tutorial / onboarding** — parcours post-inscription si non complété (`TutorialScreen` / onboarding).
- ✅ **Profil utilisateur** — hub profil (compte, préférences, accès staff si éligible).
- ✅ **Profil public** — consultation profil d’un autre membre.
- ✅ **Compte / données personnelles** — édition infos profil (nom, affichage…).
- ✅ **Suppression de compte (RGPD)** — flux `AccountDeletionService`.
- ✅ **Favoris** — sous-collection `users/{uid}/favorites`.
- ✅ **Préférences utilisateur** — notifs, UI (`UserPreferencesService`).
- ⚠️ **Hero profil / fond** — index de fond configurable (`profileHeroBackgroundIndex` / config).
- ✅ **Force update / update optionnelle** — politique version (`AppVersionPolicyService`, `ForceUpdateScreen`).
- ✅ **Parrainage** — codes referral (`ReferralService` + Functions XP).

---

## 2. Navigation & shell applicatif

- ✅ **Barre d’onglets principale** — Accueil, DVCR TV, Calendrier, Actus, Communauté, Pronos (selon flags / auth) — **sans** onglets événementiels.
- ⛔ **Navigators imbriqués** (pattern V1) — push profil, recherche, détails via `Navigator` — **non reproduit** ; GoRouter unique en V2.
- ✅ **Feature flags runtime** — `app_config/feature_flags` + rollouts **cœur** (chat, prono hub…).
- ⛔ **Rollouts World Cup & Esti** — flags V1 événementiels — hors core (ADR-0002).
- ✅ **Deep-links notifications** — ouverture onglet / écran (V2 = GoRouter).
- ⚠️ **Recherche globale** — `GlobalSearchService` / écran search (matchs, actus, etc.).
- ⚠️ **Liens sociaux** — écran / section liens réseaux.
- ✅ **Season lifecycle overlay** — messages hors-saison / entre saisons (`SeasonLifecycleService`).

---

## 3. Accueil (Home feed)

- ✅ **Hero live / émission / bannière** — priorité match en direct, émission, sinon bannière configurée.
- ✅ **Slot interaction live** — actions liées au match (selon état).
- ✅ **Sondage émission** — vote pendant une émission (`EmissionPollService`).
- ✅ **Cartes MOTM / note de match** — vote homme du match et notation post/live.
- ✅ **Sections média** — blocs configurables (`HomeSectionsService`).
- ✅ **Fil Actus sur home** — aperçu articles + filtre catégories.
- ✅ **Fil résultats** — résultats récents / saison.
- ✅ **Bannière « Soutenez DVCR » / don** — encarts donation configurables (copy tenant).
- ✅ **Encart partenaire / powered-by** — partenaire affiché (config `powered_by_partner`).
- ✅ **Upload / config bannière home (admin)** — image Storage `home_banner/banner.jpg`.

---

## 4. Matchs & calendrier

- ✅ **Onglet Calendrier** — à venir / résultats / classement (`MatchesScreen`).
- ✅ **Détail match** — fiche complète (scores, infos, replay, stats si publiées).
- ✅ **Classement de ligue** — lecture `ranking` (FFF).
- ✅ **Filtres calendrier** — helpers `match_calendar_filter`.
- ⚠️ **Écran calendrier dédié** — route `/calendar` (vue alternative V1) — fusionner avec onglet si redondant.
- ✅ **Sync FFF automatique** — cron Functions toutes les ~6 h.
- ✅ **Sync FFF à l’ouverture calendrier** — callable authentifiée + throttle.
- ✅ **Sync FFF manuelle (admin)** — déclenchement staff + test config saison.
- ✅ **Archive classement saison** — `ranking_archive` + callable archive.
- ✅ **Matchs manuels / early publish** — flags `manual`, `earlyPublish` côté admin éditeur.
- ✅ **Replay vidéo lié** — `replayVideoId` sur match.
- ✅ **Forme / rang équipes** — champs enrichis FFF (`form`, `rank`).
- ✅ **Image stade sur carte** — `stadiumImageUrl` / équipes.

---

## 5. Direct live (match-day)

### Côté supporters

- ✅ **Suivi score en live sur Accueil** — `LiveStateService` + widgets home.
- ⚠️ **Live Activity iOS** — score sur écran verrouillé (`live_activities`, extension iOS).
- ⚠️ **Sticky notification score Android** — fallback score persistant.
- ⚠️ **Sons d’événements live** — buts / cartons (`LiveEventSoundService`).
- ✅ **Salon chat live** — salon temporaire lié au direct (`chat_salons` live_*).
- ✅ **Vote Homme du match** — sous-collection `motmVotes` + compteurs.
- ✅ **Note du match (1–10)** — `matchRatings` + miroir sur fiche match.
- ✅ **Fin de match** — copie score / événements vers `matches` (règles fin de live).

### Côté staff (Admin Direct)

- ✅ **Démarrer / arrêter un direct** — sélection match (`LiveStartService`, `SeedService` → `live/current`).
- ✅ **Pilotage chronomètre / minute** — phase match (`LiveMatchPhase`).
- ✅ **Saisie score & événements** — buts, cartons, mi-temps, fin (`LiveMatchQuickPanel`).
- ✅ **Affichage stats sur carte** — toggle publication / preview.
- ✅ **Compositions** — lineups home/away + notif compositions (callable).
- ✅ **Salon live admin** — panneau salon (`direct_live_salon_panel`).
- ✅ **Lecture seule Direct pour statisticien** — UI bloquée, pas de pilotage.
- ✅ **Récap audience fin de direct** — `live_stats_sessions` (admin).
- ✅ **Présence viewers** — `live_presence` (Functions / TV).

---

## 6. Streaming & DVCR TV

- ✅ **Onglet DVCR TV** — playlists / replays YouTube (`LiveScreen`).
- ✅ **Sync YouTube planifiée** — playlist → collection `videos`.
- ✅ **Sync YouTube manuelle (admin)** — callable admin.
- ✅ **Vidéo mise en avant** — `VideoFeaturedService` / config.
- ✅ **Lecteurs vidéo** — YouTube iframe, webview, lecteurs natifs / chewie selon écrans (packages via `PACKAGE_POLICY`).
- ✅ **Écran replay** — navigation replays.
- ⚠️ **Podcast / audio** — `PodcastController` (lecture audio service).
- ✅ **Admin Android TV** — onglet TV (`tv` / `config` stream, next live).
- ✅ **API TV publique** — `tvApi` catalogue / live pour box.
- ✅ **Heartbeat TV** — `tvLiveHeartbeat` présence.
- ✅ **Config stream TV (admin callable)** — `setTvStreamConfig`.

---

## 7. Statistiques de match

- ✅ **Fiche stats dédiée** — collection `match_stats` (workbench).
- ✅ **Saisie faits de jeu / stats chiffrées** — rôles statisticien / CM / admin.
- ✅ **Preview automatique / manuelle** — merge preview vers `matches` (+ live) sans finaliser.
- ✅ **Publication / finalisation** — `finalizeMatchStats` ; peut passer match en `finished`.
- ✅ **Réouverture stats** — `reopenMatchStats`.
- ✅ **Affichage public stats** — `showStats` / `statsState` sur carte match.
- ⛔ **Migration legacy** — `migrateMatchStatsFromMatches` — outil one-shot V1, pas un module V2.
- ⚠️ **Reset stats saison** — callable admin destructif (V1 « Sedan ») — généraliser tenant ou garder ops manuelle documentée.
- ✅ **Workflow documenté** — `docs/match_stats_workflow.md` (réf. ops).
- ✅ **Historique des votes** — MOTM / sondages archivés (`vote_history`, UI admin).

---

## 8. Score, chronomètre, joueurs, overlays

- ✅ **Score live & score final** — champs multi-alias synchronisés.
- ✅ **Chronomètre / phases** — kickoff, mi-temps, fin, minute affichée.
- ✅ **Cartons jaune / rouge** — compteurs home/away.
- ✅ **Événements timeline** — liste `events` sur live / match / sheet.
- ✅ **Compositions (joueurs)** — `lineupHome` / `lineupAway`, affichage carte optionnel.
- ✅ **Homme du match + sponsor partenaire** — nom joueur, partenaire, logo.
- ⚠️ **Overlay / bannières live** — formats bannière (`live_banner_format`) pour diffusion visuelle.
- ✅ **Encarts gamifiés / sponsors sur surfaces prono & home** — partenaires, powered-by.

> Note V1 : pas de moteur overlay broadcast dédié type OBS plugin séparé — l’« overlay » correspond aux couches UI live / bannières / TV config.

---

## 9. Pronostics (championnat)

- ✅ **Hub Pronos (4 onglets)** — Accueil hub, Matchs à pronostiquer, Progression saison, Social (`PronoRootShell`).
- ✅ **Saisie prono score** — feuille de pronostic avant coup d’envoi.
- ✅ **Points auto** — 3 exact / 1 bon résultat / 0 sinon à la fin du match (Function).
- ✅ **Classement global** — `prono_leaderboard` (points, streaks…).
- ✅ **Stats communautaires 1-N-2** — barres `match_prono_stats`.
- ✅ **Saison prono** — `prono_seasons/current`, bootstrap, fenêtres.
- ✅ **Progression / division** — `user_season_stats`.
- ✅ **Onboarding équipe favorite** — `PronoOnboardingService`.
- ✅ **Historique pronos récents** — pages history feature.
- ✅ **Bannières prono** — config admin `prono_banners`.
- ✅ **Reset saison prono (admin)** — archive + wipe (callable).
- ✅ **Motivation classement** — pushes hebdo rangs bas.
- ✅ **Visibilité / feature flag hub** — `show_prono_championship_hub`.
- ✅ **Thème prono dédié** — tokens / scope thème (tenant-aware).

---

## 10. Pronos sociaux (amis, duels, ligues)

- ✅ **Amis** — demandes `friend_requests`, liste amis sur profil social.
- ✅ **Duels 1v1** — création, picks, résolution auto (points puis delta), XP duel.
- ✅ **Notifications duels** — créé / résolu (triggers FCM).
- ✅ **Ligues privées** — créer / rejoindre par code, membres, classements.
- ✅ **Activité sociale** — feed `prono_social_activity`.
- ✅ **Leaderboard social / classements ligue** — UI social pages + power rankings (admin callable).
- ✅ **Config sociale admin** — `app_config/prono_social`.
- ✅ **Spec écrite** — `docs/PRONO_LIGUES_DUELS_SPEC.md` (réf. comportement).

---

## 11. Tournois / Esti’DVCR / Coupe du monde — ⛔ HORS SCOPE V2 CORE

> Section entière **exclue** du core V2. Extension indépendante uniquement si besoin produit futur (ADR-0002).  
> Ne pas créer de modules / routes / onglets admin permanents pour ces surfaces.
>
> **GO ADR-0005 (2026-07-26)** : code produit Esti + CdM **supprimé** du monorepo V1 (`ESTI_WC_REMOVAL_DONE.md`). Collections Firestore legacy peuvent encore exister côté data ; client + exports Functions `tournament_scoring` retirés.

- ⛔ **Écran tournoi** — pronostics sur `tournaments/{id}/…` *(retiré client)*.
- ⛔ **Scoring tournoi** — Functions recalcul / undo / leaderboard matchday *(plus exporté depuis `functions/index.js` ; undeploy manuel éventuel)*.
- ⛔ **Onglets / rollouts World Cup & Esti** — flags de visibilité *(retirés)*.
- ⛔ **Ligues Esti** — `esti_dvcr_leagues` + membres *(client retiré)*.
- ⛔ **Fix matchdays Esti** — callable `fixEstiDvcrMatchDays` *(plus exportée)*.
- ⛔ **Admin : alias historiques** — routes esti/cdm *(retirés)*.
- ⛔ **Partenaire world-cup (admin)** — section dans onglet pronos *(retirée)*.

---

## 12. Chat / Communauté

- ✅ **Onglet Communauté** — salons `chat_salons` + messages.
- ✅ **Messages temps réel** — create, réactions emoji, soft-delete.
- ✅ **Indicateur typing** — `chat_typing`.
- ✅ **Mentions** — push `notifyChatMention`.
- ✅ **Badges de rôle dans le chat** — affichage rôles / staff.
- ✅ **Modération** — signalements `reports`, ban temporaire, warnings (CM).
- ✅ **Admin Chat & modération** — onglet `CommunauteTab`.
- ✅ **Nettoyage messages anciens** — schedule Functions.
- ✅ **Archivage salons live** — fin de direct + cleanup archives.
- ✅ **Flag visibilité chat** — `CommunityChatRollout`.

---

## 13. Articles / Actus

- ✅ **Liste Actus** — catégories, featured, détail.
- ✅ **Commentaires articles** — sous-collection + compteur.
- ✅ **Likes / vues** — compteurs sur articles (selon UI).
- ✅ **Éditeur article (staff)** — `ArticleEditorScreen` / admin Actus.
- ✅ **Import Wix** — webhook → `articles` + enrichissement scrape.
- ✅ **Push nouvel article** — trigger publication.
- ✅ **Accès invité aux Actus** — tab ouvert en guest mode.

---

## 14. Notifications

- ✅ **FCM token sync** — multi-plateforme (`fcmTokens`).
- ✅ **Préférences canaux** — `NotificationPrefsService` + channels Android/APNs.
- ✅ **Centre de notifications in-app** — `NotificationsCenterScreen`.
- ✅ **Notifs live** — buts, cartons, kickoff, fin, émission.
- ✅ **Notifs actus / PDF bénévoles / social** — triggers dédiés.
- ✅ **Notifs rappel match** — candidats + envoi manuel admin.
- ✅ **Notifs compositions** — `notifyLineups`.
- ✅ **Notifs manuelles / diffusion** — file `notifications_queue` (topics, UIDs, team, adhérents).
- ✅ **Notifs bénévoles ciblées** — panel delivery admin.
- ✅ **Pause maintenance notifs** — `app_config/admin_maintenance`.
- ✅ **Recap match pour pronostiqueurs** — `notifyMatchRecap`.

---

## 15. XP, badges, niveaux

- ✅ **Gain XP** — événements allowlistés (prono, duel, etc. — **hors** events tournoi exclus).
- ✅ **Niveaux** — config `app_settings/xp_levels`.
- ✅ **Badges** — catalogue `badges` + logs.
- ✅ **Leaderboard XP hebdo** — schedule + doc settings.
- ✅ **Admin XP** — onglet configuration / attribution manuelle (action sensible).
- ✅ **Parrainage XP** — `useReferralCode`, stats.

---

## 16. Adhérents & HelloAsso

- ✅ **Webhook HelloAsso** — adhésion / don → flags user / donations.
- ✅ **Expiration adhérents** — job schedule.
- ✅ **Admin Adhérents** — suivi, matching paiements en attente.
- ✅ **Ciblage notifs adhérents** — audience queue.
- ✅ **Dons** — collection `donations` + UI soutien.
- ✅ **Config adhésion** — `app_config/helloasso_adhesion`.

---

## 17. Bénévoles (Team DVCR)

- ✅ **Espace bénévoles app** — documents PDF pour rôle `team_dvcr`.
- ✅ **Visionneuse PDF** — écran benevole.
- ✅ **Admin Bénévoles** — CRUD docs + Storage `benevole_docs/`.
- ✅ **Push nouveau PDF** — trigger Functions.
- ✅ **Notifs bénévoles** — section / panel delivery.
- ✅ **Liste membres Team DVCR** — `TeamDvcrMembersService`.

---

## 18. Sponsors & partage

- ✅ **Sponsors configurables** — `config/sponsors` (logo, couleur, lien, actif).
- ✅ **Affichage sponsors** — services / encarts UI.
- ✅ **Partage natif** — `share_plus` + `DvcrShareService` (package via politique).
- ✅ **Templates de texte de partage** — config `share_text_templates` / cache.
- ✅ **Cartes de partage** — config `share_card`.
- ✅ **Partage résultats / pronos** — helpers dédiés.

---

## 19. Stades & équipes

- ✅ **Admin Équipes & stades** — fiches `teams`, images stade.
- ✅ **Association image stade ↔ match** — affichage cartes.

---

## 20. Administration (centre staff)

- ✅ **Portail web admin** — home Flutter Web.
- ✅ **Shell admin** — sidebar par univers, permissions par onglet.
- ✅ **Deep-links `#/admin/<segment>`** — bookmark onglets (segments **cœur** uniquement).
- ✅ **Dashboard / Pilotage** — KPIs / vue d’ensemble.
- ✅ **Onglet Direct** — match-day ops.
- ✅ **Onglet Matchs** — éditeur matchs, sync FFF.
- ✅ **Onglet Stats** — workbench stats.
- ✅ **Onglet Actus** — éditorial.
- ✅ **Onglet Notifications / Diffusion** — campagnes + rappel match.
- ✅ **Onglet Membres** — gestion users, rôles (selon droits).
- ✅ **Onglet Communauté** — modération chat.
- ✅ **Onglet Pronos** — championnat, duels/ligues, visibilité, reset, vote history, bannières (**sans** World Cup / Esti).
- ⛔ **Sous-surfaces admin « jeux » événementiels** (CdM / Esti / partenaire world-cup / alias routes) — hors core.
- ✅ **Onglet XP** — config niveaux / badges.
- ✅ **Onglet Réglages** — version app, FFF season, season lifecycle, maintenance, extras, bannières soutien, etc. (tenant-aware).
- ✅ **Onglet TV** — Android TV.
- ✅ **Onglet Journal** — logs / audit.
- ✅ **Onglet Staff & permissions** — matrice RBAC, badges rôles, sponsors staff.
- ✅ **Actions sensibles gated** — promotion rôles, delete Auth user, XP manuel, pilot live…
- ✅ **Delete / reset user Auth** — callable `adminDeleteAuthUser`.
- ✅ **Audit trail** — `admin_audit_logs` + logger.
- ✅ **Maintenance système** — section admin (pause notifs, etc.).

---

## 21. Permissions & rôles staff

- ✅ **Rôles multiples** — tableau `roles[]` + legacy `role`.
- ✅ **Permissions granulaires `admin.*`** — access, dashboard, direct, matches, stats, articles, notifs, users, community, xp, settings, stades, logs, tv, benevoles, adherents, pronos, staff, benevoles.notifs…
- ✅ **Defaults par rôle** — CM, statisticien, editor, admin…
- ✅ **Surcharge Firestore** — `config/role_permissions`.
- ✅ **Badges de rôle** — `config/role_badges` / panels.
- ✅ **Claims `dvcr_admin`** — sync Functions + refresh client.
- ✅ **Règles Firestore alignées** — editorial vs match-ops vs stats.

---

## 22. Paramètres & configuration app

- ✅ **Version / bannière update** — `app_config/app_version`.
- ✅ **FFF season settings** — IDs compétition, sync enable, labels (**via tenant**, pas hardcode).
- ✅ **Season lifecycle** — betweenSeasons, messages UX.
- ✅ **Feature flags** — activation modules **cœur**.
- ⛔ **Feature flags World Cup / Esti** — non repris comme modules core.
- ✅ **Chat config** — `app_config/chat`.
- ✅ **Support / liens** — `app_config/support`.
- ✅ **Maintenance admin** — pause notifs, bypass.
- ⚠️ **Cache app** — `AppCacheService` (stratégie à redéfinir proprement).
- ⚠️ **Profil hero assets** — config.
- ⚠️ **Archive compétition / saison** — callables XP / seasons (ops ; cadrer en conception).

---

## 23. Intégrations externes

- ✅ **Firebase Auth / Firestore / Storage / FCM / Functions / Hosting**.
- ✅ **API DOFA FFF** — sync calendrier & classement.
- ✅ **YouTube Data API** — sync vidéos.
- ✅ **Wix Automations** — articles.
- ✅ **HelloAsso** — adhésions / dons.
- ✅ **App Store / Play** — versioning, Live Activity Xcode docs, fastlane iOS.
- ✅ **Android TV clients** — via HTTP Functions.

---

## 24. Qualité produit transverse

- ⚠️ **Mode hors-ligne partiel** — connectivity_plus (gestion connexion).
- ⚠️ **Animations / Lottie** — polish UI (package via ADR si retenu).
- ⚠️ **Markdown / HTML actus** — rendu riche (package via ADR si retenu).
- ⚠️ **Graphiques** — fl_chart (stats / XP selon écrans ; ADR si retenu).
- ⚠️ **Accessibilité basique** — Material ; pas d’audit a11y formalisé inventorié.
- ✅ **Multi-plateforme** — iOS, Android, Web admin (desktop targets V1 : ⚠️ pas prioritaires V2).

---

## Synthèse quantitative (disposition V2)

| Domaine | ✅ Cœur | ⛔ Hors scope | ⚠️ À revoir |
|---------|---------|---------------|-------------|
| Auth & compte | ~13 | 0 | ~1 |
| Navigation / shell | ~3 | ~2 | ~2 |
| Home | 10 | 0 | 0 |
| Matchs / calendrier / FFF | ~13 | 0 | ~1 |
| Direct live | ~15 | 0 | ~3 |
| Streaming / TV | ~10 | 0 | ~1 |
| Stats match | ~8 | ~1 | ~1 |
| Score / joueurs / overlays | ~7 | 0 | ~1 |
| Pronos championnat | 14 | 0 | 0 |
| Pronos sociaux | 8 | 0 | 0 |
| Tournois / Esti / CdM | **0** | **7** | 0 |
| Chat | 10 | 0 | 0 |
| Articles | 7 | 0 | 0 |
| Notifications | 11 | 0 | 0 |
| XP / badges | 6 | 0 | 0 |
| Adhérents / HelloAsso | 6 | 0 | 0 |
| Bénévoles | 6 | 0 | 0 |
| Sponsors / share | 6 | 0 | 0 |
| Stades | 2 | 0 | 0 |
| Admin | ~19 | ~1 (+ surfaces §11) | 0 |
| Permissions | 7 | 0 | 0 |
| Settings / config | ~7 | ~1 | ~3 |
| Intégrations | 7 | 0 | 0 |
| Transverse | ~1 | 0 | ~5 |

> Pour la modernisation in-place, traiter les **✅** (comportement à conserver) et trancher les **⚠️** en conception. Les **⛔** ne sont **pas** industrialisés dans le core — éventuellement extension (ADR-0002). Voir `MODERNIZATION_PLAN.md` (pas `MIGRATION_PLAN.md`, superseded).

---

## Pushbacks liés à cet inventaire

1. Ne pas scaffolder toutes les features listées en dossiers vides.
2. Ne pas industrialiser la §11 (Esti / World Cup / tournois) « au cas où ».
3. Ne pas démarrer le refactor code sans GO **ADR-0004** + module (`MODERNIZATION_PLAN.md`).
4. Ne pas réécrire une feature from scratch — refactor interne seulement.