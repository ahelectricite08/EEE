# Feuille de route — Refonte organisationnelle UX Administration DVCR

**Date :** 2026-07-26  
**Statut :** Proposition produit / UX — **attente validation utilisateur**  
**Périmètre :** Admin existant (`lib/screens/admin/**`, façade `lib/features/admin/**`) — **pas** un nouvel Admin V2  
**Architecture IA (dominante) :** [`ADMIN_WORKFLOWS.md`](./ADMIN_WORKFLOWS.md) — **4 flux** 🟢 Prépa · 🔴 Direct · 🔵 Après · 🟣 Admin  
**Source d’état :** [`ADMIN_STATUS.md`](./ADMIN_STATUS.md)  
**Visions par onglet (outils secondaires) :** [`ADMIN_UX_MODULE_VISIONS.md`](./ADMIN_UX_MODULE_VISIONS.md)  
**Résumé 1 page :** [`ADMIN_UX_SUMMARY.md`](./ADMIN_UX_SUMMARY.md)  
**Cadre :** ADR-0004 (modernisation in-place), ADR-0005 (cleanup uniquement après GO), ADR-0002 (Esti/CdM non remis)  
**Ce chantier docs :** zéro modification `lib/`, `functions/`, `pubspec`

---

## 0. Architecture informationnelle par flux (dominante)

**Navigation primaire = phases de travail**, pas 17 onglets plats.

| Flux | Promesse | Prototype / livraison |
|------|----------|------------------------|
| 🟢 **Préparation** | Fiche, compos, live programmé, notifs, graphismes/TV | Hub checklist → outils Matchs / Direct / Diffusion / TV / Stades |
| 🔴 **Match en direct** | **Single view** : score, chrono, buts, cartons, stats, push, modération | **#1 recommandé** — sticky + Pilotage/Studio + latéral |
| 🔵 **Après-match** | Stats finalisées, MOTM, replay, résumé, classements, publication | Hub checklist → Stats / Matchs / Actus / Diffusion |
| 🟣 **Administration** | Utilisateurs, staff, paramètres, TV, journaux | Catalogue d’outils (CRM, RBAC, système) |

Les **17 onglets** (`admin_tab_registry`) restent la **couche outils** (RBAC, deep-links `#/admin/<segment>` stables). Les flux sont la **couche jobs**. Rien n’est perdu — réorganisation IA. Détail, matrice feature→flux, cohabitation tabs, risques : **[`ADMIN_WORKFLOWS.md`](./ADMIN_WORKFLOWS.md)**.

**Ordre produit de cette feuille :** Prépa → Direct → Après → Admin *(implémentation recommandée : Direct d’abord, puis hubs Prépa/Après, puis catalogue Admin)*. Design system = **outil**, jamais l’étape dominante.

---

## 1. Manifeste produit (anti-timidité, anti-polish-only)

Cette feuille de route **n’est pas** une vague « harmoniser boutons / tokens / headers ».

| On refuse | On vise |
|-----------|---------|
| Étapes A→B→C = kit composants puis labels sidebar | **Organiser l’Admin par flux** (Prépa / Direct / Après / Admin), puis layouts |
| Sidebar = vérité produit | Sidebar 17 tabs = **outils** ; rail flux = **jobs** |
| « Rendre plus joli » l’existant scrollé | **Plus rapide, intuitif, efficace au quotidien** |
| Micro-ajustements cosmétiques présentés comme UX | Déplacer blocs, fusionner panneaux, changer workflows, redéployer l’info |
| Design system comme **étape principale** | Design system = **outil au service** des nouveaux layouts (après validation UX) |
| Nouvel Admin / second arbre Flutter | **Évolution de l’admin vivant** — mêmes permissions, toutes features conservées |

**Règle d’or :** si une livraison ne change **pas** l’organisation (flux, layout, hiérarchie, workflow, densité d’actions), ce n’est **pas** une livraison de cette feuille de route — c’est du polish hors scope (ou outil secondaire).

**Anti-timidité :** chaque module / onglet peut être remis en question *comme placement*. Conserver les **features** ≠ conserver le **placement** des features.

---

## 2. Principes d’usage

