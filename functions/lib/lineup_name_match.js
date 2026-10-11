'use strict';

/**
 * Matching XI probable Sedan — même règles que
 * `lib/utils/player_name_normalize.dart`.
 */

function normalizePlayerName(raw) {
  let s = String(raw || '').trim().toLowerCase();
  if (!s) return '';
  try {
    s = s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  } catch (_) {
    // older Node
  }
  s = s
    .replace(/[àáâãäå]/g, 'a')
    .replace(/[èéêë]/g, 'e')
    .replace(/[ìíîï]/g, 'i')
    .replace(/[òóôõö]/g, 'o')
    .replace(/[ùúûü]/g, 'u')
    .replace(/[ýÿ]/g, 'y')
    .replace(/ç/g, 'c')
    .replace(/ñ/g, 'n');
  s = s.replace(/[''`´’-]/g, '');
  s = s.replace(/^\d+\s*[-.]?\s*/, '');
  s = s.replace(/[^a-z0-9\s]+/g, '');
  s = s.replace(/\s+/g, ' ').trim();
  return s;
}

function lastNameToken(normalizedFull) {
  const parts = String(normalizedFull || '').split(' ').filter(Boolean);
  return parts.length ? parts[parts.length - 1] : '';
}

function levenshtein(a, b) {
  if (a === b) return 0;
  if (!a) return b.length;
  if (!b) return a.length;
  const prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  const curr = new Array(b.length + 1);
  for (let i = 1; i <= a.length; i += 1) {
    curr[0] = i;
    const ca = a.charCodeAt(i - 1);
    for (let j = 1; j <= b.length; j += 1) {
      const cost = ca === b.charCodeAt(j - 1) ? 0 : 1;
      const del = prev[j] + 1;
      const ins = curr[j - 1] + 1;
      const sub = prev[j - 1] + cost;
      curr[j] = Math.min(del, ins, sub);
    }
    for (let j = 0; j <= b.length; j += 1) prev[j] = curr[j];
  }
  return prev[b.length];
}

function isLetterLastName(token) {
  return token.length >= 3 && /^[a-z]+$/.test(token);
}

function lastNamesResemble(a, b) {
  if (!a || !b) return false;
  if (a === b) return true;
  if (!isLetterLastName(a) || !isLetterLastName(b)) return false;
  const d = levenshtein(a, b);
  if (d <= 1) return true;
  if (d === 2 && a.length >= 6 && b.length >= 6 && a[0] === b[0]) return true;
  return false;
}

function resolvePredictedLabels(names, ids, squadIdToName) {
  const nList = Array.isArray(names) ? names : [];
  const iList = Array.isArray(ids) ? ids : [];
  const map = squadIdToName instanceof Map ? squadIdToName : new Map();
  if (!iList.length || map.size === 0) {
    return nList.map((e) => String(e || '').trim()).filter(Boolean);
  }
  const n = Math.max(nList.length, iList.length);
  const out = [];
  for (let i = 0; i < n; i += 1) {
    const id = String(iList[i] || '').trim();
    const fromSquad = id ? map.get(id) : '';
    if (fromSquad && String(fromSquad).trim()) {
      out.push(String(fromSquad).trim());
      continue;
    }
    const name = String(nList[i] || '').trim();
    if (name) out.push(name);
  }
  return out;
}

function matchPlayerNames(predicted, official) {
  const pool = [];
  (official || []).forEach((raw, i) => {
    const norm = normalizePlayerName(raw);
    if (!norm) return;
    pool.push({ i, raw: String(raw), norm });
  });

  const predItems = [];
  (predicted || []).forEach((raw, i) => {
    const norm = normalizePlayerName(raw);
    if (!norm) return;
    predItems.push({ i, raw: String(raw), norm });
  });

  const officialLastCounts = new Map();
  for (const e of pool) {
    const last = lastNameToken(e.norm);
    if (!last) continue;
    officialLastCounts.set(last, (officialLastCounts.get(last) || 0) + 1);
  }
  const predLastCounts = new Map();
  for (const e of predItems) {
    const last = lastNameToken(e.norm);
    if (!last) continue;
    predLastCounts.set(last, (predLastCounts.get(last) || 0) + 1);
  }

  const used = new Set();
  const takenPred = new Set();
  const hits = [];

  function take(p, o) {
    used.add(o.i);
    takenPred.add(p.i);
    hits.push({
      predictedIndex: p.i,
      predictedRaw: p.raw,
      officialIndex: o.i,
      officialRaw: o.raw,
    });
  }

  for (const p of predItems) {
    for (const o of pool) {
      if (used.has(o.i)) continue;
      if (o.norm === p.norm) {
        take(p, o);
        break;
      }
    }
  }

  for (const p of predItems) {
    if (takenPred.has(p.i)) continue;
    const last = lastNameToken(p.norm);
    if (!isLetterLastName(last)) continue;
    if (officialLastCounts.get(last) !== 1) continue;
    if (predLastCounts.get(last) !== 1) continue;
    for (const o of pool) {
      if (used.has(o.i)) continue;
      if (lastNameToken(o.norm) === last) {
        take(p, o);
        break;
      }
    }
  }

  for (const p of predItems) {
    if (takenPred.has(p.i)) continue;
    const last = lastNameToken(p.norm);
    if (!isLetterLastName(last)) continue;
    if (predLastCounts.get(last) !== 1) continue;
    const candidates = [];
    for (const o of pool) {
      if (used.has(o.i)) continue;
      const oLast = lastNameToken(o.norm);
      if (!isLetterLastName(oLast)) continue;
      if (officialLastCounts.get(oLast) !== 1) continue;
      if (lastNamesResemble(last, oLast)) candidates.push(o);
    }
    if (candidates.length === 1) take(p, candidates[0]);
  }

  return hits;
}

function countNameMatches(predicted, official) {
  return matchPlayerNames(predicted, official).length;
}

function lineupPredPoints(matched) {
  if (matched >= 11) return 3;
  if (matched >= 10) return 2;
  if (matched >= 9) return 1;
  return 0;
}

module.exports = {
  normalizePlayerName,
  lastNameToken,
  levenshtein,
  lastNamesResemble,
  resolvePredictedLabels,
  matchPlayerNames,
  countNameMatches,
  lineupPredPoints,
};
