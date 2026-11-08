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

/** CSSA R1 poule A 2026-2027 — mêmes URLs que epreuves.fff.fr / DOFA. */
function fffPouleCalendrierUrl(base, cp, ph, gp) {
  return `${String(base).replace(/\/$/, '')}/compets/${cp}/phases/${ph}/poules/${gp}/calendrier?itemsPerPage=50`;
}

function fffPouleClassementUrl(base, cp, ph, gp, { itemsPerPage = 200 } = {}) {
  return `${String(base).replace(/\/$/, '')}/compets/${cp}/phases/${ph}/poules/${gp}/classement_journees?itemsPerPage=${itemsPerPage}`;
}

function fffPouleMatchsUrl(base, cp, ph, gp, { itemsPerPage = FFF_MATCH_PAGE_SIZE } = {}) {
  // Pas de ?journee= : l’API l’ignore et paginé depuis J1. Toute la poule
  // est dans /matchs (≈30/page). Calendrier = prochaine journée seulement.
  return `${String(base).replace(/\/$/, '')}/compets/${cp}/phases/${ph}/poules/${gp}/matchs?itemsPerPage=${itemsPerPage}`;
}

function fffHydraLastPage(data) {
  const last = data && data['hydra:view'] && data['hydra:view']['hydra:last'];
  if (!last) return 0;
  const m = String(last).match(/[?&]page=(\d+)/);
  return m ? Number(m[1]) : 0;
}

function fffUrlWithPage(url, page) {
  try {
    const u = new URL(url);
    u.searchParams.set('page', String(page));
    return u.toString();
  } catch (_) {
    const bare = String(url || '');
    if (/[?&]page=/.test(bare)) {
      return bare.replace(/([?&]page=)\d+/, `$1${page}`);
    }
    return `${bare}${bare.includes('?') ? '&' : '?'}page=${page}`;
  }
}

function fffPublishedScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = Number.parseInt(String(raw), 10);
  return Number.isFinite(n) ? n : null;
}

function fffMatchHasPublishedScore(match) {
  if (!match || typeof match !== 'object') return false;
  return fffPublishedScore(match.home_score) != null
    && fffPublishedScore(match.away_score) != null;
}

/** Scores d’abord, puis date récente — pour ne pas mourir sur J1 si le sync coupe. */
function prioritizeFffMatchesForSync(a, b) {
  const sa = fffMatchHasPublishedScore(a) ? 1 : 0;
  const sb = fffMatchHasPublishedScore(b) ? 1 : 0;
  if (sa !== sb) return sb - sa;
  const da = Date.parse(a && a.date ? a.date : '') || 0;
  const db = Date.parse(b && b.date ? b.date : '') || 0;
  return db - da;
}

/** `fffClubNo` admin = n° affiliation (500266). L’API DOFA veut `cl_no` (380). */
const CSSA_AFFILIATION_NO = 500266;
const CSSA_DOFA_CLUB_NO = 380;

function fffClubMatchsUrl(base, clNo, { itemsPerPage = FFF_MATCH_PAGE_SIZE } = {}) {
  return `${String(base).replace(/\/$/, '')}/clubs/${clNo}/matchs?itemsPerPage=${itemsPerPage}`;
}

function resolveCssaDofaClubNo(configured) {
  const n = Number(configured);
  if (!Number.isFinite(n) || n <= 0 || n === CSSA_AFFILIATION_NO) {
    return CSSA_DOFA_CLUB_NO;
  }
  return Math.floor(n);
}

function fffCompetitionType(match) {
  const t = match && match.competition && match.competition.type;
  return String(t || '').trim().toUpperCase();
}

function isFffCupOrFriendly(match) {
  const t = fffCompetitionType(match);
  return t === 'CP' || t === 'AC';
}