| # | Principe | Question produit |
|---|----------|------------------|
| U0 | **Jobs avant pixels** | Qu’est-ce que le staff vient **faire** ici ? Pas « quoi afficher ». |
| U1 | **5 actions / 95 %** | Quelles sont les 5 actions faites 95 % du temps ? Elles doivent être **impossibles à rater**. |
| U2 | **Match-day first** | Jour de match = contrainte temps réel. Mode simplifié vs écran « cuisine » hors match. |
| U3 | **Zéro navigation inutile** | Peut-on tout faire (ou presque) **sans quitter** l’écran principal du job ? |
| U4 | **Densité utile** | Toute info affichée est-elle utile *maintenant* ? Sinon → secondaire, replié, autre mode. |
| U5 | **Raccourcis & latéral** | Clavier (web), panneau latéral, bandeau contexte : accélérateurs, pas décoration. |
| U6 | **Features intactes** | Aucune capacité métier retirée. Mapping explicite « où ça vit maintenant ». |
| U7 | **Même Admin** | Indices d’onglets, deep-links, RBAC stables. Réorganisation **interne** aux modules. |
| U8 | **Web = poste de travail** | Desktop/sidebar d’abord. Mobile = secours (ne pas bloquer sur redesign phone). |
| U9 | **Validation UX avant code** | Prototype / maquette organisation → GO → implémentation. Pas de « on polish en attendant ». |

---

## 3. Méthode (par flux, puis par outil)

1. **Flux d’abord** — valider IA [`ADMIN_WORKFLOWS.md`](./ADMIN_WORKFLOWS.md) (jobs de phase, hub, mapping).
2. **Puis onglet-outil** — pour chaque tab touché par le flux :
   - JTBD · critique existant · layout cible · mapping features · PR org après GO.
3. Visions outils : §5 (prioritaires match-day) + [`ADMIN_UX_MODULE_VISIONS.md`](./ADMIN_UX_MODULE_VISIONS.md).

---

## 4. Diagnostic rapide (ancré dans le réel)

Constat issu de `admin_tab_registry.dart`, shell, et lecture des tabs critiques.

### Ce qui tient déjà

- Shell unique + 6 univers sidebar + deep-links `#/admin/<segment>`.
- Quick actions match (Fiche / Stats / Direct / Rappel) sur la liste Matchs.
- Pilotage live réel via `LiveMatchQuickPilotageBody` (score, chrono, buts, cartons).
- Diffusion unifiée Push + Rappel match (sous-onglets).
- RBAC par onglet + lecture seule Direct pour statisticien.

### Problèmes d’**ergonomie** (pas cosmétiques)

| ID | Module | Problème organisationnel |
|----|--------|---------------------------|
| E1 | **Pilotage** | Dashboard = santé système + KPIs génériques. `DashboardMatchDayCard` **existe mais n’est pas branchée**. Les 30 premières secondes ne servent pas le match du jour. |
| E2 | **Direct** | Un seul `ListView` (~3.1k L) : live → votes → salon → émission/sondage. **Pas de sticky**, pas d’onglets locaux. Actions chaudes perdues au scroll. Stats = sortie obligatoire vers workbench. |
| E3 | **Matchs** | Liste cartes OK + quick actions ; éditeur monolithe (~2.3k L) mélange calendrier, faits, post-match, liens stats. Trois surfaces (Direct / Fiche / Stats) pour un même match. |
| E4 | **Stats** | Hub EN DIRECT / ARCHIVE / COMPARER + workbench publication multi-étapes (débloquer → saisir → carte → sync → officialiser). Charge cognitive élevée en live. |
| E5 | **Notifications** | Push = long formulaire 6–8 étapes ; rappel plus court mais **peu découvrable** (sous-tab). Pas de « envoi en 2 clics » depuis le match. |
| E6 | **Transversal** | Job match-day éclaté sur Direct + Matchs + Stats + Diffusion ; Pilotage ne relie pas. |

---

## 5. Visions détaillées (modules prioritaires)

Chaque proposition majeure : **problème d’ergonomie** → **organisation cible** → **features conservées** → **écrans impactés** → **risque / difficulté / bénéfices**.

---

### 5.1 Dashboard (Pilotage) — les 30 premières secondes

