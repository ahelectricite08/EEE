# Live Activity iOS — fix updates arrière-plan

**Date :** 2026-07-26  
**Symptôme :** Dynamic Island / Lock Screen ne se mettait à jour qu’après relancer l’app.

## Cause racine

Les mises à jour passaient **uniquement** par :

1. FCM **silent** (`apns-push-type: background`, `content-available: 1`, priorité 5)
2. Réveil de l’app → `AppDelegate` / Flutter → écriture App Group + `Activity.update()` local

Ce mode est **best-effort** : iOS throttle / ignore souvent les silent pushes (app en arrière-plan longtemps, Low Power, app tuée). Résultat : score / cartons figés jusqu’à ouverture de l’app.

De plus :

- Aucun **ActivityKit push token** n’était enregistré côté serveur
- Le `ContentState` ne contenait que `appGroupId` (score uniquement en UserDefaults App Group) → un push ActivityKit n’aurait de toute façon pas pu porter le score

Il n’y avait **pas** de pipeline `apns-push-type: liveactivity`.

## Correctif appliqué

### 1. ContentState riche (Runner + Widget)

`LiveActivitiesAppAttributes.ContentState` inclut désormais score, équipes, minute, chrono, phase, `lastEventLine`, `lastEventIsHome`, `contentTick`.

Le widget lit **d’abord** `context.state` (si `contentTick > 0`), sinon App Group (création plugin / logos).
`lastEventIsHome` aligne le buteur / fait de jeu : **gauche = domicile**, **droite = extérieur**.

### 2. Updates locales native

`LiveActivityFcmSync` pousse un ContentState complet (plus seulement `appGroupId` + staleDate).
Les updates **partielles** (refresh chrono) **fusionnent** avec le ContentState précédent pour ne pas écraser score / événement.

### 3. Enregistrement token ActivityKit (Flutter)

Quand une Live Activity démarre, l’app écoute `activityUpdateStream` / `getPushToken` (avec **retries**) et écrit :

`live_activity_tokens/{uid}` → `{ activityToken, fcmToken, activityId, matchId, … }`

Cache local + flush au retour auth / refresh FCM / `syncNow` (resume).

Règles Firestore ajoutées (écriture uniquement pour son propre uid).

### 4. Cloud Function → push ActivityKit

`functions/lib/live_activity_apns.js` envoie via FCM HTTP v1 :

- `apns.live_activity_token`
- headers `apns-push-type: liveactivity`, `apns-topic: fr.dvcr.app.push-type.liveactivity`, priorité 10
- `aps.event: update|end` + `content-state` aligné Swift (+ `stale-date`, `relevance-score`)

Branché depuis `live_push.js` (buts, cartons, phases, chrono, fin de match). Les silent FCM restent en filet de secours (moins fiables quand l’app est tuée / Low Power).

## Déploiement requis

1. **Firestore rules** : déployer `firestore.rules` (collection `live_activity_tokens`)
2. **Cloud Functions** : déployer `notifyGoal` / module `live_push` (+ `lib/live_activity_apns.js`)
3. **App iOS** : rebuild + install (ContentState + token registration)
4. Capacités déjà OK : Push Notifications, App Groups, `NSSupportsLiveActivities`

Pas de nouveau secret Apple : FCM utilise déjà l’auth APNs du projet Firebase.

## Checklist test manuelle (iPhone physique)

1. Connexion utilisateur + notif « Score écran verrouillage » ON  
2. Admin : démarrer un live → ouvrir l’app (LA apparaît)  
3. Vérifier Firestore `live_activity_tokens/{uid}` : `activityToken` + `fcmToken` présents  
4. Mettre l’app en **arrière-plan** (ou verrouiller l’écran) **sans** la tuer d’abord  
5. Admin : but / carton → DI / Lock Screen doit se mettre à jour **sans** rouvrir l’app  
6. Logs Functions : `[liveActivityKit] update sent=…`  
7. Fin de match : LA se termine ; tokens nettoyés

### Si `sent=0`

- Token pas encore enregistré (rouvrir l’app pendant le live)  
- Pas connecté (auth requise pour écrire le token)  
- Vérifier logs `[liveActivityKit] send fail …`

### Si `sent>0` mais UI stale

- Rebuild iOS manqué (ancien ContentState widget)  
- Vérifier que Widget Extension et Runner ont le **même** ContentState

## Fichiers touchés

- `ios/Runner/LiveActivitiesAppAttributes.swift`
- `ios/Runner/LiveActivityFcmSync.swift`
- `ios/DvcrLiveActivity/DvcrLiveActivityLiveActivity.swift`
- `lib/services/live_activity_token_service.dart`
- `lib/services/live_match_activity_service.dart`
- `functions/lib/live_activity_apns.js`
- `functions/live_push.js`
- `firestore.rules`
- `dvcr-v2/docs/LIVE_ACTIVITY_UPDATE_FIX.md` (ce fichier)
