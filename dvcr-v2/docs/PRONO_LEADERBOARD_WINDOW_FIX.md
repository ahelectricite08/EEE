# Prono — Classement : top 20 + fenêtre autour de moi

## Problème

Le classement global chargeait un **top 50** Firestore et n’affichait la « zone » utilisateur que s’il était **dans ces 50**.

Conséquences produit :
- Copy trompeuse (« Top 50 mis à jour… ») alors que la logique réelle était partielle.
- Un joueur **hors top 50** ne voyait **pas sa place** (dernier inclus).
- Confusion entre « top 50 » et « top 20 / ta zone ».

## Comportement final

### Classement global (`PronoLeaderboardPage`)

1. **Toujours** afficher le **top 20** (ou moins s’il y a moins de joueurs).
2. Afficher clairement **« Tu es Xe sur N »** dès qu’une entrée `prono_leaderboard/{uid}` existe.
3. Si l’utilisateur est **hors top 20** : séparateur `…` puis **voisins** (rang−1 · moi · rang+1), avec bords :
   - juste après le top (ex. 21e) → pas de doublon du 20e déjà listé ;
   - dernier → pas de rang+1 ;
   - 1er / 2e → uniquement dans le top (pas de 2ᵉ zone).
4. Copy : plus de mention « top 50 ».

### Ligues privées (`PronoLeagueDetailPage`)

Même **règle d’affichage** (slice client) :
- ≤ 20 membres → liste complète ;
- \> 20 → top 20 + `…` + voisins autour de moi.

Les ligues restent chargées via `leagueLeaderboardFiltered` (membres déjà connus, dataset petit).

## Perf (global)

Ne charge **pas** tout le peloton :

| Requête | Rôle |
|--------|------|
| `orderBy(points desc).limit(20)` (stream) | Top 20 live |
| `prono_leaderboard.count()` | Total N |
| `doc(uid)` | Entrée user |
| `where(points > mine).count()` | Rang compétition |
| `where(points > mine).orderBy(points).limit(1)` | Voisin au-dessus |
| `where(points < mine).orderBy(points desc).limit(1)` | Voisin en-dessous |

Logique pure testable : `lib/features/prono/domain/leaderboard_window.dart`.

## Fichiers

| Fichier | Rôle |
|---------|------|
| `lib/features/prono/domain/leaderboard_window.dart` | Plan / slice fenêtre |
| `lib/services/prono_social_service.dart` | `watchGlobalLeaderboardWindow` |
| `lib/screens/prono/prono_social_pages.dart` | UI global + ligue |
| `lib/features/prono/presentation/progress/prono_progress_page.dart` | CTA sans « top 50 » |
| `test/features/prono/leaderboard_window_test.dart` | Unit tests |

## Retest manuel

1. **Top 20** : compte avec rang ≤ 20 → voir top, ligne « Tu es Xe sur N », pas de `…`.
2. **Hors top** : compte avec rang ≫ 20 → top 20, `…`, puis rang−1 / moi / rang+1.
3. **Dernier** : voisins = rang−1 + moi seulement.
4. **Sans prono** : message d’incitation, pas de rang.
5. **Ligue privée** avec \> 20 membres (si dispo) : même pattern ; petite ligue : liste complète.
6. **Progression** → bouton « Classement global » (sans « top 50 »).
7. Après un match scoré : top / rang se mettent à jour (stream top 20).
