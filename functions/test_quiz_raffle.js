'use strict';

/**
 * Tests unitaires (sans Firebase) pour quiz_raffle_core.
 * Run: node test_quiz_raffle.js
 */

const assert = require('assert');
const { eligibleVotes, pickWinner, isPastEndsAt } = require('./lib/quiz_raffle_core');

const votes = [
  { uid: 'a', choiceIndex: 0, displayName: 'Ada' },
  { uid: 'b', choiceIndex: 1, displayName: 'Bix' },
  { uid: 'c', choiceIndex: 1, displayName: 'Coco' },
  { uid: 'd', choiceIndex: 2, displayName: 'Dan' },
];

assert.strictEqual(eligibleVotes(votes, 1).length, 2);
assert.strictEqual(eligibleVotes(votes, 9).length, 0);
assert.strictEqual(eligibleVotes(null, 1).length, 0);

const none = pickWinner(votes, 3);
assert.strictEqual(none.winnerUid, '');
assert.strictEqual(none.winnerName, '');
assert.strictEqual(none.eligibleCount, 0);

const onlyB = pickWinner(votes, 1, () => 0);
assert.strictEqual(onlyB.winnerUid, 'b');
assert.strictEqual(onlyB.winnerName, 'Bix');
assert.strictEqual(onlyB.eligibleCount, 2);

const onlyC = pickWinner(votes, 1, () => 0.999);
assert.strictEqual(onlyC.winnerUid, 'c');
assert.strictEqual(onlyC.winnerName, 'Coco');

const empty = pickWinner([], 0);
assert.strictEqual(empty.winnerUid, '');
assert.strictEqual(empty.eligibleCount, 0);

assert.strictEqual(isPastEndsAt(new Date(1000), 1000), true);
assert.strictEqual(isPastEndsAt(new Date(2000), 1000), false);
assert.strictEqual(isPastEndsAt({ toMillis: () => 50 }, 50), true);
assert.strictEqual(isPastEndsAt(null, 1), false);

console.log('OK — quiz_raffle_core tests passed');
