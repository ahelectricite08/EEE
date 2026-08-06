/**
 * Bénévoles Make — Scénario 1 (dispo → Make) + Scénario 2 (brief inbound).
 */
const crypto = require('crypto');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _isTeamDvcrUserData, _toSafeString } = require('./lib/admin_auth');

const benevoleMakeWebhookUrl = defineSecret('BENEVOLE_MAKE_WEBHOOK_URL');
const benevoleBriefWebhookSecret = defineSecret('BENEVOLE_BRIEF_WEBHOOK_SECRET');

const PRESENCE_STATUSES = new Set([
  'Présent',
  'Disponible si besoin',
  'Absent',
]);

const TYPE_PREMIERE = 'Équipe première';
const TYPE_RESERVE = 'Équipe réserve';

const POSTES_PREMIERE = [
  'Cadreur plan large',
  'Cadreur plan serré',
  'Cadreur 16m stabi',
  'Cadreur 16m',
  'Réalisateur',
  'Responsable Post Prod',
  "Chef d'édition – Ralenti",
  'Commentateur match 1',
  'Commentateur match 2',
  'Commentateur bord terrain',
  'Consultant bord terrain et tribune',
  'Présentateur avant match/mi-temps/après match',
  'Statisticien 1',
  'Statisticien 2',
  'Chef régisseur',
  'Régisseur 1 (tribune)',
  'Régisseur 2 (camion/édition)',
  'Régisseur 3 (pelouse)',
  'Community Manager',
  'Buvette local',
];

const POSTES_RESERVE = ['Vidéo', 'Commentateur'];

function _timingEqual(a, b) {
  const aa = Buffer.from(String(a || ''));
  const bb = Buffer.from(String(b || ''));
  if (aa.length !== bb.length) return false;
  return crypto.timingSafeEqual(aa, bb);
}

function _isSedanSide(name) {
  const u = _toSafeString(name).toUpperCase();
  return u.includes('SEDAN') || u.includes('CSSA') || u.includes('CS SEDAN');
}

function _resolveBenevoleType(m) {
  const explicit = _toSafeString(m.benevoleType);
  if (explicit) return explicit;
  const comp = _toSafeString(m.competition).toLowerCase();
  if (
    comp.includes('réserve') ||
    comp.includes('reserve') ||
    comp.includes('b team') ||
    /\bb\b/.test(comp)
  ) {
    return TYPE_RESERVE;
  }
  return TYPE_PREMIERE;
}

function _resolveDomicileExterieur(m) {
  const explicit = _toSafeString(m.domicileExterieur || m.domicile_exterieur);
  if (explicit === 'Domicile' || explicit === 'Extérieur') return explicit;
  if (_isSedanSide(m.team1)) return 'Domicile';
  return 'Extérieur';
}

function _resolveVille(m) {
  for (const k of ['ville', 'city', 'town']) {
    const v = _toSafeString(m[k]);
    if (v) return v;
  }
  const addr = _toSafeString(m.adresse || m.address || m.venueAddress);
  const mCp = /\b\d{5}\s+([A-Za-zÀ-ÿ\- ]+)/.exec(addr);
  if (mCp) return mCp[1].trim();
  if (_resolveDomicileExterieur(m) === 'Domicile') return 'Sedan';
  return '';
}

function _resolveLieu(m) {
  for (const k of ['lieu', 'stadium', 'venue', 'stade', 'stadiumName']) {
    const v = _toSafeString(m[k]);
    if (v) return v;
  }
  if (_resolveDomicileExterieur(m) === 'Domicile') return 'Stade Louis Dugauguez';
  return '';
}

function _resolveAdresse(m) {
  for (const k of ['adresse', 'address', 'venueAddress', 'fullAddress']) {
    const v = _toSafeString(m[k]);
    if (v) return v;
  }
  if (_resolveDomicileExterieur(m) === 'Domicile') {
    return 'Route de Charleville, 08200 Sedan';
  }
  return '';
}

function _postsForEventType(type) {
  const t = _toSafeString(type);
  if (t === TYPE_RESERVE) return [...POSTES_RESERVE];
  if (t === TYPE_PREMIERE) return [...POSTES_PREMIERE];
  const seen = new Set();
  const out = [];
  for (const p of [...POSTES_PREMIERE, ...POSTES_RESERVE]) {
    if (!seen.has(p)) {
      seen.add(p);
      out.push(p);
    }
  }
  return out;
}

function _daysUntilMatch(matchDate, now = new Date()) {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const kick = new Date(
    matchDate.getFullYear(),
    matchDate.getMonth(),
    matchDate.getDate(),
  );
  return Math.round((kick - today) / (24 * 60 * 60 * 1000));
}

