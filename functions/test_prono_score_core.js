'use strict';

/**
 * Tests unitaires (sans Firebase) pour le barème prono.
 * Run: node test_prono_score_core.js
 */

const assert = require('assert');
const { pointsForProno } = require('./lib/prono_score_core');

assert.strictEqual(pointsForProno('2', '0', 2, 0), 3, '"2" vs 2 exact');
assert.strictEqual(pointsForProno(2, 0, 2, 0), 3, '2-0 vs 2-0 numbers');
assert.strictEqual(pointsForProno(2, 0, 1, 0), 1, '2-0 vs 1-0 same winner');
assert.strictEqual(pointsForProno(2, 0, 0, 2), 0, '2-0 vs 0-2 miss');
assert.strictEqual(pointsForProno(0, 0, 1, 1), 1, '0-0 vs 1-1 draw');
assert.strictEqual(pointsForProno('abc', 0, 2, 0), 0, 'non-numeric pred → 0');
assert.strictEqual(pointsForProno(2, 0, undefined, 0), 0, 'non-numeric score → 0');

console.log('test_prono_score_core: OK');
