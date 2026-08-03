# Variables d'environnement et secrets — DVCR

## Firebase Cloud Functions (Secret Manager)

| Secret | Usage |
|--------|--------|
| `YOUTUBE_API_KEY` | Sync playlists YouTube |
| `WIX_WEBHOOK_SECRET` | Webhook articles Wix |
| `HELLOASSO_WEBHOOK_SECRET` | Signature webhooks HelloAsso |
| `LIVEKIT_API_KEY` | Radio commentaire live (JWT) |
| `LIVEKIT_API_SECRET` | Radio commentaire live (JWT) |
| `LIVEKIT_URL` | URL LiveKit (`wss://…`) pour la radio |

## Firebase Functions (env classique)

| Variable | Usage |
|----------|--------|
| `HELLOASSO_ORGANIZATION_SLUG` | Filtre org HelloAsso |

## GitHub Actions (iOS TestFlight)

| Secret | Usage |
|--------|--------|
| `CERTIFICATE_BASE64` | Certificat signature iOS |
| `CERTIFICATE_PASSWORD` | Mot de passe certificat |
| `KEYCHAIN_PASSWORD` | Keychain temporaire CI |
| `PROFILE_RUNNER_BASE64` | Profil provisioning Runner |
| `PROFILE_EXTENSION_BASE64` | Profil Live Activity |
| `ASC_PRIVATE_KEY_B64` | Clé API App Store Connect |

## Fastlane (optionnel)

| Variable | Usage |
|----------|--------|
| `APPLE_ID` | Compte Apple développeur |
| `ITC_TEAM_ID` | Équipe App Store Connect |
| `ASC_PRIVATE_KEY_B64` | Clé API ASC |

## Android (local, gitignored)

| Fichier | Usage |
|---------|--------|
| `android/key.properties` | Keystore release |
| `android/local.properties` | Chemins SDK |

## LiveKit — radio commentaire

1. Créer un projet LiveKit Cloud (ou self-host) et récupérer API Key / Secret / URL `wss://…`.
2. Définir les secrets Firebase :

```bash
firebase functions:secrets:set LIVEKIT_API_KEY
firebase functions:secrets:set LIVEKIT_API_SECRET
firebase functions:secrets:set LIVEKIT_URL
```

3. Lier les secrets sur `getLiveRadioToken` dans `functions/livekit_radio.js`
   (`secrets: ['LIVEKIT_API_KEY','LIVEKIT_API_SECRET','LIVEKIT_URL']` sur le `onCall`)
   puis redéployer :

```bash
firebase deploy --only functions:getLiveRadioToken
```

Sans ces variables, l’admin voit « LiveKit non configuré » et les fans ne peuvent pas écouter.

## Déploiement

```bash
# Functions + rules + indexes
firebase deploy --only functions,firestore:rules,firestore:indexes

# App web admin
flutter build web && firebase deploy --only hosting
```
