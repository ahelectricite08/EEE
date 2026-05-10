/**
 * Webhook Wix Automations → Firestore `articles`.
 * Déclencheur : « Un nouveau post de blog est publié » + action « Envoyer une requête HTTP » POST.
 *
 * Corps « Personnalisé » (recommandé si la charge utile totale manque image / extrait) —
 * construire un JSON avec les champs déclenchés Wix, par ex. :
 *   title        ← Titre du post
 *   url          ← URL du post (ou postUrl)
 *   description  ← Description de la publication
 *   imageUrl     ← Image de couverture du post
 *   id           ← ID du post
 *   publishedAt  ← Date de publication du post (ISO)
 *   category / categories / blogCategory ← catégories Wix Blog (mappées vers les filtres de l’app ; sans catégorie → visible uniquement sous « TOUT »)
 * Le texte intégral du billet n’est en général *pas* dans l’automatisation : l’app ouvre wixUrl (WebView).
 *
 * Sécurité : header `X-DVCR-Webhook-Secret: <valeur>` (même valeur que le secret Firebase WIX_WEBHOOK_SECRET).
 *
 * Déploiement :
 *   firebase functions:secrets:set WIX_WEBHOOK_SECRET
 *   firebase deploy --only functions:wixArticleWebhook
 *
 * URL (exemple) :
 *   https://europe-west1-<PROJECT_ID>.cloudfunctions.net/wixArticleWebhook
 */
const crypto = require('crypto');
const axios = require('axios');
const { onRequest } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const cheerio = require('cheerio');

const wixWebhookSecret = defineSecret('WIX_WEBHOOK_SECRET');

const DVCR_POST_BASE = 'https://www.dvcr.fr/post/';

