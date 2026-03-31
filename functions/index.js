const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { onCall }            = require('firebase-functions/v2/https');
const { initializeApp }     = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getMessaging }      = require('firebase-admin/messaging');

// ── FFF API — CSSA Régional 1 Grand Est ──────────────────────────────────────
const FFF_BASE  = 'https://api-dofa.fff.fr/api';
const FFF_HOST  = 'https://api-dofa.fff.fr';  // pour les liens hydra:next
const FFF_CP    = 436257;  // Régional 1 Homiris Grand Est 2025-2026
const FFF_PH    = 1;
const FFF_GP    = 1;       // Poule A (CSSA's group)
const FFF_CLUB  = 500266;  // CS Sedan Ardennes

initializeApp();

const YOUTUBE_API_KEY = 'AIzaSyBH2Jq3O2rEg9l5R0Mb1Mz42TqqCu9H00Q';

const PLAYLISTS = [
  { id: 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD', category: 'resume'     },
  { id: 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22', category: 'podcast'    },
  { id: 'PLHZuIRHxEd8w_J7I_aEhtGc2MpLfINJVB', category: 'matchday'   },
  { id: 'PLHZuIRHxEd8zKv-Z_Y-kg1_1S7u07Nw90', category: 'partenaire' },
];

// ── 1. Notification push quand un article est publié ─────────────────────────
exports.notifyArticlePublished = onDocumentWritten('articles/{id}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return; // suppression

  // Déclenche uniquement si on passe à 'published' (création ou depuis draft)
  const wasDraft    = !before || before.status !== 'published';
  const isPublished = after.status === 'published';
  if (!isPublished || !wasDraft) return;

  await getMessaging().send({
    topic: 'dvcr_articles',
    notification: {
      title: '📰 Nouvelle actu DVCR',
      body:  after.title || 'Nouvel article publié',
    },
    data: {
      type:      'article',
      articleId: event.params.id,
    },
    android: {
      priority: 'high',
      notification: { sound: 'default', channelId: 'dvcr_articles' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });
});

// ── 2. Nettoyage automatique des messages de chat (> 7 jours) ────────────────
exports.cleanOldChatMessages = onSchedule('every 24 hours', async () => {
  const db      = getFirestore();
  const cutoff  = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const snap    = await db.collection('chat')
    .where('createdAt', '<', Timestamp.fromDate(cutoff))
    .get();

  if (snap.empty) { console.log('Aucun message à supprimer'); return; }

  // Suppression par batch de 500 (limite Firestore)
  const chunks = [];
  for (let i = 0; i < snap.docs.length; i += 500) {
    chunks.push(snap.docs.slice(i, i + 500));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`Chat : ${snap.docs.length} message(s) supprimé(s) (> 7 jours)`);
});

// ── 2. Notification push quand un live démarre ────────────────────────────────
exports.notifyLive = onDocumentCreated('live/current', async (event) => {
  const data = event.data?.data();
  if (!data) return;

  await getMessaging().send({
    topic: 'dvcr_live',
    notification: {
      title: '🔴 DVCR est en direct !',
      body:  'Rejoins-nous maintenant',
    },
    data: {
      url:  data.url ?? '',
      type: 'live',
    },
    android: {
      priority: 'high',
      notification: { sound: 'default', channelId: 'dvcr_live' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });
});

exports.notifyEmission = onDocumentCreated('live/emission', async (event) => {
  const data = event.data?.data();
  if (!data) return;

  await getMessaging().send({
    topic: 'dvcr_live',
    notification: {
      title: '📺 L\'émission DVCR est en direct !',
      body:  'Rejoins-nous maintenant',
    },
    data: {
      url:  data.url ?? '',
      type: 'emission',
    },
    android: {
      priority: 'high',
      notification: { sound: 'default', channelId: 'dvcr_live' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });
});

// ── 2. Sync vidéos YouTube → Firestore (toutes les heures) ───────────────────
exports.syncYoutubeVideos = onSchedule('every 1 hours', async () => {
  const db = getFirestore();
  for (const playlist of PLAYLISTS) {
    await _syncPlaylist(db, playlist.id, playlist.category);
  }
});

// Sync manuelle déclenchable depuis l'admin web (admin only)
exports.syncYoutubeVideosManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const role = userDoc.exists ? userDoc.data().role : '';
  if (role !== 'admin') throw new Error('Accès refusé');
  for (const playlist of PLAYLISTS) {
    await _syncPlaylist(db, playlist.id, playlist.category);
  }
  return { success: true };
});

// ── Sync une playlist complète ────────────────────────────────────────────────
async function _syncPlaylist(db, playlistId, category) {
  const playlistIds = new Set();
  let nextPageToken = null;

  do {
    const url = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${playlistId}&maxResults=50${nextPageToken ? `&pageToken=${nextPageToken}` : ''}&key=${YOUTUBE_API_KEY}`;
    const res  = await fetch(url);
    const data = await res.json();

    const items = data.items ?? [];

    // Récupère les IDs pour la durée en batch
    const videoIds = items
      .map(i => i.snippet?.resourceId?.videoId)
      .filter(Boolean)
      .join(',');

    const detailsRes = await fetch(
      `https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics&id=${videoIds}&key=${YOUTUBE_API_KEY}`
    );
    const detailsData = await detailsRes.json();
    const detailsMap  = {};
    for (const v of detailsData.items ?? []) {
      detailsMap[v.id] = v;
    }

    for (const item of items) {
      const snippet   = item.snippet;
      const youtubeId = snippet?.resourceId?.videoId;
      if (!youtubeId) continue;

      // Skip vidéos privées ou supprimées
      const title = snippet.title ?? '';
      if (title === 'Private video' || title === 'Deleted video' || title === '') continue;

      playlistIds.add(youtubeId);

      // Skip si déjà dans Firestore
      const existing = await db.collection('videos')
        .where('youtubeId', '==', youtubeId)
        .limit(1)
        .get();
      if (!existing.empty) continue;

      const detail   = detailsMap[youtubeId];
      const duration = _formatDuration(detail?.contentDetails?.duration ?? '');
      const views    = parseInt(detail?.statistics?.viewCount ?? '0');

      await db.collection('videos').add({
        youtubeId,
        title:      snippet.title ?? '',
        duration,
        category,
        views,
        created_at: Timestamp.fromDate(new Date(snippet.publishedAt)),
      });

      console.log(`[${category}] Ajouté : ${snippet.title}`);
    }

    nextPageToken = data.nextPageToken ?? null;
  } while (nextPageToken);

  // Supprime les vidéos de cette catégorie qui ne sont plus dans la playlist
  const firestoreDocs = await db.collection('videos')
    .where('category', '==', category)
    .get();
  const batch = db.batch();
  let deleted = 0;
  for (const doc of firestoreDocs.docs) {
    if (!playlistIds.has(doc.data().youtubeId)) {
      batch.delete(doc.ref);
      deleted++;
    }
  }
  if (deleted > 0) {
    await batch.commit();
    console.log(`[${category}] Supprimés (retirés de la playlist) : ${deleted}`);
  }
}

// ── 3. Sync FFF classement + matchs CSSA → Firestore (toutes les 6 heures) ───
exports.syncFffData = onSchedule('every 6 hours', async () => {
  const db = getFirestore();
  await Promise.all([
    _syncClassement(db),
    _cleanMockMatches(db),
    _syncMatches(db),
  ]);
  console.log('FFF sync terminé');
});

// Sync manuelle scores/classement (admin only)
exports.syncFffDataManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const role = userDoc.exists ? userDoc.data().role : '';
  if (role !== 'admin') throw new Error('Accès refusé');
  await Promise.all([
    _syncClassement(db),
    _cleanMockMatches(db),
    _syncMatches(db),
  ]);
  return { success: true };
});

// ── Supprime les documents matches sans fffId (données mock) ─────────────────
async function _cleanMockMatches(db) {
  const snap = await db.collection('matches').where('fffId', '==', null).get();
  // Aussi cherche docs sans le champ fffId du tout
  const snap2 = await db.collection('matches').get();
  const batch = db.batch();
  let count = 0;
  for (const doc of snap2.docs) {
    if (!doc.data().fffId) {
      batch.delete(doc.ref);
      count++;
    }
  }
  if (count > 0) {
    await batch.commit();
    console.log(`Mock supprimés : ${count}`);
  }
}

// ── Sync classement FFF → collection "ranking" ────────────────────────────────
async function _syncClassement(db) {
  const url = `${FFF_BASE}/compets/${FFF_CP}/phases/${FFF_PH}/poules/${FFF_GP}/classement_journees`;
  const res  = await fetch(url, { headers: { Accept: 'application/ld+json' } });
  if (!res.ok) { console.error('Classement HTTP', res.status); return; }
  const data = await res.json();

  const members = data['hydra:member'] ?? [];
  if (!members.length) { console.warn('Classement vide'); return; }

  // Supprime uniquement les docs de la saison courante (pas les autres saisons)
  const existing = await db.collection('ranking').get();
  const batch = db.batch();
  for (const d of existing.docs) {
    const s = d.data().season;
    if (!s || s === '2025-2026') batch.delete(d.ref);
  }

  let lastJournee = 0;
  for (const entry of members) {
    // Vrais noms de champs FFF API
    const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const mj       = entry.total_games_count ?? 0;
    const journee  = entry.cj_no ?? 0;
    if (journee > lastJournee) lastJournee = journee;

    const ref = db.collection('ranking').doc(`pos_${entry.rank}`);
    batch.set(ref, {
      season:    '2025-2026',
      position:  entry.rank ?? 0,
      team:      teamName,
      logo:      entry.equipe?.logo ?? null,
      mj,
      v:         entry.won_games_count  ?? 0,
      n:         entry.draw_games_count ?? 0,
      d:         entry.lost_games_count ?? 0,
      bf:        entry.goals_for_count     ?? 0,
      bc:        entry.goals_against_count ?? 0,
      pts:       entry.point_count ?? 0,
      forme:     entry.forme ?? '',
      updatedAt: Timestamp.now(),
    });
  }

  // Save current journée in meta doc
  batch.set(db.collection('competition').doc('meta'), {
    journee:   lastJournee,
    updatedAt: Timestamp.now(),
  }, { merge: true });

  await batch.commit();
  console.log(`Classement : ${members.length} équipes, J${lastJournee}`);
}

// ── Sync matchs CSSA → collection "matches" ───────────────────────────────────
// Pagine tous les 182 matchs de la poule (7 pages) via hydra:next
async function _syncMatches(db) {
  const headers = { Accept: 'application/ld+json' };
  const seenIds = new Set();
  let   written = 0;

  // Démarre page 1 — journee=1 est requis pour éviter le 404
  let url = `${FFF_BASE}/compets/${FFF_CP}/phases/${FFF_PH}/poules/${FFF_GP}/matchs?journee=1`;

  while (url) {
    const res = await fetch(url, { headers });
    if (!res.ok) { console.error('Matchs HTTP', res.status, url); break; }
    const data = await res.json();

    for (const m of data['hydra:member'] ?? []) {
      if (_isCSSA(m)) {
        const w = await _writeMatch(db, m, seenIds);
        if (w) written++;
      }
    }

    // Suit la pagination Hydra
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }

  console.log(`Matchs CSSA écrits/mis à jour : ${written}`);
}

function _isCSSA(match) {
  const homeCl = match.home?.club?.cl_no;
  const awayCl = match.away?.club?.cl_no;
  if (homeCl === 380 || awayCl === 380) return true;
  // Fallback nom
  const h = (match.home?.short_name ?? '').toUpperCase();
  const a = (match.away?.short_name ?? '').toUpperCase();
  return h.includes('SEDAN ARDENNES') || a.includes('SEDAN ARDENNES');
}

async function _writeMatch(db, match, seenIds) {
  const fffId = match.ma_no;
  if (!fffId || seenIds.has(fffId)) return false;
  seenIds.add(fffId);

  const homeTeam = match.home?.short_name ?? '';
  const awayTeam = match.away?.short_name ?? '';
  if (!homeTeam || !awayTeam) return false;

  // Date + time → "2025-08-24T00:00:00+00:00" + "16H00" → Date
  const dateStr = match.date;
  if (!dateStr) return false;
  const matchDate = _parseMatchDate(dateStr, match.time);

  const homeLogo = match.home?.club?.logo ?? null;
  const awayLogo = match.away?.club?.logo ?? null;
  const score1   = _parseScore(match.home_score);
  const score2   = _parseScore(match.away_score);
  const isFinished = score1 !== null && score2 !== null;
  const isPast     = matchDate < new Date();

  await db.collection('matches').doc(`fff_${fffId}`).set({
    team1:       homeTeam,
    team2:       awayTeam,
    logo1:       homeLogo,
    logo2:       awayLogo,
    score1,
    score2,
    date:        Timestamp.fromDate(matchDate),
    competition: 'Régional 1',
    status:      isFinished || isPast ? 'finished' : 'upcoming',
    fffId:       String(fffId),
    updatedAt:   Timestamp.now(),
  }, { merge: true });
  return true;
}

// "2025-08-24T00:00:00+00:00" + "16H00" → Date
function _parseMatchDate(dateStr, timeStr) {
  // dateStr = "2025-06-14", timeStr = "20H00" (heure française)
  const base = new Date(dateStr);
  if (timeStr) {
    const match = timeStr.match(/(\d+)H(\d+)/i);
    if (match) {
      const h = parseInt(match[1]);
      const m = parseInt(match[2]);
      // L'heure FFF est en Europe/Paris → convertir en UTC
      const offset = _getParisOffsetHours(base);
      base.setUTCHours(h - offset, m, 0, 0);
    }
  }
  return base;
}

function _getParisOffsetHours(date) {
  const year = date.getUTCFullYear();
  // Dernier dimanche de mars à 1h UTC (= 2h CET → passage en CEST)
  const marchLast = new Date(Date.UTC(year, 2, 31));
  while (marchLast.getUTCDay() !== 0) marchLast.setUTCDate(marchLast.getUTCDate() - 1);
  marchLast.setUTCHours(1, 0, 0, 0);
  // Dernier dimanche d'octobre à 1h UTC (= 3h CEST → passage en CET)
  const octLast = new Date(Date.UTC(year, 9, 31));
  while (octLast.getUTCDay() !== 0) octLast.setUTCDate(octLast.getUTCDate() - 1);
  octLast.setUTCHours(1, 0, 0, 0);
  return (date >= marchLast && date < octLast) ? 2 : 1;
}

function _parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw);
  return isNaN(n) ? null : n;
}

// ── 4. Pronostics — calcul des points quand un match passe à "finished" ───────
exports.calculatePronoPoints = onDocumentWritten('matches/{matchId}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return;

  // Déclenche seulement quand le statut passe à 'finished' pour la première fois
  if (before?.status === 'finished' || after.status !== 'finished') return;

  const score1 = after.score1;
  const score2 = after.score2;
  if (score1 === null || score1 === undefined || score2 === null || score2 === undefined) return;

  const db      = getFirestore();
  const matchId = event.params.matchId;

  const predsSnap = await db.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  if (predsSnap.empty) {
    console.log(`Aucun prono pour le match ${matchId}`);
    return;
  }

  const batch = db.batch();

  for (const doc of predsSnap.docs) {
    const pred = doc.data();
    const p1   = pred.score1Pred;
    const p2   = pred.score2Pred;

    let points = 0;
    if (p1 === score1 && p2 === score2) {
      points = 3;
    } else {
      const predResult = Math.sign(p1 - p2);
      const realResult = Math.sign(score1 - score2);
      if (predResult === realResult) points = 1;
    }

    batch.update(doc.ref, {
      points,
      resolvedAt: FieldValue.serverTimestamp(),
    });

    // Mise à jour du classement global (merge pour créer ou incrémenter)
    const lbRef = db.collection('prono_leaderboard').doc(pred.uid);
    batch.set(lbRef, {
      uid:              pred.uid,
      displayName:      pred.displayName,
      points:           FieldValue.increment(points),
      exactScores:      FieldValue.increment(points === 3 ? 1 : 0),
      goodResults:      FieldValue.increment(points === 1 ? 1 : 0),
      totalPredictions: FieldValue.increment(1),
      season:           pred.season ?? '2025-2026',
      updatedAt:        FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();
  console.log(`Pronos calculés pour ${matchId} (${score1}-${score2}) : ${predsSnap.size} prédiction(s)`);
});

// ── Notifications live (but, mi-temps, fin de match) ─────────────────────────
exports.notifyGoal = onDocumentWritten('live/current', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();

  // ── Début de match (document créé) ──
  if (!before && after) {
    const team1 = after.team1 || 'Domicile';
    const team2 = after.team2 || 'Extérieur';
    await getMessaging().send({
      topic: 'dvcr_live',
      notification: {
        title: '🔴 C\'est parti ! Rejoins-nous !',
        body:  `${team1} vs ${team2} — Le live a commencé !`,
      },
      data: { type: 'kickoff' },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── Fin de match (document supprimé) ──
  if (before && !after) {
    const team1 = before.team1 || 'Domicile';
    const team2 = before.team2 || 'Extérieur';
    const h     = before.scoreHome ?? 0;
    const a     = before.scoreAway ?? 0;
    await getMessaging().send({
      topic: 'dvcr_alerts',
      notification: {
        title: '🏁 Fin du match !',
        body:  `Score final : ${team1} ${h} - ${a} ${team2}`,
      },
      data: { type: 'fulltime' },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  if (!before || !after) return;

  const team1 = after.team1 || 'Domicile';
  const team2 = after.team2 || 'Extérieur';
  const h     = after.scoreHome  ?? 0;
  const a     = after.scoreAway  ?? 0;

  // ── Mi-temps ──
  if (after.lastEvent === 'halftime' && before.lastEvent !== 'halftime') {
    await getMessaging().send({
      topic: 'dvcr_alerts',
      notification: {
        title: '⏸ Mi-temps ! Rejoins-nous !',
        body:  `Score : ${team1} ${h} - ${a} ${team2}`,
      },
      data: { type: 'halftime' },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── But / But annulé ──
  const prevHome = before.scoreHome ?? 0;
  const prevAway = before.scoreAway ?? 0;

  let title = null;
  if      (h > prevHome) title = `⚽ BUT ! ${team1}`;
  else if (a > prevAway) title = `⚽ BUT ! ${team2}`;
  else if (h < prevHome) title = `❌ But annulé — ${team1}`;
  else if (a < prevAway) title = `❌ But annulé — ${team2}`;
  if (!title) return;

  await getMessaging().send({
    topic: 'dvcr_alerts',
    notification: { title, body: `${team1} ${h} - ${a} ${team2}` },
    data: { type: 'goal' },
    android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
    apns: { payload: { aps: { sound: 'default' } } },
  });
});

// ── TEMP : Peuple un faux classement de pronos (admin only — à supprimer après) ─
exports.addFakePronoData = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const role = userDoc.exists ? userDoc.data().role : '';
  if (role !== 'admin') throw new Error('Accès refusé');

  const fakeData = [
    { uid: 'fake_1', displayName: 'Axel D.',   points: 22, exactScores: 5, goodResults: 7,  totalPredictions: 14 },
    { uid: 'fake_2', displayName: 'Thomas M.', points: 17, exactScores: 3, goodResults: 8,  totalPredictions: 13 },
    { uid: 'fake_3', displayName: 'Julie B.',  points: 14, exactScores: 2, goodResults: 10, totalPredictions: 14 },
    { uid: 'fake_4', displayName: 'Kévin L.',  points: 11, exactScores: 1, goodResults: 8,  totalPredictions: 12 },
    { uid: 'fake_5', displayName: 'Marie T.',  points:  9, exactScores: 1, goodResults: 6,  totalPredictions: 10 },
    { uid: 'fake_6', displayName: 'Romain C.', points:  6, exactScores: 0, goodResults: 6,  totalPredictions:  9 },
    { uid: 'fake_7', displayName: 'Lucie F.',  points:  3, exactScores: 1, goodResults: 0,  totalPredictions:  7 },
  ];

  const batch = db.batch();
  for (const d of fakeData) {
    batch.set(db.collection('prono_leaderboard').doc(d.uid), {
      ...d, season: '2025-2026', updatedAt: Timestamp.now(),
    });
  }
  await batch.commit();
  return { success: true, count: fakeData.length };
});

// ── Formate ISO 8601 duration → "mm:ss" ou "hh:mm:ss" ────────────────────────
function _formatDuration(iso) {
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return '';
  const h = parseInt(match[1] ?? 0);
  const m = parseInt(match[2] ?? 0);
  const s = parseInt(match[3] ?? 0);
  if (h > 0) return `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
  return `${m}:${String(s).padStart(2,'0')}`;
}