function _isFormOpenFor(matchDate, now = new Date()) {
  const days = _daysUntilMatch(matchDate, now);
  return days >= 6 && days <= 20;
}

function _formatDateIso(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function _formatHeure(d) {
  const h = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${h}:${min}`;
}

async function _requireTeamDvcrCall(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isTeamDvcrUserData(userDoc.data())) {
    throw new HttpsError('permission-denied', 'Réservé aux Team DVCR');
  }
  return { db, userDoc, uid: request.auth.uid };
}

function _validateVoeux({ statut, voeu1, voeu2, voeu3, allowedPosts }) {
  if (!PRESENCE_STATUSES.has(statut)) {
    throw new HttpsError('invalid-argument', 'Statut présence invalide');
  }
  if (statut === 'Absent') {
    return { voeu1: '', voeu2: '', voeu3: '' };
  }
  if (!voeu1) {
    throw new HttpsError('invalid-argument', 'Vœu 1 requis (sauf Absent)');
  }
  const allowed = new Set(allowedPosts);
  const picks = [voeu1, voeu2, voeu3].filter(Boolean);
  const unique = new Set(picks);
  if (unique.size !== picks.length) {
    throw new HttpsError('invalid-argument', 'Vœux en double interdits');
  }
  for (const p of picks) {
    if (!allowed.has(p)) {
      throw new HttpsError('invalid-argument', `Poste non autorisé : ${p}`);
    }
  }
  return { voeu1, voeu2, voeu3 };
}

async function _postToMake(url, payload, { retries = 2 } = {}) {
  if (!url || !String(url).trim()) {
    console.warn('[benevole] BENEVOLE_MAKE_WEBHOOK_URL non configuré');
    return false;
  }
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(String(url).trim(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (res.ok) return true;
      lastErr = new Error(`HTTP ${res.status}`);
      console.warn(
        `[benevole] Make HTTP ${res.status} attempt=${attempt + 1}`,
      );
    } catch (err) {
      lastErr = err;
      console.warn(`[benevole] Make fetch error attempt=${attempt + 1}`, err);
    }
    if (attempt < retries) {
      await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
    }
  }
  console.error('[benevole] Make webhook failed', lastErr);
  return false;
}

function _verifyBriefSecret(req) {
  const expected = benevoleBriefWebhookSecret.value();
  if (!expected || !String(expected).trim()) return false;
  const exp = String(expected).trim();
  const header =
    req.get('X-DVCR-Webhook-Secret') ||
    req.get('x-dvcr-webhook-secret') ||
    '';
  const auth = req.get('Authorization') || '';
  let bearer = '';
  const m = /^Bearer\s+(.+)$/i.exec(auth);
  if (m) bearer = m[1].trim();
  const q =
    (req.query &&
      (req.query.dvcr_secret || req.query.key || req.query.token)) ||
    '';
  const fromQuery = Array.isArray(q) ? q[0] : q;
  return (
    _timingEqual(header.trim(), exp) ||
    _timingEqual(bearer, exp) ||
    _timingEqual(String(fromQuery || '').trim(), exp)
  );
}

function _readJsonBody(req) {
  const body = req.body;
  if (body && typeof body === 'object' && !Buffer.isBuffer(body)) return body;
  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch (_) {
      return null;
    }
  }
  return null;
}

exports.submitBenevoleAvailability = onCall(
  {
    cors: true,
    region: 'europe-west1',
    secrets: [benevoleMakeWebhookUrl],
  },
  async (request) => {
    const { db, userDoc, uid } = await _requireTeamDvcrCall(request);
    const data = request.data || {};

    const matchId = _toSafeString(data.matchId);
    if (!matchId) {
      throw new HttpsError('invalid-argument', 'matchId requis');
    }

    const matchSnap = await db.collection('matches').doc(matchId).get();
    if (!matchSnap.exists) {
      throw new HttpsError('not-found', 'Match introuvable');
    }
    const match = matchSnap.data() || {};
    const rawDate = match.date;
    if (!rawDate || typeof rawDate.toDate !== 'function') {
      throw new HttpsError('failed-precondition', 'Date match invalide');
    }
    const matchDate = rawDate.toDate();
    if (!_isFormOpenFor(matchDate)) {
      throw new HttpsError(
        'failed-precondition',
        'Formulaire fermé (fenêtre J-20 → J-6)',
      );
    }

    const t1 = _toSafeString(match.team1);
    const t2 = _toSafeString(match.team2);
    if (!_isSedanSide(t1) && !_isSedanSide(t2)) {
      throw new HttpsError('failed-precondition', 'Match non éligible');
    }

    const statut = _toSafeString(data.statut_presence || data.statutPresence);
    const voeu1 = _toSafeString(data.voeu_1 || data.voeu1);
    const voeu2 = _toSafeString(data.voeu_2 || data.voeu2);
    const voeu3 = _toSafeString(data.voeu_3 || data.voeu3);

    const benevoleType = _resolveBenevoleType(match);
    const userData = userDoc.data() || {};
    const authorizedRaw = userData.benevolePostes;
    const authorized = Array.isArray(authorizedRaw)
      ? authorizedRaw.map((e) => _toSafeString(e)).filter(Boolean)
      : [];
    const forType = _postsForEventType(benevoleType);
    const allowedPosts =
      authorized.length > 0
        ? forType.filter((p) => authorized.includes(p))
        : forType;

    const voeux = _validateVoeux({
      statut,
      voeu1,
      voeu2,
      voeu3,
      allowedPosts,
    });

    const email =
      _toSafeString(request.auth.token.email) ||
      _toSafeString(userData.email);
    if (!email) {
      throw new HttpsError('failed-precondition', 'Email bénévole manquant');
    }

    const domicileExterieur = _resolveDomicileExterieur(match);
    const ville = _resolveVille(match);
    const lieu = _resolveLieu(match);
    const adresse = _resolveAdresse(match);
    const nomEvenement = `${t1} vs ${t2}`;

    const responseId = `${matchId}_${uid}`;
    const now = Timestamp.now();

    const makePayload = {
      id_evenement: matchId,
      email_benevole: email,
      statut_presence: statut,
      voeu_1: voeux.voeu1,
      voeu_2: voeux.voeu2,
      voeu_3: voeux.voeu3,
      type: benevoleType,
      nom_evenement: nomEvenement,
      date: _formatDateIso(matchDate),
      heure: _formatHeure(matchDate),
      competition: _toSafeString(match.competition),
      domicile_exterieur: domicileExterieur,
      lieu,
      ville,
      adresse,
    };

    const makeOk = await _postToMake(
      benevoleMakeWebhookUrl.value(),
      makePayload,
    );

    await db
      .collection('benevole_responses')
      .doc(responseId)
      .set(
        {
          matchId,
          uid,
          email,
          statutPresence: statut,
          voeu1: voeux.voeu1,
          voeu2: voeux.voeu2,
          voeu3: voeux.voeu3,
          benevoleType,
          nomEvenement,
          ville,
          lieu,
          makeOk,
          submittedAt: now,
          updatedAt: now,
        },
        { merge: true },
      );

    return { ok: true, makeOk, id: responseId };
  },
);

exports.receiveBenevoleBrief = onRequest(
  {
    cors: true,
    region: 'europe-west1',
    secrets: [benevoleBriefWebhookSecret],
    invoker: 'public',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method === 'GET') {
      if (!_verifyBriefSecret(req)) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }
      res.status(200).json({
        ok: true,
        service: 'receiveBenevoleBrief',
        hint:
          'POST JSON { id_evenement, nom_evenement, date, lien_brief } + secret X-DVCR-Webhook-Secret',
      });
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }
    if (!_verifyBriefSecret(req)) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }

    const body = _readJsonBody(req);
    if (!body || typeof body !== 'object') {
      res.status(400).json({ error: 'invalid_body' });
      return;
    }

    const idEvenement = _toSafeString(
      body.id_evenement || body.idEvenement || body.matchId,
    );
    const lienBrief = _toSafeString(
      body.lien_brief || body.lienBrief || body.briefUrl || body.url,
    );
    if (!idEvenement) {
      res.status(422).json({ error: 'missing_id_evenement' });
      return;
    }
    if (!lienBrief.startsWith('http')) {
      res.status(422).json({ error: 'missing_lien_brief' });
      return;
    }

    const db = getFirestore();
    const ref = db.collection('matches').doc(idEvenement);
    const snap = await ref.get();
    if (!snap.exists) {
      res.status(404).json({ error: 'match_not_found', id: idEvenement });
      return;
    }

    const nomEvenement = _toSafeString(
      body.nom_evenement || body.nomEvenement,
    );
    const dateStr = _toSafeString(body.date);

    await ref.set(
      {
        benevoleBriefUrl: lienBrief,
        benevoleBriefUpdatedAt: FieldValue.serverTimestamp(),
        ...(nomEvenement ? { benevoleBriefNom: nomEvenement } : {}),
        ...(dateStr ? { benevoleBriefDate: dateStr } : {}),
      },
      { merge: true },
    );

    console.log(`[benevole] brief updated match=${idEvenement}`);
    res.status(200).json({ ok: true, matchId: idEvenement });
  },
);
