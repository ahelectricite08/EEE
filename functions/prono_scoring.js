const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _isUserAdmin } = require('./lib/admin_auth');
const { _awardXpToUser } = require('./lib/xp_core');
const {
  _notificationsPaused, _sendFcmToUser, _userFcmTokens, _notifPref,
} = require('./lib/push_helpers');
const { fcmChannelBlocks } = require('./notification_push');
const {
  matchReadyToScorePronos,
  scoreFinishedMatchPronos,
  findPendingFinishedMatches,
} = require('./lib/prono_score_core');
const { maybeSendPronoDayRecap } = require('./lib/prono_day_recap');
const { scoreFirstScorerBetsForMatch } = require('./lib/first_scorer_core');
const {
  collectDueReminders,
  predictionHasScore,
  lineupIsComplete,
  missingScoreCount,
  userNeedsScoreReminder,
  userNeedsXiReminder,
  scoreReminderBodyForUser,
} = require('./lib/prono_lock_reminders');
const { buildCrowdXi, crowdXiShouldWrite } = require('./lib/crowd_xi');
const {
  countNameMatches,
  resolvePredictedLabels,
  lineupPredPoints,
} = require('./lib/lineup_name_match');

const PRONO_SCORE_OPTS = { timeoutSeconds: 540, memory: '512MiB' };

// ── Pronostics — points + XP dès qu’un match finished a un score ────────────
// FFF pose souvent `status: finished` dès que le coup d’envoi est passé, AVANT
// d’avoir home_score/away_score. L’ancien garde `before.status === 'finished'`
// faisait alors un skip silencieux pour toujours. On score dès que les deux
// scores sont là. Premier scoring via `pronoScoredAt` ; rescore si le score FFF
// change ensuite (souvent un score live 1-0 écrit `finished`, puis 2-0 final).
exports.scorePendingPronosSchedule = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'Europe/Paris',
    ...PRONO_SCORE_OPTS,
  },
  async () => {
    const db = getFirestore();
    const pending = await findPendingFinishedMatches(db, {});
    console.log(`scorePendingPronosSchedule : ${pending.length} match(s)`);
    for (const row of pending) {
      await scoreFinishedMatchPronos(db, row.id, row.data, row.ref, {
        sendRecap: false,
      });
      await maybeSendPronoDayRecap(db, row.id, {
        ...row.data,
        pronoScoredAt: row.data.pronoScoredAt || true,
      });
    }
  },
);

