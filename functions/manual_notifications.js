const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { _normalizeTargetUserIds } = require('./lib/admin_auth');
const {
  _sendFcmToUserWithStats,
  _sendManualBroadcast,
  _sendTeamDvcrNotificationWithStats,
  _sendAdherentNotification,
  _loadMaintenanceConfig,
  _notificationsPaused,
  _emptyPlatformStats,
  _sumPlatformStats,
  _userDisplayLabel,
  _recipientDeliveryStatus,
} = require('./lib/push_helpers');
const { fcmChannelBlocks, channelFromTopic } = require('./notification_push');

async function _statsForUser(db, userData, messageBase, logLabel, opts = {}) {
  const ios = await _sendFcmToUserWithStats(
    db,
    userData,
    messageBase,
    `${logLabel} [ios]`,
    { ...opts, platform: 'ios' },
  );
  const android = await _sendFcmToUserWithStats(
    db,
    userData,
    messageBase,
    `${logLabel} [android]`,
    { ...opts, platform: 'android' },
  );
  const platformStats = {
    ios: { sent: ios.sent, failed: ios.failed },
    android: { sent: android.sent, failed: android.failed },
  };
  const total = _sumPlatformStats(platformStats);
  return { platformStats, total, sentCount: total.sent };
}

function _friendlyQueueError(err) {
  const raw = String(err?.message || err || 'Erreur inconnue');
  const lower = raw.toLowerCase();
  if (lower.includes('resource_exhausted') || lower.includes('quota')) {
    return 'Quota FCM temporairement dépassé — réessaie dans quelques minutes.';
  }
  if (lower.includes('deadline') || lower.includes('timeout')) {
    return 'Délai dépassé pendant l’envoi — vérifie le statut ou renvoie.';
  }
  if (lower.includes('permission') || lower.includes('unauthenticated')) {
    return 'Permission FCM refusée — contacte un admin technique.';
  }
  if (raw.length > 200) return `${raw.slice(0, 200)}…`;
  return raw;
}

/**
 * Claim atomique pending → processing.
 * @returns {'ok'|'cancelled'|'skip'}
 */
async function _claimQueueItem(queueRef) {
  return getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(queueRef);
    if (!snap.exists) return 'skip';
    const status = String(snap.data()?.status || 'pending');
    if (status === 'cancelled') return 'cancelled';
    if (status !== 'pending') return 'skip';
    tx.update(queueRef, {
      status: 'processing',
      processingStartedAt: FieldValue.serverTimestamp(),
    });
    return 'ok';
  });
}

async function _isQueueCancelled(queueRef) {
  const snap = await queueRef.get();
  return String(snap.data()?.status || '') === 'cancelled';
}

async function _finalizeIfNotCancelled(queueRef, update) {
  return getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(queueRef);
    if (!snap.exists) return 'missing';
    const status = String(snap.data()?.status || '');
    if (status === 'cancelled') return 'cancelled';
    tx.update(queueRef, update);
    return 'ok';
  });
}

