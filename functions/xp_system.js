const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const {
  _requireAdminCall, _isUserAdmin, CLIENT_AWARD_XP_EVENTS, _toSafeString, _pickPrimaryRole,
} = require('./lib/admin_auth');
const { _deleteFirestoreCollectionInBatches } = require('./lib/push_helpers');
const {
  _eventXpFromConfig, _computeLevel, _getXpConfig, _awardXpToUser,
} = require('./lib/xp_core');

// ── awardXp (onCall) — appelé depuis l'app pour chaque action utilisateur ─────
exports.awardXp = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }

  const eventType = request.data?.eventType;
  if (!eventType || typeof eventType !== 'string') {
    throw new HttpsError('invalid-argument', 'eventType manquant');
  }
  if (!CLIENT_AWARD_XP_EVENTS.has(eventType)) {
    throw new HttpsError('permission-denied', 'Type d\'événement XP non autorisé');
  }

  const db = getFirestore();
  const meta = {};
  if (request.data?.matchId) meta.matchId = String(request.data.matchId);
  return _awardXpToUser(db, request.auth.uid, eventType, meta);
});

// Legacy : remplacé par calculatePronoPoints + _awardXpToUser (collection predictions).
exports.onMatchFinished = onDocumentWritten('matches/{matchId}', async () => {});

// ── onXpUpdate — recalcule le niveau quand l'XP change ───────────────────────
exports.onXpUpdate = onDocumentWritten('users/{uid}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after || !before) return;

  const xpBefore = before.xp ?? 0;
  const xpAfter  = after.xp  ?? 0;
  if (xpBefore === xpAfter) return; // Pas de changement XP

  const db  = getFirestore();
  const uid = event.params.uid;
  const { levels } = await _getXpConfig(db);

  const correctLevel = _computeLevel(xpAfter, levels);
  if (correctLevel === (after.level ?? 1)) return; // Niveau déjà correct

  await db.collection('users').doc(uid).update({ level: correctLevel, updatedAt: Timestamp.now() });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SYSTÈME DE PARRAINAGE
// ═══════════════════════════════════════════════════════════════════════════════

// ── Génère un code de parrainage à la création du document user ───────────────
exports.onUserDocCreated = onDocumentCreated('users/{uid}', async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const uid  = event.params.uid;
  const db = getFirestore();
  const code = data.referralCode || ('DVCR' + uid.slice(0, 4).toUpperCase() + _randomStr(4));
  const emailLower = _toSafeString(data.emailLower || data.email).toLowerCase();

  await event.data.ref.set({
    referralCode: data.referralCode || code,
    referredBy: data.referredBy ?? null,
    createdAt: data.createdAt ?? Timestamp.now(),
    emailLower: emailLower || null,
  }, { merge: true });
});

function _randomStr(len) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let result  = '';
  for (let i = 0; i < len; i++) result += chars[Math.floor(Math.random() * chars.length)];
  return result;
}

