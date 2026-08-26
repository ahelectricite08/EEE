'use strict';

/**
 * Tests unitaires (sans Firebase) pour le récap journée prono.
 * Run: node test_prono_day_recap.js
 */

const assert = require('assert');
const {
  parisDateKey,
  matchdayToken,
  dayRecapDocId,
  formatPronoDayRecapCopy,
  addPredictionToAgg,
  emptyAgg,
} = require('./lib/prono_day_recap');

assert.strictEqual(parisDateKey(new Date('2026-08-23T18:00:00+02:00')), '2026-08-23');
assert.strictEqual(matchdayToken({ journee: 4 }), 'j4');
assert.strictEqual(matchdayToken({ date: new Date('2026-08-23T15:00:00+02:00') }), 'd2026-08-23');

const copyWin = formatPronoDayRecapCopy({ points: 12, exacts: 3, goods: 3, played: 8 });
assert.strictEqual(copyWin.title, 'Tes pronos : +12 pts');
assert.ok(copyWin.body.includes('3 exacts, 3 bons 1-N-2'));
assert.ok(copyWin.body.includes('N’oublie pas de remplir la prochaine journée'));

const copyExact = formatPronoDayRecapCopy({ points: 3, exacts: 1, goods: 0, played: 1 });
assert.strictEqual(copyExact.title, 'Tes pronos : +3 pts');
assert.ok(copyExact.body.startsWith('1 exact.'));

const copyZero = formatPronoDayRecapCopy({ points: 0, exacts: 0, goods: 0, played: 4 });
assert.strictEqual(copyZero.title, 'Tes pronos : 0 pts');
assert.ok(copyZero.body.startsWith('Aucun point cette journée.'));

const agg = emptyAgg();
addPredictionToAgg(agg, { points: 3 });
addPredictionToAgg(agg, { points: 1 });
addPredictionToAgg(agg, { points: 0 });
assert.strictEqual(agg.points, 4);
assert.strictEqual(agg.exacts, 1);
assert.strictEqual(agg.goods, 1);
assert.strictEqual(agg.played, 3);

const id = dayRecapDocId({
  competition: 'Régional 1',
  fffSeason: '2025-2026',
  journee: 6,
});
assert.strictEqual(id, '2025_2026_regional_1_j6');

console.log('test_prono_day_recap: OK');
