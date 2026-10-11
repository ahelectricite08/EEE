'use strict';

const assert = require('assert');
const { isTemporaryId, kindFor, pickSalonId } = require('./lib/chat_live_salon');

assert.strictEqual(isTemporaryId('live_abc'), true);
assert.strictEqual(isTemporaryId('coupe-de-france'), false);

assert.strictEqual(
  kindFor({ competition: 'Coupe de France Crédit Agricole' }),
  'coupe',
);
assert.strictEqual(kindFor({ competition: 'RÉGIONAL 1 HOMIRIS' }), 'r1');
assert.strictEqual(kindFor({ competition: 'Équipe réserve' }), 'reserve');
assert.strictEqual(kindFor({ competition: 'Régional 2' }), 'reserve');

const salons = [
  { id: 'general', name: 'Général' },
  { id: 'abc', name: 'Coupe de France' },
  { id: 'def', name: 'R1 Homiris' },
  { id: 'ghi', name: 'Réserve' },
  { id: 'live_old', name: '🔴 Live — Sedan vs X' },
];
assert.strictEqual(pickSalonId('coupe', salons), 'abc');
assert.strictEqual(pickSalonId('r1', salons), 'def');
assert.strictEqual(pickSalonId('reserve', salons), 'ghi');

console.log('test_chat_live_salon.js ok');
