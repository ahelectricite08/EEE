'use strict';

const assert = require('assert');
const {
  buildCrowdXi,
  crowdXiShouldWrite,
  crowdXiUnchanged,
} = require('./lib/crowd_xi');

function pred(names) {
  return { playerNames: names };
}

const a = pred([
  '1 Dupont', 'Martin', 'Lopez', 'Bernard', 'Petit',
  'Moreau', 'Lefevre', 'Garcia', 'Roux', 'Fournier', 'Girard',
]);
const b = pred([
  'Dupont', 'Martin', 'Lopez', 'Bernard', 'Petit',
  'Moreau', 'Lefevre', 'Garcia', 'Roux', 'Fournier', 'X Extra',
]);
const incomplete = pred(['Dupont', 'Martin']);

const crowd = buildCrowdXi([a, b, incomplete]);
assert.strictEqual(crowd.ballots, 2);
assert.strictEqual(crowd.players.length, 11);
assert.strictEqual(crowd.officialComputed, false);
const dupont = crowd.players.find((p) => /dupont/i.test(p.name));
assert.ok(dupont);
assert.strictEqual(dupont.votes, 2);
assert.strictEqual(dupont.inOfficial, false);

const official = [
  '1 Dupont', 'Martin', 'Lopez', 'Bernard', 'Petit',
  'Moreau', 'Lefevre', 'Garcia', 'Roux', 'Fournier', 'Girard',
];
const vsOff = buildCrowdXi([a, b, b], official);
assert.strictEqual(vsOff.officialComputed, true);
assert.strictEqual(vsOff.officialHits, 10);
assert.strictEqual(
  vsOff.players.find((p) => /dupont/i.test(p.name)).inOfficial,
  true,
);
const extra = vsOff.players.find((p) => /extra/i.test(p.name));
assert.ok(extra);
assert.strictEqual(extra.inOfficial, false);

assert.strictEqual(crowdXiUnchanged(vsOff, vsOff), true);
assert.strictEqual(crowdXiShouldWrite(vsOff, vsOff), false);
assert.strictEqual(crowdXiShouldWrite(null, vsOff), true);
assert.strictEqual(crowdXiShouldWrite(null, { players: [], ballots: 0 }), false);

console.log('test_crowd_xi: OK');
