const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _toSafeString } = require('./lib/admin_auth');
const { APP_BRAND_NAME } = require('./lib/app_brand');

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

/** Spectateurs actifs sur le direct (TTL 90 s, heartbeat app TV / mobile). */
/** Doit dépasser l’intervalle heartbeat TV (5 min) + marge. */
const LIVE_PRESENCE_TTL_MS = 360_000;

function _parisHourKey(date = new Date()) {
  return date
    .toLocaleString('sv-SE', { timeZone: 'Europe/Paris', hour12: false })
    .slice(0, 13)
    .replace(' ', 'T');
}

async function _clearAllLivePresence(db) {
  const snap = await db.collection('live_presence').get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function _recordLiveViewerMetrics(db, viewerCount, viewerId, platform) {
  const liveSnap = await db.collection('live').doc('current').get();
  if (!liveSnap.exists) return;
  const sessionId = (liveSnap.data()?.statsSessionId ?? '').toString();
  if (!sessionId) return;

  const sessionRef = db.collection('live_stats_sessions').doc(sessionId);
  const hourKey = _parisHourKey();

  await db.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) return;
    const data = sessionSnap.data() || {};
    const peak = Math.max(Number(data.peakViewers ?? 0), viewerCount);
    const byHour = { ...(data.viewersByHour || {}) };
    byHour[hourKey] = Math.max(Number(byHour[hourKey] ?? 0), viewerCount);

    let samples = Array.isArray(data.samples) ? [...data.samples] : [];
    const now = Timestamp.now();
    const lastAt = data.lastSampleAt;
    const lastMs = lastAt && typeof lastAt.toMillis === 'function' ? lastAt.toMillis() : 0;
    const shouldSample = !lastMs || now.toMillis() - lastMs >= 60_000;
    if (shouldSample) {
      samples.push({ at: now, viewers: viewerCount });
      if (samples.length > 180) samples = samples.slice(-180);
    }

    tx.update(sessionRef, {
      peakViewers: peak,
      viewersByHour: byHour,
      samples,
      lastSampleAt: shouldSample ? now : (data.lastSampleAt || now),
      lastViewerCount: viewerCount,
    });
  });

  if (viewerId) {
    await sessionRef
      .collection('unique_viewers')
      .doc(viewerId)
      .set(
        {
          platform: (platform || 'other').toString().slice(0, 32),
          lastSeen: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }
}

async function _finalizeLiveStatsSession(db, sessionId, liveData) {
  const sessionRef = db.collection('live_stats_sessions').doc(sessionId);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) return;

  const uniqueSnap = await sessionRef.collection('unique_viewers').get();
  const platformTotals = { tv: 0, mobile: 0, other: 0 };
  uniqueSnap.forEach((d) => {
    const p = (d.data().platform || 'other').toString();
    if (p === 'tv') platformTotals.tv += 1;
    else if (p === 'mobile') platformTotals.mobile += 1;
    else platformTotals.other += 1;
  });

  const data = sessionSnap.data() || {};
  const samples = Array.isArray(data.samples) ? data.samples : [];
  let averageViewers = 0;
  if (samples.length) {
    const sum = samples.reduce((acc, s) => acc + (Number(s.viewers) || 0), 0);
    averageViewers = Math.round(sum / samples.length);
  }

  const startedAt = data.startedAt;
  const endedAt = Timestamp.now();
  let durationMinutes = 0;
  if (startedAt && typeof startedAt.toMillis === 'function') {
    durationMinutes = Math.max(
      0,
      Math.round((endedAt.toMillis() - startedAt.toMillis()) / 60_000),
    );
  }

  const team1 = (liveData?.team1 ?? data.team1 ?? '').toString();
  const team2 = (liveData?.team2 ?? data.team2 ?? '').toString();
  const title =
    [team1, team2].filter(Boolean).join(' — ') ||
    (data.title ?? '').toString() ||
    `Direct ${APP_BRAND_NAME}`;

  await sessionRef.set(
    {
      status: 'ended',
      endedAt,
      durationMinutes,
      uniqueViewerCount: uniqueSnap.size,
      platformTotals,
      averageViewers,
      peakViewers: Math.max(Number(data.peakViewers ?? 0), Number(liveData?.viewers ?? 0)),
      team1,
      team2,
      title,
      matchId: (liveData?.matchId ?? data.matchId ?? '').toString(),
      recapReady: true,
    },
    { merge: true },
  );

  await _clearAllLivePresence(db);
}

async function _countActiveLivePresence(db) {
  const snap = await db.collection('live_presence').get();
  const now = Date.now();
  let count = 0;
  snap.forEach((doc) => {
    const lastSeen = doc.data().lastSeen;
    const ms = lastSeen && typeof lastSeen.toMillis === 'function' ? lastSeen.toMillis() : 0;
    if (ms > 0 && now - ms < LIVE_PRESENCE_TTL_MS) count += 1;
  });
  return count;
}

function _tvCorsPreflight(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

/** Heartbeat / départ spectateur (app TV sans auth Firebase). */
exports.tvLiveHeartbeat = onRequest({ cors: true, region: 'europe-west1' }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    _tvCorsPreflight(res);
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  _tvCorsPreflight(res);
  const db = getFirestore();

  try {
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const viewerId = (body.viewerId || req.query.viewerId || '').toString().trim();
    if (!viewerId || viewerId.length > 128) {
      res.status(400).json({ error: 'viewerId requis' });
      return;
    }

    const platform = (body.platform || 'tv').toString().slice(0, 32);
    const ref = db.collection('live_presence').doc(viewerId);

    if (body.action === 'leave') {
      await ref.delete().catch(() => {});
    } else {
      await ref.set(
        {
          lastSeen: FieldValue.serverTimestamp(),
          platform,
        },
        { merge: true },
      );
    }

    const liveSnap = await db.collection('live').doc('current').get();
    const viewers = liveSnap.exists ? await _countActiveLivePresence(db) : 0;

    if (liveSnap.exists) {
      await db.collection('live').doc('current').set(
        { viewers, viewersUpdatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      if (body.action !== 'leave') {
        await _recordLiveViewerMetrics(db, viewers, viewerId, platform);
      }
    }

    res.json({ viewers, isLive: liveSnap.exists });
  } catch (e) {
    console.error('[tvLiveHeartbeat]', e);
    res.status(500).json({ error: e.message || 'tvLiveHeartbeat error' });
  }
});

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
          };
        })
        .filter((v) => !_isPartnerVideo(v));

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
    const liveViewers = liveSnap.exists
      ? await _countActiveLivePresence(db)
      : 0;

    if (liveSnap.exists) {
      await db.collection('live').doc('current').set(
        { viewers: liveViewers, viewersUpdatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      await _recordLiveViewerMetrics(db, liveViewers, null, null);
    }

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
          other: videos.filter(
            (v) => !['resume', 'matchday', 'podcast', 'partenaire'].includes(v.category),
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
