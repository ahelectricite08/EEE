/**
 * Smoke test — logique Top ligues (signatures membres / stats manquantes).
 * Run: node functions/test_league_power.js
 */
function memberIdsFromLeagueData(data) {
  return (Array.isArray(data?.memberIds) ? data.memberIds : [])
    .map((id) => String(id))
    .filter((id) => id.length > 0);
}

function memberIdsSignature(ids) {
  return [...ids].map(String).sort().join(',');
}

function shouldRecomputeRankingStats(before, after) {
  const memberIds = memberIdsFromLeagueData(after);
  const prevIds = before ? memberIdsFromLeagueData(before) : [];
  const membersChanged = !before || memberIdsSignature(memberIds) !== memberIdsSignature(prevIds);
  const sumRaw = after.rankingStats && after.rankingStats.memberPointsSum;
  const missingStats = sumRaw === undefined || sumRaw === null;
  return membersChanged || missingStats;
}

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
  shouldRecomputeRankingStats(null, { memberIds: ['a'] }) === true,
  'create without rankingStats → recompute',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3 } },
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3 } },
  ) === false,
  'noop rankingStats write → skip',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'], rankingStats: { memberPointsSum: 3 } },
    { memberIds: ['a', 'b'], rankingStats: { memberPointsSum: 3 } },
  ) === true,
  'join member → recompute',
);
assert(
  shouldRecomputeRankingStats(
    { memberIds: ['a'] },
    { memberIds: ['a'], rankingStats: { memberPointsSum: 0 } },
  ) === false,
  'only stats filled, members same → skip (after has stats)',
);
assert(
  memberIdsSignature(['b', 'a']) === memberIdsSignature(['a', 'b']),
  'member signature order-independent',
);

process.exit(failed ? 1 : 0);
