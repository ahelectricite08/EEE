const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { _requireAdminCall, _isUserAdmin } = require('./lib/admin_auth');

// ── Stats match : onWrite (stats figées) + filet nuit + clôture ──────────────
// Possession / minute / chrono = compteurs LiveHub. JAMAIS d’agrégat à chaque tick.

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

/** Compteurs live : UI = `live/current` (LiveHub). Pas d’invoc agrégat. */
const LIVE_COUNTER_KEYS = new Set([
  'possession1', 'possession2',
  'possessionMs1', 'possessionMs2',
  'possessionMillis1', 'possessionMillis2',
  'possessionActiveTeam',
  'minute', 'clock', 'chrono',
  'chronoBaseSeconds', 'chronoStartedAtMs', 'chronoRunning',
  'chronoDisplaySeconds', 'elapsedSeconds',
]);

function _isLiveCounterKey(key) {
  if (LIVE_COUNTER_KEYS.has(key)) return true;
  const n = String(key || '').toLowerCase();
  return n.startsWith('possession') || n.startsWith('chrono')
    || n === 'minute' || n === 'clock' || n === 'elapsedseconds';
}

function _omitLiveCountersFromStats(stats) {
  if (!stats || typeof stats !== 'object' || Array.isArray(stats)) return {};
  const out = {};
  for (const [k, v] of Object.entries(stats)) {
    if (_isLiveCounterKey(k)) continue;
    out[k] = v;
  }
  return out;
}

