/**
 * Canaux push DVCR — même identifiant Android (channelId) et iOS (category + thread-id).
 */
const TOPIC_TO_CHANNEL = {
  dvcr_live: 'dvcr_live',
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
  return {
    android: {
      priority: high ? 'high' : 'normal',
      notification: { sound: 'default', channelId: id },
    },
    apns: {
      headers: { 'apns-priority': high ? '10' : '5' },
      payload: {
        aps: {
          sound: 'default',
          'thread-id': id,
          category: id,
        },
      },
    },
  };
}

module.exports = {
  fcmChannelBlocks,
  channelFromTopic,
  TOPIC_TO_CHANNEL,
};
