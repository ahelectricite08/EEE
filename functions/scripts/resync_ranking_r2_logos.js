/**
 * One-shot : remplit ranking_r2.logo depuis les matchs FFF R2 (id 449972).
 * Usage: node scripts/resync_ranking_r2_logos.js
 */
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { initLocalAdminApp } = require('../admin_app');
const { _loadFffSeasonConfig, FFF_BASE, FFF_HOST } = require('../lib/fff_config');
const {
  collectLogosFromMatchMembers,
  emptyLogoMaps,
  mergeLogoMaps,
  rankingLogoForEntry,
  fffClubNo,
} = require('../lib/fff_ranking_logos');

const FFF_FETCH_HEADERS = {
  Accept: 'application/ld+json, application/json',
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  Origin: 'https://epreuves.fff.fr',
  Referer: 'https://epreuves.fff.fr/',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
};

async function fffJson(url) {
  const res = await fetch(url, { headers: FFF_FETCH_HEADERS });
  const text = await res.text();
  let data = null;
  try {
    data = JSON.parse(text);
  } catch (_) {
    throw new Error(`Non-JSON HTTP ${res.status} ${url}`);
  }
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  return data;
}

async function fetchLatestClassement(cp, ph, gp) {
  let url = `${FFF_BASE}/compets/${cp}/phases/${ph}/poules/${gp}/classement_journees`;
  const all = [];
  while (url) {
    const data = await fffJson(url);
    all.push(...(data['hydra:member'] ?? []));
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  let lastJournee = 0;
  for (const entry of all) {
    const j = entry.cj_no ?? 0;
    if (j > lastJournee) lastJournee = j;
  }
  const members =
    lastJournee > 0 ? all.filter((e) => (e.cj_no ?? 0) === lastJournee) : all;
  return { members, lastJournee };
}

async function fetchMatchLogos(cp, ph, gp) {
  const url =
    `${FFF_BASE}/compets/${cp}/phases/${ph}/poules/${gp}/matchs?journee=1&itemsPerPage=100`;
  const data = await fffJson(url);
  return collectLogosFromMatchMembers(data['hydra:member'] ?? []);
}

async function main() {
  initLocalAdminApp();
  const db = getFirestore();
  const cfg = await _loadFffSeasonConfig(db);
  const cp = cfg.r2Cp || 449972;
  const ph = cfg.r2Ph || 1;
  const gp = cfg.r2Gp || 1;
  console.log(`R2 FFF ${cp}/${ph}/${gp} season ${cfg.seasonLabel}`);

  const { members, lastJournee } = await fetchLatestClassement(cp, ph, gp);
  console.log(`Classement J${lastJournee} : ${members.length} équipes`);
  const maps = mergeLogoMaps(emptyLogoMaps(), await fetchMatchLogos(cp, ph, gp));
  console.log(`Logos matchs : ${maps.byClNo.size} clubs`);

  const batch = db.batch();
  let withLogo = 0;
  let missing = 0;
  for (const entry of members) {
    const logo = rankingLogoForEntry(entry, maps);
    const team = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const clNo = fffClubNo(entry.equipe);
    if (logo) {
      withLogo += 1;
      batch.set(
        db.collection('fff_club_logos').doc(String(clNo || team)),
        {
          clNo: clNo || 0,
          logo,
          shortName: team,
          updatedAt: Timestamp.now(),
        },
        { merge: true },
      );
    } else {
      missing += 1;
      console.warn(`Sans logo : ${team} cl_no=${clNo}`);
    }
    const docId = `pos_${entry.rank}`;
    batch.set(
      db.collection('ranking_r2').doc(docId),
      { logo: logo || null, updatedAt: Timestamp.now() },
      { merge: true },
    );
  }
  await batch.commit();
  console.log(`Écrit ranking_r2 + fff_club_logos — ${withLogo} logos, ${missing} manquants`);

  const snap = await db.collection('ranking_r2').get();
  let filled = 0;
  for (const doc of snap.docs) {
    const u = (doc.data().logo || '').toString().trim();
    if (u) filled += 1;
    console.log(`${doc.id} ${doc.data().team} ${u ? 'OK' : 'VIDE'}`);
  }
  console.log(`Firestore ranking_r2 : ${filled}/${snap.size} avec logo`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
