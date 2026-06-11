# Live Activity iOS — configuration Xcode (obligatoire une fois)

Les fichiers Swift sont dans `ios/DvcrLiveActivity/`. Il reste à **ajouter la cible Widget Extension** dans Xcode (non faisable entièrement depuis Windows).

## Étapes (Mac + Xcode)

1. Ouvre `ios/Runner.xcworkspace`.
2. **File → New → Target → Widget Extension**
   - Nom : `DvcrLiveActivity`
   - Décocher « Include Configuration App Intent »
   - Embed in : **Runner**
3. Supprime les fichiers Swift générés par Xcode dans le dossier extension.
4. Glisse les fichiers du repo :
   - `ios/DvcrLiveActivity/DvcrLiveActivity.swift`
   - `ios/DvcrLiveActivity/Info.plist`
5. **Signing & Capabilities** (Runner **et** DvcrLiveActivity) :
   - **App Groups** → `group.fr.dvcr.app.liveactivities`
6. **DvcrLiveActivity** → Deployment Target **iOS 16.1**
7. **Runner** → Info.plist contient déjà `NSSupportsLiveActivities` et l’URL scheme `dvcr`.
8. Build sur **iPhone physique** (pas le simulateur).

## Test

1. Profil → **Score sur écran de verrouillage** : ON
2. Lance un match live en admin
3. Ouvre l’app (ou tape la notif coup d’envoi)
4. Verrouille l’iPhone : bannière DVCR avec le score

## Android

Aucune étape Xcode : rebuild APK suffit. La notif persistante custom (`live_activity.xml`) s’affiche pendant le direct.
