const { Timestamp, FieldValue } = require('firebase-admin/firestore');

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
    if (earned.has(doc.id)) continue;

    const badge     = doc.data();
    const condition = (badge.condition ?? '').trim();
    if (!condition) continue;

    let unlocked = false;

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

  batch.set(db.collection('admin_logs').doc(), {
    action: `${newBadges} badge(s) attribué(s) automatiquement`,
    type: 'badge',
    adminName: 'Système',
    target: uid,
    timestamp: Timestamp.now(),
  });

  await batch.commit();
}

module.exports = {
  DEFAULT_XP,
  _parseEventEntry,
  _eventXpFromConfig,
  DEFAULT_LEVELS,
  _computeLevel,
  _getXpConfig,
  _dailyCap,
  _awardXpToUser,
  _checkBadges,
};
