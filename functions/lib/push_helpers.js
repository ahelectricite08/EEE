const { getMessaging } = require('firebase-admin/messaging');
const { _isTeamDvcrUserData } = require('./admin_auth');

const helloassoWebhookModule = require('../helloasso_webhook');
const _isAdherentUserData = helloassoWebhookModule._isAdherentUserData;

/** Cache court — évite 1 lecture Firestore par token FCM pendant un broadcast. */
let _maintCache = { at: 0, cfg: null };
const MAINT_CACHE_TTL_MS = 4000;
const FCM_SEND_EACH_LIMIT = 500;

/** Config maintenance — pause globale + UID exempté (ex. tel admin de test). */
async function _loadMaintenanceConfig(db) {
  const now = Date.now();
  if (_maintCache.cfg && (now - _maintCache.at) < MAINT_CACHE_TTL_MS) {
    return _maintCache.cfg;
  }
  try {
    const snap = await db.collection('app_config').doc('admin_maintenance').get();
    const d = snap.exists ? (snap.data() || {}) : {};
    const bypassUid = d.maintenanceBypassUid != null
      ? String(d.maintenanceBypassUid).trim()
      : '';
    const cfg = {
      paused: d.notificationsPaused === true,
      bypassUid: bypassUid || null,
    };
    _maintCache = { at: now, cfg };
    return cfg;
  } catch (e) {
    console.warn('[maintenance] config read failed:', e.message);
    const cfg = { paused: false, bypassUid: null };
    _maintCache = { at: now, cfg };
    return cfg;
  }
}

function _isInvalidFcmTokenError(err) {
  const code = err?.errorInfo?.code || err?.code || '';
  const invalidCodes = [
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
    'messaging/invalid-argument',
    'messaging/mismatched-credential',
  ];
  return invalidCodes.some((c) => String(code).startsWith(c));
}

/**
 * Envoi FCM par lots (sendEach, max 500).
 * @returns {{ sent: number, failed: number }}
 */
async function _sendFcmMessagesBatch(messages, logLabel = '') {
  if (!messages.length) return { sent: 0, failed: 0 };
  let sent = 0;
  let failed = 0;
  const messaging = getMessaging();
  for (let i = 0; i < messages.length; i += FCM_SEND_EACH_LIMIT) {
    const chunk = messages.slice(i, i + FCM_SEND_EACH_LIMIT);
    try {
      const res = await messaging.sendEach(chunk);
      for (let j = 0; j < res.responses.length; j += 1) {
        const r = res.responses[j];
        if (r.success) {
          sent += 1;
        } else {
          failed += 1;
          if (!_isInvalidFcmTokenError(r.error)) {
            console.warn(
              `[fcm] sendEach fail${logLabel ? `: ${logLabel}` : ''}:`,
              r.error?.message || r.error,
            );
          }
        }
      }
    } catch (err) {
      failed += chunk.length;
      console.error(`[fcm] sendEach batch error${logLabel ? `: ${logLabel}` : ''}`, err);
    }
  }
  return { sent, failed };
}

async function _maybeAbort(opts = {}) {
  if (typeof opts.shouldAbort !== 'function') return false;
  try {
    return !!(await opts.shouldAbort());
  } catch (e) {
    console.warn('[fcm] shouldAbort check failed:', e.message);
    return false;
  }
}

async function _notificationsPaused(db) {
  const cfg = await _loadMaintenanceConfig(db);
  return cfg.paused;
}

/** true = bloquer l’envoi (maintenance active et pas exempté). */
async function _shouldBlockPush(db, opts = {}) {
  const cfg = await _loadMaintenanceConfig(db);
  if (!cfg.paused) return false;
  if (opts.allowMaintenanceBypass === true) return false;
  if (cfg.bypassUid && opts.recipientUid && opts.recipientUid === cfg.bypassUid) {
    return false;
  }
  if (cfg.bypassUid && opts.token) {
    const snap = await db.collection('users').doc(cfg.bypassUid).get();
    const tokens = _userFcmTokens(snap.data());
    if (tokens.includes(String(opts.token).trim())) return false;
  }
  return true;
}

