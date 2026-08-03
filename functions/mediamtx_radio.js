/**
 * Radio commentaire live — MediaMTX (WHIP publish + HLS listen).
 *
 * Secrets optionnels (auth publish MediaMTX) :
 *   MEDIAMTX_PUBLISH_USER
 *   MEDIAMTX_PUBLISH_PASS
 *   — ou —
 *   MEDIAMTX_PUBLISH_AUTHORIZATION  (ex. "Basic xxx" ou "Bearer yyy")
 *
 * Config publique Firestore `app_config/radio` :
 *   { baseUrl, streamName, whipUrl, hlsUrl }
 *
 * `live/current` : radioLive, radioHlsUrl, radioWhipUrl, radioStartedAt
 *
 * Écoute fans = URL HLS publique (pas de token).
 * Publish staff = callable [getLiveRadioPublishConfig].
 *
 * Compat : [getLiveRadioToken] reste exporté et délègue (évite casser d’anciens clients).
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const { _isUserAdmin } = require('./lib/admin_auth');

function _canPublishRadio(userDoc) {
  if (!userDoc || !userDoc.exists) return false;
  if (_isUserAdmin(userDoc)) return true;
  const data = userDoc.data() || {};
  const role = String(data.role || '')
    .trim()
    .toLowerCase();
  if (role === 'community_manager' || role === 'statisticien') return true;
  const roles = Array.isArray(data.roles)
    ? data.roles.map((r) => String(r || '').trim().toLowerCase())
    : [];
  return (
    roles.includes('community_manager') || roles.includes('statisticien')
  );
}

function _withPort(base, port) {
  try {
    const u = new URL(base);
    u.port = String(port);
    return u.toString().replace(/\/+$/, '');
  } catch (_) {
    return `${String(base).replace(/\/+$/, '')}:${port}`;
  }
}

function _normalizeRadioConfig(raw) {
  const m = raw || {};
  const streamName =
    String(m.streamName || 'dvcr-radio').trim() || 'dvcr-radio';
  const baseUrl = String(m.baseUrl || '')
    .trim()
    .replace(/\/+$/, '');
  let whipUrl = String(m.whipUrl || '').trim();
  let hlsUrl = String(m.hlsUrl || '').trim();
  if (baseUrl) {
    if (!whipUrl) whipUrl = `${_withPort(baseUrl, 8889)}/${streamName}/whip`;
    if (!hlsUrl) hlsUrl = `${_withPort(baseUrl, 8888)}/${streamName}/index.m3u8`;
  }
  return { streamName, baseUrl, whipUrl, hlsUrl };
}

function _readPublishAuthorization() {
  const direct = String(process.env.MEDIAMTX_PUBLISH_AUTHORIZATION || '').trim();
  if (direct) return direct;
  const user = String(process.env.MEDIAMTX_PUBLISH_USER || '').trim();
  const pass = String(process.env.MEDIAMTX_PUBLISH_PASS || '').trim();
  if (user && pass) {
    const token = Buffer.from(`${user}:${pass}`, 'utf8').toString('base64');
    return `Basic ${token}`;
  }
  return '';
}

async function _loadPublishContext(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canPublishRadio(userDoc)) {
    throw new HttpsError(
      'permission-denied',
      'Seul le staff peut commenter à la radio',
    );
  }

  const liveSnap = await db.collection('live').doc('current').get();
  if (!liveSnap.exists) {
    throw new HttpsError('failed-precondition', 'Aucun match en direct');
  }
  const live = liveSnap.data() || {};
  if (live.radioLive !== true) {
    throw new HttpsError('failed-precondition', 'Radio commentaire éteinte');
  }

  const cfgSnap = await db.collection('app_config').doc('radio').get();
  const cfg = _normalizeRadioConfig(cfgSnap.data());
  const whipUrl =
    String(live.radioWhipUrl || '').trim() || cfg.whipUrl;
  if (!whipUrl) {
    throw new HttpsError(
      'failed-precondition',
      'MediaMTX non configuré — renseigne app_config/radio (whipUrl ou baseUrl)',
    );
  }

  return {
    whipUrl,
    hlsUrl: String(live.radioHlsUrl || '').trim() || cfg.hlsUrl,
    authorization: _readPublishAuthorization(),
    streamName: cfg.streamName,
  };
}

const CALL_OPTS = {
  cors: true,
  region: 'europe-west1',
  // Pour activer l’auth publish : créer les secrets puis ajouter
  // secrets: ['MEDIAMTX_PUBLISH_USER','MEDIAMTX_PUBLISH_PASS']
  // (ou MEDIAMTX_PUBLISH_AUTHORIZATION) sur ce onCall.
};

/**
 * Callable staff : URL WHIP + en-tête Authorization optionnel.
 */
exports.getLiveRadioPublishConfig = onCall(CALL_OPTS, async (request) => {
  const ctx = await _loadPublishContext(request);
  return {
    whipUrl: ctx.whipUrl,
    hlsUrl: ctx.hlsUrl,
    authorization: ctx.authorization || null,
    streamName: ctx.streamName,
    role: 'publisher',
  };
});

/**
 * @deprecated Compat anciens clients LiveKit — renvoie désormais la config WHIP.
 * Les champs `token`/`url` miment l’ancien contrat (token = auth header, url = whip).
 */
exports.getLiveRadioToken = onCall(CALL_OPTS, async (request) => {
  const roleRaw = String(request.data?.role || '')
    .trim()
    .toLowerCase();
  if (roleRaw !== 'publisher') {
    throw new HttpsError(
      'failed-precondition',
      'Écoute radio via HLS (live/current.radioHlsUrl) — plus de token auditeur',
    );
  }
  const ctx = await _loadPublishContext(request);
  return {
    token: ctx.authorization || 'whip',
    url: ctx.whipUrl,
    roomName: ctx.streamName,
    role: 'publisher',
    whipUrl: ctx.whipUrl,
    hlsUrl: ctx.hlsUrl,
    authorization: ctx.authorization || null,
  };
});
