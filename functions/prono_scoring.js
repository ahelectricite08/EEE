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
  hasMatchScores,
  scoreFinishedMatchPronos,
  findPendingFinishedMatches,
} = require('./lib/prono_score_core');
const { maybeSendPronoDayRecap } = require('./lib/prono_day_recap');

const PRONO_SCORE_OPTS = { timeoutSeconds: 540, memory: '512MiB' };

// ── Pronostics — points + XP dès qu’un match finished a un score ────────────
// FFF pose souvent `status: finished` dès que le coup d’envoi est passé, AVANT
// d’avoir home_score/away_score. L’ancien garde `before.status === 'finished'`
// faisait alors un skip silencieux pour toujours. On score dès que les deux
// scores sont là, une seule fois (`pronoScoredAt` + resolvedAt sur chaque prono).
exports.calculatePronoPoints = onDocumentWritten(
  { document: 'matches/{matchId}', ...PRONO_SCORE_OPTS },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;
    if (after.status !== 'finished') return;
    if (!hasMatchScores(after)) return;

    const db = getFirestore();
    const matchId = event.params.matchId;
    if (!after.pronoScoredAt) {
      await scoreFinishedMatchPronos(db, matchId, after, event.data.after.ref, {
        sendRecap: false,
      });
      return;
    }

    const before = event.data?.before?.data();
    const justScored = !before?.pronoScoredAt;
    if (!justScored) return;
    await maybeSendPronoDayRecap(db, matchId, after);
  },
);

/**
 * Admin — relance l’attribution des pronos (matchs finished + scores, pas encore
 * `pronoScoredAt`). `matchId` optionnel pour un seul match.
 */
exports.scoreMatchPronos = onCall(
  { cors: true, ...PRONO_SCORE_OPTS },
  async (request) => {
    const { db } = await _requireAdminCall(request);
    const matchId = String(request.data?.matchId ?? '').trim();
    const pending = await findPendingFinishedMatches(db, { matchId });
    const results = [];
    const recaps = [];
    for (const row of pending) {
      results.push(await scoreFinishedMatchPronos(
        db,
        row.id,
        row.data,
        row.ref,
        { sendRecap: false },
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
  let s = String(raw || '').trim().toLowerCase();
  if (!s) return '';
  try {
    s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  } catch (_) {
    // older Node — best-effort accent strip below
  }
  s = s
    .replace(/[àáâãäå]/g, 'a')
    .replace(/[èéêë]/g, 'e')
    .replace(/[ìíîï]/g, 'i')
    .replace(/[òóôõö]/g, 'o')
    .replace(/[ùúûü]/g, 'u')
    .replace(/[ýÿ]/g, 'y')
    .replace(/ç/g, 'c')
    .replace(/ñ/g, 'n');
  s = s.replace(/^\d+\s*[-.]?\s*/, '');
  s = s.replace(/\s+/g, ' ').trim();
  return s;
}

function _isSedanTeamLabel(name) {
  return String(name || '').toUpperCase().includes('SEDAN');
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
  if (matched >= 11) return 3;
  if (matched >= 10) return 2;
  if (matched >= 9) return 1;
  return 0;
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
  const pool = official.map(_normalizePlayerName).filter(Boolean);
  let matched = 0;
  for (const p of predicted) {
    const n = _normalizePlayerName(p);
    if (!n) continue;
    const idx = pool.indexOf(n);
    if (idx >= 0) {
      matched += 1;
      pool.splice(idx, 1);
    }
  }
  return matched;
}

/**
 * Trigger: quand la composition Sedan officielle (≥11 titulaires) est écrite
 * sur `matches/{matchId}`, score les `lineup_predictions` du match.
 * Idempotent — ne re-crédite pas si `awarded` / `lineupPredictionsScored`.
 */
exports.scoreLineupPredictions = onDocumentWritten('matches/{matchId}', async (event) => {
  const after = event.data?.after?.data();
  if (!after) return;

  const matchId = event.params.matchId;
  const db = getFirestore();

  // Lock XI 2 j 12 h avant le coup d’envoi — do NOT score here.
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
      await event.data.after.ref.set({
        lineupPredictionsLocked: true,
      }, { merge: true });
    }
  }

  if (after.lineupPredictionsScored === true) return;

  const team1 = String(after.team1 || '');
  const team2 = String(after.team2 || '');
  let official = [];
  if (_isSedanTeamLabel(team1)) {
    official = _startersFromLineupSide(after.lineupHome);
  } else if (_isSedanTeamLabel(team2)) {
    official = _startersFromLineupSide(after.lineupAway);
  } else {
    return; // not a Sedan match
  }

  if (official.length < 11) return;

  // First time official XI is available → lock + score.
  const predsSnap = await db.collection('lineup_predictions')
    .where('matchId', '==', matchId)
    .get();

  let awardedCount = 0;
  let scoredCount = 0;

  for (let i = 0; i < predsSnap.docs.length; i += 200) {
    const chunk = predsSnap.docs.slice(i, i + 200);
    const batch = db.batch();
    let ops = 0;
    const xpQueue = [];

    for (const doc of chunk) {
      const pred = doc.data() || {};
      if (pred.awarded === true) continue;

      const names = Array.isArray(pred.playerNames) ? pred.playerNames : [];
      const matched = _countNameMatches(names, official);
      const points = _lineupPredPoints(matched);
      const uid = String(pred.uid || '').trim() || String(doc.id).split('_').pop();

      batch.set(doc.ref, {
        awarded: true,
        awardedAt: FieldValue.serverTimestamp(),
        matchedCount: matched,
        points,
        lockedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      ops += 1;
      scoredCount += 1;

      if (uid) xpQueue.push({ uid, matched });

      if (points > 0 && uid) {
        const lbName = String(pred.displayName || '').trim() || 'Membre';
        const lbPatch = {
          uid,
          displayName: lbName,
          displayNameLower: lbName.toLowerCase(),
          points: FieldValue.increment(points),
          updatedAt: FieldValue.serverTimestamp(),
        };
        // 11/11 → +3 pts (_lineupPredPoints) + compteur départage fin de saison.
        // Idempotent : on n’entre ici que si `awarded` n’était pas déjà true.
        if (matched >= 11) {
          lbPatch.perfectXiCount = FieldValue.increment(1);
        }
        batch.set(db.collection('prono_leaderboard').doc(uid), lbPatch, { merge: true });
        awardedCount += 1;
      }
    }

    if (ops > 0) {
      await batch.commit();

      // XP APRÈS le commit, jamais avant : le commit a posé `awarded: true` en
      // même temps que le crédit de classement. Un rejeu du trigger repassera
      // donc par le `continue` plus haut et ne re-créditera rien. En cas de
      // crash entre le commit et cette boucle, l'XP est perdue pour ces
      // pronos — jamais doublée. C'est exactement le schéma déjà utilisé pour
      // l'XP du prono de score.
      for (const item of xpQueue) {
        await _awardXpToUser(db, item.uid, _lineupPredXpEvent(item.matched), {
          matchId,
          matchedCount: item.matched,
        });
      }
    }
  }

  await event.data.after.ref.set({
    lineupPredictionsLocked: true,
    lineupPredictionsScored: true,
    lineupPredictionsScoredAt: FieldValue.serverTimestamp(),
    lineupPredictionsAwardedUsers: awardedCount,
    lineupPredictionsScoredCount: scoredCount,
  }, { merge: true });

  console.log(
    `scoreLineupPredictions match=${matchId} scored=${scoredCount} withPoints=${awardedCount}`,
  );
});

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
