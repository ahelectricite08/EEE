'use strict';

const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _sendFcmToUser, _notifPref, _notificationsPaused } = require('./push_helpers');
const { fcmChannelBlocks } = require('../notification_push');

const CLAIM_STALE_MS = 15 * 60 * 1000;
const USER_READ_CHUNK = 30;
const SEND_CHUNK = 20;

function parisDateKey(dateLike) {
  let ms = null;
  if (dateLike && typeof dateLike.toMillis === 'function') {
    ms = dateLike.toMillis();
  } else if (dateLike instanceof Date) {
    ms = dateLike.getTime();
  } else if (typeof dateLike === 'number') {
    ms = dateLike;
  } else if (typeof dateLike === 'string') {
    const parsed = new Date(dateLike);
    if (!Number.isNaN(parsed.getTime())) ms = parsed.getTime();
  }
  if (!Number.isFinite(ms)) return '';
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(ms));
}

function championshipLabel(match) {
  return String(match?.competition || '').trim() || 'Championnat';
}

function matchDateMs(match) {
  const dateLike = match?.date;
  if (dateLike && typeof dateLike.toMillis === 'function') return dateLike.toMillis();
  if (dateLike instanceof Date) return dateLike.getTime();
  if (typeof dateLike === 'number' && Number.isFinite(dateLike)) return dateLike;
  return 0;
}

function journeeNumber(match) {
  const raw = match?.journee ?? match?.matchday ?? match?.fffJournee ?? match?.dayNumber;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function parisWeekday(ms) {
  if (!ms) return '';
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Europe/Paris',
    weekday: 'long',
  }).format(new Date(ms)).toLowerCase();
}

function matchdayToken(match) {
  const n = journeeNumber(match);
  if (n > 0) return `j${n}`;
  const ms = matchDateMs(match);
  if (!ms) {
    const day = parisDateKey(match?.date);
    return day ? `d${day}` : '';
  }
  const wd = parisWeekday(ms);
  // R1 : samedi + dimanche = une seule journée même sans champ `journee`.
  if (wd === 'samedi') return `w${parisDateKey(ms)}`;
  if (wd === 'dimanche') return `w${parisDateKey(ms - 18 * 3600000)}`;
  const day = parisDateKey(ms);
  return day ? `d${day}` : '';
}

function slugPart(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 48) || 'x';
}

function dayRecapDocId(match) {
  const season = slugPart(match?.fffSeason || 'current');
  const champ = slugPart(championshipLabel(match));
  const day = matchdayToken(match) || `d${parisDateKey(Date.now())}`;
  return `${season}_${champ}_${day}`;
}

function sameSeason(a, b) {
  const sa = String(a?.fffSeason || '').trim();
  const sb = String(b?.fffSeason || '').trim();
  if (!sa || !sb) return true;
  return sa === sb;
}

function isMatchRoundSettled(data) {
  return !!(data && data.pronoScoredAt);
}

function formatPronoDayRecapCopy(agg = {}, { journee } = {}) {
  const points = Number(agg.points) || 0;
  const exacts = Number(agg.exacts) || 0;
  const goods = Number(agg.goods) || 0;
  const played = Number(agg.played) || 0;
  const n = Number(journee);
  const round = Number.isFinite(n) && n > 0 ? `Journée ${Math.floor(n)}` : 'Journée';
  const ptsWord = Math.abs(points) === 1 ? 'pt' : 'pts';
  const pts = points > 0 ? `+${points} ${ptsWord}` : `${points} ${ptsWord}`;

  const bits = [];
  if (exacts > 0) bits.push(exacts === 1 ? '1 score exact' : `${exacts} scores exacts`);
  if (goods > 0) bits.push(goods === 1 ? '1 bon 1-N-2' : `${goods} bons 1-N-2`);

  let detail;
  if (bits.length) detail = bits.join(' · ');
  else if (played > 0) detail = 'Aucun point';
  else detail = 'Journée enregistrée';

  return {
    title: `${round} · ${pts}`,
    body: `${detail}.`,
  };
}

function emptyAgg() {
  return { points: 0, exacts: 0, goods: 0, played: 0 };
}

