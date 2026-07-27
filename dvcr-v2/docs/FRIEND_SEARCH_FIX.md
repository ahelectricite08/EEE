# Recherche d’amis — tous les inscrits (pseudo OU email)



**Date :** 2026-07-26 (v2 — searchable globale)  

**Attente produit :** Pronos → Social → Amis → recherche sur **tous les comptes inscrits**, par **pseudo/prénom** **ou** **email**.



## Comportement final



| Critère | Règle |

|---|---|

| Portée | Collection `users` (tous les inscrits), **pas** seulement `prono_leaderboard` |

| Pseudo / prénom / nom | Préfixe, insensible à la casse (`displayNameLower`, `firstNameLower`, `lastNameLower`) |

| Email | Correspondance **exacte** sur `emailLower` (ex. `ami@mail.fr`) |

| Résultat UI | `uid` + nom affiché uniquement — **jamais** l’email renvoyé |

| Min. caractères | 2 |

| Max. résultats | 12 (soi-même exclu) |



Label UI : **« Pseudo, prénom ou email »**.



Empty state : *Aucun inscrit trouvé. Essaie le prénom / pseudo (début du nom) ou l’email exact du compte.*



## Flux (UI → CF → Firestore)



```

PronoFriendsPage (_search)

  → PronoSocialService.searchUsers(query)

  → Callable Cloud Function `searchUsersForFriends` (Admin SDK)

       1) emailLower == query (exact)

       2) préfixe displayNameLower / firstNameLower / lastNameLower

       3) fallback legacy préfixe displayName / firstName / lastName

  → résultats { uid, displayName, firstName, lastName }

  → sendFriendRequest → `friend_requests` (inchangé)

```



La collection `users` reste **privée** (owner / staff). Aucune rule n’ouvre la lecture des emails à tous les clients.



## Sécurité



- **Pas** de `allow read` public sur `users` avec emails.

- Recherche email uniquement côté **Admin SDK** dans la callable authentifiée.

- Réponse sans champ `email`.

- Champs searchable (`emailLower`, `displayNameLower`, …) servent aux requêtes serveur ; le client n’y a pas accès en list open.



## Maintenance des champs searchable



Écrits / tenus à jour par :



| Moment | Où |

|---|---|

| Inscription | `AuthFirebaseDatasource.createUserProfile`, `UserService.createUser` |

| Création doc | `onUserDocCreated` (`xp_system.js`) |

| Toute écriture `users/{uid}` | Trigger `syncUserSearchFields` (`friend_search.js`) — idempotent |



Champs : `emailLower`, `displayNameLower`, `firstNameLower`, `lastNameLower`.



Les comptes legacy sans `*Lower` restent trouvables via fallback casse (`displayName` / `firstName`) + `emailLower` (déjà souvent présent). Toute MAJ profil déclenche le backfill via le trigger.



## Ancien fix (insuffisant)



Le correctif « préfixe `displayNameLower` sur `prono_leaderboard` + stub à l’ouverture Pronos » améliorait la search **parmi les joueurs Pronos indexés**, mais :



1. Un inscrit qui n’avait jamais ouvert Pronos / jamais de prono restait invisible.

2. L’email n’était jamais cherché (et ne doit pas l’être côté client).

3. Limite structurelle leaderboard ≠ annuaire app.



Ce flux leaderboard **n’est plus** utilisé pour la search amis.



## Indexes



Equality / range mono-champ (`emailLower`, `displayNameLower`, `firstNameLower`, …) → **index auto** Firestore. Rien à ajouter dans `firestore.indexes.json` pour cette feature.



Invitations : indexes composites `friend_requests` — inchangés (voir `FRIEND_REQUESTS_INDEX_FIX.md`).



## Deploy



```bash

# Depuis la racine du repo

firebase deploy --only "functions:searchUsersForFriends,functions:syncUserSearchFields"

# Optionnel si onUserDocCreated a changé :

firebase deploy --only "functions:onUserDocCreated"

```



Rebuild / release app Flutter requis (client appelle la callable + nouveaux labels).

Déployé le **2026-07-26** : `searchUsersForFriends`, `syncUserSearchFields`, `onUserDocCreated` (us-central1).



## Retest



1. Deux comptes A et B **inscrits** (B n’a pas besoin d’avoir ouvert Pronos).

2. A : Social → Amis → saisir ≥ 2 lettres du **prénom** de B → Rechercher → B apparaît.

3. A : saisir l’**email exact** de B → Rechercher → B apparaît (nom affiché, pas l’email).

4. Ajouter → invitation `friend_requests` pending (flow inchangé).

5. Email partiel / fauté → 0 résultat (normal : match exact uniquement).



## Fichiers clés



- `functions/friend_search.js` — callable + sync trigger

- `functions/lib/friend_search_core.js` — helpers purs

- `functions/test_friend_search.js` — `node test_friend_search.js`

- `lib/services/prono_social_service.dart` — `searchUsers`

- `lib/screens/prono/prono_social_pages.dart` — UI Amis

