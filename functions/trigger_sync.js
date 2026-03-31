// Script one-shot pour re-sync les matchs FFF après fix timezone
// Usage: cd functions && node trigger_sync.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'drapeau-vert-app',
});

const db = admin.firestore();

// Calcule si une date est en heure d'été (CEST) ou hiver (CET) pour Paris
function getParisOffsetHours(date) {
  // Dernier dimanche de mars (passage à l'heure d'été) à 2h UTC
  const year = date.getUTCFullYear();
  const marchLast = new Date(Date.UTC(year, 2, 31));
  while (marchLast.getUTCDay() !== 0) marchLast.setUTCDate(marchLast.getUTCDate() - 1);
  marchLast.setUTCHours(1, 0, 0, 0); // 2h CET = 1h UTC

  // Dernier dimanche d'octobre (passage à l'heure d'hiver) à 1h UTC  
  const octLast = new Date(Date.UTC(year, 9, 31));
  while (octLast.getUTCDay() !== 0) octLast.setUTCDate(octLast.getUTCDate() - 1);
  octLast.setUTCHours(1, 0, 0, 0); // 3h CEST = 1h UTC

  return (date >= marchLast && date < octLast) ? 2 : 1;
}

async function syncDirect() {
  const FFF_BASE = 'https://api-dofa.fff.fr/api';
  const FFF_HOST = 'https://api-dofa.fff.fr';
  const FFF_CP = 436257;
  const FFF_PH = 1;
  const FFF_GP = 1;

  // Récupère TOUS les matchs de la poule (pagination) — même approche que index.js
  const matches = [];
  let url = `${FFF_BASE}/compets/${FFF_CP}/phases/${FFF_PH}/poules/${FFF_GP}/matchs?journee=1`;
  while (url) {
    const res = await fetch(url, { headers: { Accept: 'application/ld+json' } });
    if (!res.ok) { console.error('HTTP', res.status, url); break; }
    const data = await res.json();
    matches.push(...(data['hydra:member'] || []));
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  console.log(`Found ${matches.length} matches (toute la poule)`);

  let updated = 0;
  for (const match of matches) {
    const fffId = `${match.ma_no}`;
    const dateStr = match.date;
    const timeStr = match.time;

    if (!dateStr) continue;

    const base = new Date(dateStr);
    if (timeStr) {
      const m = timeStr.match(/(\d+)H(\d+)/i);
      if (m) {
        const h = parseInt(m[1]);
        const min = parseInt(m[2]);
        // L'heure FFF est en heure de Paris, on la convertit en UTC
        const offset = getParisOffsetHours(base);
        base.setUTCHours(h - offset, min, 0, 0);
      }
    }

    // Essaie les deux formats de doc ID (ancien: fff_2025_X, nouveau: fff_X)
    for (const docId of [`fff_${fffId}`, `fff_2025_${fffId}`]) {
      const docRef = db.collection('matches').doc(docId);
      const doc = await docRef.get();
      if (doc.exists) {
        const old = doc.data().date?.toDate?.()?.toISOString() ?? 'inconnu';
        await docRef.update({ date: admin.firestore.Timestamp.fromDate(base) });
        console.log(`✓ ${docId}: ${old} → ${base.toISOString()} (Paris: ${timeStr})`);
        updated++;
      }
    }
  }

  console.log(`\nDone! ${updated} matchs mis à jour.`);
}

syncDirect().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
