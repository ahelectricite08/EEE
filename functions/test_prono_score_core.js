'use strict';

/**
 * Tests unitaires (sans Firebase) pour le barème prono.
 * Run: node test_prono_score_core.js
 */

const assert = require('assert');
const {
  pointsForProno,
  matchReadyToScorePronos,
  hasMatchScores,
  canTakePronoScoringLock,
} = require('./lib/prono_score_core');

assert.strictEqual(pointsForProno('2', '0', 2, 0), 3, '"2" vs 2 exact');
assert.strictEqual(pointsForProno(2, 0, 2, 0), 3, '2-0 vs 2-0 numbers');
assert.strictEqual(pointsForProno(2, 0, 1, 0), 1, '2-0 vs 1-0 same winner');
assert.strictEqual(pointsForProno(2, 0, 0, 2), 0, '2-0 vs 0-2 miss');
assert.strictEqual(pointsForProno(0, 0, 1, 1), 1, '0-0 vs 1-1 draw');
assert.strictEqual(pointsForProno('abc', 0, 2, 0), 0, 'non-numeric pred → 0');
assert.strictEqual(pointsForProno(2, 0, undefined, 0), 0, 'non-numeric score → 0');

assert.strictEqual(
  matchReadyToScorePronos({ status: 'finished', score1: 1, score2: 0 }),
  true,
  'finished + scores',
);
assert.strictEqual(
  matchReadyToScorePronos({ status: 'finished', score1: 1 }),
  false,
  'finished without both scores',
);
assert.strictEqual(
  matchReadyToScorePronos({
    status: 'live',
    score1: 1,
    score2: 0,
    date: new Date(Date.now() - 30 * 60 * 1000),
  }),
  false,
  'live under 2h not scored',
);
assert.strictEqual(
  matchReadyToScorePronos({
    status: 'live',
    score1: 1,
    score2: 0,
    date: new Date(Date.now() - 3 * 60 * 60 * 1000),
  }),
  true,
  'live after 2h scored',
);
assert.strictEqual(
  matchReadyToScorePronos({
    status: 'upcoming',
    date: new Date(Date.now() - 5 * 60 * 60 * 1000),
  }),
  false,
  'pas de score FFF → jamais scoré, même 5 h après',
);
assert.strictEqual(
  matchReadyToScorePronos({
    status: 'finished',
    score1: 0,
    score2: 0,
  }),
  true,
  '0-0 FFF est un vrai score',
);
assert.strictEqual(
  matchReadyToScorePronos({
    status: 'finished',
    score1: 2,
    score2: 1,
    fffId: '55794284',
  }),
  true,
  'Sedan FFF avec score',
);
assert.strictEqual(
  matchReadyToScorePronos({
    status: 'finished',
    score1: 1,
    score2: 1,
    fffId: '55794280',
  }),
  true,
  'autre club FFF avec score',
);
assert.strictEqual(
  hasMatchScores({ score1: '2', score2: '1' }),
  true,
  'string scores count',
);
assert.strictEqual(
  hasMatchScores({ score1: 2 }),
  false,
  'one score missing',
);

assert.strictEqual(canTakePronoScoringLock({}), true, 'empty match takes lock');
assert.strictEqual(
  canTakePronoScoringLock({ pronoScoredAt: new Date() }),
  false,
  'already scored',
);
assert.strictEqual(
  canTakePronoScoringLock({
    pronoScoringInProgress: true,
    pronoScoringStartedAt: { toMillis: () => Date.now() },
  }),
  false,
  'in progress',
);
assert.strictEqual(
  canTakePronoScoringLock({
    pronoScoringInProgress: true,
    pronoScoringStartedAt: { toMillis: () => Date.now() - 20 * 60 * 1000 },
  }),
  true,
  'stale lock can retry',
);

console.log('test_prono_score_core: OK');

require('./test_lineup_name_match');
