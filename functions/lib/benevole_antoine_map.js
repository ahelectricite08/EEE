/** Mapping API Antoine (dispos bénévoles) — sans I/O. */

function flattenSkills(categories) {
  const names = [];
  const idToName = Object.create(null);
  const seen = new Set();
  for (const cat of Array.isArray(categories) ? categories : []) {
    for (const sk of Array.isArray(cat?.skills) ? cat.skills : []) {
      const id = String(sk?.id || '').trim();
      const name = String(sk?.name || '').trim();
      if (!name) continue;
      if (id) idToName[id] = name;
      if (seen.add(name)) names.push(name);
    }
  }
  return { names, idToName };
}

function normalizeEmail(raw) {
  return String(raw || '').trim().toLowerCase();
}

function normalizeStatus(raw) {
  const s = String(raw || '').trim().toUpperCase();
  if (s === 'PRESENT' || s === 'ABSENT') return s;
  return null;
}

function normalizeWishes(raw, max = 3) {
  if (!Array.isArray(raw)) return [];
  const out = [];
  const seen = new Set();
  for (const item of raw) {
    const name = String(item || '').trim();
    if (!name || seen.has(name.toLowerCase())) continue;
    seen.add(name.toLowerCase());
    out.push(name);
    if (out.length >= max) break;
  }
  return out;
}

function wishNamesFromRow(row, idToName) {
  const ids = Array.isArray(row?.wishSkillIds) ? row.wishSkillIds : [];
  const names = [];
  const seen = new Set();
  for (const id of ids) {
    const name = idToName[String(id || '').trim()];
    if (!name || seen.has(name)) continue;
    seen.add(name);
    names.push(name);
  }
  if (names.length) return names;
  return normalizeWishes(row?.wishes);
}

function pickMine(rows, email) {
  const needle = normalizeEmail(email);
  if (!needle || !Array.isArray(rows)) return null;
  return (
    rows.find((row) => normalizeEmail(row?.user?.email) === needle) || null
  );
}

function jwtPayload(token) {
  const parts = String(token || '').split('.');
  if (parts.length < 2) return null;
  try {
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4 === 0 ? '' : '='.repeat(4 - (b64.length % 4));
    return JSON.parse(Buffer.from(b64 + pad, 'base64').toString('utf8'));
  } catch (_) {
    return null;
  }
}

function jwtStillValid(token, skewSec = 60) {
  const raw = String(token || '').trim();
  if (!raw) return false;
  const p = jwtPayload(raw);
  if (!p || !p.exp) return true;
  return Date.now() / 1000 < Number(p.exp) - skewSec;
}

function matchPutId(match) {
  const external = String(match?.externalId || '').trim();
  if (external) return external;
  return String(match?.id || '').trim();
}

function toPublicMatch(match, mine, idToName) {
  return {
    id: String(match?.id || ''),
    putId: matchPutId(match),
    sport: String(match?.sport || ''),
    source: String(match?.source || ''),
    externalId: match?.externalId == null ? null : String(match.externalId),
    kickoffAt: match?.kickoffAt || null,
    homeTeam: String(match?.homeTeam || ''),
    awayTeam: String(match?.awayTeam || ''),
    homeLogoUrl: match?.homeLogoUrl || null,
    awayLogoUrl: match?.awayLogoUrl || null,
    venue: match?.venue || null,
    city: match?.city || null,
    competition: match?.competition || null,
    round: match?.round || null,
    status: normalizeStatus(mine?.status),
    wishes: wishNamesFromRow(mine, idToName),
  };
}

module.exports = {
  flattenSkills,
  normalizeEmail,
  normalizeStatus,
  normalizeWishes,
  wishNamesFromRow,
  pickMine,
  jwtPayload,
  jwtStillValid,
  matchPutId,
  toPublicMatch,
};