#### Jobs-to-be-done
- Savoir en &lt;5 s : live ON/OFF, quel match, urgences (signalements, file notifs).
- Entrer en 1 clic dans Direct / Stats / Rappel / Fiche du match du jour.
- Hors match-day : health + backlog éditorial (sans monopoliser le fold).

#### Critique de l’existant
Ordre actuel : header Live → santé système → maintenance → KPIs utilisateurs/articles/notifs → inscrits / notifs récentes. La carte « JOUR DE MATCH » (chips Direct/Stats/Matchs/Diffusion, « Saisir stats », « Fiche match ») est **orpheline**.

#### Organisation cible
```
┌─────────────────────────────────────────────────────────┐
│  COCKPIT JOUR DE MATCH (fold)                           │
│  Live ON/OFF · match · minute · score aperçu            │
│  [Direct] [Stats] [Rappel] [Fiche] [Push live]          │
│  Alertes : signalements / file notifs (compteurs)       │
├─────────────────────────────────────────────────────────┤
│  MODE HORS MATCH (ou sous le fold)                      │
│  Santé système · KPIs · derniers inscrits / notifs      │
└─────────────────────────────────────────────────────────┘
```
- **Jour de match** = mode par défaut si live OU prochain CSSA &lt; N h.
- Health / KPIs / listes = **secondaires** (toujours accessibles, plus bas ou onglet local « Système »).

#### Mapping features conservées

| Aujourd’hui | Cible |
|-------------|--------|
| Pill Live + CTA Direct si live | Intégré au cockpit |
| AdminSystemHealthPanel | Sous le fold / mode hors match |
| KPIs users/articles/notifs | Idem |
| Derniers inscrits / notifs | Idem |
| DashboardMatchDayCard (non branchée) | Devenir le **cœur** du fold (ou son successeur layout) |

#### Écrans impactés
`dashboard_tab.dart`, `dashboard_match_day_card.dart`, `admin_system_health_panel.dart`, navigation `admin_navigation.dart`.

| Risque | Difficulté | Bénéfices |
|--------|------------|-----------|
| Faible–Moyen (layout + streams déjà là) | S–M | Orientation immédiate ; moins de formation ; ROI élevé |

---

### 5.2 Direct — cockpit match-day (vision détaillée — exemple type)

#### Jobs-to-be-done
1. Démarrer / arrêter le live (calendrier, domicile/extérieur, URL stream).
2. Piloter score, chrono, buts, cartons **sans perdre la main**.
3. Basculer bandeau stats / compositions ; ouvrir saisie stats sans perdre le contexte live.
4. Gérer MOTM / notes (moments précis, pas en continu).
5. Surveiller salon live ; piloter émission / sondage (souvent **autre personne** ou hors pic).

#### Les 5 actions ≈ 95 % du temps (quand live)
1. Ajuster score / **AJOUTER BUT**  
2. Chrono (0′ / 45′ / MI-TEMPS / 2e MT / FIN)  
3. Cartons (+ JAUNE / + ROUGE)  
4. Démarrer / Arrêter live  
5. Saisir / sync stats (ou ouvrir workbench)  

→ Tout le reste (salon, émission, sondage, votes) = **secondaire** pendant le pic.

#### Critique de l’existant
- Un scroll vertical unique : Match en direct → Votes & notes → Salon live → Émission & sondage.
- Pilotage chaud dans `LiveMatchQuickPilotageBody` : **non sticky** — scroll = perte de contrôle.
- Stats chiffrées = bouton « Saisir les statistiques » → **autre écran** (workbench).
- Code mort / doublons dans le même fichier (`_ScorePanel`, `_GoalFeed` non utilisés) = poids cognitif pour les mainteneurs, symptôme d’accumulation sans réorganisation.
- Statisticien : bandeau RO OK, mais UI ne distingue pas clairement « suivi » vs « pilotage ».

#### Questions produit → réponses cibles

| Question | Réponse cible |
|----------|----------------|
| Toutes les infos utiles ? | Non : émission/sondage/salon hors mode « Jour de match ». |
| Tout sans quitter l’écran ? | Oui pour score/chrono/faits ; stats = **panneau latéral ou split** (pas navigation pleine page obligatoire). |
| Raccourcis clavier ? | Oui (web) : but domicile/extérieur, chrono pause, mi-temps, carton — documentés + focus. |
| Panneau latéral ? | Oui : contexte match + stats rapides / ouverture workbench embarqué. |
| Mode jour de match vs surcharge ? | **Deux modes** (ou onglets locaux) : *Pilotage* vs *Studio & chat*. |

