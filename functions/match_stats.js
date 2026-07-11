const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { _requireAdminCall } = require('./lib/admin_auth');

// ── Stats match : preview 5 min + clôture + migration ────────────────────────

function _canWriteMatchStats(userDoc, auth) {
  if (auth?.token?.dvcr_admin === true) return true;
  if (_isUserAdmin(userDoc)) return true;
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  const roles = Array.isArray(data.roles)
    ? data.roles
    : (data.role ? [data.role] : []);
  return roles.includes('statisticien') || roles.includes('community_manager');
}

function _statsMapNonEmpty(stats) {
  return stats && typeof stats === 'object' && Object.keys(stats).length > 0;
}

/** Fusionne deux listes d’événements (live + fiche match) sans doublons. */
function _mergeGameEvents(a, b) {
  const listA = Array.isArray(a) ? a : [];
  const listB = Array.isArray(b) ? b : [];
  if (listA.length === 0) return listB;
  if (listB.length === 0) return listA;
  const seen = new Set();
  const out = [];
  for (const e of [...listA, ...listB]) {
    if (!e || typeof e !== 'object') continue;
    const type = String(e.type || '').toLowerCase();
    const key = type === 'substitution'
      ? `${type}|${e.minute}|${e.playerOut}|${e.playerIn}|${e.team}`.toLowerCase()
      : `${type}|${e.minute}|${e.player}|${e.team}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(e);
  }
  out.sort((x, y) => (Number(x.minute) || 0) - (Number(y.minute) || 0));
  return out;
}

async function _applyMatchStatsPreview(db, sheetId, sheet) {
  const matchId = sheet.matchId || sheetId;
  const stats = sheet.stats || {};
  const sheetEvents = Array.isArray(sheet.events) ? sheet.events : [];
  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) return false;

  const matchData = matchSnap.data() || {};
  const matchEvents = Array.isArray(matchData.events) ? matchData.events : [];
  const legacyLive = Array.isArray(matchData.liveEvents) ? matchData.liveEvents : [];
  const events = _mergeGameEvents(
    _mergeGameEvents(matchEvents, legacyLive),
    sheetEvents,
  );

  await matchRef.set({
    stats,
    events,
    statsState: 'preview',
    showStats: _statsMapNonEmpty(stats) || events.length > 0,
    statsPreviewAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const matchDate = matchSnap.data()?.date?.toMillis?.() ?? 0;
  const now = Date.now();
  const isToday = matchDate > 0 && Math.abs(matchDate - now) < 48 * 3600000;
  if (isToday && sheet.previewEnabled === true) {
    await _syncLiveHubStatsPreview(db, matchId, stats, events);
  }
  return true;
}

async function _syncLiveHubStatsPreview(db, matchId, stats, events) {
  const liveRef = db.collection('live').doc('current');
  const liveSnap = await liveRef.get();
  if (!liveSnap.exists) return;
  const live = liveSnap.data() || {};
  const liveMid = (live.matchId ?? '').toString().trim();
  const previewMid = (live.statsPreviewMatchId ?? '').toString().trim();
  if (liveMid !== matchId && previewMid !== matchId) return;

  const matchSnap = await db.collection('matches').doc(matchId).get();
  const matchData = matchSnap.exists ? matchSnap.data() : {};

  const patch = {
    statsEnabled: true,
    statsPreviewMatchId: matchId,
    statsPreviewUpdatedAt: FieldValue.serverTimestamp(),
  };
  if (_statsMapNonEmpty(stats)) {
    patch.statsPreview = stats;
    patch.stats = stats;
  }
  // Ne pas écraser score/cartons/events du live en cours — ces champs sont gérés
  // exclusivement par le direct (notifyGoal se déclencherait et enverrait de faux buts).
  await liveRef.set(patch, { merge: true });
}

async function _clearLiveHubStatsPreview(db, matchId) {
  const liveRef = db.collection('live').doc('current');
  const liveSnap = await liveRef.get();
  if (!liveSnap.exists) return;
  const live = liveSnap.data() || {};
  const liveMid = (live.matchId ?? '').toString().trim();
  const previewMid = (live.statsPreviewMatchId ?? '').toString().trim();
  if (liveMid !== matchId && previewMid !== matchId) return;

  await liveRef.set({
    statsPreview: FieldValue.delete(),
    statsPreviewMatchId: FieldValue.delete(),
    statsPreviewUpdatedAt: FieldValue.delete(),
  }, { merge: true });
}

async function _ensureMatchStatsSheetFromMatch(db, matchId) {
  const sheetRef = db.collection('match_stats').doc(matchId);
  const existing = await sheetRef.get();
  if (existing.exists) return existing.data();

  const matchSnap = await db.collection('matches').doc(matchId).get();
  if (!matchSnap.exists) return null;
  const m = matchSnap.data() || {};
  const stats = m.stats && typeof m.stats === 'object' ? m.stats : {};
  const events = Array.isArray(m.events) ? m.events : [];

  let state = 'draft';
  const statsState = (m.statsState ?? '').toString();
  if (statsState === 'published' || m.showStats === true) state = 'published';
  else if (statsState === 'preview') state = 'preview';

  const payload = {
    matchId,
    team1: m.team1 ?? '',
    team2: m.team2 ?? '',
    date: m.date ?? null,
    competition: m.competition ?? '',
    stats,
    events,
    state,
    previewEnabled: state === 'preview',
    statsVersion: 1,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await sheetRef.set(payload, { merge: true });
  return payload;
}

async function _finalizeMatchStatsInternal(db, matchId, uid) {
  const sheetRef = db.collection('match_stats').doc(matchId);
  const sheetSnap = await sheetRef.get();
  if (!sheetSnap.exists) {
    throw new HttpsError('not-found', 'Fiche stats introuvable');
  }
  const sheet = sheetSnap.data();
  const stats = sheet.stats || {};
  const sheetEvents = Array.isArray(sheet.events) ? sheet.events : [];
  const hasContent = _statsMapNonEmpty(stats) || sheetEvents.length > 0;

  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  const matchData = matchSnap.exists ? matchSnap.data() : {};
  const matchEvents = Array.isArray(matchData?.events) ? matchData.events : [];
  const legacyLive = Array.isArray(matchData?.liveEvents) ? matchData.liveEvents : [];
  const events = _mergeGameEvents(
    _mergeGameEvents(matchEvents, legacyLive),
    sheetEvents,
  );

  const patch = {
    stats,
    events,
    statsState: 'published',
    showStats: hasContent,
    statsPublishedAt: FieldValue.serverTimestamp(),
  };
  const s1 = matchData?.score1 ?? matchData?.homeScore;
  const s2 = matchData?.score2 ?? matchData?.awayScore;
  if (s1 != null && s2 != null && matchData?.status !== 'finished') {
    patch.status = 'finished';
  }
  await matchRef.set(patch, { merge: true });

  await sheetRef.set({
    state: 'published',
    previewEnabled: false,
    publishedAt: FieldValue.serverTimestamp(),
    statsVersion: (sheet.statsVersion || 0) + 1,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: uid,
  }, { merge: true });

  await _clearLiveHubStatsPreview(db, matchId);

  return { ok: true, matchId, published: hasContent };
}

async function _syncAllMatchStatsPreviews(db) {
  const snap = await db.collection('match_stats')
    .where('previewEnabled', '==', true)
    .get();
  let n = 0;
  for (const doc of snap.docs) {
    const sheet = doc.data();
    if (sheet.state === 'published') continue;
    if (await _applyMatchStatsPreview(db, doc.id, sheet)) n += 1;
  }
  return n;
}

exports.syncMatchStatsPreview = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Europe/Paris' },
  async () => {
    const db = getFirestore();
    const n = await _syncAllMatchStatsPreviews(db);
    console.log(`match_stats preview sync: ${n} fiche(s)`);
  },
);

exports.syncMatchStatsPreviewManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const matchId = (request.data?.matchId ?? '').toString().trim();
  if (matchId) {
    const sheet = await db.collection('match_stats').doc(matchId).get();
    if (!sheet.exists) {
      throw new HttpsError('not-found', 'Fiche stats introuvable');
    }
    await _applyMatchStatsPreview(db, matchId, sheet.data());
    return { ok: true, count: 1 };
  }
  const n = await _syncAllMatchStatsPreviews(db);
  return { ok: true, count: n };
});

exports.finalizeMatchStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const matchId = (request.data?.matchId ?? '').toString().trim();
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }

  return _finalizeMatchStatsInternal(db, matchId, request.auth.uid);
});

exports.setMatchStatsPublicationState = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const matchId = (request.data?.matchId ?? '').toString().trim();
  const state = (request.data?.state ?? '').toString().trim();
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }
  if (!['draft', 'preview', 'published', 'none'].includes(state)) {
    throw new HttpsError('invalid-argument', 'state invalide');
  }

  if (state === 'published') {
    await _ensureMatchStatsSheetFromMatch(db, matchId);
    return _finalizeMatchStatsInternal(db, matchId, request.auth.uid);
  }

  await _ensureMatchStatsSheetFromMatch(db, matchId);
  const sheetRef = db.collection('match_stats').doc(matchId);
  const sheetSnap = await sheetRef.get();
  const sheet = sheetSnap.exists ? sheetSnap.data() : {};
  const matchSnap = await db.collection('matches').doc(matchId).get();
  const matchData = matchSnap.exists ? matchSnap.data() : {};

  const stats = sheet.stats && typeof sheet.stats === 'object'
    ? sheet.stats
    : (matchData?.stats && typeof matchData.stats === 'object' ? matchData.stats : {});
  const events = Array.isArray(sheet.events)
    ? sheet.events
    : (Array.isArray(matchData?.events) ? matchData.events : []);
  const hasContent = _statsMapNonEmpty(stats) || events.length > 0;

  if (state === 'preview') {
    const previewState = hasContent ? 'preview' : 'draft';
    await sheetRef.set({
      stats,
      events,
      state: previewState,
      previewEnabled: hasContent,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    }, { merge: true });

    await db.collection('matches').doc(matchId).set({
      stats,
      events,
      statsState: previewState,
      showStats: hasContent,
      statsPreviewAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (hasContent) {
      await _syncLiveHubStatsPreview(db, matchId, stats, events);
    } else {
      await _clearLiveHubStatsPreview(db, matchId);
    }

    return { ok: true, matchId, state: previewState };
  }

  // draft / none → à saisir
  await sheetRef.set({
    stats,
    events,
    state: 'draft',
    previewEnabled: false,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  }, { merge: true });

  await db.collection('matches').doc(matchId).set({
    stats,
    events,
    statsState: 'draft',
    showStats: false,
  }, { merge: true });

  await _clearLiveHubStatsPreview(db, matchId);

  return { ok: true, matchId, state: 'draft' };
});

exports.reopenMatchStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const matchId = (request.data?.matchId ?? '').toString().trim();
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }

  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) {
    throw new HttpsError('not-found', 'Match introuvable');
  }
  const matchData = matchSnap.data();

  const sheetRef = db.collection('match_stats').doc(matchId);
  const sheetSnap = await sheetRef.get();
  const sheetState = sheetSnap.exists ? sheetSnap.data()?.state : null;
  const matchStatsState = matchData?.statsState?.toString();

  if (sheetState !== 'published' && matchStatsState !== 'published') {
    throw new HttpsError(
      'failed-precondition',
      'Ce match n\'est pas clôturé',
    );
  }

  const stats = sheetSnap.exists
    ? (sheetSnap.data()?.stats || matchData.stats || {})
    : (matchData.stats || {});
  const events = sheetSnap.exists
    ? (Array.isArray(sheetSnap.data()?.events)
      ? sheetSnap.data().events
      : (Array.isArray(matchData.events) ? matchData.events : []))
    : (Array.isArray(matchData.events) ? matchData.events : []);
  const hasContent = _statsMapNonEmpty(stats) || events.length > 0;

  await sheetRef.set({
    matchId,
    team1: matchData.team1 ?? '',
    team2: matchData.team2 ?? '',
    date: matchData.date ?? null,
    competition: matchData.competition ?? '',
    stats,
    events,
    state: hasContent ? 'preview' : 'draft',
    previewEnabled: hasContent,
    reopenedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  }, { merge: true });

  await matchRef.set({
    stats,
    events,
    statsState: hasContent ? 'preview' : 'draft',
    showStats: hasContent,
    statsPreviewAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const sheetForPreview = {
    matchId,
    stats,
    events,
    previewEnabled: hasContent,
    state: hasContent ? 'preview' : 'draft',
  };
  await _applyMatchStatsPreview(db, matchId, sheetForPreview);

  return { ok: true, matchId, reopened: true };
});

exports.migrateMatchStatsFromMatches = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const snap = await db.collection('matches').limit(800).get();
  let migrated = 0;
  const batchSize = 400;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const stats = d.stats;
    if (!_statsMapNonEmpty(stats)) continue;

    const events = Array.isArray(d.events) ? d.events : [];
    let state = 'draft';
    if (d.statsState === 'published' || d.showStats === true) state = 'published';
    else if (d.statsState === 'preview') state = 'preview';

    const ref = db.collection('match_stats').doc(doc.id);
    batch.set(ref, {
      matchId: doc.id,
      team1: d.team1 ?? '',
      team2: d.team2 ?? '',
      date: d.date ?? null,
      competition: d.competition ?? '',
      stats,
      events,
      state,
      previewEnabled: state === 'preview',
      statsVersion: 1,
      migratedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (!d.statsState) {
      batch.set(doc.ref, {
        statsState: state === 'published' ? 'published' : 'none',
      }, { merge: true });
    }

    migrated += 1;
    ops += 1;
    if (ops >= batchSize) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  return { ok: true, migrated };
});
