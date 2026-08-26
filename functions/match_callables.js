const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { _isUserAdmin } = require('./lib/admin_auth');
const { _sendFcm, _sendManualBroadcast } = require('./lib/push_helpers');
const { fcmChannelBlocks } = require('./notification_push');

// ── Rappels match Sedan/CSSA : uniquement depuis l’admin (pas de cron = moins de coût) ─
exports.getMatchReminderCandidates = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const now = Timestamp.now();
  const snap = await db.collection('matches')
    .where('status', '==', 'upcoming')
    .where('date', '>', now)
    .orderBy('date')
    .limit(80)
    .get();

  const matches = [];
  for (const doc of snap.docs) {
    const m = doc.data();
    if (!_isSedanCssaReminderMatch(m)) continue;
    const kick = m.date?.toMillis?.() ?? null;
    matches.push({
      matchId: doc.id,
      team1: String(m.team1 ?? ''),
      team2: String(m.team2 ?? ''),
      kickoffMs: kick,
      suggestedTitle: _defaultMatchReminderTitle(),
      suggestedBody: _defaultMatchReminderBody(m),
    });
    if (matches.length >= 20) break;
  }

  return { matches };
});

exports.sendMatchReminderManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const payload = request.data || {};
  const matchId = typeof payload.matchId === 'string' ? payload.matchId.trim() : '';
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }

  const titleOverride = typeof payload.title === 'string' ? payload.title.trim() : '';
  const bodyOverride = typeof payload.body === 'string' ? payload.body.trim() : '';

  const docRef = db.collection('matches').doc(matchId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'Match introuvable');
  }
  const m = doc.data();
  if (m.status !== 'upcoming') {
    throw new HttpsError('failed-precondition', 'Le match doit être à venir (upcoming)');
  }
  if (!_isSedanCssaReminderMatch(m)) {
    throw new HttpsError('failed-precondition', 'Réservé aux matchs impliquant Sedan / CSSA');
  }

  const finalTitle = titleOverride || _defaultMatchReminderTitle();
  const finalBody = bodyOverride || _defaultMatchReminderBody(m);
  const targetPlatform = String(payload.targetPlatform || 'all').trim().toLowerCase();

  const messageBase = {
    notification: {
      title: finalTitle,
      body: finalBody,
    },
    data: { type: 'match_reminder', matchId },
    ...fcmChannelBlocks('dvcr_notifications'),
  };

  const broadcast = await _sendManualBroadcast(
    db,
    messageBase,
    targetPlatform,
    'all',
    finalTitle,
    null,
  );
  if (broadcast.sentCount === 0) {
    throw new HttpsError(
      'failed-precondition',
      String(broadcast.mode || '').startsWith('topic_')
        ? 'Envoi topic bloqué (maintenance) ou échec FCM'
        : 'Aucun appareil iOS/Android trouvé pour cette cible',
    );
  }

  const logId = `reminder_admin_${matchId}_${Date.now()}`;
  await db.collection('match_notifs_sent').doc(logId).set({
    sentAt: Timestamp.now(),
    type: 'reminder_admin_manual',
    title: finalTitle,
    body: finalBody,
    matchId,
    sentByUid: request.auth.uid,
    targetPlatform,
    sendMode: broadcast.mode,
    recipientsCount: broadcast.sentCount,
    ...(broadcast.iosCount != null ? { iosCount: broadcast.iosCount } : {}),
    ...(broadcast.androidCount != null ? { androidCount: broadcast.androidCount } : {}),
  });

  console.log(
    `[Reminder manual] ${finalTitle} — ${matchId} (${broadcast.mode}, ${broadcast.sentCount})`,
  );
  return {
    success: true,
    matchId,
    sendMode: broadcast.mode,
    recipientsCount: broadcast.sentCount,
  };
});

// ── Notif compositions disponibles (déclenchée manuellement par l'admin) ─────
exports.notifyLineups = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const payload = request.data || {};
  const matchId = typeof payload.matchId === 'string' ? payload.matchId.trim() : '';
  const titleOverride = typeof payload.title === 'string' ? payload.title.trim() : '';
  const bodyOverride = typeof payload.body === 'string' ? payload.body.trim() : '';

  let team1 = '';
  let team2 = '';
  if (matchId) {
    const matchSnap = await db.collection('matches').doc(matchId).get();
    if (matchSnap.exists) {
      team1 = (matchSnap.data().team1 ?? '').toString().trim();
      team2 = (matchSnap.data().team2 ?? '').toString().trim();
    }
  }

  const matchLine = team1 && team2 ? `${team1} — ${team2}` : '';
  const finalTitle = titleOverride || '📋 Compositions disponibles !';
  const finalBody = bodyOverride ||
    (matchLine
      ? `Les compos de ${matchLine} sont là — viens les consulter 🔥`
      : 'Les compositions des deux équipes sont disponibles — viens les consulter 🔥');

  await _sendFcm(db, {
    topic: 'dvcr_live',
    notification: { title: finalTitle, body: finalBody },
    data: {
      type: 'lineups_available',
      ...(matchId ? { matchId } : {}),
    },
    ...fcmChannelBlocks('dvcr_live'),
  }, 'lineups notify');

  console.log(`[notifyLineups] sent: ${finalTitle} — matchId=${matchId || '—'}`);
  return { success: true };
});
