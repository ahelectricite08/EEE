# Admin UX — visions cibles par module (17 onglets = outils)

**Date :** 2026-07-26  
**Statut :** Proposition — **attente validation**  
**Parent :** [`ADMIN_UX_ROADMAP.md`](./ADMIN_UX_ROADMAP.md)  
**IA dominante (4 flux) :** [`ADMIN_WORKFLOWS.md`](./ADMIN_WORKFLOWS.md) — 🟢 Prépa · 🔴 Direct · 🔵 Après · 🟣 Admin  
**Rôle de ce doc :** visions **par onglet-outil** (couche secondaire). La nav primaire produit = les flux, pas cette liste.  
**Règle :** chaque vision change l’**organisation** (jobs, layout, workflow). Features conservées. Pas de polish-only.  
**Ancrage :** lecture `lib/screens/admin/**` (registry, dashboard, direct, matchs, stats, diffusion, etc.)

Méthode commune : **JTBD → critique → organisation cible → mapping features → notes implémentation (après GO UX)**.

### Rappel — onglet → flux

| Onglet | Flux primaire | Secondaire |
|--------|---------------|------------|
| Pilotage | Pont 🟢/🔴/🔵 | 🟣 |
| Direct | 🔴 single-view | 🟢 setup |
| Matchs | 🟢 / 🔵 | 🔴 liens |
| Stats | 🔴 / 🔵 | — |
| Diffusion | 🟢 / 🔴 / 🔵 | 🟣 |
| Stades, TV | 🟢 | 🟣 |
| Actus | 🔵 | 🟢 / 🟣 |
| Chat & modération | 🔴 (queue) | 🟣 |
| Membres, Staff, Réglages, Logs, XP, Pronos, Bénévoles, Adhérents | 🟣 | (voir matrice `ADMIN_WORKFLOWS`) |

---

## Univers Match Day & Pilotage

### 0 — Pilotage (`DashboardTab`)

| | |
|--|--|
| **JTBD** | En 30 s : état live, urgences, entrée Direct/Stats/Rappel/Fiche. Hors match : health + backlog. |
| **Critique** | Fold = santé + KPIs génériques. `DashboardMatchDayCard` écrite, **jamais montée**. CTA Direct seulement si live. |
| **Cible** | Cockpit **jour de match** au-dessus du fold (live, match, score/minute si dispo, CTA Direct / Stats / Rappel / Fiche / Push). Health + KPIs + listes = sous le fold ou mode « Hors match ». |
| **Features** | Live pill, health, maintenance, KPIs, inscrits, notifs, CTA Direct — tous conservés, **réordonnés**. Carte match-day devient le cœur (ou remplacée par layout équivalent). |
| **Impl. après GO** | F0bis roadmap (pont 4 flux). Risque S–M. |

---

### 1 — Direct (`DirectTab`) — cœur du flux 🔴 single-view

| | |
|--|--|
| **Flux** | 🔴 **Match en direct** — tout dans une seule vue (score, chrono, faits, stats, push, modération). Voir `ADMIN_WORKFLOWS` §4. |
| **JTBD** | Piloter live (score, chrono, buts, cartons) ; stats sans perdre le contexte ; push/modo ; votes aux bons moments ; salon/émission souvent hors pic. |
| **5 actions / 95 %** | But/score · Chrono (MT/FIN) · Cartons · Start/Stop live · Ouvrir/sync stats. |
| **Critique** | Un `ListView` : live → votes → salon → émission. Pas de sticky. Stats = navigation workbench. Surcharge jour de match. |
| **Cible** | **Single-view** : bandeau sticky + latéral (URL, match, stats, compos, push, signalements) + **Mode Pilotage** (défaut) vs **Mode Studio** (salon + émission/sondage). Votes en drawer. Raccourcis clavier web. Split stats. |
| **Features** | Toggle live + dialog démarrage, URL, quick pilotage, bandeau stats, compos, MOTM/notes, salon, émission, sondage, RO statisticien — **mapping 1:1** vers sticky / latéral / Studio. |
| **Impl. après GO** | F0 prototype → F1 (`ADMIN_UX_ROADMAP` §8). Risque **élevé**. Plusieurs PR organisationnelles. |

Questions types (réponses cibles) :

- Infos toutes utiles ? → Non en pic : Studio hors mode Pilotage.  
- Sans quitter l’écran ? → Oui pour le chaud ; stats en panneau/split.  
- Clavier / latéral / mode match-day ? → Oui / oui / oui.

---

### 3 — Matchs (`MatchsTab` + `MatchEditorScreen`)