function _timingEqual(a, b) {
  if (a == null || b == null) return false;
  const ba = Buffer.from(String(a), 'utf8');
  const bb = Buffer.from(String(b), 'utf8');
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

function _stripHtml(raw) {
  const s = String(raw ?? '');
  if (!s) return '';
  try {
    return cheerio.load(s)('body').text().replace(/\s+/g, ' ').trim();
  } catch {
    return s.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  }
}

function _s(v) {
  if (v == null) return '';
  if (typeof v === 'string') return v.trim();
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  return '';
}

/** Aligné sur les chips `ArticleService` / écran Actus (hors « TOUT »). */
const DVCR_APP_CATEGORIES = [
  'RÉSULTATS',
  'AVANT-MATCH',
  'CHRONIQUES SEDANAISES',
  'ANALYSE',
  'COULISSES',
  'CLUB',
];

/** Stocké en Firestore : ne correspond à aucun onglet ; l’article n’apparaît que sous « TOUT ». */
const UNCATEGORIZED_TOUT = 'UNCATEGORIZED_TOUT';

function _foldAscii(s) {
  return _s(s)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function _matchExactAppCategory(raw) {
  const a = _foldAscii(raw);
  for (const c of DVCR_APP_CATEGORIES) {
    if (_foldAscii(c) === a) return c;
  }
  return null;
}

/**
 * Catégorie affichée dans l’app : correspond aux filtres Actus.
 * Si la catégorie Wix ne correspond à rien → UNCATEGORIZED_TOUT (uniquement « TOUT »).
 */
function _mapWixCategory(raw) {
  const trimmed = _s(raw);
  if (!trimmed) return UNCATEGORIZED_TOUT;

  const exact = _matchExactAppCategory(trimmed);
  if (exact) return exact;

  const f = _foldAscii(trimmed);

  if (f.includes('chronique')) return 'CHRONIQUES SEDANAISES';
  if ((f.includes('avant') && f.includes('match')) || f.includes('avant-match')) {
    return 'AVANT-MATCH';
  }
  if (
    f.includes('jour de match') ||
    f.includes('resultat') ||
    f.includes('score') ||
    f.includes('debrief') ||
    f.includes('recap')
  ) {
    return 'RÉSULTATS';
  }
  if (f.includes('expat') || f.includes('coulisse') || f.includes('backstage')) {
    return 'COULISSES';
  }
  if (f.includes('mercato') || f.includes('effectif') || f.includes('transfert')) {
    return 'CLUB';
  }
  if (
    f.includes('analyse') ||
    f.includes('emission') ||
    f.includes('tactique') ||
    f.includes('debriefing')
  ) {
    return 'ANALYSE';
  }

  return UNCATEGORIZED_TOUT;
}

function _collectCategoryCandidates(post) {
  const out = [];
  const add = (v) => {
    const s = _s(v);
    if (s && !out.includes(s)) out.push(s);
  };

  if (typeof post.category === 'string') add(post.category);
  if (post.category && typeof post.category === 'object') {
    add(post.category.name);
    add(post.category.label);
    add(post.category.title);
  }

  const arr = post.categories;
  if (Array.isArray(arr)) {
    for (const first of arr) {
      if (typeof first === 'string') add(first);
      else if (first && typeof first === 'object') {
        add(first.name || first.label || first.title);
      }
    }
  }

  add(post.blogCategory);
  if (Array.isArray(post.blogCategories)) {
    for (const x of post.blogCategories) {
      if (typeof x === 'string') add(x);
      else if (x && typeof x === 'object') add(x.name || x.label || x.title);
    }
  }
  add(post.primaryCategory);
  add(post.categoryName);
  add(post.blogCategoryName);
  add(post.postCategory);

  if (Array.isArray(post.labels)) {
    for (const x of post.labels) add(typeof x === 'string' ? x : x?.name || x?.label);
  }
  if (Array.isArray(post.tags)) {
    for (const x of post.tags) add(typeof x === 'string' ? x : x?.name || x?.label);
  }

  return out;
}

function _pickCategory(post) {
  const candidates = _collectCategoryCandidates(post);
  if (candidates.length === 0) return UNCATEGORIZED_TOUT;

  for (const raw of candidates) {
    const m = _mapWixCategory(raw);
    if (m !== UNCATEGORIZED_TOUT) return m;
  }
  return UNCATEGORIZED_TOUT;
}

function _imageUrlFromObject(x) {
  if (!x) return '';
  if (typeof x === 'string' && x.startsWith('http')) return x;
  if (typeof x !== 'object') return '';
  const u =
    _s(
      x.url ||
        x.src ||
        x.imageUrl ||
        x.fullUrl ||
        x.uri ||
        x.thumbnailUrl ||
        x.image,
    ) ||
    _s(x.wixImage?.url) ||
    _s(x.image?.url) ||
    _s(x.image?.src?.url) ||
    _s(x.fileUrl) ||
    _s(x.media?.url) ||
    _s(x.media?.image?.url);
  return u.startsWith('http') ? u : '';
}

function _pickImageUrl(post) {
  /** Corps « Personnalisé » Wix : URLs directes */
  for (const k of [
    'imageUrl',
    'coverImageUrl',
    'featuredImageUrl',
    'heroImageUrl',
    'coverImage',
    'featuredImage',
  ]) {
    const u = _s(post[k]);
    if (u.startsWith('http')) return u;
  }
  const candidates = [
    post.featuredImage,
    post.coverImage,
    post.coverMedia,
    post.heroImage,
    post.image,
    post.mainImage,
    post.media,
    post.featuredMedia,
    post.hero,
  ];
  for (const x of candidates) {
    if (Array.isArray(x)) {
      for (const it of x) {
        const u = _imageUrlFromObject(it);
        if (u) return u;
      }
      continue;
    }
    const u = _imageUrlFromObject(x);
    if (u) return u;
    if (x && typeof x === 'object' && x.image) {
      const u2 = _imageUrlFromObject(x.image);
      if (u2) return u2;
    }
    if (x && typeof x === 'object' && x.wixMedia) {
      const u3 = _imageUrlFromObject(x.wixMedia);
      if (u3) return u3;
    }
  }
  return null;
}

/** Dernière chance : première URL wixstatic trouvée dans l’objet post. */
function _deepFindWixMediaUrl(obj, depth = 0, seen = new Set()) {
  if (depth > 14 || obj == null || typeof obj !== 'object') return null;
  if (seen.has(obj)) return null;
  seen.add(obj);
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === 'string' && /^https?:\/\//i.test(v)) {
      if (/wixstatic\.com\/media\//i.test(v) || (k.toLowerCase().includes('image') && v.length > 20)) {
        return v;
      }
    }
    if (v && typeof v === 'object') {
      const u = _deepFindWixMediaUrl(v, depth + 1, seen);
      if (u) return u;
    }
  }
  return null;
}

