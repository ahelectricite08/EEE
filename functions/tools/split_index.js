/**
 * One-shot splitter: reads index.js and writes module files + index.new.js
 * Run: node tools/split_index.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(ROOT, 'index.js'), 'utf8');
const lines = src.split('\n');

function chunk(start, end) {
  return lines.slice(start - 1, end).join('\n');
}

function write(rel, content) {
  const p = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, content.trimEnd() + '\n', 'utf8');
  console.log('  +', rel);
}

write('lib/format_utils.js', `
function _formatDuration(iso) {
  const match = iso.match(/PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?/);
  if (!match) return '';
  const h = parseInt(match[1] ?? 0);
  const m = parseInt(match[2] ?? 0);
  const s = parseInt(match[3] ?? 0);
  if (h > 0) return \`\${h}:\${String(m).padStart(2,'0')}:\${String(s).padStart(2,'0')}\`;
  return \`\${m}:\${String(s).padStart(2,'0')}\`;
}

module.exports = { _formatDuration };
`);

write('lib/app_brand.js', `
const APP_BRAND_NAME = 'Drapeau Vert Carton Rouge';
const CLUB_SHORT_NAME = 'CSSA';

module.exports = { APP_BRAND_NAME, CLUB_SHORT_NAME };
`);

write('lib/fff_config.js', chunk(15, 20) + '\n\n' + chunk(25, 26) + '\n\n' + chunk(52, 77) + `

module.exports = {
  FFF_BASE,
  FFF_HOST,
  FFF_CP,
  FFF_PH,
  FFF_GP,
  FFF_CLUB,
  FFF_CONFIG_DOC,
  FFF_LIFECYCLE_DOC,
  _loadFffSeasonConfig,
};
`);

write('lib/xp_core.js', chunk(2965, 3112) + `

module.exports = {
  DEFAULT_XP,
  _parseEventEntry,
  _eventXpFromConfig,
  DEFAULT_LEVELS,
  _computeLevel,
  _getXpConfig,
  _dailyCap,
  _awardXpToUser,
  _checkBadges,
};
`);

// Prepend Timestamp import to xp_core
const xpCorePath = path.join(ROOT, 'lib/xp_core.js');
let xpCore = fs.readFileSync(xpCorePath, 'utf8');
xpCore = `const { Timestamp, FieldValue } = require('firebase-admin/firestore');\n\n${xpCore}`;
fs.writeFileSync(xpCorePath, xpCore, 'utf8');

// Prepend getFirestore to fff_config
const fffConfigPath = path.join(ROOT, 'lib/fff_config.js');
let fffConfig = fs.readFileSync(fffConfigPath, 'utf8');
fffConfig = `const { getFirestore } = require('firebase-admin/firestore');\n\n${fffConfig}`;
fs.writeFileSync(fffConfigPath, fffConfig, 'utf8');

const HEAD = {
  notification_triggers: `const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { fcmChannelBlocks } = require('./notification_push');
const { _isUserAdmin } = require('./lib/admin_auth');
const {
  _sendFcm, _sendFcmToUser, _sendTeamDvcrNotification, _notifPref, _skipMentionPushForRecipient,
} = require('./lib/push_helpers');

`,

  youtube_sync: `const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { _requireAdminCall } = require('./lib/admin_auth');
const { _formatDuration } = require('./lib/format_utils');

const youtubeApiKeySecret = defineSecret('YOUTUBE_API_KEY');

`,

  fff_sync: `const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _isUserAdmin } = require('./lib/admin_auth');
const {
  FFF_BASE, FFF_HOST, FFF_CP, FFF_PH, FFF_GP, FFF_CLUB,
  FFF_CONFIG_DOC, FFF_LIFECYCLE_DOC, _loadFffSeasonConfig,
} = require('./lib/fff_config');

`,

  match_callables: `const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { _isUserAdmin } = require('./lib/admin_auth');
const { _sendFcm, _sendManualBroadcast } = require('./lib/push_helpers');
const { fcmChannelBlocks } = require('./notification_push');

`,

  prono_scoring: `const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _isUserAdmin } = require('./lib/admin_auth');
const { _loadFffSeasonConfig } = require('./lib/fff_config');
const { _awardXpToUser } = require('./lib/xp_core');
const {
  _notificationsPaused, _sendFcmToUser, _userFcmTokens, _notifPref,
} = require('./lib/push_helpers');
const { fcmChannelBlocks } = require('./notification_push');

`,

  live_push: `const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { fcmChannelBlocks } = require('./notification_push');
const { APP_BRAND_NAME, CLUB_SHORT_NAME } = require('./lib/app_brand');
const { _sendFcm } = require('./lib/push_helpers');

`,

  manual_notifications: `const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { _normalizeTargetUserIds } = require('./lib/admin_auth');
const {
  _sendFcm, _sendFcmToUser, _sendManualBroadcast, _sendTeamDvcrNotification,
  _sendAdherentNotification, _loadMaintenanceConfig, _notificationsPaused,
} = require('./lib/push_helpers');
const { fcmChannelBlocks, channelFromTopic } = require('./notification_push');

`,

  xp_system: `const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const {
  _requireAdminCall, _isUserAdmin, CLIENT_AWARD_XP_EVENTS, _toSafeString, _pickPrimaryRole,
} = require('./lib/admin_auth');
const { _deleteFirestoreCollectionInBatches } = require('./lib/push_helpers');
const {
  _eventXpFromConfig, _computeLevel, _getXpConfig, _awardXpToUser,
} = require('./lib/xp_core');

`,

  tv_api: `const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _toSafeString } = require('./lib/admin_auth');
const { APP_BRAND_NAME } = require('./lib/app_brand');

`,

  match_stats: `const { onSchedule, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { _requireAdminCall } = require('./lib/admin_auth');

`,
};

const RANGES = {
  notification_triggers: [[154, 522]],
  youtube_sync: [[120, 125], [127, 152], [564, 687]],
  fff_sync: [[79, 115], [689, 858], [860, 1307]],
  match_callables: [[1309, 1478]],
  prono_scoring: [[1480, 1802], [2765, 2894], [2906, 2959]],
  live_push: [[523, 562], [1804, 2556]],
  manual_notifications: [[2561, 2762]],
  xp_system: [[3191, 3567]],
  tv_api: [[3581, 4045]],
  match_stats: [[4047, 4530]],
};

for (const [name, ranges] of Object.entries(RANGES)) {
  const body = ranges.map(([s, e]) => chunk(s, e)).join('\n\n');
  write(`${name}.js`, HEAD[name] + body);
}

write('index.new.js', `
const { initializeApp } = require('firebase-admin/app');

initializeApp();

const MODULES = [
  './notification_triggers',
  './youtube_sync',
  './fff_sync',
  './match_callables',
  './prono_scoring',
  './live_push',
  './manual_notifications',
  './xp_system',
  './tv_api',
  './match_stats',
  // tournament_scoring retiré (ADR-0002 / GO Esti+CdM 2026-07-26)
];

for (const mod of MODULES) {
  Object.assign(exports, require(mod));
}

const { wixArticleWebhook, enrichWixArticleFromSite } = require('./wix_article_webhook');
exports.wixArticleWebhook = wixArticleWebhook;
exports.enrichWixArticleFromSite = enrichWixArticleFromSite;

const helloassoWebhookModule = require('./helloasso_webhook');
exports.helloAssoWebhook = helloassoWebhookModule.helloAssoWebhook;
exports.expireHelloAssoAdherents = helloassoWebhookModule.expireHelloAssoAdherents;
`);

console.log('\nDone. Validating...');
