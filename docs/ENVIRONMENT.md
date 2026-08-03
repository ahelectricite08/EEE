# Variables d'environnement et secrets — DVCR

## Firebase Cloud Functions (Secret Manager)

| Secret | Usage |
|--------|--------|
| `YOUTUBE_API_KEY` | Sync playlists YouTube |
| `WIX_WEBHOOK_SECRET` | Webhook articles Wix |
| `HELLOASSO_WEBHOOK_SECRET` | Signature webhooks HelloAsso |
| `MEDIAMTX_PUBLISH_USER` | (opt.) Auth WHIP radio — user MediaMTX |
| `MEDIAMTX_PUBLISH_PASS` | (opt.) Auth WHIP radio — pass MediaMTX |
| `MEDIAMTX_PUBLISH_AUTHORIZATION` | (opt.) Header Authorization complet WHIP |

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

## Radio commentaire — MediaMTX (WHIP + HLS)

Doc complète : [`docs/RADIO_MEDIAMTX.md`](RADIO_MEDIAMTX.md).

1. Déployer MediaMTX sur le VPS (compose dans la doc).
2. Créer Firestore `app_config/radio` avec `whipUrl` + `hlsUrl` (ou `baseUrl` + `streamName`).
3. (Optionnel) Auth publish :

```bash
firebase functions:secrets:set MEDIAMTX_PUBLISH_USER
firebase functions:secrets:set MEDIAMTX_PUBLISH_PASS
```

Lier les secrets sur `getLiveRadioPublishConfig` dans `functions/mediamtx_radio.js` puis :

```bash
firebase deploy --only functions:getLiveRadioPublishConfig,functions:getLiveRadioToken
```

Sans `app_config/radio`, l’admin voit « MediaMTX non configuré » / « URL HLS manquante ».
Les anciens secrets LiveKit (`LIVEKIT_*`) ne sont plus utilisés.

## Déploiement

```bash
# Functions + rules + indexes
firebase deploy --only functions,firestore:rules,firestore:indexes

# App web admin
flutter build web && firebase deploy --only hosting
```
