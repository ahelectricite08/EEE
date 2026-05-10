/**
 * Script one-shot : importe classement + résultats R1 saison 2025-2026
 * (Régional 1, cp_no=436257, poule 1)
 *
 * Utilisation :
 *   node import2025.js
 *
 * Supprimer ce fichier après utilisation.
 */

const { initLocalAdminApp } = require('./admin_app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

// ── Config ─────────────────────────────────────────────────────────────────
const FFF_BASE  = 'https://api-dofa.fff.fr/api';
const FFF_HOST  = 'https://api-dofa.fff.fr';
const CP        = 436257;   // Régional 1 2025-2026
const PH        = 1;
const GP        = 1;        // Poule A
const SEASON    = '2025-2026';
const COMP_NAME = 'Régional 1';

// Charge les credentials du service account (même dossier que ce script)
// ou utilise GOOGLE_APPLICATION_CREDENTIALS si déjà défini
initLocalAdminApp();

const db = getFirestore();

// ── Helpers ────────────────────────────────────────────────────────────────
async function fffGet(url) {
  const res = await fetch(url, { headers: { Accept: 'application/ld+json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status} — ${url}`);
  return res.json();
}

function parseMatchDate(dateStr, timeStr) {
  const base = new Date(dateStr);
  if (timeStr) {
    const m = timeStr.match(/(\d+)H(\d+)/i);
    if (m) base.setUTCHours(parseInt(m[1]), parseInt(m[2]), 0, 0);
  }
  return base;
}

function parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw);
  return isNaN(n) ? null : n;
}

// ── 1. Import classement ───────────────────────────────────────────────────
async function importClassement() {
  console.log('\n📊 Import classement 2025-2026...');
  const url = `${FFF_BASE}/compets/${CP}/phases/${PH}/poules/${GP}/classement_journees`;
  const data = await fffGet(url);
  const members = data['hydra:member'] ?? [];
  if (!members.length) { console.warn('  Classement vide'); return; }

  // Supprime les anciennes entrées 2024-2025
  const existing = await db.collection('ranking').where('season', '==', SEASON).get();
  const delBatch = db.batch();
  existing.docs.forEach(d => delBatch.delete(d.ref));
  if (!existing.empty) await delBatch.commit();
  console.log(`  ${existing.size} entrée(s) supprimée(s)`);

  // Écrit les nouvelles
  const batch = db.batch();
  let lastJ = 0;
  for (const e of members) {
    const j = e.cj_no ?? 0;
    if (j > lastJ) lastJ = j;
    const ref = db.collection('ranking').doc(`r2_2024_pos_${e.rank}`);
    batch.set(ref, {
      season:   SEASON,
      position: e.rank ?? 0,
      team:     e.equipe?.short_name ?? '',
      logo:     e.equipe?.club?.logo ?? null,
      mj:       e.total_games_count ?? 0,
      v:        e.won_games_count  ?? 0,
      n:        e.draw_games_count ?? 0,
      d:        e.lost_games_count ?? 0,
      bf:       e.goals_for_count     ?? 0,
      bc:       e.goals_against_count ?? 0,
      pts:      e.point_count ?? 0,
      forme:    e.forme ?? '',
      updatedAt: Timestamp.now(),
    });
  }
  await batch.commit();
  console.log(`  ✓ ${members.length} équipes importées (J${lastJ})`);

  // Écrit la meta journée pour que l'app affiche le bon numéro
  await db.collection('competition').doc(SEASON).set({
    journee:   lastJ,
    competition: COMP_NAME,
    updatedAt: Timestamp.now(),
  }, { merge: true });
  console.log(`  ✓ competition/${SEASON} meta écrit (J${lastJ})`);
}

// ── 2. Import résultats CSSA ───────────────────────────────────────────────
async function importMatches() {
  console.log('\n⚽ Import matchs R1 2025-2026...');
  const headers = { Accept: 'application/ld+json' };
  let url = `${FFF_BASE}/compets/${CP}/phases/${PH}/poules/${GP}/matchs?journee=1`;
  let written = 0;

  // Supprime les anciens matchs FFF 2024
  const existing = await db.collection('matches')
    .where('fffSeason', '==', SEASON).get();
  const delBatch = db.batch();
  existing.docs.forEach(d => delBatch.delete(d.ref));
  if (!existing.empty) await delBatch.commit();
  console.log(`  ${existing.size} match(s) supprimé(s)`);

  while (url) {
    const data = await fffGet(url);
    for (const m of data['hydra:member'] ?? []) {
      // Import TOUS les matchs de la poule (pas de filtre SEDAN)
      // Cela permet d'avoir les données de forme pour toutes les équipes
      const fffId = m.ma_no;
      if (!fffId) continue;

      const dateStr  = m.date;
      if (!dateStr) continue;
      const matchDate = parseMatchDate(dateStr, m.time);

      const score1 = parseScore(m.home_score);
      const score2 = parseScore(m.away_score);
      const isFinished = score1 !== null && score2 !== null;

      await db.collection('matches').doc(`fff_2025_${fffId}`).set({
        team1:       m.home?.short_name ?? '',
        team2:       m.away?.short_name ?? '',
        logo1:       m.home?.club?.logo ?? null,
        logo2:       m.away?.club?.logo ?? null,
        score1,
        score2,
        date:        Timestamp.fromDate(matchDate),
        competition: COMP_NAME,
        status:      isFinished ? 'finished' : 'upcoming',
        fffId:       String(fffId),
        fffSeason:   SEASON,
        updatedAt:   Timestamp.now(),
      }, { merge: true });
      written++;
    }
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  console.log(`  ✓ ${written} match(s) CSSA importé(s)`);
}

// ── Main ───────────────────────────────────────────────────────────────────
(async () => {
  try {
    await importClassement();
    await importMatches();
    console.log('\n✅ Import 2025-2026 terminé !');
    process.exit(0);
  } catch (e) {
    console.error('❌ Erreur:', e.message);
    process.exit(1);
  }
})();
