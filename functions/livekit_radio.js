/**
 * Radio commentaire live (LiveKit, audio-only).
 *
 * Secrets / env à configurer (Cloud Functions → Variables / Secrets) :
 *   LIVEKIT_API_KEY
 *   LIVEKIT_API_SECRET
 *   LIVEKIT_URL   (ex. wss://xxx.livekit.cloud)
 *
 * Exemple Secret Manager + liaison :
 *   firebase functions:secrets:set LIVEKIT_API_KEY
 *   firebase functions:secrets:set LIVEKIT_API_SECRET
 *   firebase functions:secrets:set LIVEKIT_URL
 * Puis ajouter `secrets: ['LIVEKIT_API_KEY','LIVEKIT_API_SECRET','LIVEKIT_URL']`
 * dans l’export onCall et redéployer.
 *
 * Si absents → failed-precondition « LiveKit non configuré ».
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const { AccessToken } = require('livekit-server-sdk');
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

function _readLivekitConfig() {
  const apiKey = String(process.env.LIVEKIT_API_KEY || '').trim();
  const apiSecret = String(process.env.LIVEKIT_API_SECRET || '').trim();
  const url = String(process.env.LIVEKIT_URL || '').trim();
  if (!apiKey || !apiSecret || !url) {
    throw new HttpsError(
      'failed-precondition',
      'LiveKit non configuré',
    );
  }
  return { apiKey, apiSecret, url };
}

/**
 * Callable : mint un JWT LiveKit pour la radio du match en cours.
 * data: { role: 'publisher' | 'subscriber' }
 */
exports.getLiveRadioToken = onCall(
  {
    cors: true,
    region: 'europe-west1',
  },
  async (request) => {
    const roleRaw = String(request.data?.role || '')
      .trim()
      .toLowerCase();
    const role = roleRaw === 'publisher' ? 'publisher' : 'subscriber';

    const db = getFirestore();
    const liveSnap = await db.collection('live').doc('current').get();
    if (!liveSnap.exists) {
      throw new HttpsError('failed-precondition', 'Aucun match en direct');
    }
    const live = liveSnap.data() || {};
    if (live.radioLive !== true) {
      throw new HttpsError('failed-precondition', 'Radio commentaire éteinte');
    }

    const matchId = String(live.matchId || '').trim();
    const roomName =
      String(live.radioRoomName || '').trim() ||
      (matchId ? `dvcr-radio-${matchId}` : 'dvcr-radio');

    let identity;
    let displayName;

    if (role === 'publisher') {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Non authentifié');
      }
      const userDoc = await db.collection('users').doc(request.auth.uid).get();
      if (!_canPublishRadio(userDoc)) {
        throw new HttpsError(
          'permission-denied',
          'Seul le staff peut commenter à la radio',
        );
      }
      identity = `pub_${request.auth.uid}`;
      const u = userDoc.data() || {};
      displayName =
        String(u.displayName || u.firstName || u.pseudo || 'Commentateur')
          .trim()
          .slice(0, 64) || 'Commentateur';
    } else {
      if (request.auth?.uid) {
        identity = `sub_${request.auth.uid}`;
        displayName = 'Auditeur';
      } else {
        const suffix = Math.random().toString(36).slice(2, 10);
        identity = `anon_${suffix}`;
        displayName = 'Auditeur';
      }
    }

    const { apiKey, apiSecret, url } = _readLivekitConfig();

    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name: displayName,
      ttl: '6h',
    });
    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: role === 'publisher',
      canSubscribe: true,
      canPublishData: false,
    });

    const token = await at.toJwt();
    return {
      token,
      url,
      roomName,
      role,
    };
  },
);
