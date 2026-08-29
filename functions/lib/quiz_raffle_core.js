'use strict';

/**
 * Tirage quiz-sondage (logique pure, sans Firestore).
 * Un gagnant au hasard parmi les votes dont choiceIndex === correctIndex.
 */

function _toInt(value) {
  if (typeof value === 'number' && Number.isInteger(value)) return value;
  if (typeof value === 'string' && /^-?\d+$/.test(value.trim())) {
    return parseInt(value.trim(), 10);
  }
  return NaN;
}

function eligibleVotes(votes, correctIndex) {
  const ci = _toInt(correctIndex);
  if (!Number.isInteger(ci) || ci < 0) return [];
  const list = Array.isArray(votes) ? votes : [];
  return list.filter((v) => {
    if (!v || typeof v !== 'object') return false;
    return _toInt(v.choiceIndex) === ci;
  });
}

/**
 * @param {Array<{uid?: string, id?: string, choiceIndex?: *, displayName?: string}>} votes
 * @param {number} correctIndex
 * @param {() => number} [randomFn] Math.random-compatible, in [0, 1)
 */
function pickWinner(votes, correctIndex, randomFn) {
  const eligible = eligibleVotes(votes, correctIndex);
  if (eligible.length === 0) {
    return {
      winnerUid: '',
      winnerName: '',
      eligibleCount: 0,
    };
  }
  const rand = typeof randomFn === 'function' ? randomFn : Math.random;
  let n = rand();
  if (typeof n !== 'number' || !Number.isFinite(n) || n < 0) n = 0;
  if (n >= 1) n = 0;
  const i = Math.min(Math.floor(n * eligible.length), eligible.length - 1);
  const picked = eligible[i] || {};
  const uid = String(picked.uid || picked.id || '').trim();
  const name = String(picked.displayName || '').trim();
  return {
    winnerUid: uid,
    winnerName: name || 'Membre',
    eligibleCount: eligible.length,
  };
}

function isPastEndsAt(endsAt, nowMs) {
  if (endsAt == null) return false;
  let ms = NaN;
  if (typeof endsAt.toMillis === 'function') ms = endsAt.toMillis();
  else if (endsAt instanceof Date) ms = endsAt.getTime();
  else if (typeof endsAt === 'number') ms = endsAt;
  else if (typeof endsAt === 'string') ms = Date.parse(endsAt);
  if (!Number.isFinite(ms)) return false;
  return nowMs >= ms;
}

module.exports = {
  eligibleVotes,
  pickWinner,
  isPastEndsAt,
};
