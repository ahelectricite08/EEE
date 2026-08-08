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
const { defineSecret } = require('firebase-functions/params');

const mediamtxPublishUser = defineSecret('MEDIAMTX_PUBLISH_USER');
const mediamtxPublishPass = defineSecret('MEDIAMTX_PUBLISH_PASS');
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
  let whepUrl = String(m.whepUrl || '').trim();
  let hlsUrl = String(m.hlsUrl || '').trim();
  if (baseUrl) {
    if (!whipUrl) whipUrl = `${_withPort(baseUrl, 8889)}/${streamName}/whip`;
    if (!hlsUrl) hlsUrl = `${_withPort(baseUrl, 8888)}/${streamName}/index.m3u8`;
  }
  if (!whepUrl && whipUrl.toLowerCase().endsWith('/whip')) {
    whepUrl = `${whipUrl.slice(0, -5)}/whep`;
  } else if (!whepUrl && baseUrl) {
    whepUrl = `${_withPort(baseUrl, 8889)}/${streamName}/whep`;
  }
  return { streamName, baseUrl, whipUrl, whepUrl, hlsUrl };
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
    whepUrl: String(live.radioWhepUrl || '').trim() || cfg.whepUrl,
    hlsUrl: String(live.radioHlsUrl || '').trim() || cfg.hlsUrl,
    authorization: _readPublishAuthorization(),
    streamName: cfg.streamName,
  };
}

const CALL_OPTS = {
  cors: true,
  region: 'europe-west1',
  secrets: [mediamtxPublishUser, mediamtxPublishPass],
};

/**
 * Callable staff : URL WHIP + en-tête Authorization optionnel.
 */
exports.getLiveRadioPublishConfig = onCall(CALL_OPTS, async (request) => {
  const ctx = await _loadPublishContext(request);
  return {
    whipUrl: ctx.whipUrl,
    whepUrl: ctx.whepUrl,
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

/**
 * Résout Location WHIP (souvent relative) et refuse les hosts hors MediaMTX.
 */
function _resolveWhipLocation(location, whipUrl) {
  let resolved;
  try {
    resolved = new URL(location, whipUrl);
  } catch (_) {
    throw new HttpsError('invalid-argument', 'Location WHIP invalide');
  }
  let whip;
  try {
    whip = new URL(whipUrl);
  } catch (_) {
    throw new HttpsError('failed-precondition', 'URL WHIP invalide');
  }
  if (resolved.protocol !== whip.protocol || resolved.host !== whip.host) {
    throw new HttpsError(
      'invalid-argument',
      'Location WHIP hors MediaMTX',
    );
  }
  return resolved.toString();
}

/**
 * Proxy WHIP SDP POST (évite CORS navigateur → MediaMTX).
 * Auth publish reste côté Functions ; le média WebRTC va browser ↔ MediaMTX.
 */
exports.postLiveRadioWhipOffer = onCall(CALL_OPTS, async (request) => {
  const sdp = String(request.data?.sdp || '').trim();
  if (!sdp) {
    throw new HttpsError('invalid-argument', 'SDP manquant');
  }
  const ctx = await _loadPublishContext(request);
  const headers = {
    'Content-Type': 'application/sdp',
  };
  if (ctx.authorization) {
    headers.Authorization = ctx.authorization;
  }

  let response;
  try {
    response = await fetch(ctx.whipUrl, {
      method: 'POST',
      headers,
      body: sdp,
    });
  } catch (e) {
    const msg = e && e.message ? String(e.message) : 'erreur réseau';
    throw new HttpsError('unavailable', `WHIP injoignable — ${msg}`);
  }

  const answerBody = await response.text();
  if (!response.ok) {
    const snippet = String(answerBody || '').trim().slice(0, 200);
    throw new HttpsError(
      'failed-precondition',
      snippet
        ? `WHIP refusé (${response.status}) — ${snippet}`
        : `WHIP refusé (${response.status}) — vérifie MediaMTX`,
    );
  }

  const location =
    response.headers.get('Location') || response.headers.get('location');
  return {
    sdp: answerBody,
    location: location && String(location).trim() ? String(location).trim() : null,
  };
});

/**
 * Proxy WHIP DELETE (session de test / cleanup). Soft-fail si déjà absente.
 */
exports.deleteLiveRadioWhipSession = onCall(CALL_OPTS, async (request) => {
  const locationRaw = String(request.data?.location || '').trim();
  if (!locationRaw) {
    throw new HttpsError('invalid-argument', 'Location WHIP manquante');
  }
  const ctx = await _loadPublishContext(request);
  const url = _resolveWhipLocation(locationRaw, ctx.whipUrl);
  const headers = {};
  if (ctx.authorization) {
    headers.Authorization = ctx.authorization;
  }

  try {
    const response = await fetch(url, { method: 'DELETE', headers });
    if (
      !response.ok &&
      response.status !== 404 &&
      response.status !== 410
    ) {
      // Soft-fail : session peut déjà être expirée côté MediaMTX.
      console.warn(
        `[deleteLiveRadioWhipSession] DELETE ${response.status} for ${url}`,
      );
    }
  } catch (e) {
    console.warn('[deleteLiveRadioWhipSession] soft-fail', e);
  }
  return { ok: true };
});
