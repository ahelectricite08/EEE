# Fix — Top ligues vide (« aucune ligue »)

## Symptôme

Pronos → Social → **Top ligues** : liste vide alors qu’une ligue privée existe et que le créateur a déjà des points prono.

## Cause racine

1. L’écran lisait `private_leagues` avec  
   `orderBy('rankingStats.memberPointsSum', descending: true)`.
2. En Firestore, **un document sans le champ ordonné est exclu** du résultat.
3. `createLeague` n’écrivait **pas** `rankingStats`.
4. Ce champ n’était rempli que par le callable admin  
   `adminRecomputeLeaguePowerRankings` (manuel) ou un reset de saison — **jamais** à la création, au join, ni au scoring.

Résultat : ligue créée + scorée → toujours invisible dans Top ligues.

## Règle produit

- **Pas de seuil minimum de membres** : une ligue apparaît dès 1 membre.
- **Puissance** = somme des points `prono_leaderboard` des `memberIds`.
- Empty state : explique création / code d’invitation (pas un faux filtre « min 2 »).

## Correctifs

| Couche | Changement |
|--------|------------|
| Client `createLeague` | Initialise `rankingStats` avec les points owner |
| Client Top ligues | Query `orderBy(updatedAt)` + tri par puissance ; si `rankingStats` manquant, somme à la volée depuis `prono_leaderboard` |
| CF `syncPrivateLeagueRankingStats` | Écrit `rankingStats` à la création / changement de membres |
| CF `syncLeaguePowerOnLeaderboardWrite` | Recalcule les ligues du joueur quand ses points changent |
| CF `adminRecomputeLeaguePowerRankings` | Backfill manuel (FieldPath import corrigé) |

## Retest

1. Hot restart / build avec le client à jour.
2. Pronos → Social → **Top ligues** : la ligue existante doit apparaître avec ~3 pts (somme membres).
3. Créer une nouvelle ligue → elle apparaît tout de suite (même à 1 membre).
4. (Après deploy functions) Admin → maintenance → **Recalculer stats ligues** une fois pour backfill `rankingStats` en base.
5. Après un match scoré, les points Top ligues doivent suivre sans action admin.

## Deploy

```bash
firebase deploy --only "functions:syncPrivateLeagueRankingStats"
firebase deploy --only "functions:syncLeaguePowerOnLeaderboardWrite"
firebase deploy --only "functions:adminRecomputeLeaguePowerRankings"
```

Pas d’index composite nouveau (single-field `updatedAt` / `memberIds` array-contains).

Backfill one-shot (admin app) : **Recalculer stats ligues** → écrit `rankingStats` sur toutes les ligues existantes.
