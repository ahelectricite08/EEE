'use strict';

/**
 * Tests unitaires (sans Firebase) pour friend_search_core.
 * Run: node test_friend_search.js
 */

const assert = require('assert');
const {
  normalizeQuery,
  looksLikeEmail,
  buildSearchFields,
  publicUserHit,
  mergeHits,
  capitalizePrefix,
} = require('./lib/friend_search_core');

assert.strictEqual(normalizeQuery('  Axel  '), 'axel');
assert.strictEqual(normalizeQuery(null), '');
assert.ok(looksLikeEmail('axel@dvcr.fr'));
assert.ok(!looksLikeEmail('axel'));
assert.ok(!looksLikeEmail('@dvcr.fr'));

const fields = buildSearchFields({
  email: 'Axel@DVCR.FR',
  firstName: 'Axel',
  lastName: 'Dupont',
});
assert.strictEqual(fields.emailLower, 'axel@dvcr.fr');
assert.strictEqual(fields.displayNameLower, 'axel dupont');
assert.strictEqual(fields.firstNameLower, 'axel');
assert.strictEqual(fields.lastNameLower, 'dupont');

const fieldsDn = buildSearchFields({
  displayName: 'PseudoCool',
  emailLower: 'x@y.z',
});
assert.strictEqual(fieldsDn.displayNameLower, 'pseudocool');

const hit = publicUserHit('uid1', { firstName: 'Axel', lastName: 'D' });
assert.strictEqual(hit.uid, 'uid1');
assert.strictEqual(hit.displayName, 'Axel D');
assert.ok(!('email' in hit));

const map = new Map();
mergeHits(map, 'a', { displayName: 'A' }, 'self');
mergeHits(map, 'self', { displayName: 'Me' }, 'self');
mergeHits(map, 'a', { displayName: 'A2' }, 'self');
assert.strictEqual(map.size, 1);
assert.strictEqual(map.get('a').displayName, 'A');

assert.strictEqual(capitalizePrefix('axel'), 'Axel');

console.log('OK — friend_search_core tests passed');
