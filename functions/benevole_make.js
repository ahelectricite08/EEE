/**
 * Bénévoles Make — Scénario 1 (dispo → Make) + Scénario 2 (brief inbound).
 */
const crypto = require('crypto');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const {
  _isTeamDvcrUserData,
  _toSafeString,
  _isUserAdmin,
} = require('./lib/admin_auth');

const benevoleMakeWebhookUrl = defineSecret('BENEVOLE_MAKE_WEBHOOK_URL');
const benevoleBriefWebhookSecret = defineSecret('BENEVOLE_BRIEF_WEBHOOK_SECRET');

const PRESENCE_STATUSES = new Set([
  'Présent',
  'Disponible si besoin',
  'Absent',
]);

const TYPE_R1 = 'R1';
const TYPE_COUPE = 'Coupe';
const TYPE_RESERVE = 'Réserve';
const TYPE_FLAMMES = 'Flammes';
const TYPE_PERSO = 'Perso / intervention extérieure';
const TYPE_PREMIERE = TYPE_R1;

const RIGHT_R1 = 'r1';
const RIGHT_COUPE = 'coupe';
const RIGHT_RESERVE = 'reserve';
const RIGHT_FLAMMES = 'flammes';
const RIGHT_EXTERIEUR = 'exterieur';

const POSTES_PREMIERE = [
  'Cadreur plan large',
  'Cadreur plan serré',
  'Cadreur 16m stabi',
  'Cadreur 16m',
  'Cadreur bord terrain stabi',
  'Cadreur bord terrain',
  'Réalisateur',
  'Responsable Post Prod',
  "Chef d'édition – Ralenti",
  'Commentateur match 1',
  'Commentateur match 2',
  'Commentateur bord terrain',
  'Consultant bord terrain et tribune',
  'Présentateur avant/mi-temps/après match',
  'Statisticien 1',
  'Statisticien 2',
  'Chef régisseur',
  'Régisseur 1 (tribune)',
  'Régisseur 2 (camion/édition)',
  'Régisseur 3 (pelouse 1)',
  'Régisseur 4 (pelouse 2)',
  'Community Manager',
  'Responsable buvette 1',
  'Responsable buvette 2',
  'Responsable buvette 3',
  'Responsable buvette 4',
];

const POSTES_RESERVE = ['Vidéo (Réserve)', 'Commentateur (Réserve)'];

const POSTES_FLAMMES = [
  'Cadreur plan large',
  'Cadreur plan serré',
  'Cadreur 16m stabi',
  'Cadreur 16m',
  'Réalisateur',
  "Chef d'édition – Ralenti",
  'Régisseur 1 (tribune)',
];

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

function _normalizeBenevoleType(raw) {
  const t = _toSafeString(raw);
  if (!t) return TYPE_R1;
  if (
    t === TYPE_R1 ||
    t === TYPE_COUPE ||
    t === TYPE_RESERVE ||
    t === TYPE_FLAMMES ||
    t === TYPE_PERSO
  ) {
    return t;
  }
  const lower = t.toLowerCase();
  if (lower.includes('réserve') || lower.includes('reserve')) return TYPE_RESERVE;
  if (lower.includes('flammes') || lower.includes('carolo')) return TYPE_FLAMMES;
  if (lower.includes('coupe')) return TYPE_COUPE;
  if (
    lower.includes('perso') ||
    lower.includes('extérieur') ||
    lower.includes('exterieur') ||
    lower.includes('intervention') ||
    t === 'Autre' ||
    t === 'Formation'
  ) {
    return TYPE_PERSO;
  }
  if (
    lower.includes('première') ||
    lower.includes('premiere') ||
    lower === 'r1'
  ) {
    return TYPE_R1;
  }
  return TYPE_R1;
}

