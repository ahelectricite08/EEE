# Admin Notifications — améliorations (perf, bugs, cancel)

Date : 2026-07-26  
Périmètre : file `notifications_queue` + worker `sendManualNotification` + UI Admin Notifs / Bénévoles / Adhérents.

## Diagnostic (avant)

### Lenteur
1. **1 appel FCM `send()` par token**, en série — un broadcast « tous » pouvait prendre des minutes.
2. **Relecture Firestore maintenance** (`app_config/admin_maintenance`) **à chaque token** via `_sendFcm` → N lectures inutiles.
3. **iOS puis Android en série** dans `_sendManualBroadcast`.
4. UI : bouton « ENVOI EN COURS » ne couvrait que le `add()` Firestore (rapide), puis **attente silencieuse** du worker sans annulation.

### Bugs / friction
1. Statut restait **`pending`** pendant tout le traitement → confusing ; si la CF timeout / crashait, **pending bloqué** pour toujours.
2. **Pas d’annulation** des items en file.
3. Double-submit partiellement protégé (`_sending`) mais feedback d’erreur brut.
4. Historique affichait `PENDING` / `SENT` techniques, peu lisibles.

## Correctifs livrés

### Backend (`functions/lib/push_helpers.js`, `functions/manual_notifications.js`)
| Changement | Effet |
|---|---|
| Cache maintenance ~4 s | Fini les centaines de lectures config |
| `messaging.sendEach` par lots de 500 | Envoi broadcast beaucoup plus rapide |
| iOS + Android en **parallèle** | ~2× sur cible « tous » |
| Claim atomique `pending` → `processing` | État clair + race cancel |
| Respect de `status: cancelled` (avant + mid-flight) | Annulation réelle |
| Messages d’erreur FCM humanisés | Quota / timeout / permission |

### Cycle de vie statut
```
pending → processing → sent | skipped | error
   ↘           ↘
    cancelled ← cancelled (mid-flight, stats partielles possibles)
```

### UI
- Snackbar immédiat « mise en file » (fire-and-forget + stream Firestore).
- Suivi : En file / En cours + bouton **Annuler**.
- Historique : libellés FR + icône annuler sur pending/processing.
- Même pattern côté **Bénévoles** (Team DVCR).
- Dashboard / health : compte `pending` **ou** `processing`.

### Permissions
Inchangées : écriture `notifications_queue` = `isAdmin()` (`firestore.rules`). Onglet Notifs = `admin.notifs` (admin only).

## Comment annuler un pending

1. Admin ouvre **Notifications** (ou historique Bénévoles).
2. Sur un item **En file** / **En cours** : bouton **Annuler** (suivi dernier envoi ou icône rouge historique).
3. Client écrit `status: cancelled` (+ `cancelledAt`, `cancelledBy`) via transaction (uniquement si encore pending/processing).
4. Worker :
   - si cancel **avant claim** → no-op ;
   - si cancel **pendant** → stop entre lots FCM, laisse `cancelled` (+ stats partielles éventuelles).

> Si des push étaient déjà partis dans un lot `sendEach`, elles ne sont pas rappelables (limite FCM).

## Deploy

```bash
# Functions (obligatoire pour cancel + perf)
firebase deploy --only functions:sendManualNotification

# UI Admin web (si hosting = build/web)
flutter build web --release
firebase deploy --only hosting
```

## Retest

1. **Test perso** : Notifs → « Test sur mon téléphone » → snackbar immédiat → statut En file → En cours → Envoyé ; vérifier réception.
2. **Cancel pending** : envoyer une notif (cible large si possible) → Annuler pendant En file / En cours → statut Annulé ; worker ne doit pas repasser en `sent`.
3. **Broadcast** : envoi « Tous » — durée perçue nettement inférieure ; UI non bloquée après mise en file.
4. **Erreur** : (si possible) message compréhensible dans le panneau résultat.
5. **Bénévoles** : même flux cancel sur un envoi Team DVCR.
6. **Dashboard** : KPI notifs reflète pending+processing.

## Fichiers touchés
- `functions/manual_notifications.js`
- `functions/lib/push_helpers.js`
- `lib/screens/admin/tabs/notifs/notifs_tab.dart`
- `lib/screens/admin/tabs/benevoles/benevole_notifs_section.dart`
- `lib/screens/admin/tabs/benevoles/benevole_notif_delivery_panel.dart`
- `lib/screens/admin/tabs/adherents/adherents_tab.dart`
- `lib/screens/admin/tabs/dashboard/dashboard_tab.dart`
- `lib/screens/admin/widgets/admin_system_health_panel.dart`
