'use strict';

function isTemporaryId(id) {
  return String(id || '').startsWith('live_');
}

function kindFor({ competition, benevoleType, team1, team2 } = {}) {
  const blob = [competition, benevoleType, team1, team2]
    .filter((v) => v != null && String(v).trim() !== '')
    .join(' ')
    .toLowerCase();

  if (
    blob.includes('réserve') ||
    blob.includes('reserve') ||
    blob.includes('régional 2') ||
    blob.includes('regional 2') ||
    /\br2\b/.test(blob)
  ) {
    return 'reserve';
  }
  if (blob.includes('coupe')) return 'coupe';
  return 'r1';
}

function nameScore(kind, name) {
  const n = String(name || '').trim().toLowerCase();
  if (!n) return 0;
  if (kind === 'coupe') {
    if (n.includes('coupe de france')) return 20;
    if (n.includes('coupe')) return 12;
    return 0;
  }
  if (kind === 'r1') {
    if (n.includes('homiris')) return 20;
    if (n.includes('régional 1') || n.includes('regional 1')) return 16;
    if (/\br1\b/.test(n) || n === 'r1') return 14;
    return 0;
  }
  if (n.includes('réserve') || n.includes('reserve')) return 20;
  if (n.includes('régional 2') || n.includes('regional 2')) return 12;
  if (/\br2\b/.test(n)) return 10;
  return 0;
}

function pickSalonId(kind, salons) {
  let bestId = 'general';
  let bestScore = 0;
  for (const s of salons || []) {
    const id = String(s.id || '');
    if (isTemporaryId(id)) continue;
    const score = nameScore(kind, s.name);
    if (score > bestScore) {
      bestScore = score;
      bestId = id;
    }
  }
  return bestId;
}

module.exports = {
  isTemporaryId,
  kindFor,
  pickSalonId,
};