/** Tokens FCM d'un user (ios + android + legacy fcmToken). */
function _userFcmTokens(userData, platform = null) {
  const tokens = [];
  const seen = new Set();
  const add = (t) => {
    if (t == null) return;
    const s = String(t).trim();
    if (!s || seen.has(s)) return;
    seen.add(s);
    tokens.push(s);
  };
  const d = userData || {};
  const map = d.fcmTokens;
  const plat = String(d.fcmPlatform || '').trim().toLowerCase();

  if (platform === 'ios' || platform === 'android') {
    if (map && typeof map === 'object') add(map[platform]);
    if (plat === platform) add(d.fcmToken);
    return tokens;
  }

  if (map && typeof map === 'object') {
    add(map.ios);
    add(map.android);
  }
  add(d.fcmToken);
  return tokens;
}

/** User éligible pour une plateforme (fcmPlatform, flags ou token map). */
function _userMatchesPlatform(userData, platform) {
  if (!userData || typeof userData !== 'object') return false;
  const p = platform === 'ios' ? 'ios' : 'android';
  if (String(userData.fcmPlatform || '').trim().toLowerCase() === p) return true;
  if (p === 'ios' && userData.fcmHasIos === true) return true;
  if (p === 'android' && userData.fcmHasAndroid === true) return true;
  const map = userData.fcmTokens;
  if (map && typeof map === 'object') {
    const t = map[p];
    if (t && String(t).trim()) return true;
  }
  return _userFcmTokens(userData, p).length > 0;
}

/** Envoie FCM sauf si maintenance active (sauf exempt / test admin). Retourne true si envoyé. */
async function _sendFcm(db, message, logLabel = '', opts = {}) {
  const cfg = await _loadMaintenanceConfig(db);

  if (cfg.paused && !opts.allowMaintenanceBypass) {
    if (message.topic) {
      if (!cfg.bypassUid) {
        console.log(`[maintenance] topic blocked${logLabel ? `: ${logLabel}` : ''}`);
        return false;
      }
      const userSnap = await db.collection('users').doc(cfg.bypassUid).get();
      if (!userSnap.exists) {
        console.log(`[maintenance] bypass user missing${logLabel ? `: ${logLabel}` : ''}`);
        return false;
      }
      const { topic, ...directMessage } = message;
      return _sendFcmToUser(
        db,
        userSnap.data() ?? {},
        directMessage,
        `${logLabel || 'push'} [topic→bypass ${topic}]`,
        { recipientUid: cfg.bypassUid, allowMaintenanceBypass: true },
      );
    }
    if (await _shouldBlockPush(db, { ...opts, token: message.token })) {
      console.log(`[maintenance] push blocked${logLabel ? `: ${logLabel}` : ''}`);
      return false;
    }
  }

  try {
    await getMessaging().send(message);
    return true;
  } catch (err) {
    if (_isInvalidFcmTokenError(err)) {
      const code = err?.errorInfo?.code || err?.code || '';
      console.warn(`[fcm] token invalide/expiré — ignoré (${code})${logLabel ? `: ${logLabel}` : ''}`);
      return false;
    }
    throw err;
  }
}

/** Push ciblée user — envoie sur tous les appareils enregistrés (ou une plateforme). */
async function _sendFcmToUser(db, userData, messageBase, logLabel = '', opts = {}) {
  const stats = await _sendFcmToUserWithStats(db, userData, messageBase, logLabel, opts);
  return stats.sent > 0;
}

/** Compte les envois réussis / échoués par token (appareil). */
async function _sendFcmToUserWithStats(db, userData, messageBase, logLabel = '', opts = {}) {
  const platform = opts.platform || null;
  const tokens = _userFcmTokens(userData, platform);
  if (!tokens.length) return { sent: 0, failed: 0 };

  // Maintenance : un seul check pour tous les tokens du user.
  if (await _shouldBlockPush(db, opts)) {
    return { sent: 0, failed: tokens.length };
  }

  const messages = tokens.map((token) => ({ ...messageBase, token }));
  if (messages.length === 1) {
    try {
      const ok = await _sendFcm(
        db,
        messages[0],
        logLabel,
        { ...opts, token: tokens[0], recipientUid: opts.recipientUid },
      );
      return ok ? { sent: 1, failed: 0 } : { sent: 0, failed: 1 };
    } catch {
      return { sent: 0, failed: 1 };
    }
  }
  return _sendFcmMessagesBatch(messages, logLabel);
}

function _emptyPlatformStats() {
  return {
    ios: { sent: 0, failed: 0 },
    android: { sent: 0, failed: 0 },
  };
}

