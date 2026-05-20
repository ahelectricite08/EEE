# Spécification produit — Ligues privées & duels (prono club)

## Principes

- **Une seule vérité** : les scores prédits vivent dans `predictions` ; ligues et duels **agrègent** ces mêmes données (pas de second prono par contexte).
- **Ligues** (`private_leagues`) : code d’invitation, membres `memberIds`, admin `ownerUid`, recalcul de classement interne à partir des points résolus sur les matchs du scope (toute la saison club par défaut).
- **Duels** (`prono_duels`) : deux participants, un `matchId`, états `pending` → `in_progress` → `won` / `draw`, résolution à la fin du match (déjà géré côté Cloud Functions).
- **Anti-triche basique** : pronos fermés au coup d’envoi (côté client + règles métier match) ; pas de modification serveur des scores réels par les joueurs.

## Saisons de ligue (option)

- Champ optionnel `seasonEndsAt` ou `scopeCompetition` sur la ligue pour limiter le classement à une compétition ou une fenêtre temporelle.
- Historique : sous-collection `private_leagues/{id}/season_snapshots` ou archive en fin de période (v2).

## Notifications & deep links

- Type `duel` : ouvrir l’**Arène** ([`PronoArenaScreen`](../lib/screens/prono/prono_arena_screen.dart)) puis accès duels.
- Futur : `league_invite` avec `leagueId` + code → même onglet Arène.

## Modération

- Exclusion membre réservée au **owner** (à renforcer côté règles Firestore si besoin).
- Signalement utilisateur via flux `reports` existant.
