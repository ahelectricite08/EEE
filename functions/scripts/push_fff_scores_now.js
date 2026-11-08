/**
 * Pousse calendrier + scores FFF (depuis cette machine, hors WAF GCP)
 * vers Firestore. Crée les fiches manquantes. Déclenche calculatePronoPoints
 * dès qu’un score est écrit.
 *
 *   node scripts/push_fff_scores_now.js
 */
const path = require('path');
const { fffSideTeamName } = require('../lib/fff_sync_helpers');

const toolsRoot = path.join(
  process.env.APPDATA,
  'npm',
  'node_modules',
  'firebase-tools',
  'lib',
);
const { getGlobalDefaultAccount, getAccessToken } = require(path.join(toolsRoot, 'auth.js'));
const { CLOUD_PLATFORM } = require(path.join(toolsRoot, 'scopes.js'));

const PROJECT = 'drapeau-vert-app';
const COMMIT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:commit`;
const MATCH_BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/matches`;

const FFF_HEADERS = {
  Accept: 'application/ld+json, application/json',
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  Origin: 'https://epreuves.fff.fr',
  Referer: 'https://epreuves.fff.fr/',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
};

function parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw, 10);
  return Number.isNaN(n) ? null : n;
}

function intVal(v) {
  if (v == null) return undefined;
  if (typeof v === 'number') return v;
  if (v.integerValue != null) return Number(v.integerValue);
  if (v.doubleValue != null) return v.doubleValue;
  if (v.stringValue != null) return Number(v.stringValue);
  return undefined;
}

function parseMatchDate(dateStr, timeStr) {
  const parts = String(dateStr ?? '').match(/(\d{4})-(\d{2})-(\d{2})/);
  if (!parts) return new Date(dateStr);
  const y = parseInt(parts[1], 10);
  const mo = parseInt(parts[2], 10) - 1;
  const day = parseInt(parts[3], 10);
  let h = 15;
  let min = 0;
  if (timeStr) {
    const tm = String(timeStr).match(/(\d+)H(\d+)/i);
    if (tm) {
      h = parseInt(tm[1], 10);
      min = parseInt(tm[2], 10);
    }
  }
  const probe = new Date(Date.UTC(y, mo, day, 12, 0, 0));
  const offset = parisOffsetHours(probe);
  return new Date(Date.UTC(y, mo, day, h - offset, min, 0, 0));
}

function parisOffsetHours(date) {
  const year = date.getUTCFullYear();
  const marchLast = new Date(Date.UTC(year, 2, 31));
  while (marchLast.getUTCDay() !== 0) marchLast.setUTCDate(marchLast.getUTCDate() - 1);
  marchLast.setUTCHours(1, 0, 0, 0);
  const octLast = new Date(Date.UTC(year, 9, 31));
  while (octLast.getUTCDay() !== 0) octLast.setUTCDate(octLast.getUTCDate() - 1);
  octLast.setUTCHours(1, 0, 0, 0);
  return date >= marchLast && date < octLast ? 2 : 1;
}

function logoOf(side) {
  const raw = side?.club?.logo || side?.logo;
  if (!raw) return null;
  if (typeof raw === 'string') return raw.trim() || null;
  if (typeof raw === 'object') {
    return String(raw.url || raw['@id'] || '').trim() || null;
  }
  return null;
}

async function fetchAllMatches(cp, ph, gp) {
  const HOST = 'https://api-dofa.fff.fr';
  let url = `${HOST}/api/compets/${cp}/phases/${ph}/poules/${gp}/matchs?itemsPerPage=30`;
  const out = [];
  while (url) {
    const res = await fetch(url, { headers: FFF_HEADERS });
    const data = await res.json();
    if (!res.ok) throw new Error(`FFF HTTP ${res.status} ${url}`);
    out.push(...(data['hydra:member'] ?? []));
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? (String(next).startsWith('http') ? next : `${HOST}${next}`) : null;
  }
  return out;
}

function tsField(date) {
  return { timestampValue: date.toISOString() };
}

