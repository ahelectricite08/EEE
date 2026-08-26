/**
 * Smoke test — Top ligues (moyenne par membre, signatures, stats manquantes).
 * Run: node functions/test_league_power.js
 */
const {
  memberIdsFromLeagueData,
  memberIdsSignature,
  memberPointsAverage,
  shouldRecomputeRankingStats,
} = require('./lib/league_ranking');

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error('FAIL:', msg);
    failed++;
  } else {
    console.log('OK:', msg);
  }
}

assert(
  memberPointsAverage(20, 2) === 10,
  '2 membres 20 pts → moyenne 10',
);
assert(
  memberPointsAverage(100, 10) === 10,
  '10 membres 100 pts → moyenne 10 (égalité avec la petite ligue)',
);
assert(
  memberPointsAverage(21, 2) === 10.5,
  'moyenne à une décimale',
);
assert(
  memberPointsAverage(0, 2) === 0,
  'membres sans points → 0',
);
assert(
  memberPointsAverage(40, 0) === 0,
  '0 membre → 0 (pas de division par zéro)',
);
assert(
  memberPointsAverage(30, 2) > memberPointsAverage(100, 10),
  'petite ligue 15 de moyenne bat grosse ligue 10 de moyenne',
);

assert(
  shouldRecomputeRankingStats(null, { memberIds: ['a'] }) === true,
  'create without rankingStats → recompute',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3, memberPointsAvg: 3 } },
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3, memberPointsAvg: 3 } },
  ) === false,
  'noop rankingStats write → skip',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3, memberPointsAvg: 3 } },
    { memberIds: ['a', 'b'], rankingStats: { memberPointsSum: 3, memberPointsAvg: 3 } },
  ) === true,
  'join member → recompute',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'] },
    { memberIds: ['a'], rankingStats: { memberPointsSum: 0, memberPointsAvg: 0 } },
  ) === false,
  'only stats filled, members same → skip',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3 } },
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3 } },
  ) === true,
  'sum without avg → backfill moyenne',
);
assert(
  memberIdsSignature(['b', 'a']) === memberIdsSignature(['a', 'b']),
  'member signature order-independent',
);
assert(
  memberIdsFromLeagueData({ memberIds: ['x', ''] }).join(',') === 'x',
  'empty member ids stripped',
);

process.exit(failed ? 1 : 0);