function _normalizeRichRoot(raw) {
  if (raw == null) return null;
  let o = raw;
  if (typeof raw === 'string') {
    try {
      o = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (!o || typeof o !== 'object') return null;
  if (Array.isArray(o.nodes)) return o;
  if (o.document && Array.isArray(o.document.nodes)) {
    return { nodes: o.document.nodes };
  }
  if (o.richContent && typeof o.richContent === 'object') {
    return _normalizeRichRoot(o.richContent);
  }
  return null;
}

/** Texte complet depuis le Ricos Wix (Blog). */
function _richContentToPlain(rich) {
  const root = _normalizeRichRoot(rich);
  if (!root) return '';
  const parts = [];
  function walk(nlist) {
    if (!Array.isArray(nlist)) return;
    for (const n of nlist) {
      if (!n || typeof n !== 'object') continue;
      if (n.type === 'TEXT' && n.textData && _s(n.textData.text)) {
        parts.push(_s(n.textData.text));
      }
      if (n.nodes) walk(n.nodes);
    }
  }
  walk(root.nodes);
  const t = parts.join(' ').replace(/\s+/g, ' ').trim();
  return t;
}

/** Première image du corps (souvent la une n’est pas dans coverMedia dans le payload). */
function _firstImageFromRich(rich) {
  const root = _normalizeRichRoot(rich);
  if (!root || !Array.isArray(root.nodes)) return null;
  function find(nlist) {
    if (!Array.isArray(nlist)) return null;
    for (const n of nlist) {
      if (!n || typeof n !== 'object') continue;
      if (n.type === 'IMAGE') {
        const src = n.imageData?.image?.src || n.imageData?.src;
        const u =
          _s(src?.url) ||
          _s(n.imageData?.url) ||
          _s(n.imageData?.image?.url);
        if (u.startsWith('http')) return u;
      }
      if (n.nodes) {
        const u = find(n.nodes);
        if (u) return u;
      }
    }
    return null;
  }
  return find(root.nodes);
}

async function _fallbackOgImage(pageUrl) {
  try {
    const r = await axios.get(pageUrl, {
      timeout: 15000,
      maxRedirects: 5,
      responseType: 'text',
      headers: {
        'User-Agent': 'DVCR-WixSync/1.0',
        Accept: 'text/html,application/xhtml+xml',
      },
      validateStatus: (s) => s >= 200 && s < 400,
    });
    const $ = cheerio.load(r.data || '');
    const og =
      _s($('meta[property="og:image"]').attr('content')) ||
      _s($('meta[property="og:image:secure_url"]').attr('content')) ||
      _s($('meta[name="twitter:image"]').attr('content'));
    return og.startsWith('http') ? og : null;
  } catch (e) {
    console.warn('wixArticleWebhook og:image fallback failed', e.message);
    return null;
  }
}

const _HTML_MAX_CHARS = 480000;

/**
 * Images Wix : lazy-load (src vide / data: / data-src), srcset — flutter_html ne charge que src.
 * Retire aussi des min-height / height énormes qui créent du « scroll dans le vide » en bas.
 */
function _normalizeArticleHtmlFragment(html, pageUrl) {
  if (!html || typeof html !== 'string') return html;
  let baseOrigin = '';
  try {
    baseOrigin = new URL(pageUrl).origin;
  } catch (_) {
    /* ignore */
  }

  const $ = cheerio.load(`<div id="__dvcr_root">${html}</div>`);

  const absUrl = (raw) => {
    const s = _s(raw);
    if (!s) return '';
    if (s.startsWith('//')) return `https:${s}`;
    if (/^https?:\/\//i.test(s)) return s;
    if (s.startsWith('/') && baseOrigin) {
      try {
        return new URL(s, baseOrigin).href;
      } catch {
        return '';
      }
    }
    return '';
  };

  const pickSrcFromSrcset = (srcset) => {
    const ss = _s(srcset);
    if (!ss) return '';
    const first = ss.split(',')[0].trim().split(/\s+/)[0];
    return absUrl(first);
  };

  /** AVIF (enc_avif) : ImageDecoder Flutter / Android souvent incompatible — préférer JPEG (data-pin-media). */
  const stripAvifFromWixStatic = (u) => {
    const s = _s(u);
    if (!s || !/enc_avif/i.test(s)) return s;
    return s
      .replace(/,blur_\d+/gi, '')
      .replace(/,enc_avif,quality_auto/gi, '')
      .replace(/,enc_avif/gi, '');
  };

  /** Balise custom Wix : <img> interne OU JSON data-image-info (SSR sans img, galeries). */
  $('wow-image').each((_, el) => {
    const $w = $(el);
    const $inner = $w.find('img').first();
    if ($inner.length) {
      $w.replaceWith($inner.clone());
      return;
    }
    let rawInfo = _s($w.attr('data-image-info'));
    if (!rawInfo) {
      $w.remove();
      return;
    }
    rawInfo = rawInfo.replace(/&quot;/g, '"');
    let info;
    try {
      info = JSON.parse(rawInfo);
    } catch {
      $w.remove();
      return;
    }
    const uri = _s(info?.imageData?.uri);
    if (!uri) {
      $w.remove();
      return;
    }
    const url = uri.startsWith('http') ? uri : `https://static.wixstatic.com/media/${uri}`;
    const clean = stripAvifFromWixStatic(url) || url;
    const esc = clean.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
    $w.replaceWith(
      `<img src="${esc}" alt="" style="max-width:100%;width:100%;height:auto;display:block;object-fit:contain"/>`,
    );
  });

  /** Visuels uniquement en background-image (blocs Wix / galeries). */
  $('#__dvcr_root figure, [data-hook="image-viewer"], [data-hook^="figure-"]').each((_, el) => {
    const $el = $(el);
    if ($el.find('img[src*="http"],img[src^="//"]').length) return;
    const style = _s($el.attr('style'));
    if (!style) return;
    const m = /url\s*\(\s*["']?([^"')]+)["']?\s*\)/i.exec(style);
    if (!m) return;
    let u = m[1].trim().replace(/^["']|["']$/g, '');
    if (u.startsWith('//')) u = `https:${u}`;
    if (!/^https?:\/\//i.test(u) || !/wixstatic\.com/i.test(u)) return;
    const clean = stripAvifFromWixStatic(u) || u;
    const esc = clean.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
    $el.prepend(
      `<img src="${esc}" alt="" style="max-width:100%;width:100%;height:auto;display:block;object-fit:contain"/>`,
    );
  });

  /** Wix met souvent position:absolute + height:100% sur les img → hauteur 0 dans flutter_html. */
  const sanitizeImgStyle = (styleRaw) => {
    let s = _s(styleRaw);
    if (s) {
      s = s
        .replace(/position\s*:\s*[^;]+;?/gi, '')
        .replace(/left\s*:\s*[^;]+;?/gi, '')
        .replace(/top\s*:\s*[^;]+;?/gi, '')
        .replace(/right\s*:\s*[^;]+;?/gi, '')
        .replace(/bottom\s*:\s*[^;]+;?/gi, '')
        .replace(/height\s*:\s*100%[^;]*;?/gi, 'height:auto;')
        .replace(/width\s*:\s*100%\s*;\s*height\s*:\s*100%/gi, 'width:100%;height:auto;');
      s = s.replace(/;\s*;/g, ';').replace(/^;|;$/g, '').trim();
    }
    const keep = s
      ? `${s};max-width:100%;width:100%;height:auto;display:block;`
      : 'max-width:100%;width:100%;height:auto;display:block;object-fit:contain;';
    return keep.replace(/;\s*;/g, ';').replace(/^;|;$/g, '').trim();
  };

  $('#__dvcr_root img').each((_, el) => {
    const $img = $(el);
    const src = _s($img.attr('src'));
    const dataSrc =
      _s($img.attr('data-src')) ||
      _s($img.attr('data-lazy-src')) ||
      _s($img.attr('data-image')) ||
      _s($img.attr('data-url')) ||
      _s($img.attr('data-wix-url'));
    const fromSet = pickSrcFromSrcset($img.attr('srcset'));

    const pinMedia = _s($img.attr('data-pin-media'));
    let resolved = '';
    if (pinMedia.startsWith('http') && !/^data:/i.test(pinMedia)) {
      resolved = stripAvifFromWixStatic(pinMedia) || pinMedia;
    } else if (src.startsWith('http') && !/^data:/i.test(src)) {
      resolved = stripAvifFromWixStatic(src) || src;
    } else if (dataSrc.startsWith('http')) resolved = dataSrc;
    else if (fromSet) resolved = fromSet;
    else if (src.startsWith('//') && !/^data:/i.test(src)) resolved = absUrl(src);
    else if (src && !/^data:/i.test(src)) resolved = absUrl(src);

    if (resolved) {
      $img.attr('src', stripAvifFromWixStatic(resolved) || resolved);
    }
    $img.removeAttr('srcset');
    $img.removeAttr('data-src');
    $img.removeAttr('data-lazy-src');
    $img.attr('style', sanitizeImgStyle($img.attr('style')));
    $img.removeAttr('draggable');
  });

  $('#__dvcr_root *').each((_, el) => {
    const $n = $(el);
    const style = _s($n.attr('style'));
    if (!style) return;
    let s = style
      .replace(/min-height\s*:\s*[^;]+;?/gi, '')
      .replace(/height\s*:\s*\d{2,}vh[^;]*;?/gi, '')
      .replace(/height\s*:\s*\d{5,}px[^;]*;?/gi, '');
    s = s.replace(/;\s*;/g, ';').replace(/^;|;$/g, '').trim();
    if (!s) $n.removeAttr('style');
    else $n.attr('style', s);
  });

  _pruneTrailingEmptyWixNodes($, $('#__dvcr_root'));

  return ($('#__dvcr_root').html() || '').trim();
}

/** En fin d’article Ricos : div vides, type=empty-line, rcv-block — gros blanc avant le bouton dans l’app. */
function _isWixNodeEffectivelyEmpty($, $n) {
  if (!$n || $n.length === 0) return true;
  const txt = $n.text().replace(/[\s\u00a0\u200b]+/g, '');
  if (txt.length > 0) return false;
  if ($n.find('img,iframe,video,table,svg,picture,object,embed').length > 0) {
    return false;
  }
  return true;
}

function _pruneTrailingEmptyWixNodes($, $container) {
  let guard = 0;
  while (guard++ < 400) {
    const kids = $container.children();
    if (kids.length === 0) return;
    const $last = $(kids[kids.length - 1]);
    _pruneTrailingEmptyWixNodes($, $last);
    const kids2 = $container.children();
    if (kids2.length === 0) return;
    const $last2 = $(kids2[kids2.length - 1]);
    if (_isWixNodeEffectivelyEmpty($, $last2)) {
      $last2.remove();
    } else {
      break;
    }
  }
}

/**
 * Télécharge la page publique du post et extrait le HTML du corps (affichage in-app).
 * Les thèmes Wix varient : plusieurs sélecteurs + meilleur score par longueur de texte.
 */
async function fetchArticleBodyHtml(pageUrl) {
  const r = await axios.get(pageUrl, {
    timeout: 28000,
    maxRedirects: 5,
    responseType: 'text',
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 DVCR-Article/1',
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'fr-FR,fr;q=0.9',
    },
    validateStatus: (s) => s >= 200 && s < 400,
  });
  const $ = cheerio.load(r.data || '');
  $('script, style, iframe, noscript').remove();

  const selectors = [
    '[data-hook="post-description"]',
    '[data-hook="post-content"]',
    '[data-hook="post-body"]',
    '.blog-post-post-body',
    '.blog-post-post__body',
    '[class*="post-content"]',
    '[class*="richContentContainer"]',
    'article[data-hook="post"]',
    'article.post',
    'main article',
    'article',
  ];

  let bestHtml = '';
  let bestScore = -1;
  const scoreBlock = ($el) => {
    const textLen = $el.text().replace(/\s+/g, ' ').trim().length;
    const html = $el.html() || '';
    const visuals =
      $el.find('img[src^="http"],img[src^="//"]').length +
      $el.find('wow-image').length +
      $el.find('picture').length +
      $el.find('[style*="wixstatic.com"]').filter((_, n) => {
        const st = _s($(n).attr('style'));
        return /url\s*\(/i.test(st) && /wixstatic\.com/i.test(st);
      }).length;
    /** Billets très visuels (galeries, « chaque match… ») : ne pas perdre contre un wrapper plus verbeux. */
    return textLen + visuals * 380;
  };

  for (const sel of selectors) {
    $(sel).each((_, el) => {
      const $el = $(el).clone();
      $el.find('script, style, iframe, form, button, nav, aside, header, footer').remove();
      const html = $el.html() || '';
      const textLen = $el.text().replace(/\s+/g, ' ').trim().length;
      if (html.length < 20) return;
      const sc = scoreBlock($el);
      if (sc > bestScore) {
        bestScore = sc;
        bestLen = textLen;
        bestHtml = html;
      }
    });
  }

  if (bestLen < 150) {
    const $main = $('main').first().clone();
    $main.find('script, style, iframe, nav, footer, header, aside, form, button').remove();
    const t = $main.text().replace(/\s+/g, ' ').trim().length;
    const h = $main.html() || '';
    const scMain = scoreBlock($main);
    if (scMain > bestScore && h.length > 40) {
      bestHtml = h;
      bestLen = t;
      bestScore = scMain;
    }
  }

  bestHtml = _normalizeArticleHtmlFragment(bestHtml.trim(), pageUrl);

  if (bestHtml.length > _HTML_MAX_CHARS) {
    bestHtml = `${bestHtml.slice(0, _HTML_MAX_CHARS)}…`;
  }

  return { html: bestHtml.trim(), textLen: bestLen };
}

function _pickPostUrl(post) {
  const direct = _s(
    post.url ||
      post.postUrl ||
      post.postURL ||
      post.link ||
      post.canonicalUrl ||
      post.permalink ||
      post.pageUrl ||
      post.blogPostUrl,
  );
  if (direct.startsWith('http')) return direct;
  const slug = _s(post.slug || post.postSlug);
  if (slug) return `${DVCR_POST_BASE}${encodeURIComponent(slug)}`;
  return '';
}

function _pickPostId(post, fallbackUrl) {
  const id = _s(post._id || post.id || post.postId || post.entityId);
  if (id) return id.replace(/\//g, '_');
  if (fallbackUrl) {
    try {
      const u = new URL(fallbackUrl);
      return u.pathname.replace(/[^a-zA-Z0-9_-]+/g, '_').replace(/^_|_$/g, '').slice(0, 120) || 'post';
    } catch {
      return 'post';
    }
  }
  return 'unknown';
}

function _pickAuthor(post) {
  const a = post.author;
  const fromObj =
    a && typeof a === 'object'
      ? _s(a.name || a.displayName || a.nickname)
      : '';
  return (
    fromObj ||
    _s(post.authorDisplayName || post.authorName || post.writerName) ||
    'Rédaction DVCR'
  );
}

function _pickPublishedAt(post) {
  const raw =
    post.publishedDate ||
    post.firstPublishedDate ||
    post.publishedAt ||
    post.createdDate ||
    post.datePublished ||
    post.createdAt ||
    post._createdDate;
  if (raw == null) return Date.now();
  const d = raw instanceof Date ? raw : new Date(raw);
  return Number.isNaN(d.getTime()) ? Date.now() : d.getTime();
}

const _CONTENT_MAX = 95000;

function _pickContent(post, richPlain) {
  const fromRich = _s(richPlain);
  if (fromRich.length > 80) {
    return fromRich.length > _CONTENT_MAX
      ? `${fromRich.slice(0, _CONTENT_MAX)}…`
      : fromRich;
  }
  const plain = _s(
    post.excerpt ||
      post.shortDescription ||
      post.description ||
      post.summary ||
      post.publicationDescription,
  );
  if (plain) {
    const t = _stripHtml(plain);
    if (t.length > 80) {
      return t.length > _CONTENT_MAX ? `${t.slice(0, _CONTENT_MAX)}…` : t;
    }
  }
  const html = _s(post.content || post.body || post.html || post.text);
  if (html) {
    const t = _stripHtml(html);
    if (t.length > 80) {
      return t.length > _CONTENT_MAX ? `${t.slice(0, _CONTENT_MAX)}…` : t;
    }
  }
  const title = _s(post.title);
  return title || 'Article DVCR';
}

/**
 * Trouve un objet « article » dans la charge utile Wix (forme variable).
 */
function findBlogPostLike(obj, depth = 0) {
  if (!obj || typeof obj !== 'object' || depth > 6) return null;
  const title = _s(obj.title || obj.postTitle || obj.name);
  if (title.length > 0) {
    const url = _pickPostUrl(obj);
    const id = _s(obj._id || obj.id || obj.postId);
    if (url.startsWith('http') || id || _s(obj.slug)) {
      return obj;
    }
  }
  for (const v of Object.values(obj)) {
    if (!v || typeof v !== 'object') continue;
    if (Array.isArray(v)) {
      for (const item of v) {
        const found = findBlogPostLike(item, depth + 1);
        if (found) return found;
      }
    } else {
      const found = findBlogPostLike(v, depth + 1);
      if (found) return found;
    }
  }
  return null;
}

/**
 * Charge utile imbriquée OU JSON plat (Automatisations → Personnalisé).
 * Wix envoie parfois tout sous `data`, ou un seul objet racine.
 */
function _coercePostFromBody(body) {
  if (!body || typeof body !== 'object') return null;

  const singleWrapped = () => {
    const keys = Object.keys(body);
    if (keys.length !== 1) return null;
    const v = body[keys[0]];
    if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
    const t = _s(v.title || v.postTitle || v.name);
    const u = _pickPostUrl(v);
    if (t && (u.startsWith('http') || _s(v.slug))) return v;
    return null;
  };

  const dataFlat =
    body.data && typeof body.data === 'object' && !Array.isArray(body.data)
      ? body.data
      : null;
  if (dataFlat && !dataFlat.post && !dataFlat.blogPost) {
    const t = _s(dataFlat.title || dataFlat.postTitle);
    const u = _pickPostUrl(dataFlat);
    if (t && u.startsWith('http')) return dataFlat;
  }

  const nested =
    body.post ||
    body.blogPost ||
    body.payload ||
    body.data?.post ||
    body.data?.blogPost ||
    body.entity ||
    body.event?.data ||
    singleWrapped();
  if (nested && typeof nested === 'object' && !Array.isArray(nested)) {
    return nested;
  }
  const found = findBlogPostLike(body);
  if (found) return found;
  const title = _s(body.title || body.postTitle);
  const url = _pickPostUrl(body);
  if (title && url.startsWith('http')) return body;
  return null;
}

/** Corps vide `{}` côté Functions v2 : tenter `rawBody`. */
function _readJsonBody(req) {
  let body = req.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body || '{}');
    } catch {
      return null;
    }
  }
  if (body && typeof body === 'object' && Object.keys(body).length > 0) {
    return body;
  }
  const raw = req.rawBody;
  if (Buffer.isBuffer(raw) && raw.length > 2) {
    try {
      const txt = raw.toString('utf8').trim();
      if (txt.startsWith('{') || txt.startsWith('[')) {
        return JSON.parse(txt);
      }
    } catch (_) {
      /* ignore */
    }
  }
  return body && typeof body === 'object' ? body : null;
}

function _verifySecret(req) {
  const expected = wixWebhookSecret.value();
  if (!expected || !String(expected).trim()) {
    return false;
  }
  const exp = String(expected).trim();
  const header =
    req.get('X-DVCR-Webhook-Secret') ||
    req.get('x-dvcr-webhook-secret') ||
    '';
  const auth = req.get('Authorization') || '';
  let bearer = '';
  const m = /^Bearer\s+(.+)$/i.exec(auth);
  if (m) bearer = m[1].trim();
  const q =
    (req.query && (req.query.dvcr_secret || req.query.key || req.query.token)) ||
    '';
  const fromQuery = Array.isArray(q) ? q[0] : q;
  return (
    _timingEqual(header.trim(), exp) ||
    _timingEqual(bearer, exp) ||
    _timingEqual(String(fromQuery || '').trim(), exp)
  );
}

exports.wixArticleWebhook = onRequest(
  {
    cors: true,
    region: 'europe-west1',
    secrets: [wixWebhookSecret],
    invoker: 'public',
    /** Wix coupe souvent les requêtes HTTP > ~10–30 s : pas de fetch page ici. */
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    /** Test rapide : ouvrir dans le navigateur avec ?dvcr_secret=… (même valeur que le secret Firebase). */
    if (req.method === 'GET') {
      if (!_verifySecret(req)) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      res.status(200).json({
        ok: true,
        service: 'wixArticleWebhook',
        hint: 'Wix doit envoyer POST + JSON (title, url, …) avec le même secret en query ou en-tête.',
      });
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }
    if (!_verifySecret(req)) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }

    const body = _readJsonBody(req);
    if (!body || typeof body !== 'object') {
      res.status(400).json({ error: 'invalid_body' });
      return;
    }

    const post = _coercePostFromBody(body);

    if (!post || typeof post !== 'object') {
      const keys = Object.keys(body).slice(0, 12);
      console.warn('wixArticleWebhook no_post_in_payload keys=', keys.join(','));
      res.status(422).json({
        error: 'no_post_in_payload',
        hint:
          'Charge utile totale ou JSON plat avec au minimum title + url (ou postUrl).',
        receivedKeys: keys,
      });
      return;
    }

    const title = _s(post.title || post.postTitle || post.name);
    if (!title) {
      res.status(422).json({ error: 'missing_title' });
      return;
    }

    const wixUrl = _pickPostUrl(post);
    if (!wixUrl.startsWith('http')) {
      res.status(422).json({ error: 'missing_post_url', title });
      return;
    }

    const wixId = _pickPostId(post, wixUrl);
    const docId = `wix_${wixId}`;
    const db = getFirestore();

    const richSources = [
      post.richContent,
      post.content,
      post.richText,
      post.body,
      post.draft?.richContent,
      post.published?.richContent,
    ];
    let richPlain = '';
    let richForImage = null;
    for (const r of richSources) {
      const p = _richContentToPlain(r);
      if (p.length > richPlain.length) {
        richPlain = p;
        richForImage = r;
      }
    }
    if (!richForImage) {
      for (const r of richSources) {
        if (_normalizeRichRoot(r)) {
          richForImage = r;
          break;
        }
      }
    }

    const imageUrl =
      _pickImageUrl(post) ||
      _firstImageFromRich(richForImage) ||
      _deepFindWixMediaUrl(post) ||
      null;

    const category = _pickCategory(post);
    const authorName = _pickAuthor(post);
    const content = _pickContent(post, richPlain);
    const pubMs = _pickPublishedAt(post);

    const payload = {
      title,
      content: content || title,
      category,
      imageUrl,
      authorName,
      status: 'published',
      wixUrl,
      featured: false,
      images: imageUrl ? [imageUrl] : [],
      source: 'wix_automation',
      created_at: Timestamp.fromMillis(pubMs),
      updated_at: FieldValue.serverTimestamp(),
      contentHtml: FieldValue.delete(),
      contentHtmlTextLen: FieldValue.delete(),
      contentHtmlFetchedAt: FieldValue.delete(),
    };

    await db.collection('articles').doc(docId).set(payload, { merge: true });

    console.log('wixArticleWebhook ok', docId, title.slice(0, 60));

    res.status(200).json({
      ok: true,
      id: docId,
      enrichment: 'async',
    });
  },
);

/**
 * Après écriture rapide par le webhook Wix : télécharge la page pour contentHtml (+ og:image si besoin).
 * Évite le timeout côté Wix sur la requête HTTP du webhook.
 */
exports.enrichWixArticleFromSite = onDocumentWritten(
  {
    document: 'articles/{articleId}',
    region: 'europe-west1',
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (event) => {
    const afterSnap = event.data?.after;
    if (!afterSnap?.exists) return;
    const after = afterSnap.data();
    if (!after) return;
    if (after.source !== 'wix_automation') return;
    if (after.contentHtmlFetchedAt != null) return;

    const wixUrl = after.wixUrl;
    const ref = afterSnap.ref;
    if (!wixUrl || typeof wixUrl !== 'string' || !wixUrl.startsWith('http')) {
      await ref.set(
        {
          contentHtmlFetchedAt: FieldValue.serverTimestamp(),
          contentHtmlEnrichmentNote: 'no_wix_url',
        },
        { merge: true },
      );
      return;
    }

    let imageUrl = after.imageUrl || null;
    if (!imageUrl) {
      try {
        imageUrl = await _fallbackOgImage(wixUrl);
      } catch (e) {
        console.warn('enrichWixArticleFromSite og:image', e.message);
      }
    }

    let contentHtml = '';
    let contentHtmlTextLen = 0;
    try {
      const fetched = await fetchArticleBodyHtml(wixUrl);
      contentHtml = fetched.html || '';
      contentHtmlTextLen = fetched.textLen || 0;
    } catch (e) {
      console.warn('enrichWixArticleFromSite html', e.message);
    }

    const fresh = (await ref.get()).data() || {};
    const prevHtml = fresh.contentHtml || '';
    const prevLen = Number(fresh.contentHtmlTextLen) || 0;

    if (contentHtmlTextLen < 120 && prevLen > 120) {
      contentHtml = prevHtml;
      contentHtmlTextLen = prevLen;
    } else if (contentHtmlTextLen < 120) {
      contentHtml = '';
      contentHtmlTextLen = 0;
    } else if (prevLen > 200 && contentHtmlTextLen < prevLen * 0.5) {
      contentHtml = prevHtml;
      contentHtmlTextLen = prevLen;
    }

    const patch = {
      contentHtmlFetchedAt: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    };
    if (imageUrl && !after.imageUrl) {
      patch.imageUrl = imageUrl;
      patch.images = [imageUrl];
    }
    if (contentHtml && contentHtmlTextLen >= 120) {
      patch.contentHtml = contentHtml;
      patch.contentHtmlTextLen = contentHtmlTextLen;
    }

    await ref.set(patch, { merge: true });
  },
);
