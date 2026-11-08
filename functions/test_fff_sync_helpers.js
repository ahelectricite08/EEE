'use strict';

/**
 * Run: node test_fff_sync_helpers.js
 */
const assert = require('assert');
const {
  fffHydraNext,
  fffPouleCalendrierUrl,
  fffPouleClassementUrl,
  fffPouleMatchsUrl,
  fffHydraLastPage,
  fffUrlWithPage,
  fffMatchHasPublishedScore,
  prioritizeFffMatchesForSync,
  fffClubMatchsUrl,
  resolveCssaDofaClubNo,
  isFffCupOrFriendly,
  isSeniorFirstTeamClubMatch,
  fffCompetitionLabel,
  fffSideTeamName,
  isSedanCssaMatch,
  pickLatestCompleteClassementJournee,
  rankingWriteShouldDeleteLeftovers,
  rankingRowEquals,
  sanitizeClassementMembers,
  rankingTeamOverlapOk,
  fffRankingHttpHint,
  fffMatchJournee,
} = require('./lib/fff_sync_helpers');

const HOST = 'https://api-dofa.fff.fr';
const API = `${HOST}/api`;

assert.strictEqual(
  fffPouleCalendrierUrl(API, 449966, 1, 1),
  'https://api-dofa.fff.fr/api/compets/449966/phases/1/poules/1/calendrier?itemsPerPage=50',
);
assert.strictEqual(
  fffPouleClassementUrl(API, 449966, 1, 1),
  'https://api-dofa.fff.fr/api/compets/449966/phases/1/poules/1/classement_journees?itemsPerPage=200',
);
assert.strictEqual(
  fffPouleMatchsUrl(API, 449972, 1, 1),
  'https://api-dofa.fff.fr/api/compets/449972/phases/1/poules/1/matchs?itemsPerPage=100',
);

assert.strictEqual(
  fffHydraLastPage({
    'hydra:view': {
      'hydra:last':
        '/api/compets/449966/phases/1/poules/1/matchs?itemsPerPage=30&page=7',
    },
  }),
  7,
);
assert.strictEqual(
  fffUrlWithPage('https://api-dofa.fff.fr/api/compets/1/matchs?itemsPerPage=30', 3),
  'https://api-dofa.fff.fr/api/compets/1/matchs?itemsPerPage=30&page=3',
);
assert.strictEqual(fffMatchHasPublishedScore({ home_score: 1, away_score: 2 }), true);
assert.strictEqual(fffMatchHasPublishedScore({ home_score: 1 }), false);
{
  const j1 = { date: '2026-08-23T00:00:00+00:00', home_score: 1, away_score: 2 };
  const j9 = { date: '2026-11-01T00:00:00+00:00', home_score: 3, away_score: 0 };
  const next = { date: '2026-11-08T00:00:00+00:00' };
  const ordered = [j1, next, j9].sort(prioritizeFffMatchesForSync);
  assert.strictEqual(ordered[0], j9);
  assert.strictEqual(ordered[1], j1);
  assert.strictEqual(ordered[2], next);
}

assert.strictEqual(fffHydraNext(null, HOST), null);
assert.strictEqual(
  fffHydraNext('/api/compets/1/matchs?page=2', HOST),
  'https://api-dofa.fff.fr/api/compets/1/matchs?page=2',
);
assert.strictEqual(
  fffHydraNext('https://api-dofa.fff.fr/api/compets/1/matchs?page=2', HOST),
  'https://api-dofa.fff.fr/api/compets/1/matchs?page=2',
);

assert.strictEqual(fffSideTeamName({ short_name: 'CSSA' }), 'CSSA');
assert.strictEqual(fffSideTeamName({ nom: 'FC Test' }), 'FC Test');
assert.strictEqual(
  fffSideTeamName({ equipe: { short_name: 'REIMS STE ANNE' } }),
  'REIMS STE ANNE',
);
assert.strictEqual(fffSideTeamName(null), '');

function row(j, team) {
  return { cj_no: j, equipe: { short_name: team } };
}

const mixed = [
  ...Array.from({ length: 14 }, (_, i) => row(1, `T${i}`)),
  row(2, 'SEDAN ARDENNES CS'),
];
const picked = pickLatestCompleteClassementJournee(mixed);
assert.strictEqual(picked.lastJournee, 1);
assert.strictEqual(picked.members.length, 14);
assert.strictEqual(picked.complete, true);

const completeJ2 = [
  ...Array.from({ length: 14 }, (_, i) => row(1, `A${i}`)),
  ...Array.from({ length: 14 }, (_, i) => row(2, `B${i}`)),
];
const picked2 = pickLatestCompleteClassementJournee(completeJ2);
assert.strictEqual(picked2.lastJournee, 2);
assert.strictEqual(picked2.members.length, 14);

assert.strictEqual(isSedanCssaMatch('CSSA', 'Nancy'), true);
assert.strictEqual(isSedanCssaMatch('Raon', 'Épinal'), false);

assert.strictEqual(rankingWriteShouldDeleteLeftovers(1), false);
assert.strictEqual(rankingWriteShouldDeleteLeftovers(14), true);

