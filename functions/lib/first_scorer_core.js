'use strict';

const { FieldValue } = require('firebase-admin/firestore');
const { _awardXpToUser } = require('./xp_core');

const SEDAN_HIT = 3;
const SEDAN_HIT_XP = 10;
const SEDAN_HIT_XP_EVENT = 'first_scorer_cssa';
const OPPONENT_HIT = 1;

function _normalizePlayerName(raw) {
  let s = String(raw || '').trim().toLowerCase();
  if (!s) return '';
  try {
    s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  } catch (_) {
    // older Node
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

function _isCssaTeamLabel(name) {
  const u = String(name || '').toUpperCase();
  return u.includes('SEDAN') || u.includes('CSSA');
}

function _eventMinute(e) {
  const v = e && e.minute;
  if (typeof v === 'number' && Number.isFinite(v)) return Math.round(v);
  if (typeof v === 'string') {
    const n = parseInt(v.trim(), 10);
    return Number.isFinite(n) ? n : 0;
  }
  return 0;
}

function _eventIsSedanSide(event, team1, team2) {
  const teamRaw = String((event && (event.team || event.teamName)) || '').trim();
  if (teamRaw) {
    if (_isCssaTeamLabel(teamRaw)) return true;
    const u = teamRaw.toUpperCase();
    if (_isCssaTeamLabel(team1) && u === String(team1).trim().toUpperCase()) {
      return true;
    }
    if (_isCssaTeamLabel(team2) && u === String(team2).trim().toUpperCase()) {
      return true;
    }
  }
  const side = String((event && (event.side || event.teamSide)) || '')
    .trim()
    .toLowerCase();
  const home = side === 'home' || side === 'team1' || event?.isHome === true
    || (typeof event?.teamIndex === 'number' && event.teamIndex === 0);
  if (_isCssaTeamLabel(team1) && home) return true;
  if (_isCssaTeamLabel(team2) && event?.isHome === false) return true;
  if (_isCssaTeamLabel(team2) && side && !home) return true;
  return false;
}

function collectMatchEvents(match) {
  const a = Array.isArray(match?.events) ? match.events : [];
  const b = Array.isArray(match?.liveEvents) ? match.liveEvents : [];
  return [...a, ...b].filter((e) => e && typeof e === 'object');
}

function resolveFirstScorer(match) {
  const ov = match?.firstScorerOverride;
  if (ov && typeof ov === 'object') {
    const kind = String(ov.kind || '').trim();
    const playerName = String(ov.playerName || '').trim();
    if (kind === 'opponent') return { kind: 'opponent', playerId: '', playerName: '' };
    if (kind === 'sedan' && playerName) {
      return {
        kind: 'sedan',
        playerId: String(ov.playerId || '').trim(),
        playerName,
      };
    }
  }

  const team1 = String(match?.team1 || '');
  const team2 = String(match?.team2 || '');
  const scored = collectMatchEvents(match).filter((e) => {
    const type = String(e.type || '').trim().toLowerCase();
    return type === 'goal' || type === 'own_goal';
  });
  if (!scored.length) return null;
  scored.sort((a, b) => _eventMinute(a) - _eventMinute(b));
  const first = scored[0];
  const type = String(first.type || '').trim().toLowerCase();
  const sedanSide = _eventIsSedanSide(first, team1, team2);
  const player = String(first.player || '').trim();

  if (type === 'own_goal') {
    if (sedanSide) return { kind: 'opponent', playerId: '', playerName: '' };
    return { kind: 'sedan', playerId: '', playerName: player };
  }
  if (sedanSide) return { kind: 'sedan', playerId: '', playerName: player };
  return { kind: 'opponent', playerId: '', playerName: '' };
}

function matchInvolvesCssa(match) {
  return _isCssaTeamLabel(match?.team1) || _isCssaTeamLabel(match?.team2);
}

function cssaFirstScorerHit(pick, resolved) {
  if (!resolved || resolved.kind !== 'sedan') return false;
  if (String(pick?.kind || '').trim() !== 'sedan') return false;
  const pickId = String(pick?.playerId || '').trim();
  const resolvedId = String(resolved.playerId || '').trim();
  if (pickId && resolvedId && pickId === resolvedId) return true;
  const a = _normalizePlayerName(pick?.playerName);
  const b = _normalizePlayerName(resolved.playerName);
  return Boolean(a && a === b);
}

function pointsForFirstScorerPick(pick, resolved) {
  if (!resolved || !resolved.kind) return 0;
  const kind = String(pick?.kind || '').trim();
  if (kind === 'opponent') return resolved.kind === 'opponent' ? OPPONENT_HIT : 0;
  return cssaFirstScorerHit(pick, resolved) ? SEDAN_HIT : 0;
}

function xpForFirstScorerPick(pick, resolved) {
  return cssaFirstScorerHit(pick, resolved) ? SEDAN_HIT_XP : 0;
}

/**
 * Idempotent via matches.firstScorerBetsScored + pick.awarded.
 * Ne touche pas aux points 1N2 / XI (`predictions.points`, lineup_predictions).
 */
async function scoreFirstScorerBetsForMatch(db, matchId, matchData, matchRef) {
  if (!matchData || matchData.firstScorerBetsScored === true) return { skipped: true };
  if (!matchInvolvesCssa(matchData)) return { skipped: true, notCssa: true };

  const resolved = resolveFirstScorer(matchData);
  const status = String(matchData.status || '');
  if (!resolved && status !== 'finished') {
    return { skipped: true, waiting: true };
  }

  const predsSnap = await db.collection('first_scorer_bets')
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
      const pick = doc.data() || {};
      if (pick.awarded === true) continue;

      const points = pointsForFirstScorerPick(pick, resolved);
      const xp = xpForFirstScorerPick(pick, resolved);
      const uid = String(pick.uid || '').trim() || String(doc.id).split('_').pop();

      batch.set(doc.ref, {
        awarded: true,
        awardedAt: FieldValue.serverTimestamp(),
        points,
        xp,
      }, { merge: true });
      ops += 1;
      scoredCount += 1;

      if (xp > 0 && uid) xpQueue.push({ uid });

      if (points > 0 && uid) {
        const lbName = String(pick.displayName || '').trim() || 'Membre';
        batch.set(db.collection('prono_leaderboard').doc(uid), {
          uid,
          displayName: lbName,
          displayNameLower: lbName.toLowerCase(),
          points: FieldValue.increment(points),
          firstScorerPoints: FieldValue.increment(points),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      if ((points > 0 || xp > 0) && uid) awardedCount += 1;
    }

    if (ops > 0) {
      await batch.commit();
      for (const item of xpQueue) {
        await _awardXpToUser(db, item.uid, SEDAN_HIT_XP_EVENT, { matchId });
      }
    }
  }

  await matchRef.set({
    firstScorerBetsScored: true,
    firstScorerBetsScoredAt: FieldValue.serverTimestamp(),
    firstScorerResolvedKind: resolved ? resolved.kind : 'none',
    firstScorerResolvedPlayerName: resolved ? (resolved.playerName || '') : '',
    firstScorerBetsAwardedUsers: awardedCount,
    firstScorerBetsScoredCount: scoredCount,
  }, { merge: true });

  return { skipped: false, scoredCount, awardedCount };
}

module.exports = {
  resolveFirstScorer,
  pointsForFirstScorerPick,
  xpForFirstScorerPick,
  matchInvolvesCssa,
  scoreFirstScorerBetsForMatch,
  SEDAN_HIT,
  SEDAN_HIT_XP,
  OPPONENT_HIT,
};
