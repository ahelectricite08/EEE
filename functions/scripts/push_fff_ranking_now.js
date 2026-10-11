/**
 * Compare ranking Firestore vs FFF, puis pousse R1/R2 si besoin.
 *   node scripts/push_fff_ranking_now.js
 */
const path = require('path');

const toolsRoot = path.join(
  process.env.APPDATA,
  'npm',
  'node_modules',
  'firebase-tools',
  'lib',
);
const { getGlobalDefaultAccount, getAccessToken } = require(path.join(toolsRoot, 'auth.js'));
const { CLOUD_PLATFORM } = require(path.join(toolsRoot, 'scopes.js'));
const {
  pickLatestCompleteClassementJournee,
} = require('../lib/fff_sync_helpers');

const PROJECT = 'drapeau-vert-app';
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const COMMIT = `${FS.replace('/documents', '')}/documents:commit`;
const HOST = 'https://api-dofa.fff.fr';

const FFF_HEADERS = {
  Accept: 'application/ld+json, application/json',
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  Origin: 'https://epreuves.fff.fr',
  Referer: 'https://epreuves.fff.fr/',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
};

function val(f, k) {
  const x = f?.[k];
  if (!x) return undefined;
  if (x.stringValue != null) return x.stringValue;
  if (x.integerValue != null) return Number(x.integerValue);
  if (x.doubleValue != null) return x.doubleValue;
  if (x.timestampValue != null) return x.timestampValue;
  return undefined;
}

