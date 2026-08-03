/**
 * Envoi FCM HTTP v1 pour mises à jour ActivityKit
 * (`apns-push-type: liveactivity`).
 *
 * firebase-admin@12 ne type pas encore `live_activity_token` —
 * on passe par l’API REST avec les credentials du runtime Functions.
 */
const { GoogleAuth } = require('google-auth-library');

const BUNDLE_ID = 'fr.dvcr.app';
const TOPIC = `${BUNDLE_ID}.push-type.liveactivity`;
const TOKENS_COLLECTION = 'live_activity_tokens';

let _auth;
function _googleAuth() {
  if (!_auth) {
    _auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
  }
  return _auth;
}

function _projectId() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  if (process.env.GCP_PROJECT) return process.env.GCP_PROJECT;
  if (process.env.FIREBASE_CONFIG) {
    try {
      return JSON.parse(process.env.FIREBASE_CONFIG).projectId || '';
    } catch (_) {
      return '';
    }
  }
  return '';
}

/** Content-state aligné sur LiveActivitiesAppAttributes.ContentState (Swift). */
function buildLiveActivityContentState(after, extra = {}) {
  const lastEvent = String(extra.lastEvent || after?.lastEvent || '');
  const events = Array.isArray(after?.events) ? after.events : [];
  const last = events.length ? events[events.length - 1] : null;
  let lastEventLine = String(extra.lastEventLine || '').trim();
  if (!lastEventLine && last && last.player) {
    const min = last.minute != null ? `${last.minute}'` : '';
    lastEventLine = [min, String(last.player || '')].filter(Boolean).join(' · ');
  }

  const team1 = String(after?.team1 || '').trim() || '—';
  const team2 = String(after?.team2 || '').trim() || '—';
  const short = (t) => (t.length <= 16 ? t : `${t.slice(0, 14)}…`);

  let lastEventIsHome = true;
  if (Object.prototype.hasOwnProperty.call(extra, 'lastEventIsHome')) {
    lastEventIsHome = extra.lastEventIsHome === true
      || extra.lastEventIsHome === 1
      || extra.lastEventIsHome === '1'
      || extra.lastEventIsHome === 'true';
  } else if (last) {
    lastEventIsHome = _isHomeLiveEvent(last, team1, team2);
  }

  const minuteNum = Number(after?.minute ?? 0) || 0;
  let matchMinute = 'LIVE';
  if (lastEvent === 'fulltime' || lastEvent === 'extra_fulltime') matchMinute = 'Fin';
  else if (lastEvent === 'halftime' || lastEvent === 'extra_halftime') matchMinute = 'Mi-temps';
  else if (lastEvent === 'extra_time') matchMinute = 'Prol.';
  else if (minuteNum > 0) matchMinute = `${minuteNum}'`;
  else if (after?.chronoRunning) matchMinute = "0'";

  return {
    appGroupId: 'group.fr.dvcr.app.liveactivities',
    teamAName: short(team1),
    teamBName: short(team2),
    teamAScore: Number(after?.scoreHome ?? 0) || 0,
    teamBScore: Number(after?.scoreAway ?? 0) || 0,
    matchMinute,
    lastEventLine,
    lastEventIsHome,
    contentTick: Date.now(),
    chronoRunning: after?.chronoRunning === true,
    chronoBaseSeconds: Number(after?.chronoBaseSeconds ?? 0) || 0,
    chronoStartedAtMs: Number(after?.chronoStartedAtMs ?? 0) || 0,
    liveMinute: minuteNum,
    isHalftime: lastEvent === 'halftime',
    isExtraHalftime: lastEvent === 'extra_halftime',
    isFulltime: lastEvent === 'fulltime',
    isExtraFulltime: lastEvent === 'extra_fulltime',
    isExtraTimePlaying: lastEvent === 'extra_time',
    lastEvent,
  };
}