async function commitWrites(auth, writes) {
  for (let i = 0; i < writes.length; i += 20) {
    const chunk = writes.slice(i, i + 20);
    const res = await fetch(COMMIT, {
      method: 'POST',
      headers: { ...auth, 'Content-Type': 'application/json' },
      body: JSON.stringify({ writes: chunk }),
    });
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body).slice(0, 800));
  }
}

(async () => {
  const account = getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error('firebase login requis');
  const tok = await getAccessToken(account.tokens.refresh_token, [CLOUD_PLATFORM]);
  const auth = { Authorization: `Bearer ${tok.access_token}` };

  const members = await fetchAllMatches(449966, 1, 1);
  const rows = [];
  for (const m of members) {
    const fffId = String(m.ma_no || '');
    const team1 = fffSideTeamName(m.home);
    const team2 = fffSideTeamName(m.away);
    if (!fffId || !team1 || !team2 || !m.date) continue;
    const s1 = parseScore(m.home_score);
    const s2 = parseScore(m.away_score);
    const date = parseMatchDate(m.date, m.time);
    const finished = s1 !== null && s2 !== null;
    rows.push({
      id: `fff_${fffId}`,
      fffId,
      team1,
      team2,
      s1,
      s2,
      date,
      logo1: logoOf(m.home),
      logo2: logoOf(m.away),
      status: finished || date.getTime() < Date.now() ? 'finished' : 'upcoming',
    });
  }
  const withScores = rows.filter((r) => r.s1 !== null && r.s2 !== null);
  console.log(`FFF R1 : ${members.length} matchs, ${rows.length} valides, ${withScores.length} avec score`);

  const writes = [];
  let created = 0;
  let updated = 0;
  let skipped = 0;
  for (const row of rows) {
    const res = await fetch(`${MATCH_BASE}/${row.id}`, { headers: auth });
    const name = `projects/${PROJECT}/databases/(default)/documents/matches/${row.id}`;
    if (res.status === 404) {
      const fields = {
        team1: { stringValue: row.team1 },
        team2: { stringValue: row.team2 },
        date: tsField(row.date),
        competition: { stringValue: 'Régional 1' },
        status: { stringValue: row.status },
        fffId: { stringValue: row.fffId },
        fffSeason: { stringValue: '2026-2027' },
        updatedAt: tsField(new Date()),
      };
      if (row.s1 !== null) fields.score1 = { integerValue: String(row.s1) };
      if (row.s2 !== null) fields.score2 = { integerValue: String(row.s2) };
      if (row.logo1) fields.logo1 = { stringValue: row.logo1 };
      if (row.logo2) fields.logo2 = { stringValue: row.logo2 };
      writes.push({ update: { name, fields } });
      created += 1;
      console.log(`+ ${row.id}  ${row.team1} ${row.s1 ?? '-'}-${row.s2 ?? '-'} ${row.team2}  ${row.status}`);
      continue;
    }
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body).slice(0, 300));
    const f = body.fields || {};
    if (f.manual?.booleanValue === true) {
      skipped += 1;
      continue;
    }
    const cur1 = intVal(f.score1);
    const cur2 = intVal(f.score2);
    const status = f.status?.stringValue;
    const sameScores =
      (row.s1 === null || cur1 === row.s1) &&
      (row.s2 === null || cur2 === row.s2);
    const sameStatus = status === row.status;
    if (sameScores && sameStatus) {
      skipped += 1;
      continue;
    }
    const fields = {
      status: { stringValue: row.status },
      updatedAt: tsField(new Date()),
    };
    const mask = ['status', 'updatedAt'];
    if (row.s1 !== null) {
      fields.score1 = { integerValue: String(row.s1) };
      mask.push('score1');
    }
    if (row.s2 !== null) {
      fields.score2 = { integerValue: String(row.s2) };
      mask.push('score2');
    }
    writes.push({
      update: { name, fields },
      updateMask: { fieldPaths: mask },
    });
    updated += 1;
    console.log(`→ ${row.id}  ${cur1}-${cur2} ${status}  => ${row.s1}-${row.s2}  ${row.team1}/${row.team2}`);
  }

  console.log(`Écritures : ${writes.length} (créés ${created}, scorés ${updated}, inchangés ${skipped})`);
  await commitWrites(auth, writes);
  console.log('DONE');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
