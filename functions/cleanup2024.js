/**
 * Nettoyage : supprime le classement 2024-2025
 * Utilisation : node cleanup2024.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = (() => {
  try { return require('./serviceAccountKey.json'); } catch { return null; }
})();

if (serviceAccount) {
  initializeApp({ credential: cert(serviceAccount) });
} else {
  initializeApp();
}

const db = getFirestore();

(async () => {
  try {
    console.log('🗑️  Suppression du classement 2024-2025...');
    const existing = await db.collection('ranking').where('season', '==', '2024-2025').get();
    const batch = db.batch();
    existing.docs.forEach(d => batch.delete(d.ref));
    if (!existing.empty) await batch.commit();
    console.log(`✅ ${existing.size} entrée(s) supprimée(s)`);
    process.exit(0);
  } catch (e) {
    console.error('❌ Erreur:', e.message);
    process.exit(1);
  }
})();
