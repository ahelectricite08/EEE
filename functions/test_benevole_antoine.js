const assert = require('assert');
const {
  flattenSkills,
  jwtPayload,
  jwtStillValid,
  normalizeEmail,
  normalizeStatus,
  normalizeWishes,
  pickMine,
  matchPutId,
  toPublicMatch,
  wishNamesFromRow,
} = require('./lib/benevole_antoine_map');

const skills = flattenSkills([
  {
    skills: [
      { id: 'a', name: 'Réalisateur' },
      { id: 'b', name: 'Ralenti' },
    ],
  },
]);
assert.deepStrictEqual(skills.names, ['Réalisateur', 'Ralenti']);
assert.strictEqual(skills.idToName.a, 'Réalisateur');

assert.strictEqual(normalizeEmail('  A@B.FR '), 'a@b.fr');
assert.strictEqual(normalizeStatus('present'), 'PRESENT');
assert.strictEqual(normalizeStatus('nope'), null);
assert.deepStrictEqual(
  normalizeWishes(['Réalisateur', 'Réalisateur', 'Ralenti', 'x', 'y']),
  ['Réalisateur', 'Ralenti', 'x'],
);

const mine = pickMine(
  [
    { user: { email: 'other@club.fr' }, status: 'ABSENT' },
    { user: { email: 'A@B.FR' }, status: 'PRESENT', wishSkillIds: ['b'] },
  ],
  'a@b.fr',
);
assert.strictEqual(mine.status, 'PRESENT');
assert.deepStrictEqual(wishNamesFromRow(mine, skills.idToName), ['Ralenti']);

assert.strictEqual(
  matchPutId({ id: 'uuid', externalId: '55794284' }),
  '55794284',
);

const card = toPublicMatch(
  {
    id: 'uuid',
    externalId: '55794284',
    homeTeam: 'SEDAN',
    awayTeam: 'UCKANGE',
  },
  mine,
  skills.idToName,
);
assert.strictEqual(card.putId, '55794284');
assert.strictEqual(card.status, 'PRESENT');
assert.deepStrictEqual(card.wishes, ['Ralenti']);

assert.strictEqual(jwtStillValid(''), false);
const expSoon = Math.floor(Date.now() / 1000) + 3600;
const liveJwt = `e30.${Buffer.from(JSON.stringify({ exp: expSoon })).toString('base64url')}.x`;
assert.strictEqual(jwtPayload(liveJwt).exp, expSoon);
assert.strictEqual(jwtStillValid(liveJwt), true);
const deadJwt = `e30.${Buffer.from(JSON.stringify({ exp: 1000 })).toString('base64url')}.x`;
assert.strictEqual(jwtStillValid(deadJwt), false);

console.log('test_benevole_antoine: OK');
