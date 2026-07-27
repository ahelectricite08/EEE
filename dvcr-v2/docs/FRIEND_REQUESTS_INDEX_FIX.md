# Friend requests — fix FAILED_PRECONDITION (index manquant)

**Date :** 2026-07-26  
**Symptôme :** à l’ajout d’un ami, logs Flutter :

```
Listen for Query(friend_requests where fromUid==… and status==pending order by -createdAt)
failed: FAILED_PRECONDITION — The query requires an index.
```

## Cause

`PronoSocialService.sentFriendRequestsForUser` écoute :

- `fromUid == uid`
- `status == pending`
- `orderBy(createdAt, descending: true)`

Seul l’index **incoming** (`toUid` + `status` + `createdAt`) existait dans `firestore.indexes.json`. L’index **outgoing** (`fromUid` + …) manquait.

## Queries Dart (`lib/services/prono_social_service.dart`)

| Méthode | Filtres | Index |
|---|---|---|
| `friendRequestsForUser` | `toUid`, `status`, `orderBy createdAt DESC` | composite toUid |
| `sentFriendRequestsForUser` | `fromUid`, `status`, `orderBy createdAt DESC` | composite fromUid (**ajouté**) |
| `sendFriendRequest` (doublon) | `fromUid`, `toUid`, `status` (sans orderBy) | indexes mono-champ auto — OK |

## Correctif

Dans `firestore.indexes.json`, collection `friend_requests` :

1. `toUid` ASC, `status` ASC, `createdAt` DESC
2. `fromUid` ASC, `status` ASC, `createdAt` DESC

(`__name__` DESC est ajouté automatiquement par Firestore.)

## Deploy

```bash
firebase deploy --only firestore:indexes
```

Projet Firebase : `drapeau-vert-app` (voir `.firebaserc`).

Déployé le 2026-07-26 (`Deploy complete!`). L’index peut rester en état **Building** quelques minutes dans la console avant d’être **Enabled**.

## Console (lien dans les logs)

Le message d’erreur Flutter contient souvent une URL directe du type :

`https://console.firebase.google.com/v1/r/project/drapeau-vert-app/firestore/indexes?create_composite=…`

Sinon : Firebase Console → Firestore → Indexes.

## Vérification

1. Attendre que les deux index `friend_requests` soient **Enabled**.
2. Ouvrir Pronos → Social → envoyer une demande d’ami.
3. Plus d’erreur `FAILED_PRECONDITION` dans les logs ; la demande apparaît côté destinataire et dans les envois en attente.

## Cleanup — index redondant `status` + `toUid` + `createdAt` (2026-07-26)

### Verdict : **inutile**

Audit des queries `friend_requests` :

| Source | Query | Index requis |
|---|---|---|
| `friendRequestsForUser` | `toUid` → `status` → `orderBy createdAt DESC` | **toUid** + status + createdAt |
| `sentFriendRequestsForUser` | `fromUid` → `status` → `orderBy createdAt DESC` | **fromUid** + status + createdAt |
| `sendFriendRequest` (doublon) | `fromUid` + `toUid` + `status` (sans orderBy) | mono-champ auto |
| `functions/notification_triggers.js` | `onDocumentCreated` trigger | aucun index query |

Aucune query n’exige l’ordre **status → toUid → createdAt**.

### État fichiers vs console

- `firestore.indexes.json` : déjà correct (uniquement toUid… et fromUid…). Le redondant n’y figurait pas.
- Console / remote : 3 index `friend_requests` (dont le redondant, probablement créé via un lien console `create_composite`).

### Note Firebase deploy

`firebase deploy --only firestore:indexes` **ajoute** les index manquants du JSON, mais **ne supprime pas** les index absents du fichier. Suppression manuelle requise (console ou API).

### Action

Supprimé via Firestore REST API :

```
DELETE …/collectionGroups/friend_requests/indexes/CICAgOi3kJAK
# fields: status ASC, toUid ASC, createdAt DESC, __name__ DESC
```

### Console attendue

Exactement **2** index composites `friend_requests`, tous **Enabled / READY** :

1. `fromUid` ASC + `status` ASC + `createdAt` DESC  
2. `toUid` ASC + `status` ASC + `createdAt` DESC  

Plus d’index `status` + `toUid` + `createdAt`.
