const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _isUserAdmin, _toSafeString } = require('./lib/admin_auth');

// ── Android TV — espace Firestore dédié `tv/` (ne pas mélanger avec app_config) ─
const TV_CONFIG_DOC = 'config';

/** Annonce prochain live (écran TV hors direct) depuis tv/config. */
function _nextLiveScheduledAtMs(tv) {
  const raw = tv.nextLiveAt;
  if (raw == null) return null;
  if (typeof raw.toMillis === 'function') return raw.toMillis();
  if (typeof raw === 'number' && raw > 0) return raw;
  if (typeof raw === 'object' && raw._seconds != null) {
    return Math.floor(raw._seconds * 1000 + (raw._nanoseconds || 0) / 1e6);
  }
  return null;
}

function _buildNextLive(tv) {
  if (tv.nextLiveEnabled === false) return null;
  const team1 = _toSafeString(tv.nextLiveTeam1);
  const team2 = _toSafeString(tv.nextLiveTeam2);
  const day = _toSafeString(tv.nextLiveDay);
  const date = _toSafeString(tv.nextLiveDate);
  const time = _toSafeString(tv.nextLiveTime);
  const imageUrl = _toSafeString(tv.nextLiveImageUrl);
  const scheduledAt = _nextLiveScheduledAtMs(tv);
  const hasContent =
    (team1 && team2) || day || date || time || scheduledAt;
  if (!hasContent) return null;
  const out = {
    imageUrl,
    day,
    date,
    time,
    team1,
    team2,
    enabled: true,
    matchup: team1 && team2 ? `${team1} — ${team2}` : '',
  };
  if (scheduledAt) out.scheduledAt = scheduledAt;
  return out;
}

/** Exclure contenus partenaires du catalogue Android TV. */
function _isPartnerVideo(v) {
  const cat = (v.category ?? '').toString().toLowerCase();
  if (cat === 'partenaire') return true;
  const title = (v.title ?? '').toString().toLowerCase();
  return title.includes('partenaire');
}

/** Lit tv/config ; repli sur app_config/tv (ancien emplacement) si besoin. */
async function _loadTvConfig(db) {
  const tvSnap = await db.collection('tv').doc(TV_CONFIG_DOC).get();
  if (tvSnap.exists) {
    return { data: tvSnap.data() || {}, source: 'tv/config' };
  }
  const legacySnap = await db.collection('app_config').doc('tv').get();
  if (legacySnap.exists) {
    return { data: legacySnap.data() || {}, source: 'app_config/tv' };
  }
  return { data: {}, source: null };
}