// ── useReferralCode (onCall) — valide et applique un code de parrainage ───────
exports.useReferralCode = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');

  const uid  = request.auth.uid;
  const code = (request.data?.code ?? '').trim().toUpperCase();
  if (!code) throw new Error('Code manquant');

  const db = getFirestore();

  // Vérifie que l'utilisateur n'a pas déjà utilisé un code
  const selfSnap = await db.collection('users').doc(uid).get();
  if (!selfSnap.exists) throw new Error('Utilisateur introuvable');
  const selfData = selfSnap.data();

  if (selfData.referredBy != null) {
    throw new Error('Tu as déjà utilisé un code de parrainage');
  }
  if (selfData.referralCode === code) {
    throw new Error('Tu ne peux pas utiliser ton propre code');
  }

  // Trouve le parrain
  const referrerSnap = await db.collection('users')
    .where('referralCode', '==', code)
    .limit(1)
    .get();

  if (referrerSnap.empty) throw new Error('Code invalide');

  const referrerDoc  = referrerSnap.docs[0];
  const referrerUid  = referrerDoc.id;
  const referrerData = referrerDoc.data();

  const { events, levels } = await _getXpConfig(db);
  const xpParrain = _eventXpFromConfig(events, 'referral_sent').xp;
  const xpFilleul = _eventXpFromConfig(events, 'referral_used').xp;

  const batch = db.batch();

  // Filleul — marque comme parrainé + XP
  const newXpFilleul    = (selfData.xp ?? 0) + xpFilleul;
  const newLevelFilleul = _computeLevel(newXpFilleul, levels);
  batch.update(db.collection('users').doc(uid), {
    referredBy: referrerUid,
    xp:         newXpFilleul,
    level:      newLevelFilleul,
    updatedAt:  Timestamp.now(),
  });
  batch.set(db.collection('users').doc(uid).collection('xp_log').doc(), {
    eventType: 'referral_used', xpAwarded: xpFilleul, timestamp: Timestamp.now(),
  });

  // Parrain — XP
  const newXpParrain    = (referrerData.xp ?? 0) + xpParrain;
  const newLevelParrain = _computeLevel(newXpParrain, levels);
  batch.update(db.collection('users').doc(referrerUid), {
    xp:        newXpParrain,
    level:     newLevelParrain,
    'stats.referral_sent': FieldValue.increment(1),
    updatedAt: Timestamp.now(),
  });
  batch.set(db.collection('users').doc(referrerUid).collection('xp_log').doc(), {
    eventType: 'referral_sent', xpAwarded: xpParrain,
    referredUid: uid, timestamp: Timestamp.now(),
  });

  // Compteur parrainage global
  batch.set(db.collection('referrals').doc(), {
    referrerUid, referredUid: uid, code,
    xpParrain, xpFilleul,
    createdAt: Timestamp.now(),
  });

  await batch.commit();

  return {
    success:        true,
    xpAwarded:      xpFilleul,
    referrerName:   referrerData.displayName ?? 'Supporter',
  };
});

// ── getReferralStats (onCall) — stats de parrainage pour le profil ─────────────
exports.getReferralStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const uid = request.auth.uid;
  const db  = getFirestore();

  const [userSnap, referralsSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('referrals').where('referrerUid', '==', uid).get(),
  ]);

  const userData = userSnap.data() ?? {};

  return {
    referralCode:  userData.referralCode ?? '',
    referredBy:    userData.referredBy   ?? null,
    referralCount: referralsSnap.size,
    totalXpEarned: referralsSnap.size * (DEFAULT_XP.referral_sent),
  };
});

// ── Classement hebdomadaire XP (vendredi minuit) ───────────────────────────────
exports.weeklyXpLeaderboard = onSchedule('every friday 23:00', async () => {
  const db   = getFirestore();
  const snap = await db.collection('users')
    .orderBy('xp', 'desc')
    .limit(10)
    .get();

  const top = snap.docs.map((d, i) => ({
    rank:        i + 1,
    uid:         d.id,
    displayName: d.data().displayName ?? 'Supporter',
    xp:          d.data().xp ?? 0,
    level:       d.data().level ?? 1,
  }));

  await db.collection('app_settings').doc('weekly_leaderboard').set({
    top,
    updatedAt: Timestamp.now(),
    weekOf:    new Date().toISOString().split('T')[0],
  });

  console.log(`Classement hebdo mis à jour : ${top.length} entrées`);
});


/**
 * Somme des points `prono_leaderboard` des membres → `private_leagues.rankingStats`
 * pour classement global des ligues (app client). Déclenché uniquement depuis l’admin.
 */
async function _recomputeLeaguePowerRankingsCore(db) {
  const leaguesSnap = await db.collection('private_leagues').limit(500).get();
  let processed = 0;
  for (const doc of leaguesSnap.docs) {
    const data = doc.data() || {};
    const memberIds = (Array.isArray(data.memberIds) ? data.memberIds : [])
      .map((id) => String(id))
      .filter((id) => id.length > 0);
    let sum = 0;
    for (let i = 0; i < memberIds.length; i += 10) {
      const chunk = memberIds.slice(i, i + 10);
      if (!chunk.length) continue;
      const lb = await db
        .collection('prono_leaderboard')
        .where(FieldPath.documentId(), 'in', chunk)
        .get();
      lb.forEach((d) => {
        sum += Number((d.data() || {}).points || 0);
      });
    }
    await doc.ref.set({
      rankingStats: {
        memberPointsSum: sum,
        memberCount: memberIds.length,
        updatedAt: FieldValue.serverTimestamp(),
      },
    }, { merge: true });
    processed++;
    if (processed % 25 === 0) {
      await new Promise((r) => setTimeout(r, 30));
    }
  }
  console.log(`adminRecomputeLeaguePowerRankings: ${processed} ligues`);
  return processed;
}