function _sumPlatformStats(platformStats) {
  const ios = platformStats?.ios || { sent: 0, failed: 0 };
  const android = platformStats?.android || { sent: 0, failed: 0 };
  return {
    sent: (ios.sent || 0) + (android.sent || 0),
    failed: (ios.failed || 0) + (android.failed || 0),
  };
}

function _userDisplayLabel(userData, uid) {
  const d = userData || {};
  const name = String(d.displayName || d.name || '').trim();
  const first = String(d.firstName || '').trim();
  const last = String(d.lastName || '').trim();
  const email = String(d.email || '').trim();
  if (name) return name;
  const full = `${first} ${last}`.trim();
  if (full) return full;
  if (email) return email;
  return String(uid || '').trim() || 'Utilisateur';
}

function _recipientDeliveryStatus(userPlatformStats, userData, platform) {
  const totalSent = (userPlatformStats.ios?.sent || 0) + (userPlatformStats.android?.sent || 0);
  const totalFailed = (userPlatformStats.ios?.failed || 0) + (userPlatformStats.android?.failed || 0);
  if (totalSent > 0) {
    return { status: 'received', skipReason: null };
  }
  const hasTokens = _userFcmTokens(userData, platform).length > 0;
  if (totalFailed > 0 || hasTokens) {
    return { status: 'failed', skipReason: 'delivery_failed' };
  }
  if (platform && !_userMatchesPlatform(userData, platform)) {
    return { status: 'skipped', skipReason: 'wrong_platform' };
  }
  return { status: 'skipped', skipReason: 'no_token' };
}

async function _sendManualPlatformNotifications(
  db,
  messageBase,
  platform,
  targetAudience,
  title,
  targetUserIds = null,
  opts = {},
) {
  const usersById = new Map();
  if (Array.isArray(targetUserIds) && targetUserIds.length > 0) {
    const snaps = await Promise.all(
      targetUserIds.map((uid) => db.collection('users').doc(uid).get()),
    );
    for (const snap of snaps) {
      if (snap.exists) usersById.set(snap.id, snap);
    }
  } else {
    // Scan tokens — uniquement cibles team_dvcr / adhérent / UIDs (pas le broadcast club).
    const queries = [
      db.collection('users').where('fcmPlatform', '==', platform).limit(500).get(),
    ];
    if (platform === 'android') {
      queries.push(
        db.collection('users').where('fcmHasAndroid', '==', true).limit(500).get(),
      );
    } else {
      queries.push(
        db.collection('users').where('fcmHasIos', '==', true).limit(500).get(),
      );
    }
    const tokenField = `fcmTokens.${platform}`;
    queries.push(
      db.collection('users').where(tokenField, '!=', '').limit(500).get(),
    );
    const snaps = await Promise.all(queries);
    for (const snap of snaps) {
      for (const doc of snap.docs) {
        usersById.set(doc.id, doc);
      }
    }
  }

  if (await _maybeAbort(opts)) {
    return { sent: 0, failed: 0, usersReached: 0, aborted: true };
  }

  const tokenMeta = [];
  for (const userDoc of usersById.values()) {
    const userData = userDoc.data() ?? {};
    if (targetAudience === 'team_dvcr' && !_isTeamDvcrUserData(userData)) continue;
    if (targetAudience === 'adherent' && !_isAdherentUserData(userData)) continue;
    if (!_userMatchesPlatform(userData, platform)) continue;
    const tokens = _userFcmTokens(userData, platform);
    if (!tokens.length) continue;
    for (const token of tokens) {
      tokenMeta.push({ token, uid: userDoc.id });
    }
  }

  if (!tokenMeta.length) {
    return { sent: 0, failed: 0, usersReached: 0, aborted: false };
  }

  if (await _shouldBlockPush(db, opts)) {
    return {
      sent: 0,
      failed: tokenMeta.length,
      usersReached: 0,
      aborted: false,
    };
  }

  let sent = 0;
  let failed = 0;
  const uidSuccess = new Set();
  const logLabel = `manual [${platform}] ${title}`;
  const messaging = getMessaging();

  for (let i = 0; i < tokenMeta.length; i += FCM_SEND_EACH_LIMIT) {
    if (await _maybeAbort(opts)) {
      return {
        sent,
        failed,
        usersReached: uidSuccess.size,
        aborted: true,
      };
    }
    const chunk = tokenMeta.slice(i, i + FCM_SEND_EACH_LIMIT);
    const messages = chunk.map(({ token }) => ({ ...messageBase, token }));
    try {
      const res = await messaging.sendEach(messages);
      for (let j = 0; j < res.responses.length; j += 1) {
        const r = res.responses[j];
        if (r.success) {
          sent += 1;
          uidSuccess.add(chunk[j].uid);
        } else {
          failed += 1;
          if (!_isInvalidFcmTokenError(r.error)) {
            console.warn(
              `[fcm] sendEach fail${logLabel ? `: ${logLabel}` : ''}:`,
              r.error?.message || r.error,
            );
          }
        }
      }
    } catch (err) {
      failed += chunk.length;
      console.error(`[fcm] sendEach batch error${logLabel ? `: ${logLabel}` : ''}`, err);
    }
  }

  return {
    sent,
    failed,
    usersReached: uidSuccess.size,
    aborted: false,
  };
}