async function _claimPronoLockReminder(db, reminder) {
  const ref = db.collection('prono_lock_reminders').doc(reminder.id);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return false;
    tx.set(ref, {
      id: reminder.id,
      kind: reminder.kind,
      title: reminder.title,
      body: reminder.body,
      pronoTab: reminder.pronoTab || '',
      matchId: reminder.matchId || '',
      claimedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

async function _uidsWhoFilledScores(db, matchIds) {
  const uidsByMatch = new Map();
  const ids = [...new Set((matchIds || []).filter(Boolean))];
  const snaps = await Promise.all(ids.map((id) => db.collection('predictions')
    .where('matchId', '==', id)
    .get()));
  for (let i = 0; i < ids.length; i += 1) {
    const filled = new Set();
    for (const doc of snaps[i].docs) {
      const pred = doc.data() || {};
      if (!predictionHasScore(pred)) continue;
      const uid = String(pred.uid || '').trim()
        || String(doc.id).replace(`${ids[i]}_`, '');
      if (uid) filled.add(uid);
    }
    uidsByMatch.set(ids[i], filled);
  }
  return uidsByMatch;
}

async function _uidsWhoFilledXi(db, matchId) {
  const filled = new Set();
  if (!matchId) return filled;
  const snap = await db.collection('lineup_predictions')
    .where('matchId', '==', matchId)
    .get();
  for (const doc of snap.docs) {
    const pred = doc.data() || {};
    if (!lineupIsComplete(pred)) continue;
    const uid = String(pred.uid || '').trim()
      || String(doc.id).replace(`${matchId}_`, '');
    if (uid) filled.add(uid);
  }
  return filled;
}

async function _sendPronoLockReminder(db, reminder) {
  const matchIds = reminder.kind === 'xi'
    ? (reminder.matchId ? [reminder.matchId] : [])
    : (reminder.matchIds || []);
  const uidsByMatch = reminder.kind === 'score'
    ? await _uidsWhoFilledScores(db, matchIds)
    : new Map();
  const xiUids = reminder.kind === 'xi'
    ? await _uidsWhoFilledXi(db, reminder.matchId)
    : new Set();

  const snap = await db.collection('prono_leaderboard')
    .orderBy('points', 'desc')
    .limit(600)
    .get();
  let sent = 0;
  let skippedFilled = 0;
  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += 25) {
    const chunk = docs.slice(i, i + 25);
    const users = await Promise.all(
      chunk.map((d) => db.collection('users').doc(d.id).get()),
    );
    const results = await Promise.allSettled(users.map(async (uSnap, j) => {
      const uid = chunk[j].id;
      if (reminder.kind === 'score' && !userNeedsScoreReminder(matchIds, uid, uidsByMatch)) {
        skippedFilled += 1;
        return false;
      }
      if (reminder.kind === 'xi' && !userNeedsXiReminder(uid, xiUids)) {
        skippedFilled += 1;
        return false;
      }
      const udata = uSnap.data() ?? {};
      if (!_notifPref(udata, 'pronoPointsRecap')) return false;
      if (!_userFcmTokens(udata).length) return false;
      const missing = reminder.kind === 'score'
        ? missingScoreCount(matchIds, uid, uidsByMatch)
        : 0;
      const body = reminder.kind === 'score'
        ? scoreReminderBodyForUser(reminder, missing)
        : reminder.body;
      return _sendFcmToUser(
        db,
        udata,
        {
          notification: {
            title: reminder.title,
            body,
          },
          data: {
            type: reminder.kind === 'xi' ? 'prono_xi_lock' : 'prono_lock_reminder',
            pronoTab: reminder.pronoTab || (reminder.kind === 'xi' ? 'home' : 'matches'),
            ...(reminder.matchId ? { matchId: String(reminder.matchId) } : {}),
          },
          ...fcmChannelBlocks('dvcr_alerts', {
            priority: 'high',
            tag: reminder.id,
            collapseKey: reminder.id,
          }),
        },
        `prono lock ${reminder.id} ${uid}`,
        { recipientUid: uid },
      );
    }));
    for (const r of results) {
      if (r.status === 'fulfilled' && r.value) sent += 1;
    }
  }
  return { sent, skippedFilled };
}

// Rappels fermeture : XI CSSA mercredi 20 h (match samedi/dimanche)
// + pronos score groupés par jour Paris, 3 h et 1 h avant le 1er KO.
exports.notifyPronoLockReminders = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeZone: 'Europe/Paris',
    timeoutSeconds: 300,
    memory: '256MiB',
  },
  async () => {
    const db = getFirestore();
    if (await _notificationsPaused(db)) {
      console.log('[maintenance] notifyPronoLockReminders skipped');
      return;
    }
    const now = Date.now();
    const upcoming = await db.collection('matches')
      .where('date', '>', Timestamp.fromMillis(now - 60 * 1000))
      .orderBy('date')
      .limit(80)
      .get();
    const matches = upcoming.docs.map((d) => {
      const data = d.data() || {};
      return {
        id: d.id,
        date: data.date,
        competition: data.competition,
        team1: data.team1,
        team2: data.team2,
      };
    });
    const due = collectDueReminders(matches, now);
    if (!due.length) {
      console.log('notifyPronoLockReminders : 0 due');
      return;
    }
    for (const reminder of due) {
      const claimed = await _claimPronoLockReminder(db, reminder);
      if (!claimed) {
        console.log(`notifyPronoLockReminders : skip ${reminder.id}`);
        continue;
      }
      const { sent, skippedFilled } = await _sendPronoLockReminder(db, reminder);
      await db.collection('prono_lock_reminders').doc(reminder.id).set({
        sent,
        skippedFilled,
        sentAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      console.log(
        `notifyPronoLockReminders : ${reminder.id} → ${sent} envoi(s), ${skippedFilled} déjà joué(s)`,
      );
    }
  },
);

exports.calculatePronoPoints = onDocumentWritten(
  { document: 'matches/{matchId}', ...PRONO_SCORE_OPTS },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;
    if (!matchReadyToScorePronos(after)) return;

    const db = getFirestore();
    const matchId = event.params.matchId;
    const before = event.data?.before?.data();

    if (!after.pronoScoredAt) {
      await scoreFinishedMatchPronos(db, matchId, after, event.data.after.ref, {
        sendRecap: false,
      });
      await maybeSendPronoDayRecap(db, matchId, { ...after, pronoScoredAt: true });
      return;
    }

    const scoresChanged = !!(before) && (
      Number(before.score1) !== Number(after.score1) ||
      Number(before.score2) !== Number(after.score2)
    );
    if (scoresChanged) {
      await scoreFinishedMatchPronos(db, matchId, after, event.data.after.ref, {
        sendRecap: false,
        rescore: true,
      });
    }

    // Recap : uniquement au 1er passage pronoScoredAt (pas à chaque tick score).
    const justScored = !before?.pronoScoredAt;
    if (!justScored) return;
    await maybeSendPronoDayRecap(db, matchId, after);
  },
);

/**
 * Admin — relance l’attribution des pronos.
 * Sans matchId : matchs finished + scores, pas encore `pronoScoredAt`.
 * Avec matchId : force rescore (y compris prédictions déjà résolues).
 */
exports.scoreMatchPronos = onCall(
  { cors: true, ...PRONO_SCORE_OPTS },
  async (request) => {
    const { db } = await _requireAdminCall(request);
    const matchId = String(request.data?.matchId ?? '').trim();
    const pending = await findPendingFinishedMatches(db, { matchId });
    const forceRescore = matchId.length > 0;
    const results = [];
    const recaps = [];
    for (const row of pending) {
      results.push(await scoreFinishedMatchPronos(
        db,
        row.id,
        row.data,
        row.ref,
        { sendRecap: false, rescore: forceRescore },
      ));
      recaps.push(await maybeSendPronoDayRecap(db, row.id, {
        ...row.data,
        pronoScoredAt: row.data.pronoScoredAt || true,
      }));
    }
    return { ok: true, scored: results.length, results, recaps };
  },
);

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
    await clearCollection('prono_best_scorer_picks');
    await clearCollection('lineup_predictions');
    await clearCollection('first_scorer_bets');
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
            memberPointsAvg: 0,
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


/**
 * Admin — déclare le meilleur buteur de la saison et attribue +10 pts
 * au classement général (`prono_leaderboard`) pour les bons paris.
 * Idempotent via `app_config/best_scorer_challenge.awardsApplied`.
 */
exports.resolveBestScorerChallenge = onCall({ cors: true }, async (request) => {
  const { db } = await _requireAdminCall(request);

  const playerId = String(request.data?.playerId ?? '').trim();
  if (!playerId) {
    throw new HttpsError('invalid-argument', 'playerId requis');
  }

  const configRef = db.collection('app_config').doc('best_scorer_challenge');
  const configSnap = await configRef.get();
  const cfg = configSnap.data() || {};
  const seasonId = String(cfg.seasonId || '').trim();
  if (!seasonId) {
    throw new HttpsError('failed-precondition', 'seasonId manquant dans la config défi');
  }

  const players = Array.isArray(cfg.players) ? cfg.players : [];
  const winner = players.find((p) => String(p?.id || '').trim() === playerId);
  if (!winner) {
    throw new HttpsError('invalid-argument', 'Joueur inconnu dans la liste du défi');
  }
  const playerName = String(winner.name || '').trim() || playerId;

  if (cfg.awardsApplied === true) {
    return {
      ok: true,
      alreadyApplied: true,
      seasonId,
      playerId: String(cfg.resolvedPlayerId || playerId),
      playerName: String(cfg.resolvedPlayerName || playerName),
      awardedCount: Number(cfg.awardedCount || 0),
      bonusPoints: 10,
    };
  }

  const picksSnap = await db.collection('prono_best_scorer_picks')
    .where('seasonId', '==', seasonId)
    .get();

  const BONUS = 10;
  let awardedCount = 0;
  const winners = [];

  for (let i = 0; i < picksSnap.docs.length; i += 200) {
    const chunk = picksSnap.docs.slice(i, i + 200);
    const batch = db.batch();
    let ops = 0;

    for (const doc of chunk) {
      const pick = doc.data() || {};
      if (pick.awarded === true) continue;
      // Ignored users (or missing pick) never receive the bonus.
      const status = String(pick.status || '').trim();
      const pickPlayerId = String(pick.playerId || '').trim();
      if (status === 'ignored') continue;
      if (status && status !== 'picked') continue;
      if (!pickPlayerId || pickPlayerId !== playerId) continue;

      const uid = String(pick.uid || doc.id).trim();
      if (!uid) continue;

      const lbRef = db.collection('prono_leaderboard').doc(uid);
      batch.set(lbRef, {
        uid,
        points: FieldValue.increment(BONUS),
        season: seasonId,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      batch.set(doc.ref, {
        awarded: true,
        awardedAt: FieldValue.serverTimestamp(),
        awardedPoints: BONUS,
        resolvedPlayerId: playerId,
      }, { merge: true });

      ops += 1;
      awardedCount += 1;
      winners.push(uid);
    }

    if (ops > 0) await batch.commit();
  }

  await configRef.set({
    resolvedPlayerId: playerId,
    resolvedPlayerName: playerName,
    resolvedAt: FieldValue.serverTimestamp(),
    awardsApplied: true,
    awardsAppliedAt: FieldValue.serverTimestamp(),
    awardedCount,
    resolvedBy: request.auth.uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(
    `resolveBestScorerChallenge season=${seasonId} winner=${playerId} awarded=${awardedCount}`,
  );

  return {
    ok: true,
    alreadyApplied: false,
    seasonId,
    playerId,
    playerName,
    awardedCount,
    bonusPoints: BONUS,
    winnerUidsSample: winners.slice(0, 20),
  };
});

// ── XI probable Sedan — scoring à la publication de la compo officielle ─────
// Lock XI : 2 j 12 h = 60 h avant le coup d’envoi (compos souvent la veille).
// Status ≠ upcoming OU maintenant ≥ coup d’envoi − 60 h → tips XI fermés, pas de score.
// Ne pas réutiliser pour le lock des pronos score (fenêtre séparée, jusqu’au KO).
// Score: uniquement quand la compo Sedan officielle atteint ≥11 titulaires
// (idempotent via prediction.awarded + matches.lineupPredictionsScored).

/** XI lock only — 2 days + 12 hours before kickoff. Not the score-prono cutoff. */
const LINEUP_PRED_LOCK_BEFORE_MS = (2 * 24 + 12) * 60 * 60 * 1000;

function _normalizePlayerName(raw) {
  return require('./lib/lineup_name_match').normalizePlayerName(raw);
}

function _isSedanTeamLabel(name) {
  const u = String(name || '').toUpperCase();
  return u.includes('SEDAN') || u.includes('CSSA');
}

function _startersFromLineupSide(side) {
  if (!side || typeof side !== 'object') return [];
  const raw = Array.isArray(side.starters) ? side.starters : [];
  const out = [];
  for (const item of raw) {
    if (item && typeof item === 'object') {
      const n = String(item.name || '').trim();
      if (n) out.push(n);
    } else {
      const n = String(item || '').trim();
      if (n) out.push(n);
    }
  }
  return out;
}

function _lineupPredPoints(matched) {
  return lineupPredPoints(matched);
}

/**
 * Type d'événement XP du XI probable. L'XP se cumule avec les points de
 * classement de `_lineupPredPoints` et ne les remplace pas. Contrairement aux
 * points, le palier « moins de 9 » rapporte quand même le lot de participation :
 * tout XI soumis puis scoré touche de l'XP.
 * Valeurs par défaut dans `lib/xp_core.js`, surchargeables via
 * `app_settings/xp_config` comme tous les autres événements.
 */
function _lineupPredXpEvent(matched) {
  if (matched >= 11) return 'lineup_xi_perfect';
  if (matched >= 10) return 'lineup_xi_ten';
  if (matched >= 9) return 'lineup_xi_nine';
  return 'lineup_xi_played';
}

function _countNameMatches(predicted, official) {
  return countNameMatches(predicted, official);
}

async function _loadSquadIdToName(db) {
  const snap = await db.collection('app_config').doc('sedan_squad').get();
  const map = new Map();
  const raw = snap.exists ? (snap.data() || {}).players : null;
  if (!Array.isArray(raw)) return map;
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const id = String(item.id || '').trim();
    const name = String(item.name || '').trim();
    if (id && name) map.set(id, name);
  }
  return map;
}

function _predictedLabelsForScore(pred, squadIdToName) {
  const names = Array.isArray(pred.playerNames) ? pred.playerNames : [];
  const ids = Array.isArray(pred.playerIds) ? pred.playerIds : [];
  return resolvePredictedLabels(names, ids, squadIdToName);
}

async function _writeCrowdXiIfNeeded(db, matchRef, matchId, after, official) {
  const predsSnap = await db.collection('lineup_predictions')
    .where('matchId', '==', matchId)
    .get();
  const crowd = buildCrowdXi(
    predsSnap.docs.map((d) => d.data() || {}),
    official,
  );
  if (!crowdXiShouldWrite(after.crowdXi, crowd)) return false;
  await matchRef.set({
    crowdXi: {
      players: crowd.players,
      ballots: crowd.ballots,
      officialHits: crowd.officialHits,
      officialComputed: crowd.officialComputed,
      computedAt: FieldValue.serverTimestamp(),
    },
  }, { merge: true });
  return true;
}

/**
 * Score les `lineup_predictions` d’un match Sedan.
 * [force] : recalcule matchedCount/points même si déjà `awarded`.
 *   — delta classement seulement (jamais de 2e XP si déjà awarded).
 */
async function scoreLineupPredictionsForMatch(db, matchId, after, matchRef, opts = {}) {
  const force = opts.force === true || after.forceLineupRescore === true;
  const status = String(after.status || '');
  let kickoffMs = null;
  if (after.date && typeof after.date.toMillis === 'function') {
    kickoffMs = after.date.toMillis();
  } else if (after.date instanceof Date) {
    kickoffMs = after.date.getTime();
  } else if (typeof after.date === 'string' || typeof after.date === 'number') {
    const parsed = new Date(after.date);
    if (!Number.isNaN(parsed.getTime())) kickoffMs = parsed.getTime();
  }
  const lockMs = kickoffMs != null ? kickoffMs - LINEUP_PRED_LOCK_BEFORE_MS : null;
  const lockWindowReached = lockMs != null && Date.now() >= lockMs;
  if (status !== 'upcoming' || lockWindowReached) {
    if (after.lineupPredictionsLocked !== true) {
      await matchRef.set({
        lineupPredictionsLocked: true,
      }, { merge: true });
    }
  }

  const team1 = String(after.team1 || '');
  const team2 = String(after.team2 || '');
  let official = [];
  if (_isSedanTeamLabel(team1)) {
    official = _startersFromLineupSide(after.lineupHome);
  } else if (_isSedanTeamLabel(team2)) {
    official = _startersFromLineupSide(after.lineupAway);
  } else {
    return { skipped: true, reason: 'not_sedan' };
  }

  const locked = after.lineupPredictionsLocked === true
    || lockWindowReached
    || status !== 'upcoming'
    || official.length >= 11;

  if (after.lineupPredictionsScored === true && !force) {
    if (locked) {
      await _writeCrowdXiIfNeeded(db, matchRef, matchId, after, official);
    }
    return { skipped: true, reason: 'already_scored' };
  }

  if (official.length < 11) {
    if (locked) {
      await _writeCrowdXiIfNeeded(db, matchRef, matchId, after, []);
    }
    return { skipped: true, reason: 'no_official' };
  }

  const squadIdToName = await _loadSquadIdToName(db);
  const predsSnap = await db.collection('lineup_predictions')
    .where('matchId', '==', matchId)
    .get();

  let awardedCount = 0;
  let scoredCount = 0;
  let rescoreCount = 0;

  for (let i = 0; i < predsSnap.docs.length; i += 200) {
    const chunk = predsSnap.docs.slice(i, i + 200);
    const batch = db.batch();
    let ops = 0;
    const xpQueue = [];

    for (const doc of chunk) {
      const pred = doc.data() || {};
      const wasAwarded = pred.awarded === true;
      if (wasAwarded && !force) continue;

      const names = _predictedLabelsForScore(pred, squadIdToName);
      const matched = _countNameMatches(names, official);
      const points = _lineupPredPoints(matched);
      const oldPoints = Number(pred.points) || 0;
      const oldMatched = Number(pred.matchedCount) || 0;
      const uid = String(pred.uid || '').trim() || String(doc.id).split('_').pop();

      const patch = {
        awarded: true,
        matchedCount: matched,
        points,
        lockedAt: FieldValue.serverTimestamp(),
      };
      if (!wasAwarded) {
        patch.awardedAt = FieldValue.serverTimestamp();
      } else {
        patch.rescoredAt = FieldValue.serverTimestamp();
      }

      batch.set(doc.ref, patch, { merge: true });
      ops += 1;
      scoredCount += 1;
      if (wasAwarded) rescoreCount += 1;

      if (!wasAwarded && uid) xpQueue.push({ uid, matched });

      if (uid) {
        const delta = wasAwarded ? (points - oldPoints) : points;
        const lbName = String(pred.displayName || '').trim() || 'Membre';
        const lbPatch = {
          uid,
          displayName: lbName,
          displayNameLower: lbName.toLowerCase(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (delta !== 0) {
          lbPatch.points = FieldValue.increment(delta);
          lbPatch.lineupPoints = FieldValue.increment(delta);
        }
        if (matched >= 11 && !(wasAwarded && oldMatched >= 11)) {
          lbPatch.perfectXiCount = FieldValue.increment(1);
        } else if (wasAwarded && oldMatched >= 11 && matched < 11) {
          lbPatch.perfectXiCount = FieldValue.increment(-1);
        }
        if (delta !== 0 || lbPatch.perfectXiCount) {
          batch.set(db.collection('prono_leaderboard').doc(uid), lbPatch, { merge: true });
        }
        if (points > 0 && (!wasAwarded || delta > 0)) awardedCount += 1;
      }
    }

    if (ops > 0) {
      await batch.commit();
      for (const item of xpQueue) {
        await _awardXpToUser(db, item.uid, _lineupPredXpEvent(item.matched), {
          matchId,
          matchedCount: item.matched,
        });
      }
    }
  }

  const crowd = buildCrowdXi(
    predsSnap.docs.map((d) => d.data() || {}),
    official,
  );
  const scoredPatch = {
    lineupPredictionsLocked: true,
    lineupPredictionsScored: true,
    lineupPredictionsScoredAt: FieldValue.serverTimestamp(),
    lineupPredictionsAwardedUsers: awardedCount,
    lineupPredictionsScoredCount: scoredCount,
    forceLineupRescore: FieldValue.delete(),
  };
  if (rescoreCount > 0) {
    scoredPatch.lineupPredictionsRescoredAt = FieldValue.serverTimestamp();
    scoredPatch.lineupPredictionsRescoredCount = rescoreCount;
  }
  if (crowdXiShouldWrite(after.crowdXi, crowd)) {
    scoredPatch.crowdXi = {
      players: crowd.players,
      ballots: crowd.ballots,
      officialHits: crowd.officialHits,
      officialComputed: crowd.officialComputed,
      computedAt: FieldValue.serverTimestamp(),
    };
  }
  await matchRef.set(scoredPatch, { merge: true });

  console.log(
    `scoreLineupPredictions match=${matchId} scored=${scoredCount} `
    + `withPoints=${awardedCount} rescored=${rescoreCount} force=${force}`,
  );
  return { scoredCount, awardedCount, rescoreCount, force };
}

/**
 * Trigger: quand la composition Sedan officielle (≥11 titulaires) est écrite
 * sur `matches/{matchId}`, score les `lineup_predictions` du match.
 * Idempotent — ne re-crédite pas si `awarded` / `lineupPredictionsScored`
 * sauf `forceLineupRescore: true` (recalcul points, pas de 2e XP).
 */
exports.scoreLineupPredictions = onDocumentWritten('matches/{matchId}', async (event) => {
  const after = event.data?.after?.data();
  if (!after) return;
  const matchId = event.params.matchId;
  const db = getFirestore();
  const matchRef = event.data.after.ref;
  await scoreLineupPredictionsForMatch(db, matchId, after, matchRef);
});

// ── Pari 1er buteur du match — scoring au 1er but (faits de jeu / override) ──
// Idempotent via firstScorerBetsScored. Ne modifie pas predictions.points / XI.
exports.scoreFirstScorerBets = onDocumentWritten(
  { document: 'matches/{matchId}', ...PRONO_SCORE_OPTS },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;
    const db = getFirestore();
    const matchId = event.params.matchId;
    await scoreFirstScorerBetsForMatch(db, matchId, after, event.data.after.ref);
  },
);

exports.scoreFirstScorerBetsOnLive = onDocumentWritten(
  { document: 'live/current', ...PRONO_SCORE_OPTS },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;
    const matchId = String(after.matchId || '').trim();
    if (!matchId) return;
    const db = getFirestore();
    const matchRef = db.collection('matches').doc(matchId);
    const snap = await matchRef.get();
    if (!snap.exists) return;
    const match = snap.data() || {};
    if (match.firstScorerBetsScored === true) return;
    const merged = { ...match, events: after.events || match.events };
    await scoreFirstScorerBetsForMatch(db, matchId, merged, matchRef);
  },
);

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
