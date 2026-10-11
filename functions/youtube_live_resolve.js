const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');

const youtubeApiKeySecret = defineSecret('YOUTUBE_API_KEY');

/** Chaîne @drapeauvertcartonrouge */
const CHANNEL_ID = 'UCt5uHMCEz9w1BhE0D-ZerKg';
const MAX_ATTEMPTS = 6;
const RETRY_DELAY_MS = 25_000;

function _sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function _extractVideoIdFromUrl(url) {
  if (!url) return '';
  try {
    const u = new URL(url);
    const v = u.searchParams.get('v');
    if (v) return v.trim();
    const m = u.pathname.match(/\/(live|watch|embed|shorts)\/([a-zA-Z0-9_-]{11})/);
    if (m) return m[2];
  } catch (_) {}
  const match = String(url).match(/[?&]v=([a-zA-Z0-9_-]{11})/);
  return match ? match[1] : '';
}

function _extractVideoIdFromHtml(html) {
  if (!html) return '';
  const patterns = [
    /"videoId":"([a-zA-Z0-9_-]{11})"/,
    /"video_id":"([a-zA-Z0-9_-]{11})"/,
    /watch\?v=([a-zA-Z0-9_-]{11})/,
  ];
  const isLive =
    html.includes('"isLiveNow":true') ||
    html.includes('"isLive":true') ||
    html.includes('"LIVE_STREAM_OFFLINE":false');
  for (const re of patterns) {
    const m = html.match(re);
    if (m && isLive) return m[1];
  }
  // Redirect pages often land on watch URL without strong isLive markers
  for (const re of patterns) {
    const m = html.match(re);
    if (m && (html.includes('isLiveNow') || html.includes('LIVE'))) return m[1];
  }
  return '';
}

async function _scrapeChannelLive() {
  const url = `https://www.youtube.com/channel/${CHANNEL_ID}/live`;
  const res = await fetch(url, {
    redirect: 'follow',
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
    },
  });
  const finalUrl = res.url || '';
  const fromUrl = _extractVideoIdFromUrl(finalUrl);
  const html = await res.text();
  if (fromUrl && !html.includes('LIVE_STREAM_OFFLINE')) {
    // /channel/.../live that did not redirect usually means offline
    if (!finalUrl.includes('/channel/') || finalUrl.includes('watch')) {
      return { videoId: fromUrl, title: '', source: 'redirect' };
    }
  }
  const fromHtml = _extractVideoIdFromHtml(html);
  if (fromHtml) {
    let title = '';
    const titleMatch = html.match(/"title":\{"runs":\[\{"text":"([^"]+)"\}/);
    if (titleMatch) title = titleMatch[1];
    return { videoId: fromHtml, title, source: 'html' };
  }
  return null;
}

async function _searchLiveViaApi(apiKey) {
  if (!apiKey) return null;
  const url =
    `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${CHANNEL_ID}` +
    `&eventType=live&type=video&maxResults=1&key=${apiKey}`;
  const res = await fetch(url);
  const data = await res.json();
  if (data.error) {
    console.warn('[resolveYoutubeLive] API:', data.error.message);
    return null;
  }
  const item = data.items?.[0];
  if (!item?.id?.videoId) return null;
  return {
    videoId: item.id.videoId,
    title: item.snippet?.title || '',
    source: 'api',
  };
}

/**
 * Cherche le live YouTube de la chaîne (jusqu’à 6 essais).
 * @returns {{ videoId: string, title: string, source: string } | null}
 */
async function resolveYoutubeLiveWithRetries(apiKey) {
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    console.log(`[resolveYoutubeLive] essai ${attempt}/${MAX_ATTEMPTS}`);
    try {
      let found = await _scrapeChannelLive();
      if (!found && attempt === MAX_ATTEMPTS) {
        found = await _searchLiveViaApi(apiKey);
      } else if (!found && attempt >= 3) {
        found = await _searchLiveViaApi(apiKey);
      }
      if (found?.videoId) {
        console.log(`[resolveYoutubeLive] trouvé ${found.videoId} via ${found.source}`);
        return found;
      }
    } catch (e) {
      console.warn(`[resolveYoutubeLive] essai ${attempt} erreur:`, e.message || e);
    }
    if (attempt < MAX_ATTEMPTS) {
      await _sleep(RETRY_DELAY_MS);
    }
  }
  return null;
}

/**
 * Au lancement du live (Admin Direct → live/current créé) :
 * cherche l’URL YouTube live 4–6 fois puis stop.
 */
exports.resolveYoutubeLiveOnStart = onDocumentCreated(
  {
    document: 'live/current',
    region: 'europe-west1',
    timeoutSeconds: 200,
    memory: '512MiB',
    secrets: [youtubeApiKeySecret],
  },
  async (event) => {
    const snap = event.data;
    if (!snap?.exists) return;

    const db = getFirestore();
    const ref = snap.ref;
    const existingId = (snap.data()?.youtubeLiveVideoId || '').toString().trim();
    if (existingId) {
      console.log('[resolveYoutubeLive] déjà résolu:', existingId);
      return;
    }

    await ref.set(
      {
        youtubeLiveResolveStatus: 'searching',
        youtubeLiveResolveAttemptedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    let apiKey = '';
    try {
      apiKey = youtubeApiKeySecret.value();
    } catch (_) {}

    const found = await resolveYoutubeLiveWithRetries(apiKey);

    // Doc peut avoir été supprimé (fin de live) pendant la recherche
    const still = await ref.get();
    if (!still.exists) {
      console.log('[resolveYoutubeLive] live/current disparu — abandon');
      return;
    }

    if (found?.videoId) {
      await ref.set(
        {
          youtubeLiveVideoId: found.videoId,
          youtubeLiveTitle: found.title || '',
          youtubeLiveResolvedAt: FieldValue.serverTimestamp(),
          youtubeLiveResolveStatus: 'ok',
          youtubeLiveResolveFailed: false,
        },
        { merge: true },
      );
      return;
    }

    await ref.set(
      {
        youtubeLiveResolveStatus: 'failed',
        youtubeLiveResolveFailed: true,
        youtubeLiveResolvedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.warn('[resolveYoutubeLive] introuvable après', MAX_ATTEMPTS, 'essais');
  },
);
