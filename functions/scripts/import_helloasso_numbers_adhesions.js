/**
 * One-off : importe un CSV HelloAsso (colonne Email payeur) vers le même
 * schéma que le webhook (users.helloAsso / helloasso_events / pending).
 *
 * Firestore Admin SDK exige un JSON service account ; ce script passe
 * par l’API REST avec le refresh token Firebase CLI (jamais affiché).
 *
 * Usage (PowerShell) :
 *   $env:HELLOASSO_IMPORT_CSV = "C:\path\export.csv"
 *   node scripts/import_helloasso_numbers_adhesions.js
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

const PROJECT_ID = 'drapeau-vert-app';
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const AUTH_LOOKUP = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:lookup`;
const HELLOASSO_CONFIG_PATH = 'app_config/helloasso_adhesion';
const DEFAULT_ADHERENT_EXPIRES_ISO = '2027-06-01T21:59:59.000Z';
const IMPORT_SOURCE = 'numbers_file_import';
const DRY_RUN = process.env.DRY_RUN === '1';

function _toSafeString(value) {
  if (value === null || value === undefined) return '';
  return value.toString().trim();
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
    const exp = ha.adherentExpiresAt instanceof Date
      ? ha.adherentExpiresAt
      : (ha.adherentExpiresAt ? new Date(ha.adherentExpiresAt) : null);
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

function loadCliTokens() {
  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  return JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
}

async function getAccessToken() {
  const cfg = loadCliTokens();
  const cached = cfg.tokens || {};
  if (cached.access_token && cached.expires_at && Date.now() < cached.expires_at - 60_000) {
    return cached.access_token;
  }
  const body = new URLSearchParams({
    client_id: cfg.user?.azp || cfg.user?.aud,
    client_secret: process.env.FIREBASE_CLIENT_SECRET || 'jQRSvDrYdYmbWclV1uoI7hsr',
    refresh_token: cached.refresh_token,
    grant_type: 'refresh_token',
  });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error(`oauth refresh failed: ${json.error || res.status}`);
  }
  return json.access_token;
}

function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(value)) {
      if (v === undefined) continue;
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

function fromFirestoreValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('stringValue' in value) return value.stringValue;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(fromFirestoreValue);
  }
  if ('mapValue' in value) {
    const out = {};
    for (const [k, v] of Object.entries(value.mapValue.fields || {})) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }
  return null;
}

function docToJs(doc) {
  const out = {};
  for (const [k, v] of Object.entries(doc.fields || {})) {
    out[k] = fromFirestoreValue(v);
  }
  const name = doc.name || '';
  const id = name.split('/').pop();
  return { id, data: out };
}

function parseCsvEmails(csvPath) {
  const raw = fs.readFileSync(csvPath, 'utf8');
  const lines = raw.replace(/^\uFEFF/, '').split(/\r?\n/);
  const header = (lines[0] || '').split(',').map((h) => h.trim().replace(/^"|"$/g, ''));
  const emailCol = header.findIndex((h) => /email/i.test(h));
  if (emailCol < 0) {
    throw new Error(`Aucune colonne email. Colonnes: ${header.join(' | ')}`);
  }
  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line) continue;
    const cols = line.split(',').map((c) => c.trim().replace(/^"|"$/g, ''));
    const email = _toSafeString(cols[emailCol]).toLowerCase();
    rows.push({ line: i + 1, email });
  }
  return { header, rows };
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function fsRequest(token, method, url, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = {};
  try { json = text ? JSON.parse(text) : {}; } catch (_) {
    json = { raw: text };
  }
  if (!res.ok) {
    const msg = json.error?.message || text.slice(0, 400);
    const err = new Error(`${method} ${res.status}: ${msg}`);
    err.status = res.status;
    throw err;
  }
  return json;
}

async function getDoc(token, relPath) {
  try {
    const json = await fsRequest(token, 'GET', `${FS_BASE}/${relPath}`);
    return docToJs(json);
  } catch (err) {
    if (err.status === 404) return null;
    throw err;
  }
}

async function runQuery(token, structuredQuery) {
  const json = await fsRequest(token, 'POST', `${FS_BASE}:runQuery`, { structuredQuery });
  const rows = [];
  for (const item of json) {
    if (item.document) rows.push(docToJs(item.document));
  }
  return rows;
}

async function setDoc(token, relPath, data, merge) {
  const fields = toFirestoreValue(data).mapValue.fields;
  const mask = Object.keys(data).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const url = merge
    ? `${FS_BASE}/${relPath}?${mask}`
    : `${FS_BASE}/${relPath}`;
  return fsRequest(token, 'PATCH', url, { fields });
}

async function addDoc(token, collection, data) {
  const fields = toFirestoreValue(data).mapValue.fields;
  return fsRequest(token, 'POST', `${FS_BASE}/${collection}`, { fields });
}

function fieldEqual(fieldPath, stringValue) {
  return {
    fieldFilter: {
      field: { fieldPath },
      op: 'EQUAL',
      value: { stringValue },
    },
  };
}

async function loadAdherentExpiresAt(token) {
  const doc = await getDoc(token, HELLOASSO_CONFIG_PATH);
  const raw = doc?.data?.adherentExpiresAt ?? doc?.data?.expiresAt;
  if (raw instanceof Date && !Number.isNaN(raw.getTime())) return raw;
  if (typeof raw === 'string' && raw.trim()) {
    const parsed = new Date(raw.trim());
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return new Date(DEFAULT_ADHERENT_EXPIRES_ISO);
}

async function findTargetUser(token, payerEmail) {
  const byEmail = await runQuery(token, {
    from: [{ collectionId: 'users' }],
    where: fieldEqual('email', payerEmail),
    limit: 1,
  });
  if (byEmail.length) {
    return { uid: byEmail[0].id, data: byEmail[0].data, matchedBy: 'email' };
  }
  const byEmailLower = await runQuery(token, {
    from: [{ collectionId: 'users' }],
    where: fieldEqual('emailLower', payerEmail),
    limit: 1,
  });
  if (byEmailLower.length) {
    return { uid: byEmailLower[0].id, data: byEmailLower[0].data, matchedBy: 'emailLower' };
  }
  const lookup = await fsRequest(token, 'POST', AUTH_LOOKUP, { email: [payerEmail] });
  const users = lookup.users || [];
  if (!users.length) return null;
  const uid = users[0].localId;
  const existing = await getDoc(token, `users/${uid}`);
  return {
    uid,
    data: existing?.data || {},
    matchedBy: 'auth.email',
  };
}

async function pendingExists(token, payerEmail, grantKey) {
  const byKey = await runQuery(token, {
    from: [{ collectionId: 'helloasso_pending_matches' }],
    where: fieldEqual('grantKey', grantKey),
    limit: 1,
  });
  if (byKey.length) return true;
  const byEmail = await runQuery(token, {
    from: [{ collectionId: 'helloasso_pending_matches' }],
    where: fieldEqual('payerEmailLower', payerEmail),
    limit: 5,
  });
  return byEmail.some((d) => (d.data.status || 'pending') === 'pending');
}

function buildUserPatch(userData, { amount, paymentId, orderId, expiresAt, nextTotal, email }) {
  const existingHelloAsso =
    userData && typeof userData.helloAsso === 'object' && !Array.isArray(userData.helloAsso)
      ? userData.helloAsso
      : {};
  const seasonId = _seasonIdForDate(expiresAt);
  const now = new Date();
  return {
    email: userData.email || email,
    emailLower: String(userData.emailLower || email).toLowerCase(),
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
      lastSyncedAt: now,
      isDonateurActive: false,
    },
    updatedAt: now,
  };
}

async function main() {
  const csvPath = process.env.HELLOASSO_IMPORT_CSV;
  if (!csvPath || !fs.existsSync(csvPath)) {
    throw new Error('HELLOASSO_IMPORT_CSV manquant ou fichier introuvable');
  }

  const token = await getAccessToken();
  const { header, rows } = parseCsvEmails(csvPath);
  console.log('columns', header.join(' | '));
  console.log('data_rows', rows.length);

  const expiresAt = await loadAdherentExpiresAt(token);
  const seasonId = _seasonIdForDate(expiresAt);
  console.log('adherentExpiresAt', expiresAt.toISOString(), 'seasonId', seasonId);
  console.log('dryRun', DRY_RUN);

  const seen = new Set();
  const stats = {
    rows: rows.length,
    uniqueEmails: 0,
    imported: 0,
    matchedUsers: 0,
    pending: 0,
    skipped: 0,
    failed: [],
    skipReasons: {},
  };
  const bumpSkip = (reason) => {
    stats.skipped += 1;
    stats.skipReasons[reason] = (stats.skipReasons[reason] || 0) + 1;
  };

  for (const row of rows) {
    const email = row.email;
    if (!email) {
      bumpSkip('empty_email');
      continue;
    }
    if (!isValidEmail(email)) {
      stats.failed.push({ email, reason: 'invalid_email' });
      continue;
    }
    if (seen.has(email)) {
      bumpSkip('duplicate_email_in_export');
      continue;
    }
    seen.add(email);
    stats.uniqueEmails += 1;

    const grantKey = `numbers_import_2026-2027_${email}`;
    const paymentId = grantKey;
    const orderId = grantKey;
    const eventId = ['payment', paymentId, orderId, 'authorized'].join('_');

    try {
      const existingEvent = await getDoc(token, `helloasso_events/${eventId}`);
      if (existingEvent) {
        bumpSkip('helloasso_event_exists');
        continue;
      }
      const grantSnap = await getDoc(token, `helloasso_processed_payments/${grantKey}`);
      if (grantSnap) {
        bumpSkip('processed_payment_exists');
        continue;
      }

      const target = await findTargetUser(token, email);
      const amount = 0;
      const paidAt = new Date();
      const now = new Date();
      const baseLog = {
        eventType: 'Payment',
        paymentId,
        orderId,
        organizationSlug: null,
        state: 'authorized',
        payerEmail: email,
        payerEmailLower: email,
        amount,
        metadata: { source: IMPORT_SOURCE, importFile: path.basename(csvPath) },
        paidAt,
        adherentExpiresAt: expiresAt,
        receivedAt: now,
        importSource: IMPORT_SOURCE,
      };

      if (!target) {
        const alreadyPending = await pendingExists(token, email, grantKey);
        if (alreadyPending) {
          bumpSkip('pending_already');
          continue;
        }
        if (!DRY_RUN) {
          await setDoc(token, `helloasso_events/${eventId}`, {
            ...baseLog,
            processed: false,
            needsReview: true,
            ignoredReason: 'user_not_found',
          }, false);
          await addDoc(token, 'helloasso_pending_matches', {
            ...baseLog,
            eventId,
            grantKey,
            createdAt: now,
            status: 'pending',
          });
        }
        stats.pending += 1;
        stats.imported += 1;
        continue;
      }

      if (_userHasAdherentSeason(target.data, seasonId)) {
        bumpSkip('already_adherent_season');
        continue;
      }

      const currentTotal = Number(
        target.data.helloAsso?.adherentTotalPaid ?? target.data.totalDonations ?? 0,
      );
      const nextTotal = currentTotal + amount;

      if (!DRY_RUN) {
        await setDoc(token, `helloasso_events/${eventId}`, {
          ...baseLog,
          processed: true,
          processedAt: now,
          matchedUserId: target.uid,
          matchedBy: target.matchedBy,
        }, false);
        await setDoc(token, `helloasso_processed_payments/${grantKey}`, {
          userId: target.uid,
          paymentId,
          orderId,
          eventId,
          amount,
          state: 'authorized',
          adherentExpiresAt: expiresAt,
          processedAt: now,
          importSource: IMPORT_SOURCE,
        }, true);
        await setDoc(token, `donations/helloasso_${grantKey}`, {
          userId: target.uid,
          source: 'helloasso',
          method: 'helloasso',
          amount,
          status: 'completed',
          payerEmail: email,
          paymentId,
          orderId,
          eventType: 'Payment',
          metadata: baseLog.metadata,
          sourceApp: null,
          paidAt,
          adherentExpiresAt: expiresAt,
          createdAt: now,
        }, true);
        await setDoc(
          token,
          `users/${target.uid}`,
          buildUserPatch(target.data, {
            amount,
            paymentId,
            orderId,
            expiresAt,
            nextTotal,
            email,
          }),
          true,
        );
      }

      stats.matchedUsers += 1;
      stats.imported += 1;
    } catch (err) {
      stats.failed.push({ email, reason: err.message || String(err) });
    }
  }

  console.log(JSON.stringify({
    rows: stats.rows,
    uniqueEmails: stats.uniqueEmails,
    imported: stats.imported,
    matchedUsers: stats.matchedUsers,
    pending: stats.pending,
    skipped: stats.skipped,
    skipReasons: stats.skipReasons,
    failed: stats.failed,
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
