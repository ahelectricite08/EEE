# Prono social — fix headers (ligue, duel, ami, classement)

**Date :** 2026-07-26  
**Symptôme :** headers cassés (titre/back écrasés, trop haut, overflow) sur les pages poussées depuis le hub Social.

## Navigation

Hub `PronoSocialHubPage` → `Navigator.push` (nav imbriquée Prono) → pages de `prono_social_pages.dart` :

- Ligues → `PronoLeaguesPage` / détail
- Duels → `PronoDuelsPage` / détail / pickers
- Amis → `PronoFriendsPage`
- Classement → `PronoLeaderboardPage`
- Top ligues → `PronoTopLeaguesPage`

Toutes passent par `_buildSocialPageAppBar` (sauf même helper pour le leaderboard).

## Cause

`_buildSocialPageAppBar` construit un `PreferredSize` qui :

1. ajoute déjà le safe-area haut (`SizedBox(height: MediaQuery.padding.top)`)
2. place un `AppBar` dans un `SizedBox` de hauteur fixe (`kToolbarHeight` + bordure)

L’`AppBar` gardait `primary: true` (défaut) → second `SafeArea` **à l’intérieur** de la boîte fixe → toolbar écrasée / layout buggué.

Sans lien métier avec le fix bottom padding de `prono_root_shell.dart` (onglets flottants).

## Correctif

`primary: false` sur l’`AppBar` imbriqué (safe-area déjà géré manuellement).

Fichier : `lib/screens/prono/prono_social_pages.dart`

## Vérifier

1. Pronos → Social  
2. Ouvrir Ligues / Duels / Amis / Classement / Top ligues  
3. Header : bandeau accent, back, titre + sous-titre lisibles, pas d’overflow  
4. Retour + barre d’onglets Prono intacte  
