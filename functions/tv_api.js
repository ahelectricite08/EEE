const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _requireAdminCall, _isUserAdmin, _toSafeString } = require('./lib/admin_auth');
const { isTvCatalogVideo, loadEligibleCatalogIds } = require('./lib/tv_catalog');

// ── Android TV — espace Firestore dédié `tv/` (ne pas mélanger avec app_config) ─
const TV_CONFIG_DOC = 'config';

function _scheduledStartTimeMs(v) {
  if (typeof v.scheduledStartTimeMs === 'number' && v.scheduledStartTimeMs > 0) {
    return v.scheduledStartTimeMs;
  }
  const iso = (v.scheduledStartTime || '').toString().trim();
  if (!iso) return 0;
  const ms = Date.parse(iso);
  return Number.isFinite(ms) && ms > 0 ? ms : 0;
}

function _videoForTv(doc, overrides = {}) {
  const v = doc.data() || {};
  const scheduledStartTime = (v.scheduledStartTime || '').toString().trim();
  const scheduledStartTimeMs = _scheduledStartTimeMs(v);
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
    privacyStatus: (v.privacyStatus || '').toString().trim(),
    liveBroadcastContent: (v.liveBroadcastContent || '').toString().trim(),
    scheduledStartTime,
    scheduledStartTimeMs,
    ...overrides,
  };
}

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

function _isSedanCssaMatch(m) {
  const t1 = String(m?.team1 || '').toUpperCase();
  const t2 = String(m?.team2 || '').toUpperCase();
  return (
    t1.includes('SEDAN') ||
    t1.includes('CSSA') ||
    t2.includes('SEDAN') ||
    t2.includes('CSSA')
  );
}

