/**
 * Catch-up : attribue points + XP + notifs recap pour les matchs finished
 * qui ont un score mais pas encore `pronoScoredAt`.
 *
 *   node scripts/score_pending_pronos.js
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const {
  findPendingFinishedMatches,
  scoreFinishedMatchPronos,
} = require('../lib/prono_score_core');
const { maybeSendPronoDayRecap } = require('../lib/prono_day_recap');

initializeApp({
  credential: applicationDefault(),
  projectId: 'drapeau-vert-app',
});

const db = getFirestore();

(async () => {
  const pending = await findPendingFinishedMatches(db, {});
  console.log(`Matchs à scorer : ${pending.length}`);
  for (const row of pending) {
    const label = `${row.data.team1} ${row.data.score1}-${row.data.score2} ${row.data.team2}`;
    console.log(`→ ${row.id}  ${label}`);
    const result = await scoreFinishedMatchPronos(
      db,
      row.id,
      row.data,
      row.ref,
      { sendRecap: false },
    );
    const recap = await maybeSendPronoDayRecap(db, row.id, {
      ...row.data,
      pronoScoredAt: true,
    });
    console.log(JSON.stringify({ result, recap }));
  }
  console.log('DONE');
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