const CLUB_BROADCAST_TOPIC = 'dvcr_notifications';

/**
 * Fan-out club (admin « tout le monde » + rappels match) — 1 send FCM, pas de scan users.
 * FCM ne filtre pas un topic par OS : iOS-only / Android-only partent quand même à tous les abonnés.
 */
async function _sendClubTopicBroadcast(db, messageBase, title, platform = 'all', opts = {}) {
  if (await _maybeAbort(opts)) {
    return {
      sentCount: 0,
      usersReached: 0,
      mode: `topic_${CLUB_BROADCAST_TOPIC}`,
      platformStats: _emptyPlatformStats(),
      total: { sent: 0, failed: 0 },
      aborted: true,
    };
  }

  const ok = await _sendFcm(
    db,
    { ...messageBase, topic: CLUB_BROADCAST_TOPIC },
    `manual [topic ${CLUB_BROADCAST_TOPIC}] ${title}`,
    opts,
  );

  const plat = String(platform || 'all').trim().toLowerCase();
  const platformStats = _emptyPlatformStats();
  if (ok) {
    if (plat === 'ios') platformStats.ios.sent = 1;
    else if (plat === 'android') platformStats.android.sent = 1;
    else {
      platformStats.ios.sent = 1;
      platformStats.android.sent = 1;
    }
  } else if (plat === 'ios') {
    platformStats.ios.failed = 1;
  } else if (plat === 'android') {
    platformStats.android.failed = 1;
  } else {
    platformStats.ios.failed = 1;
    platformStats.android.failed = 1;
  }

  console.log(
    `[fcm] topic ${CLUB_BROADCAST_TOPIC} ${ok ? 'sent' : 'skipped'} — ${title} (platform=${plat})`,
  );

  return {
    sentCount: ok ? 1 : 0,
    usersReached: ok ? 1 : 0,
    mode: `topic_${CLUB_BROADCAST_TOPIC}`,
    platformStats,
    total: { sent: ok ? 1 : 0, failed: ok ? 0 : 1 },
    iosCount: platformStats.ios.sent,
    androidCount: platformStats.android.sent,
    aborted: false,
  };
}

async function _sendManualBroadcast(
  db,
  messageBase,
  targetPlatform,
  targetAudience,
  title,
  targetUserIds = null,
  opts = {},
) {
  const plat = String(targetPlatform || 'all').trim().toLowerCase();
  const audience = String(targetAudience || 'all').trim().toLowerCase();
  const hasTargets = Array.isArray(targetUserIds) && targetUserIds.length > 0;
  // « Tout le monde » : topic FCM (plus de scan users limit 500). Cibles team/adhérent/UIDs : tokens.
  if (!hasTargets && (audience === 'all' || audience === '')) {
    return _sendClubTopicBroadcast(db, messageBase, title, plat, opts);
  }
  if (plat === 'ios' || plat === 'android') {
    const result = await _sendManualPlatformNotifications(
      db,
      messageBase,
      plat,
      targetAudience,
      title,
      targetUserIds,
      opts,
    );
    const platformStats = _emptyPlatformStats();
    platformStats[plat] = { sent: result.sent, failed: result.failed };
    return {
      sentCount: result.sent,
      usersReached: result.usersReached,
      mode: `platform_${plat}`,
      platformStats,
      total: { sent: result.sent, failed: result.failed },
      aborted: !!result.aborted,
    };
  }
  // iOS + Android en parallèle (2× plus rapide qu’en série).
  const [iosResult, androidResult] = await Promise.all([
    _sendManualPlatformNotifications(
      db,
      messageBase,
      'ios',
      targetAudience,
      title,
      targetUserIds,
      opts,
    ),
    _sendManualPlatformNotifications(
      db,
      messageBase,
      'android',
      targetAudience,
      title,
      targetUserIds,
      opts,
    ),
  ]);
  const platformStats = {
    ios: { sent: iosResult.sent, failed: iosResult.failed },
    android: { sent: androidResult.sent, failed: androidResult.failed },
  };
  const total = _sumPlatformStats(platformStats);
  return {
    sentCount: total.sent,
    usersReached: iosResult.usersReached + androidResult.usersReached,
    mode: 'platform_all',
    platformStats,
    total,
    iosCount: iosResult.sent,
    androidCount: androidResult.sent,
    aborted: !!(iosResult.aborted || androidResult.aborted),
  };
}

