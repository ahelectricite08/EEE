const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

function _name(raw, fallback) {
  const s = String(raw || '').trim();
  return s || fallback;
}

/**
 * Accepter une demande d’ami. Admin SDK : le client ne peut pas écrire
 * `users/{autre}` (rules isOwner).
 */
exports.acceptFriendRequest = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const uid = request.auth.uid;
  const requestId = String(request.data?.requestId || '').trim();
  if (!requestId) {
    throw new HttpsError('invalid-argument', 'Demande manquante');
  }

  const db = getFirestore();
  const reqRef = db.collection('friend_requests').doc(requestId);
  const snap = await reqRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Invitation introuvable');
  }
  const d = snap.data() || {};
  if (String(d.toUid || '') !== uid) {
    throw new HttpsError('permission-denied', 'Cette invitation n’est pas pour toi');
  }
  const fromUid = String(d.fromUid || '');
  if (!fromUid || fromUid === uid) {
    throw new HttpsError('failed-precondition', 'Invitation invalide');
  }
  if (d.status === 'accepted') {
    return { ok: true, already: true };
  }
  if (d.status && d.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Invitation déjà traitée');
  }

  const currentName = _name(request.data?.currentName, 'Membre');
  const otherName = _name(d.fromName, 'Membre');

  const batch = db.batch();
  batch.set(
    db.collection('users').doc(uid),
    {
      social: {
        friends: FieldValue.arrayUnion([fromUid]),
        friendNames: { [fromUid]: otherName },
      },
    },
    { merge: true },
  );
  batch.set(
    db.collection('users').doc(fromUid),
    {
      social: {
        friends: FieldValue.arrayUnion([uid]),
        friendNames: { [uid]: currentName },
      },
    },
    { merge: true },
  );
  batch.update(reqRef, {
    status: 'accepted',
    acceptedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { ok: true };
});

exports.removeFriend = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const uid = request.auth.uid;
  const otherUid = String(request.data?.otherUid || '').trim();
  if (!otherUid || otherUid === uid) {
    throw new HttpsError('invalid-argument', 'Ami invalide');
  }
  const db = getFirestore();
  const batch = db.batch();
  batch.set(
    db.collection('users').doc(uid),
    {
      social: {
        friends: FieldValue.arrayRemove([otherUid]),
        friendNames: { [otherUid]: FieldValue.delete() },
      },
    },
    { merge: true },
  );
  batch.set(
    db.collection('users').doc(otherUid),
    {
      social: {
        friends: FieldValue.arrayRemove([uid]),
        friendNames: { [uid]: FieldValue.delete() },
      },
    },
    { merge: true },
  );
  await batch.commit();
  return { ok: true };
});