async function listAll(auth, collection) {
  const docs = [];
  let pageToken = '';
  do {
    const qs = new URLSearchParams({ pageSize: '100' });
    if (pageToken) qs.set('pageToken', pageToken);
    const res = await fetch(`${FS}/${collection}?${qs}`, { headers: auth });
    const body = await res.json();
    if (!res.ok) throw new Error(`${collection} ${res.status}`);
    docs.push(...(body.documents || []));
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return docs;
}

async function fetchAllClassement(cp, ph, gp) {
  let url = `${HOST}/api/compets/${cp}/phases/${ph}/poules/${gp}/classement_journees?itemsPerPage=100`;
  const all = [];
  while (url) {
    const res = await fetch(url, { headers: FFF_HEADERS });
    const data = await res.json();
    if (!res.ok) throw new Error(`FFF classement HTTP ${res.status} ${url}`);
    all.push(...(data['hydra:member'] ?? []));
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? (String(next).startsWith('http') ? next : `${HOST}${next}`) : null;
  }
  return all;
}

function intField(n) {
  return { integerValue: String(Number(n) || 0) };
}

(async () => {
  const account = getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error('firebase login requis');
  const tok = await getAccessToken(account.tokens.refresh_token, [CLOUD_PLATFORM]);
  const auth = { Authorization: `Bearer ${tok.access_token}` };

  const cfgRes = await fetch(`${FS}/app_config/fff_season`, { headers: auth });
  const cfgDoc = await cfgRes.json();
  const cfg = cfgDoc.fields || {};
  const season = val(cfg, 'seasonLabel') || '2026-2027';
  const r1 = Number(val(cfg, 'fffCompetitionId')) || 449966;
  const r2 = Number(val(cfg, 'fffR2CompetitionId')) || 449972;
  console.log('config', { season, r1, r2 });

  async function dumpFs(col) {
    const docs = await listAll(auth, col);
    const rows = docs.map((d) => {
      const f = d.fields || {};
      return {
        id: String(d.name).split('/').pop(),
        pos: val(f, 'position'),
        team: val(f, 'team'),
        mj: val(f, 'mj'),
        pts: val(f, 'pts'),
        journee: val(f, 'journee'),
        updatedAt: val(f, 'updatedAt'),
      };
    }).sort((a, b) => (a.pos || 0) - (b.pos || 0));
    const maxJ = rows.reduce((m, r) => Math.max(m, Number(r.journee) || 0), 0);
    const maxMj = rows.reduce((m, r) => Math.max(m, Number(r.mj) || 0), 0);
    console.log(`\n=== Firestore ${col} === ${rows.length} lignes J${maxJ} maxMJ=${maxMj}`);
    for (const r of rows) {
      console.log(`  ${String(r.pos).padStart(2)} ${String(r.pts).padStart(3)}pts MJ${r.mj} J${r.journee} ${r.team}`);
    }
    return { rows, existing: docs };
  }

  async function push(col, cp, ph, gp) {
    const all = await fetchAllClassement(cp, ph, gp);
    const picked = pickLatestCompleteClassementJournee(all);
    console.log(`\n=== FFF ${col} cp=${cp} === ${all.length} lignes, picked J${picked.lastJournee} n=${picked.members.length}`);
    for (const e of picked.members.sort((a, b) => (a.rank || 0) - (b.rank || 0))) {
      const name = e.equipe?.short_name ?? e.equipe?.nom ?? '';
      console.log(`  ${String(e.rank).padStart(2)} ${String(e.point_count).padStart(3)}pts MJ${e.total_games_count} J${e.cj_no} ${name}`);
    }

    const existing = await listAll(auth, col);
    const logoByTeam = new Map();
    for (const d of existing) {
      const f = d.fields || {};
      const t = String(val(f, 'team') || '').trim().toUpperCase();
      const logo = val(f, 'logo');
      if (t && logo) logoByTeam.set(t, logo);
    }

    const writes = [];
    const keep = new Set();
    for (const entry of picked.members) {
      const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
      const docId = `pos_${entry.rank}`;
      keep.add(docId);
      const logo =
        (typeof entry.equipe?.club?.logo === 'string' ? entry.equipe.club.logo : null) ||
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
      };
      if (logo) fields.logo = { stringValue: String(logo) };
      writes.push({
        update: {
          name: `projects/${PROJECT}/databases/(default)/documents/${col}/${docId}`,
          fields,
        },
        updateMask: {
          fieldPaths: Object.keys(fields),
        },
      });
    }
    for (const d of existing) {
      const id = String(d.name).split('/').pop();
      if (!keep.has(id)) {
        writes.push({ delete: d.name });
      }
    }
    console.log(`écritures ${col}: ${writes.length}`);
    for (let i = 0; i < writes.length; i += 20) {
      const chunk = writes.slice(i, i + 20);
      const res = await fetch(COMMIT, {
        method: 'POST',
        headers: { ...auth, 'Content-Type': 'application/json' },
        body: JSON.stringify({ writes: chunk }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(JSON.stringify(body).slice(0, 600));
    }
    return picked;
  }

  async function enrichMatchRanks(collection, members) {
    const rankByTeam = {};
    for (const entry of members) {
      const row = {
        rank: String(entry.rank ?? ''),
        form: String(entry.forme ?? '').toUpperCase(),
      };
      for (const key of [
        entry.equipe?.short_name,
        entry.equipe?.nom,
        entry.equipe?.abbreviation,
      ]) {
        const k = String(key || '').trim().toUpperCase();
        if (k) rankByTeam[k] = row;
      }
    }
    function findRank(teamName) {
      const t = String(teamName || '').trim().toUpperCase();
      if (!t) return null;
      if (rankByTeam[t]) return rankByTeam[t];
      for (const [key, row] of Object.entries(rankByTeam)) {
        if (t.includes(key) || key.includes(t)) return row;
      }
      return null;
    }
    const docs = await listAll(auth, collection);
    const now = Date.now();
    const past = now - 21 * 86400000;
    const future = now + 45 * 86400000;
    const writes = [];
    for (const d of docs) {
      const f = d.fields || {};
      const date = f.date?.timestampValue ? Date.parse(f.date.timestampValue) : 0;
      if (!date || date < past || date > future) continue;
      const r1 = findRank(val(f, 'team1'));
      const r2 = findRank(val(f, 'team2'));
      if (!r1 && !r2) continue;
      const fields = {};
      const mask = [];
      if (r1 && (String(val(f, 'rank1') || '') !== r1.rank || String(val(f, 'form1') || '') !== r1.form)) {
        fields.rank1 = { stringValue: r1.rank };
        fields.form1 = { stringValue: r1.form };
        mask.push('rank1', 'form1');
      }
      if (r2 && (String(val(f, 'rank2') || '') !== r2.rank || String(val(f, 'form2') || '') !== r2.form)) {
        fields.rank2 = { stringValue: r2.rank };
        fields.form2 = { stringValue: r2.form };
        mask.push('rank2', 'form2');
      }
      if (!mask.length) continue;
      writes.push({
        update: { name: d.name, fields },
        updateMask: { fieldPaths: mask },
      });
    }
    console.log(`enrich ${collection}: ${writes.length} fiche(s)`);
    for (let i = 0; i < writes.length; i += 20) {
      const chunk = writes.slice(i, i + 20);
      const res = await fetch(COMMIT, {
        method: 'POST',
        headers: { ...auth, 'Content-Type': 'application/json' },
        body: JSON.stringify({ writes: chunk }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(JSON.stringify(body).slice(0, 600));
    }
  }

  await dumpFs('ranking');
  await dumpFs('ranking_r2');
  const r1Picked = await push('ranking', r1, 1, 1);
  if (r1Picked?.members?.length) {
    await enrichMatchRanks('matches', r1Picked.members);
    await fetch(COMMIT, {
      method: 'POST',
      headers: { ...auth, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        writes: [{
          update: {
            name: `projects/${PROJECT}/databases/(default)/documents/competition/meta`,
            fields: {
              journee: intField(r1Picked.lastJournee),
              rankingTeamCount: intField(r1Picked.members.length),
              rankingSource: { stringValue: 'fff_classement_journees' },
              fffSyncedAt: { timestampValue: new Date().toISOString() },
            },
          },
          updateMask: { fieldPaths: ['journee', 'rankingTeamCount', 'rankingSource', 'fffSyncedAt'] },
        }],
      }),
    });
  }
  if (r2) {
    const r2Picked = await push('ranking_r2', r2, 1, 1);
    if (r2Picked?.members?.length) {
      await enrichMatchRanks('matches_r2', r2Picked.members);
    }
  }
  console.log('\nDONE');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