#### Organisation cible
```
┌──────────────────────────────┬────────────────────────┐
│  BANDEAU FIXE (sticky)       │  LATÉRAL (collapsible) │
│  Score · Chrono · Phase      │  Match lié · URL       │
│  [But] [J] [R] [MT] [FIN]    │  Stats : sync / ouvrir │
│  Live ON · Arrêter           │  Compos · bandeau      │
├──────────────────────────────┤  Votes (lien / drawer) │
│  ZONE PRINCIPALE             │                        │
│  Mode PILOTAGE (défaut) :    ├────────────────────────┤
│    faits récents, corrections│  MODE STUDIO (tab) :   │
│  Mode STUDIO :               │    Salon · Émission    │
│    salon + émission/sondage  │    · Sondage           │
└──────────────────────────────┴────────────────────────┘
```
- **Mode Pilotage** = écran épuré ; rien sous le fold sauf faits récents.
- **Mode Studio** = salon + émission (features 100 % conservées, autre « pièce »).
- Votes/MOTM : drawer ou section du latéral — pas entre le score et le salon.
- Option **split** wide : workbench stats en panneau droit (même session Direct) pour éviter l’aller-retour.

#### Mapping features conservées

| Feature actuelle | Où dans la cible |
|------------------|------------------|
| Toggle MATCH EN DIRECT + dialog démarrage | Bandeau / header Pilotage |
| URL stream | Latéral |
| Score / chrono / buts / cartons / vider / but annulé… | Sticky + raccourcis |
| STATS EN DIRECT / compositions | Latéral ou barre secondaire sticky |
| Saisir les statistiques | Latéral +/ou split (même features workbench) |
| MOTM + notes public | Drawer / latéral « Votes » |
| Salon live (DirectLiveSalonPanel) | Mode Studio |
| Émission DVCR + sondage | Mode Studio |
| Lecture seule statisticien | Même layout ; contrôles hot désactivés + badge |

#### Écrans impactés
`direct_tab.dart`, `direct_live_salon_panel.dart`, `live_match_quick_panel.dart` (partagé), panels MOTM/rating, éventuellement embedding workbench stats.

| Risque | Difficulté | Bénéfices |
|--------|------------|-----------|
| **Élevé** (surface critique live) | L — plusieurs PR organisationnelles | Moins d’erreurs live ; vitesse ; moins de scroll ; jobs séparés CM vs studio |

**GO UX obligatoire** (prototype cliquable ou wireframe wide) avant toute PR.

---

### 5.3 Matchs — liste vs calendrier / cartes

#### Jobs-to-be-done
- Trouver le prochain match / le match live en &lt;3 s.
- Créer un match ; corriger fiche ; ouvrir Direct / Stats / Rappel.
- Post-match : replay, faits, MOTM — sans confondre avec stats chiffrées.

#### Critique de l’existant
- Liste **cartes** + filtres À venir / Résultats / Tous + quick actions : **bon socle**.
- Éditeur long : Équipes → Calendrier & statut → Faits & post-match → aide « deux types de données ». Friction = densité + correction gated + triplet Direct/Fiche/Stats.

#### Organisation cible
1. **Liste = centre de commande match** (pas seulement CRUD) :
   - Vue **Agenda / semainier** (option) **en plus** de la liste cartes — pas à la place des features.
   - Carte live mise en avant ; filtres + recherche.
   - Quick actions conservées ; ajouter **aperçu statut** (live / stats publiées / rappel envoyé ?).
2. **Éditeur en 3 « pièces »** (local tabs ou stepper), pas un scroll unique :
   - *Identité & calendrier* (équipes, date, statut, scores)
   - *Faits & post-match* (buteurs, cartons, remplacements, MOTM, replay, import live)
   - *Liens ops* (ouvrir Direct / Stats / Rappel — pas dupliquer la saisie stats)

