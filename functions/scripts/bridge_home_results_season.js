/**
 * Contournement store (sans rebuild) : l’app publiée filtre les résultats
 * home via MatchCalendarFilter + fffSeason == app_config/fff_season.seasonLabel,
 * puis retombe sur MatchModel.mockResults si la liste est vide.
 *
 * En début de saison 2026-2027 il n’y a aucun finished avec ce label → mocks.
 * Ce script retag temporairement les derniers matchs Sedan terminés 2025-2026
 * avec fffSeason = saison active, sans toucher aux scores / dates.
 *
 * Pourquoi pas de docs « bridge » clonés ?
 * MatchService déduplique par fffId ou (équipes+compétition+jour) AVANT le
 * filtre saison : un clone serait écrasé par l’original 2025-2026.
 *
 * Usage:
 *   node scripts/bridge_home_results_season.js           # dry-run
 *   node scripts/bridge_home_results_season.js --apply
 *   node scripts/bridge_home_results_season.js --revert
 *
 * Après déploiement store (filtre cross-season) : --revert puis supprimer ce hack.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: 'drapeau-vert-app',
});

const db = getFirestore();
const APPLY = process.argv.includes('--apply');
const REVERT = process.argv.includes('--revert');
const LIMIT = 3;

function isSedan(data) {
  const blob = `${data.team1 || ''} ${data.team2 || ''}`.toUpperCase();
  return blob.includes('SEDAN') || blob.includes('CSSA');
}

function dayKey(ts) {
  if (!ts || typeof ts.toDate !== 'function') return null;
  const d = ts.toDate();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

function pairKey(data) {
  const t1 = String(data.team1 || '')
    .trim()
    .toLowerCase();
  const t2 = String(data.team2 || '')
    .trim()
    .toLowerCase();
  const pair = t1.localeCompare(t2) <= 0 ? `${t1}|${t2}` : `${t2}|${t1}`;
  const comp = String(data.competition || '')
    .trim()
    .toLowerCase();
  return `${pair}|${comp}|${dayKey(data.date)}`;
}

async function loadActiveSeason() {
  const snap = await db.collection('app_config').doc('fff_season').get();
  const d = snap.data() || {};
  return (d.seasonLabel && String(d.seasonLabel).trim()) || '2026-2027';
}

async function revert({ write }) {
  const snap = await db
    .collection('matches')
    .where('seasonRetagForHomeResults', '==', true)
    .get();
  console.log(`Docs retaggés trouvés: ${snap.size}`);
  if (!write) {
    for (const doc of snap.docs) {
      const d = doc.data();
      console.log(
        `[dry-run] revert ${doc.id} → fffSeason=${d.trueSeason || '2025-2026'}`,
      );
    }
    console.log('Relancer avec --revert --apply pour écrire.');
    return;
  }
  const batch = db.batch();
  for (const doc of snap.docs) {
    const d = doc.data();
    const trueSeason =
      (d.trueSeason && String(d.trueSeason).trim()) || '2025-2026';
    batch.update(doc.ref, {
      fffSeason: trueSeason,
      seasonRetagForHomeResults: FieldValue.delete(),
      trueSeason: FieldValue.delete(),
      seasonRetaggedAt: FieldValue.delete(),
      seasonRetagNote: FieldValue.delete(),
      updatedAt: Timestamp.now(),
    });
    console.log(`revert ${doc.id} → ${trueSeason}`);
  }
  if (snap.size > 0) await batch.commit();
  console.log('Revert OK.');
}

async function applyBridge() {
  const activeSeason = await loadActiveSeason();
  console.log(`Saison active (fff_season): ${activeSeason}`);

  const finished = await db
    .collection('matches')
    .where('status', '==', 'finished')
    .orderBy('date', 'desc')
    .limit(120)
    .get();

  // 1) Corriger l’amical sans fffSeason (sinon il passe le filtre « manual sans saison »
  //    de l’app store et chasse un vrai résultat du top 3).
  const bogny = finished.docs.find((doc) => doc.id === '0Oymi92OyGyAnh8CN6Cu');
  if (bogny && !bogny.data().fffSeason) {
    console.log(
      `${APPLY ? 'FIX' : '[dry-run] FIX'} ${bogny.id} fffSeason → 2025-2026 (amical orphelin)`,
    );
    if (APPLY) {
      await bogny.ref.update({
        fffSeason: '2025-2026',
        updatedAt: Timestamp.now(),
      });
    }
  }

  // 2) Derniers Sedan uniques (hors amical), puis TOUS les docs dédupliquables
  //    (même fffId / même paire+jour) pour que le winner du MatchService soit aussi retaggé.
  const uniqueKeys = [];
  const seen = new Set();
  for (const doc of finished.docs) {
    const d = doc.data();
    if (!isSedan(d)) continue;
    if (String(d.competition || '')
      .toLowerCase()
      .includes('amical')) {
      continue;
    }
    const key = pairKey(d);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    uniqueKeys.push(key);
    if (uniqueKeys.length >= LIMIT) break;
  }

  console.log('Cibles uniques (ordre date desc):', uniqueKeys);

  const targetIds = new Set();
  const fffIds = new Set();
  for (const doc of finished.docs) {
    const d = doc.data();
    if (!isSedan(d)) continue;
    if (uniqueKeys.includes(pairKey(d))) {
      targetIds.add(doc.id);
      const fid = String(d.fffId || '').trim();
      if (fid) fffIds.add(fid);
    }
  }
  // siblings same fffId elsewhere in the batch
  for (const doc of finished.docs) {
    const fid = String(doc.data().fffId || '').trim();
    if (fid && fffIds.has(fid)) targetIds.add(doc.id);
  }

  const updates = [];
  for (const id of targetIds) {
    const ref = db.collection('matches').doc(id);
    const snap = await ref.get();
    if (!snap.exists) continue;
    const d = snap.data() || {};
    const current = (d.fffSeason && String(d.fffSeason).trim()) || null;
    if (current === activeSeason && d.seasonRetagForHomeResults === true) {
      console.log(`skip ${id} (déjà retaggé → ${activeSeason})`);
      continue;
    }
    const trueSeason =
      (d.trueSeason && String(d.trueSeason).trim()) ||
      current ||
      '2025-2026';
    updates.push({
      id,
      trueSeason,
      from: current,
      label: `${d.team1} ${d.score1}-${d.score2} ${d.team2} (${d.competition}) ${dayKey(d.date)}`,
    });
  }

  for (const u of updates) {
    console.log(
      `${APPLY ? 'RETAG' : '[dry-run] RETAG'} ${u.id}: ${u.from || '(null)'} → ${activeSeason} | trueSeason=${u.trueSeason} | ${u.label}`,
    );
  }

  if (!APPLY) {
    console.log('\nDry-run only. Relancer avec --apply pour écrire.');
    return;
  }

  const batch = db.batch();
  for (const u of updates) {
    batch.update(db.collection('matches').doc(u.id), {
      fffSeason: activeSeason,
      trueSeason: u.trueSeason,
      seasonRetagForHomeResults: true,
      seasonRetaggedAt: Timestamp.now(),
      seasonRetagNote:
        'Temp store workaround: home results filter by active fffSeason. Revert after store build with cross-season results.',
      updatedAt: Timestamp.now(),
    });
  }
  if (updates.length > 0) await batch.commit();
  console.log(`\nOK: ${updates.length} doc(s) retaggé(s) → ${activeSeason}`);
}

async function main() {
  if (REVERT) {
    await revert({ write: APPLY });
    return;
  }
  await applyBridge();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
