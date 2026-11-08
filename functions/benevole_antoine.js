/**
 * Pont dispos bénévoles → API Antoine (Nest).
 * Auth : secret ANTOINE_BENEVOLE_BEARER = SERVICE_API_KEY (header Bearer).
 * Jamais dans l’APK.
 */
const axios = require('axios');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore } = require('firebase-admin/firestore');
const { _isUserAdmin, _isTeamDvcrUserData } = require('./lib/admin_auth');
const {
  flattenSkills,
  normalizeEmail,
  normalizeStatus,
  normalizeWishes,
  pickMine,
  toPublicMatch,
} = require('./lib/benevole_antoine_map');

const antoineBearer = defineSecret('ANTOINE_BENEVOLE_BEARER');
const ANTOINE_BASE = 'https://dvcr-backend.87.88.238.84.sslip.io';

const CALL_OPTS = {
  cors: true,
  secrets: [antoineBearer],
  timeoutSeconds: 60,
};

function _authHeaders() {
  const token = String(antoineBearer.value() || '').trim();
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

async function _antoine(method, path, { body } = {}) {
  const url = `${ANTOINE_BASE}${path}`;
  try {
    return await axios({
      method,
      url,
      data: body,
      headers: {
        ..._authHeaders(),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      timeout: 20000,
      validateStatus: () => true,
    });
  } catch (err) {
    console.warn('[benevole-antoine] réseau', err?.message);
    throw new HttpsError('unavailable', 'Planning bénévoles injoignable');
  }
}

function _mapAntoineError(res, fallback) {
  const msg = String(res?.data?.message || fallback || '').trim();
  const code = res?.status;
  if (code === 401 || code === 403) {
    throw new HttpsError(
      'failed-precondition',
      'Clé service Antoine refusée. Vérifier ANTOINE_BENEVOLE_BEARER.',
    );
  }
  if (code === 500) {
    throw new HttpsError(
      'unavailable',
      'Planning Antoine en erreur (calendrier). Prévenir Antoine : GET /api/matches plante avec la SERVICE_API_KEY.',
    );
  }
  if (code === 404) {
    if (/volunteer/i.test(msg)) {
      throw new HttpsError(
        'not-found',
        'Ton email n’est pas encore dans le planning Antoine.',
      );
    }
    throw new HttpsError('not-found', 'Match introuvable chez Antoine.');
  }
  if (code >= 400) {
    throw new HttpsError('internal', msg || 'Erreur planning bénévoles');
  }
}

async function _requireBenevoleCaller(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const data = userDoc.data() || {};
  if (!_isUserAdmin(userDoc) && !_isTeamDvcrUserData(data)) {
    throw new HttpsError('permission-denied', 'Réservé à la Team DVCR');
  }
  const email = normalizeEmail(
    request.auth.token.email || data.email || data.emailLower,
  );
  if (!email) {
    throw new HttpsError(
      'failed-precondition',
      'Compte sans email — impossible d’envoyer une dispo.',
    );
  }
  return { email, uid: request.auth.uid };
}

async function _loadSkills() {
  const res = await _antoine('GET', '/api/skills');
  if (res.status >= 400) _mapAntoineError(res, 'Catalogue postes indisponible');
  return flattenSkills(res.data);
}

exports.listBenevoleMatches = onCall(CALL_OPTS, async (request) => {
  const { email } = await _requireBenevoleCaller(request);
  const listRes = await _antoine('GET', '/api/matches?upcoming=true');
  if (listRes.status >= 400) _mapAntoineError(listRes, 'Calendrier indisponible');
  const rawMatches = Array.isArray(listRes.data) ? listRes.data : [];
  const { names, idToName } = await _loadSkills().catch(() => ({
    names: [],
    idToName: Object.create(null),
  }));

  const matches = [];
  const chunkSize = 4;
  for (let i = 0; i < rawMatches.length; i += chunkSize) {
    const slice = rawMatches.slice(i, i + chunkSize);
    const rows = await Promise.all(
      slice.map(async (match) => {
        const uuid = String(match?.id || '').trim();
        if (!uuid) return toPublicMatch(match, null, idToName);
        const avRes = await _antoine(
          'GET',
          `/api/matches/${encodeURIComponent(uuid)}/availabilities`,
        );
        const mine =
          avRes.status < 400 ? pickMine(avRes.data, email) : null;
        return toPublicMatch(match, mine, idToName);
      }),
    );
    matches.push(...rows);
  }

  return { email, posts: names, matches };
});

exports.submitBenevoleAvailability = onCall(CALL_OPTS, async (request) => {
  const { email } = await _requireBenevoleCaller(request);
  const data = request.data || {};
  const matchId = String(data.matchId || '').trim();
  const status = normalizeStatus(data.status);
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }
  if (!status) {
    throw new HttpsError('invalid-argument', 'status PRESENT ou ABSENT');
  }
  const wishes =
    status === 'ABSENT' ? [] : normalizeWishes(data.wishes);

  const body = { email, status };
  if (status === 'ABSENT' || Array.isArray(data.wishes)) {
    body.wishes = wishes;
  }

  const res = await _antoine(
    'PUT',
    `/api/matches/${encodeURIComponent(matchId)}/availability`,
    { body },
  );
  if (res.status >= 400) _mapAntoineError(res, 'Envoi dispo refusé');

  return {
    id: res.data?.id || null,
    status: normalizeStatus(res.data?.status) || status,
    updatedAt: res.data?.updatedAt || null,
  };
});
