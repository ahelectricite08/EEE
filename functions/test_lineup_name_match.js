'use strict';

const assert = require('assert');
const {
  normalizePlayerName,
  countNameMatches,
  matchPlayerNames,
  resolvePredictedLabels,
  lineupPredPoints,
} = require('./lib/lineup_name_match');

assert.strictEqual(normalizePlayerName('Dupont'), 'dupont');
assert.strictEqual(normalizePlayerName('dupont'), 'dupont');
assert.strictEqual(normalizePlayerName('9 Dupont'), 'dupont');
assert.strictEqual(normalizePlayerName("N'Goma"), 'ngoma');
assert.strictEqual(normalizePlayerName('Ngoma'), 'ngoma');
assert.strictEqual(normalizePlayerName('Hémery'), 'hemery');
assert.strictEqual(normalizePlayerName('Hemery'), 'hemery');

assert.strictEqual(countNameMatches(['Dupont'], ['dupont']), 1);
assert.strictEqual(countNameMatches(['9 Dupont'], ['Dupont']), 1);
assert.strictEqual(countNameMatches(["N'Goma"], ['Ngoma']), 1);
assert.strictEqual(countNameMatches(['Hémery'], ['Hemery']), 1);
assert.strictEqual(countNameMatches(['Dupont'], ['Jean Dupont']), 1);
assert.strictEqual(countNameMatches(['Jean Dupont'], ['Dupont']), 1);

assert.strictEqual(countNameMatches(['Dupond'], ['Dupont']), 1, 'typo d=1');
assert.strictEqual(countNameMatches(['Hemeri'], ['Hémery']), 1);
assert.strictEqual(countNameMatches(['Moreau'], ['Mareau']), 1, 'd=2 len>=6');
assert.strictEqual(countNameMatches(['Al'], ['Ali']), 0, 'trop court');
assert.strictEqual(
  require('./lib/lineup_name_match').levenshtein('dupont', 'durand'),
  3,
);
assert.strictEqual(countNameMatches(['Dupont'], ['Durand']), 0);
assert.strictEqual(countNameMatches(['Bernard'], ['Renard']), 0);
assert.strictEqual(
  countNameMatches(['Martin'], ['Jean Martin', 'Paul Martin']),
  0,
  'nom pas unique officiel',
);
assert.strictEqual(
  countNameMatches(['Martin', 'Martin'], ['Jean Martin']),
  0,
  'nom pas unique prédit',
);

const hits = matchPlayerNames(
  ['Jean Dupont', 'Intrus', 'Ngoma'],
  ['Dupont', "N'Goma", 'Lopez'],
);
assert.strictEqual(hits.length, 2);
assert.strictEqual(lineupPredPoints(8), 0);
assert.strictEqual(lineupPredPoints(9), 1);
assert.strictEqual(lineupPredPoints(10), 2);
assert.strictEqual(lineupPredPoints(11), 3);

const squad = new Map([['p1', 'Jean Dupont']]);
const resolved = resolvePredictedLabels(['X'], ['p1'], squad);
assert.strictEqual(resolved[0], 'Jean Dupont');
assert.strictEqual(countNameMatches(resolved, ['Dupont']), 1);

console.log('test_lineup_name_match: OK');
