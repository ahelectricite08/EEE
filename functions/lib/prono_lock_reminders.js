'use strict';

/** XI Sedan : verrou 2 j 12 h avant le KO — aligné `prono_scoring.js`. */
const LINEUP_LOCK_BEFORE_MS = (2 * 24 + 12) * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

function isReserveOrR2(id, competition) {
  const i = String(id || '').toLowerCase();
  if (i.startsWith('fff_r2_') || i.startsWith('r2_')) return true;
  const c = String(competition || '').toLowerCase();
  if (c.includes('régional 2') || c.includes('regional 2')) return true;
  if (c.includes('réserve') || c.includes('reserve')) return true;
  return /\br2\b/.test(c);
}

function isSedanMatch(team1, team2) {
  const hit = (s) => {
    const u = String(s || '').toUpperCase();
    return u.includes('SEDAN') || u.includes('CSSA');
  };
  return hit(team1) || hit(team2);
}

function matchDateMs(date) {
  if (date == null) return 0;
  if (typeof date.toMillis === 'function') return date.toMillis();
  if (date instanceof Date) return date.getTime();
  const n = Number(date);
  return Number.isFinite(n) ? n : 0;
}

function parisParts(ms) {
  const dtf = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Europe/Paris',
    weekday: 'long',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const map = {};
  for (const p of dtf.formatToParts(new Date(ms))) {
    if (p.type !== 'literal') map[p.type] = p.value;
  }
  return map;
}

function parisDayKey(ms) {
  const p = parisParts(ms);
  return `${p.year}-${p.month}-${p.day}`;
}

function parisHour(ms) {
  return Number(parisParts(ms).hour || 0);
}

/** Convertit un mur Paris (Y-M-D H:m) en epoch ms. */
function parisWallMs(year, month, day, hour, minute = 0) {
  const y = Number(year);
  const mo = Number(month);
  const d = Number(day);
  const h = Number(hour);
  const mi = Number(minute);
  let utc = Date.UTC(y, mo - 1, d, h, mi);
  for (let i = 0; i < 3; i += 1) {
    const p = parisParts(utc);
    const asParis = Date.UTC(
      Number(p.year),
      Number(p.month) - 1,
      Number(p.day),
      Number(p.hour),
      Number(p.minute),
    );
    utc -= asParis - utc;
    const check = parisParts(utc);
    if (Number(check.year) === y && Number(check.month) === mo
      && Number(check.day) === d && Number(check.hour) === h) {
      break;
    }
  }
  return utc;
}

function previousParisEvening(ms, hour = 20) {
  const p = parisParts(ms);
  const sinceMidnight = (Number(p.hour) * 60 + Number(p.minute)) * 60 * 1000;
  const prev = ms - sinceMidnight - HOUR_MS;
  const d = parisParts(prev);
  return parisWallMs(d.year, d.month, d.day, hour, 0);
}

/** Pas de push entre 00 h et 8 h : on bascule au créneau diurne du même jour. */
function snapXiTargetToDaytime(targetMs, { hour = 18 } = {}) {
  if (parisHour(targetMs) >= 8) return targetMs;
  const p = parisParts(targetMs);
  return parisWallMs(p.year, p.month, p.day, hour, 0);
}

/** 1 h avant le verrou, ou 20 h la veille si ça tombe la nuit. */
function xiLastCallTarget(lockAtMs) {
  const raw = lockAtMs - HOUR_MS;
  if (parisHour(raw) >= 8) return raw;
  return previousParisEvening(raw, 20);
}

function frenchWeekday(ms) {
  const w = String(parisParts(ms).weekday || '').toLowerCase();
  return w || 'jour';
}

function hoursLeftLabel(msLeft) {
  const h = Math.max(1, Math.round(msLeft / HOUR_MS));
  return h === 1 ? '1 h' : `${h} h`;
}

function isAround(nowMs, targetMs, { beforeMs = 18 * 60 * 1000, afterMs = 6 * 60 * 1000 } = {}) {
  return nowMs >= targetMs - beforeMs && nowMs <= targetMs + afterMs;
}

function formatKickoffShort(ms) {
  const p = parisParts(ms);
  return `${p.hour}h${p.minute}`;
}

/**
 * Groupes « pronos score du jour » (samedi / dimanche / autre).
 * Un rappel pour le 1er coup d’envoi du jour civil Paris.
 */
function buildScoreDayGroups(matches, nowMs) {
  const groups = new Map();
  for (const m of matches) {
    if (isReserveOrR2(m.id, m.competition)) continue;
    const ko = matchDateMs(m.date);
    if (!ko || ko <= nowMs) continue;
    const key = parisDayKey(ko);
    const cur = groups.get(key);
    if (!cur || ko < cur.firstKickoffMs) {
      groups.set(key, {
        dayKey: key,
        weekday: frenchWeekday(ko),
        firstKickoffMs: ko,
        count: (cur?.count || 0) + 1,
        matchIds: cur ? [...cur.matchIds, m.id] : [m.id],
      });
    } else {
      cur.count += 1;
      cur.matchIds.push(m.id);
    }
  }
  return [...groups.values()].sort((a, b) => a.firstKickoffMs - b.firstKickoffMs);
}

function pickScoreDayReminders(groups, nowMs) {
  const out = [];
  for (const g of groups) {
    const until = g.firstKickoffMs - nowMs;
    if (until <= 0) continue;
    for (const hours of [3, 1]) {
      const target = g.firstKickoffMs - hours * HOUR_MS;
      if (!isAround(nowMs, target)) continue;
      const when = hoursLeftLabel(until);
      const day = g.weekday;
      out.push({
        id: `score-${hours}h-${g.dayKey}`,
        kind: 'score',
        title: `Pronos ${day}`,
        body: `Les pronos pour ${day} ferment dans ${when} (1er KO ${formatKickoffShort(g.firstKickoffMs)}).`,
        pronoTab: 'matches',
        matchIds: [...(g.matchIds || [])],
        weekday: day,
        when,
      });
    }
  }
  return out;
}

