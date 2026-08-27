/**
 * Canaux push DVCR — même identifiant Android (channelId) et iOS (category + thread-id).
 */
const TOPIC_TO_CHANNEL = {
  dvcr_live: 'dvcr_live',
  dvcr_live_banners: 'dvcr_live',
  dvcr_articles: 'dvcr_articles',
  dvcr_alerts: 'dvcr_alerts',
  dvcr_live_events: 'dvcr_live_events',
  dvcr_notifications: 'dvcr_notifications',
};

function channelFromTopic(topic) {
  return TOPIC_TO_CHANNEL[String(topic || '').trim()] || 'dvcr_alerts';
}

/**
 * @param {string} channelId
 * @param {{ priority?: 'high' | 'normal' }} [opts]
 */
function fcmChannelBlocks(channelId, opts = {}) {
  const id = String(channelId || 'dvcr_alerts').trim() || 'dvcr_alerts';
  const high = opts.priority !== 'normal';
  const aps = {
    sound: opts.silent ? undefined : 'default',
    'thread-id': id,
    category: id,
  };
  if (opts.contentAvailable) {
    aps['content-available'] = 1;
  }
  const apnsHeaders = {
    'apns-priority': opts.silent ? '5' : (high ? '10' : '5'),
  };
  // apns-push-type est obligatoire sur iOS 13+ — Apple ignore ou drop le push sans lui.
  if (opts.silent) {
    apnsHeaders['apns-push-type'] = 'background';
  } else {
    // Toute notification visible (alert, son, badge) doit avoir 'alert'.
    apnsHeaders['apns-push-type'] = 'alert';
  }
  return {
    android: {
      priority: high ? 'high' : 'normal',
      notification: opts.silent ? undefined : { sound: 'default', channelId: id },
    },
    apns: {
      headers: apnsHeaders,
      payload: { aps },
    },
  };
}

module.exports = {
  fcmChannelBlocks,
  channelFromTopic,
  TOPIC_TO_CHANNEL,
};
