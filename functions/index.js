
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
  './tournament_scoring',
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
