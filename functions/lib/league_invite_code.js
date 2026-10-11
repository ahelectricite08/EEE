'use strict';

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function leagueMemberIds(data) {
  const raw = data && data.memberIds;
  if (!Array.isArray(raw)) return [];
  return raw.map((e) => String(e || '').trim()).filter(Boolean);
}

function leagueOwnerUid(data) {
  if (!data) return '';
  for (const key of ['ownerUid', 'ownerId', 'createdBy', 'createdByUid']) {
    const v = String(data[key] || '').trim();
    if (v) return v;
  }
  const members = leagueMemberIds(data);
  return members[0] || '';
}

function isLeagueMemberOrOwner(data, uid) {
  const me = String(uid || '').trim();
  if (!me) return false;
  if (leagueMemberIds(data).includes(me)) return true;
  return leagueOwnerUid(data) === me;
}

function normalizeInviteCode(value) {
  return String(value || '').trim().toUpperCase();
}

function randomLeagueInviteCode(randomFn) {
  const rnd = typeof randomFn === 'function' ? randomFn : Math.random;
  let out = '';
  for (let i = 0; i < 6; i++) {
    out += CODE_ALPHABET[Math.floor(rnd() * CODE_ALPHABET.length)];
  }
  return out;
}

function pickExistingInviteCode({ secret, parentCode, joinCodeId }) {
  const fromSecret = normalizeInviteCode(secret);
  if (fromSecret) return fromSecret;
  const fromParent = normalizeInviteCode(parentCode);
  if (fromParent) return fromParent;
  return normalizeInviteCode(joinCodeId);
}

module.exports = {
  CODE_ALPHABET,
  leagueMemberIds,
  leagueOwnerUid,
  isLeagueMemberOrOwner,
  normalizeInviteCode,
  randomLeagueInviteCode,
  pickExistingInviteCode,
};
