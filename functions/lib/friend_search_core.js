'use strict';

/**
 * Helpers purs pour la recherche d’amis (testables sans Admin SDK).
 */

function normalizeQuery(raw) {
  if (raw == null) return '';
  return String(raw).trim().toLowerCase();
}

function looksLikeEmail(q) {
  return typeof q === 'string' && q.includes('@') && q.indexOf('@') > 0;
}

function buildSearchFields(data) {
  const d = data && typeof data === 'object' ? data : {};
  const email = String(d.emailLower || d.email || '').trim().toLowerCase();
  const firstName = String(d.firstName || '').trim();
  const lastName = String(d.lastName || '').trim();
  let displayName = String(d.displayName || '').trim();
  if (!displayName) {
    displayName = `${firstName} ${lastName}`.trim();
  }
  return {
    emailLower: email || null,
    firstNameLower: firstName ? firstName.toLowerCase() : null,
    lastNameLower: lastName ? lastName.toLowerCase() : null,
    displayNameLower: displayName ? displayName.toLowerCase() : null,
  };
}

function publicUserHit(uid, data) {
  const d = data && typeof data === 'object' ? data : {};
  const firstName = String(d.firstName || '').trim();
  const lastName = String(d.lastName || '').trim();
  let displayName = String(d.displayName || '').trim();
  if (!displayName) {
    displayName = `${firstName} ${lastName}`.trim();
  }
  if (!displayName) displayName = 'Membre DVCR';
  return {
    uid: String(uid),
    displayName,
    firstName: firstName || null,
    lastName: lastName || null,
  };
}

function mergeHits(map, uid, data, excludeUid) {
  if (!uid || uid === excludeUid) return;
  if (map.has(uid)) return;
  map.set(uid, publicUserHit(uid, data));
}

function capitalizePrefix(q) {
  if (!q) return q;
  return q.charAt(0).toUpperCase() + q.slice(1);
}

module.exports = {
  normalizeQuery,
  looksLikeEmail,
  buildSearchFields,
  publicUserHit,
  mergeHits,
  capitalizePrefix,
};