| | |
|--|--|
| **JTBD** | Trouver / créer match ; jumper Direct/Stats/Rappel ; éditer fiche & faits post-match. |
| **Critique** | Liste cartes + quick actions = bon. Éditeur scroll unique dense ; confusion faits vs stats chiffrées ; 3 destinations pour un match. |
| **Cible** | Liste = **centre de commande** (mettre en avant LIVE ; option vue **agenda** en plus des cartes ; statut rappel/stats si possible). Éditeur = **3 pièces** : Identité & calendrier · Faits & post-match · Liens ops (pas de saisie stats dupliquée). |
| **Features** | Nouveau, filtres, Fiche/Stats/Direct/Rappel, modifier, replay, supprimer, toutes sections éditeur, import live — conservées. |
| **Impl. après GO** | L4. Risque M. |

---

### 4 — Statistiques match (`StatsTab` + workbench)

| | |
|--|--|
| **JTBD** | Saisir chiffres ; publier carte/officiel ; archiver ; comparer ; averages saison. |
| **Critique** | Hub riche OK. Workbench : toggles publication **au même niveau** que compteurs → parcours opaque sous stress. |
| **Cible** | Chemin chaud **Saisie → Publier** (steps). Archive/Comparer hors chemin. Ouverture depuis Direct en **panneau** si possible. Clarifier états (brouillon / carte / officiel / verrouillé) dans l’étape Publier seulement. |
| **Features** | EN DIRECT/ARCHIVE/COMPARER, compteurs, sync, terminer/rouvrir, migration, moyennes, buteurs saison — conservées. |
| **Impl. après GO** | L2. Risque M–É. |

---

## Univers Contenu & diffusion

### 2 — Actus (`ArticlesTab`)

| | |
|--|--|
| **JTBD** | Publier / une / brouillon ; éditer article. |
| **Critique** | List→editor clair. Lien faible vers notification d’actu. |
| **Cible** | Conserver CMS. Action **Notifier** → Diffusion préremplie (canal Actus + titre). Prioriser « À la une » / brouillons dans la liste. |
| **Features** | PUBLIÉS/BROUILLONS/UNE, CRUD, publish — conservées + pont Diffusion. |

---

### 8 — Équipes & stades (`StadesTab`)

| | |
|--|--|
| **JTBD** | Maintenir référentiel équipe / image stade. |
| **Critique** | Simple ; doublon conceptuel avec champs logos/stade de l’éditeur match. |
| **Cible** | Référentiel unique ; éditeur match **sélectionne** plutôt que re-saisir quand possible (feature sélection ≠ delete champs free-text si encore nécessaires). |
| **Features** | CRUD nom + URL image — conservées. |

---

### 5 — Notifications (`DiffusionTab` = Push + Rappel)

| | |
|--|--|
| **JTBD** | Rappel match rapide ; push live/alerte/actu ; historique. |
| **Critique** | Push = 6–8 étapes. Rappel meilleur mais sous-tab peu découvert. Composeurs parallèles ailleurs. |
| **Cible** | Accueil = **3 intents** : Rappel · Push match/live (prérempli) · Push libre (formulaire complet). CTA depuis Pilotage/Direct/Matchs. Historique visible d’emblée. |
| **Features** | Canaux, audiences, modèles, deep-links, test compte, rappel CF, historique — 100 %. |
| **Impl. après GO** | L3. Risque M. |

---

## Univers Communauté

### 6 — Membres (`UsersTab`)

| | |
|--|--|
| **JTBD** | Chercher membre ; rôles ; XP ; paiements ; reset mdp ; delete Auth. |
| **Critique** | Fiche / sheet **god-object** — tout mélangé. |
| **Cible** | Fiche en **onglets locaux** : Identité · Rôles · XP · Paiements · Zone danger (delete). Liste : recherche + filtres rôle inchangés en capacité. |
| **Features** | Toutes actions actuelles — redistribuées. |

---

### 7 — Chat & modération (`CommunauteTab`)

| | |
|--|--|
| **JTBD** | Traiter signalements ; modérer messages ; config salons / mots bloqués. |
| **Critique** | Config salons en tête ; **signalements en bas** — inverse de l’urgence. Dashboard compte les sign. sans deep link fort. |
| **Cible** | **Queue signalements d’abord** (fold). Config salons / emojis / mots = secondaire. Lien Pilotage → cette queue. |
| **Features** | CRUD salons, clear, blocked words, viewer messages, signalements — conservées. |

---

### 16 — Bénévoles (`BenevolesTab`)

| | |
|--|--|
| **JTBD** | Docs / planning ; notifier bénévoles. |
| **Critique** | Ops + **composeur push complet** dans le même flux — charge. |
| **Cible** | Sous-onglets **Espace** (Sheet, PDF) vs **Notifications** (templates + delivery). Ne pas diluer le planning sous le composeur. |
| **Features** | Planning URL, docs, notifs bénévoles (perm `admin.benevoles.notifs`) — conservées. |

---

### 17 — Adhérents (`AdherentsTab`)

