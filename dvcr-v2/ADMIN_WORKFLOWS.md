# Admin par flux de travail — architecture informationnelle

**Date :** 2026-07-26  
**Statut :** Proposition produit — **Phase 1 code livrée** (voir [`modules/ADMIN_WORKFLOWS_PHASE1_DONE.md`](./modules/ADMIN_WORKFLOWS_PHASE1_DONE.md)) — **attente GO Phase 2**  
**Périmètre :** Admin vivant (`lib/screens/admin/**`) — réorganisation IA, **pas** nouvel Admin  
**Cadre :** ADR-0004, ADR-0005, ADR-0002  
**Liés :** [`ADMIN_UX_ROADMAP.md`](./ADMIN_UX_ROADMAP.md) · [`ADMIN_UX_SUMMARY.md`](./ADMIN_UX_SUMMARY.md) · [`ADMIN_UX_MODULE_VISIONS.md`](./ADMIN_UX_MODULE_VISIONS.md) · [`ADMIN_STATUS.md`](./ADMIN_STATUS.md)  
**Note :** la section docs-only initiale est conservée ; l’implémentation Phase 1 est dans `lib/screens/admin/workflows/**` + cockpit Direct.

---

## 1. Manifeste

La navigation primaire de l’Admin n’est **pas** une liste plate de 17 onglets métier.

| Aujourd’hui | Cible |
|-------------|--------|
| 6 univers sidebar × ~17 tabs (Pilotage, Match Day, Contenu…) | **4 flux** : Préparation → Direct → Après-match → Administration |
| Staff choisit un *outil* (Matchs, Stats, Notifs…) | Staff choisit une *phase* du match (ou Admin hors match) |
| Job match-day éclaté sur Direct + Matchs + Stats + Diffusion | Job rassemblé **dans le flux** ; les tabs restent des **outils** (deep-link / hub) |

**Règle :** rien n’est perdu. Les 17 onglets registry (`admin_tab_registry.dart`, indices `AdminTabIndex` stables, RBAC, deep-links `#/admin/<segment>`) restent la **couche outils**. Les 4 flux sont la **couche jobs** — réorganisation informationnelle, pas suppression de capacités.

**Anti-timidité :** conserver les features ≠ conserver le placement. Un onglet peut devenir panneau, drawer, ou destination secondaire d’un hub de flux.

---

## 2. Les 4 flux (navigation primaire)

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ 🟢 PRÉPA     │ 🔴 DIRECT    │ 🔵 APRÈS     │ 🟣 ADMIN     │
│ Match bientôt│ Live / J0    │ Post-sifflet │ Hors match   │
└──────────────┴──────────────┴──────────────┴──────────────┘
         ↑ sticky contexte match (si match sélectionné) ↑
