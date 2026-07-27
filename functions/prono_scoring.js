const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _isUserAdmin } = require('./lib/admin_auth');
const { _loadFffSeasonConfig } = require('./lib/fff_config');
const { _awardXpToUser } = require('./lib/xp_core');
const {
  _notificationsPaused, _sendFcmToUser, _userFcmTokens, _notifPref,
} = require('./lib/push_helpers');
const { fcmChannelBlocks } = require('./notification_push');

// ── Pronostics — calcul des points quand un match passe à "finished" ───────
exports.calculatePronoPoints = onDocumentWritten('matches/{matchId}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return;

  // Déclenche seulement quand le statut passe à 'finished' pour la première fois
  if (before?.status === 'finished' || after.status !== 'finished') return;

  const score1 = after.score1;
  const score2 = after.score2;
  if (score1 === null || score1 === undefined || score2 === null || score2 === undefined) return;

  const db      = getFirestore();
  const cfg     = await _loadFffSeasonConfig(db);
  const matchId = event.params.matchId;

  const predsSnap = await db.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  if (predsSnap.empty) {
    console.log(`Aucun prono pour le match ${matchId}`);
    return;
  }

  const streakByUid = new Map();
  for (const doc of predsSnap.docs) {
    const uid0 = doc.data().uid;
    if (uid0 && !streakByUid.has(uid0)) {
      const lb0 = await db.collection('prono_leaderboard').doc(uid0).get();
      const s0 = lb0.data() && lb0.data().pronoStreak != null
        ? Number(lb0.data().pronoStreak)
        : 0;
      streakByUid.set(uid0, s0);
    }
  }

  const batch = db.batch();
  const predResults = new Map();

  for (const doc of predsSnap.docs) {
    const pred = doc.data();
    const p1   = pred.score1Pred;
    const p2   = pred.score2Pred;

    let points = 0;
    if (p1 === score1 && p2 === score2) {
      points = 3;
    } else {
      const predResult = Math.sign(p1 - p2);
      const realResult = Math.sign(score1 - score2);
      if (predResult === realResult) points = 1;
    }

    batch.update(doc.ref, {
      points,
      resolvedAt: FieldValue.serverTimestamp(),
    });

    predResults.set(pred.uid, {
      uid: pred.uid,
      displayName: pred.displayName,
      points,
      score1Pred: p1,
      score2Pred: p2,
      delta: Math.abs((p1 - p2) - (score1 - score2)) + Math.abs(p1 - score1) + Math.abs(p2 - score2),
    });

    const prevStreak = streakByUid.get(pred.uid) || 0;
    const nextStreak = points >= 1 ? prevStreak + 1 : 0;
    streakByUid.set(pred.uid, nextStreak);

    // Mise à jour du classement global (merge pour créer ou incrémenter)
    const lbName = String(pred.displayName || '').trim() || 'Membre';
    const lbRef = db.collection('prono_leaderboard').doc(pred.uid);
    batch.set(lbRef, {
      uid:              pred.uid,
      displayName:      lbName,
      displayNameLower: lbName.toLowerCase(),
      points:           FieldValue.increment(points),
      exactScores:      FieldValue.increment(points === 3 ? 1 : 0),
      goodResults:      FieldValue.increment(points === 1 ? 1 : 0),
      totalPredictions: FieldValue.increment(1),
      pronoStreak:      nextStreak,
      season:           pred.season ?? after.fffSeason ?? cfg.seasonLabel,
      updatedAt:        FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();

  for (const doc of predsSnap.docs) {
    const pred = doc.data();
    const uid = pred.uid;
    if (!uid) continue;
    const p1 = pred.score1Pred;
    const p2 = pred.score2Pred;
    let eventType = null;
    if (p1 === score1 && p2 === score2) {
      eventType = 'prono_correct';
    } else {
      const predResult = Math.sign(p1 - p2);
      const realResult = Math.sign(score1 - score2);
      if (predResult === realResult) eventType = 'prono_good_result';
    }
    if (eventType) {
      await _awardXpToUser(db, uid, eventType, { matchId });
    }
  }

  const rs1 = Number(score1);
  const rs2 = Number(score2);

  /** Points prono (3 / 1 / 0) + delta tie-break — mêmes règles que le championnat. */
  function duelPickResult(p1, p2) {
    const pp1 = Number(p1);
    const pp2 = Number(p2);
    if (!Number.isFinite(pp1) || !Number.isFinite(pp2)) return null;
    if (!Number.isFinite(rs1) || !Number.isFinite(rs2)) return null;
    let points = 0;
    if (pp1 === rs1 && pp2 === rs2) {
      points = 3;
    } else {
      const predResult = Math.sign(pp1 - pp2);
      const realResult = Math.sign(rs1 - rs2);
      if (predResult === realResult) points = 1;
    }
    const delta = Math.abs((pp1 - pp2) - (rs1 - rs2)) + Math.abs(pp1 - rs1) + Math.abs(pp2 - rs2);
    return {
      points,
      score1Pred: pp1,
      score2Pred: pp2,
      delta,
    };
  }

  const duelsSnap = await db.collection('prono_duels')
    .where('matchId', '==', matchId)
    .get();

  for (const duelDoc of duelsSnap.docs) {
    const duel = duelDoc.data();
    if (duel.status === 'cancelled' || duel.status === 'won' || duel.status === 'draw') continue;

    const picksSnap = await duelDoc.ref.collection('duel_picks').get();
    let ownerPickData = null;
    let oppPickData = null;
    for (const p of picksSnap.docs) {
      if (p.id === duel.ownerUid) ownerPickData = p.data();
      else if (p.id === duel.opponentUid) oppPickData = p.data();
    }

    const owner = ownerPickData != null && ownerPickData.score1 != null && ownerPickData.score2 != null
      ? duelPickResult(ownerPickData.score1, ownerPickData.score2)
      : null;
    const opponent = oppPickData != null && oppPickData.score1 != null && oppPickData.score2 != null
      ? duelPickResult(oppPickData.score1, oppPickData.score2)
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
    } else if (!owner && !opponent) {
      // Aucun score duel saisi — duel clos sans gagnant (pas d’XP).
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

  console.log(`Pronos calculés pour ${matchId} (${score1}-${score2}) : ${predsSnap.size} prédiction(s)`);
});

/** Issue 1-X-2 à partir des scores prédits (agrégat communauté). */
function _outcomeFromPredScores(s1, s2) {
  const a = Number(s1);
  const b = Number(s2);
  if (Number.isNaN(a) || Number.isNaN(b)) return null;
  if (a > b) return 'homeWin';
  if (a < b) return 'awayWin';
  return 'draw';
}

/**
 * Maintient `match_prono_stats/{matchId}` (compteurs 1 / N / 2) pour barres UI.
 * Lecture côté client uniquement sur ce doc — pas de scan de toutes les prédictions.
 */
exports.syncMatchPronoOutcomeStats = onDocumentWritten('predictions/{predId}', async (event) => {
  const db = getFirestore();
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  const matchId = (after && after.matchId) || (before && before.matchId);
  if (!matchId) return;

  // Profil searchable dès le 1er prono (avant scoring match finished).
  if (after && after.uid) {
    const name = String(after.displayName || '').trim() || 'Membre';
    try {
      await db.collection('prono_leaderboard').doc(String(after.uid)).set({
        uid: String(after.uid),
        displayName: name,
        displayNameLower: name.toLowerCase(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (e) {
      console.warn('syncMatchPronoOutcomeStats leaderboard upsert:', e.message);
    }
  }

  const oldO = before ? _outcomeFromPredScores(before.score1Pred, before.score2Pred) : null;
  const newO = after ? _outcomeFromPredScores(after.score1Pred, after.score2Pred) : null;
  if (before && after && oldO === newO) {
    return;
  }

  const statsRef = db.collection('match_prono_stats').doc(String(matchId));
  const patch = { matchId: String(matchId), updatedAt: FieldValue.serverTimestamp() };
  if (oldO) patch[oldO] = FieldValue.increment(-1);
  if (newO) patch[newO] = FieldValue.increment(1);
  if (!before && after) patch.total = FieldValue.increment(1);
  if (before && !after) patch.total = FieldValue.increment(-1);

  await statsRef.set(patch, { merge: true });
});

/**
 * Initialise `prono_seasons/current` (+ optionnellement `user_season_stats/{uid}_current`).
 * À appeler une fois depuis l’app admin ou la console (compte admin DVCR).
 */
exports.ensurePronoSeasonBootstrap = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Réservé aux administrateurs');
  }

  const now = Timestamp.now();
  const ends = Timestamp.fromDate(new Date(Date.UTC(2026, 6, 1, 0, 0, 0)));

  await db.collection('prono_seasons').doc('current').set({
    name: 'Saison 2025-2026',
    subtitle:
      'Classement « ranked » lié à cette fenêtre ; préférences et historique globaux restent.',
    startsAt: now,
    endsAt: ends,
    rulesVersion: 1,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const targetUid = String(request.data?.targetUid ?? request.auth.uid).trim();
  if (targetUid) {
    await db.collection('user_season_stats').doc(`${targetUid}_current`).set({
      uid: targetUid,
      seasonId: 'current',
      divisionLabel: 'Bronze',
      seasonPoints: 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  return {
    ok: true,
    pronoSeasonsDoc: 'prono_seasons/current',
    userSeasonStatsDoc: targetUid ? `user_season_stats/${targetUid}_current` : null,
  };
});

exports.notifyRankingMotivation = onSchedule(
  { schedule: 'every 252 hours', memory: '256MiB', timeoutSeconds: 300 },
  async () => {
    const db = getFirestore();
    if (await _notificationsPaused(db)) {
      console.log('[maintenance] notifyRankingMotivation skipped');
      return;
    }
    const snap = await db.collection('prono_leaderboard')
      .orderBy('points', 'desc')
      .limit(500)
      .get();

    const now = Date.now();
    const minGapMs = Math.floor(10.5 * 24 * 60 * 60 * 1000);
    let sent = 0;
    const docs = snap.docs;

    for (let i = 0; i < docs.length; i++) {
      if (sent >= 150) break;
      const rank = i + 1;
      const doc = docs[i];
      const uid = doc.id;
      const pts = Number(doc.data()?.points ?? 0) || 0;
      if (pts <= 0 && rank > 50) continue;

      const uSnap = await db.collection('users').doc(uid).get();
      const udata = uSnap.data() ?? {};
      if (!_notifPref(udata, 'rankingMotivation')) continue;
      if (!_userFcmTokens(udata).length) continue;

      const prefs = udata.notificationPrefs || {};
      const last = prefs.lastRankingDigestSentAt;
      if (last && typeof last.toMillis === 'function' && now - last.toMillis() < minGapMs) {
        continue;
      }

      const ord = rank === 1 ? '1er' : `${rank}e`;
      try {
        const ok = await _sendFcmToUser(
          db,
          udata,
          {
            notification: {
              title: 'Classement prono DVCR',
              body: `Tu es ${ord} avec ${pts} pts — continue pour grimper !`,
            },
            data: { type: 'ranking_motivation', rank: String(rank) },
            ...fcmChannelBlocks('dvcr_alerts', { priority: 'normal' }),
          },
          `ranking motivation ${uid}`,
          { recipientUid: uid },
        );
        if (!ok) continue;
        await db.collection('users').doc(uid).set({
          notificationPrefs: { lastRankingDigestSentAt: Timestamp.now() },
        }, { merge: true });
        sent += 1;
      } catch (e) {
        console.error('notifyRankingMotivation', uid, e.message);
      }
    }
    console.log(`notifyRankingMotivation : ${sent} envoi(s)`);
  },
);

// —— Fin / reset saison prono championnat (admin only) ———————————————————————
// fullReset=false : classements uniquement (legacy).
// fullReset=true  : pronos, duels, ligues, stats match et profils prono — table rase.
// Collections tournoi événementiel (tournaments/*, esti_dvcr_leagues) hors périmètre (ADR-0002).
exports.resetPronoSeason = onCall({ cors: true }, async (request) => {
  const { db } = await _requireAdminCall(request);

  const season = String(request.data?.season ?? '').trim() || 'saison_inconnue';
  const fullReset = request.data?.fullReset === true;
  const skipArchive = request.data?.skipArchive === true;
  const resetAt = Timestamp.now();

  const archiveId = skipArchive
    ? null
    : `archive_${season.replace(/[^a-zA-Z0-9_-]/g, '_')}_${Date.now()}`;
  const archiveRef = archiveId
    ? db.collection('season_archives').doc(archiveId)
    : null;

  if (archiveRef) {
    await archiveRef.set({
      type: fullReset ? 'prono_full_reset' : 'prono_rankings_reset',
      season,
      fullReset,
      startedAt: resetAt,
      startedBy: request.auth.uid,
    }, { merge: true });
  }

  const counts = {};

  async function clearCollection(collectionName, options = {}) {
    if (archiveRef) {
      counts[collectionName] = await _archiveAndDeleteCollection(
        db, archiveRef, collectionName, options,
      );
      return;
    }
    counts[collectionName] = await _deleteCollection(db, collectionName, options);
  }

  await clearCollection('prono_leaderboard');

  if (fullReset) {
    await clearCollection('predictions');
    await clearCollection('prono_duels', { subcollections: ['duel_picks'] });
    await clearCollection('private_leagues');
    await clearCollection('match_prono_stats');
    await clearCollection('user_season_stats');
    await clearCollection('prono_social_activity');
    counts.usersPronoProfileCleared = await _clearUserPronoProfiles(db);
    await _bootstrapPronoSeasonDoc(db, season, resetAt);
  } else {
    const leaguesSnap = await db.collection('private_leagues').get();
    let privateLeaguesUpdated = 0;
    for (let i = 0; i < leaguesSnap.docs.length; i += 400) {
      const chunk = leaguesSnap.docs.slice(i, i + 400);
      const batch = db.batch();
      for (const doc of chunk) {
        const data = doc.data() || {};
        const memberIds = (Array.isArray(data.memberIds) ? data.memberIds : [])
          .map((id) => String(id))
          .filter((id) => id.length > 0);
        const prevRs = data.rankingStats || {};
        const memberCount = memberIds.length > 0
          ? memberIds.length
          : Number(prevRs.memberCount || 0);
        batch.set(doc.ref, {
          rankingStats: {
            memberPointsSum: 0,
            memberCount,
            updatedAt: FieldValue.serverTimestamp(),
          },
          lastRankingsResetSeason: season,
          lastRankingsResetAt: resetAt,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        privateLeaguesUpdated++;
      }
      await batch.commit();
    }
    counts.privateLeaguesUpdated = privateLeaguesUpdated;
  }

  if (archiveRef) {
    await archiveRef.set({
      counts,
      completedAt: Timestamp.now(),
    }, { merge: true });
  }

  return {
    success: true,
    archiveId,
    season,
    fullReset,
    skipArchive,
    counts,
  };
});

async function _bootstrapPronoSeasonDoc(db, seasonLabel, startsAt) {
  const ends = Timestamp.fromDate(new Date(Date.UTC(2026, 6, 1, 0, 0, 0)));
  await db.collection('prono_seasons').doc('current').set({
    name: `Saison ${seasonLabel}`,
    subtitle: 'Nouvelle saison championnat — pronos, duels et ligues repartent de zéro.',
    startsAt,
    endsAt: ends,
    rulesVersion: 1,
    lastResetAt: startsAt,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function _clearUserPronoProfiles(db) {
  const snap = await db.collection('users').get();
  let cleared = 0;
  for (let i = 0; i < snap.docs.length; i += 400) {
    const chunk = snap.docs.slice(i, i + 400);
    const batch = db.batch();
    let ops = 0;
    for (const doc of chunk) {
      if (doc.data()?.pronoProfile == null) continue;
      batch.update(doc.ref, { pronoProfile: FieldValue.delete() });
      ops += 1;
      cleared += 1;
    }
    if (ops > 0) await batch.commit();
  }
  return cleared;
}

async function _deleteCollection(db, collectionName, options = {}) {
  const snap = await db.collection(collectionName).get();
  if (snap.empty) return 0;

  const subcollections = options.subcollections ?? [];
  let processed = 0;

  for (let i = 0; i < snap.docs.length; i += 200) {
    const chunk = snap.docs.slice(i, i + 200);
    const deleteBatch = db.batch();

    for (const doc of chunk) {
      for (const subName of subcollections) {
        const subSnap = await doc.ref.collection(subName).get();
        if (!subSnap.empty) {
          const subDeleteBatch = db.batch();
          for (const subDoc of subSnap.docs) {
            subDeleteBatch.delete(subDoc.ref);
          }
          await subDeleteBatch.commit();
        }
      }
      deleteBatch.delete(doc.ref);
      processed++;
    }

    await deleteBatch.commit();
  }

  return processed;
}


async function _archiveAndDeleteCollection(db, archiveRef, collectionName, options = {}) {
  const snap = await db.collection(collectionName).get();
  if (snap.empty) return 0;

  const subcollections = options.subcollections ?? [];
  let processed = 0;

  for (let i = 0; i < snap.docs.length; i += 200) {
    const chunk = snap.docs.slice(i, i + 200);
    const archiveBatch = db.batch();
    const deleteBatch = db.batch();

    for (const doc of chunk) {
      archiveBatch.set(
        archiveRef.collection(collectionName).doc(doc.id),
        {
          ...doc.data(),
          _archivedAt: Timestamp.now(),
          _sourceCollection: collectionName,
        },
      );

      for (const subName of subcollections) {
        const subSnap = await doc.ref.collection(subName).get();
        if (!subSnap.empty) {
          const subArchiveBatch = db.batch();
          const subDeleteBatch = db.batch();
          for (const subDoc of subSnap.docs) {
            subArchiveBatch.set(
              archiveRef.collection(`${collectionName}_${subName}`).doc(`${doc.id}__${subDoc.id}`),
              {
                parentId: doc.id,
                ...subDoc.data(),
                _archivedAt: Timestamp.now(),
                _sourceCollection: `${collectionName}/${doc.id}/${subName}`,
              },
            );
            subDeleteBatch.delete(subDoc.ref);
          }
          await subArchiveBatch.commit();
          await subDeleteBatch.commit();
        }
      }

      deleteBatch.delete(doc.ref);
      processed++;
    }

    await archiveBatch.commit();
    await deleteBatch.commit();
  }

  return processed;
}
