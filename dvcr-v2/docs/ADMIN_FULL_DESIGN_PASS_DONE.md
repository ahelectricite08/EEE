# Admin — Full Design Pass DONE

**Date :** 2026-07-26  
**Statut :** **DONE** (pass 2 + Pilotage refonte) — awaiting validation utilisateur  
**Cadre :** ADR-0004 (in-place) · suite de [`ADMIN_POLISH_DONE.md`](../modules/ADMIN_POLISH_DONE.md)  
**Deploy :** https://drapeau-vert-app.web.app/

---

## Objectif

Achever / étendre la **refonte visuelle** Admin au niveau hubs/shell : moins GPT (cartes crème empilées, gold gradient, pills), code couleur modules partout, métier inchangé.

---

## Pass 1 (précédent)

### Composants / tokens

| Élément | Fichier | Notes |
|---------|---------|--------|
| `AdminPageHeader` / `AdminSection` | `admin_module_shell.dart` | typedefs → `AdminModuleHeader` / `AdminModuleSection` |
| `AdminSegmented` | `admin_ui.dart` | typedef → `AdminSegmentedControl` |
| Barrel | `admin_ui.dart` | exports Field / PrimaryButton / colors / shell |
| `AdminField` | `admin_form_widgets.dart` | fill surface, focus accent module (défaut Prépa) |
| `AdminPrimaryButton` | `admin_components.dart` | solid, plus de gradient/glow |
| `AdminSectionHeader` | `admin_components.dart` | barre solide, icône simple |
| Shadows | `admin_palette.dart` | ombre unique discrète |

### Priorité 1–3 — Match editor, Direct sticky, Stats header, Settings, Notifs header

Voir historique pass 1.

---

## Pass 2 — chrome restant

### Composants partagés

| Élément | Changement |
|---------|------------|
| `AdminModuleSection` | wrapInCard → surface plate radius 8, **sans** carte crème ombrée |
| `AdminStatCard` / `AdminEmptyState` / `AdminMiniInfoCard` | plus de gradients |
| `AdminUsersHeroCard` | bandeau densifié (compteurs séparés par traits), **plus** de pills / carte crème |

### Écrans traités (chrome only)

| Écran | Statut |
|-------|--------|
| Direct — `_LiveCard`, votes, salon, poll wrapper | Densifié · accents `AdminModuleColors.live` |
| Stats workbench / Match Day Hero | Flat · `apresMatch` |
| Users / XP / Bénévoles / Stades / Articles / Communauté | Accents module · surfaces plates |
| Logs / Notifs / Pronos reset | Densifié |

---

## Pass 2b — Pilotage / Dashboard (anti-GPT)

**Feedback :** grosses cartes blanches (931 users…), bannière pause marketing, chip « Hors antenne » → look ChatGPT.

| Avant | Après |
|-------|--------|
| Grille de big-number cards crème | Lignes KPI densifiées (`DashboardKpiPanel`) |
| Santé = 3 mini-cartes dans une carte | Bandeau strip `SANTÉ` + lien Direct si live |
| Pause notifs = carte ambre arrondie | Alert bar plate (barre latérale + switch) |
| Pas de match-day | Bandeau `DashboardMatchDayCard` dense en tête |
| Pill « Hors antenne » | Point Live / Off discret |
| Accent gold / rainbow | `AdminModuleColors.pilotage` (ardoise) |

**Fichiers :** `dashboard_tab.dart`, `dashboard_kpi_panel.dart`, `dashboard_activity_lists.dart`, `dashboard_match_day_card.dart`, `admin_system_health_panel.dart`, `admin_system_maintenance_section.dart` (+ extras), `dashboard_matches_finished_by_season.dart`.  
**Métier / streams / counts :** inchangés.

---

## Restant (roadmap pass 3)

1. God-files Direct / Match editor / Match stats — extract ≤300 L sans toucher save  
2. Stats detail / compare — barres gold optionnelles → `apresMatch`  
3. Notifs / Settings panels / Benevole notifs — chrome résiduel  

---

## Conservé

- Firestore / permissions / RBAC / workflows  
- Sticky Direct · compteurs Pilotage  

---

## STOP

**Awaiting validation** prioritaire : **Pilotage** régie dense, puis reste pass 2 / GO pass 3.
