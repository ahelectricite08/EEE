'use strict';

/**
 * Run: node test_wix_article_url.js
 */

const assert = require('assert');
const {
  _pickPostUrl,
  _isArticlePageUrl,
  _isSiteRootUrl,
  _asArticlePageUrl,
  _urlFromWixField,
  _hasPostBody,
} = require('./lib/wix_article_urls');

assert.ok(_isSiteRootUrl('https://www.dvcr.fr'));
assert.ok(_isSiteRootUrl('https://www.dvcr.fr/'));
assert.ok(_isSiteRootUrl('https://dvcr.fr?utm=1'));
assert.ok(!_isSiteRootUrl('https://www.dvcr.fr/post/foo-bar'));

assert.ok(!_isArticlePageUrl('https://www.dvcr.fr'));
assert.ok(!_isArticlePageUrl('https://www.dvcr.fr/'));
assert.ok(!_isArticlePageUrl('https://www.dvcr.fr/post'));
assert.ok(!_isArticlePageUrl('https://www.dvcr.fr/post/'));
assert.ok(_isArticlePageUrl('https://www.dvcr.fr/post/victoire-3-1'));
assert.strictEqual(_asArticlePageUrl('https://www.dvcr.fr'), '');

assert.strictEqual(
  _urlFromWixField({ base: 'https://www.dvcr.fr', path: '/post/slug-actu' }),
  'https://www.dvcr.fr/post/slug-actu',
);

assert.strictEqual(
  _pickPostUrl({
    title: 'Match',
    url: 'https://www.dvcr.fr',
    slug: 'analyse-valence',
  }),
  'https://www.dvcr.fr/post/analyse-valence',
);

assert.strictEqual(
  _pickPostUrl({
    url: 'https://www.dvcr.fr',
    postUrl: 'https://www.dvcr.fr/post/chronique-1',
  }),
  'https://www.dvcr.fr/post/chronique-1',
);

assert.strictEqual(
  _pickPostUrl({
    url: { base: 'https://www.dvcr.fr', path: '/post/ricos-obj' },
  }),
  'https://www.dvcr.fr/post/ricos-obj',
);

assert.strictEqual(_pickPostUrl({ url: 'https://www.dvcr.fr' }), '');
assert.ok(_hasPostBody({ title: 'X', contentHtml: '<p>hello</p>' }));

console.log('test_wix_article_url ok');