function _resolveBenevoleType(m) {
  const explicit = _toSafeString(m.benevoleType);
  if (explicit) return _normalizeBenevoleType(explicit);
  const comp = _toSafeString(m.competition).toLowerCase();
  if (comp.includes('réserve') || comp.includes('reserve')) return TYPE_RESERVE;
  if (comp.includes('flammes') || comp.includes('carolo')) return TYPE_FLAMMES;
  if (comp.includes('coupe')) return TYPE_COUPE;
  return TYPE_R1;
}

function _parseEventRights(userData) {
  if (!userData || !Object.prototype.hasOwnProperty.call(userData, 'benevoleEventRights')) {
    return null;
  }
  const raw = userData.benevoleEventRights;
  if (!Array.isArray(raw)) return [];
  return raw.map((e) => _toSafeString(e)).filter(Boolean);
}

function _canSeeEventType(type, rights, isAdmin) {
  if (isAdmin) return true;
  if (rights == null) return true;
  if (!rights.length) return false;
  const set = new Set(rights.map((r) => String(r).trim().toLowerCase()));
  const normalized = _normalizeBenevoleType(type);
  if (normalized === TYPE_COUPE) {
    return set.has(RIGHT_R1) || set.has(RIGHT_COUPE);
  }
  if (normalized === TYPE_RESERVE) return set.has(RIGHT_RESERVE);
  if (normalized === TYPE_FLAMMES) return set.has(RIGHT_FLAMMES);
  if (normalized === TYPE_PERSO) return set.has(RIGHT_EXTERIEUR);
  return set.has(RIGHT_R1);
}

function _resolveDomicileExterieur(m) {
  const explicit = _toSafeString(m.domicileExterieur || m.domicile_exterieur);
  if (explicit === 'Domicile' || explicit === 'Extérieur') return explicit;
  if (_isSedanSide(m.team1)) return 'Domicile';
  return 'Extérieur';
}

function _resolveVille(m) {
  for (const k of ['ville', 'city', 'town', 'commune']) {
    const v = _toSafeString(m[k]);
    if (v) return v;
  }
  const addr = _toSafeString(m.adresse || m.address || m.venueAddress);
  const mCp = /\b\d{5}\s+([A-Za-zÀ-ÿ\-']+)/.exec(addr);
  if (mCp) return mCp[1].trim();
  if (_resolveDomicileExterieur(m) === 'Domicile') return 'Sedan';
  return '';
}

function _resolveLieu(m) {
  for (const k of [
    'lieu',
    'stadium',
    'venue',
    'stade',
    'stadiumName',
    'terrain',
    'terrainNom',
  ]) {
    const v = _toSafeString(m[k]);
    if (v) return v;
  }
  if (_resolveDomicileExterieur(m) === 'Domicile') return 'Stade Louis Dugauguez';
  return '';
}

/** Adversaire = l’équipe non-Sedan (ou team2 si Sedan des deux côtés — rare). */
function _resolveAdversaire(m) {
  const t1 = _toSafeString(m.team1);
  const t2 = _toSafeString(m.team2);
  if (_isSedanSide(t1) && !_isSedanSide(t2)) return t2;
  if (_isSedanSide(t2) && !_isSedanSide(t1)) return t1;
  return t2 || t1;
}

/** Heure locale Europe/Paris (HH:mm) — les CF tournent en UTC. */
function _formatHeureParis(d) {
  try {
    const parts = new Intl.DateTimeFormat('fr-FR', {
      timeZone: 'Europe/Paris',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).formatToParts(d);
    const hh = parts.find((p) => p.type === 'hour')?.value ?? '00';
    const mm = parts.find((p) => p.type === 'minute')?.value ?? '00';
    return `${hh}:${mm}`;
  } catch (_) {
    return _formatHeure(d);
  }
}

function _postsForEventType(type) {
  const t = _normalizeBenevoleType(type);
  if (t === TYPE_RESERVE) return [...POSTES_RESERVE];
  if (t === TYPE_FLAMMES) return [...POSTES_FLAMMES];
  return [...POSTES_PREMIERE];
}

function _ymdParis(d) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);
}

function _hourParis(d) {
  const parts = new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Europe/Paris',
    hour: '2-digit',
    hour12: false,
  }).formatToParts(d);
  return Number(parts.find((p) => p.type === 'hour')?.value ?? '0');
}

