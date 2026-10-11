/**
 * Recalcule le XI probable d’UN match (Hagondange par défaut).
 * Met à jour matchedCount / points + delta classement.
 * Ne re-donne PAS d’XP si le prono est déjà `awarded`.
 *
 *   node scripts/rescore_lineup_one_match.js
 *   node scripts/rescore_lineup_one_match.js <matchId>
 */
const path = require('path');
const {
  countNameMatches,
  resolvePredictedLabels,
  lineupPredPoints,
} = require('../lib/lineup_name_match');

const toolsRoot = path.join(
  process.env.APPDATA,
  'npm',
  'node_modules',
  'firebase-tools',
  'lib',
);
const { getGlobalDefaultAccount, getAccessToken } = require(path.join(toolsRoot, 'auth.js'));
const { CLOUD_PLATFORM } = require(path.join(toolsRoot, 'scopes.js'));

const PROJECT = 'drapeau-vert-app';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const COMMIT = `${BASE.replace(/\/documents$/, '')}/documents:commit`;
const HINT = process.argv[2] || 'hagondange';

function isSedan(name) {
  const u = String(name || '').toUpperCase();
  return u.includes('SEDAN') || u.includes('CSSA');
}

function fieldStr(fields, key) {
  return fields?.[key]?.stringValue || '';
}

function fieldBool(fields, key) {
  return fields?.[key]?.booleanValue === true;
}

function fieldNum(fields, key) {
  const f = fields?.[key];
  if (!f) return 0;
  if (f.integerValue != null) return Number(f.integerValue);
  if (f.doubleValue != null) return Number(f.doubleValue);
  return 0;
}

function fieldList(fields, key) {
  const arr = fields?.[key]?.arrayValue?.values;
  if (!Array.isArray(arr)) return [];
  return arr.map((v) => {
    if (v.stringValue) return v.stringValue;
    if (v.mapValue?.fields) return fieldStr(v.mapValue.fields, 'name');
    return '';
  }).filter(Boolean);
}

function startersFromSide(fields, sideKey) {
  const side = fields?.[sideKey]?.mapValue?.fields;
  if (!side) return [];
  return fieldList(side, 'starters');
}

function docIdFromName(name) {
  return String(name || '').split('/').pop();
}

async function authHeaders() {
  const account = getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('firebase login requis');
  }
  const tok = await getAccessToken(account.tokens.refresh_token, [CLOUD_PLATFORM]);
  return { Authorization: `Bearer ${tok.access_token}` };
}

async function listMatches(auth) {
  const docs = [];
  let pageToken = '';
  do {
    const qs = new URLSearchParams({ pageSize: '300' });
    if (pageToken) qs.set('pageToken', pageToken);
    const res = await fetch(`${BASE}/matches?${qs}`, { headers: auth });
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body));
    for (const doc of body.documents || []) docs.push(doc);
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return docs;
}

async function runQuery(auth, structuredQuery) {
  const res = await fetch(`${BASE}:runQuery`, {
    method: 'POST',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(body));
  return (Array.isArray(body) ? body : [])
    .map((row) => row.document)
    .filter(Boolean);
}

async function getDoc(auth, relPath) {
  const res = await fetch(`${BASE}/${relPath}`, { headers: auth });
  if (res.status === 404) return null;
  const body = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(body));
  return body;
}

async function commit(auth, writes) {
  if (!writes.length) return;
  for (let i = 0; i < writes.length; i += 200) {
    const chunk = writes.slice(i, i + 200);
    const res = await fetch(COMMIT, {
      method: 'POST',
      headers: { ...auth, 'Content-Type': 'application/json' },
      body: JSON.stringify({ writes: chunk }),
    });
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body));
  }
}

function findMatchDoc(docs) {
  if (HINT && !/hagondange/i.test(HINT) && HINT.length > 8) {
    const hit = docs.find((d) => docIdFromName(d.name) === HINT);
    if (hit) return hit;
  }
  const needle = String(HINT).toLowerCase();
  const hits = [];
  for (const doc of docs) {
    const f = doc.fields || {};
    const t1 = fieldStr(f, 'team1');
    const t2 = fieldStr(f, 'team2');
    if (!`${t1} ${t2}`.toLowerCase().includes(needle)) continue;
    if (!isSedan(t1) && !isSedan(t2)) continue;
    hits.push(doc);
  }
  hits.sort((a, b) => {
    const ta = a.fields?.date?.timestampValue || '';
    const tb = b.fields?.date?.timestampValue || '';
    return String(tb).localeCompare(String(ta));
  });
  return hits[0] || null;
}