/** Callable admin (nouveau nom : impossible de réutiliser l’ancien ID `recomputeLeaguePowerRankings` après un onSchedule). */
exports.adminRecomputeLeaguePowerRankings = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const processed = await _recomputeLeaguePowerRankingsCore(db);
  return { success: true, leaguesProcessed: processed };
});

// ═══════════════════════════════════════════════════════════════════════════════
// Admin Center — custom claims + competition engine (saisons)
// ═══════════════════════════════════════════════════════════════════════════════

function _rolesArrayFromUserData(data) {
  if (!data) return [];
  if (Array.isArray(data.roles)) return data.roles.map((r) => String(r));
  if (data.role) return [String(data.role)];
  return [];
}

function _rolesSignature(roles) {
  return [...roles].map(String).sort().join(',');
}

/** Sync [dvcr_admin] quand `users/{uid}.roles` change (claims pour Firestore rules). */
exports.syncDvcrAuthClaims = onDocumentWritten('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const beforeData = event.data?.before?.exists ? event.data.before.data() : null;
  const afterData = event.data?.after?.exists ? event.data.after.data() : null;
  const before = _rolesArrayFromUserData(beforeData);
  const after = _rolesArrayFromUserData(afterData);
  if (_rolesSignature(before) === _rolesSignature(after)) return;
  const isAdmin = after.includes('admin');
  try {
    await getAuth().setCustomUserClaims(uid, { dvcr_admin: isAdmin });
  } catch (e) {
    console.error('syncDvcrAuthClaims', uid, e && e.message ? e.message : e);
  }
});

/** Callable : recalculer les claims depuis Firestore (après login admin). */
exports.refreshDvcrAuthClaims = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }
  const uid = request.auth.uid;
  const db = getFirestore();
  const snap = await db.collection('users').doc(uid).get();
  const roles = _rolesArrayFromUserData(snap.data());
  const isAdmin = roles.includes('admin');
  await getAuth().setCustomUserClaims(uid, { dvcr_admin: isAdmin });
  return { ok: true, dvcr_admin: isAdmin };
});

/**
 * Admin : supprime un utilisateur Firebase Auth + doc `users/{uid}` et sous-collections connues.
 * Ne peut pas supprimer son propre compte.
 */
exports.adminDeleteAuthUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }
  const db = getFirestore();
  const callerSnap = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(callerSnap)) {
    throw new HttpsError('permission-denied', 'Réservé aux administrateurs');
  }
  const targetUid = (request.data?.uid || '').toString().trim();
  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'uid manquant');
  }
  if (targetUid === request.auth.uid) {
    throw new HttpsError('invalid-argument', 'Impossible de supprimer votre propre compte');
  }

  try {
    await getAuth().deleteUser(targetUid);
  } catch (e) {
    const code = e && e.errorInfo && e.errorInfo.code ? e.errorInfo.code : '';
    if (code !== 'auth/user-not-found') {
      console.error('adminDeleteAuthUser:auth', targetUid, e);
      throw new HttpsError(
        'internal',
        (e && e.message) ? String(e.message) : 'Erreur suppression compte Auth',
      );
    }
  }

  const userRef = db.collection('users').doc(targetUid);
  const subs = ['favorites', 'xp_log', 'badge_log'];
  for (const sub of subs) {
    await _deleteFirestoreCollectionInBatches(db, userRef.collection(sub));
  }
  try {
    await userRef.delete();
  } catch (e) {
    console.error('adminDeleteAuthUser:firestore', targetUid, e);
  }
  return { ok: true };
});

/** Archive une saison compétition (`seasons.status` → archived). Admin uniquement. */
exports.archiveCompetitionSeason = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }
  const db = getFirestore();
  const adminSnap = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(adminSnap)) {
    throw new HttpsError('permission-denied', 'Réservé aux administrateurs');
  }
  const seasonId = (request.data?.seasonId || '').toString().trim();
  if (!seasonId) {
    throw new HttpsError('invalid-argument', 'seasonId manquant');
  }
  const ref = db.collection('seasons').doc(seasonId);
  const s = await ref.get();
  if (!s.exists) {
    throw new HttpsError('not-found', 'Saison introuvable');
  }
  await ref.set(
    {
      status: 'archived',
      archivedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { ok: true };
});
