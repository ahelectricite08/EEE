'use strict';

/**
 * Run: node test_fff_sync_helpers.js
 */
const assert = require('assert');
const {
  fffHydraNext,
  fffSideTeamName,
  isSedanCssaMatch,
  pickLatestCompleteClassementJournee,
  rankingWriteShouldDeleteLeftovers,
  fffMatchJournee,
} = require('./lib/fff_sync_helpers');

const HOST = 'https://api-dofa.fff.fr';

assert.strictEqual(fffHydraNext(null, HOST), null);
assert.strictEqual(
  fffHydraNext('/api/compets/1/matchs?page=2', HOST),
  'https://api-dofa.fff.fr/api/compets/1/matchs?page=2',
);
assert.strictEqual(
  fffHydraNext('https://api-dofa.fff.fr/api/compets/1/matchs?page=2', HOST),
  'https://api-dofa.fff.fr/api/compets/1/matchs?page=2',
);

assert.strictEqual(fffSideTeamName({ short_name: 'CSSA' }), 'CSSA');
assert.strictEqual(fffSideTeamName({ nom: 'FC Test' }), 'FC Test');
assert.strictEqual(
  fffSideTeamName({ equipe: { short_name: 'REIMS STE ANNE' } }),
  'REIMS STE ANNE',
);
assert.strictEqual(fffSideTeamName(null), '');

function row(j, team) {
  return { cj_no: j, equipe: { short_name: team } };
}

const mixed = [
  ...Array.from({ length: 14 }, (_, i) => row(1, `T${i}`)),
  row(2, 'SEDAN ARDENNES CS'),
];
const picked = pickLatestCompleteClassementJournee(mixed);
assert.strictEqual(picked.lastJournee, 1);
assert.strictEqual(picked.members.length, 14);
assert.strictEqual(picked.complete, true);

const completeJ2 = [
  ...Array.from({ length: 14 }, (_, i) => row(1, `A${i}`)),
  ...Array.from({ length: 14 }, (_, i) => row(2, `B${i}`)),
];
const picked2 = pickLatestCompleteClassementJournee(completeJ2);
assert.strictEqual(picked2.lastJournee, 2);
assert.strictEqual(picked2.members.length, 14);

assert.strictEqual(isSedanCssaMatch('CSSA', 'Nancy'), true);
assert.strictEqual(isSedanCssaMatch('Raon', 'Épinal'), false);

assert.strictEqual(rankingWriteShouldDeleteLeftovers(1), false);
assert.strictEqual(rankingWriteShouldDeleteLeftovers(14), true);

assert.strictEqual(fffMatchJournee({ poule_journee: { number: 6, name: '6' } }), 6);
assert.strictEqual(fffMatchJournee({ journee: 2 }), 2);
assert.strictEqual(fffMatchJournee({}), 0);

console.log('test_fff_sync_helpers: OK');
