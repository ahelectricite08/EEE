/**
 * Run: node functions/test_league_invite_code.js
 */
const {
  isLeagueMemberOrOwner,
  leagueOwnerUid,
  pickExistingInviteCode,
  randomLeagueInviteCode,
} = require('./lib/league_invite_code');

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
  leagueOwnerUid({ ownerId: 'legacy', memberIds: ['x'] }) === 'legacy',
  'ownerId si ownerUid vide',
);
assert(
  leagueOwnerUid({ createdByUid: 'cbu', memberIds: ['x'] }) === 'cbu',
  'createdByUid si owner vide',
);
assert(
  isLeagueMemberOrOwner({ memberIds: ['a', 'b'] }, 'b') === true,
  'membre voit le salon',
);
assert(
  isLeagueMemberOrOwner({ ownerUid: 'boss', memberIds: ['a'] }, 'boss') === true,
  'créateur hors liste',
);
assert(
  isLeagueMemberOrOwner({ memberIds: ['a'] }, 'z') === false,
  'non-membre refusé',
);
assert(
  pickExistingInviteCode({ secret: '', parentCode: '', joinCodeId: 'ab12' }) ===
    'AB12',
  'repli join-code id',
);
assert(
  pickExistingInviteCode({ secret: ' xy9k ' }) === 'XY9K',
  'secret prioritaire',
);
assert(randomLeagueInviteCode(() => 0).length === 6, 'code 6 caractères');

if (failed) {
  console.error(`${failed} failure(s)`);
  process.exit(1);
}
console.log('All tests passed');
