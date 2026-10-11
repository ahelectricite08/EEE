const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall } = require('./lib/admin_auth');
const { _formatDuration, _durationSeconds } = require('./lib/format_utils');
const { normalizeTvCategory, loadEligibleCatalogIds } = require('./lib/tv_catalog');

const youtubeApiKeySecret = defineSecret('YOUTUBE_API_KEY');

/** Anti-spam double ouverture — quelques secondes, PAS 20 min. Chaque cold start doit checker. */
const TV_SYNC_COOLDOWN_MS = 8 * 1000;
const TV_SYNC_META_DOC = 'catalog_sync';
const TV_CONFIG_DOC = 'config';

const SYNC_CATEGORIES = new Set([
  'resume',
  'matchday',
  'podcast',
  'shorts',
  'partenaire',
  'dvcrfc',
  'club',
  'interview',
]);

/// Chaîne @drapeauvertcartonrouge — UCt5uHMCEz9w1BhE0D-ZerKg
/// Playlist Shorts YouTube (UUSH + id sans UC).
const INTERVIEW_PLAYLIST_ID = 'PLUbVPydzbIZM';
const DVCRFC_PLAYLIST_ID = 'PLeS7XcjX-dY0';

/// IDs confirmés (pages YouTube + Studio, format court).
const PLAYLISTS = [
  { id: 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD', category: 'resume' },
  { id: 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22', category: 'podcast' },
  { id: 'PLHZuIRHxEd8w_J7I_aEhtGc2MpLfINJVB', category: 'matchday' },
  { id: 'PLHZuIRHxEd8zKv-Z_Y-kg1_1S7u07Nw90', category: 'partenaire' },
  { id: 'UUSHt5uHMCEz9w1BhE0D-ZerKg', category: 'shorts' },
  { id: DVCRFC_PLAYLIST_ID, category: 'dvcrfc' },
  { id: INTERVIEW_PLAYLIST_ID, category: 'interview' },
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

function _youtubeThumbUrl(youtubeId, thumbnails) {
  if (youtubeId) {
    return `https://i.ytimg.com/vi/${youtubeId}/maxresdefault.jpg`;
  }
  return _pickYoutubeThumbnailUrl(thumbnails);
}

/** liveBroadcastContent + scheduledStartTime — même videos.list, pas d’appel extra. */
function _liveScheduleFields(detail) {
  const liveBroadcastContent = (detail?.snippet?.liveBroadcastContent || '').toString().trim();
  const iso = (detail?.liveStreamingDetails?.scheduledStartTime || '').toString().trim();
  const ms = iso ? Date.parse(iso) : NaN;
  const fields = {
    liveBroadcastContent: liveBroadcastContent || 'none',
  };
  if (iso) {
    fields.scheduledStartTime = iso;
  }
  if (Number.isFinite(ms) && ms > 0) {
    fields.scheduledStartTimeMs = ms;
  }
  return fields;
}

function _storedCategory(category) {
  return normalizeTvCategory(category) || category;
}

function _categoryAliases(category) {
  const stored = _storedCategory(category);
  if (stored === 'dvcrfc') return ['dvcrfc', 'club'];
  return [stored];
}

async function _docsForCategory(db, category) {
  const aliases = _categoryAliases(category);
  const snaps = await Promise.all(
    aliases.map((cat) => db.collection('videos').where('category', '==', cat).get()),
  );
  const docs = [];
  const seen = new Set();
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      docs.push(doc);
    }
  }
  return docs;
}

async function _youtubeGet(url) {
  const res = await fetch(url);
  const data = await res.json();
  if (data.error) {
    throw new Error(data.error.message || 'YouTube API error');
  }
  return data;
}

async function _resolvePlaylists(db) {
  const byCategory = new Map();
  for (const playlist of PLAYLISTS) {
    if (playlist.id) {
      byCategory.set(_storedCategory(playlist.category), {
        id: playlist.id,
        category: _storedCategory(playlist.category),
      });
    }
  }

  try {
    const snap = await db.collection('tv').doc(TV_CONFIG_DOC).get();
    const data = snap.exists ? snap.data() || {} : {};
    const fcId = (
      data.dvcrFcPlaylistId ||
      data.playlistDvcrFc ||
      data.dvcrfcPlaylistId ||
      ''
    ).toString().trim();
    if (fcId) {
      byCategory.set('dvcrfc', { id: fcId, category: 'dvcrfc' });
    }
    const interviewId = (
      data.interviewPlaylistId ||
      data.playlistInterview ||
      ''
    ).toString().trim();
    if (interviewId) {
      byCategory.set('interview', { id: interviewId, category: 'interview' });
    }

    const arr = data.youtubePlaylists;
    if (Array.isArray(arr)) {
      for (const item of arr) {
        const id = (item?.id || item?.playlistId || '').toString().trim();
        const category = _storedCategory(item?.category);
        if (!id || !SYNC_CATEGORIES.has(category)) continue;
        byCategory.set(category, { id, category });
      }
    }
  } catch (e) {
    console.warn('[youtube_sync] tv/config playlists', e.message);
  }

  return [...byCategory.values()];
}

async function _writePlaylistIdsToTvConfig(db) {
  await db.collection('tv').doc(TV_CONFIG_DOC).set(
    {
      interviewPlaylistId: INTERVIEW_PLAYLIST_ID,
      dvcrFcPlaylistId: DVCRFC_PLAYLIST_ID,
      youtubePlaylists: [
        { id: INTERVIEW_PLAYLIST_ID, category: 'interview' },
        { id: DVCRFC_PLAYLIST_ID, category: 'dvcrfc' },
      ],
      playlistsUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function _metaSyncedAtMs(data) {
  const raw = data?.lastSyncedAt;
  if (raw == null) return 0;
  if (typeof raw.toMillis === 'function') return raw.toMillis();
  if (typeof raw === 'number') return raw;
  if (typeof raw === 'object' && raw._seconds != null) {
    return Math.floor(raw._seconds * 1000 + (raw._nanoseconds || 0) / 1e6);
  }
  return 0;
}

async function _fetchPlaylistFingerprints(apiKey, playlistIds) {
  const unique = [...new Set(playlistIds.filter(Boolean))];
  const fingerprints = {};
  for (let i = 0; i < unique.length; i += 50) {
    const chunk = unique.slice(i, i + 50);
    const url =
      `https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails` +
      `&id=${chunk.join(',')}&maxResults=50&key=${apiKey}`;
    const data = await _youtubeGet(url);
    for (const item of data.items ?? []) {
      fingerprints[item.id] = {
        etag: item.etag || '',
        itemCount: item.contentDetails?.itemCount ?? 0,
        title: item.snippet?.title || '',
      };
    }
  }
  return fingerprints;
}

async function _fetchVideoPrivacy(apiKey, youtubeIds) {
  const unique = [...new Set(youtubeIds.filter(Boolean))];
  const statusMap = {};
  for (let i = 0; i < unique.length; i += 50) {
    const chunk = unique.slice(i, i + 50);
    const url =
      `https://www.googleapis.com/youtube/v3/videos?part=status` +
      `&id=${chunk.join(',')}&key=${apiKey}`;
    const data = await _youtubeGet(url);
    for (const item of data.items ?? []) {
      statusMap[item.id] = (item.status?.privacyStatus || '').toString();
    }
  }
  return statusMap;
}

async function _purgeNonPublicInCategory(db, category, apiKey) {
  const docs = await _docsForCategory(db, category);
  if (docs.length === 0) return [];
  const statusMap = await _fetchVideoPrivacy(
    apiKey,
    docs.map((doc) => doc.data().youtubeId),
  );
  const batch = db.batch();
  const removedIds = [];
  for (const doc of docs) {
    const youtubeId = doc.data().youtubeId;
    const privacy = statusMap[youtubeId];
    // Absent de videos.list = privé / supprimé. Unlisted aussi hors TV.
    if (privacy !== 'public') {
      batch.delete(doc.ref);
      if (youtubeId) removedIds.push(youtubeId);
      removedIds.push(doc.id);
    }
  }
  if (removedIds.length > 0) {
    await batch.commit();
    console.log(`[${category}] Purge non-public : ${removedIds.length}`);
  }
  return removedIds;
}

/**
 * Sync TV : GET léger (etag + itemCount) puis merge seulement si la playlist a changé.
 * Privacy sweep même si etag inchangé (privé/unlisted sans toucher le compteur).
 */
async function _syncPlaylistsFast(db, { forceAllPages = false, source = 'tv_app' } = {}) {
  await _writePlaylistIdsToTvConfig(db);
  const apiKey = _getYoutubeApiKey();
  const playlists = await _resolvePlaylists(db);
  const metaRef = db.collection('tv').doc(TV_SYNC_META_DOC);
  const metaSnap = await metaRef.get();
  const prev = metaSnap.exists ? metaSnap.data() || {} : {};
  const prevPlaylists = prev.playlists && typeof prev.playlists === 'object' ? prev.playlists : {};

  const fingerprints = await _fetchPlaylistFingerprints(
    apiKey,
    playlists.map((p) => p.id),
  );

  const results = [];
  const removedIds = [];
  for (const playlist of playlists) {
    if (!playlist.id) continue;
    const fp = fingerprints[playlist.id];
    const prevFp = prevPlaylists[playlist.id] || {};
    const unchanged =
      !forceAllPages &&
      !!fp &&
      !!prevFp.etag &&
      fp.etag === prevFp.etag &&
      Number(fp.itemCount) === Number(prevFp.itemCount);

    if (unchanged) {
      const purged = await _purgeNonPublicInCategory(db, playlist.category, apiKey);
      removedIds.push(...purged);
      results.push({
        id: playlist.id,
        category: playlist.category,
        skippedPages: true,
        purged: purged.length,
        itemCount: fp.itemCount,
      });
    } else {
      const synced = await _syncPlaylist(db, playlist.id, playlist.category);
      removedIds.push(...(synced.removedIds || []));
      results.push({
        id: playlist.id,
        category: playlist.category,
        skippedPages: false,
        purged: (synced.removedIds || []).length,
        itemCount: fp?.itemCount ?? null,
      });
    }
  }

  const playlistMeta = { ...prevPlaylists };
  for (const playlist of playlists) {
    if (!playlist.id) continue;
    const fp = fingerprints[playlist.id];
    if (fp) {
      playlistMeta[playlist.id] = {
        etag: fp.etag,
        itemCount: fp.itemCount,
        category: playlist.category,
        title: fp.title,
      };
    }
  }

  await metaRef.set(
    {
      lastSyncedAt: FieldValue.serverTimestamp(),
      source,
      playlists: playlistMeta,
    },
    { merge: true },
  );

  return { results, removedIds: [...new Set(removedIds)] };
}

// ── 2. Sync vidéos YouTube → Firestore (1× / jour, nuit Europe/Paris) ─────────
exports.syncYoutubeVideos = onSchedule(
  { schedule: '0 4 * * *', timeZone: 'Europe/Paris', secrets: [youtubeApiKeySecret] },
  async () => {
    const db = getFirestore();
    await _syncPlaylistsFast(db, { forceAllPages: true, source: 'cron' });
  }
);

// Sync manuelle déclenchable depuis l'admin web (admin only)
exports.syncYoutubeVideosManual = onCall(
  { cors: true, secrets: [youtubeApiKeySecret] },
  async (request) => {
  const { db } = await _requireAdminCall(request);
  await _syncPlaylistsFast(db, { forceAllPages: true, source: 'admin' });
    return { success: true };
  }
);

/**
 * Appelée par l’app Android TV au démarrage : check léger puis merge incremental.
 * Garde-fou quelques secondes (anti-spam), chaque cold start rafraîchit.
 */
exports.syncYoutubeVideosForTv = onRequest(
  {
    cors: true,
    region: 'europe-west1',
    timeoutSeconds: 300,
    memory: '512MiB',
    secrets: [youtubeApiKeySecret],
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.status(204).send('');
      return;
    }
    if (req.method !== 'GET' && req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    res.set('Access-Control-Allow-Origin', '*');
    const db = getFirestore();
    const force =
      (req.query.force || '').toString() === '1' ||
      req.body?.force === true;

    try {
      const metaRef = db.collection('tv').doc(TV_SYNC_META_DOC);
      const metaSnap = await metaRef.get();
      const lastMs = _metaSyncedAtMs(metaSnap.exists ? metaSnap.data() : null);
      const age = Date.now() - lastMs;
      if (!force && lastMs > 0 && age < TV_SYNC_COOLDOWN_MS) {
        const catalogIds = await loadEligibleCatalogIds(db);
        res.json({
          ok: true,
          skipped: true,
          reason: 'cooldown',
          ageMs: age,
          cooldownMs: TV_SYNC_COOLDOWN_MS,
          catalogIds,
          removedIds: [],
        });
        return;
      }

      const synced = await _syncPlaylistsFast(db, {
        forceAllPages: force,
        source: force ? 'tv_app_force' : 'tv_app',
      });
      const catalogIds = await loadEligibleCatalogIds(db);

      res.json({
        ok: true,
        skipped: false,
        synced: true,
        fast: !force,
        playlists: synced.results,
        catalogIds,
        removedIds: synced.removedIds,
      });
    } catch (e) {
      console.error('[syncYoutubeVideosForTv]', e);
      res.status(500).json({ error: e.message || 'sync error' });
    }
  },
);

function _isPublicYoutubeVideo(snippet, detail) {
  const title = (snippet?.title ?? '').toString().trim();
  if (!title || title === 'Private video' || title === 'Deleted video') {
    return false;
  }
  if (!detail) return false;
  const privacy = (detail.status?.privacyStatus || '').toString().trim().toLowerCase();
  return privacy === 'public';
}

// ── Sync une playlist complète ────────────────────────────────────────────────
async function _syncPlaylist(db, playlistId, category) {
  const youtubeApiKey = _getYoutubeApiKey();
  const storedCategory = _storedCategory(category);
  const playlistIds = new Set();
  let nextPageToken = null;

  do {
    const url = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=${playlistId}&maxResults=50${nextPageToken ? `&pageToken=${nextPageToken}` : ''}&key=${youtubeApiKey}`;
    const data = await _youtubeGet(url);

    const items = data.items ?? [];

    // Récupère les IDs pour la durée + privacy en batch
    const videoIds = items
      .map(i => i.snippet?.resourceId?.videoId)
      .filter(Boolean)
      .join(',');

    const detailsMap  = {};
    if (videoIds) {
      const detailsData = await _youtubeGet(
        `https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics,snippet,liveStreamingDetails,status&id=${videoIds}&key=${youtubeApiKey}`
      );
      for (const v of detailsData.items ?? []) {
        detailsMap[v.id] = v;
      }
    }

    for (const item of items) {
      const snippet   = item.snippet;
      const youtubeId = snippet?.resourceId?.videoId;
      if (!youtubeId) continue;

      const detail = detailsMap[youtubeId];
      // Skip privé / unlisted / supprimé — ne pas les ajouter à playlistIds → purge Firestore
      if (!_isPublicYoutubeVideo(snippet, detail)) continue;

      playlistIds.add(youtubeId);

      const existing = await db.collection('videos')
        .where('youtubeId', '==', youtubeId)
        .limit(1)
        .get();

      const isoDuration = detail?.contentDetails?.duration ?? '';
      const durationSeconds = _durationSeconds(isoDuration);
      const duration = _formatDuration(isoDuration);
      const isShort =
        storedCategory === 'shorts' || (durationSeconds > 0 && durationSeconds <= 60);
      const views = parseInt(detail?.statistics?.viewCount ?? '0', 10);
      const publishedAt = _parseYoutubePublishedAt(
        item?.contentDetails?.videoPublishedAt ??
        detail?.snippet?.publishedAt ??
        snippet?.publishedAt
      );
      const thumbnailUrl = _youtubeThumbUrl(
        youtubeId,
        detail?.snippet?.thumbnails ?? snippet?.thumbnails
      );

      const videoPayload = {
        youtubeId,
        title: snippet.title ?? '',
        duration,
        durationSeconds,
        isShort,
        views,
        thumbnailUrl,
        privacyStatus: 'public',
        sourcePlaylistId: playlistId,
        created_at: Timestamp.fromDate(publishedAt),
        ..._liveScheduleFields(detail),
      };
      if (storedCategory === 'shorts') {
        videoPayload.category = 'shorts';
        videoPayload.isShort = true;
      }

      if (existing.empty) {
        await db.collection('videos').add({
          ...videoPayload,
          category: storedCategory,
        });
      } else {
        await existing.docs[0].ref.set(videoPayload, { merge: true });
      }

      console.log(`[${storedCategory}] Ajouté : ${snippet.title}`);
    }

    nextPageToken = data.nextPageToken ?? null;
  } while (nextPageToken);

  if (playlistIds.size === 0) {
    console.warn(`[${storedCategory}] Playlist vide — pas de purge Firestore`);
    return { removedIds: [] };
  }

  // Supprime les vidéos de cette catégorie qui ne sont plus dans la playlist (ou plus publiques)
  const firestoreDocs = await _docsForCategory(db, storedCategory);
  const batch = db.batch();
  const removedIds = [];
  for (const doc of firestoreDocs) {
    if (!playlistIds.has(doc.data().youtubeId)) {
      batch.delete(doc.ref);
      const youtubeId = doc.data().youtubeId;
      if (youtubeId) removedIds.push(youtubeId);
      removedIds.push(doc.id);
    }
  }
  if (removedIds.length > 0) {
    await batch.commit();
    console.log(`[${storedCategory}] Supprimés (retirés de la playlist) : ${removedIds.length}`);
  }
  return { removedIds };
}