function _daysUntilMatchParis(matchDate, now = new Date()) {
  const a = Date.parse(`${_ymdParis(now)}T00:00:00Z`);
  const b = Date.parse(`${_ymdParis(matchDate)}T00:00:00Z`);
  return Math.round((b - a) / (24 * 60 * 60 * 1000));
}

/** J-20 00:00 Paris → J-3 12:00 Paris (exclus à midi). */
function _isFormOpenFor(matchDate, now = new Date()) {
  const days = _daysUntilMatchParis(matchDate, now);
  if (days > 20 || days < 3) return false;
  if (days > 3) return true;
  return _hourParis(now) < 12;
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

async function _loadBenevoleEvent(db, matchId) {
  let snap = await db.collection('matches').doc(matchId).get();
  if (snap.exists) {
    return { match: snap.data() || {}, isCustom: false };
  }
  snap = await db.collection('benevole_events').doc(matchId).get();
  if (snap.exists) {
    return { match: snap.data() || {}, isCustom: true };
  }
  return null;
}

function _eventDisplayName(match, isCustom) {
  const title = _toSafeString(match.title);
  const t1 = _toSafeString(match.team1) || title;
  const t2 = _toSafeString(match.team2);
  if (isCustom && t1 && !t2) return t1;
  if (t1 && t2) return `${t1} vs ${t2}`;
  return t1 || t2 || 'Événement';
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

    const loaded = await _loadBenevoleEvent(db, matchId);
    if (!loaded) {
      throw new HttpsError('not-found', 'Événement introuvable');
    }
    const { match, isCustom } = loaded;
    const rawDate = match.date;
    if (!rawDate || typeof rawDate.toDate !== 'function') {
      throw new HttpsError('failed-precondition', 'Date événement invalide');
    }
    const matchDate = rawDate.toDate();
    if (!_isFormOpenFor(matchDate)) {
      throw new HttpsError(
        'failed-precondition',
        'Formulaire fermé (fenêtre J-20 → J-3 12h)',
      );
    }

    const t1 = _toSafeString(match.team1) || _toSafeString(match.title);
    const t2 = _toSafeString(match.team2);
    if (!isCustom && !_isSedanSide(t1) && !_isSedanSide(t2)) {
      const tagged = _resolveBenevoleType(match);
      const blob = `${t1} ${t2} ${match.competition || ''}`.toLowerCase();
      const okTagged =
        tagged === TYPE_FLAMMES ||
        tagged === TYPE_RESERVE ||
        blob.includes('flammes') ||
        blob.includes('carolo');
      if (!okTagged) {
        throw new HttpsError('failed-precondition', 'Match non éligible');
      }
    }

    const statut = _toSafeString(data.statut_presence || data.statutPresence);
    const voeu1 = _toSafeString(data.voeu_1 || data.voeu1);
    const voeu2 = _toSafeString(data.voeu_2 || data.voeu2);
    const voeu3 = _toSafeString(data.voeu_3 || data.voeu3);

    const benevoleType = isCustom
      ? TYPE_PERSO
      : _resolveBenevoleType(match);
    const userData = userDoc.data() || {};
    const isAdmin = _isUserAdmin(userDoc);
    const rights = _parseEventRights(userData);
    if (!_canSeeEventType(benevoleType, rights, isAdmin)) {
      throw new HttpsError(
        'permission-denied',
        'Tu n’es pas affecté à ce type d’événement',
      );
    }

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

    const domicileExterieur = isCustom
      ? 'Extérieur'
      : _resolveDomicileExterieur(match);
    const ville = _resolveVille(match);
    const lieu = _resolveLieu(match);
    const adversaire = isCustom ? '' : _resolveAdversaire(match);
    const nomEvenement = _eventDisplayName(match, isCustom);
    const heureDebut = _formatHeureParis(matchDate);

    const responseId = `${matchId}_${uid}`;
    const now = Timestamp.now();

    const makePayload = {
      id_evenement: matchId,
      nom_evenement: nomEvenement,
      type: benevoleType,
      date: _formatDateIso(matchDate),
      heure_debut: heureDebut,
      lieu,
      ville,
      domicile_exterieur: domicileExterieur,
      adversaire,
      email_benevole: email,
      statut_presence: statut,
      voeu_1: voeux.voeu1,
      voeu_2: voeux.voeu2,
      voeu_3: voeux.voeu3,
    };

    const makeOk = await _postToMake(
      benevoleMakeWebhookUrl.value(),
      makePayload,
    );
    if (!makeOk) {
      console.error(
        `[benevole] Make sync failed response=${responseId} email=${email} event=${matchId}`,
      );
    }

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
          adversaire,
          heureDebut,
          ville,
          lieu,
          makeOk,
          makeLastAttemptAt: now,
          isCustomEvent: isCustom,
          submittedAt: now,
          updatedAt: now,
        },
        { merge: true },
      );

    return { ok: true, makeOk, id: responseId };
  },
);

