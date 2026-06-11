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
const { fcmChannelBlocks, channelFromTopic } = require('./notification_push');

// ── FFF API — CSSA Régional 1 Grand Est ──────────────────────────────────────
const FFF_BASE  = 'https://api-dofa.fff.fr/api';
const FFF_HOST  = 'https://api-dofa.fff.fr';  // pour les liens hydra:next
const FFF_CP    = 436257;  // Régional 1 Homiris Grand Est 2025-2026
const FFF_PH    = 1;
const FFF_GP    = 1;       // Poule A (CSSA's group)
const FFF_CLUB  = 500266;  // CS Sedan Ardennes
/** Marque app / média DVCR (push live, coup d'envoi, mi-temps…). */
const APP_BRAND_NAME = 'Drapeau Vert Carton Rouge';
const CLUB_SHORT_NAME = 'CSSA';

const FFF_CONFIG_DOC = 'fff_season';
const FFF_LIFECYCLE_DOC = 'season_lifecycle';

function _isUserAdmin(userDoc) {
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  if (data.role === 'admin') return true;
  if (Array.isArray(data.roles) && data.roles.includes('admin')) return true;
  return false;
}

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

/** Envoie FCM sauf si maintenance active (sauf exempt / test admin). Retourne true si envoyé. */
async function _sendFcm(db, message, logLabel = '', opts = {}) {
  const cfg = await _loadMaintenanceConfig(db);

  if (cfg.paused && !opts.allowMaintenanceBypass) {
    // Topics (live, actus…) : en maintenance → uniquement le compte exempté
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

/** Envoi manuel filtré ios/android (fcmPlatform + legacy flags). */
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

/** Supprime tous les docs d’une sous-collection (lots de 400). */
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
    fffSyncEnabled: d.fffSyncEnabled !== false,
  };
}

/** Sync FFF autorisée ? (cron + manuel sauf force admin) */
async function _fffSyncGate(db, { force = false } = {}) {
  if (force) return { enabled: true };

  const [fffSnap, lifeSnap] = await Promise.all([
    db.collection('app_config').doc(FFF_CONFIG_DOC).get(),
    db.collection('app_config').doc(FFF_LIFECYCLE_DOC).get(),
  ]);
  const fffData = fffSnap.data() || {};
  const lifeData = lifeSnap.data() || {};

  if (fffData.fffSyncEnabled === false) {
    return {
      enabled: false,
      reason: 'Synchronisation FFF désactivée (app_config/fff_season.fffSyncEnabled)',
    };
  }
  if (lifeData.betweenSeasons === true) {
    return {
      enabled: false,
      reason: 'Fin de saison active (app_config/season_lifecycle.betweenSeasons)',
    };
  }
  return { enabled: true };
}

async function _runFffSyncCore(db, { force = false } = {}) {
  const gate = await _fffSyncGate(db, { force });
  if (!gate.enabled) {
    console.log(`FFF sync ignorée : ${gate.reason}`);
    return { skipped: true, reason: gate.reason };
  }
  // Matchs d’abord (scores / statuts), puis classement + enrichissement rank/form.
  await _syncMatches(db);
  const classement = await _syncClassement(db);
  return { skipped: false, ...classement };
}

initializeApp();
const youtubeApiKeySecret = defineSecret('YOUTUBE_API_KEY');

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

function _toSafeString(value) {
  if (value === null || value === undefined) return '';
  return value.toString().trim();
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

function _isTeamDvcrUserData(userData) {
  if (!userData || typeof userData !== 'object') return false;
  if (Array.isArray(userData.roles)) {
    const roles = userData.roles
      .map((r) => String(r || '').trim().toLowerCase())
      .filter(Boolean);
    if (roles.includes('team_dvcr') || roles.includes('teamdvcr')) return true;
  }
  const role = String(userData.role || '').trim().toLowerCase();
  if (role === 'team_dvcr' || role === 'teamdvcr') return true;
  if (userData.dvcrTeamMember === true) return true;
  return false;
}

function _normalizeTargetUserIds(data) {
  const raw = data?.targetUserIds;
  if (!Array.isArray(raw)) return null;
  const ids = [...new Set(raw.map((id) => String(id || '').trim()).filter(Boolean))];
  return ids.length ? ids.slice(0, 500) : null;
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

const helloassoWebhookModule = require('./helloasso_webhook');
const _isAdherentUserData = helloassoWebhookModule._isAdherentUserData;

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

// ── 1. Notification push quand un article est publié ─────────────────────────
exports.notifyArticlePublished = onDocumentWritten('articles/{id}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return; // suppression

  // Déclenche uniquement si on passe à 'published' (création ou depuis draft)
  const wasDraft    = !before || before.status !== 'published';
  const isPublished = after.status === 'published';
  if (!isPublished || !wasDraft) return;

  const db = getFirestore();
  await _sendFcm(db, {
    topic: 'dvcr_articles',
    notification: {
      title: '📰 Nouvelle actu DVCR',
      body:  after.title || 'Nouvel article publié',
    },
    data: {
      type:      'article',
      articleId: event.params.id,
    },
    ...fcmChannelBlocks('dvcr_articles'),
  }, 'article published');
});

// ── Notification PDF bénévoles (Team DVCR uniquement) ─────────────────────────
exports.notifyTeamDvcrPdfUpdated = onDocumentWritten('benevole_documents/{id}', async (event) => {
  const before = event.data?.before?.exists ? (event.data.before.data() || {}) : null;
  const after = event.data?.after?.exists ? (event.data.after.data() || {}) : null;
  if (!after) return;
  if (after.published === false) return;

  const isCreate = !before;
  const changed =
    isCreate
    || String(before.fileUrl || '') !== String(after.fileUrl || '')
    || String(before.title || '') !== String(after.title || '')
    || before.published === false;
  if (!changed) return;

  const db = getFirestore();
  const title = '📄 Nouveau script de match disponible';
  const body = (after.title && String(after.title).trim())
    ? `Nouveau script : ${String(after.title).trim()}`
    : 'Consulte le nouveau script dans l’espace bénévoles.';

  const messageBase = {
    notification: { title, body },
    data: {
      type: 'benevole_pdf',
      documentId: String(event.params.id || ''),
    },
    ...fcmChannelBlocks('dvcr_alerts'),
  };

  const sent = await _sendTeamDvcrNotification(
    db,
    messageBase,
    'team_dvcr pdf updated',
  );
  console.log(`[team_dvcr] notifyTeamDvcrPdfUpdated: ${sent} envoi(s)`);
});

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
      return _sendFcmToUser(
        db,
        udata,
        {
          notification: {
            title: `💬 ${senderName} t'a mentionné`,
            body:  text,
          },
          data: { type: 'chat_mention', salonId: event.params.salonId },
          ...fcmChannelBlocks('dvcr_alerts'),
        },
        `chat mention ${uid}`,
        { recipientUid: uid },
      );
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

  try {
    await _sendFcmToUser(
      db,
      odata,
      {
        notification: {
          title: '⚔️ Défi prono',
          body:  `${ownerName} veut t’affronter en duel. Ouvre l’app pour répondre !`,
        },
        data: {
          type:    'duel',
          duelId:  event.params.duelId,
        },
        ...fcmChannelBlocks('dvcr_alerts'),
      },
      `duel created ${opponentUid}`,
      { recipientUid: opponentUid },
    );
    console.log(`Duel notif envoyée à ${opponentUid}`);
  } catch (e) {
    console.error('notifyDuelCreated:', e.message);
  }
});

// ── Demande d’ami — notifie le destinataire ───────────────────────────────────
exports.notifyFriendRequest = onDocumentCreated('friend_requests/{reqId}', async (event) => {
  const db = getFirestore();
  const data = event.data?.data();
  if (!data) return;
  if ((data.status || 'pending') !== 'pending') return;

  const toUid = data.toUid;
  const fromName = data.fromName || 'Un membre';
  if (!toUid) return;

  const userSnap = await db.collection('users').doc(toUid).get();
  const udata = userSnap.data() ?? {};
  if (!_notifPref(udata, 'friendRequest')) return;

  try {
    await _sendFcmToUser(
      db,
      udata,
      {
        notification: {
          title: '👋 Nouvelle demande d’ami',
          body: `${fromName} souhaite être ton ami sur DVCR.`,
        },
        data: {
          type: 'friend_request',
          requestId: String(event.params.reqId || ''),
          fromUid: String(data.fromUid || ''),
        },
        ...fcmChannelBlocks('dvcr_alerts'),
      },
      `friend request ${toUid}`,
      { recipientUid: toUid },
    );
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
    await _sendFcmToUser(
      db,
      udata,
      {
        notification: { title, body },
        data: {
          type: 'duel_result',
          duelId: String(duelId),
          matchLabel: String(label),
        },
        ...fcmChannelBlocks('dvcr_alerts'),
      },
      `duel resolved ${uid}`,
      { recipientUid: uid },
    );
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

    promises.push(
      _sendFcmToUser(
        db,
        udata,
        {
          notification: {
            title: `${emoji} ${team1} ${score1}–${score2} ${team2}`,
            body:  `Ton prono : ${p1}–${p2} · ${label} · ${xpGained}`,
          },
          data: {
            type:    'match_recap',
            matchId,
          },
          ...fcmChannelBlocks('dvcr_alerts'),
        },
        `match recap ${uid}`,
        { recipientUid: uid },
      ).catch(e => console.error(`Recap notif failed for ${uid}:`, e.message))
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
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  if (!after) return;

  const isCreate = !beforeSnap?.exists;
  const becameLive = before?.live !== true && after.live === true;
  const startedNow = !before?.startedAt && !!after.startedAt;
  const sessionChanged =
    (before?.sessionId ?? '') !== (after.sessionId ?? '') && !!after.sessionId;
  const streamChanged =
    (before?.url ?? '') !== (after.url ?? '') && !!after.url;
  const shouldSend =
    isCreate || becameLive || startedNow || sessionChanged || streamChanged;
  if (!shouldSend) {
    console.log('[notifyEmission] skipped (poll/update only)');
    return;
  }

  const db = getFirestore();
  const title = String(after.title || '').trim() || 'ÉMISSION DVCR';
  const sent = await _sendFcm(db, {
    topic: 'dvcr_live',
    notification: {
      title: '📺 L\'émission DVCR est en direct !',
      body: title,
    },
    data: {
      url: String(after.url ?? ''),
      type: 'emission',
    },
    ...fcmChannelBlocks('dvcr_live'),
  }, 'emission live');
  console.log(`[notifyEmission] push ${sent ? 'sent' : 'blocked/skipped'} session=${after.sessionId || '—'}`);
});

// ── 2. Sync vidéos YouTube → Firestore (1× / jour, nuit Europe/Paris) ─────────
exports.syncYoutubeVideos = onSchedule(
  { schedule: '0 4 * * *', timeZone: 'Europe/Paris', secrets: [youtubeApiKeySecret] },
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

// ── 3. Sync FFF (6 h) — rien si fin de saison ou fffSyncEnabled=false ─────────
exports.syncFffData = onSchedule('every 6 hours', async () => {
  const db = getFirestore();
  const result = await _runFffSyncCore(db);
  if (!result.skipped) console.log('FFF sync terminé');
});

/** Délai minimum entre deux sync FFF déclenchées depuis l’app (onglet Calendrier). */
const FFF_ON_DEMAND_COOLDOWN_MS = 30 * 60 * 1000;
const FFF_ON_DEMAND_DOC = 'fff_sync_on_demand';

// Sync à la demande (app — onglet Calendrier). Auth requise ; throttle global ~90 s.
exports.syncFffDataOnCalendarOpen = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Connexion requise pour actualiser le calendrier');
  }
  const db = getFirestore();
  const now = Date.now();
  const throttleRef = db.collection('app_config').doc(FFF_ON_DEMAND_DOC);
  const throttleSnap = await throttleRef.get();
  const lastMs = throttleSnap.data()?.lastTriggeredAt?.toMillis?.() ?? 0;
  const elapsed = now - lastMs;
  if (elapsed < FFF_ON_DEMAND_COOLDOWN_MS) {
    return {
      success: true,
      skipped: true,
      reason: 'throttled',
      retryAfterSeconds: Math.ceil((FFF_ON_DEMAND_COOLDOWN_MS - elapsed) / 1000),
    };
  }

  const result = await _runFffSyncCore(db);
  if (!result.skipped) {
    await throttleRef.set(
      {
        lastTriggeredAt: Timestamp.now(),
        lastUid: request.auth.uid,
      },
      { merge: true },
    );
  }
  return {
    success: true,
    skipped: !!result.skipped,
    reason: result.reason ?? null,
    journee: result.journee ?? 0,
    rankingTeams: result.rankingTeams ?? 0,
    rankingWrites: result.rankingWrites ?? 0,
    matchesEnriched: result.matchesEnriched ?? 0,
  };
});

// Sync manuelle scores/classement (admin only). data.force=true pour ignorer la coupure.
exports.syncFffDataManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const force = request.data?.force === true;
  const result = await _runFffSyncCore(db, { force });
  if (result.skipped) {
    throw new HttpsError(
      'failed-precondition',
      `${result.reason}. Pour forcer : call avec { "force": true }.`,
    );
  }
  await _cleanMockMatches(db);
  return {
    success: true,
    journee: result.journee ?? 0,
    rankingTeams: result.rankingTeams ?? 0,
    rankingWrites: result.rankingWrites ?? 0,
    matchesEnriched: result.matchesEnriched ?? 0,
  };
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

// Fenêtre Firestore pour les matchs : passés récents (scores) + à venir (calendrier).
const FFF_SYNC_PAST_DAYS = 21;
const FFF_SYNC_FUTURE_DAYS = 120;
const FFF_RANK_ENRICH_FUTURE_DAYS = 60;

