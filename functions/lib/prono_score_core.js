const { FieldValue } = require('firebase-admin/firestore');
const { _awardXpToUser } = require('./xp_core');
const { _sendFcmToUser, _notifPref } = require('./push_helpers');
const { fcmChannelBlocks } = require('../notification_push');

/** Firestore batch max 500 writes — 2 writes / prono (pred + leaderboard). */
const PRED_CHUNK = 200;

function hasMatchScores(data) {
  if (!data) return false;
  const s1 = data.score1;
  const s2 = data.score2;
  return s1 !== null && s1 !== undefined && s2 !== null && s2 !== undefined;
}

function predictionAlreadyResolved(pred) {
  if (!pred) return false;
  if (pred.resolvedAt != null) return true;
  return typeof pred.points === 'number';
}

function pointsForProno(p1, p2, score1, score2) {
  if (p1 === score1 && p2 === score2) return 3;
  const predResult = Math.sign(p1 - p2);
  const realResult = Math.sign(score1 - score2);
  return predResult === realResult ? 1 : 0;
}

function duelPickResult(p1, p2, rs1, rs2) {
  const pp1 = Number(p1);
  const pp2 = Number(p2);
  if (!Number.isFinite(pp1) || !Number.isFinite(pp2)) return null;
  if (!Number.isFinite(rs1) || !Number.isFinite(rs2)) return null;
  const points = pointsForProno(pp1, pp2, rs1, rs2);
  const delta =
    Math.abs((pp1 - pp2) - (rs1 - rs2)) +
    Math.abs(pp1 - rs1) +
    Math.abs(pp2 - rs2);
  return { points, score1Pred: pp1, score2Pred: pp2, delta };
}

/**
 * Attribue points classement + XP pour un match finished avec scores.
 * Idempotent : ignore les prédictions déjà `resolvedAt` / `points` numériques.
 */