exports.retryBenevoleMakeSync = onCall(
  {
    cors: true,
    region: 'europe-west1',
    secrets: [benevoleMakeWebhookUrl],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Non authentifié');
    }
    const db = getFirestore();
    const adminSnap = await db.collection('users').doc(request.auth.uid).get();
    if (!_isUserAdmin(adminSnap)) {
      throw new HttpsError('permission-denied', 'Réservé aux admins');
    }
    const responseId = _toSafeString(request.data?.responseId);
    if (!responseId) {
      throw new HttpsError('invalid-argument', 'responseId requis');
    }
    const respSnap = await db.collection('benevole_responses').doc(responseId).get();
    if (!respSnap.exists) {
      throw new HttpsError('not-found', 'Réponse introuvable');
    }
    const r = respSnap.data() || {};
    const matchId = _toSafeString(r.matchId);
    const loaded = matchId ? await _loadBenevoleEvent(db, matchId) : null;
    const match = loaded?.match || {};
    const isCustom = loaded?.isCustom === true || r.isCustomEvent === true;
    const rawDate = match.date;
    const matchDate =
      rawDate && typeof rawDate.toDate === 'function'
        ? rawDate.toDate()
        : null;

    const makePayload = {
      id_evenement: matchId,
      nom_evenement: _toSafeString(r.nomEvenement) ||
        (loaded ? _eventDisplayName(match, isCustom) : matchId),
      type: _normalizeBenevoleType(r.benevoleType),
      date: matchDate ? _formatDateIso(matchDate) : '',
      heure_debut: _toSafeString(r.heureDebut),
      lieu: _toSafeString(r.lieu),
      ville: _toSafeString(r.ville),
      domicile_exterieur: _toSafeString(r.domicile_exterieur) ||
        (isCustom ? 'Extérieur' : _resolveDomicileExterieur(match)),
      adversaire: _toSafeString(r.adversaire),
      email_benevole: _toSafeString(r.email),
      statut_presence: _toSafeString(r.statutPresence),
      voeu_1: _toSafeString(r.voeu1),
      voeu_2: _toSafeString(r.voeu2),
      voeu_3: _toSafeString(r.voeu3),
    };

    const makeOk = await _postToMake(
      benevoleMakeWebhookUrl.value(),
      makePayload,
    );
    await respSnap.ref.set(
      {
        makeOk,
        makeLastAttemptAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );
    if (!makeOk) {
      console.error(`[benevole] retry Make failed response=${responseId}`);
    }
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
    let ref = db.collection('matches').doc(idEvenement);
    let snap = await ref.get();
    if (!snap.exists) {
      ref = db.collection('benevole_events').doc(idEvenement);
      snap = await ref.get();
    }
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
