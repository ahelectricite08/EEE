'use strict';

/**
 * URLs d’articles Wix / DVCR — jamais la home du site.
 */

const DVCR_POST_BASE = 'https://www.dvcr.fr/post/';

function _s(v) {
  if (v == null) return '';
  if (typeof v === 'string') return v.trim();
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  return '';
}

function _urlFromWixField(v) {
  if (v == null) return '';
  if (typeof v === 'string') {
    const s = v.trim();
    return /^https?:\/\//i.test(s) ? s : '';
  }
  if (typeof v !== 'object') return '';
  const nested = _s(v.url || v.href || v.full || v.canonical || v.postUrl);
  if (/^https?:\/\//i.test(nested)) return nested;
  const base = _s(v.base || v.origin);
  let path = _s(v.path || v.pathname || v.relativePath);
  if (/^https?:\/\//i.test(base) && path) {
    if (!path.startsWith('/')) path = `/${path}`;
    try {
      return new URL(path, base.endsWith('/') ? base : `${base}/`).href;
    } catch {
      return `${base.replace(/\/+$/, '')}${path}`;
    }
  }
  return '';
}

function _isSiteRootUrl(raw) {
  const s = _s(raw);
  if (!s) return true;
  try {
    const u = new URL(s);
    const path = (u.pathname || '/').replace(/\/+$/, '') || '/';
    return path === '/';
  } catch {
    return true;
  }
}

function _isArticlePageUrl(raw) {
  const s = _s(raw);
  if (!/^https?:\/\//i.test(s)) return false;
  try {
    const u = new URL(s);
    const path = u.pathname || '';
    if (/\/post\/[^/]+/i.test(path)) return true;
    if (/\/blog\/[^/]+/i.test(path) && !/\/blog\/?$/i.test(path)) return true;
    return false;
  } catch {
    return false;
  }
}

function _asArticlePageUrl(raw) {
  const s = _s(raw);
  return _isArticlePageUrl(s) ? s : '';
}

function _deepFindPostUrl(obj, depth = 0, seen = new Set()) {
  if (depth > 10 || obj == null || typeof obj !== 'object') return '';
  if (seen.has(obj)) return '';
  seen.add(obj);
  for (const [k, v] of Object.entries(obj)) {
    const key = String(k).toLowerCase();
    if (/siteurl|website|homeurl|homepage/.test(key)) continue;
    if (typeof v === 'string') {
      const hit = _asArticlePageUrl(v);
      if (hit) return hit;
    } else if (v && typeof v === 'object') {
      const fromObj = _asArticlePageUrl(_urlFromWixField(v));
      if (fromObj) return fromObj;
      const nested = _deepFindPostUrl(v, depth + 1, seen);
      if (nested) return nested;
    }
  }
  return '';
}

function _slugToPostUrl(slugRaw) {
  let slug = _s(slugRaw);
  if (!slug) return '';
  if (/^https?:\/\//i.test(slug)) return _asArticlePageUrl(slug);
  slug = slug.replace(/^\/+/, '').replace(/^post\//i, '');
  if (!slug || slug === '/' || /\s/.test(slug) && slug.length < 2) return '';
  const safe = slug
    .split('/')
    .filter(Boolean)
    .map((p) => encodeURIComponent(p))
    .join('/');
  if (!safe) return '';
  return `${DVCR_POST_BASE}${safe}`;
}

/**
 * URL publique de CE billet. Ignore https://www.dvcr.fr (home / siteUrl).
 */
function _pickPostUrl(post) {
  if (!post || typeof post !== 'object') return '';
  const candidates = [
    _urlFromWixField(post.postUrl),
    _urlFromWixField(post.postURL),
    _urlFromWixField(post.blogPostUrl),
    _urlFromWixField(post.canonicalUrl),
    _urlFromWixField(post.permalink),
    _urlFromWixField(post.pageUrl),
    _urlFromWixField(post.link),
    _urlFromWixField(post.url),
  ];
  for (const c of candidates) {
    const article = _asArticlePageUrl(c);
    if (article) return article;
  }
  const fromSlug = _slugToPostUrl(post.slug || post.postSlug);
  if (fromSlug) return fromSlug;
  return _deepFindPostUrl(post);
}

function _hasPostBody(post) {
  if (!post || typeof post !== 'object') return false;
  return !!(
    _s(post.contentHtml) ||
    _s(post.html) ||
    _s(post.bodyHtml) ||
    _s(post.description) ||
    _s(post.excerpt) ||
    _s(post.imageUrl) ||
    _s(post.content) ||
    _s(post.slug) ||
    _s(post.postSlug)
  );
}

module.exports = {
  DVCR_POST_BASE,
  _urlFromWixField,
  _isSiteRootUrl,
  _isArticlePageUrl,
  _asArticlePageUrl,
  _pickPostUrl,
  _hasPostBody,
  _slugToPostUrl,
};
