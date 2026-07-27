# Admin Polish — DONE

**Date :** 2026-07-26  
**Statut :** **DONE** — polish UI shell / hubs / sticky Direct + deploy hosting  
**Cadre :** ADR-0004 (in-place) · feedback user « trop ChatGPT »  
**Parent :** [`ADMIN_WORKFLOWS_PHASE1_DONE.md`](./ADMIN_WORKFLOWS_PHASE1_DONE.md)

---

## Objectif

Refondre **uniquement le chrome visuel** (navigation flux, hubs Prépa/Après/Admin, sticky Direct) sans changer l’IA des 4 flux, permissions, routes ni onglets.

---

## Changements visuels

| Zone | Avant (slop) | Après (régie) |
|------|--------------|---------------|
| Sidebar | Pastilles colorées, gradient or, glow, carte « univers » | Titre `DVCR ADMIN`, barre gauche sélection, vert club / rouge LIVE |
| Hubs | Cartes accent multi-couleurs + header module | Titre typo + liste rows sobres (bordure unique) |
| Mobile bar | Pastilles colorées 66 px | Indicateur haut 2 px, hauteur 56 |
| Sticky Direct | Chips arrondies, elevation/glow, stack vertical | Cockpit compact : score + START/STOP, liens texte, segment Pilotage/Studio |
| Top bar | Pill univers colorée | Titre seul + search |
| Sheet Outils | Wrap de chips or | Liste `ListTile` |

**Palette flux :** Prépa / Après / Admin → `adminGreen` ; Direct → `adminRed`. Plus de cyan / violet / pastilles rainbow.

---

## Conservé (inchangé)

- 4 flux conceptuels + shortcuts hub
- Permissions / RBAC
- 17 onglets « Tous les outils »
- Deep-links `#/admin/<segment>`
- Pilotage / Studio Direct (comportement métier)
- Esti / WC hors scope

---

## Fichiers touchés

| Fichier | Rôle |
|---------|------|
| `workflows/admin_workflow_hub.dart` | Hub listes sobres |
| `workflows/admin_sidebar_workflow_nav.dart` | Nav flux densifiée |
| `workflows/admin_mobile_workflow_bar.dart` | Bottom bar compacte |
| `workflows/admin_workflow_model.dart` | Couleurs accent (IA intacte) |
| `tabs/direct/direct_sticky_actions.dart` | Sticky cockpit |
| `admin_shell.dart` | Shell allégé |
| `admin_sidebar.dart` | Header / chrome |
| `admin_lazy_tab_stack.dart` | Extract (anti god-file) |
| `admin_content_top_bar.dart` | Extract top bar + sheet outils |

Tous les fichiers polish **≤ 300 L**.

---

## Vérifications

- `flutter analyze` périmètre polish : **0 issue**
- Smoke `admin_workflows_smoke_test.dart` : **4 PASS**
- `flutter build web --release` + `firebase deploy --only hosting`

---

## STOP

**Awaiting validation utilisateur** sur le look Admin (shell + hubs + sticky).
