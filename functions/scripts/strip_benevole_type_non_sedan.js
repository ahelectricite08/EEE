/**
 * Retire benevoleType des fiches match qui ne sont pas Sedan/CSSA/Flammes.
 * La sync FFF avait taggé toute la poule R1 → elles apparaissaient aux bénévoles.
 *
 *   node scripts/strip_benevole_type_non_sedan.js
 */
const path = require('path');

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

function isClubMatch(t1, t2, competition) {
  const a = String(t1 || '').toUpperCase();
  const b = String(t2 || '').toUpperCase();
  if (a.includes('SEDAN') || a.includes('CSSA') || b.includes('SEDAN') || b.includes('CSSA')) {
    return true;
  }
  const blob = `${a} ${b} ${competition || ''}`.toLowerCase();
  return blob.includes('flammes') || blob.includes('carolo');
}

function fieldStr(fields, key) {
  return fields?.[key]?.stringValue || '';
}

async function main() {
  const account = getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('firebase login requis');
  }
  const tok = await getAccessToken(account.tokens.refresh_token, [CLOUD_PLATFORM]);
  const auth = { Authorization: `Bearer ${tok.access_token}` };

  const docs = [];
  let pageToken = '';
  do {
    const qs = new URLSearchParams({ pageSize: '300' });
    if (pageToken) qs.set('pageToken', pageToken);
    const res = await fetch(`${BASE}/matches?${qs}`, { headers: auth });
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body));
    docs.push(...(body.documents || []));
    pageToken = body.nextPageToken || '';
  } while (pageToken);

  const toStrip = [];
  let kept = 0;
  for (const doc of docs) {
    const f = doc.fields || {};
    if (!f.benevoleType) {
      kept += 1;
      continue;
    }
    if (isClubMatch(fieldStr(f, 'team1'), fieldStr(f, 'team2'), fieldStr(f, 'competition'))) {
      kept += 1;
      continue;
    }
    toStrip.push(doc.name);
  }

  for (let i = 0; i < toStrip.length; i += 200) {
    const chunk = toStrip.slice(i, i + 200);
    const res = await fetch(
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:commit`,
      {
        method: 'POST',
        headers: { ...auth, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          writes: chunk.map((name) => ({
            update: { name, fields: {} },
            updateMask: { fieldPaths: ['benevoleType'] },
          })),
        }),
      },
    );
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body));
  }

  console.log(`stripped=${toStrip.length} kept=${kept} total=${docs.length}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
