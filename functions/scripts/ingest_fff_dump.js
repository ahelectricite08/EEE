/**
 * Pousse un dump FFF (classement + matchs) vers Firestore.
 * Sert quand le WAF bloque api-dofa depuis Node.
 *
 *   node scripts/ingest_fff_dump.js path/to/dump.json
 *
 * dump.json = { r1matches, r2matches, r1rank, r2rank }
 * ou le JSON CDP { result: { value: { ... } } }.
 */
const fs = require('fs');
const path = require('path');
const {
  pickLatestCompleteClassementJournee,
  isSedanCssaMatch,
  fffMatchJournee,
  fffSideTeamName,
} = require('../lib/fff_sync_helpers');

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
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const COMMIT = `${FS.replace('/documents', '')}/documents:commit`;

function val(f, k) {
  const x = f?.[k];
  if (!x) return undefined;
  if (x.stringValue != null) return x.stringValue;
  if (x.integerValue != null) return Number(x.integerValue);
  if (x.doubleValue != null) return x.doubleValue;
  if (x.booleanValue != null) return x.booleanValue;
  if (x.timestampValue != null) return x.timestampValue;
  return undefined;
}

function intField(n) {
  return { integerValue: String(Number(n) || 0) };
}

function tsField(date) {
  return { timestampValue: date.toISOString() };
}

function parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw, 10);
  return Number.isNaN(n) ? null : n;
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
  const year = probe.getUTCFullYear();
  const marchLast = new Date(Date.UTC(year, 2, 31));
  while (marchLast.getUTCDay() !== 0) marchLast.setUTCDate(marchLast.getUTCDate() - 1);
  marchLast.setUTCHours(1, 0, 0, 0);
  const octLast = new Date(Date.UTC(year, 9, 31));
  while (octLast.getUTCDay() !== 0) octLast.setUTCDate(octLast.getUTCDate() - 1);
  octLast.setUTCHours(1, 0, 0, 0);
  const offset = probe >= marchLast && probe < octLast ? 2 : 1;
  return new Date(Date.UTC(y, mo, day, h - offset, min, 0, 0));
}

function logoOf(side) {
  const raw = side?.club?.logo || side?.logo;
  if (!raw) return null;
  if (typeof raw === 'string') return raw.trim() || null;
  return null;
}

function loadDump(file) {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (raw.r1matches || raw.r1rank) return raw;
  if (raw.result && raw.result.value) return raw.result.value;
  throw new Error('dump JSON inattendu');
}