```

| Flux | Moment | Promesse |
|------|--------|----------|
| 🟢 **Préparation du match** | J−N → coup d’envoi − ε | Tout préparer sans zapping 5 onglets |
| 🔴 **Match en direct** | Live ON | **Une seule vue** : score, chrono, faits, stats, push, modération |
| 🔵 **Après-match** | FIN → publication | Finaliser, publier, classer — parcours guidé |
| 🟣 **Administration** | Hors urgence match | Utilisateurs, staff, paramètres, TV, journaux |

**Contexte match (bandeau global, optionnel) :** quand un match CSSA est « actif » (prochain / live / à finaliser), un sticky bar affiche adversaire · date · statut · CTA vers le flux pertinent. Hors contexte → 🟣 Admin ou hub Prépa « choisir un match ».

---

## 3. 🟢 Préparation du match

### Jobs
1. Vérifier / corriger équipes, logos, stade, calendrier, statut.
2. Préparer compositions / bandeau (données live-ready).
3. Programmer le live (match lié, URL stream, domicile/extérieur).
4. Préparer notifications (rappel match, push J0 préremplis).
5. Préparer graphismes / antenne (TV featured, next live, visuels émission si besoin).

### Actions ≈ 95 %
1. Ouvrir / corriger **fiche match**  
2. Vérifier **équipes & stade**  
3. **Programmer live** (lien match + URL)  
4. **Préparer rappel** (aperçu, pas forcément envoi)  
5. Check **TV / featured** si antenne du jour  

### Layout cible (hub Prépa)
```
┌─ Match sélectionné (ou « Prochain CSSA ») ─────────────────┐
│ Checklist : Fiche ✓ · Compos · Live prêt · Rappel · TV     │
├─────────────┬─────────────┬─────────────┬──────────────────┤
│ Fiche       │ Live setup  │ Notifs      │ Graphismes / TV  │
│ (éditeur    │ (dialog /   │ (rappel +   │ (featured, HLS,  │
│  pièce 1)   │  extrait    │  push J0)   │  next live)      │
│             │  Direct)    │             │                  │
└─────────────┴─────────────┴─────────────┴──────────────────┘
│ Outils : [Matchs] [Équipes&stades] [Direct] [Diffusion] [TV]
```

Pas une nouvelle app : **checklist + panneaux** qui embarquent ou deep-linkent vers les surfaces existantes.

### Mapping → existant (rien perdu)

| Job Prépa | Surface actuelle | Fichiers d’ancrage |
|-----------|------------------|--------------------|
| Équipes, calendrier, statut | Matchs → `MatchEditor` (sections équipes / calendrier) | `matchs_tab.dart`, `match_editor.dart` |
| Logos / stade référentiel | Équipes & stades | `stades_tab.dart` |
| Compositions / bandeau live | Direct (bandeau stats / compos) + éditeur faits | `direct_tab.dart`, `live_match_quick_panel.dart` |
| Programmer le live | Direct : toggle + dialog démarrage (URL, match) | `direct_tab.dart` |
| Rappel / push J0 | Diffusion = Push + Rappel | `diffusion_tab.dart`, `notifs_tab.dart`, `match_reminder_tab.dart` |
| Graphismes TV | Android TV | `tv_admin_tab.dart` |
| Orientation « match du jour » | Pilotage (carte match-day **non branchée**) | `dashboard_tab.dart`, `dashboard_match_day_card.dart` |
| Actu pré-match (option) | Actus + pont Diffusion | `articles_tab.dart` |

---

## 4. 🔴 Match en direct — **single view** (flux critique)

### Jobs
1. Piloter score, chrono, buts, cartons **sans perdre la main**.
2. Sync / saisir stats sans quitter le cockpit.
3. Push live / alerte en 1–2 clics (prérempli).
4. Surveiller salon + signalements (modération légère).
5. Studio (émission / sondage) quand pertinent — **autre mode**, pas sous le fold du score.

### Actions ≈ 95 % (pic live)
1. But / score  
2. Chrono (0′ / 45′ / MT / 2e / FIN)  
3. Cartons J / R  
4. Start / Stop live  
5. Stats sync / ouvrir saisie **dans la vue**  

→ Salon, émission, sondage, votes/MOTM = **secondaires** pendant le pic (mode Studio / drawer).

### Layout cible — **tout dans une seule vue**
```
┌──────────────────────────────────── STICKY HOT ─────────────────────────────────┐
│ LIVE ON · Score 1-0 · 67′ · [BUT] [J] [R] [MT] [FIN] · [Stop] · [Push live]    │
├──────────────────────────────────────────────┬──────────────────────────────────┤
│ ZONE PRINCIPALE                              │ LATÉRAL (collapsible)            │
│                                              │ Match · URL · Compos · Bandeau   │
│ Mode PILOTAGE (défaut)                       │ Stats : compteurs / sync / split │
│   Faits récents · corrections · feed buts    │ Votes / MOTM (drawer)            │
│                                              │ Signalements (compteur → queue)  │
│ Mode STUDIO (toggle)                         ├──────────────────────────────────┤
│   Salon live · Émission · Sondage            │ Même session — pas de nav plein  │
│                                              │ écran obligatoire vers Stats     │
└──────────────────────────────────────────────┴──────────────────────────────────┘
```

**Exigence produit :** sticky + latéral + modes = **une vue**. Sortie vers `StatsTab` / workbench = secours (outil), pas le chemin nominal.

**Modes Pilotage vs Studio**
| | Pilotage | Studio |
|--|----------|--------|
| Qui | CM / ops score | Animateur / community |
| Focus | Score, chrono, faits, stats | Salon, émission, sondage |
| Sticky hot | **Toujours visible** | **Toujours visible** (ne jamais perdre le score) |

**Raccourcis (web)** : but domicile/extérieur, pause chrono, MT, carton — documentés + focus. Sticky bar = accélérateur tactile.

### Mapping → existant

| Capacité Direct actuelle | Où dans la single-view |
|--------------------------|------------------------|
| Toggle MATCH EN DIRECT + dialog | Sticky / header |
| `LiveMatchQuickPilotageBody` (score, chrono, buts, cartons) | Sticky + zone Pilotage |
| STATS EN DIRECT / compositions | Latéral |
| « Saisir les statistiques » → workbench | Latéral / split (mêmes features) |
| MOTM + notes | Drawer / latéral Votes |
| `DirectLiveSalonPanel` | Mode Studio |
| Émission DVCR + sondage | Mode Studio |
| RO statisticien (`isDirectReadOnly`) | Même layout ; hot désactivés + badge |
| Push live | CTA sticky → Diffusion préremplie (outil) |
| Modération | Compteur → Chat & modération (panneau ou deep-link) |

**Ancrage code :** `direct_tab.dart` (~3.1k L, `ListView` unique), `direct_live_salon_panel.dart`, `live_match_quick_panel.dart`, workbench stats (`match_stats_workbench_screen.dart`).

---

## 5. 🔵 Après-match

### Jobs
1. Finaliser stats (carte → sync → officiel / verrouiller).
2. MOTM / notes / faits post-match (buteurs, cartons, remplacements).
3. Replay + résumé / actu.
4. Classements / averages saison si besoin.
5. Publication & diffusion post-match (push résultat, actu).

### Actions ≈ 95 %
1. **Finaliser stats** (parcours Publier)  
2. Compléter **faits & MOTM** (éditeur pièce post-match)  
3. **Replay**  
4. **Push / actu résultat**  
5. Check **classement / hub archive**  

### Layout cible (hub Après)
```
┌─ Match terminé ────────────────────────────────────────────┐
│ Checklist : Stats ✓ · Faits/MOTM · Replay · Publié · Push │
├──────────────────┬──────────────────┬──────────────────────┤
│ Stats            │ Fiche post-match │ Publication         │
│ (saisie→publier) │ (éditeur pièce 2) │ Actu + Diffusion    │
└──────────────────┴──────────────────┴──────────────────────┘
│ Outils : [Stats] [Matchs] [Actus] [Diffusion] [Pronos…]
```

### Mapping → existant

| Job Après | Surface actuelle |
|-----------|------------------|
| Stats finalisation | Stats hub EN DIRECT → workbench publication (`stats_publication_controls`, états Officiel/Carte/Verrouillé) |
| Faits, MOTM, replay, import live | Match editor « Faits & post-match » |
| Résumé / une | Actus |
| Push résultat | Diffusion (intent push match) |
| Classements / comparer / averages | Stats ARCHIVE / COMPARER ; XP classement (secondaire) |
| Pronos post-journée | Pronos & jeux (suivi, pas chemin chaud) |

---

## 6. 🟣 Administration

### Jobs
- Utilisateurs / rôles / XP / paiements  
- Staff & permissions / badges  
- Paramètres (maintenance, saison FFF, home, support)  
- TV (hors checklist Prépa)  
- Journaux / audit  
- Communauté structurelle, bénévoles, adhérents, pronos ops saison  

### Layout cible
**Catalogue d’outils** regroupé par job (proche des univers actuels), pas un 5ᵉ faux « match-day ».

| Zone Admin | Onglets outils |
|------------|----------------|
| Personnes | Membres, Staff, Bénévoles, Adhérents |
| Contenu & jeux | Actus, Pronos, XP |
| Système | Réglages, TV, Journal |
| Modération structurelle | Chat & modération (config salons — queue urgente aussi joignable depuis Direct) |

Pilotage (Dashboard) hors match-day = **entrée 🟣** (health, KPIs) ; en match-day = **pont** vers 🟢/🔴/🔵 (cockpit 30 s).

---

## 7. Cohabitation avec les 17 tabs (transition)

Les indices, permissions et deep-links **ne bougent pas** (U7 roadmap). Trois couches :

| Couche | Rôle | Exemple |
|--------|------|---------|
| **A. Flux (nouvelle IA)** | Nav primaire : Prépa / Direct / Après / Admin | Sidebar ou top rail « phases » |
| **B. Hub de flux** | Checklist + panneaux / embeds | Hub 🔴 = single-view Direct |
| **C. Tabs legacy** | Outils complets, toujours joignables | « Ouvrir dans Matchs » → `#/admin/matchs` |