function preferFffMatchId(a, b) {
  const score = (id) => {
    const i = String(id || '');
    if (i.startsWith('fff_r2_') || i.startsWith('r2_')) return 0;
    if (i.startsWith('fff_')) return 2;
    return 1;
  };
  return score(a) >= score(b) ? a : b;
}

function uniqueSedanXiMatches(matches) {
  const byKey = new Map();
  for (const m of matches || []) {
    if (!isSedanMatch(m.team1, m.team2)) continue;
    if (isReserveOrR2(m.id, m.competition)) continue;
    const ko = matchDateMs(m.date);
    if (!ko) continue;
    const opp = isSedanMatch(m.team1, '') ? m.team2 : m.team1;
    const key = `${parisDayKey(ko)}|${String(opp || '').toUpperCase()}`;
    const prev = byKey.get(key);
    if (!prev || preferFffMatchId(m.id, prev.id) === m.id) {
      byKey.set(key, m);
    }
  }
  return [...byKey.values()];
}

function sameParisEvening(aMs, bMs) {
  if (!aMs || !bMs) return false;
  return parisDayKey(aMs) === parisDayKey(bMs)
    && Math.abs(aMs - bMs) <= 8 * HOUR_MS;
}

function pickXiReminders(matches, nowMs, { lockBeforeMs = LINEUP_LOCK_BEFORE_MS } = {}) {
  if (frenchWeekday(nowMs) !== 'mercredi') return [];
  const p = parisParts(nowMs);
  const target = parisWallMs(p.year, p.month, p.day, 20, 0);
  if (!isAround(nowMs, target)) return [];

  const weekend = uniqueSedanXiMatches(matches)
    .filter((m) => {
      const ko = matchDateMs(m.date);
      if (!ko || ko <= nowMs) return false;
      if (nowMs >= ko - lockBeforeMs) return false;
      const wd = frenchWeekday(ko);
      return wd === 'samedi' || wd === 'dimanche';
    })
    .sort((a, b) => matchDateMs(a.date) - matchDateMs(b.date));
  if (!weekend.length) return [];

  const days = [...new Set(weekend.map((m) => frenchWeekday(matchDateMs(m.date))))];
  const first = weekend[0];
  const opp = isSedanMatch(first.team1, '') ? first.team2 : first.team1;
  let whenLabel = 'samedi';
  if (days.includes('samedi') && days.includes('dimanche')) whenLabel = 'le week-end';
  else if (days.includes('dimanche')) whenLabel = 'dimanche';
  const oppBit = opp && whenLabel !== 'le week-end' ? ` (${opp})` : '';

  return [{
    id: `xi-wed20-${parisDayKey(target)}`,
    kind: 'xi',
    matchId: first.id,
    title: 'Prono compo CSSA',
    body: `N’oublie pas la composition pour ${whenLabel}${oppBit}.`,
    pronoTab: 'home',
  }];
}

function collectDueReminders(matches, nowMs = Date.now()) {
  const score = pickScoreDayReminders(buildScoreDayGroups(matches, nowMs), nowMs);
  const xi = pickXiReminders(matches, nowMs);
  return [...score, ...xi];
}

function predictionHasScore(pred) {
  if (!pred) return false;
  const s1 = pred.score1Pred;
  const s2 = pred.score2Pred;
  if (s1 == null || s1 === '' || s2 == null || s2 === '') return false;
  return Number.isFinite(Number(s1)) && Number.isFinite(Number(s2));
}

function lineupIsComplete(pred) {
  const names = Array.isArray(pred?.playerNames) ? pred.playerNames : [];
  return names.filter((n) => String(n || '').trim()).length >= 11;
}

function missingScoreCount(matchIds, uid, uidsByMatch) {
  const ids = Array.isArray(matchIds) ? matchIds : [];
  let missing = 0;
  for (const id of ids) {
    if (!uidsByMatch.get(id)?.has(uid)) missing += 1;
  }
  return missing;
}

function userNeedsScoreReminder(matchIds, uid, uidsByMatch) {
  const ids = Array.isArray(matchIds) ? matchIds : [];
  if (!ids.length) return false;
  return missingScoreCount(ids, uid, uidsByMatch) > 0;
}

function userNeedsXiReminder(uid, xiUids) {
  return !xiUids.has(uid);
}

function scoreReminderBodyForUser(reminder, missing) {
  const day = reminder.weekday || 'jour';
  const when = reminder.when || 'peu de temps';
  const total = (reminder.matchIds || []).length;
  if (!missing || missing === total) {
    return reminder.body;
  }
  if (missing === 1) {
    return `Encore 1 prono pour ${day} — ça ferme dans ${when}.`;
  }
  return `Encore ${missing} pronos pour ${day} — ça ferme dans ${when}.`;
}

module.exports = {
  LINEUP_LOCK_BEFORE_MS,
  isReserveOrR2,
  isSedanMatch,
  parisDayKey,
  frenchWeekday,
  hoursLeftLabel,
  isAround,
  buildScoreDayGroups,
  pickScoreDayReminders,
  pickXiReminders,
  uniqueSedanXiMatches,
  collectDueReminders,
  parisWallMs,
  xiLastCallTarget,
  predictionHasScore,
  lineupIsComplete,
  missingScoreCount,
  userNeedsScoreReminder,
  userNeedsXiReminder,
  scoreReminderBodyForUser,
};
