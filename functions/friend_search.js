'use strict';

/**
 * Recherche d’amis sur TOUS les inscrits (collection `users`).
 * Callable Admin SDK — ne jamais exposer emails en lecture client ouverte.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const {
  normalizeQuery,
  looksLikeEmail,
  buildSearchFields,
  mergeHits,
  capitalizePrefix,
} = require('./lib/friend_search_core');

const MAX_QUERY_LEN = 80;
const MAX_RESULTS = 12;
const QUERY_LIMIT = 24;

function _fieldsEqual(a, b) {
  return (a || null) === (b || null);
}

/**
 * Maintient emailLower / displayNameLower / firstNameLower / lastNameLower.
 * Idempotent — pas de boucle infinie si déjà à jour.
 */
exports.syncUserSearchFields = onDocumentWritten('users/{uid}', async (event) => {
  const afterSnap = event.data?.after;
  if (!afterSnap?.exists) return;

  const after = afterSnap.data() || {};
  const desired = buildSearchFields(after);
  const patch = {};

  if (!_fieldsEqual(after.emailLower, desired.emailLower) && desired.emailLower) {
    patch.emailLower = desired.emailLower;
  }
  if (!_fieldsEqual(after.displayNameLower, desired.displayNameLower) && desired.displayNameLower) {
    patch.displayNameLower = desired.displayNameLower;
  }
  if (!_fieldsEqual(after.firstNameLower, desired.firstNameLower) && desired.firstNameLower) {
    patch.firstNameLower = desired.firstNameLower;
  }
  if (!_fieldsEqual(after.lastNameLower, desired.lastNameLower) && desired.lastNameLower) {
    patch.lastNameLower = desired.lastNameLower;
  }

  if (Object.keys(patch).length === 0) return;
  await afterSnap.ref.set(patch, { merge: true });
});

async function _prefixQuery(col, field, prefix, limit) {
  if (!prefix) return [];
  try {
    const snap = await col
      .where(field, '>=', prefix)
      .where(field, '<=', `${prefix}\uf8ff`)
      .limit(limit)
      .get();
    return snap.docs;
  } catch (_) {
    return [];
  }
}

async function _displayNameCaseFallback(col, cleaned, limit) {
  const variants = new Set([cleaned, capitalizePrefix(cleaned)]);
  const docs = [];
  for (const v of variants) {
    if (!v) continue;
    try {
      const snap = await col
        .orderBy('displayName')
        .startAt(v)
        .endAt(`${v}\uf8ff`)
        .limit(limit)
        .get();
      docs.push(...snap.docs);
    } catch (_) {
      // index / champ absent
    }
  }
  return docs;
}

/**
 * Callable : recherche amis par pseudo (préfixe) OU email (exact).
 * Retourne uniquement uid + noms — jamais l’email.
 */
exports.searchUsersForFriends = onCall({ cors: true }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }

  const cleaned = normalizeQuery(request.data?.query);
  if (cleaned.length < 2) {
    throw new HttpsError('invalid-argument', 'Saisis au moins 2 caractères');
  }
  if (cleaned.length > MAX_QUERY_LEN) {
    throw new HttpsError('invalid-argument', 'Requête trop longue');
  }

  const selfUid = request.auth.uid;
  const db = getFirestore();
  const users = db.collection('users');
  const hits = new Map();

  // 1) Email exact (toujours tenté — cheap equality index).
  try {
    const emailSnap = await users.where('emailLower', '==', cleaned).limit(5).get();
    for (const doc of emailSnap.docs) {
      mergeHits(hits, doc.id, doc.data(), selfUid);
    }
  } catch (_) {
    // champ / index
  }

  // Si la requête ressemble à un email et qu’on a déjà un hit, on s’arrête.
  if (looksLikeEmail(cleaned) && hits.size > 0) {
    return { users: Array.from(hits.values()).slice(0, MAX_RESULTS) };
  }

  // 2) Préfixe indexé sur champs searchable.
  const prefixDocs = [
    ...(await _prefixQuery(users, 'displayNameLower', cleaned, QUERY_LIMIT)),
    ...(await _prefixQuery(users, 'firstNameLower', cleaned, QUERY_LIMIT)),
    ...(await _prefixQuery(users, 'lastNameLower', cleaned, QUERY_LIMIT)),
  ];
  for (const doc of prefixDocs) {
    mergeHits(hits, doc.id, doc.data(), selfUid);
  }

  // 3) Fallback legacy : préfixe displayName / firstName / lastName (casse d’origine).
  if (hits.size < MAX_RESULTS) {
    const legacyDocs = [
      ...(await _displayNameCaseFallback(users, cleaned, QUERY_LIMIT)),
      ...(await _prefixQuery(users, 'firstName', capitalizePrefix(cleaned), QUERY_LIMIT)),
      ...(await _prefixQuery(users, 'lastName', capitalizePrefix(cleaned), QUERY_LIMIT)),
      ...(await _prefixQuery(users, 'firstName', cleaned, QUERY_LIMIT)),
      ...(await _prefixQuery(users, 'lastName', cleaned, QUERY_LIMIT)),
    ];
    for (const doc of legacyDocs) {
      mergeHits(hits, doc.id, doc.data(), selfUid);
    }
  }

  return { users: Array.from(hits.values()).slice(0, MAX_RESULTS) };
});