function fffSideClubNo(side) {
  if (!side || typeof side !== 'object') return 0;
  const n = Number(side.club && side.club.cl_no);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

/** 1ère séniors CSSA — pas R2, pas jeunes, pas Torcy Sedan Olympique. */
function isSeniorFirstTeamClubMatch(match, clNo) {
  const want = Number(clNo);
  if (!Number.isFinite(want) || want <= 0) return false;
  for (const key of ['home', 'away']) {
    const side = match && match[key];
    if (!side || typeof side !== 'object') continue;
    if (fffSideClubNo(side) !== want) continue;
    const cat = String(side.category_code || '').toUpperCase();
    const number = Number(side.number);
    if (cat === 'SEM' && number === 1) return true;
  }
  return false;
}

function fffCompetitionLabel(name, type) {
  const n = String(name || '').trim().toUpperCase();
  const t = String(type || '').trim().toUpperCase();
  if (t === 'AC' || n.includes('AMICAL')) return 'Match Amical';
  if (n.includes('COUPE DE FRANCE')) return 'Coupe de France';
  if (n.includes('COUPE DU GRAND EST') || n.includes('COUPE GRAND EST')) {
    return 'Coupe Grand Est';
  }
  if (n.includes('COUPE DES ARDENNES')) return 'Coupe des Ardennes';
  const raw = String(name || '').trim();
  if (!raw) return t === 'CP' ? 'Coupe' : 'Match Amical';
  return raw
    .split(/\s+/)
    .map((w) => (w ? w[0].toUpperCase() + w.slice(1).toLowerCase() : w))
    .join(' ');
}

function fffCompetitionDisplayName(match) {
  const comp = match && match.competition && typeof match.competition === 'object'
    ? match.competition
    : {};
  return fffCompetitionLabel(comp.name, comp.type);
}

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

  // Dump sans cj_no (une seule page poule). Jamais un mélange de journées.
  const unlabeled = byJ.get(0) || [];
  if (unlabeled.length >= minTeams && byJ.size <= 1) {
    return { members: unlabeled, lastJournee, complete: true };
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

/** Lignes Firestore `ranking` / `ranking_r2` : skip write si identiques. */
function rankingRowEquals(prev, row) {
  if (!prev || !row) return false;
  return (
    (prev.position ?? 0) === (row.position ?? 0) &&
    (prev.team ?? '') === (row.team ?? '') &&
    (prev.logo ?? null) === (row.logo ?? null) &&
    (prev.mj ?? 0) === (row.mj ?? 0) &&
    (prev.v ?? 0) === (row.v ?? 0) &&
    (prev.n ?? 0) === (row.n ?? 0) &&
    (prev.d ?? 0) === (row.d ?? 0) &&
    (prev.bf ?? 0) === (row.bf ?? 0) &&
    (prev.bc ?? 0) === (row.bc ?? 0) &&
    (prev.pts ?? 0) === (row.pts ?? 0) &&
    (prev.forme ?? '') === (row.forme ?? '') &&
    (prev.season ?? '') === (row.season ?? '') &&
    (prev.journee ?? 0) === (row.journee ?? 0)
  );
}

function _clipStr(raw, max) {
  const s = String(raw ?? '').trim();
  if (!s) return '';
  return s.length <= max ? s : s.slice(0, max);
}

function _clipInt(raw, { min = 0, max = 200 } = {}) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return 0;
  const i = Math.floor(n);
  if (i < min) return min;
  if (i > max) return max;
  return i;
}

/** Payload téléphone → ligne FFF minimale. Pas de champs libres vers Firestore. */
function sanitizeClassementMember(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const rank = Number(raw.rank);
  if (!Number.isFinite(rank) || rank < 1 || rank > 24) return null;
  const equipe = raw.equipe && typeof raw.equipe === 'object' ? raw.equipe : {};
  const club = equipe.club && typeof equipe.club === 'object' ? equipe.club : {};
  const name = _clipStr(equipe.short_name || equipe.nom, 80);
  if (!name) return null;
  const logo = _clipStr(equipe.logo || club.logo, 500);
  const clubLogo = _clipStr(club.logo, 500);
  const clNo = _clipInt(club.cl_no || equipe.cl_no, { min: 0, max: 9999999 });
  return {
    rank: Math.floor(rank),
    cj_no: _clipInt(raw.cj_no, { min: 0, max: 50 }),
    total_games_count: _clipInt(raw.total_games_count),
    won_games_count: _clipInt(raw.won_games_count),
    draw_games_count: _clipInt(raw.draw_games_count),
    lost_games_count: _clipInt(raw.lost_games_count),
    goals_for_count: _clipInt(raw.goals_for_count, { max: 500 }),
    goals_against_count: _clipInt(raw.goals_against_count, { max: 500 }),
    point_count: _clipInt(raw.point_count, { max: 200 }),
    forme: _clipStr(raw.forme, 16),
    equipe: {
      short_name: name,
      nom: _clipStr(equipe.nom || name, 80),
      logo,
      club: {
        logo: clubLogo || logo,
        cl_no: clNo || undefined,
      },
    },
  };
}

function sanitizeClassementMembers(rawList) {
  const ranks = new Set();
  const out = [];
  for (const raw of Array.isArray(rawList) ? rawList : []) {
    const row = sanitizeClassementMember(raw);
    if (!row || ranks.has(row.rank)) continue;
    ranks.add(row.rank);
    out.push(row);
  }
  return out;
}

/** Empêche d’écraser la poule par un tableau d’équipes hors championnat. */
function rankingTeamOverlapOk(existingNames, incomingNames) {
  const existing = [...(existingNames || [])]
    .map((n) => String(n || '').trim().toUpperCase())
    .filter(Boolean);
  if (existing.length < 8) return true;
  const incomingList = [...(incomingNames || [])]
    .map((n) => String(n || '').trim().toUpperCase())
    .filter(Boolean);
  const incoming = new Set(incomingList);
  const existingSet = new Set(existing);
  let hitIncoming = 0;
  for (const t of incoming) {
    if (existingSet.has(t)) hitIncoming += 1;
  }
  // Tableau FFF (8–16) qui recouvre le live → OK même si l’actuel
  // a été gonflé (anciennes saisons, 53 pts, etc.).
  if (incoming.size >= 8 && incoming.size <= 16 && hitIncoming >= 6) {
    return true;
  }
  let hit = 0;
  for (const t of existing) {
    if (incoming.has(t)) hit += 1;
  }
  return hit >= Math.max(6, Math.floor(existing.length * 0.5));
}

/** 403 = WAF, 404 = ids. Ne pas dire « ids à vérifier » sur un 403. */
function fffRankingHttpHint(status) {
  const s = Number(status);
  if (s === 403) {
    return 'WAF FFF (pas un ID faux) — synchro téléphone staff ou script local';
  }
  if (s === 404) {
    return 'ids compétition / phase / poule à vérifier';
  }
  return `HTTP ${status}`;
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
  CSSA_AFFILIATION_NO,
  CSSA_DOFA_CLUB_NO,
  fffPouleCalendrierUrl,
  fffPouleClassementUrl,
  fffPouleMatchsUrl,
  fffHydraLastPage,
  fffUrlWithPage,
  fffMatchHasPublishedScore,
  prioritizeFffMatchesForSync,
  fffClubMatchsUrl,
  resolveCssaDofaClubNo,
  fffCompetitionType,
  isFffCupOrFriendly,
  isSeniorFirstTeamClubMatch,
  fffCompetitionLabel,
  fffCompetitionDisplayName,
  fffHydraNext,
  fffSideTeamName,
  isSedanCssaMatch,
  pickLatestCompleteClassementJournee,
  rankingWriteShouldDeleteLeftovers,
  rankingRowEquals,
  sanitizeClassementMember,
  sanitizeClassementMembers,
  rankingTeamOverlapOk,
  fffRankingHttpHint,
  fffMatchJournee,
};