async function _deleteFirestoreCollectionInBatches(db, collectionRef, batchSize = 400) {
  let snapshot = await collectionRef.limit(batchSize).get();
  while (!snapshot.empty) {
    const batch = db.batch();
    snapshot.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    snapshot = await collectionRef.limit(batchSize).get();
  }
}

function _notifPref(userData, key, defaultVal = true) {
  if (!userData || typeof userData !== 'object') return defaultVal;
  const p = userData.notificationPrefs;
  if (!p || typeof p !== 'object') return defaultVal;
  if (p[key] === false) return false;
  if (p[key] === true) return true;
  return defaultVal;
}

function _skipMentionPushForRecipient(userData) {
  if (!userData || typeof userData !== 'object') return false;
  if (userData.role === 'admin') return true;
  if (Array.isArray(userData.roles) && userData.roles.includes('admin')) return true;
  if (userData.dvcrTeamMember === true) return true;
  return false;
}

async function _loadTeamDvcrUsersById(db, targetUserIds = null) {
  const usersById = new Map();
  let broadcastSnaps = null;

  if (Array.isArray(targetUserIds) && targetUserIds.length > 0) {
    const snaps = await Promise.all(
      targetUserIds.map((uid) => db.collection('users').doc(uid).get()),
    );
    for (const snap of snaps) {
      if (snap.exists) usersById.set(snap.id, snap);
    }
    return { usersById, broadcastSnaps: null };
  }

  broadcastSnaps = await Promise.all([
    db.collection('users').where('roles', 'array-contains', 'team_dvcr').limit(500).get(),
    db.collection('users').where('roles', 'array-contains', 'teamDvcr').limit(500).get(),
    db.collection('users').where('role', 'in', ['team_dvcr', 'teamDvcr']).limit(500).get(),
    db.collection('users').where('dvcrTeamMember', '==', true).limit(500).get(),
  ]);
  for (const snap of broadcastSnaps) {
    for (const doc of snap.docs) {
      usersById.set(doc.id, doc);
    }
  }
  return { usersById, broadcastSnaps };
}

