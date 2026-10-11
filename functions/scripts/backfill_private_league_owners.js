/**
 * One-shot : pose un créateur (ownerUid) sur les ligues privées qui n’en ont pas.
 *
 * - Ligues sans créateur utilisable → memberIds[0] (« au piff »).
 * - Owner fantôme (plus dans memberIds) → memberIds[0].
 * - Team DVCR → UID d’Axel s’il est membre (jamais memberIds[0] au hasard).
 * - Ne touche pas un owner réel encore membre (sauf Team DVCR → Axel).
 *
 * Auth : refresh token Firebase CLI (REST Firestore), comme les autres scripts.
 *
 *   node scripts/backfill_private_league_owners.js
 *   $env:DRY_RUN="1"; node scripts/backfill_private_league_owners.js
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
const DRY_RUN = process.env.DRY_RUN === '1';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const COMMIT = `${BASE.replace(/\/documents$/, '')}/documents:commit`;
const AUTH_LOOKUP = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`;
const OWNER_KEYS = ['ownerUid', 'ownerId', 'createdBy', 'createdByUid'];

function memberIdsOf(data) {
  const raw = data && data.memberIds;
  if (!Array.isArray(raw)) return [];
  return raw.map((e) => String(e || '').trim()).filter(Boolean);
}

function declaredOwnerUids(data) {
  const out = [];
  if (!data) return out;
  for (const key of OWNER_KEYS) {
    const v = String(data[key] || '').trim();
    if (v) out.push(v);
  }
  return out;
}

function usableOwnerUid(data, members) {
  const set = new Set(members);
  for (const uid of declaredOwnerUids(data)) {
    if (set.has(uid)) return uid;
  }
  return '';
}

function normalizeLeagueName(name) {
  return String(name || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function isTeamDvcrLeague(data) {
  const n = normalizeLeagueName(data && data.name);
  const k = normalizeLeagueName(data && data.nameKey);
  // « Team DVCR », « TEAM DVCR », « LA TEAM DVCR »
  return n === 'team dvcr' || k === 'team dvcr' || n.includes('team dvcr') || k.includes('team dvcr');
}

function rolesOf(data) {
  const out = [];
  if (!data) return out;
  if (typeof data.role === 'string' && data.role.trim()) {
    out.push(data.role.trim().toLowerCase());
  }
  if (Array.isArray(data.roles)) {
    for (const r of data.roles) {
      const v = String(r || '').trim().toLowerCase();
      if (v) out.push(v);
    }
  }
  return out;
}

function axelScore(uid, data, authEmail) {
  const display = String(
    (data && (data.displayName || data.displayNameLower)) || '',
  ).toLowerCase();
  const first = String(
    (data && (data.firstName || data.firstNameLower)) || '',
  ).toLowerCase();
  const email = String(
    (data && (data.email || data.emailLower)) || authEmail || '',
  ).toLowerCase();
  const blob = `${uid} ${display} ${first} ${email}`.toLowerCase();
  let score = 0;
  if (email.includes('axeld') || String(uid).toLowerCase().includes('axeld')) {
    score += 50;
  }
  if (/\baxel[d._-]/.test(email) || email.startsWith('axel')) score += 40;
  if (display === 'axel' || display.startsWith('axel ')) score += 40;
  if (first === 'axel') score += 30;
  if (blob.includes('axel')) score += 20;
  if (rolesOf(data).includes('admin')) score += 10;
  return score;
}

function fromFirestoreValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('stringValue' in value) return value.stringValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(fromFirestoreValue);
  }
  if ('mapValue' in value) {
    const out = {};
    for (const [k, v] of Object.entries(value.mapValue.fields || {})) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }
  return null;
}

function docToJs(doc) {
  const out = {};
  for (const [k, v] of Object.entries(doc.fields || {})) {
    out[k] = fromFirestoreValue(v);
  }
  const name = doc.name || '';
  const id = name.split('/').pop();
  return { id, name, data: out, fields: doc.fields || {} };
}

function ownerFieldPaths(data) {
  const paths = ['ownerUid', 'updatedAt'];
  for (const key of ['ownerId', 'createdBy', 'createdByUid']) {
    if (Object.prototype.hasOwnProperty.call(data, key)) paths.push(key);
  }
  return paths;
}

function ownerUpdateFields(data, uid) {
  const fields = {
    ownerUid: { stringValue: uid },
    updatedAt: { timestampValue: new Date().toISOString() },
  };
  for (const key of ['ownerId', 'createdBy', 'createdByUid']) {
    if (Object.prototype.hasOwnProperty.call(data, key)) {
      fields[key] = { stringValue: uid };
    }
  }
  return fields;
}

async function authHeaders() {
  const account = getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('firebase login requis');
  }
  const tok = await getAccessToken(account.tokens.refresh_token, [CLOUD_PLATFORM]);
  return { Authorization: `Bearer ${tok.access_token}` };
}

async function listCollection(auth, collection) {
  const docs = [];
  let pageToken = '';
  do {
    const qs = new URLSearchParams({ pageSize: '300' });
    if (pageToken) qs.set('pageToken', pageToken);
    const res = await fetch(`${BASE}/${collection}?${qs}`, { headers: auth });
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body));
    docs.push(...(body.documents || []));
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return docs.map(docToJs);
}

async function getDoc(auth, collection, id) {
  const res = await fetch(`${BASE}/${collection}/${encodeURIComponent(id)}`, {
    headers: auth,
  });
  if (res.status === 404) return null;
  const body = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(body));
  return docToJs(body);
}

async function lookupAuthUsers(auth, uids) {
  const out = new Map();
  for (let i = 0; i < uids.length; i += 90) {
    const chunk = uids.slice(i, i + 90);
    const res = await fetch(AUTH_LOOKUP, {
      method: 'POST',
      headers: { ...auth, 'Content-Type': 'application/json' },
      body: JSON.stringify({ localId: chunk }),
    });
    const body = await res.json();
    if (!res.ok) {
      console.warn('accounts:lookup skip:', body.error?.message || res.status);
      continue;
    }
    for (const u of body.users || []) {
      out.set(String(u.localId || ''), {
        email: String(u.email || ''),
        displayName: String(u.displayName || ''),
      });
    }
  }
  return out;
}

function pickAxelUid(memberIds, hints) {
  let best = { uid: '', score: 0 };
  for (const uid of memberIds) {
    const hint = hints.get(uid) || { data: {}, authEmail: '' };
    const score = axelScore(uid, hint.data, hint.authEmail);
    if (score > best.score) best = { uid, score };
  }
  return best.score > 0 ? best.uid : '';
}

async function commitPatches(auth, writes) {
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

async function main() {
  const auth = await authHeaders();
  const leagues = await listCollection(auth, 'private_leagues');
  const teamDvcr = leagues.filter((l) => isTeamDvcrLeague(l.data));

  const teamMembers = [];
  for (const l of teamDvcr) {
    for (const uid of memberIdsOf(l.data)) {
      if (!teamMembers.includes(uid)) teamMembers.push(uid);
    }
  }

  const hints = new Map();
  const authUsers = teamMembers.length
    ? await lookupAuthUsers(auth, teamMembers)
    : new Map();
  for (const uid of teamMembers) {
    const userDoc = await getDoc(auth, 'users', uid);
    const rec = authUsers.get(uid) || { email: '', displayName: '' };
    const data = userDoc ? { ...userDoc.data } : {};
    if (!data.displayName && rec.displayName) data.displayName = rec.displayName;
    if (!data.email && rec.email) data.email = rec.email;
    hints.set(uid, { data, authEmail: rec.email });
  }

  const axelUid = pickAxelUid(teamMembers, hints);
  if (axelUid) {
    const hint = hints.get(axelUid) || { data: {}, authEmail: '' };
    console.log(
      `Axel identifié : ${axelUid}  display=${hint.data.displayName || '—'}  email=${hint.data.email || hint.authEmail || '—'}  roles=${rolesOf(hint.data).join(',') || '—'}`,
    );
  } else if (teamDvcr.length && teamMembers.length) {
    console.warn(
      'Aucun membre Team DVCR ne ressemble à Axel (displayName/email). Team DVCR ne sera PAS assignée à memberIds[0].',
    );
  } else if (teamDvcr.length) {
    console.warn('Team DVCR sans memberIds — skip owner Axel.');
  } else {
    console.warn('Aucune ligue nommée Team DVCR.');
  }

  const patched = [];
  const skipped = [];
  const writes = [];
  let teamDvcrOwnerNow = '';

  for (const league of leagues) {
    const { id, name, data } = league;
    const members = memberIdsOf(data);
    const label = String(data.name || id);
    const current = usableOwnerUid(data, members);
    const isTeam = isTeamDvcrLeague(data);

    if (isTeam) {
      if (!axelUid) {
        skipped.push({ id, name: label, reason: 'team_dvcr_axel_introuvable' });
        teamDvcrOwnerNow = current || String(data.ownerUid || '');
        continue;
      }
      if (current === axelUid && String(data.ownerUid || '').trim() === axelUid) {
        skipped.push({ id, name: label, reason: 'deja_axel' });
        teamDvcrOwnerNow = axelUid;
        continue;
      }
      writes.push({
        update: { name, fields: ownerUpdateFields(data, axelUid) },
        updateMask: { fieldPaths: ownerFieldPaths(data) },
      });
      patched.push({
        id,
        name: label,
        from: String(data.ownerUid || current || '(vide)'),
        to: axelUid,
        why: 'team_dvcr_axel',
      });
      teamDvcrOwnerNow = axelUid;
      continue;
    }

    if (!members.length) {
      skipped.push({ id, name: label, reason: 'memberIds_vide' });
      continue;
    }
    if (current) {
      skipped.push({ id, name: label, reason: 'owner_membre' });
      continue;
    }
    const chosen = members[0];
    writes.push({
      update: { name, fields: ownerUpdateFields(data, chosen) },
      updateMask: { fieldPaths: ownerFieldPaths(data) },
    });
    patched.push({
      id,
      name: label,
      from: String(data.ownerUid || declaredOwnerUids(data)[0] || '(vide)'),
      to: chosen,
      why: declaredOwnerUids(data).length ? 'owner_fantome' : 'owner_vide',
    });
  }

  if (!DRY_RUN && writes.length) {
    await commitPatches(auth, writes);
  }

  console.log(
    DRY_RUN
      ? `\nDRY_RUN — ${patched.length} ligue(s) à patcher, ${skipped.length} ignorée(s), ${leagues.length} au total.`
      : `\nOK — ${patched.length} ligue(s) patchée(s), ${skipped.length} ignorée(s), ${leagues.length} au total.`,
  );
  for (const p of patched) {
    console.log(`  PATCH ${p.name} [${p.id}] ${p.from} → ${p.to} (${p.why})`);
  }
  const skipCounts = {};
  for (const s of skipped) {
    skipCounts[s.reason] = (skipCounts[s.reason] || 0) + 1;
  }
  console.log('skips:', skipCounts);
  if (teamDvcr.length) {
    console.log(
      `Team DVCR ownerUid maintenant : ${teamDvcrOwnerNow || '(vide)'} (axelUid=${axelUid || '—'})`,
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
