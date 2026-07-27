# Admin Module Colors — DONE

**Date :** 2026-07-26  
**Statut :** **DONE** — code couleur par module + anti-GPT headers/listes  
**Cadre :** ADR-0004 (in-place) · feedback user « moins ChatGPT partout » + code couleur  
**Parent :** [`ADMIN_POLISH_DONE.md`](./ADMIN_POLISH_DONE.md)

---

## Objectif

Donner un **vrai code couleur par flux / onglet** dans l’Admin, et aligner les écrans visibles (à commencer par **Matchs**) sur le look régie des hubs — sans toucher au métier (listes, actions, editors).

---

## Code couleur

| Flux / zone | Accent | Hex | Onglets |
|-------------|--------|-----|---------|
| 🟢 Préparation | Vert club | `#0E5A43` | Matchs, Équipes, Notifs/Diffusion, Actus |
| 🔴 Direct | Rouge LIVE | `#BA203C` | Direct |
| 🔵 Après-match | Bleu | `#2F5F9E` | Stats |
| 🟣 Administration | Violet-gris | `#5E5478` | Membres, Staff, Settings, Logs, TV, XP |
| Jeux | Ambre | `#B0892E` | Pronos |
| Communauté | Vert-teal | `#2F7A6B` | Chat, Bénévoles, Adhérents |
| Pilotage | Ardoise | `#4A5568` | Dashboard |

Source unique : `lib/screens/admin/admin_module_colors.dart` (`forTab` / constantes flux).  
Les 4 flux (`AdminWorkflowDef.color`) consomment ces tokens.

---

## Anti-GPT (chrome)

| Avant | Après |
|-------|--------|
| Header module = carte crème + icône gradient | Barre d’accent 3 px + typo uppercase + icône inline |
| Filtres Matchs avec icônes décoratives | Chips texte densifiés, accent module |
| Cartes Matchs lourdes (chip compétition or, VS décoratif) | Ligne compacte, bordure gauche statut, méta en texte |
| Flux sidebar tous verts sauf LIVE | Chaque flux / outil porte sa couleur |

**Inchangé métier :** queries Matchs, dédup, filtres, editor, quick actions, permissions, 4 flux conceptuels.

---

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `admin_module_colors.dart` | Tokens + `forTab` |
| `admin_module_shell.dart` | Header / sections allégés |
| `admin_segmented_control.dart` | Filtres segmentés |
| `tabs/matchs/matchs_tab.dart` | Header + chips Prep |
| `tabs/matchs/matchs_list_tile.dart` | Liste densifiée |
| `tabs/matchs/matchs_replay_sheet.dart` | Sheet replay extrait |
| `workflows/*` | Couleurs flux sidebar / mobile / hub |
| Headers tabs | Dashboard, Stats, Notifs, Users, Actus, Stades, Logs, TV, Pronos, Staff, XP, Communauté… |

---

## Vérifications

- `flutter analyze` (périmètre admin couleurs / Matchs) : OK  
- Smoke `admin_workflows_smoke_test.dart` : OK  
- `flutter build web --release` + `firebase deploy --only hosting`

---

## Live

https://drapeau-vert-app.web.app/

---

## STOP

**Awaiting validation utilisateur** — Matchs + code couleur modules.
