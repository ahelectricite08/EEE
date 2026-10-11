const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const {
  isLeagueMemberOrOwner,
  leagueOwnerUid,
  pickExistingInviteCode,
  randomLeagueInviteCode,
} = require('./lib/league_invite_code');

const CODE_RE = /^[A-Z0-9]{4,12}$/;

async function _ensureInviteCodeForLeague(db, leagueId, uid) {
  const leagueRef = db.collection('private_leagues').doc(leagueId);
  const leagueSnap = await leagueRef.get();
  if (!leagueSnap.exists) {
    throw new HttpsError('not-found', 'Ligue introuvable');
  }
  const data = leagueSnap.data() || {};
  if (!isLeagueMemberOrOwner(data, uid)) {
    throw new HttpsError('permission-denied', 'Réservé aux membres de la ligue');
  }

  const secretRef = leagueRef.collection('secrets').doc('join');
  const secretSnap = await secretRef.get();
  const codesSnap = await db
    .collection('league_join_codes')
    .where('leagueId', '==', leagueId)
    .limit(1)
    .get();

  let code = pickExistingInviteCode({
    secret: secretSnap.data()?.value,
    parentCode: data.code,
    joinCodeId: codesSnap.empty ? '' : codesSnap.docs[0].id,
  });

  if (!code) {
    for (let i = 0; i < 8; i++) {
      const candidate = randomLeagueInviteCode();
      const codeRef = db.collection('league_join_codes').doc(candidate);
      if ((await codeRef.get()).exists) continue;
      code = candidate;
      break;
    }
  }
  if (!code) {
    throw new HttpsError('internal', 'Impossible de créer un code salon');
  }

  const ownerUid = leagueOwnerUid(data) || uid;
  await db.collection('league_join_codes').doc(code).set({
    leagueId,
    ownerUid,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await secretRef.set({
    value: code,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  if (data.code) {
    await leagueRef.update({ code: FieldValue.delete() });
  }
  return code;
}

async function _lookupLeagueIdByCode(db, code) {
  const codeSnap = await db.collection('league_join_codes').doc(code).get();
  if (codeSnap.exists) {
    const leagueId = String(codeSnap.data()?.leagueId || '').trim();
    return leagueId || null;
  }

  const legacy = await db
    .collection('private_leagues')
    .where('code', '==', code)
    .limit(1)
    .get();
  if (legacy.empty) return null;

  const doc = legacy.docs[0];
  const leagueId = doc.id;
  const ownerUid = String(doc.data()?.ownerUid || '');
  await db.collection('league_join_codes').doc(code).set({
    leagueId,
    ownerUid,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await doc.ref.collection('secrets').doc('join').set({
    value: code,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await doc.ref.update({ code: FieldValue.delete() });
  return leagueId;
}

/**
 * Rejoindre une ligue privée par code — Admin SDK.
 * Les docs `private_leagues` ne portent plus le code (lisible par tout user auth).
 */
exports.joinPrivateLeagueByCode = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const uid = request.auth.uid;
  const code = String(request.data?.code || '').trim().toUpperCase();
  if (!CODE_RE.test(code)) {
    throw new HttpsError('invalid-argument', 'Code de ligue invalide');
  }

  const db = getFirestore();
  const leagueId = await _lookupLeagueIdByCode(db, code);
  if (!leagueId) {
    throw new HttpsError('not-found', 'Code de ligue introuvable');
  }

  const userSnap = await db.collection('users').doc(uid).get();
  const fromBody = String(request.data?.displayName || '').trim();
  const fromUser = String(userSnap.data()?.displayName || '').trim();
  const displayName = fromBody || fromUser || 'Supporter';

  const leagueRef = db.collection('private_leagues').doc(leagueId);
  const joined = await db.runTransaction(async (tx) => {
    const leagueSnap = await tx.get(leagueRef);
    if (!leagueSnap.exists) {
      throw new HttpsError('not-found', 'Ligue introuvable');
    }
    const data = leagueSnap.data() || {};
    const memberIds = Array.isArray(data.memberIds)
      ? data.memberIds.map(String)
      : [];
    if (memberIds.includes(uid)) {
      return { alreadyMember: true, name: String(data.name || 'Ligue privée'), memberIds };
    }
    tx.update(leagueRef, {
      memberIds: FieldValue.arrayUnion([uid]),
      memberNames: FieldValue.arrayUnion([displayName]),
      memberCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {
      alreadyMember: false,
      name: String(data.name || 'Ligue privée'),
      memberIds,
    };
  });

  if (!joined.alreadyMember) {
    const memberIds = [...new Set([...joined.memberIds, uid])];
    await db.collection('prono_social_activity').add({
      type: 'league_joined',
      title: `${displayName} a rejoint une ligue`,
      subtitle: joined.name,
      memberIds,
      scope: 'social',
      leagueId,
      leagueName: joined.name,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return {
    success: true,
    alreadyMember: joined.alreadyMember === true,
    leagueId,
  };
});

/**
 * Lit ou crée le code salon. Tout membre déjà dans la ligue (pas seulement
 * le créateur). Ligues legacy sans `secrets/join` (ex. Team DVCR).
 */
exports.ensurePrivateLeagueInviteCode = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const leagueId = String(request.data?.leagueId || '').trim();
  if (!leagueId) {
    throw new HttpsError('invalid-argument', 'Ligue manquante');
  }
  const db = getFirestore();
  const code = await _ensureInviteCodeForLeague(db, leagueId, request.auth.uid);
  return { success: true, code };
});
