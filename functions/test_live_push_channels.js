'use strict';

/**
 * Run: node test_live_push_channels.js
 */

const assert = require('assert');
const {
  fcmChannelBlocks,
  fcmAndroidVisibleApnsSilent,
  LIVE_SILENT_SYNC_TOPIC,
  LIVE_VISIBLE_BANNER_TOPIC,
  LIVE_ANDROID_TAG,
} = require('./notification_push');

assert.strictEqual(LIVE_SILENT_SYNC_TOPIC, 'dvcr_live');
assert.strictEqual(LIVE_VISIBLE_BANNER_TOPIC, 'dvcr_live_banners');
assert.notStrictEqual(
  LIVE_SILENT_SYNC_TOPIC,
  'dvcr_live_events',
  'silent sync must not also target dvcr_live_events (Android 2×/3× notifs)',
);

const visible = fcmChannelBlocks('dvcr_live', {
  tag: LIVE_ANDROID_TAG,
  collapseKey: LIVE_ANDROID_TAG,
});
assert.strictEqual(visible.android.collapseKey, 'dvcr_live');
assert.strictEqual(visible.android.notification.tag, 'dvcr_live');
assert.strictEqual(visible.android.notification.channelId, 'dvcr_live');

const silent = fcmChannelBlocks('dvcr_live', {
  silent: true,
  contentAvailable: true,
  priority: 'high',
});
assert.strictEqual(silent.android.notification, undefined);
assert.ok(!Object.prototype.hasOwnProperty.call(silent.android, 'notification'));
assert.strictEqual(silent.android.priority, 'high');

const banner = fcmChannelBlocks('dvcr_live');
assert.strictEqual(banner.android.notification.tag, 'dvcr_live');

const hybrid = fcmAndroidVisibleApnsSilent('dvcr_live', {
  tag: LIVE_ANDROID_TAG,
  collapseKey: LIVE_ANDROID_TAG,
  title: 'BUT !',
  body: '1-0',
});
assert.strictEqual(hybrid.android.notification.channelId, 'dvcr_live');
assert.strictEqual(hybrid.android.notification.tag, 'dvcr_live');
assert.strictEqual(hybrid.android.notification.title, 'BUT !');
assert.strictEqual(hybrid.android.notification.body, '1-0');
assert.strictEqual(hybrid.apns.headers['apns-push-type'], 'background');
assert.strictEqual(hybrid.apns.payload.aps['content-available'], 1);
assert.strictEqual(hybrid.apns.payload.aps.sound, undefined);

console.log('test_live_push_channels.js ok');