### Modes de transition (progressifs)

1. **Phase T0 — Docs + prototype** : flux documentés ; UI inchangée.  
2. **Phase T1 — Hub overlay** : rail « 4 flux » au-dessus de la sidebar actuelle ; chaque flux ouvre un hub qui **deep-link** vers tabs. Staff habitué garde la sidebar 17 tabs.  
3. **Phase T2 — Direct single-view** : flux 🔴 = nouvelle orga *dans* `DirectTab` (sticky, Pilotage/Studio) — premier vrai changement d’écran.  
4. **Phase T3 — Hubs Prépa / Après** : checklist + panneaux ; tabs restent secours.  
5. **Phase T4 — Sidebar secondaire** : univers 6 groupes → « Outils » replié ; flux = défaut. Tabs jamais supprimés sans GO ADR-0005.

**Toggle « Mode classique »** (recommandé T1–T3) : masque le rail flux, sidebar 17 tabs seule — filet pour staff habitué.

---

## 8. Raccourcis, sticky, Pilotage vs Studio

| Mécanisme | Où | Rôle |
|-----------|-----|------|
| Sticky hot bar | 🔴 Direct | Score/chrono/faits toujours visibles |
| Sticky contexte match | Global (option) | CTA phase selon statut live/prépa/après |
| Mode Pilotage / Studio | 🔴 Direct | Séparer CM vs animateur sans perdre le sticky |
| Raccourcis clavier | Web Direct | Accélérer les 5 actions 95 % |
| CTA préremplis | Prépa / Direct / Après → Diffusion | Rappel & push sans formulaire géant |
| Split stats | Direct latéral | Évite nav pleine page workbench |