/** Lit tout le classement FFF (pagination Hydra) et ne garde que la dernière journée. */
async function _fetchFffClassementLatestMembers(cfg) {
  const headers = { Accept: 'application/ld+json' };
  let url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/classement_journees`;
  const all = [];
  while (url) {
    const res = await fetch(url, { headers });
    if (!res.ok) {
      console.error('Classement HTTP', res.status, url);
      return { members: [], lastJournee: 0, httpError: res.status };
    }
    const data = await res.json();
    all.push(...(data['hydra:member'] ?? []));
    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  if (!all.length) return { members: [], lastJournee: 0 };

  let lastJournee = 0;
  for (const entry of all) {
    const j = entry.cj_no ?? 0;
    if (j > lastJournee) lastJournee = j;
  }
  const members = lastJournee > 0
    ? all.filter((e) => (e.cj_no ?? 0) === lastJournee)
    : all;
  return { members, lastJournee };
}

function _matchBelongsToFffSeason(data, seasonLabel) {
  const fs = (data.fffSeason ?? '').toString().trim();
  if (fs) return fs === seasonLabel;
  return true;
}

// ── Sync classement FFF → collection "ranking" ────────────────────────────────
async function _syncClassement(db) {
  const cfg = await _loadFffSeasonConfig(db);
  const { members, lastJournee, httpError } = await _fetchFffClassementLatestMembers(cfg);
  if (httpError) {
    return { journee: 0, rankingTeams: 0, rankingWrites: 0, matchesEnriched: 0, error: httpError };
  }
  if (!members.length) {
    console.warn('Classement FFF vide');
    return { journee: 0, rankingTeams: 0, rankingWrites: 0, matchesEnriched: 0 };
  }

  const existingSnap = await db.collection('ranking').get();
  const existingById = new Map(existingSnap.docs.map((d) => [d.id, d]));

  const batch = db.batch();
  let rankingWrites = 0;

  for (const entry of members) {
    const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const mj       = entry.total_games_count ?? 0;

    const docId = `pos_${entry.rank}`;
    const row = {
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
      journee:   entry.cj_no ?? lastJournee,
    };

    const prev = existingById.get(docId)?.data();
    if (prev && _rankingRowEquals(prev, row)) {
      existingById.delete(docId);
      continue;
    }

    batch.set(db.collection('ranking').doc(docId), {
      ...row,
      updatedAt: Timestamp.now(),
    });
    existingById.delete(docId);
    rankingWrites += 1;
  }

  for (const leftover of existingById.values()) {
    batch.delete(leftover.ref);
    rankingWrites += 1;
  }

  if (rankingWrites > 0) await batch.commit();

  const metaRef = db.collection('competition').doc('meta');
  await metaRef.set({
    journee: lastJournee,
    fffSyncedAt: Timestamp.now(),
    rankingTeamCount: members.length,
    rankingSource: 'fff_classement_journees',
  }, { merge: true });

  console.log(`Classement : ${members.length} équipes, J${lastJournee}, ${rankingWrites} écriture(s)`);

  // ── Enrichit les matchs avec rank depuis le classement ────────────────────
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

  function findRank(teamName) {
    const t = teamName.trim().toUpperCase();
    if (!t) return null;
    if (rankByTeam[t]) return rankByTeam[t];
    for (const [key, val] of Object.entries(rankByTeam)) {
      if (t.includes(key) || key.includes(t)) return val;
    }
    const tWords = t.split(/[\s\-\.]+/).filter(w => w.length > 3);
    for (const [key, val] of Object.entries(rankByTeam)) {
      const kWords = key.split(/[\s\-\.]+/).filter(w => w.length > 3);
      if (tWords.some(w => kWords.includes(w))) return val;
    }
    return null;
  }

  const matchesSnap = await db.collection('matches').get();

  const nowMs = Date.now();
  const enrichPastMs = nowMs - FFF_SYNC_PAST_DAYS * 86400000;
  const enrichUntilMs = nowMs + FFF_RANK_ENRICH_FUTURE_DAYS * 86400000;
  const matchBatch = db.batch();
  let enriched = 0;
  let enrichSkipped = 0;
  for (const doc of matchesSnap.docs) {
    const d = doc.data();
    if (!_matchBelongsToFffSeason(d, cfg.seasonLabel)) {
      enrichSkipped += 1;
      continue;
    }
    const matchMs = d.date?.toMillis?.() ?? 0;
    if (matchMs < enrichPastMs || matchMs > enrichUntilMs) {
      enrichSkipped += 1;
      continue;
    }
    const status = d.status ?? 'upcoming';
    if (status !== 'upcoming' && status !== 'finished') {
      enrichSkipped += 1;
      continue;
    }
    const r1 = findRank(d.team1 ?? '');
    const r2 = findRank(d.team2 ?? '');
    if (!r1 && !r2) continue;
    const update = {};
    if (r1 && (d.rank1 !== r1.rank || d.form1 !== r1.form)) {
      update.rank1 = r1.rank;
      update.form1 = r1.form;
    }
    if (r2 && (d.rank2 !== r2.rank || d.form2 !== r2.form)) {
      update.rank2 = r2.rank;
      update.form2 = r2.form;
    }
    if (Object.keys(update).length === 0) {
      enrichSkipped += 1;
      continue;
    }
    matchBatch.update(doc.ref, update);
    enriched += 1;
  }
  if (enriched > 0) await matchBatch.commit();
  console.log(
    `Matchs enrichis rank/form : ${enriched} écrit(s), ${enrichSkipped} ignoré(s)`,
  );

  return {
    journee: lastJournee,
    rankingTeams: members.length,
    rankingWrites,
    matchesEnriched: enriched,
  };
}

// ── Sync matchs FFF → collection "matches" (lecture API complète, écritures ciblées) ─
async function _syncMatches(db) {
  const cfg = await _loadFffSeasonConfig(db);
  const headers = { Accept: 'application/ld+json' };
  const seenIds = new Set();
  const stats = { written: 0, newDoc: 0, updated: 0, unchanged: 0, frozen: 0, manual: 0 };

  let url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/matchs?journee=1`;

  while (url) {
    const res = await fetch(url, { headers });
    if (!res.ok) { console.error('Matchs HTTP', res.status, url); break; }
    const data = await res.json();

    for (const m of data['hydra:member'] ?? []) {
      const r = await _writeMatch(db, m, seenIds, cfg);
      if (r.written) stats.written += 1;
      if (r.reason === 'new') stats.newDoc += 1;
      if (r.reason === 'updated') stats.updated += 1;
      if (r.reason === 'unchanged') stats.unchanged += 1;
      if (r.reason === 'frozen') stats.frozen += 1;
      if (r.reason === 'manual') stats.manual += 1;
    }

    const next = data['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }

  console.log(
    `FFF matchs : ${stats.written} écrit(s) (${stats.newDoc} nouveau(x), ${stats.updated} modif(s)), ` +
    `${stats.unchanged} inchangé(s), ${stats.frozen} ancien(s) gelé(s), ${stats.manual} manuel(s)`,
  );
}

/** Données match normalisées pour comparer API ↔ Firestore (sans updatedAt). */
function _fffMatchFieldsFromApi(match, cfg) {
  const homeTeam = match.home?.short_name ?? '';
  const awayTeam = match.away?.short_name ?? '';
  const dateStr = match.date;
  if (!dateStr || !homeTeam || !awayTeam) return null;

  const matchDate = _parseMatchDate(dateStr, match.time);
  const score1 = _parseScore(match.home_score);
  const score2 = _parseScore(match.away_score);
  const isFinished = score1 !== null && score2 !== null;
  const isPast = matchDate < new Date();

  return {
    team1: homeTeam,
    team2: awayTeam,
    logo1: match.home?.club?.logo ?? null,
    logo2: match.away?.club?.logo ?? null,
    score1,
    score2,
    dateMs: matchDate.getTime(),
    competition: cfg.competitionDisplayName,
    status: isFinished || isPast ? 'finished' : 'upcoming',
    fffId: String(match.ma_no),
    fffSeason: cfg.seasonLabel,
  };
}

function _fffMatchFieldsFromDoc(data) {
  const dateMs = data.date?.toMillis?.() ?? 0;
  return {
    team1: data.team1 ?? '',
    team2: data.team2 ?? '',
    logo1: data.logo1 ?? null,
    logo2: data.logo2 ?? null,
    score1: data.score1 ?? null,
    score2: data.score2 ?? null,
    dateMs,
    competition: data.competition ?? '',
    status: data.status ?? 'upcoming',
    fffId: String(data.fffId ?? ''),
    fffSeason: data.fffSeason ?? '',
  };
}

function _fffMatchFieldsEqual(a, b) {
  if (!a || !b) return false;
  return (
    a.team1 === b.team1 &&
    a.team2 === b.team2 &&
    a.logo1 === b.logo1 &&
    a.logo2 === b.logo2 &&
    a.score1 === b.score1 &&
    a.score2 === b.score2 &&
    a.dateMs === b.dateMs &&
    a.competition === b.competition &&
    a.status === b.status &&
    a.fffId === b.fffId &&
    a.fffSeason === b.fffSeason
  );
}

function _isInFffMatchSyncWindow(dateMs, nowMs = Date.now()) {
  const past = nowMs - FFF_SYNC_PAST_DAYS * 86400000;
  const future = nowMs + FFF_SYNC_FUTURE_DAYS * 86400000;
  return dateMs >= past && dateMs <= future;
}

function _rankingRowEquals(prev, row) {
  return (
    (prev.position ?? 0) === (row.position ?? 0) &&
    (prev.team ?? '') === (row.team ?? '') &&
    (prev.logo ?? null) === (row.logo ?? null) &&
    (prev.mj ?? 0) === (row.mj ?? 0) &&
    (prev.v ?? 0) === (row.v ?? 0) &&
    (prev.n ?? 0) === (row.n ?? 0) &&
    (prev.d ?? 0) === (row.d ?? 0) &&
    (prev.bf ?? 0) === (row.bf ?? 0) &&
    (prev.bc ?? 0) === (row.bc ?? 0) &&
    (prev.pts ?? 0) === (row.pts ?? 0) &&
    (prev.forme ?? '') === (row.forme ?? '') &&
    (prev.season ?? '') === (row.season ?? '')
  );
}

async function _writeMatch(db, match, seenIds, cfg) {
  const fffId = match.ma_no;
  if (!fffId || seenIds.has(fffId)) {
    return { written: false, reason: 'duplicate' };
  }
  seenIds.add(fffId);

  const fields = _fffMatchFieldsFromApi(match, cfg);
  if (!fields) return { written: false, reason: 'invalid' };

  const docId = `${cfg.matchDocIdPrefix}${fffId}`;
  const ref = db.collection('matches').doc(docId);
  const existing = await ref.get();
  if (existing.exists && existing.data()?.manual === true) {
    return { written: false, reason: 'manual' };
  }

  const prevFields = existing.exists ? _fffMatchFieldsFromDoc(existing.data()) : null;
  const nowMs = Date.now();

  if (prevFields && _fffMatchFieldsEqual(prevFields, fields)) {
    if (!_isInFffMatchSyncWindow(fields.dateMs, nowMs)) {
      return { written: false, reason: 'frozen' };
    }
    return { written: false, reason: 'unchanged' };
  }

  if (
    prevFields &&
    !_isInFffMatchSyncWindow(fields.dateMs, nowMs) &&
    fields.status === 'finished' &&
    prevFields.status === 'finished'
  ) {
    return { written: false, reason: 'frozen' };
  }

  await ref.set({
    team1: fields.team1,
    team2: fields.team2,
    logo1: fields.logo1,
    logo2: fields.logo2,
    score1: fields.score1,
    score2: fields.score2,
    date: Timestamp.fromMillis(fields.dateMs),
    competition: fields.competition,
    status: fields.status,
    fffId: fields.fffId,
    fffSeason: fields.fffSeason,
    updatedAt: Timestamp.now(),
  }, { merge: true });

  return { written: true, reason: prevFields ? 'updated' : 'new' };
}

// "2025-08-24" ou "2025-08-24T00:00:00+00:00" + "16H00" → Date (jour civil Europe/Paris)
function _parseMatchDate(dateStr, timeStr) {
  const parts = String(dateStr ?? '').match(/(\d{4})-(\d{2})-(\d{2})/);
  if (!parts) {
    return new Date(dateStr);
  }
  const y = parseInt(parts[1], 10);
  const mo = parseInt(parts[2], 10) - 1;
  const day = parseInt(parts[3], 10);
  let h = 15;
  let min = 0;
  if (timeStr) {
    const tm = String(timeStr).match(/(\d+)H(\d+)/i);
    if (tm) {
      h = parseInt(tm[1], 10);
      min = parseInt(tm[2], 10);
    }
  }
  const probe = new Date(Date.UTC(y, mo, day, 12, 0, 0));
  const offset = _getParisOffsetHours(probe);
  return new Date(Date.UTC(y, mo, day, h - offset, min, 0, 0));
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

function _isSedanCssaReminderMatch(m) {
  const t1 = String(m.team1 || '').toUpperCase();
  const t2 = String(m.team2 || '').toUpperCase();
  return t1.includes('SEDAN') || t1.includes('CSSA') ||
         t2.includes('SEDAN') || t2.includes('CSSA');
}

function _defaultMatchReminderTitle() {
  return '⚽ Match Sedan';
}

function _defaultMatchReminderBody(m) {
  const a = m.team1 || '?';
  const b = m.team2 || '?';
  return `${a} vs ${b} — même rendez-vous que sur l’accueil.`;
}

// ── Rappels match Sedan/CSSA : uniquement depuis l’admin (pas de cron = moins de coût) ─
exports.getMatchReminderCandidates = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const now = Timestamp.now();
  const snap = await db.collection('matches')
    .where('status', '==', 'upcoming')
    .where('date', '>', now)
    .orderBy('date')
    .limit(80)
    .get();

  const matches = [];
  for (const doc of snap.docs) {
    const m = doc.data();
    if (!_isSedanCssaReminderMatch(m)) continue;
    const kick = m.date?.toMillis?.() ?? null;
    matches.push({
      matchId: doc.id,
      team1: String(m.team1 ?? ''),
      team2: String(m.team2 ?? ''),
      kickoffMs: kick,
      suggestedTitle: _defaultMatchReminderTitle(),
      suggestedBody: _defaultMatchReminderBody(m),
    });
    if (matches.length >= 20) break;
  }

  return { matches };
});

exports.sendMatchReminderManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const payload = request.data || {};
  const matchId = typeof payload.matchId === 'string' ? payload.matchId.trim() : '';
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }

  const titleOverride = typeof payload.title === 'string' ? payload.title.trim() : '';
  const bodyOverride = typeof payload.body === 'string' ? payload.body.trim() : '';

  const docRef = db.collection('matches').doc(matchId);
  const doc = await docRef.get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'Match introuvable');
  }
  const m = doc.data();
  if (m.status !== 'upcoming') {
    throw new HttpsError('failed-precondition', 'Le match doit être à venir (upcoming)');
  }
  if (!_isSedanCssaReminderMatch(m)) {
    throw new HttpsError('failed-precondition', 'Réservé aux matchs impliquant Sedan / CSSA');
  }

  const finalTitle = titleOverride || _defaultMatchReminderTitle();
  const finalBody = bodyOverride || _defaultMatchReminderBody(m);
  const targetPlatform = String(payload.targetPlatform || 'all').trim().toLowerCase();

  const messageBase = {
    notification: {
      title: finalTitle,
      body: finalBody,
    },
    data: { type: 'match_reminder', matchId },
    ...fcmChannelBlocks('dvcr_notifications'),
  };

  const broadcast = await _sendManualBroadcast(
    db,
    messageBase,
    targetPlatform,
    'all',
    finalTitle,
    null,
  );
  if (broadcast.sentCount === 0) {
    throw new HttpsError(
      'failed-precondition',
      'Aucun appareil iOS/Android trouvé pour cette cible',
    );
  }

  const logId = `reminder_admin_${matchId}_${Date.now()}`;
  await db.collection('match_notifs_sent').doc(logId).set({
    sentAt: Timestamp.now(),
    type: 'reminder_admin_manual',
    title: finalTitle,
    body: finalBody,
    matchId,
    sentByUid: request.auth.uid,
    targetPlatform,
    sendMode: broadcast.mode,
    recipientsCount: broadcast.sentCount,
    ...(broadcast.iosCount != null ? { iosCount: broadcast.iosCount } : {}),
    ...(broadcast.androidCount != null ? { androidCount: broadcast.androidCount } : {}),
  });

  console.log(
    `[Reminder manual] ${finalTitle} — ${matchId} (${broadcast.mode}, ${broadcast.sentCount})`,
  );
  return {
    success: true,
    matchId,
    sendMode: broadcast.mode,
    recipientsCount: broadcast.sentCount,
  };
});

