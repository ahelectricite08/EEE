const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { fcmChannelBlocks } = require('./notification_push');
const { APP_BRAND_NAME, CLUB_SHORT_NAME } = require('./lib/app_brand');
const { _sendFcm } = require('./lib/push_helpers');
const {
  sendLiveActivityKitUpdates,
  clearLiveActivityTokens,
} = require('./lib/live_activity_apns');

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

/** Push ActivityKit (background-safe) + FCM silent legacy. */
async function _sendLiveActivityKitAndFcm(db, after, extra = {}, logLabel = 'live la') {
  await _sendLiveLaSyncBothTopics(db, after, extra, logLabel);
}

/** Sync Live Activity sans bannière (buts, cartons, faits de jeu). */
async function _sendLiveCardSyncFcm(db, after, extra = {}, logLabel = 'live card sync') {
  await _sendLiveActivityKitAndFcm(db, after, extra, logLabel);
}

async function _sendLiveEndFcm(db) {
  const payload = { syncLiveActivity: '1', type: 'live_end', endLive: '1' };
  const silent = { silent: true, contentAvailable: true, priority: 'normal' };
  await Promise.all([
    sendLiveActivityKitUpdates(db, {}, { event: 'end', alertTitle: 'Fin du match' })
      .catch((e) => console.warn('[live end] activitykit:', e.message)),
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
  try {
    const n = await clearLiveActivityTokens(db);
    if (n) console.log(`[live end] cleared ${n} activity tokens`);
  } catch (e) {
    console.warn('[live end] token cleanup:', e.message);
  }
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

/**
 * Sync Live Activity (carte verte / DI) + bannière FCM pour app tuée / arrière-plan.
 * Côté iOS/Flutter : la bannière est masquée si une Live Activity est déjà active.
 * Default alsoPushBanner=true — sans ça, but / mi-temps / fin ne partent plus (régression).
 */
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

  const pushBanner = opts.alsoPushBanner !== false;
  if (pushBanner) {
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

/** Sync Live Activity sur les deux topics (sans bannière) + ActivityKit push. */
async function _sendLiveLaSyncBothTopics(db, after, extra = {}, logLabel = 'live sync') {
  const alertTitle = String(extra.alertTitle || '').trim();
  const alertBody = String(extra.alertShortBody || extra.alertBody || extra.lastEventLine || '').trim();
  await Promise.all([
    sendLiveActivityKitUpdates(db, after, {
      event: 'update',
      alertTitle,
      alertBody,
      lastEventLine: extra.lastEventLine,
      lastEvent: after?.lastEvent,
    }).catch((e) => console.warn(`[${logLabel}] activitykit:`, e.message)),
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
    await _sendLiveEventNotifyFcm(db, after, {
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
    await _sendLiveEventNotifyFcm(db, after, {
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
