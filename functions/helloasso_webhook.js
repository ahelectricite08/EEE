/**
 * HelloAsso — webhook paiements + expiration statut adhérent (admin uniquement, invisible app).
 */
const crypto = require('crypto');
const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

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

  return {
    totalDonations: nextTotal,
    helloAsso: {
      ...existingHelloAsso,
      status: 'adherent',
      isAdherentActive: true,
      adherentExpiresAt: expiresAt,
      adherentTotalPaid: nextTotal,
      lastPaymentAmount: amount,
      lastPaymentId: paymentId || null,
      lastOrderId: orderId || null,
      lastSyncedAt: FieldValue.serverTimestamp(),
      isDonateurActive: false,
    },
  };
}

/** HelloAsso officiel : HMAC-SHA256 du body brut + header `x-ha-signature` (clé = signatureKey). */
function _verifyHelloAssoRequest(req) {
  const secretKey = helloAssoWebhookSecret.value();
  if (!secretKey || !secretKey.trim()) return false;

  const receivedSig = (
    req.get('x-ha-signature') ||
    req.get('X-Ha-Signature') ||
    ''
  ).toString().trim().toLowerCase();

  if (receivedSig) {
    const rawBody = req.rawBody != null
      ? (Buffer.isBuffer(req.rawBody) ? req.rawBody.toString('utf8') : String(req.rawBody))
      : (typeof req.body === 'string' ? req.body : JSON.stringify(req.body ?? {}));
    const computed = crypto
      .createHmac('sha256', secretKey.trim())
      .update(rawBody, 'utf8')
      .digest('hex');
    if (computed.length === receivedSig.length) {
      try {
        return crypto.timingSafeEqual(
          Buffer.from(computed, 'utf8'),
          Buffer.from(receivedSig, 'utf8'),
        );
      } catch (_) {
        return false;
      }
    }
    return computed === receivedSig;
  }

  const legacyHeader = (
    req.get('X-HelloAsso-Secret') ||
    req.get('x-helloasso-secret') ||
    ''
  ).toString().trim();
  return legacyHeader.length > 0 && legacyHeader === secretKey.trim();
}

const helloAssoWebhookHandler = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  if (!_verifyHelloAssoRequest(req)) {
    res.status(401).json({ error: 'unauthorized' });
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