async function listAll(auth, collection) {
  const docs = [];
  let pageToken = '';
  do {
    const qs = new URLSearchParams({ pageSize: '100' });
    if (pageToken) qs.set('pageToken', pageToken);
    const res = await fetch(`${FS}/${collection}?${qs}`, { headers: auth });
    const body = await res.json();
    if (!res.ok) throw new Error(`${collection} ${res.status} ${JSON.stringify(body).slice(0, 200)}`);
    docs.push(...(body.documents || []));
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return docs;
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

async function pushRanking(auth, { col, members, season, existing }) {
  const picked = pickLatestCompleteClassementJournee(members);
  if (!picked.complete) {
    console.log(`${col}: classement incomplet J${picked.lastJournee} n=${picked.members.length}`);
    return picked;
  }
  const logoByTeam = new Map();
  for (const d of existing) {
    const f = d.fields || {};
    const t = String(val(f, 'team') || '').trim().toUpperCase();
    const logo = val(f, 'logo');
    if (t && logo) logoByTeam.set(t, logo);
  }
  const writes = [];
  const keep = new Set();
  const now = new Date();
  for (const entry of picked.members) {
    const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const docId = `pos_${entry.rank}`;
    keep.add(docId);
    const logo =
      (typeof entry.equipe?.club?.logo === 'string' ? entry.equipe.club.logo : null) ||
      (typeof entry.equipe?.logo === 'string' ? entry.equipe.logo : null) ||
      logoByTeam.get(String(teamName).trim().toUpperCase()) ||
      null;
    const fields = {
      season: { stringValue: season },
      position: intField(entry.rank),
      team: { stringValue: String(teamName) },
      mj: intField(entry.total_games_count),
      v: intField(entry.won_games_count),
      n: intField(entry.draw_games_count),
      d: intField(entry.lost_games_count),
      bf: intField(entry.goals_for_count),
      bc: intField(entry.goals_against_count),
      pts: intField(entry.point_count),
      forme: { stringValue: String(entry.forme || '') },
      journee: intField(entry.cj_no ?? picked.lastJournee),
      source: { stringValue: 'fff' },
      updatedAt: tsField(now),
    };
    if (logo) fields.logo = { stringValue: String(logo) };
    writes.push({
      update: {
        name: `projects/${PROJECT}/databases/(default)/documents/${col}/${docId}`,
        fields,
      },
      updateMask: { fieldPaths: Object.keys(fields) },
    });
  }
  for (const d of existing) {
    const id = String(d.name).split('/').pop();
    if (!keep.has(id)) writes.push({ delete: d.name });
  }
  console.log(`${col}: J${picked.lastJournee} ${picked.members.length} équipes, ${writes.length} écriture(s)`);
  for (const e of [...picked.members].sort((a, b) => (a.rank || 0) - (b.rank || 0))) {
    console.log(
      `  ${String(e.rank).padStart(2)} ${String(e.point_count).padStart(3)}pts MJ${e.total_games_count} ${e.equipe?.short_name || ''}`,
    );
  }
  await commitWrites(auth, writes);
  return picked;
}

async function pushMatches(auth, {
  collection,
  prefix,
  members,
  competition,
  season,
  sedanOnly,
  existing,
}) {
  const byId = new Map();
  const byFff = new Map();
  for (const d of existing) {
    const id = String(d.name).split('/').pop();
    byId.set(id, d);
    const fffId = String(val(d.fields, 'fffId') || '');
    if (fffId) byFff.set(fffId, d);
  }
  const writes = [];
  let created = 0;
  let updated = 0;
  let skipped = 0;
  const now = new Date();
  for (const m of members) {
    const fffId = String(m.ma_no || '');
    const team1 = fffSideTeamName(m.home);
    const team2 = fffSideTeamName(m.away);
    if (!fffId || !team1 || !team2 || !m.date) {
      skipped += 1;
      continue;
    }
    if (sedanOnly && !isSedanCssaMatch(team1, team2)) {
      skipped += 1;
      continue;
    }
    const s1 = parseScore(m.home_score);
    const s2 = parseScore(m.away_score);
    const date = parseMatchDate(m.date, m.time);
    const finished = s1 !== null && s2 !== null;
    const status = finished || date.getTime() < Date.now() ? 'finished' : 'upcoming';
    const journee = fffMatchJournee(m);
    const docId = `${prefix}${fffId}`;
    const existingDoc = byId.get(docId) || byFff.get(fffId) || null;
    if (existingDoc && val(existingDoc.fields, 'manual') === true) {
      skipped += 1;
      continue;
    }
    const name = existingDoc
      ? existingDoc.name
      : `projects/${PROJECT}/databases/(default)/documents/${collection}/${docId}`;
    const logo1 = logoOf(m.home);
    const logo2 = logoOf(m.away);
    if (!existingDoc) {
      const fields = {
        team1: { stringValue: team1 },
        team2: { stringValue: team2 },
        date: tsField(date),
        competition: { stringValue: competition },
        status: { stringValue: status },
        fffId: { stringValue: fffId },
        fffSeason: { stringValue: season },
        updatedAt: tsField(now),
      };
      if (s1 !== null) fields.score1 = { integerValue: String(s1) };
      if (s2 !== null) fields.score2 = { integerValue: String(s2) };
      if (logo1) fields.logo1 = { stringValue: logo1 };
      if (logo2) fields.logo2 = { stringValue: logo2 };
      if (journee > 0) fields.journee = intField(journee);
      writes.push({ update: { name, fields } });
      created += 1;
      continue;
    }
    const f = existingDoc.fields || {};
    const cur1 = val(f, 'score1');
    const cur2 = val(f, 'score2');
    const sameScores =
      (s1 === null || Number(cur1) === s1) &&
      (s2 === null || Number(cur2) === s2);
    const sameStatus = val(f, 'status') === status;
    const sameJ = journee <= 0 || Number(val(f, 'journee') || 0) === journee;
    const sameComp = val(f, 'competition') === competition;
    if (sameScores && sameStatus && sameJ && sameComp) {
      skipped += 1;
      continue;
    }
    const fields = {
      status: { stringValue: status },
      updatedAt: tsField(now),
    };
    const mask = ['status', 'updatedAt'];
    if (s1 !== null) {
      fields.score1 = { integerValue: String(s1) };
      mask.push('score1');
    }
    if (s2 !== null) {
      fields.score2 = { integerValue: String(s2) };
      mask.push('score2');
    }
    if (journee > 0) {
      fields.journee = intField(journee);
      mask.push('journee');
    }
    if (!sameComp) {
      fields.competition = { stringValue: competition };
      mask.push('competition');
    }
    if (logo1 && !val(f, 'logo1')) {
      fields.logo1 = { stringValue: logo1 };
      mask.push('logo1');
    }
    if (logo2 && !val(f, 'logo2')) {
      fields.logo2 = { stringValue: logo2 };
      mask.push('logo2');
    }
    writes.push({ update: { name, fields }, updateMask: { fieldPaths: mask } });
    updated += 1;
  }
  console.log(
    `${collection}: ${members.length} FFF → ${writes.length} écrit(s) (créés ${created}, maj ${updated}, skip ${skipped})`,
  );
  await commitWrites(auth, writes);
}

(async () => {
  const dumpFile = process.argv[2];
  if (!dumpFile) throw new Error('usage: node scripts/ingest_fff_dump.js dump.json');
  const dump = loadDump(dumpFile);
  const account = getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error('firebase login requis');
  const tok = await getAccessToken(account.tokens.refresh_token, [CLOUD_PLATFORM]);
  const auth = { Authorization: `Bearer ${tok.access_token}` };

  const cfgRes = await fetch(`${FS}/app_config/fff_season`, { headers: auth });
  const cfgDoc = await cfgRes.json();
  const season = val(cfgDoc.fields, 'seasonLabel') || '2026-2027';
  console.log('saison', season);

  const ranking = await listAll(auth, 'ranking');
  console.log('\n=== Firestore ranking avant ===');
  for (const d of ranking
    .map((doc) => ({
      pos: val(doc.fields, 'position'),
      pts: val(doc.fields, 'pts'),
      mj: val(doc.fields, 'mj'),
      j: val(doc.fields, 'journee'),
      team: val(doc.fields, 'team'),
    }))
    .sort((a, b) => (a.pos || 0) - (b.pos || 0))) {
    console.log(`  ${String(d.pos).padStart(2)} ${String(d.pts).padStart(3)}pts MJ${d.mj} J${d.j} ${d.team}`);
  }

  const r1Picked = await pushRanking(auth, {
    col: 'ranking',
    members: dump.r1rank || [],
    season,
    existing: ranking,
  });
  const rankingR2 = await listAll(auth, 'ranking_r2');
  await pushRanking(auth, {
    col: 'ranking_r2',
    members: dump.r2rank || [],
    season,
    existing: rankingR2,
  });

  if (r1Picked?.complete) {
    await commitWrites(auth, [{
      update: {
        name: `projects/${PROJECT}/databases/(default)/documents/competition/meta`,
        fields: {
          journee: intField(r1Picked.lastJournee),
          rankingTeamCount: intField(r1Picked.members.length),
          rankingSource: { stringValue: 'fff_classement_journees' },
          fffSyncedAt: tsField(new Date()),
        },
      },
      updateMask: { fieldPaths: ['journee', 'rankingTeamCount', 'rankingSource', 'fffSyncedAt'] },
    }]);
  }

  const matches = await listAll(auth, 'matches');
  await pushMatches(auth, {
    collection: 'matches',
    prefix: 'fff_',
    members: dump.r1matches || [],
    competition: 'Régional 1',
    season,
    sedanOnly: false,
    existing: matches,
  });
  const matchesR2 = await listAll(auth, 'matches_r2');
  await pushMatches(auth, {
    collection: 'matches_r2',
    prefix: 'fff_r2_',
    members: dump.r2matches || [],
    competition: 'Régional 2',
    season,
    sedanOnly: true,
    existing: matchesR2,
  });
  console.log('\nDONE');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