function addPredictionToAgg(agg, pred) {
  const pts = Number(pred?.points);
  if (!Number.isFinite(pts)) return agg;
  agg.points += pts;
  agg.played += 1;
  if (pts === 3) agg.exacts += 1;
  else if (pts === 1) agg.goods += 1;
  return agg;
}

async function findRoundMatches(db, triggerMatch) {
  const competition = championshipLabel(triggerMatch);
  const dayToken = matchdayToken(triggerMatch);
  if (!dayToken) return [];

  const centerMs = matchDateMs(triggerMatch) || Date.now();
  const padMs = dayToken.startsWith('j') || dayToken.startsWith('w')
    ? 5 * 86400000
    : 40 * 3600000;
  const from = Timestamp.fromMillis(centerMs - padMs);
  const to = Timestamp.fromMillis(centerMs + padMs);

  const snap = await db.collection('matches')
    .where('competition', '==', competition)
    .where('date', '>=', from)
    .where('date', '<=', to)
    .get();

  const out = [];
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!sameSeason(triggerMatch, data)) continue;
    if (matchdayToken(data) !== dayToken) continue;
    out.push({ id: doc.id, data, ref: doc.ref });
  }
  return out;
}

async function loadRoundAggregates(db, matchIds) {
  const byUid = new Map();
  for (const matchId of matchIds) {
    const snap = await db.collection('predictions')
      .where('matchId', '==', matchId)
      .get();
    for (const doc of snap.docs) {
      const pred = doc.data() || {};
      const uid = String(pred.uid || '').trim();
      if (!uid) continue;
      if (!Number.isFinite(Number(pred.points))) continue;
      const agg = byUid.get(uid) || emptyAgg();
      addPredictionToAgg(agg, pred);
      byUid.set(uid, agg);
    }
  }
  return byUid;
}

