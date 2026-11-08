
const { initializeApp } = require('firebase-admin/app');

initializeApp();

const MODULES = [
  './notification_triggers',
  './youtube_sync',
  './youtube_live_resolve',
  './youtube_embed',
  './fff_sync',
  './match_callables',
  './prono_scoring',
  './live_push',
  './manual_notifications',
  './xp_system',
  './private_league_join',
  './friend_search',
  './friends',
  './tv_api',
  './match_stats',
  './mediamtx_radio',
  // ADR-0002 / GO 2026-07-26: tournament_scoring (World Cup / Esti) retiré du bundle.
  // Les fonctions déjà déployées (recalculateWorldCupLeaderboard, etc.) restent en
  // prod jusqu’à undeploy manuel — ne plus les ré-exporter depuis ce monolithe.
];

for (const mod of MODULES) {
  Object.assign(exports, require(mod));
}
// Pont scripts GitHub — pas une Cloud Function.
delete exports.runFffCourier;

const { wixArticleWebhook, enrichWixArticleFromSite } = require('./wix_article_webhook');
exports.wixArticleWebhook = wixArticleWebhook;
exports.enrichWixArticleFromSite = enrichWixArticleFromSite;

const helloassoWebhookModule = require('./helloasso_webhook');
exports.helloAssoWebhook = helloassoWebhookModule.helloAssoWebhook;
exports.expireHelloAssoAdherents = helloassoWebhookModule.expireHelloAssoAdherents;
exports.adminLinkHelloAssoPending = helloassoWebhookModule.adminLinkHelloAssoPending;

const quizRaffleModule = require('./quiz_raffle');
exports.drawQuizRaffle = quizRaffleModule.drawQuizRaffle;
exports.closeQuizRaffle = quizRaffleModule.closeQuizRaffle;
exports.tickOpenQuizRaffles = quizRaffleModule.tickOpenQuizRaffles;

const benevoleAntoine = require('./benevole_antoine');
exports.listBenevoleMatches = benevoleAntoine.listBenevoleMatches;
exports.submitBenevoleAvailability = benevoleAntoine.submitBenevoleAvailability;
