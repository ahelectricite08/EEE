const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret }      = require('firebase-functions/params');
const { initializeApp }     = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging }      = require('firebase-admin/messaging');
const axios                 = require('axios');
const { XMLParser }         = require('fast-xml-parser');
const cheerio               = require('cheerio');

// ── FFF API — CSSA Régional 1 Grand Est ──────────────────────────────────────
const FFF_BASE  = 'https://api-dofa.fff.fr/api';
const FFF_HOST  = 'https://api-dofa.fff.fr';  // pour les liens hydra:next
const FFF_CP    = 436257;  // Régional 1 Homiris Grand Est 2025-2026
const FFF_PH    = 1;
const FFF_GP    = 1;       // Poule A (CSSA's group)
const FFF_CLUB  = 500266;  // CS Sedan Ardennes

const FFF_CONFIG_DOC = 'fff_season';

function _isUserAdmin(userDoc) {
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  if (data.role === 'admin') return true;
  if (Array.isArray(data.roles) && data.roles.includes('admin')) return true;
  return false;
}

/** Supprime tous les docs d’une sous-collection (lots de 400). */
async function _deleteFirestoreCollectionInBatches(db, collectionRef, batchSize = 400) {
  let snapshot = await collectionRef.limit(batchSize).get();
  while (!snapshot.empty) {
    const batch = db.batch();
    snapshot.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    snapshot = await collectionRef.limit(batchSize).get();
  }
}

/** Préférences `users.*.notificationPrefs` (app DVCR) — défaut : activé. */
function _notifPref(userData, key, defaultVal = true) {
  if (!userData || typeof userData !== 'object') return defaultVal;
  const p = userData.notificationPrefs;
  if (!p || typeof p !== 'object') return defaultVal;
  if (p[key] === false) return false;
  if (p[key] === true) return true;
  return defaultVal;
}

/** Pas de push « mention chat » pour les comptes équipe DVCR (admin / flag). */
function _skipMentionPushForRecipient(userData) {
  if (!userData || typeof userData !== 'object') return false;
  if (userData.role === 'admin') return true;
  if (Array.isArray(userData.roles) && userData.roles.includes('admin')) return true;
  if (userData.dvcrTeamMember === true) return true;
  return false;
}

/** Lit app_config/fff_season ; retombe sur les constantes historiques si absent. */
async function _loadFffSeasonConfig(db) {
  const snap = await db.collection('app_config').doc(FFF_CONFIG_DOC).get();
  const d = snap.data() || {};
  const cp = Number(d.fffCompetitionId) || FFF_CP;
  const ph = Number(d.fffPhaseId) || FFF_PH;
  const gp = Number(d.fffPouleId) || FFF_GP;
  const clubNo = Number(d.fffClubNo) || FFF_CLUB;
  const seasonLabel =
    (d.seasonLabel && String(d.seasonLabel).trim()) || '2025-2026';
  const competitionDisplayName =
    (d.competitionDisplayName && String(d.competitionDisplayName).trim()) ||
    'Régional 1';
  let prefix =
    (d.matchDocIdPrefix && String(d.matchDocIdPrefix).trim()) || 'fff_';
  if (!prefix.endsWith('_')) prefix = `${prefix}_`;
  return {
    cp,
    ph,
    gp,
    clubNo,
    seasonLabel,
    competitionDisplayName,
    matchDocIdPrefix: prefix,
  };
}

initializeApp();
const youtubeApiKeySecret = defineSecret('YOUTUBE_API_KEY');

const HELLOASSO_DONATEUR_ROLE = 'donateur';
const HELLOASSO_DONATEUR_DURATION_MS = 365 * 24 * 60 * 60 * 1000;
const HELLOASSO_PROCESSED_STATES = new Set(['authorized', 'processed']);
const HELLOASSO_ORGANIZATION_SLUG =
  (process.env.HELLOASSO_ORGANIZATION_SLUG || '').trim().toLowerCase();