// ── Notif compositions disponibles (déclenchée manuellement par l'admin) ─────
exports.notifyLineups = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const payload = request.data || {};
  const matchId = typeof payload.matchId === 'string' ? payload.matchId.trim() : '';
  const titleOverride = typeof payload.title === 'string' ? payload.title.trim() : '';
  const bodyOverride = typeof payload.body === 'string' ? payload.body.trim() : '';

  let team1 = '';
  let team2 = '';
  if (matchId) {
    const matchSnap = await db.collection('matches').doc(matchId).get();
    if (matchSnap.exists) {
      team1 = (matchSnap.data().team1 ?? '').toString().trim();
      team2 = (matchSnap.data().team2 ?? '').toString().trim();
    }
  }

  const matchLine = team1 && team2 ? `${team1} — ${team2}` : '';
  const finalTitle = titleOverride || '📋 Compositions disponibles !';
  const finalBody = bodyOverride ||
    (matchLine
      ? `Les compos de ${matchLine} sont là — viens les consulter 🔥`
      : 'Les compositions des deux équipes sont disponibles — viens les consulter 🔥');

  await _sendFcm(db, {
    topic: 'dvcr_live',
    notification: { title: finalTitle, body: finalBody },
    data: {
      type: 'lineups_available',
      ...(matchId ? { matchId } : {}),
    },
    ...fcmChannelBlocks('dvcr_live'),
  }, 'lineups notify');

  console.log(`[notifyLineups] sent: ${finalTitle} — matchId=${matchId || '—'}`);
  return { success: true };
});

// ── Pronostics — calcul des points quand un match passe à "finished" ───────
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

  for (const doc of predsSnap.docs) {
    const pred = doc.data();
    const uid = pred.uid;
    if (!uid) continue;
    const p1 = pred.score1Pred;
    const p2 = pred.score2Pred;
    let eventType = null;
    if (p1 === score1 && p2 === score2) {
      eventType = 'prono_correct';
    } else {
      const predResult = Math.sign(p1 - p2);
      const realResult = Math.sign(score1 - score2);
      if (predResult === realResult) eventType = 'prono_good_result';
    }
    if (eventType) {
      await _awardXpToUser(db, uid, eventType, { matchId });
    }
  }

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
      await _awardXpToUser(db, winnerUid, 'duel_won', { matchId, duelId: duelDoc.id });
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

function _liveJsonEq(a, b) {
  return JSON.stringify(a ?? null) === JSON.stringify(b ?? null);
}

/** Changements qui peuvent déclencher but / cartons / mi-temps (hors bloc stats seul). */
function _liveNotifiableFieldsChanged(before, after) {
  const keys = [
    'scoreHome', 'scoreAway', 'yellowHome', 'yellowAway', 'redHome', 'redAway',
    'lastEvent', 'minute', 'events',
    'chronoRunning', 'chronoBaseSeconds', 'chronoStartedAtMs',
    'logo1', 'logo2', 'team1', 'team2',
  ];
  for (const k of keys) {
    if (!_liveJsonEq(before[k], after[k])) return true;
  }
  return false;
}

function _liveScoreCompact(h, a) {
  return `${h ?? 0} : ${a ?? 0}`;
}

function _liveShortTeam(name, maxLen = 18) {
  const t = String(name || '').trim();
  if (!t) return '—';
  return t.length <= maxLen ? t : `${t.slice(0, maxLen - 1)}…`;
}

function _liveJoinParts(parts) {
  return parts
    .map((p) => String(p || '').trim())
    .filter(Boolean)
    .join(' · ');
}

/** Ligne DI / carte : minute puis fait (buteur, carton…). */
function _liveEventDetail({ minute, player, prefix = '' }) {
  const minBit =
    minute !== '' && minute != null && String(minute).trim()
      ? `${String(minute).trim()}'`
      : '';
  const p = String(player || '').trim();
  const playerBit = p ? (prefix ? `${prefix} ${p}` : p) : '';
  return _liveJoinParts([minBit, playerBit]);
}

function _liveIslandTitle(team1, team2) {
  return _liveMatchLine(team1, team2);
}

/** Payload FCM pour resync Live Activity sans ouvrir l’app. */
function _liveActivityFcmData(after, extra = {}) {
  const events = Array.isArray(after?.events) ? after.events : [];
  const last = events.length ? events[events.length - 1] : null;
  let lastEventLine = String(extra.lastEventLine || '').trim();
  if (!lastEventLine && last && last.player) {
    const min = last.minute != null ? `${last.minute}'` : '';
    lastEventLine = _liveJoinParts([min, String(last.player || '')]);
  }
  return {
    syncLiveActivity: '1',
    matchId: String(after?.matchId || ''),
    scoreHome: String(after?.scoreHome ?? 0),
    scoreAway: String(after?.scoreAway ?? 0),
    team1: String(after?.team1 || ''),
    team2: String(after?.team2 || ''),
    minute: String(after?.minute ?? 0),
    logo1: String(after?.logo1 || ''),
    logo2: String(after?.logo2 || ''),
    chronoRunning: after?.chronoRunning ? '1' : '0',
    chronoBaseSeconds: String(after?.chronoBaseSeconds ?? 0),
    chronoStartedAtMs: String(after?.chronoStartedAtMs ?? 0),
    lastEvent: String(after?.lastEvent || ''),
    lastEventLine,
    alertTitle: String(extra.alertTitle || ''),
    alertBody: String(extra.alertBody || ''),
    alertShortBody: String(extra.alertShortBody || ''),
    ...extra,
  };
}

async function _sendLiveActivitySyncFcm(
  db,
  after,
  logLabel = 'live silent sync',
  extra = {},
  topic = 'dvcr_live',
) {
  const type = String(extra.type || 'live_sync');
  await _sendFcm(db, {
    topic,
    data: {
      ..._liveActivityFcmData(after, extra),
      type,
    },
    ...fcmChannelBlocks(topic, { silent: true, contentAvailable: true, priority: 'normal' }),
  }, logLabel);
}

/** Sync Live Activity sans bannière (buts, cartons, faits de jeu). */
async function _sendLiveCardSyncFcm(db, after, extra = {}, logLabel = 'live card sync') {
  await Promise.all([
    _sendLiveActivitySyncFcm(db, after, `${logLabel} [live]`, extra, 'dvcr_live'),
    _sendLiveActivitySyncFcm(db, after, `${logLabel} [events]`, extra, 'dvcr_live_events'),
  ]);
}

async function _sendLiveEndFcm(db) {
  const payload = { syncLiveActivity: '1', type: 'live_end', endLive: '1' };
  const silent = { silent: true, contentAvailable: true, priority: 'normal' };
  await Promise.all([
    _sendFcm(db, {
      topic: 'dvcr_live',
      data: payload,
      ...fcmChannelBlocks('dvcr_live', silent),
    }, 'live end [live]'),
    _sendFcm(db, {
      topic: 'dvcr_live_events',
      data: payload,
      ...fcmChannelBlocks('dvcr_live_events', silent),
    }, 'live end [events]'),
  ]);
}

/** Sync Live Activity silencieux — alertTitle = match (DI), alertShortBody = minute · fait. */
async function _sendLiveEventSyncFcm(
  db,
  after,
  {
    type,
    title = '',
    body = '',
    shortBody = '',
    lastEventLine = '',
    islandTitle = '',
    logLabel = 'live event',
  },
) {
  const line = String(lastEventLine || shortBody || '').trim();
  const short = String(shortBody || '').trim();
  const matchLine = String(islandTitle || '').trim();
  const extra = {
    type,
    lastEventLine: line,
    alertTitle: matchLine,
    alertBody: short || line,
    alertShortBody: short,
  };
  await _sendLiveLaSyncBothTopics(db, after, extra, logLabel);
}

/** Sync Live Activity (carte verte / DI) + push locale si pas de LA — jamais de bannière FCM si LA active. */
async function _sendLiveEventNotifyFcm(db, after, opts) {
  const line = String(opts.lastEventLine || opts.body || '').trim();
  const short = String(opts.shortBody || '').trim();
  await _sendLiveEventSyncFcm(db, after, {
    type: opts.type,
    title: opts.title,
    body: opts.body || line,
    shortBody: short,
    lastEventLine: line,
    islandTitle: opts.islandTitle || '',
    logLabel: opts.logLabel || 'live event',
  });

  // Bannière système (app tuée / arrière-plan) — supprimée côté iOS si Live Activity active.
  if (opts.alsoPushBanner) {
    const matchLine = String(opts.islandTitle || '').trim();
    const data = {
      ..._liveActivityFcmData(after, {
        type: opts.type,
        lastEventLine: line,
        alertTitle: matchLine,
        alertBody: short || line,
        alertShortBody: short,
        notifyVisible: '1',
        ...(opts.extraData || {}),
      }),
    };
    await _sendFcm(db, {
      topic: 'dvcr_live',
      notification: { title: opts.title, body: opts.body || line },
      data,
      ...fcmChannelBlocks('dvcr_live'),
    }, `${opts.logLabel || 'live event'} banner`);
  }
}

/** @deprecated alias — sync riche uniquement, pas de bloc notification FCM. */
async function _sendLiveVisibleNotifyFcm(db, after, opts) {
  return _sendLiveEventNotifyFcm(db, after, opts);
}

async function _sendLiveKickoffNotifyFcm(db, after, opts) {
  return _sendLiveEventNotifyFcm(db, after, opts);
}

function _matchRatingSessionPatch(after) {
  if (String(after.matchRatingStatus || '').trim() === 'active') return null;
  const team1 = String(after.team1 || '').trim();
  const team2 = String(after.team2 || '').trim();
  const title = team1 && team2 ? `${team1} — ${team2}` : 'Note du match';
  const bg = String(after.motmVoteBackgroundImage || '').trim();
  const counts = {};
  for (let n = 1; n <= 10; n++) counts[String(n)] = 0;
  return {
    matchRatingPending: false,
    matchRatingStatus: 'active',
    matchRatingSessionId: `${Date.now()}`,
    matchRatingTitle: title,
    matchRatingBackgroundImage: bg,
    matchRatingCounts: counts,
    matchRatingTotal: 0,
    matchRatingSum: 0,
    matchRatingAverage: 0.0,
    matchRatingStartedAt: FieldValue.serverTimestamp(),
  };
}

