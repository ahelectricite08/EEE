'use strict';

/**
 * Run: node test_push_helpers.js
 */

const assert = require('assert');
const { _userFcmTokens, _userMatchesPlatform } = require('./lib/push_helpers');

assert.deepStrictEqual(
  _userFcmTokens({
    fcmPlatform: 'ios',
    fcmToken: 'ios-legacy',
    fcmTokens: { ios: 'ios-map' },
  }, 'ios'),
  ['ios-map', 'ios-legacy'],
);

assert.deepStrictEqual(
  _userFcmTokens({
    fcmPlatform: 'ios',
    fcmToken: 'ios-legacy',
    fcmTokens: { ios: 'ios-map', android: 'and-map' },
  }, 'android'),
  ['and-map'],
);

assert.deepStrictEqual(
  _userFcmTokens({
    fcmPlatform: 'Android',
    fcmToken: 'and-legacy',
    fcmTokens: { Android: 'and-alias' },
  }, 'android'),
  ['and-alias', 'and-legacy'],
);

assert.deepStrictEqual(
  _userFcmTokens({
    fcmToken: 'only-legacy',
  }, 'android'),
  ['only-legacy'],
);
assert.deepStrictEqual(
  _userFcmTokens({
    fcmToken: 'only-legacy',
  }, 'ios'),
  [],
);

assert.strictEqual(
  _userMatchesPlatform({ fcmHasAndroid: true, fcmTokens: { android: 'x' } }, 'android'),
  true,
);
assert.strictEqual(
  _userMatchesPlatform({ fcmPlatform: 'ios', fcmToken: 'ios-only' }, 'android'),
  false,
);

console.log('test_push_helpers.js ok');