async function scoreFinishedMatchPronos(db, matchId, after, matchRef, options = {}) {
  const sendRecap = options.sendRecap === true;
  const score1 = after.score1;
  const score2 = after.score2;

  const predsSnap = await db.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  let newlyResolved = 0;
  let alreadyResolved = 0;
  const recapQueue = [];

  if (!predsSnap.empty) {
    const pending = [];
    for (const doc of predsSnap.docs) {
      const pred = doc.data() || {};
      if (predictionAlreadyResolved(pred)) {
        alreadyResolved += 1;
        continue;
      }
      pending.push(doc);
    }

    const streakByUid = new Map();
    const uids = [...new Set(pending.map((d) => d.data()?.uid).filter(Boolean))];
    for (const uid0 of uids) {
      const lb0 = await db.collection('prono_leaderboard').doc(uid0).get();
      const s0 = lb0.data() && lb0.data().pronoStreak != null
        ? Number(lb0.data().pronoStreak)
        : 0;
      streakByUid.set(uid0, s0);
    }

    for (let i = 0; i < pending.length; i += PRED_CHUNK) {
      const chunk = pending.slice(i, i + PRED_CHUNK);
      const batch = db.batch();
      const xpQueue = [];

      for (const doc of chunk) {
        const pred = doc.data() || {};
        const p1 = pred.score1Pred;
        const p2 = pred.score2Pred;
        const points = pointsForProno(p1, p2, score1, score2);

        batch.update(doc.ref, {
          points,
          resolvedAt: FieldValue.serverTimestamp(),
        });
        newlyResolved += 1;

        const prevStreak = streakByUid.get(pred.uid) || 0;
        const nextStreak = points >= 1 ? prevStreak + 1 : 0;
        streakByUid.set(pred.uid, nextStreak);

        const lbName = String(pred.displayName || '').trim() || 'Membre';
        const lbRef = db.collection('prono_leaderboard').doc(pred.uid);
        batch.set(lbRef, {
          uid: pred.uid,
          displayName: lbName,
          displayNameLower: lbName.toLowerCase(),
          points: FieldValue.increment(points),
          exactScores: FieldValue.increment(points === 3 ? 1 : 0),
          goodResults: FieldValue.increment(points === 1 ? 1 : 0),
          totalPredictions: FieldValue.increment(1),
          pronoStreak: nextStreak,
          season: pred.season ?? after.fffSeason ?? null,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        let eventType = null;
        if (points === 3) eventType = 'prono_correct';
        else if (points === 1) eventType = 'prono_good_result';
        if (eventType && pred.uid) {
          xpQueue.push({ uid: pred.uid, eventType });
        }
        recapQueue.push({ pred, points, p1, p2 });
      }

      await batch.commit();

      for (const item of xpQueue) {
        await _awardXpToUser(db, item.uid, item.eventType, { matchId });
      }
    }
  }

  await resolvePronoDuels(db, matchId, score1, score2);

  if (matchRef) {
    await matchRef.set({
      pronoScoredAt: FieldValue.serverTimestamp(),
      pronoScoredCount: newlyResolved,
      pronoScoringInProgress: FieldValue.delete(),
    }, { merge: true });
  }

  let recapSent = 0;
  if (sendRecap && recapQueue.length > 0) {
    recapSent = await sendMatchPronoRecaps(db, matchId, after, recapQueue);
    if (matchRef) {
      await matchRef.set({
        pronoRecapSentAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }

  console.log(
    `Pronos calculés pour ${matchId} (${score1}-${score2}) : ` +
    `${newlyResolved} nouveau(x), ${alreadyResolved} déjà résolu(s)`,
  );

  return {
    matchId,
    score1,
    score2,
    predicted: predsSnap.size,
    newlyResolved,
    alreadyResolved,
    recapSent,
  };
}

async function resolvePronoDuels(db, matchId, score1, score2) {
  const rs1 = Number(score1);
  const rs2 = Number(score2);

  const duelsSnap = await db.collection('prono_duels')
    .where('matchId', '==', matchId)
    .get();

  for (const duelDoc of duelsSnap.docs) {
    const duel = duelDoc.data();
    if (duel.status === 'cancelled' || duel.status === 'won' || duel.status === 'draw') {
      continue;
    }

    const picksSnap = await duelDoc.ref.collection('duel_picks').get();
    let ownerPickData = null;
    let oppPickData = null;
    for (const p of picksSnap.docs) {
      if (p.id === duel.ownerUid) ownerPickData = p.data();
      else if (p.id === duel.opponentUid) oppPickData = p.data();
    }

    const owner = ownerPickData != null && ownerPickData.score1 != null && ownerPickData.score2 != null
      ? duelPickResult(ownerPickData.score1, ownerPickData.score2, rs1, rs2)
      : null;
    const opponent = oppPickData != null && oppPickData.score1 != null && oppPickData.score2 != null
      ? duelPickResult(oppPickData.score1, oppPickData.score2, rs1, rs2)
      : null;

    let status = 'in_progress';
    let winnerUid = null;
    let winnerName = null;
    let loserUid = null;

    if (owner && opponent) {
      if (owner.points > opponent.points) {
        winnerUid = duel.ownerUid;
        winnerName = duel.ownerName;
        loserUid = duel.opponentUid;
      } else if (opponent.points > owner.points) {
        winnerUid = duel.opponentUid;
        winnerName = duel.opponentName;
        loserUid = duel.ownerUid;
      } else if (owner.delta < opponent.delta) {
        winnerUid = duel.ownerUid;
        winnerName = duel.ownerName;
        loserUid = duel.opponentUid;
      } else if (opponent.delta < owner.delta) {
        winnerUid = duel.opponentUid;
        winnerName = duel.opponentName;
        loserUid = duel.ownerUid;
      }
      status = winnerUid ? 'won' : 'draw';
    } else if (owner && !opponent) {
      winnerUid = duel.ownerUid;
      winnerName = duel.ownerName;
      loserUid = duel.opponentUid;
      status = 'won';
    } else if (opponent && !owner) {
      winnerUid = duel.opponentUid;
      winnerName = duel.opponentName;
      loserUid = duel.ownerUid;
      status = 'won';
    } else {
      status = 'draw';
    }

    await duelDoc.ref.set({
      ownerPoints: owner?.points ?? null,
      opponentPoints: opponent?.points ?? null,
      ownerScore: owner ? `${owner.score1Pred}-${owner.score2Pred}` : null,
      opponentScore: opponent ? `${opponent.score1Pred}-${opponent.score2Pred}` : null,
      winnerUid,
      winnerName,
      loserUid,
      status,
      resolvedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (winnerUid) {
      await _awardXpToUser(db, winnerUid, 'duel_won', { matchId, duelId: duelDoc.id });
      await db.collection('users').doc(winnerUid).set({
        'pronoProfile.duelXp': FieldValue.increment(3),
        'pronoProfile.duelWins': FieldValue.increment(1),
        'pronoProfile.duelPoints': FieldValue.increment(3),
        'pronoProfile.lastDuelAt': FieldValue.serverTimestamp(),
      }, { merge: true });

      if (loserUid) {
        await db.collection('users').doc(loserUid).set({
          'pronoProfile.duelLosses': FieldValue.increment(1),
          'pronoProfile.lastDuelAt': FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    } else if (owner || opponent) {
      const duelDrawUpdate = {
        'pronoProfile.duelDraws': FieldValue.increment(1),
        'pronoProfile.lastDuelAt': FieldValue.serverTimestamp(),
      };
      if (duel.ownerUid) {
        await db.collection('users').doc(duel.ownerUid).set(duelDrawUpdate, { merge: true });
      }
      if (duel.opponentUid) {
        await db.collection('users').doc(duel.opponentUid).set(duelDrawUpdate, { merge: true });
      }
    }
  }
}

async function sendMatchPronoRecaps(db, matchId, after, recapQueue) {
  const score1 = after.score1;
  const score2 = after.score2;
  const team1 = after.team1 ?? 'Eq. 1';
  const team2 = after.team2 ?? 'Eq. 2';
  const promises = [];

  for (const item of recapQueue) {
    const uid = item.pred.uid;
    if (!uid) continue;
    const p1 = item.p1;
    const p2 = item.p2;
    if (p1 === null || p1 === undefined || p2 === null || p2 === undefined) continue;

    const isExact = item.points === 3;
    const isCorrect = item.points >= 1;
    const xpGained = isExact ? '+20 XP' : isCorrect ? '+8 XP' : '+0 XP';
    const emoji = isExact ? '🎯' : isCorrect ? '✅' : '❌';
    const label = isExact ? 'Score exact !' : isCorrect ? 'Bon résultat !' : 'Raté cette fois';

    promises.push((async () => {
      const userSnap = await db.collection('users').doc(uid).get();
      const udata = userSnap.data() ?? {};
      if (!_notifPref(udata, 'pronoPointsRecap')) return false;
      return _sendFcmToUser(
        db,
        udata,
        {
          notification: {
            title: `${emoji} ${team1} ${score1}–${score2} ${team2}`,
            body: `Ton prono : ${p1}–${p2} · ${label} · ${xpGained}`,
          },
          data: { type: 'match_recap', matchId },
          ...fcmChannelBlocks('dvcr_alerts'),
        },
        `match recap ${uid}`,
        { recipientUid: uid },
      );
    })().catch((e) => {
      console.error(`Recap notif failed for ${uid}:`, e.message);
      return false;
    }));
  }

  const results = await Promise.allSettled(promises);
  const sent = results.filter((r) => r.status === 'fulfilled' && r.value).length;
  console.log(`Match ${matchId} recap: ${sent} notification(s) envoyées`);
  return sent;
}

async function findPendingFinishedMatches(db, { sinceMs = 21 * 86400000, matchId = '' } = {}) {
  if (matchId) {
    const snap = await db.collection('matches').doc(matchId).get();
    if (!snap.exists) return [];
    const d = snap.data() || {};
    if (d.status !== 'finished' || !hasMatchScores(d)) return [];
    return [{ id: snap.id, data: d, ref: snap.ref }];
  }

  const { Timestamp } = require('firebase-admin/firestore');
  const from = Timestamp.fromMillis(Date.now() - sinceMs);
  const snap = await db.collection('matches')
    .where('date', '>=', from)
    .get();

  const out = [];
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    if (d.status !== 'finished') continue;
    if (!hasMatchScores(d)) continue;
    if (d.pronoScoredAt) continue;
    out.push({ id: doc.id, data: d, ref: doc.ref });
  }
  return out;
}

module.exports = {
  hasMatchScores,
  predictionAlreadyResolved,
  scoreFinishedMatchPronos,
  sendMatchPronoRecaps,
  findPendingFinishedMatches,
};