(async () => {
  const auth = await authHeaders();
  const matches = await listMatches(auth);
  const found = findMatchDoc(matches);
  if (!found) {
    console.error(`Aucun match Sedan / ${HINT}`);
    process.exit(2);
  }
  const matchId = docIdFromName(found.name);
  const f = found.fields || {};
  const t1 = fieldStr(f, 'team1');
  const t2 = fieldStr(f, 'team2');
  const official = isSedan(t1)
    ? startersFromSide(f, 'lineupHome')
    : startersFromSide(f, 'lineupAway');
  console.log(`Match ${matchId}  ${t1} / ${t2}  officiels=${official.length}`);
  console.log('Officiel:', official.join(' | '));
  if (official.length < 11) {
    console.error('Pas 11 titulaires Sedan — abort.');
    process.exit(3);
  }

  const squadDoc = await getDoc(auth, 'app_config/sedan_squad');
  const squad = new Map();
  for (const raw of fieldList(squadDoc?.fields || {}, 'players')) {
    // fieldList flattens to names only — reload maps
  }
  const players = squadDoc?.fields?.players?.arrayValue?.values || [];
  for (const item of players) {
    const pf = item.mapValue?.fields || {};
    const id = fieldStr(pf, 'id');
    const name = fieldStr(pf, 'name');
    if (id && name) squad.set(id, name);
  }

  const preds = await runQuery(auth, {
    from: [{ collectionId: 'lineup_predictions' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'matchId' },
        op: 'EQUAL',
        value: { stringValue: matchId },
      },
    },
  });
  console.log(`Pronos XI: ${preds.length}`);

  const writes = [];
  let rescoreCount = 0;
  let deltaUsers = 0;
  for (const doc of preds) {
    const pf = doc.fields || {};
    const names = fieldList(pf, 'playerNames');
    const ids = fieldList(pf, 'playerIds');
    const resolved = resolvePredictedLabels(names, ids, squad);
    const matched = countNameMatches(resolved, official);
    const points = lineupPredPoints(matched);
    const wasAwarded = fieldBool(pf, 'awarded');
    const oldPoints = fieldNum(pf, 'points');
    const oldMatched = fieldNum(pf, 'matchedCount');
    const uid = fieldStr(pf, 'uid') || docIdFromName(doc.name).split('_').pop();
    const displayName = fieldStr(pf, 'displayName') || 'Membre';

    writes.push({
      update: {
        name: doc.name,
        fields: {
          awarded: { booleanValue: true },
          matchedCount: { integerValue: String(matched) },
          points: { integerValue: String(points) },
        },
      },
      updateMask: { fieldPaths: ['awarded', 'matchedCount', 'points'] },
    });
    rescoreCount += 1;

    const delta = wasAwarded ? (points - oldPoints) : points;
    const lbName = `projects/${PROJECT}/databases/(default)/documents/prono_leaderboard/${uid}`;
    const transforms = [];
    if (delta !== 0) {
      transforms.push(
        { fieldPath: 'points', increment: { integerValue: String(delta) } },
        { fieldPath: 'lineupPoints', increment: { integerValue: String(delta) } },
      );
      deltaUsers += 1;
    }
    if (matched >= 11 && !(wasAwarded && oldMatched >= 11)) {
      transforms.push({ fieldPath: 'perfectXiCount', increment: { integerValue: '1' } });
    } else if (wasAwarded && oldMatched >= 11 && matched < 11) {
      transforms.push({ fieldPath: 'perfectXiCount', increment: { integerValue: '-1' } });
    }
    if (transforms.length && uid) {
      writes.push({
        update: {
          name: lbName,
          fields: {
            uid: { stringValue: uid },
            displayName: { stringValue: displayName },
            displayNameLower: { stringValue: displayName.toLowerCase() },
          },
        },
        updateMask: { fieldPaths: ['uid', 'displayName', 'displayNameLower'] },
        updateTransforms: transforms,
      });
    }
    console.log(
      `  ${uid}  ${oldMatched}->${matched}  ${oldPoints}->${points} pts`
      + `${wasAwarded ? ' (recalc, pas d’XP)' : ' (1er score)'}`,
    );
  }

  writes.push({
    update: {
      name: found.name,
      fields: {
        lineupPredictionsLocked: { booleanValue: true },
        lineupPredictionsScored: { booleanValue: true },
        lineupPredictionsRescoredCount: { integerValue: String(rescoreCount) },
      },
    },
    updateMask: {
      fieldPaths: [
        'lineupPredictionsLocked',
        'lineupPredictionsScored',
        'lineupPredictionsRescoredCount',
      ],
    },
  });

  await commit(auth, writes);
  console.log(`DONE match=${matchId} docs=${rescoreCount} lbDelta=${deltaUsers}`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