/** Aligné MatchStatsSchema.isHomeTeamEvent / seed_service. */
function _isHomeLiveEvent(ev, team1, team2) {
  if (!ev || typeof ev !== 'object') return true;
  if (typeof ev.isHome === 'boolean') return ev.isHome;
  const side = String(ev.side || ev.teamSide || ev.teamSlot || '')
    .trim()
    .toLowerCase();
  if (side === 'home' || side === 'left' || side === 'team1' || side === 'dom') return true;
  if (side === 'away' || side === 'right' || side === 'team2' || side === 'ext') return false;
  if (typeof ev.teamIndex === 'number') return ev.teamIndex === 0;
  const team = String(ev.team || ev.teamName || '').trim().toUpperCase();
  const t1 = String(team1 || '').trim().toUpperCase();
  const t2 = String(team2 || '').trim().toUpperCase();
  if (team) {
    if (t1 && team === t1) return true;
    if (t2 && team === t2) return false;
  }
  return true;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {object} after live/current data
 * @param {{ event?: 'update'|'end', alertTitle?: string, alertBody?: string, lastEventLine?: string, lastEvent?: string, lastEventIsHome?: boolean }} [opts]
 */
async function sendLiveActivityKitUpdates(db, after, opts = {}) {
  const projectId = _projectId();
  if (!projectId) {
    console.warn('[liveActivityKit] missing project id');
    return { sent: 0, failed: 0 };
  }

  let snap;
  try {
    snap = await db.collection(TOKENS_COLLECTION).get();
  } catch (e) {
    console.warn('[liveActivityKit] tokens read failed:', e.message);
    return { sent: 0, failed: 0 };
  }
  if (snap.empty) {
    console.log('[liveActivityKit] no registered tokens');
    return { sent: 0, failed: 0 };
  }

  const event = opts.event === 'end' ? 'end' : 'update';
  const contentState = buildLiveActivityContentState(after || {}, opts);
  const nowSec = Math.floor(Date.now() / 1000);
  const alertTitle = String(opts.alertTitle || '').trim();
  const alertBody = String(opts.alertBody || opts.lastEventLine || '').trim();

  const auth = _googleAuth();
  const client = await auth.getClient();
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  let sent = 0;
  let failed = 0;
  const staleDocs = [];

  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const activityToken = String(d.activityToken || '').trim();
    const fcmToken = String(d.fcmToken || '').trim();
    if (!activityToken || !fcmToken) {
      failed += 1;
      continue;
    }

    const aps = {
      timestamp: nowSec,
      event,
      'content-state': contentState,
      // Aide le widget à rester « frais » même si un update est manqué.
      'stale-date': nowSec + 4 * 3600,
      'relevance-score': alertTitle ? 100 : 50,
    };
    if (event === 'end') {
      aps['dismissal-date'] = nowSec;
    }
    // Alert DI uniquement pour les vrais événements (but / carton / phase).
    // Les syncs chrono (sans alertTitle) restent silencieux pour ne pas spammer l’île.
    if (alertTitle) {
      aps.alert = {
        title: alertTitle,
        body: alertBody || alertTitle,
      };
    }

    const message = {
      message: {
        token: fcmToken,
        apns: {
          live_activity_token: activityToken,
          headers: {
            'apns-push-type': 'liveactivity',
            'apns-priority': '10',
            'apns-topic': TOPIC,
            // Expiration courte pour ne pas empiler des updates obsolètes.
            'apns-expiration': String(nowSec + 3600),
          },
          payload: { aps },
        },
      },
    };

    try {
      const res = await client.request({
        url,
        method: 'POST',
        data: message,
      });
      if (res.status >= 200 && res.status < 300) {
        sent += 1;
      } else {
        failed += 1;
      }
    } catch (err) {
      failed += 1;
      const status = err?.response?.status;
      const code = err?.response?.data?.error?.details?.[0]?.errorCode
        || err?.response?.data?.error?.status
        || err?.code
        || '';
      const msg = err?.response?.data?.error?.message || err.message || '';
      console.warn(`[liveActivityKit] send fail uid=${doc.id} status=${status} ${code} ${msg}`);
      if (
        status === 404
        || String(code).includes('UNREGISTERED')
        || String(msg).toLowerCase().includes('not found')
        || String(msg).toLowerCase().includes('unregistered')
      ) {
        staleDocs.push(doc.ref);
      }
    }
  }

  if (staleDocs.length) {
    const batch = db.batch();
    for (const ref of staleDocs.slice(0, 400)) batch.delete(ref);
    try {
      await batch.commit();
      console.log(`[liveActivityKit] cleared ${Math.min(staleDocs.length, 400)} stale tokens`);
    } catch (e) {
      console.warn('[liveActivityKit] stale cleanup failed:', e.message);
    }
  }

  console.log(`[liveActivityKit] ${event} sent=${sent} failed=${failed} tokens=${snap.size}`);
  return { sent, failed };
}

async function clearLiveActivityTokens(db) {
  const snap = await db.collection(TOKENS_COLLECTION).limit(400).get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return snap.size;
}

module.exports = {
  buildLiveActivityContentState,
  sendLiveActivityKitUpdates,
  clearLiveActivityTokens,
  isHomeLiveEvent: _isHomeLiveEvent,
  TOKENS_COLLECTION,
  BUNDLE_ID,
};