function _stableJson(value) {
  if (value === undefined || value === null) return 'null';
  if (typeof value === 'function') return 'null';
  if (typeof value.toMillis === 'function') return String(value.toMillis());
  if (typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map((item) => _stableJson(item)).join(',')}]`;
  }
  const keys = Object.keys(value).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${_stableJson(value[k])}`).join(',')}}`;
}

function _sheetFingerprint(data) {
  if (!data) return '';
  return _stableJson({
    state: data.state ?? '',
    previewEnabled: data.previewEnabled === true,
    stats: _omitLiveCountersFromStats(data.stats),
    events: Array.isArray(data.events) ? data.events : [],
  });
}

/** Champs figés sur `matches/{id}` — pas `stats` (écho preview) ni compteurs live. */
const MATCH_TRIGGER_KEYS = [
  'score1', 'score2', 'scoreHome', 'scoreAway', 'homeScore', 'awayScore',
  'status', 'events', 'liveEvents',
  'lineupHome', 'lineupAway', 'showLineupOnCard',
  'yellowHome', 'yellowAway', 'redHome', 'redAway',
  'team1', 'team2', 'date', 'competition',
  'manOfTheMatchName',
];

function _matchTriggerFingerprint(data) {
  if (!data) return '';
  const out = {};
  for (const key of MATCH_TRIGGER_KEYS) {
    out[key] = data[key] ?? null;
  }
  return _stableJson(out);
}

function _hasMeaningfulSheetChange(before, after) {
  return _sheetFingerprint(before) !== _sheetFingerprint(after);
}

function _hasMeaningfulMatchChange(before, after) {
  return _matchTriggerFingerprint(before) !== _matchTriggerFingerprint(after);
}

function _sheetWantsPreview(sheet) {
  if (!sheet || sheet.state === 'published') return false;
  return sheet.previewEnabled === true || sheet.state === 'preview';
}

async function _maybeApplyPreviewFromSheet(db, matchId) {
  if (!matchId) return false;
  const sheetSnap = await db.collection('match_stats').doc(matchId).get();
  if (!sheetSnap.exists) return false;
  const sheet = sheetSnap.data() || {};
  if (!_sheetWantsPreview(sheet)) return false;
  return _applyMatchStatsPreview(db, matchId, sheet);
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

  const showStats = _statsMapNonEmpty(stats) || events.length > 0;
  const unchanged =
    _stableJson(_omitLiveCountersFromStats(matchData.stats))
      === _stableJson(_omitLiveCountersFromStats(stats))
    && _stableJson(matchData.events) === _stableJson(events)
    && (matchData.statsState || '') === 'preview'
    && Boolean(matchData.showStats) === Boolean(showStats);
  if (unchanged) return false;

  await matchRef.set({
    stats,
    events,
    statsState: 'preview',
    showStats,
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

// Filet 1×/nuit (04:00 Europe/Paris). Plus « every 5 minutes » (~288 invoc/j).
// Agrégat principal = onWrite ci-dessous. Ne pas rétablir le cron 5 min.
exports.syncMatchStatsPreview = onSchedule(
  { schedule: '0 4 * * *', timeZone: 'Europe/Paris' },
  async () => {
    const db = getFirestore();
    const n = await _syncAllMatchStatsPreviews(db);
    console.log(`match_stats preview filet nuit: ${n} fiche(s)`);
  },
);

/** Fiche statisticien : tirs, buteurs, cartons, compo… — pas possession/chrono. */
exports.onMatchStatsSheetWritten = onDocumentWritten(
  'match_stats/{matchId}',
  async (event) => {
    const matchId = event.params?.matchId;
    if (!matchId) return;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return;
    if (!_sheetWantsPreview(after)) return;

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    if (!_hasMeaningfulSheetChange(before, after)) {
      console.log(`onMatchStatsSheetWritten skip live-counters ${matchId}`);
      return;
    }

    const db = getFirestore();
    const applied = await _applyMatchStatsPreview(db, matchId, after);
    console.log(`onMatchStatsSheetWritten ${matchId} applied=${applied}`);
  },
);

/** Direct (score/buteurs/cartons) ou write FFF sur la fiche match. */
exports.onMatchWrittenForStats = onDocumentWritten(
  'matches/{matchId}',
  async (event) => {
    const matchId = event.params?.matchId;
    if (!matchId) return;
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return;

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    if (!_hasMeaningfulMatchChange(before, after)) {
      return;
    }

    const db = getFirestore();
    const applied = await _maybeApplyPreviewFromSheet(db, matchId);
    if (applied) {
      console.log(`onMatchWrittenForStats ${matchId} applied=${applied}`);
    }
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

function _parseSeasonYears(seasonLabel) {
  const nums = [...String(seasonLabel || '').matchAll(/\d{4}/g)]
    .map((m) => parseInt(m[0], 10))
    .filter((n) => !Number.isNaN(n));
  if (nums.length >= 2) return [nums[0], nums[1]];
  if (nums.length === 1) return [nums[0], nums[0] + 1];
  return null;
}

function _dateInSeason(date, seasonLabel) {
  const years = _parseSeasonYears(seasonLabel);
  if (!years || !(date instanceof Date) || Number.isNaN(date.getTime())) return false;
  const start = new Date(years[0], 6, 1);
  const end = new Date(years[1], 6, 1);
  return date >= start && date < end;
}

function _matchDocBelongsToSeason(data, seasonLabel, activeSeasonLabel, implicitLegacySeasonLabel) {
  const target = String(seasonLabel || '').trim();
  if (!target) return false;
  const fs = String(data.fffSeason || '').trim();
  if (fs) return fs === target;
  const active = String(activeSeasonLabel || '').trim();
  if (data.manual === true && active && target === active) return true;
  const date = data.date?.toDate?.();
  if (date && active && target === active && _dateInSeason(date, target)) return true;
  return target === String(implicitLegacySeasonLabel || '').trim();
}

function _isSedanMatch(data) {
  const t1 = String(data.team1 || '').toUpperCase();
  const t2 = String(data.team2 || '').toUpperCase();
  return t1.includes('SEDAN') || t1.includes('CSSA')
    || t2.includes('SEDAN') || t2.includes('CSSA');
}

function _matchHasSeasonStatsContent(data, sheet) {
  const stats = sheet?.stats && typeof sheet.stats === 'object' ? sheet.stats : data.stats;
  if (_statsMapNonEmpty(stats)) return true;
  const events = _mergeGameEvents(
    Array.isArray(data.events) ? data.events : [],
    Array.isArray(data.liveEvents) ? data.liveEvents : [],
  );
  const sheetEvents = Array.isArray(sheet?.events) ? sheet.events : [];
  const merged = _mergeGameEvents(events, sheetEvents);
  if (merged.length > 0) return true;
  const cardFields = ['yellowHome', 'yellowAway', 'redHome', 'redAway'];
  return cardFields.some((k) => Number(data[k] || 0) > 0);
}

/** Admin : remet à zéro stats chiffrées + buteurs/cartons Sedan pour une saison. */
exports.resetSedanSeasonStats = onCall({ cors: true }, async (request) => {
  const { db, userDoc } = await _requireAdminCall(request);
  const season = String(request.data?.season || '').trim();
  if (!season) {
    throw new HttpsError('invalid-argument', 'Saison requise');
  }
  const activeSeasonLabel = String(request.data?.activeSeasonLabel || season).trim();
  const implicitLegacySeasonLabel = String(
    request.data?.implicitLegacySeasonLabel || activeSeasonLabel,
  ).trim();
  const uid = request.auth.uid;

  const [matchesSnap, sheetsSnap] = await Promise.all([
    db.collection('matches').orderBy('date', 'desc').limit(1200).get(),
    db.collection('match_stats').limit(1200).get(),
  ]);
  const sheetsById = new Map(sheetsSnap.docs.map((d) => [d.id, d.data()]));

  const targets = matchesSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    if (!_isSedanMatch(data)) return false;
    if (!_matchDocBelongsToSeason(
      data,
      season,
      activeSeasonLabel,
      implicitLegacySeasonLabel,
    )) {
      return false;
    }
    return _matchHasSeasonStatsContent(data, sheetsById.get(doc.id));
  });

  let resetMatches = 0;
  let resetSheets = 0;
  const batchSize = 400;
  let batch = db.batch();
  let ops = 0;

  const commitIfNeeded = async (force = false) => {
    if (ops === 0) return;
    if (!force && ops < batchSize) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  for (const doc of targets) {
    const data = doc.data() || {};
    const sheet = sheetsById.get(doc.id);
    const hadSheet = Boolean(sheet && _matchHasSeasonStatsContent(data, sheet));

    batch.set(doc.ref, {
      stats: {},
      events: [],
      liveEvents: FieldValue.delete(),
      showStats: false,
      statsState: 'none',
      statsPublishedAt: FieldValue.delete(),
      statsPreviewAt: FieldValue.delete(),
      yellowHome: 0,
      yellowAway: 0,
      redHome: 0,
      redAway: 0,
      seasonStatsResetAt: FieldValue.serverTimestamp(),
      seasonStatsResetBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    resetMatches += 1;
    ops += 1;

    if (hadSheet) {
      batch.set(db.collection('match_stats').doc(doc.id), {
        stats: {},
        events: [],
        state: 'draft',
        previewEnabled: false,
        publishedAt: FieldValue.delete(),
        seasonStatsResetAt: FieldValue.serverTimestamp(),
        seasonStatsResetBy: uid,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      }, { merge: true });
      resetSheets += 1;
      ops += 1;
    }

    await commitIfNeeded();
  }

  await commitIfNeeded(true);

  for (const doc of targets) {
    await _clearLiveHubStatsPreview(db, doc.id);
  }

  return {
    ok: true,
    season,
    resetMatches,
    resetSheets,
    resetBy: userDoc.id,
  };
});
