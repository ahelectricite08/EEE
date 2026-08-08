# Radio commentaire — MediaMTX (WHIP + HLS)

Remplace LiveKit Cloud : le staff publie le micro en **WHIP** vers un MediaMTX sur VPS ;
les fans écoutent en **HLS** (quelques secondes de latence, ~400 auditeurs OK, coût faible).

Voir aussi `docs/ENVIRONMENT.md` (secrets Firebase optionnels).

## Architecture

```
Admin téléphone  --WHIP-->  MediaMTX (VPS)  --HLS-->  Fans (app / web)
                     ^
                     |  (option) Icecast / OBS / autre → colle URL HLS dans Pilotage
```

| Rôle | Protocole | URL type |
|------|-----------|----------|
| Publish (staff) | WHIP | `https://HOST:8889/dvcr-radio/whip` |
| Listen (fans) | HLS | `https://HOST:8888/dvcr-radio/index.m3u8` |

Firestore :

- `app_config/radio` — URLs par défaut (`baseUrl`, `streamName`, `whipUrl`, `hlsUrl`)
- `live/current` — `radioLive`, `radioHlsUrl`, `radioWhipUrl`, `radioStartedAt`

Callables staff :
- `getLiveRadioPublishConfig` → `{ whipUrl, authorization? }`
- `postLiveRadioWhipOffer` / `deleteLiveRadioWhipSession` — proxy WHIP HTTP (SDP POST/DELETE) pour l’admin web (**Son test**), afin d’éviter le CORS navigateur → MediaMTX. L’auth publish reste côté Functions ; le média WebRTC va toujours browser ↔ MediaMTX.

## Docker Compose (VPS)

```yaml
# /opt/mediamtx/docker-compose.yml
services:
  mediamtx:
    image: bluenviron/mediamtx:latest
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./mediamtx.yml:/mediamtx.yml:ro
```

Fichier `mediamtx.yml` minimal :

```yaml
# Auth publish (recommandé en prod)
pathDefaults:
  publishUser: dvcr
  publishPass: CHANGE_ME_STRONG

paths:
  dvcr-radio:
    # source: publisher  (défaut — premier WHIP/RTSP gagne)
```

Lancer :

```bash
mkdir -p /opt/mediamtx && cd /opt/mediamtx
# coller docker-compose.yml + mediamtx.yml
docker compose up -d
```

One-liner test (sans auth, ports par défaut) :

```bash
docker run --rm -it --network=host bluenviron/mediamtx:latest
```

### Ports firewall

| Port | Usage |
|------|--------|
| **8889/tcp** | WebRTC / WHIP (publish + ICE HTTP) |
| **8189/udp** | WebRTC ICE (UDP) — ouvrir côté VPS |
| **8888/tcp** | HLS (écoute fans) |
| 8554/tcp | RTSP (optionnel, debug / OBS) |
| 1935/tcp | RTMP (optionnel) |

Derrière NAT / Docker : configurer `webrtcAdditionalHosts` / `webrtcICEHostNAT1To1IPs` avec l’IP publique du VPS (doc MediaMTX « Usage inside a container or behind a NAT »).

HTTPS : placer un reverse-proxy (Caddy / Nginx) devant 8888 (HLS) et 8889 (WHIP) avec certificats Let’s Encrypt. Les fans mobiles préfèrent `https://`.

## URLs à mettre dans la config

### Firestore `app_config/radio`

```json
{
  "baseUrl": "https://radio.tondomaine.fr",
  "streamName": "dvcr-radio",
  "whipUrl": "https://radio.tondomaine.fr:8889/dvcr-radio/whip",
  "hlsUrl": "https://radio.tondomaine.fr:8888/dvcr-radio/index.m3u8"
}
```

Si `whipUrl` / `hlsUrl` sont vides et `baseUrl` est renseigné, l’app dérive :

- WHIP → `baseUrl` avec port **8889** + `/{streamName}/whip`
- HLS → port **8888** + `/{streamName}/index.m3u8`

Écriture console Firebase ou admin (document public en lecture).

### Auth publish (optionnel)

Sur le VPS : `publishUser` / `publishPass` dans MediaMTX.

Dans Firebase :

```bash
firebase functions:secrets:set MEDIAMTX_PUBLISH_USER
firebase functions:secrets:set MEDIAMTX_PUBLISH_PASS
# ou un seul header :
# firebase functions:secrets:set MEDIAMTX_PUBLISH_AUTHORIZATION
```

Puis lier les secrets sur `getLiveRadioPublishConfig` dans `functions/mediamtx_radio.js`
(`secrets: [...]` sur le `onCall`) et redéployer.

## Parcours produit

### Admin — radio ON puis micro explicite (MediaMTX)

1. Démarrer le match en direct (idéalement « Match non retransmis » si pas de YouTube).
2. Pilotage → **RADIO COMMENTAIRE** ON (champ URL vide) — active HLS pour les fans, **sans** démarrer le micro.
3. Sur **téléphone** : taper **Activer le micro** pour publier en WHIP ; ensuite Couper / Réactiver micro.
4. Sur **web admin** : bouton **Son test** envoie un bip sinusoïdal (~20 s) via WHIP (proxy Cloud Functions) pour valider MediaMTX sans second téléphone. Le commentaire réel reste sur l’app téléphone.
5. Micro téléphone : Radio ON **ne** démarre **pas** le WHIP — taper **Activer le micro**.
6. Écoute fans (app) : HLS via `audio_service` (fond + notif, comme le podcast). Le publish WHIP en arrière-plan n’est pas garanti (garder l’app au premier plan pour commenter).

### Mode URL (diffuseur externe)

1. Coller une URL HLS ou Icecast dans le champ « URL HLS / Icecast ».
2. RADIO ON → fans jouent cette URL ; **pas** de WHIP (micro non utilisé).

### Fans

Accueil hero (pas de vidéo YouTube) ou fiche match : **ÉCOUTER EN AUDIO** → lecture HLS de `live/current.radioHlsUrl`.
Pendant l’écoute : **EN DIRECT — AUDIO**.

## Déploiement app

```bash
# Functions radio (+ proxy Son test)
firebase deploy --only functions:getLiveRadioPublishConfig,functions:getLiveRadioToken,functions:postLiveRadioWhipOffer,functions:deleteLiveRadioWhipSession

# Hosting admin (pilotage web)
flutter build web && firebase deploy --only hosting
```

Ne pas bumper TestFlight sauf demande.

## Dépannage

| Symptôme | Piste |
|----------|--------|
| « MediaMTX non configuré » | `app_config/radio` sans `whipUrl`/`baseUrl` |
| « URL HLS manquante » | idem pour `hlsUrl`, ou coller une URL en Pilotage |
| WHIP 401 | secrets publish / `publishUser` MediaMTX |
| WHIP OK mais silence fans | firewall 8888 ; URL HLS HTTPS ; stream publié ? |
| « pas encore disponible » / 404 | MediaMTX n’a pas de segments tant que le micro WHIP n’est pas vraiment connecté — attendre « Micro en direct » + retries app (~10 s) |
| iOS HTTP HLS bloqué | `NSAllowsArbitraryLoadsForMedia` dans Info.plist ; préférer `https://` HLS en prod |
| Android cleartext | `usesCleartextTraffic=true` (dev IP http) ; préférer https en prod |
| ICE fail (WHIP) | ouvrir UDP 8189 + `webrtcAdditionalHosts` = IP publique |
