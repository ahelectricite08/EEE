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

/** Topic FCM silencieux Live Activity — un seul, pas `dvcr_live` + `dvcr_live_events`. */
const LIVE_SILENT_SYNC_TOPIC = 'dvcr_live';
/** Bannière heads-up match (sans Live Activity). */
const LIVE_VISIBLE_BANNER_TOPIC = 'dvcr_live_banners';
/** Tag / collapse Android : un live = une notif qui se remplace. */
const LIVE_ANDROID_TAG = 'dvcr_live';

/**
 * @param {string} channelId
 * @param {{ priority?: 'high' | 'normal', silent?: boolean, contentAvailable?: boolean, tag?: string, collapseKey?: string }} [opts]
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
  const collapseId = String(opts.collapseKey || opts.tag || '').trim();
  if (collapseId) {
    apnsHeaders['apns-collapse-id'] = collapseId.slice(0, 64);
  }
  // apns-push-type est obligatoire sur iOS 13+ — Apple ignore ou drop le push sans lui.
  if (opts.silent) {
    apnsHeaders['apns-push-type'] = 'background';
  } else {
    // Toute notification visible (alert, son, badge) doit avoir 'alert'.
    apnsHeaders['apns-push-type'] = 'alert';
  }
  const android = {
    priority: high ? 'high' : 'normal',
    collapseKey: String(opts.collapseKey || id),
  };
  // Pas de `notification: undefined` : certains SDK Android traitent la clé vide
  // comme une notif à afficher. Silent = data-only.
  if (!opts.silent) {
    android.notification = {
      sound: 'default',
      channelId: id,
      tag: String(opts.tag || id),
    };
  }
  return {
    android,
    apns: {
      headers: apnsHeaders,
      payload: { aps },
    },
  };
}

/**
 * But / coup d’envoi : heads-up Android sur `dvcr_live` (toujours abonné) +
 * APNS silencieux (Live Activity). Pas de `notification` top-level — sinon iOS
 * affiche une bannière en plus de l’île.
 *
 * @param {string} channelId
 * @param {{ title?: string, body?: string, tag?: string, collapseKey?: string }} [opts]
 */
function fcmAndroidVisibleApnsSilent(channelId, opts = {}) {
  const visible = fcmChannelBlocks(channelId, {
    tag: opts.tag,
    collapseKey: opts.collapseKey,
    priority: 'high',
  });
  const silent = fcmChannelBlocks(channelId, {
    silent: true,
    contentAvailable: true,
    priority: 'high',
    collapseKey: opts.collapseKey,
  });
  const title = String(opts.title || '').trim();
  const body = String(opts.body || '').trim();
  if (title) visible.android.notification.title = title;
  if (body) visible.android.notification.body = body;
  return {
    android: visible.android,
    apns: silent.apns,
  };
}

module.exports = {
  fcmChannelBlocks,
  fcmAndroidVisibleApnsSilent,
  channelFromTopic,
  TOPIC_TO_CHANNEL,
  LIVE_SILENT_SYNC_TOPIC,
  LIVE_VISIBLE_BANNER_TOPIC,
  LIVE_ANDROID_TAG,
};
