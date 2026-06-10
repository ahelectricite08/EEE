
// ─────────────────────────────────────────────────────────────────────────────
// ESTI'DVCR — Calcul automatique des points de pronos tournoi
// ─────────────────────────────────────────────────────────────────────────────

/** Détermine la clé de sous-collection pour le classement d'un match.
 *  - matchDay défini → String(matchDay) ex: "1", "2"
 *  - phase finale (pas de matchDay, champ phase contient final/demi/quart) → "finale"
 *  - sinon → null (pas de classement par journée)
 */
function _getMatchDayKey(matchData) {
  if (matchData.matchDay != null) return String(matchData.matchDay);
  if (matchData.isFinale === true) return 'finale';
  const phase = (matchData.phase || '').toLowerCase();
  if (phase.includes('final') || phase.includes('finale') ||
      phase.includes('demi') || phase.includes('quart') ||
      phase.includes('8e') || phase.includes('huitieme') ||
      phase.includes('knockout')) {
    return 'finale';
  }
  return null;
}

/**
 * Trigger Firestore : calcule les points quand un match passe en status=finished.
 * Met à jour le classement général + classement par journée / phase finale.
 */
exports.recalculateTournamentMatchScoring = onDocumentWritten(
  'tournaments/{tournamentId}/matches/{matchId}',
  async (event) => {
    const after  = event.data.after;
    const before = event.data.before;
    if (!after.exists) return null;

    const matchData = after.data();
    const wasFinished = before.exists && before.data().status === 'finished';
    if (matchData.status !== 'finished' || wasFinished) return null;
    const result1 = matchData.result1;
    const result2 = matchData.result2;
    if (result1 == null || result2 == null) return null;

    const { tournamentId, matchId } = event.params;
    const db = getFirestore();
    const tournamentRef = db.collection('tournaments').doc(tournamentId);
    const dayKey = _getMatchDayKey(matchData);

    const predsSnap = await tournamentRef.collection('predictions')
      .where('matchId', '==', matchId)
      .get();
    if (predsSnap.empty) return null;

    const leaderboardUpdates = {};
    const predsBatch = db.batch();

    for (const predDoc of predsSnap.docs) {
      const pred = predDoc.data();
      const uid = pred.uid;
      if (!uid) continue;

      let points = 0;
      if (pred.score1 === result1 && pred.score2 === result2) {
        points = 3;
      } else {
        const pw = pred.score1 > pred.score2 ? 1 : pred.score1 < pred.score2 ? -1 : 0;
        const rw = result1 > result2 ? 1 : result1 < result2 ? -1 : 0;
        if (pw === rw) points = 1;
      }
      predsBatch.update(predDoc.ref, { points });

      if (!leaderboardUpdates[uid]) {
        leaderboardUpdates[uid] = { uid, displayName: pred.displayName || 'Membre', points: 0, exactScores: 0 };
      }
      leaderboardUpdates[uid].points += points;
      if (points === 3) leaderboardUpdates[uid].exactScores += 1;
    }
    await predsBatch.commit();

    const lbBatch = db.batch();
    for (const [uid, data] of Object.entries(leaderboardUpdates)) {
      lbBatch.set(
        tournamentRef.collection('leaderboard').doc(uid),
        { uid: data.uid, displayName: data.displayName, points: FieldValue.increment(data.points), exactScores: FieldValue.increment(data.exactScores), updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      if (dayKey) {
        lbBatch.set(
          tournamentRef.collection('leaderboard_matchday').doc(dayKey).collection('entries').doc(uid),
          { uid: data.uid, displayName: data.displayName, points: FieldValue.increment(data.points), exactScores: FieldValue.increment(data.exactScores), updatedAt: FieldValue.serverTimestamp() },
          { merge: true }
        );
      }
    }
    await lbBatch.commit();
    await _recalculateTournamentRanks(tournamentRef);
    return null;
  }
);

/**
 * Recalcule tous les points depuis zéro pour un tournoi.
 * Callable — param : { tournamentId: string }
 */
exports.recalculateWorldCupLeaderboard = onCall(async (request) => {
  const db = getFirestore();
  const tournamentId = request.data.tournamentId || 'worldcup2026';
  const tournamentRef = db.collection('tournaments').doc(tournamentId);

  const matchesSnap = await tournamentRef.collection('matches')
    .where('status', '==', 'finished')
    .get();

  const allUpdates = {};

  for (const matchDoc of matchesSnap.docs) {
    const m = matchDoc.data();
    if (m.result1 == null || m.result2 == null) continue;
    const dayKey = _getMatchDayKey(m);

    const predsSnap = await tournamentRef.collection('predictions')
      .where('matchId', '==', matchDoc.id)
      .get();

    const predsBatch = db.batch();
    for (const predDoc of predsSnap.docs) {
      const pred = predDoc.data();
      const uid = pred.uid;
      if (!uid) continue;

      let points = 0;
      if (pred.score1 === m.result1 && pred.score2 === m.result2) {
        points = 3;
      } else {
        const pw = pred.score1 > pred.score2 ? 1 : pred.score1 < pred.score2 ? -1 : 0;
        const rw = m.result1 > m.result2 ? 1 : m.result1 < m.result2 ? -1 : 0;
        if (pw === rw) points = 1;
      }
      predsBatch.update(predDoc.ref, { points });

      if (!allUpdates[uid]) {
        allUpdates[uid] = { displayName: pred.displayName || 'Membre', points: 0, exactScores: 0, dayPoints: {} };
      }
      allUpdates[uid].points += points;
      if (points === 3) allUpdates[uid].exactScores += 1;
      if (dayKey) {
        if (!allUpdates[uid].dayPoints[dayKey]) allUpdates[uid].dayPoints[dayKey] = { points: 0, exactScores: 0 };
        allUpdates[uid].dayPoints[dayKey].points += points;
        if (points === 3) allUpdates[uid].dayPoints[dayKey].exactScores += 1;
      }
    }
    await predsBatch.commit();
  }

  const lbSnap = await tournamentRef.collection('leaderboard').get();
  const resetBatch = db.batch();
  for (const doc of lbSnap.docs) resetBatch.update(doc.ref, { points: 0, exactScores: 0 });
  await resetBatch.commit();

  const finalBatch = db.batch();
  for (const [uid, data] of Object.entries(allUpdates)) {
    finalBatch.set(
      tournamentRef.collection('leaderboard').doc(uid),
      { uid, displayName: data.displayName, points: data.points, exactScores: data.exactScores, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    for (const [dayKey, dayData] of Object.entries(data.dayPoints)) {
      finalBatch.set(
        tournamentRef.collection('leaderboard_matchday').doc(dayKey).collection('entries').doc(uid),
        { uid, displayName: data.displayName, points: dayData.points, exactScores: dayData.exactScores, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
    }
  }
  await finalBatch.commit();
  await _recalculateTournamentRanks(tournamentRef);

  return { ok: true, usersUpdated: Object.keys(allUpdates).length };
});

/**
 * Annule le scoring d'un match.
 * Callable — params : { tournamentId: string, matchId: string }
 */
exports.undoWorldCupMatchScoring = onCall(async (request) => {
  const db = getFirestore();
  const { tournamentId = 'worldcup2026', matchId } = request.data;
  if (!matchId) throw new HttpsError('invalid-argument', 'matchId requis');

  const tournamentRef = db.collection('tournaments').doc(tournamentId);
  const matchRef = tournamentRef.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) throw new HttpsError('not-found', 'Match introuvable');

  const predsSnap = await tournamentRef.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  const leaderboardDeltas = {};
  const predsBatch = db.batch();
  for (const predDoc of predsSnap.docs) {
    const pred = predDoc.data();
    const uid = pred.uid;
    const pts = pred.points || 0;
    if (!uid || pts === 0) continue;
    if (!leaderboardDeltas[uid]) leaderboardDeltas[uid] = { pts: 0, exact: 0 };
    leaderboardDeltas[uid].pts += pts;
    if (pts === 3) leaderboardDeltas[uid].exact += 1;
    predsBatch.update(predDoc.ref, { points: 0 });
  }
  await predsBatch.commit();

  const lbBatch = db.batch();
  for (const [uid, delta] of Object.entries(leaderboardDeltas)) {
    lbBatch.update(tournamentRef.collection('leaderboard').doc(uid), {
      points: FieldValue.increment(-delta.pts),
      exactScores: FieldValue.increment(-delta.exact),
    });
  }
  await lbBatch.commit();

  await matchRef.update({ status: 'upcoming', result1: null, result2: null });
  await _recalculateTournamentRanks(tournamentRef);

  return { ok: true, predictionsCleared: predsSnap.size, leaderboardsAdjusted: Object.keys(leaderboardDeltas).length };
});

/** Recalcule le champ rank sur chaque entrée du classement général. */
async function _recalculateTournamentRanks(tournamentRef) {
  const snap = await tournamentRef.collection('leaderboard').orderBy('points', 'desc').get();
  const db = getFirestore();
  const batch = db.batch();
  snap.docs.forEach((doc, i) => batch.update(doc.ref, { rank: i + 1 }));
  await batch.commit();
}
