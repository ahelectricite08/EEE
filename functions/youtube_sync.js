const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { _requireAdminCall } = require('./lib/admin_auth');
const { _formatDuration } = require('./lib/format_utils');

const youtubeApiKeySecret = defineSecret('YOUTUBE_API_KEY');

const PLAYLISTS = [
  { id: 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD', category: 'resume'     },
  { id: 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22', category: 'podcast'    },
  { id: 'PLHZuIRHxEd8w_J7I_aEhtGc2MpLfINJVB', category: 'matchday'   },
  { id: 'PLHZuIRHxEd8zKv-Z_Y-kg1_1S7u07Nw90', category: 'partenaire' },
];

function _getYoutubeApiKey() {
  const apiKey = youtubeApiKeySecret.value();
  if (!apiKey) {
    throw new Error('Le secret YOUTUBE_API_KEY est manquant');
  }
  return apiKey;
}

function _parseYoutubePublishedAt(rawValue) {
  const publishedAt = new Date(rawValue || Date.now());
  return Number.isNaN(publishedAt.getTime()) ? new Date() : publishedAt;
}

function _pickYoutubeThumbnailUrl(thumbnails) {
  if (!thumbnails || typeof thumbnails !== 'object') {
    return '';
  }
  return (
    thumbnails?.maxres?.url ||
    thumbnails?.standard?.url ||
    thumbnails?.high?.url ||
    thumbnails?.medium?.url ||
    thumbnails?.default?.url ||
    ''
  );
}

// ── 2. Sync vidéos YouTube → Firestore (1× / jour, nuit Europe/Paris) ─────────
exports.syncYoutubeVideos = onSchedule(
  { schedule: '0 4 * * *', timeZone: 'Europe/Paris', secrets: [youtubeApiKeySecret] },
  async () => {
    const db = getFirestore();
    for (const playlist of PLAYLISTS) {
      await _syncPlaylist(db, playlist.id, playlist.category);
    }
  }
);

// Sync manuelle déclenchable depuis l'admin web (admin only)
exports.syncYoutubeVideosManual = onCall(
  { cors: true, secrets: [youtubeApiKeySecret] },
  async (request) => {
  const { db } = await _requireAdminCall(request);
  for (const playlist of PLAYLISTS) {
    await _syncPlaylist(db, playlist.id, playlist.category);
  }
    return { success: true };
  }
);

// ── Sync une playlist complète ────────────────────────────────────────────────
async function _syncPlaylist(db, playlistId, category) {
  const youtubeApiKey = _getYoutubeApiKey();
  const playlistIds = new Set();
  let nextPageToken = null;

  do {
    const url = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=${playlistId}&maxResults=50${nextPageToken ? `&pageToken=${nextPageToken}` : ''}&key=${youtubeApiKey}`;
    const res  = await fetch(url);
    const data = await res.json();

    const items = data.items ?? [];

    // Récupère les IDs pour la durée en batch
    const videoIds = items
      .map(i => i.snippet?.resourceId?.videoId)
      .filter(Boolean)
      .join(',');

    const detailsMap  = {};
    if (videoIds) {
      const detailsRes = await fetch(
        `https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics,snippet&id=${videoIds}&key=${youtubeApiKey}`
      );
      const detailsData = await detailsRes.json();
      for (const v of detailsData.items ?? []) {
        detailsMap[v.id] = v;
      }
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

      const detail = detailsMap[youtubeId];
      const duration = _formatDuration(detail?.contentDetails?.duration ?? '');
      const views = parseInt(detail?.statistics?.viewCount ?? '0', 10);
      const publishedAt = _parseYoutubePublishedAt(
        item?.contentDetails?.videoPublishedAt ??
        detail?.snippet?.publishedAt ??
        snippet?.publishedAt
      );
      const thumbnailUrl = _pickYoutubeThumbnailUrl(
        detail?.snippet?.thumbnails ??
        snippet?.thumbnails
      );

      const videoPayload = {
        youtubeId,
        title: snippet.title ?? '',
        duration,
        views,
        thumbnailUrl,
        created_at: Timestamp.fromDate(publishedAt),
      };

      if (existing.empty) {
        await db.collection('videos').add({
          ...videoPayload,
          category,
        });
      } else {
        await existing.docs[0].ref.set(videoPayload, { merge: true });
      }

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
