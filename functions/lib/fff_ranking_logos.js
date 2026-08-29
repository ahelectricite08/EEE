/**
 * Écussons classement FFF.
 * `classement_journees` n’embarque que `equipe.club.cl_no` — pas `logo`.
 * Les matchs (`home.club.logo` / `away.club.logo`) et `/api/clubs/{cl_no}` oui.
 */

function fffLogoString(value) {
  if (value == null) return null;
  if (typeof value === 'string') {
    const s = value.trim();
    return /^https?:\/\//i.test(s) ? s : null;
  }
  if (typeof value === 'object') {
    return (
      fffLogoString(value.url) ||
      fffLogoString(value.contentUrl) ||
      fffLogoString(value.logo)
    );
  }
  return null;
}

function fffClubNo(equipe) {
  const club = equipe?.club;
  if (club == null) return 0;
  if (typeof club === 'number') return Number(club) || 0;
  if (typeof club === 'string') {
    const m = club.match(/clubs\/(\d+)/i);
    return m ? Number(m[1]) || 0 : 0;
  }
  return Number(club.cl_no) || 0;
}

function fffTeamLogoFromEquipe(equipe) {
  if (!equipe) return null;
  return fffLogoString(equipe.club?.logo) || fffLogoString(equipe.logo);
}

function emptyLogoMaps() {
  return { byClNo: new Map(), byTeam: new Map() };
}

function mergeLogoMaps(target, extra) {
  if (!extra) return target;
  for (const [k, v] of extra.byClNo || []) {
    if (k && v) target.byClNo.set(k, v);
  }
  for (const [k, v] of extra.byTeam || []) {
    if (k && v) target.byTeam.set(k, v);
  }
  return target;
}

function _putEquipeLogo(maps, equipe, logoOverride) {
  const logo = logoOverride || fffTeamLogoFromEquipe(equipe);
  if (!logo) return;
  const clNo = fffClubNo(equipe);
  if (clNo) maps.byClNo.set(clNo, logo);
  const name = (equipe?.short_name ?? equipe?.nom ?? '').trim().toUpperCase();
  if (name) maps.byTeam.set(name, logo);
}

function collectLogosFromClassementMembers(members) {
  const maps = emptyLogoMaps();
  for (const entry of members || []) {
    _putEquipeLogo(maps, entry?.equipe);
  }
  return maps;
}

function collectLogosFromMatchMembers(members) {
  const maps = emptyLogoMaps();
  for (const match of members || []) {
    _putEquipeLogo(maps, match?.home);
    _putEquipeLogo(maps, match?.away);
  }
  return maps;
}

function rankingLogoForEntry(entry, maps) {
  const equipe = entry?.equipe;
  const direct = fffTeamLogoFromEquipe(equipe);
  if (direct) return direct;
  const byClNo = maps?.byClNo;
  const byTeam = maps?.byTeam;
  const clNo = fffClubNo(equipe);
  if (clNo && byClNo?.get(clNo)) return byClNo.get(clNo);
  const name = (equipe?.short_name ?? equipe?.nom ?? '').trim().toUpperCase();
  if (name && byTeam?.get(name)) return byTeam.get(name);
  if (name && byTeam) {
    for (const [key, url] of byTeam) {
      if (!key || !url) continue;
      if (name.includes(key) || key.includes(name)) return url;
    }
  }
  return null;
}

function membersMissingLogo(members, maps) {
  return (members || []).filter((entry) => !rankingLogoForEntry(entry, maps));
}

module.exports = {
  fffLogoString,
  fffClubNo,
  fffTeamLogoFromEquipe,
  emptyLogoMaps,
  mergeLogoMaps,
  collectLogosFromClassementMembers,
  collectLogosFromMatchMembers,
  rankingLogoForEntry,
  membersMissingLogo,
};