async function claimDayRecap(db, dayKey, payload) {
  const ref = db.collection('prono_day_recaps').doc(dayKey);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data() || {};
    if (d.pronoDayRecapSent === true) return false;
    const claimedAt = d.claimedAt && typeof d.claimedAt.toMillis === 'function'
      ? d.claimedAt.toMillis()
      : 0;
    if (d.claiming === true && claimedAt && Date.now() - claimedAt < CLAIM_STALE_MS) {
      return false;
    }
    tx.set(ref, {
      ...payload,
      claiming: true,
      claimedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

async function sendDayRecapToUsers(db, dayRef, byUid, { journee } = {}) {
  const uids = [...byUid.keys()];
  let sent = 0;
  let skipped = 0;

  for (let i = 0; i < uids.length; i += USER_READ_CHUNK) {
    const chunk = uids.slice(i, i + USER_READ_CHUNK);
    const snaps = await Promise.all(
      chunk.map((uid) => db.collection('users').doc(uid).get()),
    );
    const ready = [];
    for (let j = 0; j < chunk.length; j += 1) {
      const uid = chunk[j];
      const recRef = dayRef.collection('recipients').doc(uid);
      const already = await recRef.get();
      if (already.exists) {
        skipped += 1;
        continue;
      }
      const udata = snaps[j].data() ?? {};
      if (!_notifPref(udata, 'pronoPointsRecap')) {
        await recRef.set({
          skipped: true,
          reason: 'pref_off',
          at: FieldValue.serverTimestamp(),
        });
        skipped += 1;
        continue;
      }
      ready.push({ uid, udata, recRef, agg: byUid.get(uid) });
    }

    for (let k = 0; k < ready.length; k += SEND_CHUNK) {
      const batch = ready.slice(k, k + SEND_CHUNK);
      const results = await Promise.allSettled(batch.map(async (row) => {
        const copy = formatPronoDayRecapCopy(row.agg, { journee });
        const ok = await _sendFcmToUser(
          db,
          row.udata,
          {
            notification: {
              title: copy.title,
              body: copy.body,
            },
            data: {
              type: 'prono_day_recap',
              pronoTab: 'matches',
            },
            ...fcmChannelBlocks('dvcr_alerts', { priority: 'normal' }),
          },
          `prono day recap ${row.uid}`,
          { recipientUid: row.uid },
        );
        await row.recRef.set({
          sent: !!ok,
          points: row.agg.points,
          exacts: row.agg.exacts,
          goods: row.agg.goods,
          played: row.agg.played,
          at: FieldValue.serverTimestamp(),
        });
        return ok;
      }));
      for (const r of results) {
        if (r.status === 'fulfilled' && r.value) sent += 1;
        else skipped += 1;
      }
    }
  }

  return { sent, skipped };
}

/**
 * Après le scoring d’un match : si toute la journée (même compétition +
 * matchday / date Paris) a `pronoScoredAt`, envoie 1 notif perso par user
 * qui a pronostiqué ces matchs. Idempotent via `prono_day_recaps/{dayKey}`.
 */
async function maybeSendPronoDayRecap(db, matchId, triggerMatch) {
  if (!triggerMatch || !db) return { skipped: 'no_match' };
  if (!isMatchRoundSettled(triggerMatch) && triggerMatch.status === 'finished') {
    // Le caller vient souvent de poser pronoScoredAt : on relit le round en base.
  }

  const siblings = await findRoundMatches(db, triggerMatch);
  if (!siblings.length) {
    console.log(`prono day recap: aucun sibling pour ${matchId}`);
    return { skipped: 'no_siblings' };
  }
  if (siblings.length < 2) {
    console.log(`prono day recap: match isolé ${matchId} — pas de récap journée`);
    return { skipped: 'too_small', count: siblings.length };
  }

  const pending = siblings.filter((row) => !isMatchRoundSettled(row.data));
  if (pending.length) {
    const sample = pending.slice(0, 3).map((row) => row.id).join(',');
    console.log(
      `prono day recap: journée incomplète (${pending.length} sans score) ex=${sample}`,
    );
    return { skipped: 'round_incomplete', pending: pending.length };
  }

  if (await _notificationsPaused(db)) {
    console.log('[maintenance] prono day recap skipped');
    return { skipped: 'maintenance' };
  }

  const dayKey = dayRecapDocId(triggerMatch);
  const matchIds = siblings.map((row) => row.id);
  const claimed = await claimDayRecap(db, dayKey, {
    championship: championshipLabel(triggerMatch),
    dateKey: parisDateKey(triggerMatch.date),
    matchday: matchdayToken(triggerMatch),
    matchIds,
    triggerMatchId: matchId,
  });
  if (!claimed) {
    console.log(`prono day recap: déjà envoyé / en cours ${dayKey}`);
    return { skipped: 'already_claimed', dayKey };
  }

  const dayRef = db.collection('prono_day_recaps').doc(dayKey);
  try {
    const byUid = await loadRoundAggregates(db, matchIds);
    let roundJ = journeeNumber(triggerMatch);
    if (!roundJ) {
      for (const row of siblings) {
        const j = journeeNumber(row.data);
        if (j > roundJ) roundJ = j;
      }
    }
    const { sent, skipped } = await sendDayRecapToUsers(db, dayRef, byUid, {
      journee: roundJ,
    });
    await dayRef.set({
      pronoDayRecapSent: true,
      claiming: false,
      sentAt: FieldValue.serverTimestamp(),
      sentCount: sent,
      skippedCount: skipped,
      userCount: byUid.size,
    }, { merge: true });
    console.log(
      `prono day recap ${dayKey}: ${sent} envoyée(s), ${skipped} skip, ${byUid.size} user(s)`,
    );
    return { ok: true, dayKey, sent, skipped, users: byUid.size, matchIds };
  } catch (e) {
    await dayRef.set({
      claiming: false,
      lastError: String(e.message || e),
    }, { merge: true });
    console.error(`prono day recap failed ${dayKey}:`, e.message);
    throw e;
  }
}

module.exports = {
  parisDateKey,
  championshipLabel,
  matchdayToken,
  journeeNumber,
  dayRecapDocId,
  isMatchRoundSettled,
  formatPronoDayRecapCopy,
  addPredictionToAgg,
  emptyAgg,
  maybeSendPronoDayRecap,
};
