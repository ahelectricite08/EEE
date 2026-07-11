const { getMessaging } = require('firebase-admin/messaging');
const { _isTeamDvcrUserData } = require('./admin_auth');

const helloassoWebhookModule = require('../helloasso_webhook');
const _isAdherentUserData = helloassoWebhookModule._isAdherentUserData;

/** Config maintenance — pause globale + UID exempté (ex. tel admin de test). */
async function _loadMaintenanceConfig(db) {
  try {
    const snap = await db.collection('app_config').doc('admin_maintenance').get();
    const d = snap.exists ? (snap.data() || {}) : {};
    const bypassUid = d.maintenanceBypassUid != null
      ? String(d.maintenanceBypassUid).trim()
      : '';
    return {
      paused: d.notificationsPaused === true,
      bypassUid: bypassUid || null,
    };
  } catch (e) {
    console.warn('[maintenance] config read failed:', e.message);
    return { paused: false, bypassUid: null };
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
    const code = err?.errorInfo?.code || err?.code || '';
    const invalidCodes = [
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/invalid-argument',
      'messaging/mismatched-credential',
    ];
    if (invalidCodes.some((c) => code.startsWith(c))) {
      console.warn(`[fcm] token invalide/expiré — ignoré (${code})${logLabel ? `: ${logLabel}` : ''}`);
      return false;
    }
    throw err;
  }
}

/** Push ciblée user — envoie sur tous les appareils enregistrés (ou une plateforme). */
async function _sendFcmToUser(db, userData, messageBase, logLabel = '', opts = {}) {
  const platform = opts.platform || null;
  const tokens = _userFcmTokens(userData, platform);
  if (!tokens.length) return false;
  let any = false;
  for (const token of tokens) {
    const sent = await _sendFcm(
      db,
      { ...messageBase, token },
      logLabel,
      { ...opts, token, recipientUid: opts.recipientUid },
    );
    if (sent) any = true;
  }
  return any;
}

async function _sendManualPlatformNotifications(
  db,
  messageBase,
  platform,
  targetAudience,
  title,
  targetUserIds = null,
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

  let sentCount = 0;
  for (const userDoc of usersById.values()) {
    const userData = userDoc.data() ?? {};
    if (targetAudience === 'team_dvcr' && !_isTeamDvcrUserData(userData)) continue;
    if (!_userMatchesPlatform(userData, platform)) continue;
    const ok = await _sendFcmToUser(
      db,
      userData,
      messageBase,
      `manual [${platform}] ${title}`,
      { recipientUid: userDoc.id, platform },
    );
    if (ok) sentCount += 1;
  }
  return sentCount;
}

async function _sendManualBroadcast(
  db,
  messageBase,
  targetPlatform,
  targetAudience,
  title,
  targetUserIds = null,
) {
  const plat = String(targetPlatform || 'all').trim().toLowerCase();
  if (plat === 'ios' || plat === 'android') {
    const sentCount = await _sendManualPlatformNotifications(
      db,
      messageBase,
      plat,
      targetAudience,
      title,
      targetUserIds,
    );
    return { sentCount, mode: `platform_${plat}` };
  }
  const iosCount = await _sendManualPlatformNotifications(
    db,
    messageBase,
    'ios',
    targetAudience,
    title,
    targetUserIds,
  );
  const androidCount = await _sendManualPlatformNotifications(
    db,
    messageBase,
    'android',
    targetAudience,
    title,
    targetUserIds,
  );
  return {
    sentCount: iosCount + androidCount,
    mode: 'platform_all',
    iosCount,
    androidCount,
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

async function _sendTeamDvcrNotification(db, messageBase, logLabel = '', opts = {}) {
  const platform = opts.platform || null;
  const targetUserIds = Array.isArray(opts.targetUserIds) ? opts.targetUserIds : null;

  const usersById = new Map();
  let broadcastSnaps = null;

  if (targetUserIds && targetUserIds.length > 0) {
    const snaps = await Promise.all(
      targetUserIds.map((uid) => db.collection('users').doc(uid).get()),
    );
    for (const snap of snaps) {
      if (snap.exists) usersById.set(snap.id, snap);
    }
  } else {
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
  }

  let sentCount = 0;
  for (const userDoc of usersById.values()) {
    const userData = userDoc.data() ?? {};
    if (!_isTeamDvcrUserData(userData)) continue;
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
  if (broadcastSnaps?.some((s) => s.size >= 500)) {
    console.warn('[team_dvcr] limite 500 utilisateurs atteinte sur au moins une requête');
  }
  return sentCount;
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
  _sendManualPlatformNotifications,
  _sendManualBroadcast,
  _deleteFirestoreCollectionInBatches,
  _notifPref,
  _skipMentionPushForRecipient,
  _sendTeamDvcrNotification,
  _sendAdherentNotification,
};