Design system Admin (`admin_palette`, `AdminField`, cards) = **outil d’implémentation**, pas navigation primaire.

---

## 9. Matrice Feature actuelle → Flux

| Feature / onglet actuel | Flux primaire | Flux secondaire |
|-------------------------|---------------|-----------------|
| Pilotage (`DashboardTab`) | Pont 🟢/🔴/🔵 (cockpit) | 🟣 hors match |
| Direct | 🔴 | 🟢 (setup live) |
| Matchs + éditeur | 🟢 (identité) · 🔵 (faits/replay) | 🔴 (liens ops) |
| Statistiques match | 🔴 (saisie live) · 🔵 (finaliser) | — |
| Notifications / Diffusion | 🟢 (préparer) · 🔴 (push live) · 🔵 (résultat) | 🟣 |
| Équipes & stades | 🟢 | 🟣 |
| Actus | 🔵 (résumé) | 🟢 · 🟣 |
| Android TV | 🟢 (J0) | 🟣 |
| Chat & modération | 🔴 (signalements) | 🟣 (config) |
| Membres | 🟣 | — |
| Bénévoles | 🟣 | 🟢 (planning J0, rare) |
| Adhérents | 🟣 | — |
| Pronos & jeux | 🟣 | 🔵 (post-journée) |
| XP & Niveaux | 🟣 | 🔵 (classement, rare) |
| Réglages | 🟣 | — |
| Journal | 🟣 | audit cross-flux |
| Staff & permissions | 🟣 | — |