exports.sendManualNotification = onDocumentCreated('notifications_queue/{id}', async (event) => {
  const db   = getFirestore();
  const data = event.data?.data();
  if (!data) return;

  const queueRef = db.collection('notifications_queue').doc(event.params.id);

  const claim = await _claimQueueItem(queueRef);
  if (claim === 'cancelled') {
    console.log(`[manual] annulée avant traitement : ${event.params.id}`);
    return;
  }
  if (claim !== 'ok') {
    console.log(`[manual] skip claim (${claim}) : ${event.params.id}`);
    return;
  }

  const { title, body, topic } = data;
  if (!title || !body || !topic) {
    await queueRef.update({
      status: 'error',
      error: 'Champs manquants (titre, message ou canal).',
    });
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

  const abortOpts = {
    shouldAbort: () => _isQueueCancelled(queueRef),
  };

  try {
    let sentCount = 0;
    let mode = 'platform_all';
    let platformStats = _emptyPlatformStats();
    let total = { sent: 0, failed: 0 };
    let usersReached = 0;
    let recipientDeliveries = null;
    let aborted = false;

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
      if (await _isQueueCancelled(queueRef)) {
        console.log(`[manual] annulée (test) : ${event.params.id}`);
        return;
      }
      const userData = userSnap.data() ?? {};
      const result = await _statsForUser(
        db,
        userData,
        messageBase,
        `manual test ${testOnlyUid}`,
        { recipientUid: testOnlyUid, allowMaintenanceBypass: true },
      );
      platformStats = result.platformStats;
      total = result.total;
      sentCount = result.sentCount;
      usersReached = sentCount > 0 ? 1 : 0;
      const { status, skipReason } = _recipientDeliveryStatus(
        result.platformStats,
        userData,
        null,
      );
      recipientDeliveries = [{
        uid: testOnlyUid,
        displayName: _userDisplayLabel(userData, testOnlyUid),
        email: String(userData.email || '').trim(),
        status,
        ...(skipReason ? { skipReason } : {}),
        platformStats: result.platformStats,
      }];
    } else if (targetAudience === 'all' && targetPlatform === 'all') {
      const cfg = await _loadMaintenanceConfig(db);
      if (cfg.paused) {
        if (cfg.bypassUid) {
          mode = 'maintenance_bypass_only';
          const userSnap = await db.collection('users').doc(cfg.bypassUid).get();
          if (userSnap.exists) {
            const result = await _statsForUser(
              db,
              userSnap.data() ?? {},
              messageBase,
              `manual bypass ${cfg.bypassUid}`,
              { recipientUid: cfg.bypassUid, allowMaintenanceBypass: true },
            );
            platformStats = result.platformStats;
            total = result.total;
            sentCount = result.sentCount;
            usersReached = sentCount > 0 ? 1 : 0;
          }
        }
      } else {
        const result = await _sendManualBroadcast(
          db,
          messageBase,
          'all',
          targetAudience,
          title,
          null,
          abortOpts,
        );
        sentCount = result.sentCount;
        mode = result.mode;
        platformStats = result.platformStats || _emptyPlatformStats();
        total = result.total || _sumPlatformStats(platformStats);
        usersReached = result.usersReached || 0;
        aborted = !!result.aborted;
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
        abortOpts,
      );
      sentCount = result.sentCount;
      mode = result.mode;
      platformStats = result.platformStats || _emptyPlatformStats();
      total = result.total || _sumPlatformStats(platformStats);
      usersReached = result.usersReached || 0;
      aborted = !!result.aborted;
    } else if (targetAudience === 'team_dvcr') {
      mode = targetUserIds ? 'team_dvcr_selected' : 'team_dvcr';
      const plat = (targetPlatform === 'ios' || targetPlatform === 'android')
        ? targetPlatform
        : null;
      const result = await _sendTeamDvcrNotificationWithStats(
        db,
        messageBase,
        `manual [team_dvcr] ${title}`,
        { targetUserIds, platform: plat, ...abortOpts },
      );
      sentCount = result.sentCount;
      platformStats = result.platformStats || _emptyPlatformStats();
      total = result.total || _sumPlatformStats(platformStats);
      usersReached = result.usersReached || 0;
      recipientDeliveries = result.recipientDeliveries || [];
      aborted = !!result.aborted;
    } else if (targetAudience === 'adherent') {
      mode = targetUserIds ? 'adherent_selected' : 'adherent';
      if (targetPlatform === 'ios' || targetPlatform === 'android') {
        const result = await _sendManualBroadcast(
          db,
          messageBase,
          targetPlatform,
          targetAudience,
          title,
          targetUserIds,
          abortOpts,
        );
        sentCount = result.sentCount;
        platformStats = result.platformStats || _emptyPlatformStats();
        total = result.total || _sumPlatformStats(platformStats);
        usersReached = result.usersReached || 0;
        aborted = !!result.aborted;
      } else {
        if (await _isQueueCancelled(queueRef)) {
          aborted = true;
        } else {
          sentCount = await _sendAdherentNotification(
            db,
            messageBase,
            `manual [adherent] ${title}`,
            { targetUserIds, platform: null, ...abortOpts },
          );
          usersReached = sentCount;
          total = { sent: sentCount, failed: 0 };
        }
      }
    } else {
      const cfg = await _loadMaintenanceConfig(db);
      if (cfg.paused) {
        if (cfg.bypassUid) {
          mode = 'maintenance_bypass_only';
          const userSnap = await db.collection('users').doc(cfg.bypassUid).get();
          if (userSnap.exists) {
            const result = await _statsForUser(
              db,
              userSnap.data() ?? {},
              messageBase,
              `manual bypass ${cfg.bypassUid}`,
              { recipientUid: cfg.bypassUid, allowMaintenanceBypass: true },
            );
            platformStats = result.platformStats;
            total = result.total;
            sentCount = result.sentCount;
            usersReached = sentCount > 0 ? 1 : 0;
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
          abortOpts,
        );
        sentCount = result.sentCount;
        mode = result.mode;
        platformStats = result.platformStats || _emptyPlatformStats();
        total = result.total || _sumPlatformStats(platformStats);
        usersReached = result.usersReached || 0;
        aborted = !!result.aborted;
      }
    }

    if (aborted || await _isQueueCancelled(queueRef)) {
      await queueRef.update({
        sendMode: mode,
        targetPlatform,
        targetAudience,
        platformStats,
        deliveryTotal: total,
        recipientsCount: sentCount,
        usersReached,
        ...(targetUserIds ? { targetUserIds } : {}),
        ...(Array.isArray(recipientDeliveries) ? { recipientDeliveries } : {}),
        status: 'cancelled',
        cancelledAt: FieldValue.serverTimestamp(),
        cancelNote: sentCount > 0
          ? 'Annulé pendant l’envoi (envois partiels possibles).'
          : 'Annulé avant la fin de l’envoi.',
      });
      console.log(`[manual] annulée mid-flight (${mode}) : ${title}`);
      return;
    }

    const updateBase = {
      sendMode: mode,
      targetPlatform,
      targetAudience,
      platformStats,
      deliveryTotal: total,
      ...(targetUserIds ? { targetUserIds } : {}),
      ...(Array.isArray(recipientDeliveries) ? { recipientDeliveries } : {}),
    };

    if (sentCount === 0) {
      const paused = await _notificationsPaused(db);
      const fin = await _finalizeIfNotCancelled(queueRef, {
        ...updateBase,
        status: 'skipped',
        skipReason: paused ? 'maintenance' : 'no_recipients',
        skippedAt: FieldValue.serverTimestamp(),
        recipientsCount: 0,
        usersReached: 0,
      });
      if (fin === 'cancelled') return;
      console.log(`[manual] ignorée (${mode}) : ${title}`);
      return;
    }
    const fin = await _finalizeIfNotCancelled(queueRef, {
      ...updateBase,
      status: 'sent',
      sentAt: FieldValue.serverTimestamp(),
      recipientsCount: sentCount,
      usersReached,
    });
    if (fin === 'cancelled') return;
    console.log(
      `Notif manuelle envoyée (${mode}, ios=${platformStats.ios.sent}, `
      + `android=${platformStats.android.sent}) : ${title}`,
    );
  } catch (err) {
    if (await _isQueueCancelled(queueRef)) {
      console.log(`[manual] erreur ignorée (déjà annulée) : ${event.params.id}`);
      return;
    }
    await queueRef.update({
      status: 'error',
      error: _friendlyQueueError(err),
      erroredAt: FieldValue.serverTimestamp(),
    });
    console.error('Erreur notif manuelle :', err);
  }
});
