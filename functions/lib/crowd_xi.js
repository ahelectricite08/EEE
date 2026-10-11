'use strict';

const {
  normalizePlayerName,
  countNameMatches,
} = require('./lineup_name_match');

function pickDisplayLabel(labelsMap, officialLabel) {
  if (officialLabel) return officialLabel;
  let best = '';
  let max = -1;
  for (const [label, count] of labelsMap) {
    if (count > max || (count === max && label.length > best.length)) {
      max = count;
      best = label;
    }
  }
  return best;
}

/**
 * Top 11 du vestiaire à partir des pronos XI (docs `lineup_predictions`).
 * [officialStarters] optionnel : aligne les noms et pose `inOfficial`.
 */
function buildCrowdXi(predictions, officialStarters = []) {
  const officialKeys = new Set();
  const officialLabelByKey = new Map();
  for (const raw of officialStarters || []) {
    const key = normalizePlayerName(raw);
    if (!key) continue;
    officialKeys.add(key);
    if (!officialLabelByKey.has(key)) officialLabelByKey.set(key, String(raw).trim());
  }

  const byKey = new Map();
  let ballots = 0;
  for (const pred of predictions || []) {
    const names = Array.isArray(pred?.playerNames) ? pred.playerNames : [];
    const cleaned = [];
    for (const raw of names) {
      const n = String(raw || '').trim();
      if (n) cleaned.push(n);
    }
    if (cleaned.length < 11) continue;
    ballots += 1;
    const seen = new Set();
    for (const raw of cleaned) {
      const key = normalizePlayerName(raw);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      let row = byKey.get(key);
      if (!row) {
        row = { key, votes: 0, labels: new Map() };
        byKey.set(key, row);
      }
      row.votes += 1;
      row.labels.set(raw, (row.labels.get(raw) || 0) + 1);
    }
  }

  const ranked = [...byKey.values()].sort((a, b) => {
    if (b.votes !== a.votes) return b.votes - a.votes;
    return a.key.localeCompare(b.key);
  });

  const players = ranked.slice(0, 11).map((row) => {
    const inOfficial = officialKeys.has(row.key)
      || countNameMatches([row.key], officialStarters || []) > 0;
    return {
      name: pickDisplayLabel(row.labels, officialLabelByKey.get(row.key)),
      votes: row.votes,
      inOfficial,
    };
  });

  const officialHits = players.filter((p) => p.inOfficial).length;
  return {
    players,
    ballots,
    officialHits,
    officialComputed: officialKeys.size >= 11,
  };
}

function crowdXiUnchanged(prev, next) {
  if (!prev || !next) return false;
  if (Number(prev.ballots) !== Number(next.ballots)) return false;
  if (Number(prev.officialHits) !== Number(next.officialHits)) return false;
  if (!!prev.officialComputed !== !!next.officialComputed) return false;
  const a = Array.isArray(prev.players) ? prev.players : [];
  const b = Array.isArray(next.players) ? next.players : [];
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (String(a[i].name || '') !== String(b[i].name || '')) return false;
    if (Number(a[i].votes) !== Number(b[i].votes)) return false;
    if (!!a[i].inOfficial !== !!b[i].inOfficial) return false;
  }
  return true;
}

function crowdXiShouldWrite(existing, next) {
  if (!next || !Array.isArray(next.players) || next.players.length < 11) return false;
  if (next.ballots < 1) return false;
  return !crowdXiUnchanged(existing, next);
}

module.exports = {
  normalizePlayerName,
  buildCrowdXi,
  crowdXiUnchanged,
  crowdXiShouldWrite,
};