const _FR_DAYS = [
  'Dimanche',
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
];
const _FR_MONTHS = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/** Même règle que l’accueil mobile : prochain match Sedan / CSSA à venir. */
async function _loadNextSedanMatch(db) {
  const now = Timestamp.now();
  const snap = await db
    .collection('matches')
    .where('status', '==', 'upcoming')
    .where('date', '>', now)
    .orderBy('date')
    .limit(40)
    .get();

  for (const doc of snap.docs) {
    const m = doc.data() || {};
    if (!_isSedanCssaMatch(m)) continue;
    const kickMs =
      typeof m.date?.toMillis === 'function' ? m.date.toMillis() : null;
    if (!kickMs || kickMs <= Date.now()) continue;

    const d = new Date(kickMs);
    // Affichage Europe/Paris
    const parts = new Intl.DateTimeFormat('fr-FR', {
      timeZone: 'Europe/Paris',
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).formatToParts(d);
    const get = (type) =>
      (parts.find((p) => p.type === type)?.value || '').toString();
    const weekdayRaw = get('weekday');
    const dayNum = get('day');
    const monthRaw = get('month');
    const hour = get('hour');
    const minute = get('minute');
    const day =
      weekdayRaw.charAt(0).toUpperCase() + weekdayRaw.slice(1).toLowerCase();
    const date = `${dayNum} ${monthRaw}`.trim();
    const time =
      hour && minute ? `${hour}H${minute}` : hour ? `${hour}H00` : '';

    const team1 = _toSafeString(m.team1);
    const team2 = _toSafeString(m.team2);
    const imageUrl = _toSafeString(
      m.stadiumImageUrl || m.imageUrl || m.posterUrl || '',
    );

    return {
      imageUrl,
      day,
      date,
      time,
      team1,
      team2,
      enabled: true,
      matchup: team1 && team2 ? `${team1} — ${team2}` : '',
      scheduledAt: kickMs,
      matchId: doc.id,
      source: 'matches',
    };
  }
  return null;
}

function _buildNextLiveFromConfig(tv) {
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
    source: 'tv/config',
  };
  if (scheduledAt) out.scheduledAt = scheduledAt;
  return out;
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

const NEWS_PAGE_SIZE = 100;
const NEWS_MAX_ARTICLES = 800;
const NEWS_BODY_MAX = 12000;
const NEWS_HTML_SLICE = 40000;

function _articleTsMillis(raw) {
  if (raw == null) return 0;
  if (typeof raw.toMillis === 'function') return raw.toMillis();
  if (typeof raw === 'number' && Number.isFinite(raw) && raw > 0) return raw;
  if (typeof raw === 'object' && raw._seconds != null) {
    return Math.floor(raw._seconds * 1000 + (raw._nanoseconds || 0) / 1e6);
  }
  return 0;
}

function _htmlLooksLikeSiteHome(html) {
  const h = String(html || '');
  const matches = h.match(/href\s*=\s*['"][^'"]*\/post\//gi);
  return (matches || []).length >= 4;
}

/** Texte lisible TV : pas de HTML Wix brut (payload trop lourd). */
function _plainText(html, maxLen) {
  let t = String(html || '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/h[1-6]>/gi, '\n\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\r\n/g, '\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
  if (maxLen && t.length > maxLen) {
    t = `${t.slice(0, maxLen).trimEnd()}…`;
  }
  return t;
}

/** Wix sert souvent de l’AVIF que Coil / Android TV ne décode pas. */
function _wixImageUrl(url) {
  let s = String(url || '').trim();
  if (!s) return '';
  if (s.startsWith('//')) s = `https:${s}`;
  if (s.toLowerCase().includes('enc_avif')) {
    s = s.replace(/,blur_\d+/g, '');
    s = s.replace(/,enc_avif,quality_auto/gi, '');
    s = s.replace(/,enc_avif/gi, '');
  }
  return s;
}

function _mapArticleForTv(doc) {
  const d = doc.data() || {};
  const rawHtml = (d.contentHtml || '').toString();
  const rawContent = (d.content || '').toString();
  const excerptRaw = (d.excerpt || '').toString().trim();
  const htmlUsable = rawHtml.length > 0 && !_htmlLooksLikeSiteHome(rawHtml);
  const bodySource = htmlUsable && rawHtml.length >= rawContent.length
    ? rawHtml.slice(0, NEWS_HTML_SLICE)
    : (rawContent || (htmlUsable ? rawHtml.slice(0, NEWS_HTML_SLICE) : ''));
  const body = _plainText(bodySource, NEWS_BODY_MAX);
  const excerpt = excerptRaw.length >= 24
    ? excerptRaw
    : _plainText(bodySource, 220);
  const images = Array.isArray(d.images)
    ? d.images.map((u) => _wixImageUrl(u)).filter(Boolean)
    : [];
  const imageUrl = _wixImageUrl(d.imageUrl || images[0] || '');
  return {
    id: doc.id,
    title: (d.title || '').toString(),
    excerpt,
    body,
    imageUrl,
    category: (d.category || 'ACTUS').toString(),
    featured: d.featured === true,
    authorName: (d.authorName || '').toString(),
    createdAt: _articleTsMillis(d.created_at) || _articleTsMillis(d.updated_at),
  };
}

/** Tous les articles publiés (même collection que l’app mobile). */
async function _loadPublishedArticlesForTv(db) {
  const articles = [];
  let lastDoc = null;
  while (articles.length < NEWS_MAX_ARTICLES) {
    let q = db
      .collection('articles')
      .where('status', '==', 'published')
      .orderBy('created_at', 'desc')
      .limit(NEWS_PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      const mapped = _mapArticleForTv(doc);
      if (!mapped.title.trim()) continue;
      articles.push(mapped);
      if (articles.length >= NEWS_MAX_ARTICLES) break;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < NEWS_PAGE_SIZE) break;
  }
  return articles;
}

exports.tvApi = onRequest({ cors: true, region: 'europe-west1', memory: '512MiB', timeoutSeconds: 120 }, async (req, res) => {
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

    // scope=news : un seul round-trip Firestore, hors catalogue vidéos / live.
    if (scope === 'news') {
      const articles = await _loadPublishedArticlesForTv(db);
      res.json({
        articles,
        newsMode: 'full',
        newsSyncedAt: Date.now(),
        count: articles.length,
        source: 'articles',
      });
      return;
    }

    const [tvLoaded, liveSnap, nextSedan] = await Promise.all([
      _loadTvConfig(db),
      db.collection('live').doc('current').get(),
      _loadNextSedanMatch(db),
    ]);

    const tv = tvLoaded.data;
    const live = liveSnap.exists ? liveSnap.data() : null;
    const team1 = (live?.team1 ?? '').toString().trim();
    const team2 = (live?.team2 ?? '').toString().trim();
    // Priorité = calendrier Sedan (comme accueil mobile) ; secours = tv/config admin
    const nextLive = nextSedan || _buildNextLiveFromConfig(tv);
    const youtubeLiveVideoId = (live?.youtubeLiveVideoId ?? '').toString().trim();
    const youtubeLiveTitle = (live?.youtubeLiveTitle ?? '').toString().trim();
    const youtubeLiveResolveStatus = (live?.youtubeLiveResolveStatus ?? '').toString().trim();
    const youtubeLiveResolveFailed = live?.youtubeLiveResolveFailed === true;
    const liveTitle =
      youtubeLiveTitle ||
      (team1 && team2
        ? `${team1} — ${team2}`
        : (nextLive?.matchup || '').trim() || (live?.url ?? 'En direct'));

    let catalogMode = 'skipped';
    let videos = [];
    let featuredVideo = null;
    let catalogIds = [];

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
        .map((doc) => _videoForTv(doc))
        .filter((v) => isTvCatalogVideo(v));

      const featuredId = (tv.featuredVideoId ?? '').toString().trim();
      if (featuredId) {
        featuredVideo = videos.find((v) => v.id === featuredId) ?? null;
        if (!featuredVideo && catalogMode === 'full') {
          const featSnap = await db.collection('videos').doc(featuredId).get();
          if (featSnap.exists) {
            const candidate = _videoForTv(featSnap, { featured: true });
            if (isTvCatalogVideo(candidate)) {
              featuredVideo = candidate;
            }
          }
        }
      }
      if (!featuredVideo && catalogMode === 'full') {
        featuredVideo = videos.find((v) => v.featured) ?? null;
      }
      if (featuredVideo && !isTvCatalogVideo(featuredVideo)) {
        featuredVideo = null;
      }

      catalogIds = await loadEligibleCatalogIds(db);
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
      youtubeLiveVideoId,
      youtubeLiveResolveStatus,
      youtubeLiveResolveFailed,
      videos,
      featuredVideo,
      nextLive,
      catalogMode,
      catalogSyncedAt,
      catalogIds,
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
        youtubeLiveVideoId,
        resolveStatus: youtubeLiveResolveStatus,
        resolveFailed: youtubeLiveResolveFailed,
      },
      catalog: {
        source: 'videos',
        mode: catalogMode,
        count: videos.length,
        totalFetched: videos.length,
        catalogIds,
        byCategory: {
          resume: videos.filter((v) => v.category === 'resume').length,
          matchday: videos.filter((v) => v.category === 'matchday').length,
          podcast: videos.filter((v) => v.category === 'podcast').length,
          dvcrfc: videos.filter((v) => v.category === 'dvcrfc' || v.category === 'club').length,
          interview: videos.filter((v) => v.category === 'interview').length,
          shorts: videos.filter((v) => v.category === 'shorts' || v.isShort).length,
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
