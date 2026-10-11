/**
 * Sync FFF immédiate (classements R1/R2 + scores) depuis cette machine.
 * Le cron GCP (us-central1) se fait souvent 403 par le WAF FFF.
 *
 *   node scripts/run_fff_sync_now.js
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: 'drapeau-vert-app',
});

const db = getFirestore();
const FFF_BASE = 'https://api-dofa.fff.fr/api';
const FFF_HOST = 'https://api-dofa.fff.fr';
const headers = {
  Accept: 'application/ld+json, application/json',
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  Origin: 'https://epreuves.fff.fr',
  Referer: 'https://epreuves.fff.fr/',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
};

async function fetchJson(url) {
  const res = await fetch(url, { headers });
  const data = await res.json();
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  return data;
}

function parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw, 10);
  return Number.isNaN(n) ? null : n;
}

async function latestClassement(cp, ph, gp) {
  let url = `${FFF_BASE}/compets/${cp}/phases/${ph}/poules/${gp}/classement_journees`;
  const all = [];
  while (url) {
    const data = await fetchJson(url);
    all.push(...(data['hydra:member'] ?? []));
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  let lastJournee = 0;
  for (const e of all) {
    if ((e.cj_no ?? 0) > lastJournee) lastJournee = e.cj_no;
  }
  const members = lastJournee > 0
    ? all.filter((e) => (e.cj_no ?? 0) === lastJournee)
    : all;
  return { members, lastJournee };
}

async function writeRanking(col, season, members, lastJournee) {
  const existing = await db.collection(col).get();
  const logoByTeam = new Map();
  for (const d of existing.docs) {
    const x = d.data();
    const t = String(x.team || '').trim().toUpperCase();
    if (t && x.logo) logoByTeam.set(t, x.logo);
  }
  const batch = db.batch();
  const keep = new Set();
  for (const entry of members) {
    const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const docId = `pos_${entry.rank}`;
    keep.add(docId);
    const logo =
      entry.equipe?.club?.logo ||
      logoByTeam.get(String(teamName).trim().toUpperCase()) ||
      null;
    batch.set(
      db.collection(col).doc(docId),
      {
        season,
        position: entry.rank ?? 0,
        team: teamName,
        logo,
        mj: entry.total_games_count ?? 0,
        v: entry.won_games_count ?? 0,
        n: entry.draw_games_count ?? 0,
        d: entry.lost_games_count ?? 0,
        bf: entry.goals_for_count ?? 0,
        bc: entry.goals_against_count ?? 0,
        pts: entry.point_count ?? 0,
        forme: entry.forme ?? '',
        journee: entry.cj_no ?? lastJournee,
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );
  }
  for (const d of existing.docs) {
    if (!keep.has(d.id)) batch.delete(d.ref);
  }
  await batch.commit();
}

async function syncMatchScores({ cp, ph, gp, prefix, collection }) {
  let url = `${FFF_BASE}/compets/${cp}/phases/${ph}/poules/${gp}/matchs?journee=1`;
  let updated = 0;
  const seen = new Set();
  while (url) {
    const data = await fetchJson(url);
    for (const m of data['hydra:member'] ?? []) {
      const id = `${prefix}${m.ma_no}`;
      if (seen.has(id)) continue;
      seen.add(id);
      const s1 = parseScore(m.home_score);
      const s2 = parseScore(m.away_score);
      if (s1 === null || s2 === null) continue;
      const ref = db.collection(collection).doc(id);
      const snap = await ref.get();
      if (!snap.exists) continue;
      const cur = snap.data() || {};
      if (
        Number(cur.score1) === s1 &&
        Number(cur.score2) === s2 &&
        cur.status === 'finished'
      ) {
        continue;
      }
      await ref.set(
        {
          score1: s1,
          score2: s2,
          status: 'finished',
          updatedAt: Timestamp.now(),
        },
        { merge: true },
      );
      updated += 1;
      console.log(
        'score',
        collection,
        id,
        `${s1}-${s2}`,
        cur.team1,
        cur.team2,
      );
    }
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  return updated;
}

(async () => {
  const fff = await db.collection('app_config').doc('fff_season').get();
  const cfg = fff.data() || {};
  const season = cfg.seasonLabel || '2026-2027';
  const r1 = Number(cfg.fffCompetitionId) || 449966;
  const r2 = Number(cfg.fffR2CompetitionId) || 449972;

  const c1 = await latestClassement(r1, 1, 1);
  await writeRanking('ranking', season, c1.members, c1.lastJournee);
  console.log(`R1 classement J${c1.lastJournee} (${c1.members.length} équipes)`);

  if (r2) {
    const c2 = await latestClassement(r2, 1, 1);
    await writeRanking('ranking_r2', season, c2.members, c2.lastJournee);
    console.log(`R2 classement J${c2.lastJournee} (${c2.members.length} équipes)`);
  }

  await db.collection('competition').doc('meta').set(
    {
      journee: c1.lastJournee,
      fffSyncedAt: Timestamp.now(),
      rankingTeamCount: c1.members.length,
      rankingSource: 'fff_classement_journees',
    },
    { merge: true },
  );

  const n1 = await syncMatchScores({
    cp: r1,
    ph: 1,
    gp: 1,
    prefix: 'fff_',
    collection: 'matches',
  });
  const n2 = r2
    ? await syncMatchScores({
        cp: r2,
        ph: 1,
        gp: 1,
        prefix: 'fff_r2_',
        collection: 'matches_r2',
      })
    : 0;
  console.log(`scores écrits R1=${n1} R2=${n2}`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