async function _sendTeamDvcrNotificationWithStats(db, messageBase, logLabel = '', opts = {}) {
  const platform = opts.platform || null;
  const targetUserIds = Array.isArray(opts.targetUserIds) ? opts.targetUserIds : null;
  const { usersById, broadcastSnaps } = await _loadTeamDvcrUsersById(db, targetUserIds);

  const recipientDeliveries = [];
  const platformStats = _emptyPlatformStats();
  let aborted = false;

  for (const userDoc of usersById.values()) {
    if (await _maybeAbort(opts)) {
      aborted = true;
      break;
    }
    const userData = userDoc.data() ?? {};
    const uid = userDoc.id;
    const displayName = _userDisplayLabel(userData, uid);
    const email = String(userData.email || '').trim();

    if (!_isTeamDvcrUserData(userData)) {
      recipientDeliveries.push({
        uid,
        displayName,
        email,
        status: 'skipped',
        skipReason: 'not_team_dvcr',
        platformStats: _emptyPlatformStats(),
      });
      continue;
    }

    if (platform && !_userMatchesPlatform(userData, platform)) {
      recipientDeliveries.push({
        uid,
        displayName,
        email,
        status: 'skipped',
        skipReason: 'wrong_platform',
        platformStats: _emptyPlatformStats(),
      });
      continue;
    }

    let userPlatformStats;
    if (platform === 'ios' || platform === 'android') {
      const stats = await _sendFcmToUserWithStats(
        db,
        userData,
        messageBase,
        logLabel,
        { ...opts, recipientUid: uid, platform },
      );
      userPlatformStats = _emptyPlatformStats();
      userPlatformStats[platform] = { sent: stats.sent, failed: stats.failed };
    } else {
      const [ios, android] = await Promise.all([
        _sendFcmToUserWithStats(
          db,
          userData,
          messageBase,
          `${logLabel} [ios]`,
          { ...opts, recipientUid: uid, platform: 'ios' },
        ),
        _sendFcmToUserWithStats(
          db,
          userData,
          messageBase,
          `${logLabel} [android]`,
          { ...opts, recipientUid: uid, platform: 'android' },
        ),
      ]);
      userPlatformStats = {
        ios: { sent: ios.sent, failed: ios.failed },
        android: { sent: android.sent, failed: android.failed },
      };
    }

    platformStats.ios.sent += userPlatformStats.ios.sent || 0;
    platformStats.ios.failed += userPlatformStats.ios.failed || 0;
    platformStats.android.sent += userPlatformStats.android.sent || 0;
    platformStats.android.failed += userPlatformStats.android.failed || 0;

    const { status, skipReason } = _recipientDeliveryStatus(
      userPlatformStats,
      userData,
      platform,
    );
    recipientDeliveries.push({
      uid,
      displayName,
      email,
      status,
      ...(skipReason ? { skipReason } : {}),
      platformStats: userPlatformStats,
    });
  }

  if (Array.isArray(targetUserIds)) {
    for (const uid of targetUserIds) {
      if (usersById.has(uid)) continue;
      recipientDeliveries.push({
        uid,
        displayName: uid,
        email: '',
        status: 'skipped',
        skipReason: 'user_not_found',
        platformStats: _emptyPlatformStats(),
      });
    }
  }

  if (broadcastSnaps?.some((s) => s.size >= 500)) {
    console.warn('[team_dvcr] limite 500 utilisateurs atteinte sur au moins une requête');
  }

  const total = _sumPlatformStats(platformStats);
  const usersReached = recipientDeliveries.filter((r) => r.status === 'received').length;
  return {
    sentCount: total.sent,
    usersReached,
    platformStats,
    total,
    recipientDeliveries,
    aborted,
  };
}

async function _sendTeamDvcrNotification(db, messageBase, logLabel = '', opts = {}) {
  const result = await _sendTeamDvcrNotificationWithStats(
    db,
    messageBase,
    logLabel,
    opts,
  );
  return result.sentCount;
}

async function _sendAdherentNotification(db, messageBase, logLabel = '', opts = {}) {
  const platform = opts.platform || null;
  const targetUserIds = Array.isArray(opts.targetUserIds) ? opts.targetUserIds : null;

  const usersById = new Map();

  if (targetUserIds && targetUserIds.length > 0) {
    const snaps = await Promise.all(
      targetUserIds.map((uid) => db.collection('users').doc(uid).get()),
    );
    for (const snap of snaps) {
      if (snap.exists) usersById.set(snap.id, snap);
    }
  } else {
    const activeSnap = await db.collection('users')
      .where('helloAsso.isAdherentActive', '==', true)
      .limit(500)
      .get();
    for (const doc of activeSnap.docs) {
      usersById.set(doc.id, doc);
    }
  }

  let sentCount = 0;
  for (const userDoc of usersById.values()) {
    const userData = userDoc.data() ?? {};
    if (!_isAdherentUserData(userData)) continue;
    if (platform && !_userMatchesPlatform(userData, platform)) continue;
    const ok = await _sendFcmToUser(
      db,
      userData,
      messageBase,
      logLabel,
      { ...opts, recipientUid: userDoc.id, platform },
    );
    if (ok) sentCount += 1;
  }
  if (!targetUserIds && usersById.size >= 500) {
    console.warn('[adherent] limite 500 utilisateurs atteinte');
  }
  return sentCount;
}

module.exports = {
  _loadMaintenanceConfig,
  _notificationsPaused,
  _shouldBlockPush,
  _userFcmTokens,
  _userMatchesPlatform,
  _sendFcm,
  _sendFcmToUser,
  _sendFcmToUserWithStats,
  _emptyPlatformStats,
  _sumPlatformStats,
  _sendManualPlatformNotifications,
  _sendClubTopicBroadcast,
  _sendManualBroadcast,
  CLUB_BROADCAST_TOPIC,
  _deleteFirestoreCollectionInBatches,
  _notifPref,
  _skipMentionPushForRecipient,
  _sendTeamDvcrNotification,
  _sendTeamDvcrNotificationWithStats,
  _userDisplayLabel,
  _recipientDeliveryStatus,
  _sendAdherentNotification,
};