const splitIncomplete = [
  ...Array.from({ length: 7 }, (_, i) => row(6, `A${i}`)),
  ...Array.from({ length: 7 }, (_, i) => row(7, `B${i}`)),
];
const pickedSplit = pickLatestCompleteClassementJournee(splitIncomplete);
assert.strictEqual(pickedSplit.complete, false);
assert.strictEqual(pickedSplit.lastJournee, 7);

const samePtsNewJournee = {
  position: 1,
  team: 'SEDAN ARDENNES CS',
  logo: null,
  mj: 6,
  v: 6,
  n: 0,
  d: 0,
  bf: 20,
  bc: 4,
  pts: 18,
  forme: 'WWWWWW',
  season: '2026-2027',
  journee: 6,
};
const nextJournee = { ...samePtsNewJournee, mj: 7, v: 7, pts: 21, journee: 7 };
assert.strictEqual(rankingRowEquals(samePtsNewJournee, samePtsNewJournee), true);
assert.strictEqual(rankingRowEquals(samePtsNewJournee, nextJournee), false);
assert.strictEqual(
  rankingRowEquals(samePtsNewJournee, { ...samePtsNewJournee, journee: 7 }),
  false,
);

assert.ok(fffRankingHttpHint(403).includes('WAF'));
assert.ok(fffRankingHttpHint(404).includes('ids'));
assert.ok(!fffRankingHttpHint(403).includes('ids compétition'));

assert.strictEqual(fffMatchJournee({ poule_journee: { number: 6, name: '6' } }), 6);
assert.strictEqual(fffMatchJournee({ journee: 2 }), 2);
assert.strictEqual(fffMatchJournee({}), 0);

const sanitized = sanitizeClassementMembers([
  { rank: 1, cj_no: 4, point_count: 12, equipe: { short_name: 'CSSA' }, hack: true },
  { rank: 1, equipe: { short_name: 'DOUBLON' } },
  { rank: 99, equipe: { short_name: 'TROP' } },
  { rank: 2, equipe: { short_name: 'Pau' } },
]);
assert.strictEqual(sanitized.length, 2);
assert.strictEqual(sanitized[0].equipe.short_name, 'CSSA');
assert.strictEqual(sanitized[0].hack, undefined);
assert.strictEqual(sanitized[1].rank, 2);

assert.strictEqual(
  rankingTeamOverlapOk(
    ['CSSA', 'PAU', 'A', 'B', 'C', 'D', 'E', 'F'],
    ['CSSA', 'PAU', 'A', 'B', 'C', 'D', 'E', 'F'],
  ),
  true,
);
assert.strictEqual(
  rankingTeamOverlapOk(
    ['CSSA', 'PAU', 'A', 'B', 'C', 'D', 'E', 'F'],
    ['OM', 'PSG', 'OL', 'ASSE', 'LILLE', 'NANTES', 'RENNES', 'NICE'],
  ),
  false,
);
assert.strictEqual(rankingTeamOverlapOk(['CSSA'], ['OM']), true);
assert.strictEqual(
  rankingTeamOverlapOk(
    [
      'SEDAN ARDENNES CS', 'REIMS STE ANNE', 'A', 'B', 'C', 'D', 'E', 'F',
      'VIEUX1', 'VIEUX2', 'VIEUX3', 'VIEUX4', 'VIEUX5', 'VIEUX6',
    ],
    ['SEDAN ARDENNES CS', 'REIMS STE ANNE', 'A', 'B', 'C', 'D', 'E', 'F'],
  ),
  true,
);

assert.strictEqual(
  fffClubMatchsUrl(API, 380),
  'https://api-dofa.fff.fr/api/clubs/380/matchs?itemsPerPage=100',
);
assert.strictEqual(resolveCssaDofaClubNo(500266), 380);
assert.strictEqual(resolveCssaDofaClubNo(380), 380);
assert.strictEqual(
  fffCompetitionLabel('COUPE DE FRANCE CRÉDIT AGRICOLE', 'CP'),
  'Coupe de France',
);
assert.strictEqual(fffCompetitionLabel('MATCHS AMICAUX', 'AC'), 'Match Amical');
assert.strictEqual(
  isSeniorFirstTeamClubMatch({
    home: { category_code: 'SEM', number: 1, club: { cl_no: 380 } },
    away: { category_code: 'SEM', number: 1, club: { cl_no: 12 } },
    competition: { type: 'CP' },
  }, 380),
  true,
);
assert.strictEqual(
  isSeniorFirstTeamClubMatch({
    home: { category_code: 'SEM', number: 1, club: { cl_no: 380 }, short_name: 'TORCY SEDAN OLYMP.' },
    competition: { type: 'CP' },
  }, 999),
  false,
);
assert.strictEqual(
  isSeniorFirstTeamClubMatch({
    home: { category_code: 'SEM', number: 3, club: { cl_no: 380 } },
    competition: { type: 'CH' },
  }, 380),
  false,
);
assert.strictEqual(
  isFffCupOrFriendly({ competition: { type: 'CP' } }),
  true,
);
assert.strictEqual(
  isFffCupOrFriendly({ competition: { type: 'CH' } }),
  false,
);

console.log('test_fff_sync_helpers: OK');