/** Sync Live Activity sur les deux topics (sans bannière). */
async function _sendLiveLaSyncBothTopics(db, after, extra = {}, logLabel = 'live sync') {
  await Promise.all([
    _sendLiveActivitySyncFcm(db, after, `${logLabel} [live]`, extra, 'dvcr_live'),
    _sendLiveActivitySyncFcm(db, after, `${logLabel} [events]`, extra, 'dvcr_live_events'),
  ]);
}

function _liveEventAlertPushCopy(alert, team1, team2, h, a) {
  const t = String(alert.type || '');
  const player = String(alert.player || '').trim();
  const minute = alert.minute != null ? String(alert.minute) : '';
  const teamLabel = String(alert.team || '').trim();
  const scoreLine = `${team1} ${h}-${a} ${team2}`;
  let title = null;
  let body = null;
  let dataType = t;

  switch (t) {
    case 'offside':
      title = `🚩 Hors-jeu${teamLabel ? ` — ${teamLabel}` : ''}`;
      body = player
        ? `${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : scoreLine;
      break;
    case 'goal_cancelled':
      title = `❌ But annulé${teamLabel ? ` — ${teamLabel}` : ''}`;
      body = player
        ? `${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : scoreLine;
      break;
    case 'goal_disallowed':
      title = `🚫 But refusé${teamLabel ? ` — ${teamLabel}` : ''}`;
      body = player
        ? `${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : scoreLine;
      break;
    case 'goal':
      title = `⚽ BUT · ${h}:${a}`;
      body = player
        ? `${teamLabel} — ${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : `${teamLabel} · ${scoreLine}`;
      dataType = 'goal';
      break;
    case 'yellow':
      title = `🟨 Carton jaune${teamLabel ? ` — ${teamLabel}` : ''}`;
      body = player
        ? `${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : scoreLine;
      break;
    case 'red':
      title = `🟥 Carton rouge${teamLabel ? ` — ${teamLabel}` : ''}`;
      body = player
        ? `${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : scoreLine;
      break;
    case 'substitution':
      title = `🔄 Changement${teamLabel ? ` — ${teamLabel}` : ''}`;
      body = player
        ? `${player}${minute ? ` (${minute}')` : ''} · ${scoreLine}`
        : scoreLine;
      break;
    default:
      break;
  }
  if (!title) return null;
  const matchLine = _liveMatchLine(team1, team2);
  const emojiPrefix = {
    goal: '⚽',
    yellow: '🟨',
    red: '🟥',
    substitution: '🔄',
    offside: '🚩',
    goal_cancelled: '⊘',
    goal_disallowed: '🚫',
  }[t] || '';
  const cardLine = _liveEventDetail({ minute, player, prefix: emojiPrefix });
  const minBit = minute ? `${minute}'` : '';
  const shortBody = cardLine || _livePhaseCardLine(t) || minBit;
  return {
    title,
    body: body || scoreLine,
    dataType,
    shortBody,
    islandTitle: matchLine,
    cardLine: shortBody,
  };
}

function _livePhaseCardLine(lastEvent) {
  switch (String(lastEvent || '')) {
    case 'halftime': return 'Mi-temps';
    case 'fulltime': return 'Fin du match';
    case 'extra_time': return 'Prolongations';
    case 'extra_halftime': return 'Mi-temps prolongations';
    case 'extra_fulltime': return 'Fin des prolongations';
    default: return '';
  }
}

function _liveMatchLine(team1, team2) {
  return `${_liveShortTeam(team1)} – ${_liveShortTeam(team2)}`;
}

/** Texte bannière push — titre court, corps sans doublons score/équipe. */
function _liveEventPushCopy({
  type,
  player,
  minute,
  scoreHome,
  scoreAway,
  team1,
  team2,
}) {
  const score = _liveScoreCompact(scoreHome, scoreAway);
  const p = String(player || '').trim();
  const minBit =
    minute !== '' && minute != null && String(minute).trim()
      ? `${String(minute).trim()}'`
      : '';
  const detail = _liveJoinParts([p, minBit]);
  const matchLine = _liveMatchLine(team1, team2);

  switch (type) {
    case 'goal':
      return {
        title: `⚽ BUT · ${score}`,
        body: detail || matchLine,
      };
    case 'yellow':
      return {
        title: '🟨 Carton jaune',
        body: _liveJoinParts([detail, score]),
      };
    case 'red':
      return {
        title: '🟥 Carton rouge',
        body: _liveJoinParts([detail, score]),
      };
    case 'substitution':
      return {
        title: `🔄 Changement · ${score}`,
        body: detail || matchLine,
      };
    case 'goal_cancelled':
      return {
        title: `But annulé · ${score}`,
        body: detail || matchLine,
      };
    case 'goal_disallowed':
      return {
        title: `But refusé · ${score}`,
        body: detail || matchLine,
      };
    case 'offside':
      return {
        title: `Hors-jeu · ${score}`,
        body: detail || matchLine,
      };
    default:
      return null;
  }
}

// ── Notifications live (but, mi-temps, fin de match) ─────────────────────────
exports.notifyGoal = onDocumentWritten('live/current', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();

  // ── Début de match (document créé) ──
  if (!before && after) {
    const db = getFirestore();
    const team1 = after.team1 || 'Domicile';
    const team2 = after.team2 || 'Extérieur';

    if (!after.statsSessionId) {
      const sessionId = `sess_${Date.now()}`;
      const title = [after.team1, after.team2].filter(Boolean).join(' — ') ||
        `Direct ${APP_BRAND_NAME}`;
      await db.collection('live_stats_sessions').doc(sessionId).set({
        startedAt: FieldValue.serverTimestamp(),
        team1: after.team1 || '',
        team2: after.team2 || '',
        matchId: after.matchId || '',
        liveUrl: after.url || '',
        title,
        peakViewers: 0,
        viewersByHour: {},
        samples: [],
        platformTotals: { tv: 0, mobile: 0, other: 0 },
        uniqueViewerCount: 0,
        averageViewers: 0,
        status: 'live',
        source: after.tvBroadcast ? 'tv_admin' : 'admin',
      });
      await event.data.after.ref.set({ statsSessionId: sessionId, viewers: 0 }, { merge: true });
    }

    await _sendLiveKickoffNotifyFcm(db, after, {
      type: 'live_start',
      title: `🔴 Nous sommes en live — ${APP_BRAND_NAME} !`,
      body: `${team1} vs ${team2}`,
      shortBody: 'EN LIVE',
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: '',
      logLabel: 'live start',
      alsoPushBanner: true,
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

    const sessionId = (before.statsSessionId ?? '').toString();
    if (sessionId) {
      try {
        await _finalizeLiveStatsSession(db, sessionId, before);
      } catch (e) {
        console.error('[finalizeLiveStatsSession]', e);
      }
    }

    // Sauvegarde le résumé dans le doc match si matchId présent
    const matchId = before.matchId ?? '';
    if (matchId) {
      const matchRef = db.collection('matches').doc(matchId);
      const matchSnap = await matchRef.get();
      const existing = matchSnap.exists ? matchSnap.data() : {};
      const liveEv = Array.isArray(before.events) ? before.events : [];
      const docEv = Array.isArray(existing.events) ? existing.events : [];
      const legacyEv = Array.isArray(existing.liveEvents) ? existing.liveEvents : [];
      const events = _mergeGameEvents(
        _mergeGameEvents(docEv, legacyEv),
        liveEv,
      );
      const patch = {
        liveScore1: h,
        liveScore2: a,
        score1: h,
        score2: a,
        scoreHome: h,
        scoreAway: a,
        events,
        yellowHome: before.yellowHome ?? 0,
        yellowAway: before.yellowAway ?? 0,
        redHome: before.redHome ?? 0,
        redAway: before.redAway ?? 0,
        stats: before.stats ?? {},
        manOfTheMatchName: before.manOfTheMatchName ?? '',
        manOfTheMatchPartnerName: before.manOfTheMatchPartnerName ?? '',
        manOfTheMatchPartnerLogo: before.manOfTheMatchPartnerLogo ?? '',
        showStats: _statsMapNonEmpty(before.stats) || events.length > 0,
        status: 'finished',
        liveAt: FieldValue.serverTimestamp(),
        liveEvents: FieldValue.delete(),
      };
      await matchRef.set(patch, { merge: true });
      if (events.length > 0 || _statsMapNonEmpty(before.stats)) {
        await db.collection('match_stats').doc(matchId).set({
          matchId,
          events,
          stats: before.stats ?? {},
          state: 'preview',
          previewEnabled: true,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      console.log(`Résumé live sauvegardé dans match ${matchId}`);
    }

    await _sendLiveEndFcm(db);
    return;
  }

  if (!before || !after) return;

  const team1 = after.team1 || 'Domicile';
  const team2 = after.team2 || 'Extérieur';
  const h     = after.scoreHome  ?? 0;
  const a     = after.scoreAway  ?? 0;
  const db    = getFirestore();

  const alert = after.lastEventAlert;
  if (alert && typeof alert === 'object' && !_liveJsonEq(before?.lastEventAlert, alert)) {
    const push = _liveEventAlertPushCopy(alert, team1, team2, h, a);
    if (push) {
      await _sendLiveEventNotifyFcm(db, after, {
        type: push.dataType,
        title: push.title,
        body: push.body,
        shortBody: push.shortBody,
        islandTitle: push.islandTitle,
        lastEventLine: push.cardLine,
        logLabel: `live alert ${push.dataType}`,
      });
      try {
        const snap = await event.data.after.ref.get();
        const current = snap.data()?.lastEventAlert;
        if (_liveJsonEq(current, alert)) {
          await event.data.after.ref.update({ lastEventAlert: FieldValue.delete() });
        }
      } catch (e) {
        console.warn('[lastEventAlert] clear failed:', e.message);
      }
      return;
    }
  }

  const notifiable = _liveNotifiableFieldsChanged(before, after);
  if (!notifiable) return;

  if (notifiable) {
  // ── Coup d'envoi (1er démarrage chrono, pas reprise mi-temps) ──
  const chronoStarted = !before.chronoRunning && after.chronoRunning;
  const minuteNow = after.minute ?? Math.floor((after.chronoBaseSeconds ?? 0) / 60);
  const isRealKickoff = chronoStarted
    && minuteNow < 2
    && before.lastEvent !== 'halftime'
    && before.lastEvent !== 'extra_halftime';
  if (isRealKickoff) {
    await _sendLiveKickoffNotifyFcm(db, after, {
      type: 'kickoff',
      title: `⚽ Coup d'envoi — ${APP_BRAND_NAME} !`,
      body: `${team1} vs ${team2}`,
      shortBody: "Coup d'envoi",
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: "Coup d'envoi",
      logLabel: 'live chrono kickoff',
      alsoPushBanner: true,
    });
    return;
  }

  // ── Mi-temps ──
  if (after.lastEvent === 'halftime' && before.lastEvent !== 'halftime') {
    await _sendLiveEventNotifyFcm(db, after, {
      type: 'halftime',
      title: `⏸ Mi-temps — ${APP_BRAND_NAME}`,
      body: `Score : ${team1} ${h} - ${a} ${team2}`,
      shortBody: 'Mi-temps',
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: _livePhaseCardLine('halftime'),
      logLabel: 'live halftime',
    });
    return;
  }

  if (after.lastEvent === 'fulltime' && before.lastEvent !== 'fulltime') {
    const ratingPatch = _matchRatingSessionPatch(after);
    if (ratingPatch) {
      await event.data.after.ref.set(ratingPatch, { merge: true });
    }
    await _sendLiveEventNotifyFcm(db, after, {
      type: 'fulltime',
      title: `🏁 Fin du match — ${APP_BRAND_NAME} !`,
      body: `Score final : ${team1} ${h} - ${a} ${team2}. Notez le match sur l'app !`,
      shortBody: 'Notez le match',
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: _livePhaseCardLine('fulltime'),
      logLabel: 'live fulltime',
      extraData: { openMatchRating: '1' },
    });
    return;
  }

  if (after.lastEvent === 'extra_time' && before.lastEvent !== 'extra_time') {
    await _sendLiveEventNotifyFcm(db, after, {
      type: 'extra_time',
      title: `⏱ Prolongations — ${APP_BRAND_NAME} !`,
      body: `${team1} ${h} - ${a} ${team2}`,
      shortBody: 'Prolongations',
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: _livePhaseCardLine('extra_time'),
      logLabel: 'live extra time start',
    });
    return;
  }

  if (after.lastEvent === 'extra_halftime' && before.lastEvent !== 'extra_halftime') {
    await _sendLiveEventNotifyFcm(db, after, {
      type: 'extra_halftime',
      title: `⏸ Mi-temps prolongations — ${CLUB_SHORT_NAME}`,
      body: `Score : ${team1} ${h} - ${a} ${team2}`,
      shortBody: 'Mi-temps prol.',
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: _livePhaseCardLine('extra_halftime'),
      logLabel: 'live extra halftime',
    });
    return;
  }

  if (after.lastEvent === 'extra_fulltime' && before.lastEvent !== 'extra_fulltime') {
    const ratingPatch = _matchRatingSessionPatch(after);
    if (ratingPatch) {
      await event.data.after.ref.set(ratingPatch, { merge: true });
    }
    await _sendLiveEventNotifyFcm(db, after, {
      type: 'extra_fulltime',
      title: `🏁 Fin des prolongations — ${APP_BRAND_NAME} !`,
      body: `Score final : ${team1} ${h} - ${a} ${team2}. Notez le match sur l'app !`,
      shortBody: 'Notez le match',
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: _livePhaseCardLine('extra_fulltime'),
      logLabel: 'live extra fulltime',
      extraData: { openMatchRating: '1' },
    });
    return;
  }

  // ── But / But annulé (repli si lastEventAlert absent) ──
  const prevHome = before.scoreHome ?? 0;
  const prevAway = before.scoreAway ?? 0;

  let goalType = null;
  if      (h > prevHome) goalType = 'goal';
  else if (a > prevAway) goalType = 'goal';
  else if (h < prevHome) goalType = 'goal_cancelled';
  else if (a < prevAway) goalType = 'goal_cancelled';

  if (goalType) {
    const events   = after.events ?? [];
    const goals    = events.filter(e => e.type === 'goal');
    const lastGoal = goals.length > 0 ? goals[goals.length - 1] : null;
    const player   = lastGoal?.player ?? '';
    const minute   = lastGoal?.minute ?? '';
    const pushCopy = _liveEventPushCopy({
      type: goalType,
      player,
      minute,
      scoreHome: h,
      scoreAway: a,
      team1,
      team2,
    });
    const goalTitle = goalType === 'goal_cancelled' ? '❌ But annulé' : '⚽ BUT !';
    const emoji = goalType === 'goal_cancelled' ? '⊘' : '⚽';
    const cardLine = _liveEventDetail({
      minute,
      player,
      prefix: emoji,
    });
    const body = pushCopy?.body
      || cardLine
      || `${team1} ${h}-${a} ${team2}`;
    await _sendLiveEventNotifyFcm(db, after, {
      type: goalType === 'goal_cancelled' ? 'goal_cancelled' : 'goal',
      title: `${goalTitle} · ${_liveScoreCompact(h, a)}`,
      body,
      shortBody: cardLine || pushCopy?.shortBody || body,
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: cardLine || pushCopy?.cardLine || body,
      logLabel: 'live goal',
    });
    return;
  }

  // ── Carton jaune ──
  const prevYH = before.yellowHome ?? 0;
  const prevYA = before.yellowAway ?? 0;
  const yH     = after.yellowHome  ?? 0;
  const yA     = after.yellowAway  ?? 0;

  if (yH > prevYH || yA > prevYA) {
    const events = after.events ?? [];
    const lastYellow = [...events].reverse().find((e) => e.type === 'yellow');
    const cardTeam = yH > prevYH ? team1 : team2;
    const pushCopy = _liveEventPushCopy({
      type: 'yellow',
      player: lastYellow?.player ?? '',
      minute: lastYellow?.minute ?? '',
      scoreHome: h,
      scoreAway: a,
      team1,
      team2,
    });
    const player = lastYellow?.player ?? '';
    const minute = lastYellow?.minute ?? '';
    const cardLine = _liveEventDetail({ minute, player, prefix: '🟨' });
    await _sendLiveEventSyncFcm(db, after, {
      type: 'yellow_card',
      title: `🟨 Carton jaune · ${_liveScoreCompact(h, a)}`,
      body: pushCopy?.body || `${team1} ${h}-${a} ${team2}`,
      shortBody: cardLine,
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: cardLine,
      logLabel: 'live yellow card',
    });
    return;
  }

  // ── Carton rouge ──
  const prevRH = before.redHome ?? 0;
  const prevRA = before.redAway ?? 0;
  const rH     = after.redHome  ?? 0;
  const rA     = after.redAway  ?? 0;

  if (rH > prevRH || rA > prevRA) {
    const events = after.events ?? [];
    const lastRed = [...events].reverse().find((e) => e.type === 'red');
    const cardTeam = rH > prevRH ? team1 : team2;
    const pushCopy = _liveEventPushCopy({
      type: 'red',
      player: lastRed?.player ?? '',
      minute: lastRed?.minute ?? '',
      scoreHome: h,
      scoreAway: a,
      team1,
      team2,
    });
    const player = lastRed?.player ?? '';
    const minute = lastRed?.minute ?? '';
    const cardLine = _liveEventDetail({ minute, player, prefix: '🟥' });
    await _sendLiveEventSyncFcm(db, after, {
      type: 'red_card',
      title: `🟥 Carton rouge · ${_liveScoreCompact(h, a)}`,
      body: pushCopy?.body || `${team1} ${h}-${a} ${team2}`,
      shortBody: cardLine,
      islandTitle: _liveIslandTitle(team1, team2),
      lastEventLine: cardLine,
      logLabel: 'live red card',
    });
    return;
  }

  // Minute / chrono sans événement dédié → sync silencieux Live Activity uniquement.
  await _sendLiveLaSyncBothTopics(db, after, { type: 'live_sync' }, 'live chrono sync');
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

  const channelId = channelFromTopic(topic);

  const targetPlatform = String(data.targetPlatform || 'all').trim().toLowerCase();
  const testOnlyUid = String(data.testOnlyUid || '').trim();
  const targetAudience = String(data.targetAudience || 'all').trim().toLowerCase();
  const targetUserIds = _normalizeTargetUserIds(data);

  const messageBase = {
    notification: { title, body },
    ...fcmChannelBlocks(channelId),
  };

  if (Object.keys(fcmData).length > 0) {
    messageBase.data = Object.fromEntries(
      Object.entries(fcmData).map(([k, v]) => [k, String(v)]),
    );
  }

  const queueRef = db.collection('notifications_queue').doc(event.params.id);

  try {
    let sentCount = 0;
    let mode = 'platform_all';

    if (testOnlyUid) {
      mode = 'test_only';
      const userSnap = await db.collection('users').doc(testOnlyUid).get();
      if (!userSnap.exists) {
        await queueRef.update({
          status: 'error',
          error: `Utilisateur test introuvable : ${testOnlyUid}`,
        });
        return;
      }
      const ok = await _sendFcmToUser(
        db,
        userSnap.data() ?? {},
        messageBase,
        `manual test ${testOnlyUid}`,
        { recipientUid: testOnlyUid, allowMaintenanceBypass: true },
      );
      if (ok) sentCount = 1;
    } else if (targetAudience === 'all' && targetPlatform === 'all') {
      // Topic FCM = atteint tous les abonnés iOS + Android sans itérer les tokens
      const cfg = await _loadMaintenanceConfig(db);
      if (cfg.paused) {
        if (cfg.bypassUid) {
          mode = 'maintenance_bypass_only';
          const userSnap = await db.collection('users').doc(cfg.bypassUid).get();
          if (userSnap.exists) {
            const ok = await _sendFcmToUser(
              db, userSnap.data() ?? {}, messageBase,
              `manual bypass ${cfg.bypassUid}`,
              { recipientUid: cfg.bypassUid, allowMaintenanceBypass: true },
            );
            if (ok) sentCount = 1;
          }
        }
      } else {
        mode = 'topic';
        const ok = await _sendFcm(db, { ...messageBase, topic }, `manual [${topic}] ${title}`);
        if (ok) sentCount = 1;
      }
    } else if (
      targetAudience === 'all'
      && (targetPlatform === 'ios' || targetPlatform === 'android')
    ) {
      const result = await _sendManualBroadcast(
        db,
        messageBase,
        targetPlatform,
        targetAudience,
        title,
        null,
      );
      sentCount = result.sentCount;
      mode = result.mode;
    } else if (targetAudience === 'team_dvcr') {
      mode = targetUserIds ? 'team_dvcr_selected' : 'team_dvcr';
      sentCount = await _sendTeamDvcrNotification(
        db,
        messageBase,
        `manual [team_dvcr] ${title}`,
        {
          targetUserIds,
          platform: targetPlatform !== 'all' ? targetPlatform : null,
        },
      );
    } else if (targetAudience === 'adherent') {
      mode = targetUserIds ? 'adherent_selected' : 'adherent';
      sentCount = await _sendAdherentNotification(
        db,
        messageBase,
        `manual [adherent] ${title}`,
        {
          targetUserIds,
          platform: targetPlatform !== 'all' ? targetPlatform : null,
        },
      );
    } else {
      const cfg = await _loadMaintenanceConfig(db);
      if (cfg.paused) {
        if (cfg.bypassUid) {
          mode = 'maintenance_bypass_only';
          const userSnap = await db.collection('users').doc(cfg.bypassUid).get();
          if (userSnap.exists) {
            const ok = await _sendFcmToUser(
              db,
              userSnap.data() ?? {},
              messageBase,
              `manual bypass ${cfg.bypassUid}`,
              { recipientUid: cfg.bypassUid, allowMaintenanceBypass: true },
            );
            if (ok) sentCount = 1;
          }
        }
      } else {
        const result = await _sendManualBroadcast(
          db,
          messageBase,
          targetPlatform,
          targetAudience,
          title,
          null,
        );
        sentCount = result.sentCount;
        mode = result.mode;
      }
    }

    if (sentCount === 0) {
      const paused = await _notificationsPaused(db);
      await queueRef.update({
        status: 'skipped',
        skipReason: paused ? 'maintenance' : 'no_recipients',
        skippedAt: FieldValue.serverTimestamp(),
        sendMode: mode,
        targetPlatform,
        targetAudience,
      });
      console.log(`[manual] ignorée (${mode}) : ${title}`);
      return;
    }
    await queueRef.update({
      status: 'sent',
      sentAt: FieldValue.serverTimestamp(),
      sendMode: mode,
      targetPlatform,
      targetAudience,
      recipientsCount: sentCount,
      ...(targetUserIds ? { targetUserIds } : {}),
    });
    console.log(`Notif manuelle envoyée (${mode}, ${sentCount}) : ${title}`);
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
    if (await _notificationsPaused(db)) {
      console.log('[maintenance] notifyRankingMotivation skipped');
      return;
    }
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
      if (!_userFcmTokens(udata).length) continue;

      const prefs = udata.notificationPrefs || {};
      const last = prefs.lastRankingDigestSentAt;
      if (last && typeof last.toMillis === 'function' && now - last.toMillis() < minGapMs) {
        continue;
      }

      const ord = rank === 1 ? '1er' : `${rank}e`;
      try {
        const ok = await _sendFcmToUser(
          db,
          udata,
          {
            notification: {
              title: 'Classement prono DVCR',
              body: `Tu es ${ord} avec ${pts} pts — continue pour grimper !`,
            },
            data: { type: 'ranking_motivation', rank: String(rank) },
            ...fcmChannelBlocks('dvcr_alerts', { priority: 'normal' }),
          },
          `ranking motivation ${uid}`,
          { recipientUid: uid },
        );
        if (!ok) continue;
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
  prono_good_result: 8,
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
  duel_won:          10,
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
  { level: 1, name: 'Recrue',      xpRequired: 0    },
  { level: 2, name: 'Fan',         xpRequired: 150  },
  { level: 3, name: 'Supporter',   xpRequired: 400  },
  { level: 4, name: 'Ultra',       xpRequired: 900  },
  { level: 5, name: 'Capitaine',   xpRequired: 1800 },
  { level: 6, name: 'Legende',     xpRequired: 3500 },
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
  const [configSnap, levelsSnap, pronoSnap] = await Promise.all([
    db.collection('app_settings').doc('xp_config').get(),
    db.collection('app_settings').doc('xp_levels').get(),
    db.collection('app_config').doc('prono_social').get(),
  ]);
  const events = configSnap.exists ? (configSnap.data().events ?? {}) : {};
  let levels = levelsSnap.exists ? (levelsSnap.data().levels ?? null) : null;
  if (!Array.isArray(levels) || levels.length === 0) {
    const legacy = pronoSnap.exists ? (pronoSnap.data().levels ?? null) : null;
    levels = Array.isArray(legacy) && legacy.length > 0 ? legacy : DEFAULT_LEVELS;
  }
  return { events, levels };
}

function _dailyCap(eventType) {
  const caps = { article_read: 5, chat_message: 20, daily_login: 1 };
  return caps[eventType] ?? 10;
}

/** Attribution XP unifiée (app, pronos, duels, parrainage). */
async function _awardXpToUser(db, uid, eventType, meta = {}) {
  const { events, levels } = await _getXpConfig(db);
  const ev = _eventXpFromConfig(events, eventType);
  const xpValue = ev.xp;
  if (!ev.enabled || xpValue === 0) {
    return { success: true, xpAwarded: 0, disabled: !ev.enabled };
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) return { success: false, xpAwarded: 0 };

  const userData = userSnap.data();
  const DAILY_CAPPED = ['article_read', 'chat_message', 'daily_login'];
  if (DAILY_CAPPED.includes(eventType)) {
    const today = new Date().toISOString().split('T')[0];
    const logRef = userRef.collection('xp_daily').doc(`${eventType}_${today}`);
    const logSnap = await logRef.get();
    if (logSnap.exists && (logSnap.data().count ?? 0) >= _dailyCap(eventType)) {
      return { success: true, xpAwarded: 0, capped: true };
    }
    await logRef.set({ count: FieldValue.increment(1), date: today }, { merge: true });
  }

  const newXp = (userData.xp ?? 0) + xpValue;
  const newLevel = _computeLevel(newXp, levels);
  const oldLevel = userData.level ?? 1;

  await userRef.update({
    xp: newXp,
    level: newLevel,
    updatedAt: Timestamp.now(),
    [`stats.${eventType}`]: FieldValue.increment(1),
  });

  await userRef.collection('xp_log').add({
    eventType,
    xpAwarded: xpValue,
    totalAfter: newXp,
    timestamp: Timestamp.now(),
    ...meta,
  });

  const updatedUser = {
    ...userData,
    xp: newXp,
    stats: {
      ...(userData.stats ?? {}),
      [eventType]: ((userData.stats ?? {})[eventType] ?? 0) + 1,
    },
  };
  await _checkBadges(db, uid, updatedUser);

  return {
    success: true,
    xpAwarded: xpValue,
    newXp,
    newLevel,
    leveledUp: newLevel > oldLevel,
  };
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

  const eventType = request.data?.eventType;
  if (!eventType) throw new Error('eventType manquant');

  const db = getFirestore();
  const meta = {};
  if (request.data?.matchId) meta.matchId = String(request.data.matchId);
  return _awardXpToUser(db, request.auth.uid, eventType, meta);
});

// Legacy : remplacé par calculatePronoPoints + _awardXpToUser (collection predictions).
exports.onMatchFinished = onDocumentWritten('matches/{matchId}', async () => {});

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

  await event.data.ref.set({
    referralCode: data.referralCode || code,
    referredBy: data.referredBy ?? null,
    createdAt: data.createdAt ?? Timestamp.now(),
    emailLower: emailLower || null,
  }, { merge: true });
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


/**
 * Somme des points `prono_leaderboard` des membres → `private_leagues.rankingStats`
 * pour classement global des ligues (app client). Déclenché uniquement depuis l’admin.
 */
async function _recomputeLeaguePowerRankingsCore(db) {
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
  console.log(`adminRecomputeLeaguePowerRankings: ${processed} ligues`);
  return processed;
}

/** Callable admin (nouveau nom : impossible de réutiliser l’ancien ID `recomputeLeaguePowerRankings` après un onSchedule). */
exports.adminRecomputeLeaguePowerRankings = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const processed = await _recomputeLeaguePowerRankingsCore(db);
  return { success: true, leaguesProcessed: processed };
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

// ── HelloAsso — adhérents (admin uniquement, invisible dans l’app mobile) ────
exports.helloAssoWebhook = helloassoWebhookModule.helloAssoWebhook;
exports.expireHelloAssoAdherents = helloassoWebhookModule.expireHelloAssoAdherents;

// ── Android TV — espace Firestore dédié `tv/` (ne pas mélanger avec app_config) ─
const TV_CONFIG_DOC = 'config';

/** Annonce prochain live (écran TV hors direct) depuis tv/config. */
function _nextLiveScheduledAtMs(tv) {
  const raw = tv.nextLiveAt;
  if (raw == null) return null;
  if (typeof raw.toMillis === 'function') return raw.toMillis();
  if (typeof raw === 'number' && raw > 0) return raw;
  if (typeof raw === 'object' && raw._seconds != null) {
    return Math.floor(raw._seconds * 1000 + (raw._nanoseconds || 0) / 1e6);
  }
  return null;
}

function _buildNextLive(tv) {
  if (tv.nextLiveEnabled === false) return null;
  const team1 = _toSafeString(tv.nextLiveTeam1);
  const team2 = _toSafeString(tv.nextLiveTeam2);
  const day = _toSafeString(tv.nextLiveDay);
  const date = _toSafeString(tv.nextLiveDate);
  const time = _toSafeString(tv.nextLiveTime);
  const imageUrl = _toSafeString(tv.nextLiveImageUrl);
  const scheduledAt = _nextLiveScheduledAtMs(tv);
  const hasContent =
    (team1 && team2) || day || date || time || scheduledAt;
  if (!hasContent) return null;
  const out = {
    imageUrl,
    day,
    date,
    time,
    team1,
    team2,
    enabled: true,
    matchup: team1 && team2 ? `${team1} — ${team2}` : '',
  };
  if (scheduledAt) out.scheduledAt = scheduledAt;
  return out;
}

/** Exclure contenus partenaires du catalogue Android TV. */
function _isPartnerVideo(v) {
  const cat = (v.category ?? '').toString().toLowerCase();
  if (cat === 'partenaire') return true;
  const title = (v.title ?? '').toString().toLowerCase();
  return title.includes('partenaire');
}

/** Lit tv/config ; repli sur app_config/tv (ancien emplacement) si besoin. */
async function _loadTvConfig(db) {
  const tvSnap = await db.collection('tv').doc(TV_CONFIG_DOC).get();
  if (tvSnap.exists) {
    return { data: tvSnap.data() || {}, source: 'tv/config' };
  }
  const legacySnap = await db.collection('app_config').doc('tv').get();
  if (legacySnap.exists) {
    return { data: legacySnap.data() || {}, source: 'app_config/tv' };
  }
  return { data: {}, source: null };
}

/** Spectateurs actifs sur le direct (TTL 90 s, heartbeat app TV / mobile). */
/** Doit dépasser l’intervalle heartbeat TV (5 min) + marge. */
const LIVE_PRESENCE_TTL_MS = 360_000;

function _parisHourKey(date = new Date()) {
  return date
    .toLocaleString('sv-SE', { timeZone: 'Europe/Paris', hour12: false })
    .slice(0, 13)
    .replace(' ', 'T');
}

async function _clearAllLivePresence(db) {
  const snap = await db.collection('live_presence').get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function _recordLiveViewerMetrics(db, viewerCount, viewerId, platform) {
  const liveSnap = await db.collection('live').doc('current').get();
  if (!liveSnap.exists) return;
  const sessionId = (liveSnap.data()?.statsSessionId ?? '').toString();
  if (!sessionId) return;

  const sessionRef = db.collection('live_stats_sessions').doc(sessionId);
  const hourKey = _parisHourKey();

  await db.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) return;
    const data = sessionSnap.data() || {};
    const peak = Math.max(Number(data.peakViewers ?? 0), viewerCount);
    const byHour = { ...(data.viewersByHour || {}) };
    byHour[hourKey] = Math.max(Number(byHour[hourKey] ?? 0), viewerCount);

    let samples = Array.isArray(data.samples) ? [...data.samples] : [];
    const now = Timestamp.now();
    const lastAt = data.lastSampleAt;
    const lastMs = lastAt && typeof lastAt.toMillis === 'function' ? lastAt.toMillis() : 0;
    const shouldSample = !lastMs || now.toMillis() - lastMs >= 60_000;
    if (shouldSample) {
      samples.push({ at: now, viewers: viewerCount });
      if (samples.length > 180) samples = samples.slice(-180);
    }

    tx.update(sessionRef, {
      peakViewers: peak,
      viewersByHour: byHour,
      samples,
      lastSampleAt: shouldSample ? now : (data.lastSampleAt || now),
      lastViewerCount: viewerCount,
    });
  });

  if (viewerId) {
    await sessionRef
      .collection('unique_viewers')
      .doc(viewerId)
      .set(
        {
          platform: (platform || 'other').toString().slice(0, 32),
          lastSeen: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }
}

async function _finalizeLiveStatsSession(db, sessionId, liveData) {
  const sessionRef = db.collection('live_stats_sessions').doc(sessionId);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) return;

  const uniqueSnap = await sessionRef.collection('unique_viewers').get();
  const platformTotals = { tv: 0, mobile: 0, other: 0 };
  uniqueSnap.forEach((d) => {
    const p = (d.data().platform || 'other').toString();
    if (p === 'tv') platformTotals.tv += 1;
    else if (p === 'mobile') platformTotals.mobile += 1;
    else platformTotals.other += 1;
  });

  const data = sessionSnap.data() || {};
  const samples = Array.isArray(data.samples) ? data.samples : [];
  let averageViewers = 0;
  if (samples.length) {
    const sum = samples.reduce((acc, s) => acc + (Number(s.viewers) || 0), 0);
    averageViewers = Math.round(sum / samples.length);
  }

  const startedAt = data.startedAt;
  const endedAt = Timestamp.now();
  let durationMinutes = 0;
  if (startedAt && typeof startedAt.toMillis === 'function') {
    durationMinutes = Math.max(
      0,
      Math.round((endedAt.toMillis() - startedAt.toMillis()) / 60_000),
    );
  }

  const team1 = (liveData?.team1 ?? data.team1 ?? '').toString();
  const team2 = (liveData?.team2 ?? data.team2 ?? '').toString();
  const title =
    [team1, team2].filter(Boolean).join(' — ') ||
    (data.title ?? '').toString() ||
    `Direct ${APP_BRAND_NAME}`;

  await sessionRef.set(
    {
      status: 'ended',
      endedAt,
      durationMinutes,
      uniqueViewerCount: uniqueSnap.size,
      platformTotals,
      averageViewers,
      peakViewers: Math.max(Number(data.peakViewers ?? 0), Number(liveData?.viewers ?? 0)),
      team1,
      team2,
      title,
      matchId: (liveData?.matchId ?? data.matchId ?? '').toString(),
      recapReady: true,
    },
    { merge: true },
  );

  await _clearAllLivePresence(db);
}

async function _countActiveLivePresence(db) {
  const snap = await db.collection('live_presence').get();
  const now = Date.now();
  let count = 0;
  snap.forEach((doc) => {
    const lastSeen = doc.data().lastSeen;
    const ms = lastSeen && typeof lastSeen.toMillis === 'function' ? lastSeen.toMillis() : 0;
    if (ms > 0 && now - ms < LIVE_PRESENCE_TTL_MS) count += 1;
  });
  return count;
}

function _tvCorsPreflight(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

/** Heartbeat / départ spectateur (app TV sans auth Firebase). */
exports.tvLiveHeartbeat = onRequest({ cors: true, region: 'europe-west1' }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    _tvCorsPreflight(res);
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  _tvCorsPreflight(res);
  const db = getFirestore();

  try {
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const viewerId = (body.viewerId || req.query.viewerId || '').toString().trim();
    if (!viewerId || viewerId.length > 128) {
      res.status(400).json({ error: 'viewerId requis' });
      return;
    }

    const platform = (body.platform || 'tv').toString().slice(0, 32);
    const ref = db.collection('live_presence').doc(viewerId);

    if (body.action === 'leave') {
      await ref.delete().catch(() => {});
    } else {
      await ref.set(
        {
          lastSeen: FieldValue.serverTimestamp(),
          platform,
        },
        { merge: true },
      );
    }

    const liveSnap = await db.collection('live').doc('current').get();
    const viewers = liveSnap.exists ? await _countActiveLivePresence(db) : 0;

    if (liveSnap.exists) {
      await db.collection('live').doc('current').set(
        { viewers, viewersUpdatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      if (body.action !== 'leave') {
        await _recordLiveViewerMetrics(db, viewers, viewerId, platform);
      }
    }

    res.json({ viewers, isLive: liveSnap.exists });
  } catch (e) {
    console.error('[tvLiveHeartbeat]', e);
    res.status(500).json({ error: e.message || 'tvLiveHeartbeat error' });
  }
});

exports.tvApi = onRequest({ cors: true, region: 'europe-west1' }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');
  const db = getFirestore();

  try {
    const scope = (req.query.scope || '').toString().trim().toLowerCase();
    const sinceRaw = (req.query.since || '').toString().trim();
    const sinceMs = Number(sinceRaw);
    const loadCatalog = scope !== 'status';

    const [tvLoaded, liveSnap] = await Promise.all([
      _loadTvConfig(db),
      db.collection('live').doc('current').get(),
    ]);

    const tv = tvLoaded.data;
    const live = liveSnap.exists ? liveSnap.data() : null;
    const team1 = (live?.team1 ?? '').toString().trim();
    const team2 = (live?.team2 ?? '').toString().trim();
    const nextLive = _buildNextLive(tv);
    const liveTitle =
      team1 && team2
        ? `${team1} — ${team2}`
        : (nextLive?.matchup || '').trim() || (live?.url ?? 'En direct');

    let catalogMode = 'skipped';
    let videos = [];
    let featuredVideo = null;

    if (loadCatalog) {
      let videosSnap;
      if (sinceMs > 0 && Number.isFinite(sinceMs)) {
        catalogMode = 'incremental';
        videosSnap = await db
          .collection('videos')
          .where('created_at', '>', Timestamp.fromMillis(sinceMs))
          .orderBy('created_at', 'desc')
          .limit(50)
          .get();
      } else {
        catalogMode = 'full';
        videosSnap = await db
          .collection('videos')
          .orderBy('created_at', 'desc')
          .limit(150)
          .get();
      }

      videos = videosSnap.docs
        .map((doc) => {
          const v = doc.data();
          return {
            id: doc.id,
            youtubeId: v.youtubeId ?? '',
            title: v.title ?? '',
            thumbnailUrl: v.thumbnailUrl ?? '',
            category: v.category ?? '',
            duration: v.duration ?? '',
            featured: v.featured === true,
          };
        })
        .filter((v) => !_isPartnerVideo(v));

      const featuredId = (tv.featuredVideoId ?? '').toString().trim();
      if (featuredId) {
        featuredVideo = videos.find((v) => v.id === featuredId) ?? null;
        if (!featuredVideo && catalogMode === 'full') {
          const featSnap = await db.collection('videos').doc(featuredId).get();
          if (featSnap.exists) {
            const v = featSnap.data() || {};
            const candidate = {
              id: featSnap.id,
              youtubeId: v.youtubeId ?? '',
              title: v.title ?? '',
              thumbnailUrl: v.thumbnailUrl ?? '',
              category: v.category ?? '',
              duration: v.duration ?? '',
              featured: true,
            };
            if (!_isPartnerVideo(candidate)) {
              featuredVideo = candidate;
            }
          }
        }
      }
      if (!featuredVideo && catalogMode === 'full') {
        featuredVideo = videos.find((v) => v.featured) ?? null;
      }
      if (featuredVideo && _isPartnerVideo(featuredVideo)) {
        featuredVideo = null;
      }
    }

    const catalogSyncedAt = Date.now();

    const streamPlaybackUrl = (tv.streamPlaybackUrl ?? '').toString().trim();
    const tvEnabled = tv.enabled !== false;
    const liveViewers = liveSnap.exists
      ? await _countActiveLivePresence(db)
      : 0;

    if (liveSnap.exists) {
      await db.collection('live').doc('current').set(
        { viewers: liveViewers, viewersUpdatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
      await _recordLiveViewerMetrics(db, liveViewers, null, null);
    }

    res.json({
      // Champs plats (app Android TV)
      streamPlaybackUrl,
      tvEnabled,
      isLive: liveSnap.exists,
      liveTitle,
      liveViewers,
      videos,
      featuredVideo,
      nextLive,
      catalogMode,
      catalogSyncedAt,
      updatedAt: new Date().toISOString(),
      // Contrat structuré — séparation TV / live partagé / catalogue vidéos
      tv: {
        streamPlaybackUrl,
        enabled: tvEnabled,
        configSource: tvLoaded.source,
      },
      live: {
        isLive: liveSnap.exists,
        title: liveTitle,
        matchId: (live?.matchId ?? '').toString(),
        viewers: liveViewers,
      },
      catalog: {
        source: 'videos',
        mode: catalogMode,
        count: videos.length,
        totalFetched: videos.length,
        byCategory: {
          resume: videos.filter((v) => v.category === 'resume').length,
          matchday: videos.filter((v) => v.category === 'matchday').length,
          podcast: videos.filter((v) => v.category === 'podcast').length,
          other: videos.filter(
            (v) => !['resume', 'matchday', 'podcast', 'partenaire'].includes(v.category),
          ).length,
        },
      },
    });
  } catch (e) {
    console.error('[tvApi]', e);
    res.status(500).json({ error: e.message || 'tvApi error' });
  }
});

/** Admin : enregistrer l'URL HLS de lecture TV (MediaMTX / VPS). */
exports.setTvStreamConfig = onCall({ cors: true, region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const streamPlaybackUrl = (request.data?.streamPlaybackUrl ?? '').toString().trim();
  const enabled = request.data?.enabled !== false;
  const note = (request.data?.note ?? '').toString().trim();

  if (!streamPlaybackUrl) {
    throw new HttpsError('invalid-argument', 'streamPlaybackUrl requis');
  }

  const payload = {
    streamPlaybackUrl,
    enabled,
    note,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  };

  await db.collection('tv').doc(TV_CONFIG_DOC).set(payload, { merge: true });

  return { ok: true, streamPlaybackUrl, enabled, path: 'tv/config' };
});

// ── Stats match : preview 5 min + clôture + migration ────────────────────────

function _canWriteMatchStats(userDoc, auth) {
  if (auth?.token?.dvcr_admin === true) return true;
  if (_isUserAdmin(userDoc)) return true;
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  const roles = Array.isArray(data.roles)
    ? data.roles
    : (data.role ? [data.role] : []);
  return roles.includes('statisticien') || roles.includes('community_manager');
}

function _statsMapNonEmpty(stats) {
  return stats && typeof stats === 'object' && Object.keys(stats).length > 0;
}

/** Fusionne deux listes d’événements (live + fiche match) sans doublons. */
function _mergeGameEvents(a, b) {
  const listA = Array.isArray(a) ? a : [];
  const listB = Array.isArray(b) ? b : [];
  if (listA.length === 0) return listB;
  if (listB.length === 0) return listA;
  const seen = new Set();
  const out = [];
  for (const e of [...listA, ...listB]) {
    if (!e || typeof e !== 'object') continue;
    const type = String(e.type || '').toLowerCase();
    const key = type === 'substitution'
      ? `${type}|${e.minute}|${e.playerOut}|${e.playerIn}|${e.team}`.toLowerCase()
      : `${type}|${e.minute}|${e.player}|${e.team}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(e);
  }
  out.sort((x, y) => (Number(x.minute) || 0) - (Number(y.minute) || 0));
  return out;
}

async function _applyMatchStatsPreview(db, sheetId, sheet) {
  const matchId = sheet.matchId || sheetId;
  const stats = sheet.stats || {};
  const sheetEvents = Array.isArray(sheet.events) ? sheet.events : [];
  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) return false;

  const matchData = matchSnap.data() || {};
  const matchEvents = Array.isArray(matchData.events) ? matchData.events : [];
  const legacyLive = Array.isArray(matchData.liveEvents) ? matchData.liveEvents : [];
  const events = _mergeGameEvents(
    _mergeGameEvents(matchEvents, legacyLive),
    sheetEvents,
  );

  await matchRef.set({
    stats,
    events,
    statsState: 'preview',
    showStats: _statsMapNonEmpty(stats) || events.length > 0,
    statsPreviewAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const matchDate = matchSnap.data()?.date?.toMillis?.() ?? 0;
  const now = Date.now();
  const isToday = matchDate > 0 && Math.abs(matchDate - now) < 48 * 3600000;
  if (isToday && sheet.previewEnabled === true) {
    await _syncLiveHubStatsPreview(db, matchId, stats, events);
  }
  return true;
}

async function _syncLiveHubStatsPreview(db, matchId, stats, events) {
  const liveRef = db.collection('live').doc('current');
  const liveSnap = await liveRef.get();
  if (!liveSnap.exists) return;
  const live = liveSnap.data() || {};
  const liveMid = (live.matchId ?? '').toString().trim();
  const previewMid = (live.statsPreviewMatchId ?? '').toString().trim();
  if (liveMid !== matchId && previewMid !== matchId) return;

  const matchSnap = await db.collection('matches').doc(matchId).get();
  const matchData = matchSnap.exists ? matchSnap.data() : {};

  const patch = {
    statsEnabled: true,
    statsPreviewMatchId: matchId,
    statsPreviewUpdatedAt: FieldValue.serverTimestamp(),
  };
  if (_statsMapNonEmpty(stats)) {
    patch.statsPreview = stats;
    patch.stats = stats;
  }
  // Ne pas écraser score/cartons/events du live en cours — ces champs sont gérés
  // exclusivement par le direct (notifyGoal se déclencherait et enverrait de faux buts).
  await liveRef.set(patch, { merge: true });
}

async function _clearLiveHubStatsPreview(db, matchId) {
  const liveRef = db.collection('live').doc('current');
  const liveSnap = await liveRef.get();
  if (!liveSnap.exists) return;
  const live = liveSnap.data() || {};
  const liveMid = (live.matchId ?? '').toString().trim();
  const previewMid = (live.statsPreviewMatchId ?? '').toString().trim();
  if (liveMid !== matchId && previewMid !== matchId) return;

  await liveRef.set({
    statsPreview: FieldValue.delete(),
    statsPreviewMatchId: FieldValue.delete(),
    statsPreviewUpdatedAt: FieldValue.delete(),
  }, { merge: true });
}

async function _ensureMatchStatsSheetFromMatch(db, matchId) {
  const sheetRef = db.collection('match_stats').doc(matchId);
  const existing = await sheetRef.get();
  if (existing.exists) return existing.data();

  const matchSnap = await db.collection('matches').doc(matchId).get();
  if (!matchSnap.exists) return null;
  const m = matchSnap.data() || {};
  const stats = m.stats && typeof m.stats === 'object' ? m.stats : {};
  const events = Array.isArray(m.events) ? m.events : [];

  let state = 'draft';
  const statsState = (m.statsState ?? '').toString();
  if (statsState === 'published' || m.showStats === true) state = 'published';
  else if (statsState === 'preview') state = 'preview';

  const payload = {
    matchId,
    team1: m.team1 ?? '',
    team2: m.team2 ?? '',
    date: m.date ?? null,
    competition: m.competition ?? '',
    stats,
    events,
    state,
    previewEnabled: state === 'preview',
    statsVersion: 1,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await sheetRef.set(payload, { merge: true });
  return payload;
}

async function _finalizeMatchStatsInternal(db, matchId, uid) {
  const sheetRef = db.collection('match_stats').doc(matchId);
  const sheetSnap = await sheetRef.get();
  if (!sheetSnap.exists) {
    throw new HttpsError('not-found', 'Fiche stats introuvable');
  }
  const sheet = sheetSnap.data();
  const stats = sheet.stats || {};
  const sheetEvents = Array.isArray(sheet.events) ? sheet.events : [];
  const hasContent = _statsMapNonEmpty(stats) || sheetEvents.length > 0;

  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  const matchData = matchSnap.exists ? matchSnap.data() : {};
  const matchEvents = Array.isArray(matchData?.events) ? matchData.events : [];
  const legacyLive = Array.isArray(matchData?.liveEvents) ? matchData.liveEvents : [];
  const events = _mergeGameEvents(
    _mergeGameEvents(matchEvents, legacyLive),
    sheetEvents,
  );

  const patch = {
    stats,
    events,
    statsState: 'published',
    showStats: hasContent,
    statsPublishedAt: FieldValue.serverTimestamp(),
  };
  const s1 = matchData?.score1 ?? matchData?.homeScore;
  const s2 = matchData?.score2 ?? matchData?.awayScore;
  if (s1 != null && s2 != null && matchData?.status !== 'finished') {
    patch.status = 'finished';
  }
  await matchRef.set(patch, { merge: true });

  await sheetRef.set({
    state: 'published',
    previewEnabled: false,
    publishedAt: FieldValue.serverTimestamp(),
    statsVersion: (sheet.statsVersion || 0) + 1,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: uid,
  }, { merge: true });

  await _clearLiveHubStatsPreview(db, matchId);

  return { ok: true, matchId, published: hasContent };
}

async function _syncAllMatchStatsPreviews(db) {
  const snap = await db.collection('match_stats')
    .where('previewEnabled', '==', true)
    .get();
  let n = 0;
  for (const doc of snap.docs) {
    const sheet = doc.data();
    if (sheet.state === 'published') continue;
    if (await _applyMatchStatsPreview(db, doc.id, sheet)) n += 1;
  }
  return n;
}

exports.syncMatchStatsPreview = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Europe/Paris' },
  async () => {
    const db = getFirestore();
    const n = await _syncAllMatchStatsPreviews(db);
    console.log(`match_stats preview sync: ${n} fiche(s)`);
  },
);

exports.syncMatchStatsPreviewManual = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const matchId = (request.data?.matchId ?? '').toString().trim();
  if (matchId) {
    const sheet = await db.collection('match_stats').doc(matchId).get();
    if (!sheet.exists) {
      throw new HttpsError('not-found', 'Fiche stats introuvable');
    }
    await _applyMatchStatsPreview(db, matchId, sheet.data());
    return { ok: true, count: 1 };
  }
  const n = await _syncAllMatchStatsPreviews(db);
  return { ok: true, count: n };
});

exports.finalizeMatchStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const matchId = (request.data?.matchId ?? '').toString().trim();
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }

  return _finalizeMatchStatsInternal(db, matchId, request.auth.uid);
});

exports.setMatchStatsPublicationState = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const matchId = (request.data?.matchId ?? '').toString().trim();
  const state = (request.data?.state ?? '').toString().trim();
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }
  if (!['draft', 'preview', 'published', 'none'].includes(state)) {
    throw new HttpsError('invalid-argument', 'state invalide');
  }

  if (state === 'published') {
    await _ensureMatchStatsSheetFromMatch(db, matchId);
    return _finalizeMatchStatsInternal(db, matchId, request.auth.uid);
  }

  await _ensureMatchStatsSheetFromMatch(db, matchId);
  const sheetRef = db.collection('match_stats').doc(matchId);
  const sheetSnap = await sheetRef.get();
  const sheet = sheetSnap.exists ? sheetSnap.data() : {};
  const matchSnap = await db.collection('matches').doc(matchId).get();
  const matchData = matchSnap.exists ? matchSnap.data() : {};

  const stats = sheet.stats && typeof sheet.stats === 'object'
    ? sheet.stats
    : (matchData?.stats && typeof matchData.stats === 'object' ? matchData.stats : {});
  const events = Array.isArray(sheet.events)
    ? sheet.events
    : (Array.isArray(matchData?.events) ? matchData.events : []);
  const hasContent = _statsMapNonEmpty(stats) || events.length > 0;

  if (state === 'preview') {
    const previewState = hasContent ? 'preview' : 'draft';
    await sheetRef.set({
      stats,
      events,
      state: previewState,
      previewEnabled: hasContent,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    }, { merge: true });

    await db.collection('matches').doc(matchId).set({
      stats,
      events,
      statsState: previewState,
      showStats: hasContent,
      statsPreviewAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (hasContent) {
      await _syncLiveHubStatsPreview(db, matchId, stats, events);
    } else {
      await _clearLiveHubStatsPreview(db, matchId);
    }

    return { ok: true, matchId, state: previewState };
  }

  // draft / none → à saisir
  await sheetRef.set({
    stats,
    events,
    state: 'draft',
    previewEnabled: false,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  }, { merge: true });

  await db.collection('matches').doc(matchId).set({
    stats,
    events,
    statsState: 'draft',
    showStats: false,
  }, { merge: true });

  await _clearLiveHubStatsPreview(db, matchId);

  return { ok: true, matchId, state: 'draft' };
});

exports.reopenMatchStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canWriteMatchStats(userDoc, request.auth)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  const matchId = (request.data?.matchId ?? '').toString().trim();
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId requis');
  }

  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) {
    throw new HttpsError('not-found', 'Match introuvable');
  }
  const matchData = matchSnap.data();

  const sheetRef = db.collection('match_stats').doc(matchId);
  const sheetSnap = await sheetRef.get();
  const sheetState = sheetSnap.exists ? sheetSnap.data()?.state : null;
  const matchStatsState = matchData?.statsState?.toString();

  if (sheetState !== 'published' && matchStatsState !== 'published') {
    throw new HttpsError(
      'failed-precondition',
      'Ce match n\'est pas clôturé',
    );
  }

  const stats = sheetSnap.exists
    ? (sheetSnap.data()?.stats || matchData.stats || {})
    : (matchData.stats || {});
  const events = sheetSnap.exists
    ? (Array.isArray(sheetSnap.data()?.events)
      ? sheetSnap.data().events
      : (Array.isArray(matchData.events) ? matchData.events : []))
    : (Array.isArray(matchData.events) ? matchData.events : []);
  const hasContent = _statsMapNonEmpty(stats) || events.length > 0;

  await sheetRef.set({
    matchId,
    team1: matchData.team1 ?? '',
    team2: matchData.team2 ?? '',
    date: matchData.date ?? null,
    competition: matchData.competition ?? '',
    stats,
    events,
    state: hasContent ? 'preview' : 'draft',
    previewEnabled: hasContent,
    reopenedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  }, { merge: true });

  await matchRef.set({
    stats,
    events,
    statsState: hasContent ? 'preview' : 'draft',
    showStats: hasContent,
    statsPreviewAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const sheetForPreview = {
    matchId,
    stats,
    events,
    previewEnabled: hasContent,
    state: hasContent ? 'preview' : 'draft',
  };
  await _applyMatchStatsPreview(db, matchId, sheetForPreview);

  return { ok: true, matchId, reopened: true };
});

exports.migrateMatchStatsFromMatches = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const snap = await db.collection('matches').limit(800).get();
  let migrated = 0;
  const batchSize = 400;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const stats = d.stats;
    if (!_statsMapNonEmpty(stats)) continue;

    const events = Array.isArray(d.events) ? d.events : [];
    let state = 'draft';
    if (d.statsState === 'published' || d.showStats === true) state = 'published';
    else if (d.statsState === 'preview') state = 'preview';

    const ref = db.collection('match_stats').doc(doc.id);
    batch.set(ref, {
      matchId: doc.id,
      team1: d.team1 ?? '',
      team2: d.team2 ?? '',
      date: d.date ?? null,
      competition: d.competition ?? '',
      stats,
      events,
      state,
      previewEnabled: state === 'preview',
      statsVersion: 1,
      migratedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (!d.statsState) {
      batch.set(doc.ref, {
        statsState: state === 'published' ? 'published' : 'none',
      }, { merge: true });
    }

    migrated += 1;
    ops += 1;
    if (ops >= batchSize) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  return { ok: true, migrated };
});


// ─────────────────────────────────────────────────────────────────────────────
// ESTI'DVCR — Calcul automatique des points de pronos tournoi
// ─────────────────────────────────────────────────────────────────────────────

/** Détermine la clé de sous-collection pour le classement d'un match.
 *  - matchDay défini → String(matchDay) ex: "1", "2"
 *  - phase finale (pas de matchDay, champ phase contient final/demi/quart) → "finale"
 *  - sinon → null (pas de classement par journée)
 */
function _getMatchDayKey(matchData) {
  if (matchData.matchDay != null) return String(matchData.matchDay);
  if (matchData.isFinale === true) return 'finale';
  const phase = (matchData.phase || '').toLowerCase();
  if (phase.includes('final') || phase.includes('finale') ||
      phase.includes('demi') || phase.includes('quart') ||
      phase.includes('8e') || phase.includes('16e') || phase.includes('32e') ||
      phase.includes('huitieme') || phase.includes('knockout') ||
      phase.includes('vainqueur') || phase.includes('perdant')) {
    return 'finale';
  }
  return null;
}

/**
 * Trigger Firestore : calcule les points quand un match passe en status=finished.
 * Met à jour le classement général + classement par journée / phase finale.
 */
exports.recalculateTournamentMatchScoring = onDocumentWritten(
  'tournaments/{tournamentId}/matches/{matchId}',
  async (event) => {
    const after  = event.data.after;
    const before = event.data.before;
    if (!after.exists) return null;

    const matchData = after.data();
    const result1 = matchData.result1;
    const result2 = matchData.result2;
    if (result1 == null || result2 == null) return null;
    if (matchData.status !== 'finished') return null;

    const wasFinished = before.exists && before.data().status === 'finished';
    const beforeMatchDay = before.exists ? before.data().matchDay : undefined;
    const matchDayChanged = matchData.matchDay !== beforeMatchDay;

    // Ne rien faire si le match était déjà fini ET matchDay n'a pas changé
    if (wasFinished && !matchDayChanged) return null;

    const { tournamentId, matchId } = event.params;
    const db = getFirestore();
    const tournamentRef = db.collection('tournaments').doc(tournamentId);

    // Si matchDay a changé sur un match déjà fini → recalcul complet depuis zéro
    if (wasFinished && matchDayChanged) {
      await _fullTournamentRecalc(db, tournamentRef);
      return null;
    }

    // Sinon : match vient juste d'être scoré → mise à jour incrémentale
    const dayKey = _getMatchDayKey(matchData);

    const predsSnap = await tournamentRef.collection('predictions')
      .where('matchId', '==', matchId)
      .get();
    if (predsSnap.empty) return null;

    const leaderboardUpdates = {};
    const predsBatch = db.batch();

    for (const predDoc of predsSnap.docs) {
      const pred = predDoc.data();
      const uid = pred.uid;
      if (!uid) continue;

      let points = 0;
      if (pred.score1 === result1 && pred.score2 === result2) {
        points = 3;
      } else {
        const pw = pred.score1 > pred.score2 ? 1 : pred.score1 < pred.score2 ? -1 : 0;
        const rw = result1 > result2 ? 1 : result1 < result2 ? -1 : 0;
        if (pw === rw) points = 1;
      }
      predsBatch.update(predDoc.ref, { points });

      if (!leaderboardUpdates[uid]) {
        leaderboardUpdates[uid] = { uid, displayName: pred.displayName || 'Membre', points: 0, exactScores: 0 };
      }
      leaderboardUpdates[uid].points += points;
      if (points === 3) leaderboardUpdates[uid].exactScores += 1;
    }
    await predsBatch.commit();

    const lbBatch = db.batch();
    for (const [uid, data] of Object.entries(leaderboardUpdates)) {
      lbBatch.set(
        tournamentRef.collection('leaderboard').doc(uid),
        { uid: data.uid, displayName: data.displayName, points: FieldValue.increment(data.points), exactScores: FieldValue.increment(data.exactScores), updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      if (dayKey) {
        lbBatch.set(
          tournamentRef.collection('leaderboard_matchday').doc(dayKey).collection('entries').doc(uid),
          { uid: data.uid, displayName: data.displayName, points: FieldValue.increment(data.points), exactScores: FieldValue.increment(data.exactScores), updatedAt: FieldValue.serverTimestamp() },
          { merge: true }
        );
      }
    }
    await lbBatch.commit();
    await _recalculateTournamentRanks(tournamentRef);
    return null;
  }
);

/**
 * Recalcule tous les points depuis zéro pour un tournoi.
 * Callable — param : { tournamentId: string }
 */
exports.recalculateWorldCupLeaderboard = onCall({ region: "europe-west1" }, async (request) => {
  const db = getFirestore();
  const tournamentId = (request.data && request.data.tournamentId) || 'worldcup2026';
  const tournamentRef = db.collection('tournaments').doc(tournamentId);
  await _fullTournamentRecalc(db, tournamentRef);
  return { ok: true };
});

/**
 * Annule le scoring d'un match.
 * Callable — params : { tournamentId: string, matchId: string }
 */
exports.undoWorldCupMatchScoring = onCall({ region: "europe-west1" }, async (request) => {
  const db = getFirestore();
  const data = request.data || {};
  const tournamentId = data.tournamentId || 'worldcup2026';
  const matchId = data.matchId;
  if (!matchId) throw new HttpsError('invalid-argument', 'matchId requis');

  const tournamentRef = db.collection('tournaments').doc(tournamentId);
  const matchRef = tournamentRef.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) throw new HttpsError('not-found', 'Match introuvable');

  const predsSnap = await tournamentRef.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  const leaderboardDeltas = {};
  const predsBatch = db.batch();
  for (const predDoc of predsSnap.docs) {
    const pred = predDoc.data();
    const uid = pred.uid;
    const pts = pred.points || 0;
    if (!uid || pts === 0) continue;
    if (!leaderboardDeltas[uid]) leaderboardDeltas[uid] = { pts: 0, exact: 0 };
    leaderboardDeltas[uid].pts += pts;
    if (pts === 3) leaderboardDeltas[uid].exact += 1;
    predsBatch.update(predDoc.ref, { points: 0 });
  }
  await predsBatch.commit();

  const lbBatch = db.batch();
  for (const [uid, delta] of Object.entries(leaderboardDeltas)) {
    lbBatch.update(tournamentRef.collection('leaderboard').doc(uid), {
      points: FieldValue.increment(-delta.pts),
      exactScores: FieldValue.increment(-delta.exact),
    });
  }
  await lbBatch.commit();

  await matchRef.update({ status: 'upcoming', result1: null, result2: null });
  await _recalculateTournamentRanks(tournamentRef);

  return { ok: true, predictionsCleared: predsSnap.size, leaderboardsAdjusted: Object.keys(leaderboardDeltas).length };
});

/** Recalcule tous les points depuis zéro pour un tournoi (utilisé par trigger et callable). */
async function _fullTournamentRecalc(db, tournamentRef) {
  const matchesSnap = await tournamentRef.collection('matches')
    .where('status', '==', 'finished')
    .get();

  const allUpdates = {};

  for (const matchDoc of matchesSnap.docs) {
    const m = matchDoc.data();
    if (m.result1 == null || m.result2 == null) continue;
    const dayKey = _getMatchDayKey(m);

    const predsSnap = await tournamentRef.collection('predictions')
      .where('matchId', '==', matchDoc.id)
      .get();

    const predsBatch = db.batch();
    for (const predDoc of predsSnap.docs) {
      const pred = predDoc.data();
      const uid = pred.uid;
      if (!uid) continue;

      let points = 0;
      if (pred.score1 === m.result1 && pred.score2 === m.result2) {
        points = 3;
      } else {
        const pw = pred.score1 > pred.score2 ? 1 : pred.score1 < pred.score2 ? -1 : 0;
        const rw = m.result1 > m.result2 ? 1 : m.result1 < m.result2 ? -1 : 0;
        if (pw === rw) points = 1;
      }
      predsBatch.update(predDoc.ref, { points });

      if (!allUpdates[uid]) {
        allUpdates[uid] = { displayName: pred.displayName || 'Membre', points: 0, exactScores: 0, dayPoints: {} };
      }
      allUpdates[uid].points += points;
      if (points === 3) allUpdates[uid].exactScores += 1;
      if (dayKey) {
        if (!allUpdates[uid].dayPoints[dayKey]) allUpdates[uid].dayPoints[dayKey] = { points: 0, exactScores: 0 };
        allUpdates[uid].dayPoints[dayKey].points += points;
        if (points === 3) allUpdates[uid].dayPoints[dayKey].exactScores += 1;
      }
    }
    if (!predsBatch._ops || predsBatch._ops.length > 0) await predsBatch.commit();
  }

  // Reset général
  const lbSnap = await tournamentRef.collection('leaderboard').get();
  const resetBatch = db.batch();
  for (const doc of lbSnap.docs) resetBatch.update(doc.ref, { points: 0, exactScores: 0 });
  if (lbSnap.docs.length > 0) await resetBatch.commit();

  // Écriture des nouvelles valeurs
  const finalBatch = db.batch();
  for (const [uid, data] of Object.entries(allUpdates)) {
    finalBatch.set(
      tournamentRef.collection('leaderboard').doc(uid),
      { uid, displayName: data.displayName, points: data.points, exactScores: data.exactScores, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    for (const [dayKey, dayData] of Object.entries(data.dayPoints)) {
      finalBatch.set(
        tournamentRef.collection('leaderboard_matchday').doc(dayKey).collection('entries').doc(uid),
        { uid, displayName: data.displayName, points: dayData.points, exactScores: dayData.exactScores, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
    }
  }
  await finalBatch.commit();
  await _recalculateTournamentRanks(tournamentRef);
}

/** Recalcule le champ rank sur chaque entrée du classement général. */
async function _recalculateTournamentRanks(tournamentRef) {
  const snap = await tournamentRef.collection('leaderboard').orderBy('points', 'desc').get();
  const db = getFirestore();
  const batch = db.batch();
  snap.docs.forEach((doc, i) => batch.update(doc.ref, { rank: i + 1 }));
  await batch.commit();
}

/**
 * One-shot : assigne matchDay (1/2/3) ou isFinale sur tous les matchs
 * dans l'ordre chronologique, per équipe.
 * Callable admin — params optionnel : { tournamentId }
 */
exports.fixEstiDvcrMatchDays = onCall({ region: "europe-west1" }, async (request) => {
  const db = getFirestore();
  const tournamentId = (request.data && request.data.tournamentId) || 'worldcup2026';
  const matchesRef = db.collection('tournaments').doc(tournamentId).collection('matches');

  const snap = await matchesRef.orderBy('date').get();
  const teamCounts = {};
  const batch = db.batch();
  const log = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const t1 = (d.team1 || '').toLowerCase().trim();
    const t2 = (d.team2 || '').toLowerCase().trim();
    if (!t1 || !t2) continue;

    const c1 = teamCounts[t1] || 0;
    const c2 = teamCounts[t2] || 0;
    const day = Math.max(c1, c2) + 1;

    teamCounts[t1] = c1 + 1;
    teamCounts[t2] = c2 + 1;

    if (day <= 3) {
      batch.update(doc.ref, { matchDay: day, isFinale: FieldValue.delete() });
      log.push(`${d.team1} vs ${d.team2} → J${day}`);
    } else {
      batch.update(doc.ref, { matchDay: FieldValue.delete(), isFinale: true });
      log.push(`${d.team1} vs ${d.team2} → Phase finale`);
    }
  }

  await batch.commit();
  return { ok: true, fixed: log.length, details: log };
});