| | |
|--|--|
| **JTBD** | Statut HelloAsso ; échéances ; push adhérents ; paiements non rattachés. |
| **Critique** | CRM + push + orphelins paiements sur une même surface. |
| **Cible** | Vues **Adhérents** · **Paiements orphelins** · **Push** (ou intents). Liste adhérents scannable (statut / fin). |
| **Features** | HelloAsso, dates, push, paiements non rattachés — conservées. |

---

## Univers Jeux

### 18 — Pronos & jeux (`PronosAdminTab`)

| | |
|--|--|
| **JTBD** | Suivre championnat / duels ; piloter visibilité home & bannières ; reset saison. |
| **Critique** | Trois sous-onglets OK. Visibilité/reset = ops saison mélangés au suivi jeu. |
| **Cible** | **Suivi** (Championnat, Duels) vs **Ops saison** (visibilité, bannières, vote history, reset). Pas de retour Esti/CdM. |
| **Features** | Tous sous-onglets actuels — regroupement labels/IA seulement. |

---

## Univers Système

### 10 — XP & Niveaux (`XpTab`)

| | |
|--|--|
| **JTBD** | Config événements XP ; niveaux ; voir classement ; (édition user → Membres). |
| **Critique** | Dense ; overlap avec XP dans fiche membre. |
| **Cible** | Garder ÉVÉNEMENTS / NIVEAUX / CLASSEMENT. Depuis classement : **ouvrir membre** (Membres) pour XP manuel. Séparer clairement config vs consultation. |
| **Features** | Conservées. |

---

### 11 — Réglages (`SettingsTab`)

| | |
|--|--|
| **JTBD** | Maintenance, saison FFF, bannières home, version, support, lifecycle… |
| **Critique** | Kitchen-sink APPLICATION / SAISON FFF ; concepts TV/staff parfois éclatés. Copy CDM résiduelle. |
| **Cible** | Grouper par **job** : Maintenance & accès · Saison & FFF · Contenu home (bannières) · Support & version. Cleanup copy CDM = GO ADR-0005. |
| **Features** | Toutes sections settings — redistribuées, pas supprimées. |

---

### 15 — Android TV (`TvAdminTab`)

| | |
|--|--|
| **JTBD** | Configurer antenne TV (HLS, next live, featured, audience). |
| **Critique** | Thin wrapper autour panels ; mission peu narrative. |
| **Cible** | Une page **mission** : « Ce que voit la TV maintenant » + réglages stream/featured/next live regroupés par intent. |
| **Features** | Panels TV actuels — conservés. |

---

### 12 — Journal (`LogsTab`)

| | |
|--|--|
| **JTBD** | Auditer actions admin ; filtrer ; chercher. |
| **Critique** | Correct pour lecture. Peu de pont vers l’entité concernée. |
| **Cible** | Conserver Historique/Audit. Améliorer filtres + **lien vers onglet/entité** quand l’id est connu. Pas d’actions destructives ici. |
| **Features** | Conservées. |

---

### 20 — Staff & permissions (`StaffTab`)

| | |
|--|--|
| **JTBD** | Matrice permissions ; badges rôles ; sponsors staff. |
| **Critique** | Sous-onglets clairs ; risque de double emploi historique avec Settings. |
| **Cible** | **Point d’entrée unique RBAC**. Sponsors = rester ici (pas Settings). Pas de changement matrice Firestore dans ce chantier UX. |
| **Features** | PERMISSIONS / BADGES / SPONSORS — conservées. |

---

## Hors onglets vivants (à ne pas « redesign » comme modules)

| Alias / dette | Traitement UX |
|---------------|---------------|
| Rappel match (index historique) | Reste sous Diffusion ; **découvrabilité** via intents + CTA (pas nouvel onglet registry). |
| Badges index | Redirect Staff — OK. |
| Esti / Tournament | **Non remis** (ADR-0002). |
| Entrée Profil statisticien | Organisation d’**accès** : afficher Admin si `admin.access` — micro-livraison parallèle. |

---

## Ordre de validation suggéré (par flux, puis outils)

1. **IA 4 flux** (`ADMIN_WORKFLOWS`) + **🔴 Direct single-view** (wireframe) — option Pilotage pont  
2. Outils boucle live : **Stats** + **Diffusion** (au service 🔴 / 🔵)  
3. **🟢 Hub Prépa** (Matchs pièce 1, Stades, TV, setup Direct)  
4. **🔵 Hub Après** (Stats publier, Matchs faits/replay, Actus)  
5. **Chat & modération** queue-first (latéral 🔴)  
6. **🟣 Admin** : Membres / Staff / Réglages / Logs / Pronos / XP / Bénévoles / Adhérents  

Les 17 visions ci-dessus restent valides comme **réorg interne des outils** — subordonnées aux hubs de flux.

---

## Question

**Valides-tu l’IA par flux + ces visions outils ? Lesquelles corriger avant prototype 🔴 Direct single-view ?**

---

*Docs only — zéro code applicatif.*
