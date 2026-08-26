/**
 * Top ligues : puissance = moyenne des points prono par membre
 * (pas la somme — une ligue de 2 doit pouvoir battre une ligue de 20).
 */

function memberIdsFromLeagueData(data) {
  return (Array.isArray(data?.memberIds) ? data.memberIds : [])
    .map((id) => String(id))
    .filter((id) => id.length > 0);
}

function memberIdsSignature(ids) {
  return [...ids].map(String).sort().join(',');
}

function memberPointsAverage(sum, memberCount) {
  const count = Number(memberCount) || 0;
  if (count <= 0) return 0;
  return Math.round((Number(sum) || 0) / count * 100) / 100;
}

function shouldRecomputeRankingStats(before, after) {
  const memberIds = memberIdsFromLeagueData(after);
  const prevIds = before ? memberIdsFromLeagueData(before) : [];
  const membersChanged = !before || memberIdsSignature(memberIds) !== memberIdsSignature(prevIds);
  const rs = after.rankingStats || {};
  const sumRaw = rs.memberPointsSum;
  const avgRaw = rs.memberPointsAvg;
  const missingStats = sumRaw === undefined || sumRaw === null
    || avgRaw === undefined || avgRaw === null;
  return membersChanged || missingStats;
}

module.exports = {
  memberIdsFromLeagueData,
  memberIdsSignature,
  memberPointsAverage,
  shouldRecomputeRankingStats,
};
