'use strict';

/**
 * Helpers sync FFF (poule entière — jamais un filtre Sedan/CSSA).
 * Classement + calendrier R1/R2 doivent rester la poule, pas le club.
 */

const FFF_POULE_MIN_TEAMS = 8;
const FFF_MATCH_PAGE_SIZE = 100;

function fffHydraNext(next, host) {
  if (next == null) return null;
  const s = String(next).trim();
  if (!s) return null;
  if (/^https?:\/\//i.test(s)) return s;
  const base = String(host || '').replace(/\/$/, '');
  if (!base) return s.startsWith('/') ? s : `/${s}`;
  return `${base}${s.startsWith('/') ? s : `/${s}`}`;
}

function fffSideTeamName(side) {
  if (!side || typeof side !== 'object') return '';
  const nested = side.equipe && typeof side.equipe === 'object' ? side.equipe : {};
  return String(
    side.short_name ||
      side.nom ||
      nested.short_name ||
      nested.nom ||
      '',
  ).trim();
}

/**
 * Dernière journée FFF qui a assez d’équipes (page Hydra partielle
 * sinon → 1 ligne « Sedan » et le reste du classement disparaît).
 */
function pickLatestCompleteClassementJournee(all, { minTeams = FFF_POULE_MIN_TEAMS } = {}) {
  const list = Array.isArray(all) ? all : [];
  const byJ = new Map();
  let lastJournee = 0;
  for (const entry of list) {
    const j = Number(entry?.cj_no) || 0;
    if (j > lastJournee) lastJournee = j;
    if (!byJ.has(j)) byJ.set(j, []);
    byJ.get(j).push(entry);
  }
  if (!list.length) return { members: [], lastJournee: 0, complete: false };

  const tryJ = (j) => {
    const members = byJ.get(j) || [];
    return members.length >= minTeams
      ? { members, lastJournee: j, complete: true }
      : null;
  };

  if (lastJournee > 0) {
    const latest = tryJ(lastJournee);
    if (latest) return latest;
    const js = [...byJ.keys()].filter((j) => j > 0).sort((a, b) => b - a);
    for (const j of js) {
      const picked = tryJ(j);
      if (picked) return picked;
    }
  }

  if (list.length >= minTeams) {
    return { members: list, lastJournee, complete: true };
  }
  return {
    members: lastJournee > 0 ? (byJ.get(lastJournee) || list) : list,
    lastJournee,
    complete: false,
  };
}

function rankingWriteShouldDeleteLeftovers(memberCount, { minTeams = FFF_POULE_MIN_TEAMS } = {}) {
  return Number(memberCount) >= minTeams;
}

module.exports = {
  FFF_POULE_MIN_TEAMS,
  FFF_MATCH_PAGE_SIZE,
  fffHydraNext,
  fffSideTeamName,
  pickLatestCompleteClassementJournee,
  rankingWriteShouldDeleteLeftovers,
};
