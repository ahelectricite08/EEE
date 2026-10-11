'use strict';

/**
 * Helpers sync FFF.
 * Classement R1/R2 = poule entière. Calendrier R1 = poule (pronos).
 * Calendrier R2 = matchs Sedan/CSSA seulement.
 */

function isSedanCssaMatch(team1, team2) {
  const t1 = String(team1 || '').toUpperCase();
  const t2 = String(team2 || '').toUpperCase();
  return t1.includes('SEDAN') || t1.includes('CSSA') ||
         t2.includes('SEDAN') || t2.includes('CSSA');
}

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

/** Journée FFF d’un match (`poule_journee.number`). */
function fffMatchJournee(match) {
  const pj = match && match.poule_journee;
  if (pj && typeof pj === 'object') {
    const n = Number(pj.number ?? pj.name);
    if (Number.isFinite(n) && n > 0) return Math.floor(n);
  }
  const n = Number(match?.journee ?? match?.cj_no);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

module.exports = {
  FFF_POULE_MIN_TEAMS,
  FFF_MATCH_PAGE_SIZE,
  fffHydraNext,
  fffSideTeamName,
  isSedanCssaMatch,
  pickLatestCompleteClassementJournee,
  rankingWriteShouldDeleteLeftovers,
  fffMatchJournee,
};