---

## 10. Risques & migration UX progressive

| Risque | Mitigation |
|--------|------------|
| Staff habitué aux 17 onglets | Mode classique ; deep-links inchangés ; formation 1 page « où ça vit » |
| Perte de feature perçue | Matrice §9 + mapping par hub ; audit checklist avant chaque GO |
| Stress live sur refonte Direct | Prototype wireframe → GO → PR organisationnelles petites ; RO statisticien testé |
| Deux mental models (flux vs tabs) | T1 : flux = raccourcis ; tabs = vérité ; T4 seulement après adoption |
| Dashboard match-day orphelin | Brancher cockpit comme **pont de flux**, pas KPI vanity |

Ordre migration UX (aligné roadmap) : **🔴 Direct single-view → 🟢 Prépa hub → 🔵 Après hub → 🟣 catalogue Admin** ; Pilotage cockpit peut précéder 🔴 comme quick-win de *pont*.

---

## 11. Critères de validation

| Critère | GO si… |
|---------|--------|
| IA par flux | Staff désigne Prépa / Direct / Après / Admin comme entrée ; tabs = outils |
| 🔴 Single-view | Score/chrono/but/carton/stats/push/modo joignables **sans quitter** la vue ; Studio sans perdre sticky |
| Features | Matrice §9 cochée ; aucun `AdminTabIndex` retiré |
| Transition | Mode classique + `#/admin/...` fonctionnels |
| Prépa / Après | Checklist couvre jobs ; deep-link outils OK |
| 🟣 Admin | CRM / RBAC / settings / TV / logs toujours trouvables |
| Perf cognitive | Jour de match : ≤2 clics du cockpit vers action chaude |

---

## 12. Question — validation

**Valides-tu cette architecture informationnelle par flux (🟢 Prépa · 🔴 Direct single-view · 🔵 Après · 🟣 Admin) ?**

Les 17 onglets restent la couche outils pendant toute la transition.

### Recommandation prototype #1

**🔴 Match en direct — single view** (sticky + Pilotage / Studio + latéral stats).

C’est le seul flux où le coût du scroll et des sorties d’écran est critique sous stress. Les visions module Direct existantes (`ADMIN_UX_ROADMAP` §5.2, `ADMIN_UX_MODULE_VISIONS`) **s’alignent** sur ce flux.

**Alternatives :**  
- Pilotage cockpit 30 s (pont vers les 4 flux) — GO plus sûr, ne remplace pas 🔴.  
- Hub 🟢 Prépa — utile, moins urgent que le live.

---

## Références code (ancrage, pas implémentation)

| Zone | Fichiers |
|------|----------|
| Registry / nav | `admin_tab_registry.dart`, `admin_nav_model.dart`, `admin_sidebar.dart`, `admin_shell.dart` |
| Direct | `direct_tab.dart`, `direct_live_salon_panel.dart`, `live_match_quick_panel.dart` |
| Matchs | `matchs_tab.dart`, `match_editor.dart`, `admin_match_quick_actions.dart` |
| Stats | `stats_tab.dart`, `match_stats_workbench_screen.dart`, `stats_publication_controls.dart` |
| Diffusion | `diffusion_tab.dart`, `notifs_tab.dart`, `match_reminder_tab.dart` |
| Pilotage / TV | `dashboard_tab.dart`, `dashboard_match_day_card.dart`, `tv_admin_tab.dart` |

---

*Document produit / UX — docs only. Aucun code applicatif modifié.*