exports.tvApi = onRequest({ cors: true, region: 'europe-west1' }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');
  const db = getFirestore();

  try {
    const scope = (req.query.scope || '').toString().trim().toLowerCase();
    const sinceRaw = (req.query.since || '').toString().trim();
    const sinceMs = Number(sinceRaw);
    const loadCatalog = scope !== 'status';

    const [tvLoaded, liveSnap] = await Promise.all([
      _loadTvConfig(db),
      db.collection('live').doc('current').get(),
    ]);

    const tv = tvLoaded.data;
    const live = liveSnap.exists ? liveSnap.data() : null;
    const team1 = (live?.team1 ?? '').toString().trim();
    const team2 = (live?.team2 ?? '').toString().trim();
    const nextLive = _buildNextLive(tv);
    const liveTitle =
      team1 && team2
        ? `${team1} — ${team2}`
        : (nextLive?.matchup || '').trim() || (live?.url ?? 'En direct');

    let catalogMode = 'skipped';
    let videos = [];
    let featuredVideo = null;

    if (loadCatalog) {
      let videosSnap;
      if (sinceMs > 0 && Number.isFinite(sinceMs)) {
        catalogMode = 'incremental';
        videosSnap = await db
          .collection('videos')
          .where('created_at', '>', Timestamp.fromMillis(sinceMs))
          .orderBy('created_at', 'desc')
          .limit(50)
          .get();
      } else {
        catalogMode = 'full';
        videosSnap = await db
          .collection('videos')
          .orderBy('created_at', 'desc')
          .limit(150)
          .get();
      }

      videos = videosSnap.docs
        .map((doc) => {
          const v = doc.data();
          return {
            id: doc.id,
            youtubeId: v.youtubeId ?? '',
            title: v.title ?? '',
            thumbnailUrl: v.thumbnailUrl ?? '',
            category: v.category ?? '',
            duration: v.duration ?? '',
            featured: v.featured === true,
            isShort: v.isShort === true || v.category === 'shorts',
            hidden: v.hidden === true,
          };
        })
        .filter((v) => !_isPartnerVideo(v) && v.hidden !== true);

      const featuredId = (tv.featuredVideoId ?? '').toString().trim();
      if (featuredId) {
        featuredVideo = videos.find((v) => v.id === featuredId) ?? null;
        if (!featuredVideo && catalogMode === 'full') {
          const featSnap = await db.collection('videos').doc(featuredId).get();
          if (featSnap.exists) {
            const v = featSnap.data() || {};
            const candidate = {
              id: featSnap.id,
              youtubeId: v.youtubeId ?? '',
              title: v.title ?? '',
              thumbnailUrl: v.thumbnailUrl ?? '',
              category: v.category ?? '',
              duration: v.duration ?? '',
              featured: true,
            };
            if (!_isPartnerVideo(candidate)) {
              featuredVideo = candidate;
            }
          }
        }
      }
      if (!featuredVideo && catalogMode === 'full') {
        featuredVideo = videos.find((v) => v.featured) ?? null;
      }
      if (featuredVideo && _isPartnerVideo(featuredVideo)) {
        featuredVideo = null;
      }
    }

    const catalogSyncedAt = Date.now();

    const streamPlaybackUrl = (tv.streamPlaybackUrl ?? '').toString().trim();
    const tvEnabled = tv.enabled !== false;
    const liveViewers = 0;

    res.json({
      // Champs plats (app Android TV)
      streamPlaybackUrl,
      tvEnabled,
      isLive: liveSnap.exists,
      liveTitle,
      liveViewers,
      videos,
      featuredVideo,
      nextLive,
      catalogMode,
      catalogSyncedAt,
      updatedAt: new Date().toISOString(),
      // Contrat structuré — séparation TV / live partagé / catalogue vidéos
      tv: {
        streamPlaybackUrl,
        enabled: tvEnabled,
        configSource: tvLoaded.source,
      },
      live: {
        isLive: liveSnap.exists,
        title: liveTitle,
        matchId: (live?.matchId ?? '').toString(),
        viewers: liveViewers,
      },
      catalog: {
        source: 'videos',
        mode: catalogMode,
        count: videos.length,
        totalFetched: videos.length,
        byCategory: {
          resume: videos.filter((v) => v.category === 'resume').length,
          matchday: videos.filter((v) => v.category === 'matchday').length,
          podcast: videos.filter((v) => v.category === 'podcast').length,
          shorts: videos.filter((v) => v.category === 'shorts' || v.isShort).length,
          other: videos.filter(
            (v) =>
              !['resume', 'matchday', 'podcast', 'partenaire', 'shorts'].includes(
                v.category,
              ),
          ).length,
        },
      },
    });
  } catch (e) {
    console.error('[tvApi]', e);
    res.status(500).json({ error: e.message || 'tvApi error' });
  }
});

/** Admin : enregistrer l'URL HLS de lecture TV (MediaMTX / VPS). */
exports.setTvStreamConfig = onCall({ cors: true, region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const streamPlaybackUrl = (request.data?.streamPlaybackUrl ?? '').toString().trim();
  const enabled = request.data?.enabled !== false;
  const note = (request.data?.note ?? '').toString().trim();

  if (!streamPlaybackUrl) {
    throw new HttpsError('invalid-argument', 'streamPlaybackUrl requis');
  }

  const payload = {
    streamPlaybackUrl,
    enabled,
    note,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  };

  await db.collection('tv').doc(TV_CONFIG_DOC).set(payload, { merge: true });

  return { ok: true, streamPlaybackUrl, enabled, path: 'tv/config' };
});
