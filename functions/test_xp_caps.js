/**
 * Plafonds awardXp (callable client) — pas de farm par spam.
 * Run: node functions/test_xp_caps.js
 */
const { _clientXpCapPlan, _dailyCap } = require('./lib/xp_core');

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error('FAIL:', msg);
    failed++;
  } else {
    console.log('OK:', msg);
  }
}

const share = _clientXpCapPlan('share_app');
assert(share.collection === 'xp_once' && share.docId === 'share_app' && share.max === 1,
  'share_app une fois dans la vie');

const profile = _clientXpCapPlan('profile_complete');
assert(profile.collection === 'xp_once' && profile.max === 1, 'profile_complete une fois');

const replayA = _clientXpCapPlan('replay_watched', { matchId: 'm1' });
assert(replayA.docId === 'replay_watched_m1' && replayA.max === 1,
  'replay une fois par match');

const replayNoMatch = _clientXpCapPlan('replay_watched', {});
assert(replayNoMatch.collection === 'xp_daily' && replayNoMatch.max === 1,
  'replay sans matchId → 1 / jour');

const vote = _clientXpCapPlan('vote_prono', { matchId: 'fff_1' });
assert(vote.docId === 'vote_prono_fff_1', 'vote_prono une fois par match');

assert(_dailyCap('article_read') === 5, 'article_read 5 / jour');
assert(_dailyCap('chat_message') === 20, 'chat_message 20 / jour');
assert(_dailyCap('daily_login') === 1, 'daily_login 1 / jour');
assert(_clientXpCapPlan('article_read').collection === 'xp_daily', 'articles = quota journalier');

if (failed) {
  console.error(`\n${failed} échec(s)`);
  process.exit(1);
}
console.log('\nTous les tests XP caps OK');
