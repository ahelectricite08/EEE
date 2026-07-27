# Top ligues — masquer les codes d’invitation

## Problème

Dans **Top ligues**, le sous-titre de chaque rang affichait `code XXXX` pour **toutes** les ligues. Un utilisateur pouvait copier le code d’une ligue adverse et la rejoindre sans invitation.

## Règle produit

| Surface | Code invitation |
|---------|-----------------|
| **Top ligues** (liste publique) | **Jamais** |
| **Mes ligues** / détail (membre ou owner) | Visible |
| Snackbar création / champ « rejoindre par code » | Inchangé |
| Admin communauté | Inchangé (modération) |

## Correctifs client

| Fichier | Changement |
|---------|------------|
| `lib/services/prono_social_service.dart` | `TopLeagueRow` **sans** champ `code` ; le stream Top ligues ne mappe plus `data['code']` |
| `lib/screens/prono/prono_social_pages.dart` | Subtitle Top ligues : membres + « ta ligue » uniquement ; détail ligue : code seulement si membre/owner |

Rejoindre via saisie manuelle (`joinLeague` + query `where('code'…)`) et création / partage owner : **inchangés**.

## Firestore rules — non restreint (volontaire)

`private_leagues` :

```
allow read: if isAuth();
```

Tout user authentifié lit le document **entier**, y compris `code`. Firestore n’a pas de sécurité au niveau champ.

**Pourquoi ne pas restreindre la lecture aux membres maintenant :**

1. `joinLeague` côté client query `where('code', isEqualTo: …)` — un non-membre doit pouvoir résoudre le code.
2. Top ligues lit la collection pour le classement (nom, membres, `rankingStats`).

Restreindre `allow read` aux `memberIds` casserait rejoindre-par-code et le classement, sauf migration (ex. callable Admin SDK pour join + projection sans `code` pour le top).

**État actuel :** masquage UI + strip dans le modèle Top ligues. Le snapshot Firestore brut contient encore `code` en mémoire client — mitigation produit, pas crypto.

**Suite possible (hors scope) :** callable `joinPrivateLeagueByCode` + lecture membre-only, ou sous-collection `invite` lisible seulement par membres + CF pour join.

## Retest

1. Pronos → Social → **Top ligues** : aucune ligne ne montre de code (même « ta ligue »).
2. **Mes ligues** : le code de *ta* ligue reste visible ; détail aussi.
3. Créer une ligue → snackbar avec code OK.
4. Rejoindre avec un code saisi manuellement → OK.
5. Ouvrir le détail d’une ligue dont tu es membre → code visible.
