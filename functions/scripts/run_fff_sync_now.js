/**
 * Courier FFF hors GCP (GitHub Actions 1×/jour, ou PC).
 * Classements R1/R2, calendrier (à venir + résultats), puis pronos.
 * Ne recrée pas un match déjà identifié par `fffId` / `fff_{ma_no}`.
 *
 *   node scripts/run_fff_sync_now.js
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { runFffCourier } = require('../fff_sync');
const {
  findPendingFinishedMatches,
  scoreFinishedMatchPronos,
} = require('../lib/prono_score_core');

initializeApp({
  credential: applicationDefault(),
  projectId: 'drapeau-vert-app',
});

const db = getFirestore();

(async () => {
  const result = await runFffCourier(db, { force: true });
  console.log('FFF courier', result);
  if (result.skipped) {
    process.exit(0);
    return;
  }

  const pending = await findPendingFinishedMatches(db, {});
  console.log(`Pronos à scorer : ${pending.length}`);
  let scored = 0;
  for (const row of pending) {
    const out = await scoreFinishedMatchPronos(
      db,
      row.id,
      row.data,
      row.ref,
      { sendRecap: false },
    );
    scored += Number(out && out.scored) || 0;
    console.log(
      'prono',
      row.id,
      `${row.data.team1} ${row.data.score1}-${row.data.score2} ${row.data.team2}`,
      out,
    );
  }
  console.log(`pronos scorés=${scored}`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
