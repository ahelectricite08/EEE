/**
 * Script one-shot : ajoute des données fictives dans prono_leaderboard
 * pour tester le rendu du classement.
 *
 * Utilisation : node addFakePronoData.js
 * Supprimer ce fichier + les docs Firestore après test.
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const serviceAccount = (() => {
  try { return require('./serviceAccountKey.json'); } catch { return null; }
})();

if (serviceAccount) {
  initializeApp({ credential: cert(serviceAccount) });
} else {
  initializeApp();
}

const db = getFirestore();

const fakeData = [
  { uid: 'fake_1', displayName: 'Axel D.',    points: 22, exactScores: 5, goodResults: 7,  totalPredictions: 14 },
  { uid: 'fake_2', displayName: 'Thomas M.',  points: 17, exactScores: 3, goodResults: 8,  totalPredictions: 13 },
  { uid: 'fake_3', displayName: 'Julie B.',   points: 14, exactScores: 2, goodResults: 10, totalPredictions: 14 },
  { uid: 'fake_4', displayName: 'Kévin L.',   points: 11, exactScores: 1, goodResults: 8,  totalPredictions: 12 },
  { uid: 'fake_5', displayName: 'Marie T.',   points: 9,  exactScores: 1, goodResults: 6,  totalPredictions: 10 },
  { uid: 'fake_6', displayName: 'Romain C.',  points: 6,  exactScores: 0, goodResults: 6,  totalPredictions: 9  },
  { uid: 'fake_7', displayName: 'Lucie F.',   points: 3,  exactScores: 1, goodResults: 0,  totalPredictions: 7  },
];

(async () => {
  try {
    const batch = db.batch();
    for (const d of fakeData) {
      batch.set(db.collection('prono_leaderboard').doc(d.uid), {
        ...d,
        season:    '2025-2026',
        updatedAt: Timestamp.now(),
      });
    }
    await batch.commit();
    console.log(`✅ ${fakeData.length} entrées fictives ajoutées dans prono_leaderboard`);
    console.log('⚠️  Pense à supprimer ces docs + ce fichier après le test !');
    process.exit(0);
  } catch (e) {
    console.error('❌ Erreur :', e.message);
    process.exit(1);
  }
})();