#### Mapping features
Toutes sections actuelles de `match_editor` + quick actions + Nouveau / Supprimer / replay → redistribuées dans les 3 pièces + liste enrichie.

#### Écrans impactés
`matchs_tab.dart`, `match_editor.dart`, `admin_match_quick_actions.dart`.

| Risque | Difficulté | Bénéfices |
|--------|------------|-----------|
| Moyen | M–L | Scan plus rapide ; moins de confusion faits vs stats |

---

### 5.4 Statistiques — parcours saisie

#### Jobs-to-be-done
- En live ou juste après : saisir possession/tirs/… et pousser sur la carte.
- Finaliser / verrouiller / rouvrir sans erreur.
- Archiver, comparer, moyennes saison (hors urgence).

#### Critique de l’existant
Hub riche (EN DIRECT / ARCHIVE / COMPARER) + workbench avec machine d’états publication (Officiel / Carte / Verrouillé / Brouillon). Puissant mais **parcours non linéaire** : trop de toggles au même niveau que la saisie.

#### Organisation cible — parcours guidé
```
1. Choisir match (hub) 
2. SAISIE (compteurs) ← focus unique
3. PUBLIER (étape explicite) : carte → sync → officiel / terminer
4. ARCHIVE / COMPARER = hors chemin chaud
```
- **Séparer visuellement** saisie vs publication (deux zones ou deux steps), pas une forêt de toggles au-dessus des compteurs.
- Depuis Direct : ouvrir ce parcours en **panneau** (voir §5.2) pour ne pas casser le sticky score.
- EN DIRECT hub = file « à saisir » prioritaire ; ARCHIVE/COMPARER inchangés en capacité.

#### Mapping features
Publication controls, editor sections (POSSESSION…), sync carte, terminer/rouvrir, comparer, moyennes, migration — tous conservés, **réordonnés**.

#### Écrans impactés
`stats_tab.dart`, `match_stats_workbench_screen.dart`, `match_stats_editor.dart`, `stats_publication_controls.dart`, `stats_workflow_ui.dart`.

| Risque | Difficulté | Bénéfices |
|--------|------------|-----------|
| Moyen–Élevé (finalize/reopen) | L | Moins d’erreurs de publication ; parcours statisticien clair |

---

### 5.5 Notifications / Diffusion — workflow le plus rapide

#### Jobs-to-be-done
- Envoyer un rappel match en &lt;30 s.
- Push live / actu / alerte avec preview et audience.
- Retrouver les derniers envois.

#### Critique de l’existant
- `DiffusionTab` : PUSH MANUELLE | RAPPEL MATCH — bon regroupement.
- Push = canal → audience → modèles → titre/message → deep-link → aperçu → envoyer → historique (~6–8 étapes). Complet mais lent.
- Rappel plus court mais **caché** (pas d’entrée sidebar) ; IDs Firestore bruts pour deep-links.
- Autres composeurs (Bénévoles, Adhérents) = fragmentation « outbox ».

#### Organisation cible
1. **Accueil Diffusion = 3 intents** (pas un formulaire géant) :
   - *Rappel match* (chemin court : match → aperçu → envoyer)
   - *Push live / match* (prérempli depuis contexte match si ouvert depuis Pilotage/Direct)
   - *Push libre* (formulaire complet actuel, pour les 5 %)
2. Depuis Pilotage / Direct / carte Match : CTA **Rappel** et **Push** qui **atterrissent préremplis** (feature envoi inchangée).
3. Historique « derniers envois » visible dès l’accueil.
4. (Plus tard, hors bloquant) rapprochement conceptuel outbox Bénévoles/Adhérents — **sans** retirer les composeurs métier.

#### Mapping features
Canaux, audiences, modèles, deep-links, test mon compte, rappel CF, historique — 100 % conservés ; *Push libre* = formulaire actuel relogé.

#### Écrans impactés
`diffusion_tab.dart`, `notifs_tab.dart`, `match_reminder_tab.dart`, CTA depuis dashboard / matchs / direct.

| Risque | Difficulté | Bénéfices |
|--------|------------|-----------|
| Moyen (envoi push) | M | Rappels/push match en secondes ; moins d’erreurs deep-link |

---

## 6. Autres onglets (courts — organisation, pas polish)

