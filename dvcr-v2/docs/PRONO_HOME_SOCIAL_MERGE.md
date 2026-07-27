# Prono Accueil ↔ Social (multijoueur) — merge

**Date :** 2026-07-27  
**Scope :** shell Prono uniquement (pas de rewrite métier).

## Décision

L’onglet **Social** est fusionné dans **Accueil** : le contenu multijoueur / classements est le corps principal de l’Accueil (après hero + matchs). L’onglet Social disparaît de la barre interne Prono. Les raccourcis Accueil (Classement / Progression) ont été retirés — Progression reste via l’onglet dédié ; Classement via le hub Multijoueur.

## Layout Accueil (après)

1. Hero Accueil + stats XP  
2. CTA « Voir les matchs »  
3. Prochains matchs  
4. **Multijoueur** (ligues, duels, amis) + **Classements** (global, top ligues) — via `PronoSocialHubBody` (`showTip: false` — pas d’encart « Communauté »)

## Tabs Prono restants

| Index | Label        |
|------:|--------------|
| 0     | Accueil      |
| 1     | Matchs       |
| 2     | Progression  |

## Fichiers clés

- `lib/features/prono/presentation/home/prono_home_page.dart` — embed Social après prochains matchs  
- `lib/features/prono/presentation/social/prono_social_hub_page.dart` — `PronoSocialHubBody` réutilisable (+ page standalone conservée)  
- `lib/features/prono/presentation/shell/prono_root_shell.dart` — 3 tabs ; Progression « Communauté » → Accueil  
- `lib/features/prono/presentation/theme/prono_theme.dart` — `forTabIndex` sans index Social

## Navigation préservée

Les tuiles Multijoueur / Classements poussent les mêmes écrans qu’avant (`PronoLeaguesPage`, `PronoDuelsPage`, `PronoFriendsPage`, `PronoLeaderboardPage`, `PronoTopLeaguesPage`) via le navigator nested Prono. CTA « Voir les matchs » → onglet Matchs. Progression via l’onglet Progression.

## Non-objectifs

- Pas de duplication des widgets Social  
- Empty states / permissions inchangés  
- Pas de second hero « Communauté » sur Accueil (évite double header)  
- Pas d’encart tip « Communauté » sur Accueil (`showTip: false`) — Multijoueur/Classements restent
