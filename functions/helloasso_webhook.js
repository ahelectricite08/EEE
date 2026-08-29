/**
 * HelloAsso — webhook paiements + expiration statut adhérent (admin uniquement, invisible app).
 */
const crypto = require('crypto');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { _requireAdminCall } = require('./lib/admin_auth');

const helloAssoWebhookSecret = defineSecret('HELLOASSO_WEBHOOK_SECRET');

const HELLOASSO_CONFIG_PATH = 'app_config/helloasso_adhesion';
const HELLOASSO_PROCESSED_STATES = new Set(['authorized', 'processed']);
const DEFAULT_ADHERENT_EXPIRES_ISO = '2027-06-01T21:59:59.000Z'; // 23:59:59 Europe/Paris (CEST)

const HELLOASSO_ORGANIZATION_SLUG =
  (process.env.HELLOASSO_ORGANIZATION_SLUG || '').trim().toLowerCase();

function _toSafeString(value) {
  if (value === null || value === undefined) return '';
  return value.toString().trim();
}

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
    Object.entries(metadata).map(([key, value]) => [key, value]),
  );
}

function _extractHelloAssoEmail({ payload, data, order, payment }) {
  return _toSafeString(
    data?.payer?.email ||
    payload?.payer?.email ||
    order?.payer?.email ||
    order?.email ||
    payment?.payer?.email ||
    payment?.email ||
    payload?.email,
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

function _seasonIdForDate(date) {
  const d = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  const month = d.getMonth();
  const year = d.getFullYear();
  const start = month >= 6 ? year : year - 1;
  return `${start}-${start + 1}`;
}

function _mergeAdherentSeasons(existing, seasonId) {
  const prev = Array.isArray(existing.adherentSeasons)
    ? existing.adherentSeasons.map((s) => String(s).trim()).filter(Boolean)
    : [];
  if (seasonId && !prev.includes(seasonId)) prev.push(seasonId);
  return prev;
}

function _paidSeasonsFromUser(userData) {
  if (!userData || typeof userData !== 'object') return [];
  const ha = userData.helloAsso;
  if (!ha || typeof ha !== 'object') return [];
  const out = [];
  if (Array.isArray(ha.adherentSeasons)) {
    for (const item of ha.adherentSeasons) {
      const id = String(item || '').trim();
      if (id && !out.includes(id)) out.push(id);
    }
  }
  if (out.length === 0 && ha.isAdherentActive === true) {
    const exp = ha.adherentExpiresAt?.toDate?.() || null;
    const id = _seasonIdForDate(exp || new Date());
    if (id) out.push(id);
  }
  return out;
}

function _userHasAdherentSeason(userData, seasonId) {
  const wanted = String(seasonId || '').trim();
  if (!wanted) return false;
  return _paidSeasonsFromUser(userData).includes(wanted);
}

async function _loadAdherentExpiresAt(db) {
  const snap = await db.doc(HELLOASSO_CONFIG_PATH).get();
  const data = snap.data() || {};
  const raw = data.adherentExpiresAt ?? data.expiresAt;
  if (raw && typeof raw.toDate === 'function') {
    return raw.toDate();
  }
  if (typeof raw === 'string' && raw.trim()) {
    const parsed = new Date(raw.trim());
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return new Date(DEFAULT_ADHERENT_EXPIRES_ISO);
}

async function _findHelloAssoTargetUser(db, metadata, payerEmail) {
  const metadataUserId = _toSafeString(
    metadata.userId ||
    metadata.uid ||
    metadata.firebaseUid,
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

function _isLikelyEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '').trim());
}

async function _findUserByAccountEmail(db, email) {
  const lowered = _toSafeString(email).toLowerCase();
  if (!lowered) return null;
  const fromFirestore = await _findHelloAssoTargetUser(db, {}, lowered);
  if (fromFirestore) return fromFirestore;
  try {
    const rec = await getAuth().getUserByEmail(lowered);
    return {
      uid: rec.uid,
      ref: db.collection('users').doc(rec.uid),
      matchedBy: 'auth.email',
    };
  } catch (err) {
    const code = err && err.code ? String(err.code) : '';
    if (code !== 'auth/user-not-found') throw err;
  }
  return null;
}

function _timestampFromUnknown(value, fallbackDate) {
  if (value && typeof value.toDate === 'function') {
    return Timestamp.fromDate(value.toDate());
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return Timestamp.fromDate(value);
  }
  if (typeof value === 'string' && value.trim()) {
    const parsed = new Date(value.trim());
    if (!Number.isNaN(parsed.getTime())) return Timestamp.fromDate(parsed);
  }
  return Timestamp.fromDate(fallbackDate || new Date());
}

function _buildHelloAssoUserPatch(userData, {
  amount,
  paymentId,
  orderId,
  expiresAt,
  nextTotal,
}) {
  const existingHelloAsso =
    userData && typeof userData.helloAsso === 'object' && !Array.isArray(userData.helloAsso)
      ? userData.helloAsso
      : {};

  const expiresAtDate = expiresAt && typeof expiresAt.toDate === 'function'
    ? expiresAt.toDate()
    : (expiresAt instanceof Date ? expiresAt : null);
  const seasonId = _seasonIdForDate(expiresAtDate || new Date());

  return {
    totalDonations: nextTotal,
    helloAsso: {
      ...existingHelloAsso,
      status: 'adherent',
      isAdherentActive: true,
      adherentExpiresAt: expiresAt,
      adherentSeasons: _mergeAdherentSeasons(existingHelloAsso, seasonId),
      adherentTotalPaid: nextTotal,
      lastPaymentAmount: amount,
      lastPaymentId: paymentId || null,
      lastOrderId: orderId || null,
      lastSyncedAt: FieldValue.serverTimestamp(),
      isDonateurActive: false,
    },
  };
}

function _rawHelloAssoBody(req) {
  if (req.rawBody != null) {
    return Buffer.isBuffer(req.rawBody) ? req.rawBody.toString('utf8') : String(req.rawBody);
  }
  return typeof req.body === 'string' ? req.body : JSON.stringify(req.body ?? {});
}

function _timingSafeEqualString(a, b) {
  const left = String(a || '');
  const right = String(b || '');
  if (left.length === 0 || left.length !== right.length) return false;
  try {
    return crypto.timingSafeEqual(Buffer.from(left, 'utf8'), Buffer.from(right, 'utf8'));
  } catch (_) {
    return false;
  }
}

function _hmacMatchesRawBody(rawBody, secretKey, receivedSig) {
  const computed = crypto
    .createHmac('sha256', secretKey)
    .update(rawBody, 'utf8')
    .digest('hex')
    .toLowerCase();
  const expected = String(receivedSig || '').trim().toLowerCase();
  return _timingSafeEqualString(computed, expected);
}

function _queryToken(req) {
  const query = req.query && typeof req.query === 'object' ? req.query : {};
  return _toSafeString(query.token || query.secret);
}

/**
 * Auth webhook HelloAsso :
 * - `x-ha-signature` présent → HMAC-SHA256 obligatoire (comptes partenaires).
 * - `?token=` présent → doit matcher HELLOASSO_WEBHOOK_SECRET (optionnel).
 * - Sinon (URL de callback association) : pas de HMAC → on n’envoie pas 401 ;
 *   le JSON Payment/Order est validé plus bas.
 */
function _authorizeHelloAssoRequest(req) {
  const secretKey = (helloAssoWebhookSecret.value() || '').trim();
  const receivedSig = (
    req.get('x-ha-signature') ||
    req.get('X-Ha-Signature') ||
    ''
  ).toString().trim();

  if (receivedSig) {
    if (!secretKey) {
      return { ok: false, reason: 'hmac_no_secret' };
    }
    const hmacOk = _hmacMatchesRawBody(_rawHelloAssoBody(req), secretKey, receivedSig);
    return hmacOk
      ? { ok: true, reason: 'hmac' }
      : { ok: false, reason: 'hmac_mismatch' };
  }

  const queryToken = _queryToken(req);
  if (queryToken) {
    if (!secretKey) {
      return { ok: false, reason: 'token_no_secret' };
    }
    return _timingSafeEqualString(queryToken, secretKey)
      ? { ok: true, reason: 'query_token' }
      : { ok: false, reason: 'token_mismatch' };
  }

  const legacyHeader = (
    req.get('X-HelloAsso-Secret') ||
    req.get('x-helloasso-secret') ||
    ''
  ).toString().trim();
  if (legacyHeader) {
    if (!secretKey) {
      return { ok: false, reason: 'legacy_no_secret' };
    }
    return _timingSafeEqualString(legacyHeader, secretKey)
      ? { ok: true, reason: 'legacy_header' }
      : { ok: false, reason: 'legacy_mismatch' };
  }

  return { ok: true, reason: 'unsigned_association' };
}

const helloAssoWebhookHandler = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const auth = _authorizeHelloAssoRequest(req);
  if (!auth.ok) {
    console.warn('helloAssoWebhook unauthorized', { reason: auth.reason });
    res.status(401).json({ error: 'unauthorized' });
    return;
  }

  console.info('helloAssoWebhook authorized', { reason: auth.reason });

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
  const expiresAtDate = await _loadAdherentExpiresAt(db);
  const expiresAt = Timestamp.fromDate(expiresAtDate);

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
    adherentExpiresAt: expiresAt,
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
    const currentTotal = Number(userData.helloAsso?.adherentTotalPaid ?? userData.totalDonations ?? 0);
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
      adherentExpiresAt: expiresAt,
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
      sourceApp: _toSafeString(metadata.source).toLowerCase() === 'dvcr_app'
        ? 'dvcr_app'
        : (_toSafeString(metadata.userId) ? 'dvcr_app' : null),
      paidAt: Timestamp.fromDate(paidAt),
      adherentExpiresAt: expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(target.ref, {
      ..._buildHelloAssoUserPatch(userData, {
        amount,
        paymentId,
        orderId,
        expiresAt,
        nextTotal,
      }),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  res.status(200).json({ ok: true, matchedUserId: target.uid });
};

const expireHelloAssoAdherentsHandler = async () => {
  const db = getFirestore();
  const snap = await db.collection('users')
    .where('helloAsso.isAdherentActive', '==', true)
    .get();

  if (snap.empty) return;

  const now = Date.now();
  for (let i = 0; i < snap.docs.length; i += 200) {
    const chunk = snap.docs.slice(i, i + 200);
    const batch = db.batch();

    for (const doc of chunk) {
      const data = doc.data() || {};
      const ha = data.helloAsso && typeof data.helloAsso === 'object' ? data.helloAsso : {};
      let expiryMs = ha.adherentExpiresAt?.toDate
        ? ha.adherentExpiresAt.toDate().getTime()
        : 0;
      if (!expiryMs && ha.donateurExpiresAt?.toDate) {
        expiryMs = ha.donateurExpiresAt.toDate().getTime();
      }
      if (!expiryMs || expiryMs > now) continue;

      const existingHelloAsso = { ...ha };
      batch.set(doc.ref, {
        helloAsso: {
          ...existingHelloAsso,
          status: 'expired',
          isAdherentActive: false,
          expiredAt: FieldValue.serverTimestamp(),
          lastSyncedAt: FieldValue.serverTimestamp(),
          isDonateurActive: false,
        },
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await batch.commit();
  }
};

exports.adminLinkHelloAssoPending = onCall({ cors: true }, async (request) => {
  const { db } = await _requireAdminCall(request);
  const pendingMatchId = _toSafeString(request.data?.pendingMatchId);
  const appEmail = _toSafeString(request.data?.appEmail).toLowerCase();
  const adminUid = request.auth.uid;

  if (!pendingMatchId) {
    throw new HttpsError('invalid-argument', 'pendingMatchId manquant');
  }
  if (!_isLikelyEmail(appEmail)) {
    throw new HttpsError('invalid-argument', 'E-mail du compte app invalide');
  }

  const pendingRef = db.collection('helloasso_pending_matches').doc(pendingMatchId);
  const pendingSnap = await pendingRef.get();
  if (!pendingSnap.exists) {
    throw new HttpsError('not-found', 'Paiement non rattaché introuvable');
  }
  const pending = pendingSnap.data() || {};
  const status = _toSafeString(pending.status || 'pending').toLowerCase();
  if (status && status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Ce paiement est déjà traité');
  }

  const originalEmail = _toSafeString(
    pending.payerEmailLower || pending.payerEmail,
  ).toLowerCase();
  const target = await _findUserByAccountEmail(db, appEmail);

  if (!target) {
    await pendingRef.set({
      payerEmail: appEmail,
      payerEmailLower: appEmail,
      originalPayerEmail: originalEmail || pending.originalPayerEmail || null,
      retargetedAt: FieldValue.serverTimestamp(),
      retargetedByAdminUid: adminUid,
      status: 'pending',
    }, { merge: true });
    return {
      ok: true,
      linked: false,
      pendingRetargeted: true,
      appEmail,
      message: 'Aucun compte app pour cet e-mail. Le paiement reste en attente sur cette adresse.',
    };
  }

  const expiresAtDate = await _loadAdherentExpiresAt(db);
  const expiresAt = Timestamp.fromDate(expiresAtDate);
  const paymentId = _toSafeString(pending.paymentId);
  const orderId = _toSafeString(pending.orderId);
  const eventType = _toSafeString(pending.eventType) || 'Payment';
  const state = _toSafeString(pending.state) || 'authorized';
  const eventId = _toSafeString(pending.eventId)
    || _buildHelloAssoEventId({ eventType, paymentId, orderId, state });
  const grantKey = _toSafeString(pending.grantKey) || paymentId || orderId || eventId;
  const amountRaw = Number(pending.amount);
  const amount = Number.isFinite(amountRaw) ? amountRaw : 0;
  const metadata = _normalizeMetadata(pending.metadata);
  const paidAtTs = _timestampFromUnknown(pending.paidAt, new Date());
  const eventRef = db.collection('helloasso_events').doc(eventId);
  const grantRef = db.collection('helloasso_processed_payments').doc(grantKey);

  await db.runTransaction(async (tx) => {
    const grantSnap = await tx.get(grantRef);
    const userSnap = await tx.get(target.ref);
    const userData = userSnap.data() || {};

    if (grantSnap.exists) {
      const existingUid = _toSafeString(grantSnap.data()?.userId);
      if (existingUid && existingUid !== target.uid) {
        throw new HttpsError(
          'failed-precondition',
          'Ce paiement HelloAsso est déjà lié à un autre compte',
        );
      }
    }

    const currentTotal = Number(
      userData.helloAsso?.adherentTotalPaid ?? userData.totalDonations ?? 0,
    );
    const nextTotal = grantSnap.exists ? currentTotal : currentTotal + amount;
    const matchedBy = `admin.email:${adminUid}`;

    tx.set(eventRef, {
      eventType,
      paymentId: paymentId || null,
      orderId: orderId || null,
      organizationSlug: pending.organizationSlug || null,
      state: state || null,
      payerEmail: originalEmail || pending.payerEmail || null,
      payerEmailLower: originalEmail || pending.payerEmailLower || null,
      amount,
      metadata,
      paidAt: paidAtTs,
      adherentExpiresAt: expiresAt,
      receivedAt: pending.receivedAt || FieldValue.serverTimestamp(),
      importSource: pending.importSource || null,
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
      matchedUserId: target.uid,
      matchedBy,
      linkedAppEmail: appEmail,
      needsReview: false,
      ignoredReason: null,
    }, { merge: true });

    if (!grantSnap.exists) {
      tx.set(grantRef, {
        userId: target.uid,
        paymentId: paymentId || null,
        orderId: orderId || null,
        eventId,
        amount,
        state: state || null,
        adherentExpiresAt: expiresAt,
        processedAt: FieldValue.serverTimestamp(),
        matchedBy,
        importSource: pending.importSource || null,
      }, { merge: true });

      tx.set(db.collection('donations').doc(`helloasso_${grantKey}`), {
        userId: target.uid,
        source: 'helloasso',
        method: 'helloasso',
        amount,
        status: 'completed',
        payerEmail: originalEmail || appEmail,
        paymentId: paymentId || null,
        orderId: orderId || null,
        eventType,
        metadata,
        sourceApp: null,
        importSource: pending.importSource || null,
        paidAt: paidAtTs,
        adherentExpiresAt: expiresAt,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    tx.set(target.ref, {
      ..._buildHelloAssoUserPatch(userData, {
        amount: grantSnap.exists
          ? Number(userData.helloAsso?.lastPaymentAmount ?? 0)
          : amount,
        paymentId,
        orderId,
        expiresAt,
        nextTotal,
      }),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    tx.set(pendingRef, {
      status: 'matched',
      matchedUserId: target.uid,
      matchedBy,
      matchedAt: FieldValue.serverTimestamp(),
      matchedAdminUid: adminUid,
      linkedAppEmail: appEmail,
      originalPayerEmail: originalEmail || pending.originalPayerEmail || null,
    }, { merge: true });
  });

  return {
    ok: true,
    linked: true,
    matchedUserId: target.uid,
    appEmail,
    seasonId: _seasonIdForDate(expiresAtDate),
  };
});

exports.helloAssoWebhook = onRequest(
  {
    cors: true,
    region: 'europe-west1',
    secrets: [helloAssoWebhookSecret],
  },
  helloAssoWebhookHandler,
);

exports.expireHelloAssoAdherents = onSchedule(
  {
    schedule: 'every 24 hours',
    region: 'europe-west1',
  },
  expireHelloAssoAdherentsHandler,
);

exports._loadAdherentExpiresAt = _loadAdherentExpiresAt;
exports._seasonIdForDate = _seasonIdForDate;
exports._paidSeasonsFromUser = _paidSeasonsFromUser;
exports._userHasAdherentSeason = _userHasAdherentSeason;
exports._isAdherentUserData = function isAdherentUserData(userData) {
  if (!userData || typeof userData !== 'object') return false;
  const ha = userData.helloAsso;
  if (!ha || typeof ha !== 'object') return false;
  const now = Date.now();
  if (ha.isAdherentActive === true) {
    const exp = ha.adherentExpiresAt?.toDate?.();
    if (!exp || exp.getTime() > now) return true;
  }
  if (ha.isDonateurActive === true) {
    const exp = ha.donateurExpiresAt?.toDate?.();
    if (!exp || exp.getTime() > now) return true;
  }
  return false;
};