Détail : [`ADMIN_UX_MODULE_VISIONS.md`](./ADMIN_UX_MODULE_VISIONS.md).

| Onglet | Critique organisation | Cible (idée) |
|--------|----------------------|--------------|
| **Actus** | Liste CMS correcte | Garder list→editor ; raccourci « notifier actu » vers Diffusion préremplie |
| **Équipes & stades** | CRUD simple ; doublon logos avec éditeur match | Référentiel clair ; éditeur match **réutilise** (pas double saisie conceptuelle) |
| **Membres** | Fiche god-object (rôles, XP, paiements, delete) | Fiche en **onglets locaux** : Identité / Rôles / XP / Paiements / Danger |
| **Chat & modération** | Config salons en tête ; **signalements en bas** | **Queue signalements d’abord** ; config en secondaire |
| **Bénévoles** | Planning + **second composeur push** | Ops bénévoles vs Notifs = deux zones / sous-onglets nets |
| **Adhérents** | CRM + push + paiements orphelins | Vue Adhérents / Paiements / Push séparées |
| **Pronos & jeux** | Championnat / Duels / Visibilité OK | Visibilité & reset = zone « Ops saison » distincte du suivi championnat |
| **XP & Niveaux** | Dense ; overlap Membres | Config événements/niveaux vs classement ; lien « éditer XP user » → Membres |
| **Réglages** | Kitchen-sink APPLICATION / SAISON FFF | Grouper par **job** (Maintenance, Saison, Contenu home, Support) — pas une liste plate |
| **Android TV** | Wrapper settings | Écran intent « Antenne TV » (HLS, next live, featured) — une page mission |
| **Journal** | OK lecture | Filtres + lien « voir entité » si possible ; pas d’action ops |
| **Staff & permissions** | Sous-onglets clairs | Point d’entrée unique RBAC ; éviter double emploi Settings |
| **Entrée statisticien** | Asymétrie Profil vs web | Micro-fix **organisation d’accès** (carte Profil si `admin.access`) — pas du style |

Copy CDM résiduelle (Réglages) = cleanup ADR-0005 **après GO** — cohérence produit, pas polish boutons.

---

## 7. Design system = outil, pas étape principale

- `admin_palette`, `AdminField`, `SettingsCard`, headers : **réutilisés pour implémenter** les nouveaux layouts.
- **Interdit** de faire de « Kit design system Admin » l’**étape 1** de cette feuille de route.
- Harmonisation visuelle = **effet de bord** des refontes d’organisation, ou chantier **parallèle mineur** hors chemin critique — jamais le récit produit principal.

---

## 8. Ordre de validation UX — autour des 4 flux

Chaque livraison **réorganise** un flux (ou un hub). Pas de PR « tokens only ». Ordre produit : **Prépa → Direct → Après → Admin** ; ordre d’implémentation recommandé : **Direct d’abord**.

```
              GO IA par flux ?  (ADMIN_WORKFLOWS.md)
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
   F0 Prototype    F0bis (option)   Accès statisticien
   🔴 Direct       Pilotage pont    (orga entrée Profil)
   single-view     vers 4 flux
         │               │
         └───────┬───────┘
                 ▼
          GO match-day UX
                 │
     ┌───────────┼───────────┬────────────┐
     ▼           ▼           ▼            ▼
  F1 🔴       F2 🟢       F3 🔵        F4 🟣
  Direct      Hub Prépa   Hub Après    Catalogue
  sticky+     checklist   stats→publ.  Admin
  Studio+     + CTA       + faits +    (outils
  latéral     notifs/TV   publication  groupés)
                 │
                 ▼ (en parallèle des hubs, outils)
           Matchs 3 pièces · Diffusion intents ·
           Modération queue-first · Membres · …
```

