const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { _normalizeTargetUserIds } = require('./lib/admin_auth');
const {
  _sendFcm, _sendFcmToUser, _sendManualBroadcast, _sendTeamDvcrNotification,
  _sendAdherentNotification, _loadMaintenanceConfig, _notificationsPaused,
} = require('./lib/push_helpers');
const { fcmChannelBlocks, channelFromTopic } = require('./notification_push');

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
