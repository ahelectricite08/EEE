'use strict';

/**
 * Run: node test_fff_ranking_logos.js
 */
const assert = require('assert');
const {
  fffLogoString,
  fffClubNo,
  fffTeamLogoFromEquipe,
  collectLogosFromClassementMembers,
  collectLogosFromMatchMembers,
  rankingLogoForEntry,
  membersMissingLogo,
  mergeLogoMaps,
  emptyLogoMaps,
} = require('./lib/fff_ranking_logos');

assert.strictEqual(fffLogoString(null), null);
assert.strictEqual(fffLogoString('  '), null);
assert.strictEqual(
  fffLogoString('https://cdn-transverse.azureedge.net/phlogos/BC542770.jpg'),
  'https://cdn-transverse.azureedge.net/phlogos/BC542770.jpg',
);
assert.strictEqual(
  fffLogoString({ url: 'https://cdn.example/a.png' }),
  'https://cdn.example/a.png',
);

assert.strictEqual(fffClubNo({ club: { cl_no: 22196 } }), 22196);
assert.strictEqual(fffClubNo({ club: '/api/clubs/380' }), 380);
assert.strictEqual(fffClubNo({ club: { cl_no: 380 } }), 380);

const classementRow = {
  equipe: {
    club: { cl_no: 22196, external_updated_at: '2026-08-24T14:45:18+00:00' },
    short_name: 'ETAIN BUZY US',
  },
};
assert.strictEqual(fffTeamLogoFromEquipe(classementRow.equipe), null);
assert.strictEqual(
  collectLogosFromClassementMembers([classementRow]).byClNo.size,
  0,
);

const matchMembers = [
  {
    home: {
      short_name: 'ETAIN BUZY US',
      club: {
        cl_no: 22196,
        logo: 'https://cdn-transverse.azureedge.net/phlogos/BC542770.jpg',
      },
    },
    away: {
      short_name: 'SEDAN ARDENNES CS',
      club: {
        cl_no: 380,
        logo: 'https://cdn-transverse.azureedge.net/phlogos/sedan.jpg',
      },
    },
  },
];
const fromMatches = collectLogosFromMatchMembers(matchMembers);
assert.strictEqual(
  fromMatches.byClNo.get(22196),
  'https://cdn-transverse.azureedge.net/phlogos/BC542770.jpg',
);
assert.strictEqual(
  rankingLogoForEntry(classementRow, fromMatches),
  'https://cdn-transverse.azureedge.net/phlogos/BC542770.jpg',
);

const maps = mergeLogoMaps(emptyLogoMaps(), fromMatches);
assert.strictEqual(membersMissingLogo([classementRow], maps).length, 0);
assert.strictEqual(
  membersMissingLogo(
    [{ equipe: { club: { cl_no: 1 }, short_name: 'INCONNU' } }],
    maps,
  ).length,
  1,
);

console.log('OK test_fff_ranking_logos');