| Livraison | Flux | Change d’organisation | Risque |
|-----------|------|----------------------|--------|
| **F0** Direct single-view (prototype → sticky + Pilotage/Studio) | 🔴 | Oui — structure écran | Élevé |
| **F0bis** Pilotage cockpit (pont 4 flux) | pont | Oui — fold | Faible–Moyen |
| **Accès statisticien** | — | Oui — porte d’entrée | Faible |
| **F1** Direct complet (latéral, raccourcis, split stats, push/modo) | 🔴 | Oui | Élevé |
| **F2** Hub Prépa (checklist → Matchs/Direct/Diffusion/TV) | 🟢 | Oui — hub | Moyen |
| **F3** Hub Après (stats publier + faits + pub) | 🔵 | Oui — hub | Moyen–Élevé |
| **F4** Catalogue Admin (groupement jobs) | 🟣 | Oui — nav outils | Variable |
| Outils (Matchs 3 pièces, Diffusion intents, …) | cross | Oui, au service des hubs | Variable |

**Règle :** pas de F1 code sans GO sur la vision Direct / `ADMIN_WORKFLOWS` §4 (wireframe accepté). F0bis peut précéder F0 — **ne remplace pas** la single-view Direct.

---

## 9. Hors scope (jusqu’à GO UX / hors produit)

| Hors scope | Pourquoi |
|------------|----------|
| Polish-only (boutons, radius, headers sans nouveau layout) | Contre manifeste |
| Refactor callables / modèles métier / Feature First Admin complet | Après UX validée ; risque match-day |
| GoRouter Admin | Dette routing, pas gain organisation immédiat |
| Suppression / merge d’onglets registry | ADR-0005 |
| Remise Esti / World Cup | ADR-0002 |
| Nouvel Admin dark SaaS | Contre brief |
| Changement matrice permissions Firestore | Hors UX organisation |
| Redesign mobile bottom-nav 17 onglets | Web-first |

---

## 10. Critères de validation (organisation)

| Livraison | GO staff si… |
|-----------|----------------|
| IA flux (`ADMIN_WORKFLOWS`) | Tu valides Prépa / Direct / Après / Admin comme nav primaire ; tabs = outils |
| **F0 / F1 🔴 Direct** | Single-view : score/chrono/but/carton/stats/push/modo **sans quitter** ; sticky ; Studio sans perdre Pilotage ; RO statisticien OK |
| **F0bis Pilotage** | ≤2 clics vers flux / Direct/Stats/Rappel ; live visible fold ; KPIs accessibles |
| **F2 🟢 Prépa** | Checklist couvre fiche/live/notifs/TV ; deep-links outils OK |
| **F3 🔵 Après** | Parcours stats→publier + faits/MOTM/replay/pub ; pas de finalize accidentel |
| **F4 🟣 Admin** | CRM / staff / settings / TV / logs trouvables |
| Outils (Diffusion, Matchs, …) | Mapping features coché ; rappel &lt;30 s ; éditeur 3 pièces |

---

## 11. Question finale

**Valides-tu l’IA par flux** ([`ADMIN_WORKFLOWS.md`](./ADMIN_WORKFLOWS.md)) **et** les organisations cibles ci-dessous (pas un plan « composants ») ?

**Par quel flux commence-t-on le prototype ?**

### Recommandation Lead produit / UX

**Flux #1 : 🔴 Match en direct — single view** — sticky + Pilotage/Studio + latéral. C’est là que le staff perd du temps et prend des risques sous stress.

**Alternatif (GO plus sûr) : Pilotage cockpit** — pont vers les 4 flux ; puis enchaîner 🔴.

Design system / harmonisation formulaires : **pas** le démarrage.

---

## Références fichiers

| Zone | Fichiers clés |
|------|----------------|
| Shell / nav | `admin_shell.dart`, `admin_sidebar.dart`, `admin_tab_registry.dart`, `admin_nav_model.dart` |
| Pilotage | `dashboard_tab.dart`, `dashboard_match_day_card.dart` |
| Direct | `direct_tab.dart`, `direct_live_salon_panel.dart`, `live_match_quick_panel.dart` |
| Matchs | `matchs_tab.dart`, `match_editor.dart`, `admin_match_quick_actions.dart` |
| Stats | `stats_tab.dart`, `match_stats_workbench_screen.dart`, `match_stats_editor.dart`, `stats_publication_controls.dart` |
| Diffusion | `diffusion_tab.dart`, `notifs_tab.dart`, `match_reminder_tab.dart` |
| Accès | `docs/admin_access.md`, `ADMIN_STATUS.md` |

---

*Document produit / UX — docs only. Aucun code applicatif modifié dans ce chantier.*
