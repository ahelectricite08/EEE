/** Catégories TV = playlists configurées uniquement (pas d’uploads chaîne, pas d’« Autres »). */
const TV_CATALOG_CATEGORIES = new Set([
  'resume',
  'matchday',
  'podcast',
  'shorts',
  'dvcrfc',
  'club',
  'interview',
]);

function normalizeTvCategory(raw) {
  const cat = (raw || '').toString().trim().toLowerCase();
  if (cat === 'club') return 'dvcrfc';
  return cat;
}

function isTvCatalogCategory(raw) {
  return TV_CATALOG_CATEGORIES.has(normalizeTvCategory(raw));
}

/** public only — vide = legacy (vidéos sync avant privacyStatus). */
function isPublicPrivacyStatus(raw) {
  const privacy = (raw || '').toString().trim().toLowerCase();
  return !privacy || privacy === 'public';
}

function isTvCatalogVideo(v) {
  if (!v) return false;
  if (v.hidden === true) return false;
  const cat = (v.category ?? '').toString().toLowerCase();
  if (cat === 'partenaire') return false;
  const title = (v.title ?? '').toString().toLowerCase();
  if (title.includes('partenaire')) return false;
  if (!isPublicPrivacyStatus(v.privacyStatus)) return false;
  return isTvCatalogCategory(v.category);
}

/** IDs YouTube + doc encore dans les playlists TV (publics). Léger — pas le catalogue entier. */
async function loadEligibleCatalogIds(db) {
  const cats = [...TV_CATALOG_CATEGORIES];
  const snaps = await Promise.all(
    cats.map((cat) => db.collection('videos').where('category', '==', cat).get()),
  );
  const ids = new Set();
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (!isTvCatalogVideo({
        category: data.category,
        title: data.title,
        hidden: data.hidden === true,
        privacyStatus: data.privacyStatus,
        isShort: data.isShort === true,
      })) {
        continue;
      }
      const youtubeId = (data.youtubeId || '').toString().trim();
      if (youtubeId) ids.add(youtubeId);
      if (doc.id) ids.add(doc.id);
    }
  }
  return [...ids];
}

module.exports = {
  TV_CATALOG_CATEGORIES,
  normalizeTvCategory,
  isTvCatalogCategory,
  isPublicPrivacyStatus,
  isTvCatalogVideo,
  loadEligibleCatalogIds,
};
