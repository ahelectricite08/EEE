/**
 * Corrige config/role_badges.labels.team_dvcr (Membre DVCR → Team DVCR).
 * Usage: node scripts/migrate_team_dvcr_label.js
 */
const admin = require('firebase-admin');

const LEGACY = new Set([
  'membre dvcr',
  'membres dvcr',
  'bénévole dvcr',
  'benevole dvcr',
  'bénévoles dvcr',
  'benevoles dvcr',
]);

function normalize(value) {
  const v = String(value || '').trim();
  if (!v || LEGACY.has(v.toLowerCase())) return 'Team DVCR';
  return v;
}

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'drapeau-vert-app' });
  }
  const db = admin.firestore();
  const ref = db.collection('config').doc('role_badges');
  const snap = await ref.get();
  if (!snap.exists) {
    console.log('config/role_badges absent — rien à migrer.');
    return;
  }
  const data = snap.data() || {};
  const labels = data.labels && typeof data.labels === 'object' ? { ...data.labels } : {};
  const before = String(labels.team_dvcr || '').trim();
  const after = normalize(before);
  if (before === after) {
    console.log(`Déjà OK (team_dvcr = "${before || '(vide)'}").`);
    return;
  }
  labels.team_dvcr = after;
  await ref.set(
    { labels, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  console.log(`Migré team_dvcr : "${before}" → "${after}"`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