const PLAYLISTS = [
  { id: 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD', category: 'resume'     },
  { id: 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22', category: 'podcast'    },
  { id: 'PLHZuIRHxEd8w_J7I_aEhtGc2MpLfINJVB', category: 'matchday'   },
  { id: 'PLHZuIRHxEd8zKv-Z_Y-kg1_1S7u07Nw90', category: 'partenaire' },
];

function _getYoutubeApiKey() {
  const apiKey = youtubeApiKeySecret.value();
  if (!apiKey) {
    throw new Error('Le secret YOUTUBE_API_KEY est manquant');
  }
  return apiKey;
}

function _parseYoutubePublishedAt(rawValue) {
  const publishedAt = new Date(rawValue || Date.now());
  return Number.isNaN(publishedAt.getTime()) ? new Date() : publishedAt;
}

function _pickYoutubeThumbnailUrl(thumbnails) {
  if (!thumbnails || typeof thumbnails !== 'object') {
    return '';
  }
  return (
    thumbnails?.maxres?.url ||
    thumbnails?.standard?.url ||
    thumbnails?.high?.url ||
    thumbnails?.medium?.url ||
    thumbnails?.default?.url ||
    ''
  );
}

exports.helloAssoWebhook = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const db = getFirestore();
  const payload = _normalizeHelloAssoPayload(req.body);
  const eventType = payload.eventType;
  const data = payload.data;
  const payment = eventType === 'Payment'
    ? data
    : Array.isArray(data?.payments) && data.payments.length > 0
      ? data.payments[0]
      : null;
  const order = eventType === 'Order' ? data : data?.order;
  const metadata = _normalizeMetadata(payload.metadata ?? data?.metadata ?? order?.metadata);

  if (!eventType || !data) {
    res.status(400).json({ error: 'invalid_payload' });
    return;
  }

  const organizationSlug = (
    order?.organizationSlug ||
    data?.organizationSlug ||
    ''
  ).toString().trim().toLowerCase();

  if (HELLOASSO_ORGANIZATION_SLUG && organizationSlug && organizationSlug !== HELLOASSO_ORGANIZATION_SLUG) {
    res.status(202).json({ ignored: true, reason: 'organization_slug_mismatch' });
    return;
  }

  const paymentId = _toSafeString(
    payment?.id ||
    data?.id ||
    order?.payments?.[0]?.id,
  );
  const orderId = _toSafeString(order?.id || data?.orderId || data?.id);
  const state = (
    payment?.state ||
    data?.state ||
    order?.payments?.[0]?.state ||
    ''
  ).toString().trim().toLowerCase();
  const payerEmail = _extractHelloAssoEmail({ payload, data, order, payment }).toLowerCase();
  const amount = _extractHelloAssoAmount({ data, order, payment });
  const paidAt = _extractHelloAssoPaidAt({ data, order, payment });
  const expiresAt = Timestamp.fromDate(
    new Date(paidAt.getTime() + HELLOASSO_DONATEUR_DURATION_MS)
  );

  const eventId = _buildHelloAssoEventId({
    eventType,
    paymentId,
    orderId,
    state,
  });
  const grantKey = paymentId || orderId || eventId;
  const eventRef = db.collection('helloasso_events').doc(eventId);
  const existing = await eventRef.get();
  if (existing.exists) {
    res.status(200).json({ ok: true, duplicate: true });
    return;
  }

  const baseLog = {
    eventType,
    paymentId: paymentId || null,
    orderId: orderId || null,
    organizationSlug: organizationSlug || null,
    state: state || null,
    payerEmail: payerEmail || null,
    payerEmailLower: payerEmail || null,
    amount,
    metadata,
    paidAt: Timestamp.fromDate(paidAt),
    expiresAt,
    receivedAt: FieldValue.serverTimestamp(),
    raw: payload,
  };

  const shouldGrant = eventType === 'Payment' && HELLOASSO_PROCESSED_STATES.has(state);
  if (!shouldGrant) {
    await eventRef.set({
      ...baseLog,
      processed: false,
      ignoredReason: eventType !== 'Payment' ? 'event_not_payment' : 'payment_not_authorized',
    });
    res.status(200).json({ ok: true, ignored: true });
    return;
  }

  const target = await _findHelloAssoTargetUser(db, metadata, payerEmail);
  if (!target) {
    await eventRef.set({
      ...baseLog,
      processed: false,
      needsReview: true,
      ignoredReason: 'user_not_found',
    });
    await db.collection('helloasso_pending_matches').add({
      ...baseLog,
      eventId,
      grantKey,
      createdAt: FieldValue.serverTimestamp(),
      status: 'pending',
    });
    res.status(200).json({ ok: true, pendingReview: true });
    return;
  }

  await db.runTransaction(async (tx) => {
    const grantRef = db.collection('helloasso_processed_payments').doc(grantKey);
    const grantSnap = await tx.get(grantRef);
    if (grantSnap.exists) {
      tx.set(eventRef, {
        ...baseLog,
        processed: false,
        duplicateGrant: true,
        processedAt: FieldValue.serverTimestamp(),
        matchedUserId: target.uid,
        matchedBy: target.matchedBy,
      });
      return;
    }

    const userSnap = await tx.get(target.ref);
    const userData = userSnap.data() || {};
    const currentRoles = Array.isArray(userData.roles)
      ? userData.roles.filter(Boolean).map((role) => role.toString())
      : [];
    const mergedRoles = Array.from(new Set([
      ...currentRoles,
      HELLOASSO_DONATEUR_ROLE,
    ]));
    const currentTotal = Number(userData.totalDonations || 0);
    const nextTotal = currentTotal + amount;

    tx.set(eventRef, {
      ...baseLog,
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
      matchedUserId: target.uid,
      matchedBy: target.matchedBy,
    });

    tx.set(grantRef, {
      userId: target.uid,
      paymentId: paymentId || null,
      orderId: orderId || null,
      eventId,
      amount,
      state: state || null,
      expiresAt,
      processedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(db.collection('donations').doc(`helloasso_${grantKey}`), {
      userId: target.uid,
      source: 'helloasso',
      method: 'helloasso',
      amount,
      status: 'completed',
      payerEmail: payerEmail || null,
      paymentId: paymentId || null,
      orderId: orderId || null,
      eventType,
      metadata,
      paidAt: Timestamp.fromDate(paidAt),
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(target.ref, {
      ..._buildHelloAssoUserPatch(userData, {
        amount,
        paymentId,
        orderId,
        expiresAt,
        mergedRoles,
        nextTotal,
      }),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  res.status(200).json({ ok: true, matchedUserId: target.uid });
});

function _normalizeHelloAssoPayload(body) {
  if (body && typeof body === 'object') return body;
  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch (_) {
      return {};
    }
  }
  return {};
}

function _normalizeMetadata(metadata) {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    return {};
  }
  return Object.fromEntries(
    Object.entries(metadata).map(([key, value]) => [key, value])
  );
}

function _toSafeString(value) {
  if (value === null || value === undefined) return '';
  return value.toString().trim();
}

function _extractHelloAssoEmail({ payload, data, order, payment }) {
  return _toSafeString(
    data?.payer?.email ||
    payload?.payer?.email ||
    order?.payer?.email ||
    order?.email ||
    payment?.payer?.email ||
    payment?.email ||
    payload?.email
  );
}

function _extractHelloAssoAmount({ data, order, payment }) {
  const rawAmount =
    payment?.amount ??
    data?.amount ??
    order?.amount ??
    order?.payments?.[0]?.amount ??
    0;
  const normalized = Number(rawAmount);
  if (!Number.isFinite(normalized)) return 0;
  return normalized / 100;
}

function _extractHelloAssoPaidAt({ data, order, payment }) {
  const rawValue =
    payment?.date ||
    data?.date ||
    order?.date ||
    null;

  if (!rawValue) return new Date();

  const parsed = new Date(rawValue);
  if (Number.isNaN(parsed.getTime())) return new Date();
  return parsed;
}

function _buildHelloAssoEventId({ eventType, paymentId, orderId, state }) {
  return [
    (eventType || 'unknown').toLowerCase(),
    paymentId || 'nopayment',
    orderId || 'noorder',
    state || 'nostate',
  ].join('_');
}

async function _findHelloAssoTargetUser(db, metadata, payerEmail) {
  const metadataUserId = _toSafeString(
    metadata.userId ||
    metadata.uid ||
    metadata.firebaseUid
  );
  if (metadataUserId) {
    const ref = db.collection('users').doc(metadataUserId);
    const snap = await ref.get();
    if (snap.exists) {
      return { uid: metadataUserId, ref, matchedBy: 'metadata.userId' };
    }
  }

  if (payerEmail) {
    const byEmail = await db.collection('users')
      .where('email', '==', payerEmail)
      .limit(1)
      .get();
    if (!byEmail.empty) {
      return {
        uid: byEmail.docs[0].id,
        ref: byEmail.docs[0].ref,
        matchedBy: 'email',
      };
    }

    const byEmailLower = await db.collection('users')
      .where('emailLower', '==', payerEmail)
      .limit(1)
      .get();
    if (!byEmailLower.empty) {
      return {
        uid: byEmailLower.docs[0].id,
        ref: byEmailLower.docs[0].ref,
        matchedBy: 'emailLower',
      };
    }
  }

  return null;
}

function _pickPrimaryRole(roles) {
  const priority = [
    'admin',
    'community_manager',
    'editor',
    'statisticien',
    'team_dvcr',
    'partenaire',
    'donateur',
    'supporter',
  ];
  return priority.find((role) => roles.includes(role)) || 'supporter';
}

function _buildHelloAssoUserPatch(userData, {
  amount,
  paymentId,
  orderId,
  expiresAt,
  mergedRoles,
  nextTotal,
}) {
  const existingHelloAsso =
    userData && typeof userData.helloAsso === 'object' && !Array.isArray(userData.helloAsso)
      ? userData.helloAsso
      : {};

  return {
    role: _pickPrimaryRole(mergedRoles),
    roles: mergedRoles,
    totalDonations: nextTotal,
    canAccessChat: true,
    helloAsso: {
      ...existingHelloAsso,
      isDonateurActive: true,
      donateurExpiresAt: expiresAt,
      lastDonAmount: amount,
      lastPaymentId: paymentId || null,
      lastOrderId: orderId || null,
      lastSyncedAt: FieldValue.serverTimestamp(),
    },
  };
}

exports.expireHelloAssoDonateurs = onSchedule('every 24 hours', async () => {
  const db = getFirestore();
  const snap = await db.collection('users')
    .where('helloAsso.isDonateurActive', '==', true)
    .get();

  if (snap.empty) return;

  for (let i = 0; i < snap.docs.length; i += 200) {
    const chunk = snap.docs.slice(i, i + 200);
    const batch = db.batch();

    for (const doc of chunk) {
      const data = doc.data() || {};
      const expiryMs = data?.helloAsso?.donateurExpiresAt?.toDate
        ? data.helloAsso.donateurExpiresAt.toDate().getTime()
        : 0;
      if (!expiryMs || expiryMs > Date.now()) {
        continue;
      }

      const currentRoles = Array.isArray(data.roles)
        ? data.roles.filter(Boolean).map((role) => role.toString())
        : [];
      const remainingRoles = currentRoles.filter((role) => role !== HELLOASSO_DONATEUR_ROLE);
      const safeRoles = remainingRoles.length > 0 ? remainingRoles : ['supporter'];
      const existingHelloAsso =
        data && typeof data.helloAsso === 'object' && !Array.isArray(data.helloAsso)
          ? data.helloAsso
          : {};

      batch.set(doc.ref, {
        role: _pickPrimaryRole(safeRoles),
        roles: safeRoles,
        helloAsso: {
          ...existingHelloAsso,
          isDonateurActive: false,
          expiredAt: FieldValue.serverTimestamp(),
          lastSyncedAt: FieldValue.serverTimestamp(),
        },
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await batch.commit();
  }
});

// ── 1. Notification push quand un article est publié ─────────────────────────
exports.notifyArticlePublished = onDocumentWritten('articles/{id}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return; // suppression

  // Déclenche uniquement si on passe à 'published' (création ou depuis draft)
  const wasDraft    = !before || before.status !== 'published';
  const isPublished = after.status === 'published';
  if (!isPublished || !wasDraft) return;

  await getMessaging().send({
    topic: 'dvcr_articles',
    notification: {
      title: '📰 Nouvelle actu DVCR',
      body:  after.title || 'Nouvel article publié',
    },
    data: {
      type:      'article',
      articleId: event.params.id,
    },
    android: {
      priority: 'high',
      notification: { sound: 'default', channelId: 'dvcr_articles' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });
});

// ── Notification mention chat — alerte l'utilisateur tagué ──────────────────
exports.notifyChatMention = onDocumentCreated(
  'chat_salons/{salonId}/messages/{msgId}',
  async (event) => {
    const db   = getFirestore();
    const data = event.data?.data();
    if (!data) return;

    const mentionUids = data.mentionUids ?? [];
    if (!mentionUids.length) return;

    const senderName = [data.firstName, data.lastName].filter(Boolean).join(' ') || 'Quelqu\'un';
    const text       = (data.text ?? '').substring(0, 80);
    const messaging  = getMessaging();

    await Promise.allSettled(mentionUids.map(async (uid) => {
      if (uid === data.uid) return; // pas de notif à soi-même
      const userSnap = await db.collection('users').doc(uid).get();
      const udata = userSnap.data() ?? {};
      if (_skipMentionPushForRecipient(udata)) return;
      if (!_notifPref(udata, 'chatMention')) return;
      const fcmToken = udata.fcmToken;
      if (!fcmToken) return;
      return messaging.send({
        token: fcmToken,
        notification: {
          title: `💬 ${senderName} t'a mentionné`,
          body:  text,
        },
        data: { type: 'chat_mention', salonId: event.params.salonId },
        android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_alerts' } },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    }));
  }
);

// ── Notification duel — alerte l'adversaire quand un duel est créé ───────────
exports.notifyDuelCreated = onDocumentCreated('prono_duels/{duelId}', async (event) => {
  const db   = getFirestore();
  const data = event.data?.data();
  if (!data) return;

  const opponentUid = data.opponentUid;
  const ownerName   = data.ownerName ?? 'Un supporter';
  if (!opponentUid) return;

  // Récupère le token FCM de l'adversaire
  const opponentSnap = await db.collection('users').doc(opponentUid).get();
  const odata = opponentSnap.data() ?? {};
  if (!_notifPref(odata, 'duelInvite')) return;
  const fcmToken = odata.fcmToken;
  if (!fcmToken) return;

  try {
    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: '⚔️ Défi prono',
        body:  `${ownerName} veut t’affronter en duel. Ouvre l’app pour répondre !`,
      },
      data: {
        type:    'duel',
        duelId:  event.params.duelId,
      },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'dvcr_alerts' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    console.log(`Duel notif envoyée à ${opponentUid}`);
  } catch (e) {
    console.error('notifyDuelCreated:', e.message);
  }
});

// ── Demande d’ami — notifie le destinataire ───────────────────────────────────
exports.notifyFriendRequest = onDocumentCreated('friend_requests/{reqId}', async (event) => {
  const data = event.data?.data();
  if (!data) return;
  if ((data.status || 'pending') !== 'pending') return;

  const toUid = data.toUid;
  const fromName = data.fromName || 'Un membre';
  if (!toUid) return;

  const userSnap = await db.collection('users').doc(toUid).get();
  const udata = userSnap.data() ?? {};
  if (!_notifPref(udata, 'friendRequest')) return;
  const fcmToken = udata.fcmToken;
  if (!fcmToken) return;

  try {
    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: '👋 Nouvelle demande d’ami',
        body: `${fromName} souhaite être ton ami sur DVCR.`,
      },
      data: {
        type: 'friend_request',
        requestId: String(event.params.reqId || ''),
        fromUid: String(data.fromUid || ''),
      },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'dvcr_alerts' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    console.log(`Friend request notif → ${toUid}`);
  } catch (e) {
    console.error('notifyFriendRequest:', e.message);
  }
});

// ── Duel terminé — gagnant / perdant / match nul ─────────────────────────────
exports.notifyDuelResolved = onDocumentWritten('prono_duels/{duelId}', async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.data();
  if (!after) return;

  const prev = before?.status;
  const next = after.status;
  if (next !== 'won' && next !== 'draw') return;
  if (prev === 'won' || prev === 'draw') return;

  const messaging = getMessaging();
  const duelId = event.params.duelId;
  const label = (after.matchLabel || 'Duel prono').toString();
  const ownerUid = after.ownerUid;
  const oppUid = after.opponentUid;

  const db = getFirestore();

  async function sendOne(uid, title, body) {
    if (!uid) return;
    const snap = await db.collection('users').doc(uid).get();
    const udata = snap.data() ?? {};
    if (!_notifPref(udata, 'duelResult')) return;
    const tok = udata.fcmToken;
    if (!tok) return;
    await messaging.send({
      token: tok,
      notification: { title, body },
      data: {
        type: 'duel_result',
        duelId: String(duelId),
        matchLabel: String(label),
      },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_alerts' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }

  try {
    if (next === 'draw') {
      await sendOne(ownerUid, '🤝 Duel nul', `${label} — égalité parfaite ou sans vainqueur.`);
      await sendOne(oppUid, '🤝 Duel nul', `${label} — égalité parfaite ou sans vainqueur.`);
      return;
    }
    const w = after.winnerUid;
    const wname = (after.winnerName || 'Gagnant').toString();
    const loserUid = w === ownerUid ? oppUid : ownerUid;
    await sendOne(w, '🏆 Duel gagné', `${label} — victoire pour toi !`);
    await sendOne(loserUid, '😅 Duel perdu', `${label} — ${wname} remporte ce duel.`);
  } catch (e) {
    console.error('notifyDuelResolved:', e.message);
  }
});

// ── Récap fin de match — notifie chaque pronostiqueur de son résultat ─────────
exports.notifyMatchRecap = onDocumentWritten('matches/{matchId}', async (event) => {
  const db     = getFirestore();
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return;

  // Déclenche seulement quand le match passe à 'finished'
  const wasFinished = before?.status === 'finished';
  const isFinished  = after.status === 'finished';
  if (!isFinished || wasFinished) return;

  const matchId   = event.params.matchId;
  const score1    = after.score1 ?? after.homeScore ?? null;
  const score2    = after.score2 ?? after.awayScore ?? null;
  if (score1 === null || score2 === null) return;

  const team1 = after.team1 ?? 'Eq. 1';
  const team2 = after.team2 ?? 'Eq. 2';

  // Récupère tous les pronos pour ce match (collection 'predictions', champs score1Pred/score2Pred)
  const pronosSnap = await db.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  if (pronosSnap.empty) return;

  const actualResult = score1 > score2 ? 'home' : score1 < score2 ? 'away' : 'draw';

  const messaging = getMessaging();
  const promises  = [];

  for (const doc of pronosSnap.docs) {
    const prono  = doc.data();
    const uid    = prono.uid;
    if (!uid) continue;

    const p1 = prono.score1Pred ?? null;
    const p2 = prono.score2Pred ?? null;
    if (p1 === null || p2 === null) continue;

    // Calcul du résultat
    const isExact   = p1 === score1 && p2 === score2;
    const pronoRes  = p1 > p2 ? 'home' : p1 < p2 ? 'away' : 'draw';
    const isCorrect = pronoRes === actualResult;

    const xpGained = isExact ? '+20 XP' : isCorrect ? '+8 XP' : '+0 XP';
    const emoji    = isExact ? '🎯' : isCorrect ? '✅' : '❌';
    const label    = isExact ? 'Score exact !' : isCorrect ? 'Bon résultat !' : 'Raté cette fois';

    // Récupère le token FCM
    const userSnap = await db.collection('users').doc(uid).get();
    const udata = userSnap.data() ?? {};
    if (!_notifPref(udata, 'pronoPointsRecap')) continue;
    const fcmToken = udata.fcmToken;
    if (!fcmToken) continue;

    promises.push(
      messaging.send({
        token: fcmToken,
        notification: {
          title: `${emoji} ${team1} ${score1}–${score2} ${team2}`,
          body:  `Ton prono : ${p1}–${p2} · ${label} · ${xpGained}`,
        },
        data: {
          type:    'match_recap',
          matchId,
        },
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'dvcr_alerts' },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      }).catch(e => console.error(`Recap notif failed for ${uid}:`, e.message))
    );
  }

  await Promise.allSettled(promises);
  console.log(`Match ${matchId} recap: ${promises.length} notification(s) envoyées`);
});

// ── 2. Nettoyage automatique des messages de chat (> 7 jours) ────────────────
exports.cleanOldChatMessages = onSchedule('every 24 hours', async () => {
  const db      = getFirestore();
  const cutoff  = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const snap    = await db.collection('chat')
    .where('createdAt', '<', Timestamp.fromDate(cutoff))
    .get();

  if (snap.empty) { console.log('Aucun message à supprimer'); return; }

  // Suppression par batch de 500 (limite Firestore)
  const chunks = [];
  for (let i = 0; i < snap.docs.length; i += 500) {
    chunks.push(snap.docs.slice(i, i + 500));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`Chat : ${snap.docs.length} message(s) supprimé(s) (> 7 jours)`);
});

// ── Nettoyage des salons live archivés après 7 jours ─────────────────────────
exports.cleanArchivedLiveSalons = onSchedule('every 24 hours', async () => {
  const db     = getFirestore();
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const snap   = await db.collection('chat_salons')
    .where('archived', '==', true)
    .where('archivedAt', '<', Timestamp.fromDate(cutoff))
    .get();

  if (snap.empty) { console.log('Aucun salon live à supprimer'); return; }

  for (const salonDoc of snap.docs) {
    // Supprimer les messages du sous-salon
    const msgs = await salonDoc.ref.collection('messages').get();
    const chunks = [];
    for (let i = 0; i < msgs.docs.length; i += 500) {
      chunks.push(msgs.docs.slice(i, i + 500));
    }
    for (const chunk of chunks) {
      const batch = db.batch();
      chunk.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
    await salonDoc.ref.delete();
    console.log(`Salon live supprimé : ${salonDoc.id} (${msgs.docs.length} messages)`);
  }
});

// ── 2. Notification push quand un live démarre ────────────────────────────────
// notifyLive supprimé — notifyGoal gère déjà le démarrage du live (évite la double notif)

exports.notifyEmission = onDocumentWritten('live/emission', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) return;

  const becameLive = before?.live !== true && after.live === true;
  const startedNow = !before?.startedAt && !!after.startedAt;
  const streamChanged =
    (before?.url ?? '') !== (after.url ?? '') && !!after.url;
  const shouldSend = !before || becameLive || startedNow || streamChanged;
  if (!shouldSend) return;

  await getMessaging().send({
    topic: 'dvcr_live',
    notification: {
      title: '📺 L\'émission DVCR est en direct !',
      body:  'Rejoins-nous maintenant',
    },
    data: {
      url:  after.url ?? '',
      type: 'emission',
    },
    android: {
      priority: 'high',
      notification: { sound: 'default', channelId: 'dvcr_live' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  });
});

// ── 2. Sync vidéos YouTube → Firestore (toutes les heures) ───────────────────
exports.syncYoutubeVideos = onSchedule(
  { schedule: 'every 1 hours', secrets: [youtubeApiKeySecret] },
  async () => {
    const db = getFirestore();
    for (const playlist of PLAYLISTS) {
      await _syncPlaylist(db, playlist.id, playlist.category);
    }
  }
);

// Sync manuelle déclenchable depuis l'admin web (admin only)
exports.syncYoutubeVideosManual = onCall(
  { cors: true, secrets: [youtubeApiKeySecret] },
  async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const role = userDoc.exists ? userDoc.data().role : '';
  if (role !== 'admin') throw new Error('Accès refusé');
  for (const playlist of PLAYLISTS) {
    await _syncPlaylist(db, playlist.id, playlist.category);
  }
    return { success: true };
  }
);

// ── Sync une playlist complète ────────────────────────────────────────────────
async function _syncPlaylist(db, playlistId, category) {
  const youtubeApiKey = _getYoutubeApiKey();
  const playlistIds = new Set();
  let nextPageToken = null;

  do {
    const url = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=${playlistId}&maxResults=50${nextPageToken ? `&pageToken=${nextPageToken}` : ''}&key=${youtubeApiKey}`;
    const res  = await fetch(url);
    const data = await res.json();

    const items = data.items ?? [];

    // Récupère les IDs pour la durée en batch
    const videoIds = items
      .map(i => i.snippet?.resourceId?.videoId)
      .filter(Boolean)
      .join(',');

    const detailsMap  = {};
    if (videoIds) {
      const detailsRes = await fetch(
        `https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics,snippet&id=${videoIds}&key=${youtubeApiKey}`
      );
      const detailsData = await detailsRes.json();
      for (const v of detailsData.items ?? []) {
        detailsMap[v.id] = v;
      }
    }

    for (const item of items) {
      const snippet   = item.snippet;
      const youtubeId = snippet?.resourceId?.videoId;
      if (!youtubeId) continue;

      // Skip vidéos privées ou supprimées
      const title = snippet.title ?? '';
      if (title === 'Private video' || title === 'Deleted video' || title === '') continue;

      playlistIds.add(youtubeId);

      // Skip si déjà dans Firestore
      const existing = await db.collection('videos')
        .where('youtubeId', '==', youtubeId)
        .limit(1)
        .get();

      const detail = detailsMap[youtubeId];
      const duration = _formatDuration(detail?.contentDetails?.duration ?? '');
      const views = parseInt(detail?.statistics?.viewCount ?? '0', 10);
      const publishedAt = _parseYoutubePublishedAt(
        item?.contentDetails?.videoPublishedAt ??
        detail?.snippet?.publishedAt ??
        snippet?.publishedAt
      );
      const thumbnailUrl = _pickYoutubeThumbnailUrl(
        detail?.snippet?.thumbnails ??
        snippet?.thumbnails
      );

      const videoPayload = {
        youtubeId,
        title: snippet.title ?? '',
        duration,
        views,
        thumbnailUrl,
        created_at: Timestamp.fromDate(publishedAt),
      };

      if (existing.empty) {
        await db.collection('videos').add({
          ...videoPayload,
          category,
        });
      } else {
        await existing.docs[0].ref.set(videoPayload, { merge: true });
      }

      console.log(`[${category}] Ajouté : ${snippet.title}`);
    }

    nextPageToken = data.nextPageToken ?? null;
  } while (nextPageToken);

  // Supprime les vidéos de cette catégorie qui ne sont plus dans la playlist
  const firestoreDocs = await db.collection('videos')
    .where('category', '==', category)
    .get();
  const batch = db.batch();
  let deleted = 0;
  for (const doc of firestoreDocs.docs) {
    if (!playlistIds.has(doc.data().youtubeId)) {
      batch.delete(doc.ref);
      deleted++;
    }
  }
  if (deleted > 0) {
    await batch.commit();
    console.log(`[${category}] Supprimés (retirés de la playlist) : ${deleted}`);
  }
}

// ── 3. Sync FFF classement + matchs CSSA → Firestore (toutes les 6 heures) ───
exports.syncFffData = onSchedule('every 6 hours', async () => {
  const db = getFirestore();
  await Promise.all([
    _syncClassement(db),
    _cleanMockMatches(db),
    _syncMatches(db),
  ]);
  console.log('FFF sync terminé');
});

// Sync manuelle scores/classement (admin only)
exports.syncFffDataManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  await Promise.all([
    _syncClassement(db),
    _cleanMockMatches(db),
    _syncMatches(db),
  ]);
  return { success: true };
});

/** Vérifie que l’API FFF répond pour la config saison (admin). */
exports.testFffSeasonConfig = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const cfg = await _loadFffSeasonConfig(db);
  const url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/classement_journees`;
  const res = await fetch(url, { headers: { Accept: 'application/ld+json' } });
  if (!res.ok) {
    return {
      ok: false,
      status: res.status,
      url,
      seasonLabel: cfg.seasonLabel,
    };
  }
  const data = await res.json();
  const members = data['hydra:member'] ?? [];
  return {
    ok: true,
    teamCount: members.length,
    seasonLabel: cfg.seasonLabel,
    url,
    competitionDisplayName: cfg.competitionDisplayName,
  };
});

/**
 * Copie le classement club (`ranking`) vers `ranking_archive/{seasonLabel}`
 * (snapshot : rows[] + leagueLabel). Ne supprime pas `ranking`.
 * Admin uniquement — avant changement d’ids FFF / nouvelle saison.
 */
exports.archiveClubRankingSeason = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const cfg = await _loadFffSeasonConfig(db);
  const raw = request.data && request.data.seasonLabel;
  const seasonLabel = (raw && String(raw).trim()) || cfg.seasonLabel;

  const archRef = db.collection('ranking_archive').doc(seasonLabel);
  const existing = await archRef.get();
  if (existing.exists) {
    throw new HttpsError(
      'already-exists',
      `Une archive existe déjà pour « ${seasonLabel} »`,
    );
  }

  const rankingSnap = await db.collection('ranking').get();
  const rows = [];
  for (const doc of rankingSnap.docs) {
    const d = doc.data() || {};
    rows.push({
      position: d.position ?? 0,
      team: d.team ?? '',
      logo: d.logo ?? null,
      mj: d.mj ?? 0,
      v: d.v ?? 0,
      n: d.n ?? 0,
      d: d.d ?? 0,
      bf: d.bf ?? 0,
      bc: d.bc ?? 0,
      pts: d.pts ?? 0,
      forme: d.forme ?? '',
    });
  }
  rows.sort((a, b) => (a.position || 999) - (b.position || 999));

  await archRef.set({
    seasonLabel,
    leagueLabel: cfg.competitionDisplayName,
    archivedAt: Timestamp.now(),
    rows,
  });

  return { ok: true, seasonLabel, teamCount: rows.length };
});

// ── Supprime les documents matches sans fffId (données mock) ─────────────────
// Préserve les matchs avec manual:true (ajoutés depuis l'admin panel)
async function _cleanMockMatches(db) {
  const snap = await db.collection('matches').get();
  const batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (!data.fffId && !data.manual) {
      batch.delete(doc.ref);
      count++;
    }
  }
  if (count > 0) {
    await batch.commit();
    console.log(`Mock supprimés : ${count}`);
  }
}

// ── Sync classement FFF → collection "ranking" ────────────────────────────────
async function _syncClassement(db) {
  const cfg = await _loadFffSeasonConfig(db);
  const url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/classement_journees`;
  const res  = await fetch(url, { headers: { Accept: 'application/ld+json' } });
  if (!res.ok) { console.error('Classement HTTP', res.status); return; }
  const data = await res.json();

  const members = data['hydra:member'] ?? [];
  if (!members.length) { console.warn('Classement vide'); return; }

  const existing = await db.collection('ranking').get();
  const batch = db.batch();
  for (const d of existing.docs) {
    batch.delete(d.ref);
  }

  let lastJournee = 0;
  for (const entry of members) {
    // Vrais noms de champs FFF API
    const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const mj       = entry.total_games_count ?? 0;
    const journee  = entry.cj_no ?? 0;
    if (journee > lastJournee) lastJournee = journee;

    const ref = db.collection('ranking').doc(`pos_${entry.rank}`);
    batch.set(ref, {
      season:    cfg.seasonLabel,
      position:  entry.rank ?? 0,
      team:      teamName,
      logo:      entry.equipe?.club?.logo ?? entry.equipe?.logo ?? null,
      mj,
      v:         entry.won_games_count  ?? 0,
      n:         entry.draw_games_count ?? 0,
      d:         entry.lost_games_count ?? 0,
      bf:        entry.goals_for_count     ?? 0,
      bc:        entry.goals_against_count ?? 0,
      pts:       entry.point_count ?? 0,
      forme:     entry.forme ?? '',
      updatedAt: Timestamp.now(),
    });
  }

  // Save current journée in meta doc
  batch.set(db.collection('competition').doc('meta'), {
    journee:   lastJournee,
    updatedAt: Timestamp.now(),
  }, { merge: true });

  await batch.commit();
  console.log(`Classement : ${members.length} équipes, J${lastJournee}`);

  // ── Enrichit les matchs upcoming avec rank + form depuis le classement ────
  // Stocke toutes les variantes de noms pour chaque équipe du classement
  const rankByTeam = {};
  for (const entry of members) {
    const shortName = (entry.equipe?.short_name ?? '').trim().toUpperCase();
    const fullName  = (entry.equipe?.nom ?? '').trim().toUpperCase();
    const abbr      = (entry.equipe?.abbreviation ?? '').trim().toUpperCase();
    const val = {
      rank: String(entry.rank ?? ''),
      form: (entry.forme ?? '').toUpperCase(),
    };
    if (shortName) rankByTeam[shortName] = val;
    if (fullName && fullName !== shortName) rankByTeam[fullName] = val;
    if (abbr && abbr !== shortName) rankByTeam[abbr] = val;
  }

  // Correspondance flexible : exact → contient → mots communs
  function findRank(teamName) {
    const t = teamName.trim().toUpperCase();
    if (!t) return null;
    // 1. Correspondance exacte
    if (rankByTeam[t]) return rankByTeam[t];
    // 2. L'une contient l'autre
    for (const [key, val] of Object.entries(rankByTeam)) {
      if (t.includes(key) || key.includes(t)) return val;
    }
    // 3. Mots significatifs en commun (longueur > 3)
    const tWords = t.split(/[\s\-\.]+/).filter(w => w.length > 3);
    for (const [key, val] of Object.entries(rankByTeam)) {
      const kWords = key.split(/[\s\-\.]+/).filter(w => w.length > 3);
      if (tWords.some(w => kWords.includes(w))) return val;
    }
    return null;
  }

  const matchesSnap = await db.collection('matches')
    .where('status', '==', 'upcoming')
    .get();

  const matchBatch = db.batch();
  let enriched = 0;
  for (const doc of matchesSnap.docs) {
    const d = doc.data();
    const r1 = findRank(d.team1 ?? '');
    const r2 = findRank(d.team2 ?? '');
    if (!r1 && !r2) continue;
    const update = {};
    if (r1) { update.rank1 = r1.rank; update.form1 = r1.form; }
    if (r2) { update.rank2 = r2.rank; update.form2 = r2.form; }
    matchBatch.update(doc.ref, update);
    enriched++;
  }
  if (enriched > 0) await matchBatch.commit();
  console.log(`Matchs enrichis avec rank/form : ${enriched} (keys disponibles: ${Object.keys(rankByTeam).join(', ')})`);
}

// ── Sync tous les matchs → collection "matches" ────────────────────────────────
// Pagine tous les 182 matchs de la poule (7 pages) via hydra:next
async function _syncMatches(db) {
  const cfg = await _loadFffSeasonConfig(db);
  const headers = { Accept: 'application/ld+json' };
  const seenIds = new Set();
  let   written = 0;

  // Démarre page 1 — journee=1 est requis pour éviter le 404
  let url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/matchs?journee=1`;

  while (url) {
    const res = await fetch(url, { headers });
    if (!res.ok) { console.error('Matchs HTTP', res.status, url); break; }
    const data = await res.json();

    for (const m of data['hydra:member'] ?? []) {
      // Synce TOUS les matchs (sans filtre CSSA)
      const w = await _writeMatch(db, m, seenIds, cfg);
      if (w) written++;
    }

    // Suit la pagination Hydra
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }

  console.log(`Matchs écrits/mis à jour : ${written}`);
}

async function _writeMatch(db, match, seenIds, cfg) {
  const fffId = match.ma_no;
  if (!fffId || seenIds.has(fffId)) return false;
  seenIds.add(fffId);

  const docId = `${cfg.matchDocIdPrefix}${fffId}`;
  const ref = db.collection('matches').doc(docId);
  const existing = await ref.get();
  if (existing.exists && existing.data()?.manual === true) {
    console.log(`[FFF] Sync ignorée pour ${docId} (fiche manuelle)`);
    return false;
  }

  const homeTeam = match.home?.short_name ?? '';
  const awayTeam = match.away?.short_name ?? '';
  if (!homeTeam || !awayTeam) return false;

  // Date + time → "2025-08-24T00:00:00+00:00" + "16H00" → Date
  const dateStr = match.date;
  if (!dateStr) return false;
  const matchDate = _parseMatchDate(dateStr, match.time);

  const homeLogo = match.home?.club?.logo ?? null;
  const awayLogo = match.away?.club?.logo ?? null;
  const score1   = _parseScore(match.home_score);
  const score2   = _parseScore(match.away_score);
  const isFinished = score1 !== null && score2 !== null;
  const isPast     = matchDate < new Date();

  await ref.set({
    team1:       homeTeam,
    team2:       awayTeam,
    logo1:       homeLogo,
    logo2:       awayLogo,
    score1,
    score2,
    date:        Timestamp.fromDate(matchDate),
    competition: cfg.competitionDisplayName,
    status:      isFinished || isPast ? 'finished' : 'upcoming',
    fffId:       String(fffId),
    fffSeason:   cfg.seasonLabel,
    updatedAt:   Timestamp.now(),
  }, { merge: true });
  return true;
}

// "2025-08-24T00:00:00+00:00" + "16H00" → Date
function _parseMatchDate(dateStr, timeStr) {
  // dateStr = "2025-06-14", timeStr = "20H00" (heure française)
  const base = new Date(dateStr);
  if (timeStr) {
    const match = timeStr.match(/(\d+)H(\d+)/i);
    if (match) {
      const h = parseInt(match[1]);
      const m = parseInt(match[2]);
      // L'heure FFF est en Europe/Paris → convertir en UTC
      const offset = _getParisOffsetHours(base);
      base.setUTCHours(h - offset, m, 0, 0);
    }
  }
  return base;
}

function _getParisOffsetHours(date) {
  const year = date.getUTCFullYear();
  // Dernier dimanche de mars à 1h UTC (= 2h CET → passage en CEST)
  const marchLast = new Date(Date.UTC(year, 2, 31));
  while (marchLast.getUTCDay() !== 0) marchLast.setUTCDate(marchLast.getUTCDate() - 1);
  marchLast.setUTCHours(1, 0, 0, 0);
  // Dernier dimanche d'octobre à 1h UTC (= 3h CEST → passage en CET)
  const octLast = new Date(Date.UTC(year, 9, 31));
  while (octLast.getUTCDay() !== 0) octLast.setUTCDate(octLast.getUTCDate() - 1);
  octLast.setUTCHours(1, 0, 0, 0);
  return (date >= marchLast && date < octLast) ? 2 : 1;
}

function _parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw);
  return isNaN(n) ? null : n;
}

// ── 4. Traitement de la file de notifications (envoi FCM réel) ────────────────
// processNotificationQueue supprimé — doublon de sendManualNotification

// ── 5. Rappel ~1 h avant coup d’envoi — matchs Sedan/CSSA (toutes les 30 min) ──
exports.notifyMatchReminder = onSchedule('every 30 minutes', async () => {
  const db  = getFirestore();
  const now = Date.now();
  // Fenêtre : entre ~50 min et ~70 min avant le coup d’envoi
  const windowStart = Timestamp.fromDate(new Date(now + (50 * 60 * 1000)));
  const windowEnd   = Timestamp.fromDate(new Date(now + (70 * 60 * 1000)));

  const snap = await db.collection('matches')
    .where('status', '==', 'upcoming')
    .where('date', '>=', windowStart)
    .where('date', '<=', windowEnd)
    .get();

  for (const doc of snap.docs) {
    const m  = doc.data();
    const t1 = (m.team1 || '').toUpperCase();
    const t2 = (m.team2 || '').toUpperCase();
    const isSedanMatch = t1.includes('SEDAN') || t1.includes('CSSA') ||
                         t2.includes('SEDAN') || t2.includes('CSSA');
    if (!isSedanMatch) continue;

    // Anti-doublon : un seul rappel 1 h par match (clé distincte de l’ancien rappel 2 h)
    const sentRef = db.collection('match_notifs_sent').doc(`reminder1h_${doc.id}`);
    const already = await sentRef.get();
    if (already.exists) continue;

    await sentRef.set({ sentAt: Timestamp.now(), type: 'reminder1h' });

    await getMessaging().send({
      topic: 'dvcr_notifications',
      notification: {
        title: '⚽ Match Sedan dans ~1 h',
        body:  `${m.team1} vs ${m.team2} — même rendez-vous que sur l’accueil.`,
      },
      data: { type: 'match_reminder', matchId: doc.id },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'dvcr_notifications' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    console.log(`[Reminder] Envoyé : ${m.team1} vs ${m.team2}`);
  }
});

// ── 4. Pronostics — calcul des points quand un match passe à "finished" ───────
exports.calculatePronoPoints = onDocumentWritten('matches/{matchId}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return;

  // Déclenche seulement quand le statut passe à 'finished' pour la première fois
  if (before?.status === 'finished' || after.status !== 'finished') return;

  const score1 = after.score1;
  const score2 = after.score2;
  if (score1 === null || score1 === undefined || score2 === null || score2 === undefined) return;

  const db      = getFirestore();
  const cfg     = await _loadFffSeasonConfig(db);
  const matchId = event.params.matchId;

  const predsSnap = await db.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  if (predsSnap.empty) {
    console.log(`Aucun prono pour le match ${matchId}`);
    return;
  }

  const streakByUid = new Map();
  for (const doc of predsSnap.docs) {
    const uid0 = doc.data().uid;
    if (uid0 && !streakByUid.has(uid0)) {
      const lb0 = await db.collection('prono_leaderboard').doc(uid0).get();
      const s0 = lb0.data() && lb0.data().pronoStreak != null
        ? Number(lb0.data().pronoStreak)
        : 0;
      streakByUid.set(uid0, s0);
    }
  }

  const batch = db.batch();
  const predResults = new Map();

  for (const doc of predsSnap.docs) {
    const pred = doc.data();
    const p1   = pred.score1Pred;
    const p2   = pred.score2Pred;

    let points = 0;
    if (p1 === score1 && p2 === score2) {
      points = 3;
    } else {
      const predResult = Math.sign(p1 - p2);
      const realResult = Math.sign(score1 - score2);
      if (predResult === realResult) points = 1;
    }

    batch.update(doc.ref, {
      points,
      resolvedAt: FieldValue.serverTimestamp(),
    });

    predResults.set(pred.uid, {
      uid: pred.uid,
      displayName: pred.displayName,
      points,
      score1Pred: p1,
      score2Pred: p2,
      delta: Math.abs((p1 - p2) - (score1 - score2)) + Math.abs(p1 - score1) + Math.abs(p2 - score2),
    });

    const prevStreak = streakByUid.get(pred.uid) || 0;
    const nextStreak = points >= 1 ? prevStreak + 1 : 0;
    streakByUid.set(pred.uid, nextStreak);

    // Mise à jour du classement global (merge pour créer ou incrémenter)
    const lbRef = db.collection('prono_leaderboard').doc(pred.uid);
    batch.set(lbRef, {
      uid:              pred.uid,
      displayName:      pred.displayName,
      points:           FieldValue.increment(points),
      exactScores:      FieldValue.increment(points === 3 ? 1 : 0),
      goodResults:      FieldValue.increment(points === 1 ? 1 : 0),
      totalPredictions: FieldValue.increment(1),
      pronoStreak:      nextStreak,
      season:           pred.season ?? after.fffSeason ?? cfg.seasonLabel,
      updatedAt:        FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();

  const rs1 = Number(score1);
  const rs2 = Number(score2);

  /** Points prono (3 / 1 / 0) + delta tie-break — mêmes règles que le championnat. */
  function duelPickResult(p1, p2) {
    const pp1 = Number(p1);
    const pp2 = Number(p2);
    if (!Number.isFinite(pp1) || !Number.isFinite(pp2)) return null;
    if (!Number.isFinite(rs1) || !Number.isFinite(rs2)) return null;
    let points = 0;
    if (pp1 === rs1 && pp2 === rs2) {
      points = 3;
    } else {
      const predResult = Math.sign(pp1 - pp2);
      const realResult = Math.sign(rs1 - rs2);
      if (predResult === realResult) points = 1;
    }
    const delta = Math.abs((pp1 - pp2) - (rs1 - rs2)) + Math.abs(pp1 - rs1) + Math.abs(pp2 - rs2);
    return {
      points,
      score1Pred: pp1,
      score2Pred: pp2,
      delta,
    };
  }

  const duelsSnap = await db.collection('prono_duels')
    .where('matchId', '==', matchId)
    .get();

  for (const duelDoc of duelsSnap.docs) {
    const duel = duelDoc.data();
    if (duel.status === 'cancelled' || duel.status === 'won' || duel.status === 'draw') continue;

    const picksSnap = await duelDoc.ref.collection('duel_picks').get();
    let ownerPickData = null;
    let oppPickData = null;
    for (const p of picksSnap.docs) {
      if (p.id === duel.ownerUid) ownerPickData = p.data();
      else if (p.id === duel.opponentUid) oppPickData = p.data();
    }

    const owner = ownerPickData != null && ownerPickData.score1 != null && ownerPickData.score2 != null
      ? duelPickResult(ownerPickData.score1, ownerPickData.score2)
      : null;
    const opponent = oppPickData != null && oppPickData.score1 != null && oppPickData.score2 != null
      ? duelPickResult(oppPickData.score1, oppPickData.score2)
      : null;

    let status = 'in_progress';
    let winnerUid = null;
    let winnerName = null;
    let loserUid = null;

    if (owner && opponent) {
      if (owner.points > opponent.points) {
        winnerUid = duel.ownerUid;
        winnerName = duel.ownerName;
        loserUid = duel.opponentUid;
      } else if (opponent.points > owner.points) {
        winnerUid = duel.opponentUid;
        winnerName = duel.opponentName;
        loserUid = duel.ownerUid;
      } else if (owner.delta < opponent.delta) {
        winnerUid = duel.ownerUid;
        winnerName = duel.ownerName;
        loserUid = duel.opponentUid;
      } else if (opponent.delta < owner.delta) {
        winnerUid = duel.opponentUid;
        winnerName = duel.opponentName;
        loserUid = duel.ownerUid;
      }

      status = winnerUid ? 'won' : 'draw';
    } else if (owner && !opponent) {
      winnerUid = duel.ownerUid;
      winnerName = duel.ownerName;
      loserUid = duel.opponentUid;
      status = 'won';
    } else if (opponent && !owner) {
      winnerUid = duel.opponentUid;
      winnerName = duel.opponentName;
      loserUid = duel.ownerUid;
      status = 'won';
    } else if (!owner && !opponent) {
      // Aucun score duel saisi — duel clos sans gagnant (pas d’XP).
      status = 'draw';
    }

    await duelDoc.ref.set({
      ownerPoints: owner?.points ?? null,
      opponentPoints: opponent?.points ?? null,
      ownerScore: owner ? `${owner.score1Pred}-${owner.score2Pred}` : null,
      opponentScore: opponent ? `${opponent.score1Pred}-${opponent.score2Pred}` : null,
      winnerUid,
      winnerName,
      loserUid,
      status,
      resolvedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (winnerUid) {
      await db.collection('users').doc(winnerUid).set({
        'pronoProfile.duelXp': FieldValue.increment(3),
        'pronoProfile.duelWins': FieldValue.increment(1),
        'pronoProfile.duelPoints': FieldValue.increment(3),
        'pronoProfile.lastDuelAt': FieldValue.serverTimestamp(),
      }, { merge: true });

      if (loserUid) {
        await db.collection('users').doc(loserUid).set({
          'pronoProfile.duelLosses': FieldValue.increment(1),
          'pronoProfile.lastDuelAt': FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    } else if (owner || opponent) {
      const duelDrawUpdate = {
        'pronoProfile.duelDraws': FieldValue.increment(1),
        'pronoProfile.lastDuelAt': FieldValue.serverTimestamp(),
      };
      if (duel.ownerUid) {
        await db.collection('users').doc(duel.ownerUid).set(duelDrawUpdate, { merge: true });
      }
      if (duel.opponentUid) {
        await db.collection('users').doc(duel.opponentUid).set(duelDrawUpdate, { merge: true });
      }
    }
  }

  console.log(`Pronos calculés pour ${matchId} (${score1}-${score2}) : ${predsSnap.size} prédiction(s)`);
});

/** Issue 1-X-2 à partir des scores prédits (agrégat communauté). */
function _outcomeFromPredScores(s1, s2) {
  const a = Number(s1);
  const b = Number(s2);
  if (Number.isNaN(a) || Number.isNaN(b)) return null;
  if (a > b) return 'homeWin';
  if (a < b) return 'awayWin';
  return 'draw';
}

/**
 * Maintient `match_prono_stats/{matchId}` (compteurs 1 / N / 2) pour barres UI.
 * Lecture côté client uniquement sur ce doc — pas de scan de toutes les prédictions.
 */
exports.syncMatchPronoOutcomeStats = onDocumentWritten('predictions/{predId}', async (event) => {
  const db = getFirestore();
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  const matchId = (after && after.matchId) || (before && before.matchId);
  if (!matchId) return;

  const oldO = before ? _outcomeFromPredScores(before.score1Pred, before.score2Pred) : null;
  const newO = after ? _outcomeFromPredScores(after.score1Pred, after.score2Pred) : null;
  if (before && after && oldO === newO) {
    return;
  }

  const statsRef = db.collection('match_prono_stats').doc(String(matchId));
  const patch = { matchId: String(matchId), updatedAt: FieldValue.serverTimestamp() };
  if (oldO) patch[oldO] = FieldValue.increment(-1);
  if (newO) patch[newO] = FieldValue.increment(1);
  if (!before && after) patch.total = FieldValue.increment(1);
  if (before && !after) patch.total = FieldValue.increment(-1);

  await statsRef.set(patch, { merge: true });
});

/**
 * Initialise `prono_seasons/current` (+ optionnellement `user_season_stats/{uid}_current`).
 * À appeler une fois depuis l’app admin ou la console (compte admin DVCR).
 */
exports.ensurePronoSeasonBootstrap = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Réservé aux administrateurs');
  }

  const now = Timestamp.now();
  const ends = Timestamp.fromDate(new Date(Date.UTC(2026, 6, 1, 0, 0, 0)));

  await db.collection('prono_seasons').doc('current').set({
    name: 'Saison 2025-2026',
    subtitle:
      'Classement « ranked » lié à cette fenêtre ; préférences et historique globaux restent.',
    startsAt: now,
    endsAt: ends,
    rulesVersion: 1,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const targetUid = String(request.data?.targetUid ?? request.auth.uid).trim();
  if (targetUid) {
    await db.collection('user_season_stats').doc(`${targetUid}_current`).set({
      uid: targetUid,
      seasonId: 'current',
      divisionLabel: 'Bronze',
      seasonPoints: 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  return {
    ok: true,
    pronoSeasonsDoc: 'prono_seasons/current',
    userSeasonStatsDoc: targetUid ? `user_season_stats/${targetUid}_current` : null,
  };
});

// ── Notifications live (but, mi-temps, fin de match) ─────────────────────────
exports.notifyGoal = onDocumentWritten('live/current', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();

  // ── Début de match (document créé) ──
  if (!before && after) {
    const team1 = after.team1 || 'Domicile';
    const team2 = after.team2 || 'Extérieur';
    await getMessaging().send({
      topic: 'dvcr_live',
      notification: {
        title: '🔴 C\'est parti ! Rejoins-nous !',
        body:  `${team1} vs ${team2} — Le live a commencé !`,
      },
      data: { type: 'kickoff', matchId: String(after.matchId || '') },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── Fin de match (document supprimé) ──
  if (before && !after) {
    const db    = getFirestore();
    const team1 = before.team1 || 'Domicile';
    const team2 = before.team2 || 'Extérieur';
    const h     = before.scoreHome ?? 0;
    const a     = before.scoreAway ?? 0;

    // Sauvegarde le résumé dans le doc match si matchId présent
    const matchId = before.matchId ?? '';
    if (matchId) {
      await db.collection('matches').doc(matchId).update({
        'liveScore1':  h,
        'liveScore2':  a,
        'liveEvents':  before.events    ?? [],
        'yellowHome':  before.yellowHome ?? 0,
        'yellowAway':  before.yellowAway ?? 0,
        'redHome':     before.redHome    ?? 0,
        'redAway':     before.redAway    ?? 0,
        'stats': before.stats ?? {},
        'manOfTheMatchName': before.manOfTheMatchName ?? '',
        'manOfTheMatchPartnerName': before.manOfTheMatchPartnerName ?? '',
        'manOfTheMatchPartnerLogo': before.manOfTheMatchPartnerLogo ?? '',
        'liveAt':      require('firebase-admin/firestore').FieldValue.serverTimestamp(),
      });
      console.log(`Résumé live sauvegardé dans match ${matchId}`);
    }

    await getMessaging().send({
      topic: 'dvcr_alerts',
      notification: {
        title: '🏁 Fin du match !',
        body:  `Score final : ${team1} ${h} - ${a} ${team2}`,
      },
      data: { type: 'fulltime', matchId: String(before.matchId || '') },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  if (!before || !after) return;

  const team1 = after.team1 || 'Domicile';
  const team2 = after.team2 || 'Extérieur';
  const h     = after.scoreHome  ?? 0;
  const a     = after.scoreAway  ?? 0;

  // ── Mi-temps ──
  if (after.lastEvent === 'halftime' && before.lastEvent !== 'halftime') {
    await getMessaging().send({
      topic: 'dvcr_alerts',
      notification: {
        title: '⏸ Mi-temps ! Rejoins-nous !',
        body:  `Score : ${team1} ${h} - ${a} ${team2}`,
      },
      data: { type: 'halftime', matchId: String(after.matchId || '') },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── But / But annulé ──
  const prevHome = before.scoreHome ?? 0;
  const prevAway = before.scoreAway ?? 0;

  let goalTitle = null;
  let goalTeam  = null;
  if      (h > prevHome) { goalTitle = `⚽ BUT !`; goalTeam = team1; }
  else if (a > prevAway) { goalTitle = `⚽ BUT !`; goalTeam = team2; }
  else if (h < prevHome) { goalTitle = `❌ But annulé`; goalTeam = team1; }
  else if (a < prevAway) { goalTitle = `❌ But annulé`; goalTeam = team2; }

  if (goalTitle) {
    // Cherche le dernier buteur dans les events
    const events   = after.events ?? [];
    const goals    = events.filter(e => e.type === 'goal');
    const lastGoal = goals.length > 0 ? goals[goals.length - 1] : null;
    const player   = lastGoal?.player ?? '';
    const minute   = lastGoal?.minute ?? '';
    const body     = player
        ? `${goalTeam} — ${player}${minute ? ` (${minute}')` : ''} · ${team1} ${h}-${a} ${team2}`
        : `${goalTeam} · ${team1} ${h}-${a} ${team2}`;

    await getMessaging().send({
      topic: 'dvcr_live_events',
      notification: { title: `${goalTitle} ${goalTeam}`, body },
      data: { type: 'goal', matchId: String(after.matchId || '') },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── Carton jaune ──
  const prevYH = before.yellowHome ?? 0;
  const prevYA = before.yellowAway ?? 0;
  const yH     = after.yellowHome  ?? 0;
  const yA     = after.yellowAway  ?? 0;

  if (yH > prevYH || yA > prevYA) {
    const cardTeam = yH > prevYH ? team1 : team2;
    await getMessaging().send({
      topic: 'dvcr_live_events',
      notification: {
        title: `🟨 Carton jaune — ${cardTeam}`,
        body:  `${team1} ${h}-${a} ${team2}`,
      },
      data: { type: 'yellow_card' },
      android: { priority: 'normal', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── Carton rouge ──
  const prevRH = before.redHome ?? 0;
  const prevRA = before.redAway ?? 0;
  const rH     = after.redHome  ?? 0;
  const rA     = after.redAway  ?? 0;

  if (rH > prevRH || rA > prevRA) {
    const cardTeam = rH > prevRH ? team1 : team2;
    await getMessaging().send({
      topic: 'dvcr_live_events',
      notification: {
        title: `🟥 Carton rouge — ${cardTeam}`,
        body:  `${team1} ${h}-${a} ${team2}`,
      },
      data: { type: 'red_card' },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return;
  }

  // ── Hors-jeu (compteurs stats live, même canal que buts/cartons) ──
  const stB = before.stats || {};
  const stA = after.stats || {};
  const o1b = Number(stB.horsJeu1 ?? stB.offsides1 ?? 0) || 0;
  const o2b = Number(stB.horsJeu2 ?? stB.offsides2 ?? 0) || 0;
  const o1a = Number(stA.horsJeu1 ?? stA.offsides1 ?? 0) || 0;
  const o2a = Number(stA.horsJeu2 ?? stA.offsides2 ?? 0) || 0;
  if (o1a > o1b || o2a > o2b) {
    const offTeam = o1a > o1b ? team1 : team2;
    await getMessaging().send({
      topic: 'dvcr_live_events',
      notification: {
        title: `🚩 Hors-jeu — ${offTeam}`,
        body: `${team1} ${h}-${a} ${team2}`,
      },
      data: { type: 'offside' },
      android: { priority: 'normal', notification: { sound: 'default', channelId: 'dvcr_live' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }
});

// ── TEMP : Peuple un faux classement de pronos (admin only — à supprimer après) ─
exports.addFakePronoData = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const role = userDoc.exists ? userDoc.data().role : '';
  if (role !== 'admin') throw new Error('Accès refusé');

  const fakeData = [
    { uid: 'fake_1', displayName: 'Axel D.',   points: 22, exactScores: 5, goodResults: 7,  totalPredictions: 14 },
    { uid: 'fake_2', displayName: 'Thomas M.', points: 17, exactScores: 3, goodResults: 8,  totalPredictions: 13 },
    { uid: 'fake_3', displayName: 'Julie B.',  points: 14, exactScores: 2, goodResults: 10, totalPredictions: 14 },
    { uid: 'fake_4', displayName: 'Kévin L.',  points: 11, exactScores: 1, goodResults: 8,  totalPredictions: 12 },
    { uid: 'fake_5', displayName: 'Marie T.',  points:  9, exactScores: 1, goodResults: 6,  totalPredictions: 10 },
    { uid: 'fake_6', displayName: 'Romain C.', points:  6, exactScores: 0, goodResults: 6,  totalPredictions:  9 },
    { uid: 'fake_7', displayName: 'Lucie F.',  points:  3, exactScores: 1, goodResults: 0,  totalPredictions:  7 },
  ];

  const batch = db.batch();
  for (const d of fakeData) {
    batch.set(db.collection('prono_leaderboard').doc(d.uid), {
      ...d, season: '2025-2026', updatedAt: Timestamp.now(),
    });
  }
  await batch.commit();
  return { success: true, count: fakeData.length };
});

// ── Notification manuelle depuis notifications_queue ─────────────────────────
exports.sendManualNotification = onDocumentCreated('notifications_queue/{id}', async (event) => {
  const db   = getFirestore();
  const data = event.data?.data();
  if (!data) return;

  const { title, body, topic } = data;
  if (!title || !body || !topic) {
    await event.data.ref.update({ status: 'error', error: 'Champs manquants' });
    return;
  }

  /** @type {Record<string, string>} */
  const fcmData = {};
  const actionType = String(data.actionType || 'none').trim();
  const articleId = String(data.articleId || '').trim();
  const matchId = String(data.matchId || '').trim();

  switch (actionType) {
    case 'article':
      fcmData.type = 'article';
      if (articleId) fcmData.articleId = articleId;
      break;
    case 'match':
      if (matchId) {
        fcmData.type = 'match_recap';
        fcmData.matchId = matchId;
      }
      break;
    case 'live':
      fcmData.type = 'emission';
      break;
    case 'actus':
      fcmData.type = 'article';
      break;
    case 'prono':
      fcmData.type = 'duel';
      break;
    default:
      break;
  }

  let channelId = 'dvcr_alerts';
  if (topic === 'dvcr_live') channelId = 'dvcr_live';
  else if (topic === 'dvcr_articles') channelId = 'dvcr_articles';

  const message = {
    topic,
    notification: { title, body },
    android: {
      priority: 'high',
      notification: { sound: 'default', channelId },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  };

  if (Object.keys(fcmData).length > 0) {
    message.data = Object.fromEntries(
      Object.entries(fcmData).map(([k, v]) => [k, String(v)]),
    );
  }

  try {
    await getMessaging().send(message);
    await db.collection('notifications_queue').doc(event.params.id).update({
      status: 'sent',
      sentAt: require('firebase-admin/firestore').FieldValue.serverTimestamp(),
    });
    console.log(`Notif manuelle envoyée : [${topic}] ${title}`);
  } catch (err) {
    await db.collection('notifications_queue').doc(event.params.id).update({
      status: 'error',
      error:  String(err),
    });
    console.error('Erreur notif manuelle :', err);
  }
});

// ── Encouragement classement prono (~10,5 j / utilisateur, max 150 envois / run) ─
exports.notifyRankingMotivation = onSchedule(
  { schedule: 'every 252 hours', memory: '256MiB', timeoutSeconds: 300 },
  async () => {
    const db = getFirestore();
    const messaging = getMessaging();
    const snap = await db.collection('prono_leaderboard')
      .orderBy('points', 'desc')
      .limit(500)
      .get();

    const now = Date.now();
    const minGapMs = Math.floor(10.5 * 24 * 60 * 60 * 1000);
    let sent = 0;
    const docs = snap.docs;

    for (let i = 0; i < docs.length; i++) {
      if (sent >= 150) break;
      const rank = i + 1;
      const doc = docs[i];
      const uid = doc.id;
      const pts = Number(doc.data()?.points ?? 0) || 0;
      if (pts <= 0 && rank > 50) continue;

      const uSnap = await db.collection('users').doc(uid).get();
      const udata = uSnap.data() ?? {};
      if (!_notifPref(udata, 'rankingMotivation')) continue;
      const tok = udata.fcmToken;
      if (!tok) continue;

      const prefs = udata.notificationPrefs || {};
      const last = prefs.lastRankingDigestSentAt;
      if (last && typeof last.toMillis === 'function' && now - last.toMillis() < minGapMs) {
        continue;
      }

      const ord = rank === 1 ? '1er' : `${rank}e`;
      try {
        await messaging.send({
          token: tok,
          notification: {
            title: 'Classement prono DVCR',
            body: `Tu es ${ord} avec ${pts} pts — continue pour grimper !`,
          },
          data: { type: 'ranking_motivation', rank: String(rank) },
          android: {
            priority: 'normal',
            notification: { sound: 'default', channelId: 'dvcr_alerts' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        });
        await db.collection('users').doc(uid).set({
          notificationPrefs: { lastRankingDigestSentAt: Timestamp.now() },
        }, { merge: true });
        sent += 1;
      } catch (e) {
        console.error('notifyRankingMotivation', uid, e.message);
      }
    }
    console.log(`notifyRankingMotivation : ${sent} envoi(s)`);
  },
);

// —— Fin de saison prono : classements uniquement (admin only) ———————————————
// Archive + supprime prono_leaderboard ; remet rankingStats des ligues à zéro.
// Ne supprime pas ligues, duels, predictions ; ne modifie pas users.xp / pronoProfile.
exports.resetPronoSeason = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifie');

  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const role = userDoc.exists ? userDoc.data().role : '';
  if (role !== 'admin') throw new Error('Acces refuse');

  const season = String(request.data?.season ?? '').trim() || 'saison_inconnue';
  const archiveId = `archive_${season.replace(/[^a-zA-Z0-9_-]/g, '_')}_${Date.now()}`;
  const archiveRef = db.collection('season_archives').doc(archiveId);
  const resetAt = Timestamp.now();

  await archiveRef.set({
    type: 'prono_rankings_reset',
    season,
    startedAt: resetAt,
    startedBy: request.auth.uid,
  }, { merge: true });

  const counts = {};
  counts.pronoLeaderboard = await _archiveAndDeleteCollection(db, archiveRef, 'prono_leaderboard');

  const leaguesSnap = await db.collection('private_leagues').get();
  let privateLeaguesUpdated = 0;
  for (let i = 0; i < leaguesSnap.docs.length; i += 400) {
    const chunk = leaguesSnap.docs.slice(i, i + 400);
    const batch = db.batch();
    for (const doc of chunk) {
      const data = doc.data() || {};
      const memberIds = (Array.isArray(data.memberIds) ? data.memberIds : [])
        .map((id) => String(id))
        .filter((id) => id.length > 0);
      const prevRs = data.rankingStats || {};
      const memberCount = memberIds.length > 0
        ? memberIds.length
        : Number(prevRs.memberCount || 0);
      batch.set(doc.ref, {
        rankingStats: {
          memberPointsSum: 0,
          memberCount,
          updatedAt: FieldValue.serverTimestamp(),
        },
        lastRankingsResetSeason: season,
        lastRankingsResetAt: resetAt,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      privateLeaguesUpdated++;
    }
    await batch.commit();
  }
  counts.privateLeaguesUpdated = privateLeaguesUpdated;

  await archiveRef.set({
    counts,
    completedAt: Timestamp.now(),
  }, { merge: true });

  return {
    success: true,
    archiveId,
    season,
    counts,
  };
});

// ── Formate ISO 8601 duration → "mm:ss" ou "hh:mm:ss" ────────────────────────
function _formatDuration(iso) {
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return '';
  const h = parseInt(match[1] ?? 0);
  const m = parseInt(match[2] ?? 0);
  const s = parseInt(match[3] ?? 0);
  if (h > 0) return `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
  return `${m}:${String(s).padStart(2,'0')}`;
}

async function _archiveAndDeleteCollection(db, archiveRef, collectionName, options = {}) {
  const snap = await db.collection(collectionName).get();
  if (snap.empty) return 0;

  const subcollections = options.subcollections ?? [];
  let processed = 0;

  for (let i = 0; i < snap.docs.length; i += 200) {
    const chunk = snap.docs.slice(i, i + 200);
    const archiveBatch = db.batch();
    const deleteBatch = db.batch();

    for (const doc of chunk) {
      archiveBatch.set(
        archiveRef.collection(collectionName).doc(doc.id),
        {
          ...doc.data(),
          _archivedAt: Timestamp.now(),
          _sourceCollection: collectionName,
        },
      );

      for (const subName of subcollections) {
        const subSnap = await doc.ref.collection(subName).get();
        if (!subSnap.empty) {
          const subArchiveBatch = db.batch();
          const subDeleteBatch = db.batch();
          for (const subDoc of subSnap.docs) {
            subArchiveBatch.set(
              archiveRef.collection(`${collectionName}_${subName}`).doc(`${doc.id}__${subDoc.id}`),
              {
                parentId: doc.id,
                ...subDoc.data(),
                _archivedAt: Timestamp.now(),
                _sourceCollection: `${collectionName}/${doc.id}/${subName}`,
              },
            );
            subDeleteBatch.delete(subDoc.ref);
          }
          await subArchiveBatch.commit();
          await subDeleteBatch.commit();
        }
      }

      deleteBatch.delete(doc.ref);
      processed++;
    }

    await archiveBatch.commit();
    await deleteBatch.commit();
  }

  return processed;
}

// ═══════════════════════════════════════════════════════════════════════════════
// XP & BADGE SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

// ── Valeurs XP par défaut (fallback si app_settings/xp_config manquant) ───────
const DEFAULT_XP = {
  vote_prono:     5,
  prono_correct: 20,
  article_read:   2,
  chat_message:   1,
  match_comment:  3,
  share_app:     10,
  daily_login:    5,
  badge_earned:  15,
  referral_sent: 50,  // parrain
  referral_used: 25,  // filleul
  emission_poll_vote: 3,
  motm_vote:          3,
  replay_watched:     2,
  profile_complete:   10,
  favorite_team_set:  5,
};

/** @param {any} raw @param {number} defaultXp */
function _parseEventEntry(raw, defaultXp) {
  if (raw == null || raw === undefined) {
    return { xp: defaultXp, enabled: true };
  }
  if (typeof raw === 'number') {
    return { xp: raw, enabled: true };
  }
  if (typeof raw === 'object' && raw !== null) {
    const n = Number(raw.xp);
    const xp = Number.isFinite(n) ? n : defaultXp;
    const enabled = raw.enabled !== false;
    return { xp, enabled };
  }
  return { xp: defaultXp, enabled: true };
}

/** XP effectif pour un type d'événement (0 si désactivé). */
function _eventXpFromConfig(events, eventType) {
  const def = DEFAULT_XP[eventType] ?? 0;
  const p = _parseEventEntry(events[eventType], def);
  if (!p.enabled) return { xp: 0, enabled: false };
  return { xp: Math.max(0, p.xp), enabled: true };
}

// ── Niveaux par défaut ─────────────────────────────────────────────────────────
const DEFAULT_LEVELS = [
  { level: 1, name: 'Novice',        xpRequired: 0    },
  { level: 2, name: 'Supporter',     xpRequired: 100  },
  { level: 3, name: 'Ultras',        xpRequired: 300  },
  { level: 4, name: 'Légion Sedan',  xpRequired: 700  },
  { level: 5, name: 'Légende',       xpRequired: 1500 },
];

// ── Utilitaire : calcule le niveau à partir des XP ────────────────────────────
function _computeLevel(xp, levels) {
  const sorted = [...levels].sort((a, b) => b.xpRequired - a.xpRequired);
  for (const lvl of sorted) {
    if (xp >= lvl.xpRequired) return lvl.level;
  }
  return 1;
}

// ── Utilitaire : lit la config XP depuis Firestore ────────────────────────────
async function _getXpConfig(db) {
  const [configSnap, levelsSnap] = await Promise.all([
    db.collection('app_settings').doc('xp_config').get(),
    db.collection('app_settings').doc('xp_levels').get(),
  ]);
  const events = configSnap.exists ? (configSnap.data().events ?? {}) : {};
  const levels = levelsSnap.exists ? (levelsSnap.data().levels ?? DEFAULT_LEVELS) : DEFAULT_LEVELS;
  return { events, levels };
}

// ── Utilitaire : vérifie et attribue les badges ───────────────────────────────
async function _checkBadges(db, uid, userData) {
  const badgesSnap = await db.collection('badges').get();
  if (badgesSnap.empty) return;

  const earned = new Set(userData.badges ?? []);
  const stats  = userData.stats ?? {};
  const xp     = userData.xp ?? 0;

  const batch      = db.batch();
  let   newBadges  = 0;
  let   xpFromBadges = 0;

  for (const doc of badgesSnap.docs) {
    if (earned.has(doc.id)) continue; // déjà obtenu

    const badge     = doc.data();
    const condition = (badge.condition ?? '').trim();
    if (!condition) continue;

    let unlocked = false;

    // Syntaxe : "xp >= 1000" | "prono_correct >= 10" | "article_read >= 5"
    const match = condition.match(/^(\w+)\s*(>=|>|==|<=|<)\s*(\d+)$/);
    if (match) {
      const [, field, op, valStr] = match;
      const threshold = parseInt(valStr, 10);
      let   current   = 0;

      if (field === 'xp') {
        current = xp;
      } else {
        current = typeof stats[field] === 'number' ? stats[field] : 0;
      }

      switch (op) {
        case '>=': unlocked = current >= threshold; break;
        case '>':  unlocked = current >  threshold; break;
        case '==': unlocked = current === threshold; break;
        case '<=': unlocked = current <= threshold; break;
        case '<':  unlocked = current <  threshold; break;
      }
    }

    if (unlocked) {
      earned.add(doc.id);
      xpFromBadges += (badge.xpReward ?? 0);
      newBadges++;

      // Log badge dans l'historique
      batch.set(
        db.collection('users').doc(uid).collection('badge_log').doc(doc.id),
        { badgeId: doc.id, name: badge.name, emoji: badge.emoji, earnedAt: Timestamp.now() },
      );
    }
  }

  if (newBadges === 0) return;

  batch.update(db.collection('users').doc(uid), {
    badges: [...earned],
    ...(xpFromBadges > 0 ? { xp: FieldValue.increment(xpFromBadges) } : {}),
    updatedAt: Timestamp.now(),
  });

  // Log dans admin_logs
  batch.set(db.collection('admin_logs').doc(), {
    action: `${newBadges} badge(s) attribué(s) automatiquement`,
    type: 'badge',
    adminName: 'Système',
    target: uid,
    timestamp: Timestamp.now(),
  });

  await batch.commit();
}

// ── awardXp (onCall) — appelé depuis l'app pour chaque action utilisateur ─────
exports.awardXp = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');

  const uid       = request.auth.uid;
  const eventType = request.data?.eventType;
  if (!eventType) throw new Error('eventType manquant');

  const db = getFirestore();
  const { events, levels } = await _getXpConfig(db);

  const ev = _eventXpFromConfig(events, eventType);
  const xpValue = ev.xp;
  if (!ev.enabled || xpValue === 0) {
    return { success: true, xpAwarded: 0, disabled: !ev.enabled };
  }

  // Lire l'utilisateur
  const userRef  = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new Error('Utilisateur introuvable');

  const userData = userSnap.data();
  const newXp    = (userData.xp ?? 0) + xpValue;
  const newLevel = _computeLevel(newXp, levels);
  const oldLevel = userData.level ?? 1;

  // Anti-spam : limite certains événements à 1x/jour
  const DAILY_CAPPED = ['article_read', 'chat_message', 'daily_login'];
  if (DAILY_CAPPED.includes(eventType)) {
    const today     = new Date().toISOString().split('T')[0];
    const logRef    = userRef.collection('xp_daily').doc(`${eventType}_${today}`);
    const logSnap   = await logRef.get();
    if (logSnap.exists && (logSnap.data().count ?? 0) >= _dailyCap(eventType)) {
      return { success: true, xpAwarded: 0, capped: true };
    }
    await logRef.set({ count: FieldValue.increment(1), date: today }, { merge: true });
  }

  // Update user
  await userRef.update({
    xp:        newXp,
    level:     newLevel,
    updatedAt: Timestamp.now(),
    [`stats.${eventType}`]: FieldValue.increment(1),
  });

  // Log XP
  await userRef.collection('xp_log').add({
    eventType, xpAwarded: xpValue, totalAfter: newXp, timestamp: Timestamp.now(),
  });

  // Vérif badges avec les nouvelles stats
  const updatedUser = { ...userData, xp: newXp, stats: { ...(userData.stats ?? {}), [eventType]: ((userData.stats ?? {})[eventType] ?? 0) + 1 } };
  await _checkBadges(db, uid, updatedUser);

  return {
    success:      true,
    xpAwarded:    xpValue,
    newXp,
    newLevel,
    leveledUp:    newLevel > oldLevel,
  };
});

function _dailyCap(eventType) {
  const caps = { article_read: 5, chat_message: 20, daily_login: 1 };
  return caps[eventType] ?? 10;
}

// ── onMatchFinished — évalue les pronos quand un match passe à 'finished' ──────
exports.onMatchFinished = onDocumentWritten('matches/{matchId}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return;

  // Ne se déclenche que sur le passage à 'finished'
  const wasFinished = before?.status === 'finished';
  const isFinished  = after.status === 'finished';
  if (wasFinished || !isFinished) return;

  const score1 = after.score1;
  const score2 = after.score2;
  if (score1 == null || score2 == null) return;

  const db      = getFirestore();
  const matchId = event.params.matchId;

  // Résultat réel : 'home' | 'draw' | 'away'
  const actualResult = score1 > score2 ? 'home' : score1 < score2 ? 'away' : 'draw';

  // Récupère tous les pronos pour ce match
  const pronosSnap = await db.collection('pronos')
    .where('matchId', '==', matchId)
    .get();

  if (pronosSnap.empty) return;

  const { events, levels } = await _getXpConfig(db);
  const xpCorrect = _eventXpFromConfig(events, 'prono_correct').xp;

  const batch = db.batch();
  let   evaluated = 0;

  for (const pronoDoc of pronosSnap.docs) {
    const prono     = pronoDoc.data();
    const uid       = prono.uid;
    const predicted = prono.result; // 'home' | 'draw' | 'away'
    const isCorrect = predicted === actualResult;

    // Marque le prono comme évalué
    batch.update(pronoDoc.ref, {
      evaluated:    true,
      correct:      isCorrect,
      actualResult,
      evaluatedAt:  Timestamp.now(),
    });

    if (!isCorrect) continue;

    // Mise à jour user XP + stats
    const userRef = db.collection('users').doc(uid);
    batch.update(userRef, {
      xp:                        FieldValue.increment(xpCorrect),
      'stats.prono_correct':     FieldValue.increment(1),
      'stats.prono_total':       FieldValue.increment(1),
      updatedAt:                 Timestamp.now(),
    });

    // Log XP
    batch.set(userRef.collection('xp_log').doc(), {
      eventType: 'prono_correct', xpAwarded: xpCorrect,
      matchId, timestamp: Timestamp.now(),
    });

    evaluated++;
  }

  // Met à jour les pronos non corrects aussi (total)
  for (const pronoDoc of pronosSnap.docs) {
    const prono = pronoDoc.data();
    if (!prono.correct) {
      const userRef = db.collection('users').doc(prono.uid);
      batch.update(userRef, { 'stats.prono_total': FieldValue.increment(1) });
    }
  }

  await batch.commit();

  // Vérif badges pour chaque utilisateur correct (hors batch car lecture nécessaire)
  for (const pronoDoc of pronosSnap.docs) {
    const prono = pronoDoc.data();
    if (!prono.correct) continue;
    const userSnap = await db.collection('users').doc(prono.uid).get();
    if (userSnap.exists) await _checkBadges(db, prono.uid, userSnap.data());
  }

  console.log(`Match ${matchId} évalué : ${evaluated}/${pronosSnap.size} pronos corrects`);
});

// ── onXpUpdate — recalcule le niveau quand l'XP change ───────────────────────
exports.onXpUpdate = onDocumentWritten('users/{uid}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after || !before) return;

  const xpBefore = before.xp ?? 0;
  const xpAfter  = after.xp  ?? 0;
  if (xpBefore === xpAfter) return; // Pas de changement XP

  const db  = getFirestore();
  const uid = event.params.uid;
  const { levels } = await _getXpConfig(db);

  const correctLevel = _computeLevel(xpAfter, levels);
  if (correctLevel === (after.level ?? 1)) return; // Niveau déjà correct

  await db.collection('users').doc(uid).update({ level: correctLevel, updatedAt: Timestamp.now() });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SYSTÈME DE PARRAINAGE
// ═══════════════════════════════════════════════════════════════════════════════

// ── Génère un code de parrainage à la création du document user ───────────────
exports.onUserDocCreated = onDocumentCreated('users/{uid}', async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const uid  = event.params.uid;
  const db = getFirestore();
  const code = data.referralCode || ('DVCR' + uid.slice(0, 4).toUpperCase() + _randomStr(4));
  const emailLower = _toSafeString(data.emailLower || data.email).toLowerCase();

  await db.runTransaction(async (tx) => {
    const userRef = event.data.ref;
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || data;
    const baseUpdates = {
      referralCode: userData.referralCode || code,
      referredBy: userData.referredBy ?? null,
      createdAt: userData.createdAt ?? Timestamp.now(),
      emailLower: emailLower || null,
    };

    if (!emailLower) {
      tx.set(userRef, baseUpdates, { merge: true });
      return;
    }

    const pendingSnap = await db.collection('helloasso_pending_matches')
      .where('payerEmailLower', '==', emailLower)
      .get();

    if (pendingSnap.empty) {
      tx.set(userRef, baseUpdates, { merge: true });
      return;
    }

    const nowMs = Date.now();
    let totalAmount = Number(userData.totalDonations || 0);
    let latestExpiry = null;
    let latestPaymentId = null;
    let latestOrderId = null;

    for (const doc of pendingSnap.docs) {
      const pendingData = doc.data() || {};
      if (pendingData.status !== 'pending') {
        continue;
      }

      const expiresAt = pendingData.expiresAt;
      const expiresAtMs = expiresAt?.toDate ? expiresAt.toDate().getTime() : 0;
      if (!expiresAtMs || expiresAtMs <= nowMs) {
        tx.set(doc.ref, {
          status: 'expired',
          expiredAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        continue;
      }

      totalAmount += Number(pendingData.amount || 0);
      if (!latestExpiry || expiresAtMs > latestExpiry.toDate().getTime()) {
        latestExpiry = expiresAt;
        latestPaymentId = pendingData.paymentId || null;
        latestOrderId = pendingData.orderId || null;
      }

      const grantKey = _toSafeString(
        pendingData.grantKey || pendingData.paymentId || pendingData.orderId || doc.id
      );
      tx.set(db.collection('helloasso_processed_payments').doc(grantKey), {
        userId: uid,
        paymentId: pendingData.paymentId || null,
        orderId: pendingData.orderId || null,
        eventId: pendingData.eventId || null,
        amount: Number(pendingData.amount || 0),
        state: pendingData.state || null,
        expiresAt: pendingData.expiresAt || null,
        processedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      tx.set(db.collection('donations').doc(`helloasso_${grantKey}`), {
        userId: uid,
        source: 'helloasso',
        method: 'helloasso',
        amount: Number(pendingData.amount || 0),
        status: 'completed',
        payerEmail: pendingData.payerEmail || emailLower,
        paymentId: pendingData.paymentId || null,
        orderId: pendingData.orderId || null,
        eventType: pendingData.eventType || 'Payment',
        metadata: pendingData.metadata || {},
        paidAt: pendingData.paidAt || null,
        expiresAt: pendingData.expiresAt || null,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      tx.set(doc.ref, {
        status: 'matched',
        matchedUserId: uid,
        matchedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    if (!latestExpiry) {
      tx.set(userRef, baseUpdates, { merge: true });
      return;
    }

    const currentRoles = Array.isArray(userData.roles)
      ? userData.roles.filter(Boolean).map((role) => role.toString())
      : [];
    const mergedRoles = Array.from(new Set([...currentRoles, HELLOASSO_DONATEUR_ROLE]));

    tx.set(userRef, {
      ...baseUpdates,
      ..._buildHelloAssoUserPatch(userData, {
        amount: totalAmount,
        paymentId: latestPaymentId,
        orderId: latestOrderId,
        expiresAt: latestExpiry,
        mergedRoles,
        nextTotal: totalAmount,
      }),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
});

function _randomStr(len) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let result  = '';
  for (let i = 0; i < len; i++) result += chars[Math.floor(Math.random() * chars.length)];
  return result;
}

// ── useReferralCode (onCall) — valide et applique un code de parrainage ───────
exports.useReferralCode = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');

  const uid  = request.auth.uid;
  const code = (request.data?.code ?? '').trim().toUpperCase();
  if (!code) throw new Error('Code manquant');

  const db = getFirestore();

  // Vérifie que l'utilisateur n'a pas déjà utilisé un code
  const selfSnap = await db.collection('users').doc(uid).get();
  if (!selfSnap.exists) throw new Error('Utilisateur introuvable');
  const selfData = selfSnap.data();

  if (selfData.referredBy != null) {
    throw new Error('Tu as déjà utilisé un code de parrainage');
  }
  if (selfData.referralCode === code) {
    throw new Error('Tu ne peux pas utiliser ton propre code');
  }

  // Trouve le parrain
  const referrerSnap = await db.collection('users')
    .where('referralCode', '==', code)
    .limit(1)
    .get();

  if (referrerSnap.empty) throw new Error('Code invalide');

  const referrerDoc  = referrerSnap.docs[0];
  const referrerUid  = referrerDoc.id;
  const referrerData = referrerDoc.data();

  const { events, levels } = await _getXpConfig(db);
  const xpParrain = _eventXpFromConfig(events, 'referral_sent').xp;
  const xpFilleul = _eventXpFromConfig(events, 'referral_used').xp;

  const batch = db.batch();

  // Filleul — marque comme parrainé + XP
  const newXpFilleul    = (selfData.xp ?? 0) + xpFilleul;
  const newLevelFilleul = _computeLevel(newXpFilleul, levels);
  batch.update(db.collection('users').doc(uid), {
    referredBy: referrerUid,
    xp:         newXpFilleul,
    level:      newLevelFilleul,
    updatedAt:  Timestamp.now(),
  });
  batch.set(db.collection('users').doc(uid).collection('xp_log').doc(), {
    eventType: 'referral_used', xpAwarded: xpFilleul, timestamp: Timestamp.now(),
  });

  // Parrain — XP
  const newXpParrain    = (referrerData.xp ?? 0) + xpParrain;
  const newLevelParrain = _computeLevel(newXpParrain, levels);
  batch.update(db.collection('users').doc(referrerUid), {
    xp:        newXpParrain,
    level:     newLevelParrain,
    'stats.referral_sent': FieldValue.increment(1),
    updatedAt: Timestamp.now(),
  });
  batch.set(db.collection('users').doc(referrerUid).collection('xp_log').doc(), {
    eventType: 'referral_sent', xpAwarded: xpParrain,
    referredUid: uid, timestamp: Timestamp.now(),
  });

  // Compteur parrainage global
  batch.set(db.collection('referrals').doc(), {
    referrerUid, referredUid: uid, code,
    xpParrain, xpFilleul,
    createdAt: Timestamp.now(),
  });

  await batch.commit();

  return {
    success:        true,
    xpAwarded:      xpFilleul,
    referrerName:   referrerData.displayName ?? 'Supporter',
  };
});

// ── getReferralStats (onCall) — stats de parrainage pour le profil ─────────────
exports.getReferralStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new Error('Non authentifié');
  const uid = request.auth.uid;
  const db  = getFirestore();

  const [userSnap, referralsSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('referrals').where('referrerUid', '==', uid).get(),
  ]);

  const userData = userSnap.data() ?? {};

  return {
    referralCode:  userData.referralCode ?? '',
    referredBy:    userData.referredBy   ?? null,
    referralCount: referralsSnap.size,
    totalXpEarned: referralsSnap.size * (DEFAULT_XP.referral_sent),
  };
});

// ── Classement hebdomadaire XP (vendredi minuit) ───────────────────────────────
exports.weeklyXpLeaderboard = onSchedule('every friday 23:00', async () => {
  const db   = getFirestore();
  const snap = await db.collection('users')
    .orderBy('xp', 'desc')
    .limit(10)
    .get();

  const top = snap.docs.map((d, i) => ({
    rank:        i + 1,
    uid:         d.id,
    displayName: d.data().displayName ?? 'Supporter',
    xp:          d.data().xp ?? 0,
    level:       d.data().level ?? 1,
  }));

  await db.collection('app_settings').doc('weekly_leaderboard').set({
    top,
    updatedAt: Timestamp.now(),
    weekOf:    new Date().toISOString().split('T')[0],
  });

  console.log(`Classement hebdo mis à jour : ${top.length} entrées`);
});


// ── Auto-scoring tournoi ──────────────────────────────────────────────────────
// 1) Premier enregistrement en « finished » + result1/result2 → attribue les points.
// 2) Match déjà terminé mais résultat modifié → recalcule chaque prono et ajuste
//    le leaderboard par delta (points + exactScores), puis rerank.
// Chaque participant au match reçoit une ligne leaderboard (même +0 / +0) pour que
// orderBy('points') ne les exclue pas (sinon écran « classement vide » alors qu’il y a des pronos).
/**
 * @param {import('firebase-admin/firestore').Firestore} db
 * @param {{ silent?: boolean }} opts silent = pas de push (recalcul admin).
 */
async function applyTournamentMatchFinishedScoring(
  db, tournamentId, matchId, after, before, opts = {},
) {
  const silent = opts.silent === true;
  if (!after) return { skipped: true, reason: 'no_after' };

  if (after.status !== 'finished') return { skipped: true, reason: 'not_finished' };
  if (after.result1 == null || after.result2 == null) {
    return { skipped: true, reason: 'no_results' };
  }

  const r1 = Number(after.result1);
  const r2 = Number(after.result2);
  if (!Number.isFinite(r1) || !Number.isFinite(r2)) {
    return { skipped: true, reason: 'bad_results' };
  }

  const wasFinished = before?.status === 'finished';
  const prevR1 = before != null ? Number(before.result1) : NaN;
  const prevR2 = before != null ? Number(before.result2) : NaN;
  const resultUnchanged =
    wasFinished &&
    Number.isFinite(prevR1) &&
    Number.isFinite(prevR2) &&
    prevR1 === r1 &&
    prevR2 === r2;

  if (wasFinished && resultUnchanged) return { skipped: true, reason: 'unchanged' };

  const isRecalc = wasFinished && !resultUnchanged;

  const resultSign = Math.sign(r1 - r2);

  const predsSnap = await db
    .collection('tournaments').doc(tournamentId)
    .collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  if (predsSnap.empty) {
    if (isRecalc) {
      console.log(
        `Tournoi ${tournamentId} / match ${matchId} résultat modifié — aucun prono.`,
      );
    }
    return { skipped: true, reason: 'no_predictions', predictions: 0 };
  }

  const batch = db.batch();
  const deltaByUid = {};
  const deltaExactByUid = {};
  const uidsTouched = new Set();

  for (const predDoc of predsSnap.docs) {
    const pred = predDoc.data();
    const uid  = pred.uid;
    if (!uid) continue;
    uidsTouched.add(uid);

    const p1 = Number(pred.score1);
    const p2 = Number(pred.score2);

    let newPts = 0;
    if (Number.isFinite(p1) && Number.isFinite(p2)) {
      const predSign = Math.sign(p1 - p2);
      if (p1 === r1 && p2 === r2) {
        newPts = 3;
      } else if (predSign === resultSign) {
        newPts = 1;
      }
    }

    const oldPts = isRecalc ? Math.max(0, Number(pred.points ?? 0)) : 0;
    const dPts = newPts - oldPts;
    const dExact =
      (newPts === 3 ? 1 : 0) - (oldPts === 3 ? 1 : 0);

    batch.update(predDoc.ref, { points: newPts });

    if (!deltaByUid[uid]) {
      deltaByUid[uid] = 0;
      deltaExactByUid[uid] = 0;
    }
    deltaByUid[uid] += dPts;
    deltaExactByUid[uid] += dExact;
  }

  for (const uid of uidsTouched) {
    const dPts = deltaByUid[uid] ?? 0;
    const dEx = deltaExactByUid[uid] ?? 0;

    const lbRef = db
      .collection('tournaments').doc(tournamentId)
      .collection('leaderboard').doc(uid);

    const userSnap = await db.collection('users').doc(uid).get();
    const displayName = userSnap.data()?.displayName ?? 'Supporter';
    const avatarUrl   = userSnap.data()?.avatarUrl ?? null;

    batch.set(lbRef, {
      displayName,
      avatarUrl,
      updatedAt: Timestamp.now(),
      points: FieldValue.increment(dPts),
      exactScores: FieldValue.increment(dEx),
    }, { merge: true });
  }

  await batch.commit();

  if (!wasFinished && !silent) {
    const messaging = getMessaging();
    const tMeta = await db.collection('tournaments').doc(tournamentId).get();
    const tName = (tMeta.data()?.name || tMeta.data()?.title || 'Tournoi').toString();

    for (const uid of Object.keys(deltaByUid)) {
      const dPts = deltaByUid[uid];
      if (!dPts) continue;
      const uSnap = await db.collection('users').doc(uid).get();
      const udata = uSnap.data() ?? {};
      if (!_notifPref(udata, 'tournamentPronoPoints')) continue;
      const tok = udata.fcmToken;
      if (!tok) continue;
      try {
        await messaging.send({
          token: tok,
          notification: {
            title: 'Coupe du monde — prono',
            body: `Tu gagnes +${dPts} pts sur ce match (${tName}).`,
          },
          data: {
            type: 'wc_prono_points',
            tournamentId: String(tournamentId),
            matchId: String(matchId),
            points: String(dPts),
          },
          android: {
            priority: 'high',
            notification: { sound: 'default', channelId: 'dvcr_alerts' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        });
      } catch (e) {
        console.error('wc prono FCM:', e.message);
      }
    }
  }

  console.log(
    `Tournoi ${tournamentId} / match ${matchId} ` +
      `${isRecalc ? 'recalcul résultat' : 'scoré'} : ${predsSnap.size} prédictions`,
  );

  await _recalcTournamentLeaderboardRanks(db, tournamentId);
  return { skipped: false, predictions: predsSnap.size };
}

exports.scoreTournamentMatch = onDocumentWritten(
  'tournaments/{tournamentId}/matches/{matchId}',
  async (event) => {
    const after  = event.data.after.data();
    const before = event.data.before.data();
    const db = getFirestore();
    const { tournamentId, matchId } = event.params;
    await applyTournamentMatchFinishedScoring(
      db, tournamentId, matchId, after, before, { silent: false },
    );
  }
);

/** Recalcule rank 1..N sur tournaments/{id}/leaderboard (points desc, exacts, uid). */
async function _recalcTournamentLeaderboardRanks(db, tournamentId) {
  const col = db.collection('tournaments').doc(tournamentId).collection('leaderboard');
  const snap = await col.get();
  if (snap.empty) return;

  const rows = snap.docs.map((d) => ({ ref: d.ref, id: d.id, data: d.data() ?? {} }));
  rows.sort((a, b) => {
    const pa = a.data.points ?? 0;
    const pb = b.data.points ?? 0;
    if (pb !== pa) return pb - pa;
    const ea = a.data.exactScores ?? 0;
    const eb = b.data.exactScores ?? 0;
    if (eb !== ea) return eb - ea;
    return String(a.id).localeCompare(String(b.id));
  });

  let batch = db.batch();
  let ops = 0;
  let rank = 1;
  for (const row of rows) {
    const currentRank = rank;
    batch.set(row.ref, { rank: currentRank }, { merge: true });
    rank += 1;
    ops += 1;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();
  console.log(`Rangs tournoi ${tournamentId} : ${rows.length} entrées`);
}

// ── Sync Coupe du Monde 2026 — api-football.com (RapidAPI) ───────────────────
// Une seule requête par jour suffit pour récupérer tous les matchs + résultats.
// Remplace YOUR_RAPIDAPI_KEY par ta clé sur https://rapidapi.com/api-sports/api/api-football
const RAPIDAPI_KEY = '8190e8af48240a8d675cc902f0afa9d7';
const WC_LEAGUE    = 1;    // FIFA World Cup sur api-football
const WC_SEASON    = 2026;
const TOURNAMENT_ID = 'worldcup2026';

// Mappings statut api-football → statut Firestore
function toStatus(short) {
  const done = ['FT', 'AET', 'PEN', 'AWD', 'WO'];
  const live = ['1H', '2H', 'ET', 'BT', 'P', 'INT', 'LIVE'];
  if (done.includes(short)) return 'finished';
  if (live.includes(short)) return 'live';
  return 'upcoming';
}

// Phase : api-football renvoie "Group Stage - 1", "Quarter-finals", etc.
// On traduit en français simplifié.
function toPhase(round) {
  if (!round) return 'Phase de groupes';
  const r = round.toLowerCase();
  if (r.includes('group'))    return 'Phase de groupes';
  if (r.includes('round of 16') || r.includes('8th')) return 'Huitièmes de finale';
  if (r.includes('quarter'))  return 'Quarts de finale';
  if (r.includes('semi'))     return 'Demi-finales';
  if (r.includes('3rd'))      return 'Petite finale';
  if (r.includes('final'))    return 'Finale';
  return round;
}

exports.syncWorldCupFixtures = onSchedule(
  { schedule: 'every 24 hours', timeZone: 'Europe/Paris', region: 'europe-west1' },
  async () => {
    const url = `https://v3.football.api-sports.io/fixtures?league=${WC_LEAGUE}&season=${WC_SEASON}`;
    const res = await fetch(url, {
      headers: { 'x-apisports-key': RAPIDAPI_KEY },
    });

    if (!res.ok) {
      console.error(`API error ${res.status}: ${await res.text()}`);
      return;
    }

    const json = await res.json();
    const fixtures = json.response ?? [];
    console.log(`syncWorldCupFixtures: ${fixtures.length} matchs récupérés`);

    const db = getFirestore();

    // Crée/met à jour le document tournoi
    await db.collection('tournaments').doc(TOURNAMENT_ID).set({
      name:      'Coupe du Monde 2026',
      active:    true,
      season:    WC_SEASON,
      updatedAt: Timestamp.now(),
    }, { merge: true });

    // Batch writes (max 500 par batch)
    let batch = db.batch();
    let count = 0;

    for (const item of fixtures) {
      const f      = item.fixture;
      const teams  = item.teams;
      const goals  = item.goals;
      const league = item.league;
      const status = toStatus(f.status?.short ?? 'NS');

      const docRef = db
        .collection('tournaments').doc(TOURNAMENT_ID)
        .collection('matches').doc(String(f.id));

      const data = {
        team1:  teams.home.name,
        team2:  teams.away.name,
        flag1:  teams.home.logo ?? '',
        flag2:  teams.away.logo ?? '',
        date:   Timestamp.fromDate(new Date(f.date)),
        status,
        phase:  toPhase(league.round),
        venue:  f.venue?.name ?? '',
        apiId:  f.id,
      };

      // N'écrase les résultats que si le match est terminé ou en cours
      if (status === 'finished' || status === 'live') {
        data.result1 = goals.home ?? 0;
        data.result2 = goals.away ?? 0;
      }

      batch.set(docRef, data, { merge: true });
      count++;

      // Commit tous les 400 pour rester sous la limite
      if (count % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }

    if (count % 400 !== 0) {
      await batch.commit();
    }

    console.log(`syncWorldCupFixtures: ${count} matchs synchronisés dans Firestore`);
  }
);

// ── Sync manuelle (callable depuis l'admin panel) ─────────────────────────────
exports.syncWorldCupNow = onCall({ region: 'europe-west1' }, async (request) => {
  // Vérifie que l'appelant est admin
  const uid = request.auth?.uid;
  if (!uid) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();
  const roles = userDoc.data()?.roles ?? [];
  if (!roles.includes('admin') && !roles.includes('superadmin')) {
    throw new Error('Accès refusé');
  }

  const url = `https://v3.football.api-sports.io/fixtures?league=${WC_LEAGUE}&season=${WC_SEASON}`;
  const res = await fetch(url, {
    headers: { 'x-apisports-key': RAPIDAPI_KEY },
  });

  const json = await res.json();
  console.log(`API status: ${res.status}, errors: ${JSON.stringify(json.errors)}, fixtures count: ${json.results}`);

  if (!res.ok || json.errors?.token || json.errors?.requests) {
    throw new Error(`API error: ${JSON.stringify(json.errors)} (status ${res.status})`);
  }

  const fixtures = json.response ?? [];

  await db.collection('tournaments').doc(TOURNAMENT_ID).set({
    name: 'Coupe du Monde 2026', active: true, season: WC_SEASON,
    updatedAt: Timestamp.now(),
  }, { merge: true });

  let batch = db.batch();
  let count = 0;

  for (const item of fixtures) {
    const f      = item.fixture;
    const teams  = item.teams;
    const goals  = item.goals;
    const league = item.league;
    const status = toStatus(f.status?.short ?? 'NS');

    const docRef = db
      .collection('tournaments').doc(TOURNAMENT_ID)
      .collection('matches').doc(String(f.id));

    const data = {
      team1: teams.home.name, team2: teams.away.name,
      flag1: teams.home.logo ?? '', flag2: teams.away.logo ?? '',
      date:  Timestamp.fromDate(new Date(f.date)),
      status, phase: toPhase(league.round),
      venue: f.venue?.name ?? '', apiId: f.id,
    };
    if (status === 'finished' || status === 'live') {
      data.result1 = goals.home ?? 0;
      data.result2 = goals.away ?? 0;
    }

    batch.set(docRef, data, { merge: true });
    count++;
    if (count % 400 === 0) { await batch.commit(); batch = db.batch(); }
  }
  if (count % 400 !== 0) await batch.commit();

  return { synced: count };
});

// ── Annuler le scoring d’un seul match CdM (admin) ───────────────────────────
// Remet les points du match à 0 sur chaque prono, retire le delta du leaderboard,
// remet le match en « upcoming » sans score. Ne touche pas aux autres matchs.
exports.undoWorldCupMatchScoring = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();
  const roles = userDoc.data()?.roles ?? [];
  if (!roles.includes('admin') && !roles.includes('superadmin')) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const matchId = request.data?.matchId;
  if (matchId == null || String(matchId).trim() === '') {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }
  const mid = String(matchId).trim();

  const tournamentId = TOURNAMENT_ID;
  const tRef = db.collection('tournaments').doc(tournamentId);
  const matchRef = tRef.collection('matches').doc(mid);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) {
    throw new HttpsError('not-found', `Match ${mid} introuvable`);
  }

  const predsSnap = await tRef
    .collection('predictions')
    .where('matchId', '==', mid)
    .get();

  const uidDeduct = new Map();
  for (const predDoc of predsSnap.docs) {
    const pred = predDoc.data() || {};
    const puid = pred.uid;
    if (!puid) continue;
    const rawPts = Number(pred.points ?? 0);
    const pts = Number.isFinite(rawPts) ? Math.max(0, Math.min(3, rawPts)) : 0;
    const ex = pts === 3 ? 1 : 0;
    const cur = uidDeduct.get(puid) || { pts: 0, ex: 0 };
    cur.pts += pts;
    cur.ex += ex;
    uidDeduct.set(puid, cur);
  }

  const predDocs = predsSnap.docs;
  for (let i = 0; i < predDocs.length; i += 400) {
    const batch = db.batch();
    const end = Math.min(i + 400, predDocs.length);
    for (let j = i; j < end; j++) {
      batch.update(predDocs[j].ref, { points: 0 });
    }
    await batch.commit();
  }

  const lbOps = [];
  for (const [puid, d] of uidDeduct.entries()) {
    if (d.pts === 0 && d.ex === 0) continue;
    const lbRef = tRef.collection('leaderboard').doc(puid);
    const lbSnap = await lbRef.get();
    if (!lbSnap.exists) continue;
    const curP = Math.max(0, Number(lbSnap.data()?.points ?? 0));
    const curE = Math.max(0, Number(lbSnap.data()?.exactScores ?? 0));
    lbOps.push({
      ref: lbRef,
      newP: Math.max(0, curP - d.pts),
      newE: Math.max(0, curE - d.ex),
    });
  }

  for (let i = 0; i < lbOps.length; i += 400) {
    const batch = db.batch();
    const end = Math.min(i + 400, lbOps.length);
    for (let j = i; j < end; j++) {
      const x = lbOps[j];
      batch.set(
        x.ref,
        {
          points: x.newP,
          exactScores: x.newE,
          updatedAt: Timestamp.now(),
        },
        { merge: true },
      );
    }
    await batch.commit();
  }

  await matchRef.update({
    status: 'upcoming',
    result1: FieldValue.delete(),
    result2: FieldValue.delete(),
  });

  await _recalcTournamentLeaderboardRanks(db, tournamentId);

  return {
    matchId: mid,
    predictionsCleared: predDocs.length,
    leaderboardsAdjusted: lbOps.length,
  };
});

// ── Remise à zéro + recalcul classement CdM (admin) ──────────────────────────
exports.recalculateWorldCupLeaderboard = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();
  const roles = userDoc.data()?.roles ?? [];
  if (!roles.includes('admin') && !roles.includes('superadmin')) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const tRef = db.collection('tournaments').doc(TOURNAMENT_ID);

  const preds = await tRef.collection('predictions').get();
  const predDocs = preds.docs;
  for (let i = 0; i < predDocs.length; i += 400) {
    const b = db.batch();
    const end = Math.min(i + 400, predDocs.length);
    for (let j = i; j < end; j++) {
      b.update(predDocs[j].ref, { points: 0 });
    }
    await b.commit();
  }

  const lbs = await tRef.collection('leaderboard').get();
  const lbDocs = lbs.docs;
  for (let i = 0; i < lbDocs.length; i += 400) {
    const b = db.batch();
    const end = Math.min(i + 400, lbDocs.length);
    for (let j = i; j < end; j++) {
      b.delete(lbDocs[j].ref);
    }
    await b.commit();
  }

  const matchesSnap = await tRef.collection('matches').orderBy('date').get();
  let rescored = 0;
  for (const m of matchesSnap.docs) {
    const d = m.data() || {};
    if (d.status !== 'finished') continue;
    if (d.result1 == null || d.result2 == null) continue;
    const out = await applyTournamentMatchFinishedScoring(
      db, TOURNAMENT_ID, m.id, d, null, { silent: true },
    );
    if (!out.skipped) rescored++;
  }

  return {
    predictionsReset: predDocs.length,
    leaderboardDeleted: lbDocs.length,
    finishedMatchesRescored: rescored,
  };
});

// ── Seed Coupe du Monde 2026 — tous les matchs connus ────────────────────────
exports.seedWC2026 = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new Error('Non authentifié');
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();
  const roles = userDoc.data()?.roles ?? [];
  if (!roles.includes('admin') && !roles.includes('superadmin')) throw new Error('Accès refusé');

  await db.collection('tournaments').doc(TOURNAMENT_ID).set({
    name: 'Coupe du Monde 2026', active: true, season: 2026,
    updatedAt: Timestamp.now(),
  }, { merge: true });

  const FLAG = {
    'Mexique':              'mx', 'Afrique du Sud':     'za',
    'Rép. de Corée':       'kr', 'Tchéquie':           'cz',
    'Canada':              'ca', 'Bosnie-Herzégovine':  'ba',
    'Qatar':               'qa', 'Suisse':             'ch',
    'Brésil':              'br', 'Maroc':              'ma',
    'Haïti':               'ht', 'Écosse':             'gb-sct',
    'États-Unis':          'us', 'Paraguay':           'py',
    'Australie':           'au', 'Turquie':            'tr',
    'Allemagne':           'de', 'Curaçao':            'cw',
    "Côte d'Ivoire":       'ci', 'Équateur':           'ec',
    'Pays-Bas':            'nl', 'Japon':              'jp',
    'Suède':               'se', 'Tunisie':            'tn',
    'Belgique':            'be', 'Égypte':             'eg',
    'Iran':                'ir', 'Nouvelle-Zélande':   'nz',
    'Espagne':             'es', 'Cap-Vert':           'cv',
    'Arabie saoudite':     'sa', 'Uruguay':            'uy',
    'France':              'fr', 'Sénégal':            'sn',
    'Irak':                'iq', 'Norvège':            'no',
    'Argentine':           'ar', 'Algérie':            'dz',
    'Autriche':            'at', 'Jordanie':           'jo',
    'Portugal':            'pt', 'RD Congo':           'cd',
    'Ouzbékistan':         'uz', 'Colombie':           'co',
    'Angleterre':          'gb-eng', 'Croatie':        'hr',
    'Ghana':               'gh', 'Panamá':            'pa',
  };
  const flag = (name) => FLAG[name] ? `https://flagcdn.com/w80/${FLAG[name]}.png` : '';

  const M = (id, t1, t2, iso, phase, venue) => ({
    id, team1: t1, team2: t2,
    date: Timestamp.fromDate(new Date(iso)),
    phase, venue, status: 'upcoming',
    flag1: flag(t1), flag2: flag(t2),
  });

  const matches = [
    // ── Groupe A ──────────────────────────────────────────────────────────────
    M('gA1','Mexique','Afrique du Sud',          '2026-06-11T15:00:00','Groupe A','Stade de Mexico'),
    M('gA2','Rép. de Corée','Tchéquie',          '2026-06-11T22:00:00','Groupe A','Stade de Guadalajara'),
    M('gA3','Tchéquie','Afrique du Sud',          '2026-06-18T12:00:00','Groupe A','Stade d\'Atlanta'),
    M('gA4','Mexique','Rép. de Corée',            '2026-06-18T21:00:00','Groupe A','Stade de Guadalajara'),
    M('gA5','Tchéquie','Mexique',                 '2026-06-24T21:00:00','Groupe A','Stade de Mexico'),
    M('gA6','Afrique du Sud','Rép. de Corée',     '2026-06-24T21:00:00','Groupe A','Stade de Monterrey'),
    // ── Groupe B ──────────────────────────────────────────────────────────────
    M('gB1','Canada','Bosnie-Herzégovine',        '2026-06-12T15:00:00','Groupe B','Stade de Toronto'),
    M('gB2','Qatar','Suisse',                     '2026-06-13T15:00:00','Groupe B','Stade de San Francisco'),
    M('gB3','Suisse','Bosnie-Herzégovine',        '2026-06-18T15:00:00','Groupe B','Stade de Los Angeles'),
    M('gB4','Canada','Qatar',                     '2026-06-18T18:00:00','Groupe B','BC Place de Vancouver'),
    M('gB5','Suisse','Canada',                    '2026-06-24T15:00:00','Groupe B','BC Place de Vancouver'),
    M('gB6','Bosnie-Herzégovine','Qatar',         '2026-06-24T15:00:00','Groupe B','Stade de Seattle'),
    // ── Groupe C ──────────────────────────────────────────────────────────────
    M('gC1','Brésil','Maroc',                     '2026-06-13T18:00:00','Groupe C','Stade de New York NJ'),
    M('gC2','Haïti','Écosse',                     '2026-06-13T21:00:00','Groupe C','Stade de Boston'),
    M('gC3','Écosse','Maroc',                     '2026-06-19T18:00:00','Groupe C','Stade de Boston'),
    M('gC4','Brésil','Haïti',                     '2026-06-19T20:30:00','Groupe C','Stade de Philadelphie'),
    M('gC5','Écosse','Brésil',                    '2026-06-24T18:00:00','Groupe C','Stade de Miami'),
    M('gC6','Maroc','Haïti',                      '2026-06-24T18:00:00','Groupe C','Stade d\'Atlanta'),
    // ── Groupe D ──────────────────────────────────────────────────────────────
    M('gD1','États-Unis','Paraguay',              '2026-06-12T21:00:00','Groupe D','Stade de Los Angeles'),
    M('gD2','Australie','Turquie',                '2026-06-14T00:00:00','Groupe D','BC Place de Vancouver'),
    M('gD3','États-Unis','Australie',             '2026-06-19T15:00:00','Groupe D','Stade de Seattle'),
    M('gD4','Turquie','Paraguay',                 '2026-06-19T23:00:00','Groupe D','Stade de San Francisco'),
    M('gD5','Turquie','États-Unis',               '2026-06-25T22:00:00','Groupe D','Stade de Los Angeles'),
    M('gD6','Paraguay','Australie',               '2026-06-25T22:00:00','Groupe D','Stade de San Francisco'),
    // ── Groupe E ──────────────────────────────────────────────────────────────
    M('gE1','Allemagne','Curaçao',               '2026-06-14T13:00:00','Groupe E','Stade de Houston'),
    M('gE2','Côte d\'Ivoire','Équateur',          '2026-06-14T19:00:00','Groupe E','Stade de Philadelphie'),
    M('gE3','Allemagne','Côte d\'Ivoire',         '2026-06-20T16:00:00','Groupe E','Stade de Toronto'),
    M('gE4','Équateur','Curaçao',                '2026-06-20T20:00:00','Groupe E','Stade de Kansas City'),
    M('gE5','Équateur','Allemagne',               '2026-06-25T16:00:00','Groupe E','Stade de New York NJ'),
    M('gE6','Curaçao','Côte d\'Ivoire',          '2026-06-25T16:00:00','Groupe E','Stade de Philadelphie'),
    // ── Groupe F ──────────────────────────────────────────────────────────────
    M('gF1','Pays-Bas','Japon',                   '2026-06-14T16:00:00','Groupe F','Stade de Dallas'),
    M('gF2','Suède','Tunisie',                    '2026-06-14T22:00:00','Groupe F','Stade de Monterrey'),
    M('gF3','Pays-Bas','Suède',                   '2026-06-20T13:00:00','Groupe F','Stade de Houston'),
    M('gF4','Tunisie','Japon',                    '2026-06-21T00:00:00','Groupe F','Stade de Monterrey'),
    M('gF5','Tunisie','Pays-Bas',                 '2026-06-25T19:00:00','Groupe F','Stade de Kansas City'),
    M('gF6','Japon','Suède',                      '2026-06-25T19:00:00','Groupe F','Stade de Dallas'),
    // ── Groupe G ──────────────────────────────────────────────────────────────
    M('gG1','Belgique','Égypte',                  '2026-06-15T15:00:00','Groupe G','Stade de Seattle'),
    M('gG2','Iran','Nouvelle-Zélande',            '2026-06-15T21:00:00','Groupe G','Stade de Los Angeles'),
    M('gG3','Belgique','Iran',                    '2026-06-21T15:00:00','Groupe G','Stade de Los Angeles'),
    M('gG4','Nouvelle-Zélande','Égypte',          '2026-06-21T21:00:00','Groupe G','BC Place de Vancouver'),
    M('gG5','Nouvelle-Zélande','Belgique',        '2026-06-26T23:00:00','Groupe G','BC Place de Vancouver'),
    M('gG6','Égypte','Iran',                      '2026-06-26T23:00:00','Groupe G','Stade de Seattle'),
    // ── Groupe H ──────────────────────────────────────────────────────────────
    M('gH1','Espagne','Cap-Vert',                 '2026-06-15T12:00:00','Groupe H','Stade d\'Atlanta'),
    M('gH2','Arabie saoudite','Uruguay',          '2026-06-15T18:00:00','Groupe H','Stade de Miami'),
    M('gH3','Espagne','Arabie saoudite',          '2026-06-21T12:00:00','Groupe H','Stade d\'Atlanta'),
    M('gH4','Uruguay','Cap-Vert',                 '2026-06-21T18:00:00','Groupe H','Stade de Miami'),
    M('gH5','Uruguay','Espagne',                  '2026-06-26T20:00:00','Groupe H','Stade de Guadalajara'),
    M('gH6','Cap-Vert','Arabie saoudite',         '2026-06-26T20:00:00','Groupe H','Stade de Houston'),
    // ── Groupe I ──────────────────────────────────────────────────────────────
    M('gI1','France','Sénégal',                   '2026-06-16T15:00:00','Groupe I','Stade de New York NJ'),
    M('gI2','Irak','Norvège',                     '2026-06-16T18:00:00','Groupe I','Stade de Boston'),
    M('gI3','France','Irak',                      '2026-06-22T17:00:00','Groupe I','Stade de Philadelphie'),
    M('gI4','Norvège','Sénégal',                  '2026-06-22T20:00:00','Groupe I','Stade de New York NJ'),
    M('gI5','Norvège','France',                   '2026-06-26T15:00:00','Groupe I','Stade de Boston'),
    M('gI6','Sénégal','Irak',                     '2026-06-26T15:00:00','Groupe I','Stade de Toronto'),
    // ── Groupe J ──────────────────────────────────────────────────────────────
    M('gJ1','Argentine','Algérie',                '2026-06-16T21:00:00','Groupe J','Stade de Kansas City'),
    M('gJ2','Autriche','Jordanie',                '2026-06-17T00:00:00','Groupe J','Stade de San Francisco'),
    M('gJ3','Argentine','Autriche',               '2026-06-22T13:00:00','Groupe J','Stade de Dallas'),
    M('gJ4','Jordanie','Algérie',                 '2026-06-22T23:00:00','Groupe J','Stade de San Francisco'),
    M('gJ5','Jordanie','Argentine',               '2026-06-27T22:00:00','Groupe J','Stade de Dallas'),
    M('gJ6','Algérie','Autriche',                 '2026-06-27T22:00:00','Groupe J','Stade de Kansas City'),
    // ── Groupe K ──────────────────────────────────────────────────────────────
    M('gK1','Portugal','RD Congo',                '2026-06-17T13:00:00','Groupe K','Stade de Houston'),
    M('gK2','Ouzbékistan','Colombie',             '2026-06-17T22:00:00','Groupe K','Stade de Mexico'),
    M('gK3','Portugal','Ouzbékistan',             '2026-06-23T13:00:00','Groupe K','Stade de Houston'),
    M('gK4','Colombie','RD Congo',                '2026-06-23T22:00:00','Groupe K','Stade de Guadalajara'),
    M('gK5','Colombie','Portugal',                '2026-06-27T19:30:00','Groupe K','Stade de Miami'),
    M('gK6','RD Congo','Ouzbékistan',             '2026-06-27T19:30:00','Groupe K','Stade d\'Atlanta'),
    // ── Groupe L ──────────────────────────────────────────────────────────────
    M('gL1','Angleterre','Croatie',               '2026-06-17T16:00:00','Groupe L','Stade de Dallas'),
    M('gL2','Ghana','Panamá',                     '2026-06-17T19:00:00','Groupe L','Stade de Toronto'),
    M('gL3','Angleterre','Ghana',                 '2026-06-23T16:00:00','Groupe L','Stade de Boston'),
    M('gL4','Panamá','Croatie',                   '2026-06-23T19:00:00','Groupe L','Stade de Toronto'),
    M('gL5','Panamá','Angleterre',                '2026-06-27T17:00:00','Groupe L','Stade de New York NJ'),
    M('gL6','Croatie','Ghana',                    '2026-06-27T17:00:00','Groupe L','Stade de Philadelphie'),

    // ── 32èmes de finale ──────────────────────────────────────────────────────
    M('r32-73','2ème Groupe A','2ème Groupe B',         '2026-06-28T15:00:00','32èmes de finale','Stade de Los Angeles'),
    M('r32-74','1er Groupe E','3ème A/B/C/D/F',         '2026-06-29T16:30:00','32èmes de finale','Stade de Boston'),
    M('r32-75','1er Groupe F','2ème Groupe C',          '2026-06-29T21:00:00','32èmes de finale','Stade de Monterrey'),
    M('r32-76','1er Groupe C','2ème Groupe F',          '2026-06-29T13:00:00','32èmes de finale','Stade de Houston'),
    M('r32-77','1er Groupe I','3ème C/D/F/G/H',         '2026-06-30T17:00:00','32èmes de finale','Stade de New York NJ'),
    M('r32-78','2ème Groupe E','2ème Groupe I',         '2026-06-30T13:00:00','32èmes de finale','Stade de Dallas'),
    M('r32-79','1er Groupe A','3ème C/E/F/H/I',         '2026-06-30T21:00:00','32èmes de finale','Stade de Mexico'),
    M('r32-80','1er Groupe L','3ème E/H/I/J/K',         '2026-07-01T12:00:00','32èmes de finale','Stade d\'Atlanta'),
    M('r32-81','1er Groupe D','3ème B/E/F/I/J',         '2026-07-01T20:00:00','32èmes de finale','Stade de San Francisco'),
    M('r32-82','1er Groupe G','3ème A/E/H/I/J',         '2026-07-01T16:00:00','32èmes de finale','Stade de Seattle'),
    M('r32-83','2ème Groupe K','2ème Groupe L',         '2026-07-02T19:00:00','32èmes de finale','Stade de Toronto'),
    M('r32-84','1er Groupe H','2ème Groupe J',          '2026-07-02T15:00:00','32èmes de finale','Stade de Los Angeles'),
    M('r32-85','1er Groupe B','3ème E/F/G/I/J',         '2026-07-02T23:00:00','32èmes de finale','BC Place de Vancouver'),
    M('r32-86','1er Groupe J','2ème Groupe H',          '2026-07-03T18:00:00','32èmes de finale','Stade de Miami'),
    M('r32-87','1er Groupe K','3ème D/E/I/J/L',         '2026-07-03T21:30:00','32èmes de finale','Stade de Kansas City'),
    M('r32-88','1er Groupe M (à confirmer)','TBD',      '2026-07-03T14:00:00','32èmes de finale','Stade de Dallas'),

    // ── 16èmes de finale ──────────────────────────────────────────────────────
    M('r16-89','Vainqueur M74','Vainqueur M77',   '2026-07-04T17:00:00','16èmes de finale','Stade de Philadelphie'),
    M('r16-90','Vainqueur M73','Vainqueur M75',   '2026-07-04T13:00:00','16èmes de finale','Stade de Houston'),
    M('r16-91','Vainqueur M76','Vainqueur M78',   '2026-07-05T16:00:00','16èmes de finale','Stade de New York NJ'),
    M('r16-92','Vainqueur M79','Vainqueur M80',   '2026-07-05T20:00:00','16èmes de finale','Stade de Mexico'),
    M('r16-93','Vainqueur M83','Vainqueur M84',   '2026-07-06T15:00:00','16èmes de finale','Stade de Dallas'),
    M('r16-94','Vainqueur M81','Vainqueur M82',   '2026-07-06T20:00:00','16èmes de finale','Stade de Seattle'),
    M('r16-95','Vainqueur M86','Vainqueur M88',   '2026-07-07T12:00:00','16èmes de finale','Stade d\'Atlanta'),
    M('r16-96','Vainqueur M85','Vainqueur M87',   '2026-07-07T16:00:00','16èmes de finale','BC Place de Vancouver'),

    // ── Quarts de finale ──────────────────────────────────────────────────────
    M('qf-97','Vainqueur M89','Vainqueur M90',    '2026-07-09T16:00:00','Quarts de finale','Stade de Boston'),
    M('qf-98','Vainqueur M93','Vainqueur M94',    '2026-07-10T15:00:00','Quarts de finale','Stade de Los Angeles'),
    M('qf-99','Vainqueur M91','Vainqueur M92',    '2026-07-11T17:00:00','Quarts de finale','Stade de Miami'),
    M('qf-100','Vainqueur M95','Vainqueur M96',   '2026-07-11T21:00:00','Quarts de finale','Stade de Kansas City'),

    // ── Demi-finales ──────────────────────────────────────────────────────────
    M('sf-101','Vainqueur M97','Vainqueur M98',   '2026-07-14T15:00:00','Demi-finales','Stade de Dallas'),
    M('sf-102','Vainqueur M99','Vainqueur M100',  '2026-07-15T15:00:00','Demi-finales','Stade d\'Atlanta'),

    // ── Petite finale & Finale ─────────────────────────────────────────────────
    M('bronze','Perdant M101','Perdant M102',     '2026-07-18T17:00:00','Petite finale','Stade de Miami'),
    M('final','Vainqueur M101','Vainqueur M102',  '2026-07-19T15:00:00','Finale','Stade de New York NJ'),
  ];

  const col = db.collection('tournaments').doc(TOURNAMENT_ID).collection('matches');
  let batch = db.batch();
  let count = 0;
  for (const m of matches) {
    const { id, ...data } = m;
    batch.set(col.doc(id), data, { merge: true });
    count++;
    if (count % 400 === 0) { await batch.commit(); batch = db.batch(); }
  }
  if (count % 400 !== 0) await batch.commit();

  console.log(`seedWC2026: ${count} matchs seedés`);
  return { seeded: count };
});

/**
 * Somme des points `prono_leaderboard` des membres → `private_leagues.rankingStats`
 * pour classement global des ligues (app client).
 */
exports.recomputeLeaguePowerRankings = onSchedule('every 30 minutes', async () => {
  const db = getFirestore();
  const leaguesSnap = await db.collection('private_leagues').limit(500).get();
  let processed = 0;
  for (const doc of leaguesSnap.docs) {
    const data = doc.data() || {};
    const memberIds = (Array.isArray(data.memberIds) ? data.memberIds : [])
      .map((id) => String(id))
      .filter((id) => id.length > 0);
    let sum = 0;
    for (let i = 0; i < memberIds.length; i += 10) {
      const chunk = memberIds.slice(i, i + 10);
      if (!chunk.length) continue;
      const lb = await db
        .collection('prono_leaderboard')
        .where(FieldPath.documentId(), 'in', chunk)
        .get();
      lb.forEach((d) => {
        sum += Number((d.data() || {}).points || 0);
      });
    }
    await doc.ref.set({
      rankingStats: {
        memberPointsSum: sum,
        memberCount: memberIds.length,
        updatedAt: FieldValue.serverTimestamp(),
      },
    }, { merge: true });
    processed++;
    if (processed % 25 === 0) {
      await new Promise((r) => setTimeout(r, 30));
    }
  }
  console.log(`recomputeLeaguePowerRankings: ${processed} ligues`);
});

// ═══════════════════════════════════════════════════════════════════════════════
// Admin Center — custom claims + competition engine (saisons)
// ═══════════════════════════════════════════════════════════════════════════════

function _rolesArrayFromUserData(data) {
  if (!data) return [];
  if (Array.isArray(data.roles)) return data.roles.map((r) => String(r));
  if (data.role) return [String(data.role)];
  return [];
}

function _rolesSignature(roles) {
  return [...roles].map(String).sort().join(',');
}

/** Sync [dvcr_admin] quand `users/{uid}.roles` change (claims pour Firestore rules). */
exports.syncDvcrAuthClaims = onDocumentWritten('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const beforeData = event.data?.before?.exists ? event.data.before.data() : null;
  const afterData = event.data?.after?.exists ? event.data.after.data() : null;
  const before = _rolesArrayFromUserData(beforeData);
  const after = _rolesArrayFromUserData(afterData);
  if (_rolesSignature(before) === _rolesSignature(after)) return;
  const isAdmin = after.includes('admin');
  try {
    await getAuth().setCustomUserClaims(uid, { dvcr_admin: isAdmin });
  } catch (e) {
    console.error('syncDvcrAuthClaims', uid, e && e.message ? e.message : e);
  }
});

/** Callable : recalculer les claims depuis Firestore (après login admin). */
exports.refreshDvcrAuthClaims = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }
  const uid = request.auth.uid;
  const db = getFirestore();
  const snap = await db.collection('users').doc(uid).get();
  const roles = _rolesArrayFromUserData(snap.data());
  const isAdmin = roles.includes('admin');
  await getAuth().setCustomUserClaims(uid, { dvcr_admin: isAdmin });
  return { ok: true, dvcr_admin: isAdmin };
});

/**
 * Admin : supprime un utilisateur Firebase Auth + doc `users/{uid}` et sous-collections connues.
 * Ne peut pas supprimer son propre compte.
 */
exports.adminDeleteAuthUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }
  const db = getFirestore();
  const callerSnap = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(callerSnap)) {
    throw new HttpsError('permission-denied', 'Réservé aux administrateurs');
  }
  const targetUid = (request.data?.uid || '').toString().trim();
  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'uid manquant');
  }
  if (targetUid === request.auth.uid) {
    throw new HttpsError('invalid-argument', 'Impossible de supprimer votre propre compte');
  }

  try {
    await getAuth().deleteUser(targetUid);
  } catch (e) {
    const code = e && e.errorInfo && e.errorInfo.code ? e.errorInfo.code : '';
    if (code !== 'auth/user-not-found') {
      console.error('adminDeleteAuthUser:auth', targetUid, e);
      throw new HttpsError(
        'internal',
        (e && e.message) ? String(e.message) : 'Erreur suppression compte Auth',
      );
    }
  }

  const userRef = db.collection('users').doc(targetUid);
  const subs = ['favorites', 'xp_log', 'badge_log'];
  for (const sub of subs) {
    await _deleteFirestoreCollectionInBatches(db, userRef.collection(sub));
  }
  try {
    await userRef.delete();
  } catch (e) {
    console.error('adminDeleteAuthUser:firestore', targetUid, e);
  }
  return { ok: true };
});

/** Archive une saison compétition (`seasons.status` → archived). Admin uniquement. */
exports.archiveCompetitionSeason = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentification requise');
  }
  const db = getFirestore();
  const adminSnap = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(adminSnap)) {
    throw new HttpsError('permission-denied', 'Réservé aux administrateurs');
  }
  const seasonId = (request.data?.seasonId || '').toString().trim();
  if (!seasonId) {
    throw new HttpsError('invalid-argument', 'seasonId manquant');
  }
  const ref = db.collection('seasons').doc(seasonId);
  const s = await ref.get();
  if (!s.exists) {
    throw new HttpsError('not-found', 'Saison introuvable');
  }
  await ref.set(
    {
      status: 'archived',
      archivedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { ok: true };
});

// ── Wix Automations (blog publié) → articles Firestore ───────────────────────
const {
  wixArticleWebhook,
  enrichWixArticleFromSite,
} = require('./wix_article_webhook');
exports.wixArticleWebhook = wixArticleWebhook;
exports.enrichWixArticleFromSite = enrichWixArticleFromSite;
