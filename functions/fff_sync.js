const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { _isUserAdmin } = require('./lib/admin_auth');
const {
  FFF_BASE, FFF_HOST, FFF_CP, FFF_PH, FFF_GP, FFF_CLUB,
  FFF_CONFIG_DOC, FFF_LIFECYCLE_DOC, _loadFffSeasonConfig,
} = require('./lib/fff_config');

/**
 * Headers browser-like pour api-dofa.fff.fr.
 * Un UA custom (ex. DVCR-App/…) déclenche un 403 HTML (WAF / Akamai).
 */
const FFF_FETCH_HEADERS = {
  Accept: 'application/ld+json, application/json',
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  Origin: 'https://epreuves.fff.fr',
  Referer: 'https://epreuves.fff.fr/',
  'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
};

/** Fetch JSON DOFA. Ne throw pas sur HTML/403 — retourne parseError pour soft-fail. */
async function _fffFetchJson(url) {
  const res = await fetch(url, { headers: FFF_FETCH_HEADERS });
  const text = await res.text();
  let data = null;
  let parseError = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch (_) {
      const snippet = text.replace(/\s+/g, ' ').slice(0, 160);
      parseError =
        `Réponse non-JSON HTTP ${res.status} pour ${url} — ${snippet}`;
    }
  }
  return {
    ok: res.ok && !parseError,
    status: res.status,
    data,
    url,
    parseError,
  };
}

/** Sync FFF autorisée ? (cron + manuel sauf force admin) */
async function _fffSyncGate(db, { force = false } = {}) {
  if (force) return { enabled: true };

  const [fffSnap, lifeSnap] = await Promise.all([
    db.collection('app_config').doc(FFF_CONFIG_DOC).get(),
    db.collection('app_config').doc(FFF_LIFECYCLE_DOC).get(),
  ]);
  const fffData = fffSnap.data() || {};
  const lifeData = lifeSnap.data() || {};

  if (fffData.fffSyncEnabled === false) {
    return {
      enabled: false,
      reason: 'Synchronisation FFF désactivée (app_config/fff_season.fffSyncEnabled)',
    };
  }
  if (lifeData.betweenSeasons === true) {
    return {
      enabled: false,
      reason: 'Fin de saison active (app_config/season_lifecycle.betweenSeasons)',
    };
  }
  return { enabled: true };
}

async function _runFffSyncCore(db, { force = false } = {}) {
  const gate = await _fffSyncGate(db, { force });
  if (!gate.enabled) {
    console.log(`FFF sync ignorée : ${gate.reason}`);
    return { skipped: true, reason: gate.reason };
  }
  // Matchs d’abord (scores / statuts), puis classement + enrichissement rank/form.
  await _syncMatches(db);
  const classement = await _syncClassement(db);
  return { skipped: false, ...classement };
}

// ── 3. Sync FFF (6 h) — rien si fin de saison ou fffSyncEnabled=false ─────────
exports.syncFffData = onSchedule('every 6 hours', async () => {
  const db = getFirestore();
  const result = await _runFffSyncCore(db);
  if (!result.skipped) console.log('FFF sync terminé');
});

/** Délai minimum entre deux sync FFF déclenchées depuis l’app (onglet Calendrier). */
const FFF_ON_DEMAND_COOLDOWN_MS = 30 * 60 * 1000;
const FFF_ON_DEMAND_DOC = 'fff_sync_on_demand';

// Sync à la demande (app — onglet Calendrier). Auth requise ; throttle global ~90 s.
exports.syncFffDataOnCalendarOpen = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Connexion requise pour actualiser le calendrier');
  }
  const db = getFirestore();
  const now = Date.now();
  const throttleRef = db.collection('app_config').doc(FFF_ON_DEMAND_DOC);
  const throttleSnap = await throttleRef.get();
  const lastMs = throttleSnap.data()?.lastTriggeredAt?.toMillis?.() ?? 0;
  const elapsed = now - lastMs;
  if (elapsed < FFF_ON_DEMAND_COOLDOWN_MS) {
    return {
      success: true,
      skipped: true,
      reason: 'throttled',
      retryAfterSeconds: Math.ceil((FFF_ON_DEMAND_COOLDOWN_MS - elapsed) / 1000),
    };
  }

  const result = await _runFffSyncCore(db);
  if (!result.skipped) {
    await throttleRef.set(
      {
        lastTriggeredAt: Timestamp.now(),
        lastUid: request.auth.uid,
      },
      { merge: true },
    );
  }
  return {
    success: true,
    skipped: !!result.skipped,
    reason: result.reason ?? null,
    journee: result.journee ?? 0,
    rankingTeams: result.rankingTeams ?? 0,
    rankingWrites: result.rankingWrites ?? 0,
    matchesEnriched: result.matchesEnriched ?? 0,
  };
});

// Sync manuelle scores/classement (admin only). data.force=true pour ignorer la coupure.
// Région europe-west1 : alignée sur l’appel admin Flutter (fff_season_settings_panel).
exports.syncFffDataManual = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  // Admin panel : force par défaut pour ne pas bloquer sur betweenSeasons.
  const force = request.data?.force !== false;
  try {
    const result = await _runFffSyncCore(db, { force });
    if (result.skipped) {
      throw new HttpsError(
        'failed-precondition',
        `${result.reason}. Pour forcer : call avec { "force": true }.`,
      );
    }
    await _cleanMockMatches(db);
    const rankingTeams = result.rankingTeams ?? 0;
    const rankingBlocked = !!result.error;
    let warning = null;
    if (rankingBlocked) {
      warning =
        `Classement FFF inaccessible (${result.error}) — matchs synchronisés si disponibles.`;
    } else if (rankingTeams === 0) {
      warning =
        'Classement FFF vide (pré-saison) — matchs synchronisés si disponibles.';
    }
    return {
      success: true,
      journee: result.journee ?? 0,
      rankingTeams,
      rankingWrites: result.rankingWrites ?? 0,
      matchesEnriched: result.matchesEnriched ?? 0,
      rankingEmpty: rankingTeams === 0,
      rankingBlocked,
      warning,
    };
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error('syncFffDataManual', e);
    throw new HttpsError(
      'internal',
      `Sync FFF échouée : ${e?.message || String(e)}`,
    );
  }
});

/**
 * Vérifie que l’API FFF répond pour la config saison (admin).
 * Ignore betweenSeasons / fffSyncEnabled — test pur de l’API + ids.
 * OK si les matchs répondent, même si le classement est vide (pré-saison).
 */
exports.testFffSeasonConfig = onCall(
  { cors: true, region: 'europe-west1' },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  try {
    const cfg = await _loadFffSeasonConfig(db);
    const matchesUrl =
      `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/matchs?journee=1`;
    const rankingUrl =
      `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/classement_journees`;

    const [matches, ranking] = await Promise.all([
      _fffFetchJson(matchesUrl),
      _fffFetchJson(rankingUrl),
    ]);

    const matchMembers = matches.data?.['hydra:member'] ?? [];
    const matchTotal = matches.data?.['hydra:totalItems'] ?? matchMembers.length;
    const rankingMembers = ranking.data?.['hydra:member'] ?? [];
    const rankingTotal =
      ranking.data?.['hydra:totalItems'] ?? rankingMembers.length;

    const matchesOk = matches.ok;
    const rankingOk = ranking.ok;
    // Pré-saison / WAF : classement 403 ou vide — OK si les matchs répondent.
    const ok = matchesOk;

    let message;
    if (!matchesOk && !rankingOk) {
      message =
        `API FFF inaccessible — matchs HTTP ${matches.status}, classement HTTP ${ranking.status}` +
        (matches.parseError ? ` (${matches.parseError.slice(0, 80)})` : '');
    } else if (!matchesOk) {
      message =
        matches.parseError ||
        `Matchs HTTP ${matches.status} (${matchesUrl})`;
    } else if (!rankingOk) {
      message =
        `API OK — ${matchTotal} match(s) ; classement bloqué HTTP ${ranking.status} (pré-saison / WAF)`;
    } else if (matchTotal === 0 && rankingTotal === 0) {
      message =
        'API OK mais aucun match ni classement (vérifier competitionId / phase / poule)';
    } else if (rankingTotal === 0) {
      message =
        `API OK — ${matchTotal} match(s), classement vide (pré-saison)`;
    } else {
      message =
        `API OK — ${rankingTotal} équipe(s) au classement, ${matchTotal} match(s)`;
    }

    return {
      ok,
      seasonLabel: cfg.seasonLabel,
      competitionDisplayName: cfg.competitionDisplayName,
      competitionId: cfg.cp,
      phaseId: cfg.ph,
      pouleId: cfg.gp,
      teamCount: rankingMembers.length,
      rankingTotal,
      matchCount: matchMembers.length,
      matchTotal,
      rankingEmpty: rankingOk && rankingTotal === 0,
      rankingBlocked: matchesOk && !rankingOk,
      matchesStatus: matches.status,
      rankingStatus: ranking.status,
      matchesUrl,
      rankingUrl,
      url: rankingUrl,
      message,
      warning: matchesOk && !rankingOk
        ? `Classement FFF inaccessible (HTTP ${ranking.status}) — matchs OK.`
        : null,
    };
  } catch (e) {
    console.error('testFffSeasonConfig', e);
    throw new HttpsError(
      'failed-precondition',
      `Test FFF échoué : ${e?.message || String(e)}`,
    );
  }
});

/**
 * Copie le classement club (`ranking`) vers `ranking_archive/{seasonLabel}`
 * (snapshot : rows[] + leagueLabel). Ne supprime pas `ranking`.
 * Admin uniquement — avant changement d’ids FFF / nouvelle saison.
 */
exports.archiveClubRankingSeason = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const cfg = await _loadFffSeasonConfig(db);
  const raw = request.data && request.data.seasonLabel;
  const seasonLabel = (raw && String(raw).trim()) || cfg.seasonLabel;

  const archRef = db.collection('ranking_archive').doc(seasonLabel);
  const existing = await archRef.get();
  if (existing.exists) {
    throw new HttpsError(
      'already-exists',
      `Une archive existe déjà pour « ${seasonLabel} »`,
    );
  }

  const rankingSnap = await db.collection('ranking').get();
  const rows = [];
  for (const doc of rankingSnap.docs) {
    const d = doc.data() || {};
    rows.push({
      position: d.position ?? 0,
      team: d.team ?? '',
      logo: d.logo ?? null,
      mj: d.mj ?? 0,
      v: d.v ?? 0,
      n: d.n ?? 0,
      d: d.d ?? 0,
      bf: d.bf ?? 0,
      bc: d.bc ?? 0,
      pts: d.pts ?? 0,
      forme: d.forme ?? '',
    });
  }
  rows.sort((a, b) => (a.position || 999) - (b.position || 999));

  await archRef.set({
    seasonLabel,
    leagueLabel: cfg.competitionDisplayName,
    archivedAt: Timestamp.now(),
    rows,
  });

  return { ok: true, seasonLabel, teamCount: rows.length };
});

/**
 * Remet le classement club (`ranking`) à 0 pts / 0 matchs pour chaque équipe.
 * Conserve équipe, logo, position, saison. La prochaine sync FFF (`_syncClassement`)
 * réécrit le vrai classement depuis l’API (overwrite + purge des lignes orphelines).
 * Admin uniquement — typiquement après archivage / avant nouvelle saison.
 */
exports.resetClubRankingToZero = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }

  const cfg = await _loadFffSeasonConfig(db);
  const rankingSnap = await db.collection('ranking').get();
  if (rankingSnap.empty) {
    return { ok: true, teamCount: 0, seasonLabel: cfg.seasonLabel };
  }

  const batch = db.batch();
  const now = Timestamp.now();
  for (const doc of rankingSnap.docs) {
    const d = doc.data() || {};
    batch.set(doc.ref, {
      season: d.season || cfg.seasonLabel,
      position: d.position ?? 0,
      team: d.team ?? '',
      logo: d.logo ?? null,
      mj: 0,
      v: 0,
      n: 0,
      d: 0,
      bf: 0,
      bc: 0,
      pts: 0,
      forme: '',
      journee: 0,
      updatedAt: now,
      rankingSource: 'reset_zero',
    });
  }
  await batch.commit();

  await db.collection('competition').doc('meta').set({
    journee: 0,
    rankingTeamCount: rankingSnap.size,
    rankingSource: 'reset_zero',
    rankingResetAt: now,
  }, { merge: true });

  console.log(`Classement remis à 0 : ${rankingSnap.size} équipe(s)`);
  return { ok: true, teamCount: rankingSnap.size, seasonLabel: cfg.seasonLabel };
});

// ── Supprime les documents matches sans fffId (données mock) ─────────────────
// Préserve les matchs avec manual:true (ajoutés depuis l'admin panel)
async function _cleanMockMatches(db) {
  const snap = await db.collection('matches').get();
  const batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (!data.fffId && !data.manual) {
      batch.delete(doc.ref);
      count++;
    }
  }
  if (count > 0) {
    await batch.commit();
    console.log(`Mock supprimés : ${count}`);
  }
}

// Fenêtre Firestore pour les matchs : passés récents (scores) + à venir (calendrier).
const FFF_SYNC_PAST_DAYS = 21;
const FFF_SYNC_FUTURE_DAYS = 120;
const FFF_RANK_ENRICH_FUTURE_DAYS = 60;

/** Lit tout le classement FFF (pagination Hydra) et ne garde que la dernière journée. */
async function _fetchFffClassementLatestMembers(cfg) {
  let url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/classement_journees`;
  const all = [];
  while (url) {
    let fetched;
    try {
      fetched = await _fffFetchJson(url);
    } catch (e) {
      console.error('Classement parse', e.message);
      return { members: [], lastJournee: 0, httpError: e.message };
    }
    if (!fetched.ok) {
      console.error(
        'Classement HTTP',
        fetched.status,
        url,
        fetched.parseError || '',
      );
      return {
        members: [],
        lastJournee: 0,
        httpError: fetched.parseError || fetched.status,
      };
    }
    all.push(...(fetched.data?.['hydra:member'] ?? []));
    const next = fetched.data?.['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }
  if (!all.length) return { members: [], lastJournee: 0 };

  let lastJournee = 0;
  for (const entry of all) {
    const j = entry.cj_no ?? 0;
    if (j > lastJournee) lastJournee = j;
  }
  const members = lastJournee > 0
    ? all.filter((e) => (e.cj_no ?? 0) === lastJournee)
    : all;
  return { members, lastJournee };
}

function _matchBelongsToFffSeason(data, seasonLabel) {
  const fs = (data.fffSeason ?? '').toString().trim();
  if (fs) return fs === seasonLabel;
  return true;
}

// ── Sync classement FFF → collection "ranking" ────────────────────────────────
async function _syncClassement(db) {
  const cfg = await _loadFffSeasonConfig(db);
  const { members, lastJournee, httpError } = await _fetchFffClassementLatestMembers(cfg);
  if (httpError) {
    return { journee: 0, rankingTeams: 0, rankingWrites: 0, matchesEnriched: 0, error: httpError };
  }
  if (!members.length) {
    console.warn('Classement FFF vide');
    return { journee: 0, rankingTeams: 0, rankingWrites: 0, matchesEnriched: 0 };
  }

  const existingSnap = await db.collection('ranking').get();
  const existingById = new Map(existingSnap.docs.map((d) => [d.id, d]));

  const batch = db.batch();
  let rankingWrites = 0;

  for (const entry of members) {
    const teamName = entry.equipe?.short_name ?? entry.equipe?.nom ?? '';
    const mj       = entry.total_games_count ?? 0;

    const docId = `pos_${entry.rank}`;
    const row = {
      season:    cfg.seasonLabel,
      position:  entry.rank ?? 0,
      team:      teamName,
      logo:      entry.equipe?.club?.logo ?? entry.equipe?.logo ?? null,
      mj,
      v:         entry.won_games_count  ?? 0,
      n:         entry.draw_games_count ?? 0,
      d:         entry.lost_games_count ?? 0,
      bf:        entry.goals_for_count     ?? 0,
      bc:        entry.goals_against_count ?? 0,
      pts:       entry.point_count ?? 0,
      forme:     entry.forme ?? '',
      journee:   entry.cj_no ?? lastJournee,
    };

    const prev = existingById.get(docId)?.data();
    if (prev && _rankingRowEquals(prev, row)) {
      existingById.delete(docId);
      continue;
    }

    batch.set(db.collection('ranking').doc(docId), {
      ...row,
      updatedAt: Timestamp.now(),
    });
    existingById.delete(docId);
    rankingWrites += 1;
  }

  for (const leftover of existingById.values()) {
    batch.delete(leftover.ref);
    rankingWrites += 1;
  }

  if (rankingWrites > 0) await batch.commit();

  const metaRef = db.collection('competition').doc('meta');
  await metaRef.set({
    journee: lastJournee,
    fffSyncedAt: Timestamp.now(),
    rankingTeamCount: members.length,
    rankingSource: 'fff_classement_journees',
  }, { merge: true });

  console.log(`Classement : ${members.length} équipes, J${lastJournee}, ${rankingWrites} écriture(s)`);

  // ── Enrichit les matchs avec rank depuis le classement ────────────────────
  const rankByTeam = {};
  for (const entry of members) {
    const shortName = (entry.equipe?.short_name ?? '').trim().toUpperCase();
    const fullName  = (entry.equipe?.nom ?? '').trim().toUpperCase();
    const abbr      = (entry.equipe?.abbreviation ?? '').trim().toUpperCase();
    const val = {
      rank: String(entry.rank ?? ''),
      form: (entry.forme ?? '').toUpperCase(),
    };
    if (shortName) rankByTeam[shortName] = val;
    if (fullName && fullName !== shortName) rankByTeam[fullName] = val;
    if (abbr && abbr !== shortName) rankByTeam[abbr] = val;
  }

  function findRank(teamName) {
    const t = teamName.trim().toUpperCase();
    if (!t) return null;
    if (rankByTeam[t]) return rankByTeam[t];
    for (const [key, val] of Object.entries(rankByTeam)) {
      if (t.includes(key) || key.includes(t)) return val;
    }
    const tWords = t.split(/[\s\-\.]+/).filter(w => w.length > 3);
    for (const [key, val] of Object.entries(rankByTeam)) {
      const kWords = key.split(/[\s\-\.]+/).filter(w => w.length > 3);
      if (tWords.some(w => kWords.includes(w))) return val;
    }
    return null;
  }

  const matchesSnap = await db.collection('matches').get();

  const nowMs = Date.now();
  const enrichPastMs = nowMs - FFF_SYNC_PAST_DAYS * 86400000;
  const enrichUntilMs = nowMs + FFF_RANK_ENRICH_FUTURE_DAYS * 86400000;
  const matchBatch = db.batch();
  let enriched = 0;
  let enrichSkipped = 0;
  for (const doc of matchesSnap.docs) {
    const d = doc.data();
    if (!_matchBelongsToFffSeason(d, cfg.seasonLabel)) {
      enrichSkipped += 1;
      continue;
    }
    const matchMs = d.date?.toMillis?.() ?? 0;
    if (matchMs < enrichPastMs || matchMs > enrichUntilMs) {
      enrichSkipped += 1;
      continue;
    }
    const status = d.status ?? 'upcoming';
    if (status !== 'upcoming' && status !== 'finished') {
      enrichSkipped += 1;
      continue;
    }
    const r1 = findRank(d.team1 ?? '');
    const r2 = findRank(d.team2 ?? '');
    if (!r1 && !r2) continue;
    const update = {};
    if (r1 && (d.rank1 !== r1.rank || d.form1 !== r1.form)) {
      update.rank1 = r1.rank;
      update.form1 = r1.form;
    }
    if (r2 && (d.rank2 !== r2.rank || d.form2 !== r2.form)) {
      update.rank2 = r2.rank;
      update.form2 = r2.form;
    }
    if (Object.keys(update).length === 0) {
      enrichSkipped += 1;
      continue;
    }
    matchBatch.update(doc.ref, update);
    enriched += 1;
  }
  if (enriched > 0) await matchBatch.commit();
  console.log(
    `Matchs enrichis rank/form : ${enriched} écrit(s), ${enrichSkipped} ignoré(s)`,
  );

  return {
    journee: lastJournee,
    rankingTeams: members.length,
    rankingWrites,
    matchesEnriched: enriched,
  };
}

// ── Sync matchs FFF → collection "matches" (lecture API complète, écritures ciblées) ─
async function _syncMatches(db) {
  const cfg = await _loadFffSeasonConfig(db);
  const seenIds = new Set();
  const stats = { written: 0, newDoc: 0, updated: 0, unchanged: 0, frozen: 0, manual: 0 };

  let url =
    `${FFF_BASE}/compets/${cfg.cp}/phases/${cfg.ph}/poules/${cfg.gp}/matchs?journee=1`;

  while (url) {
    let fetched;
    try {
      fetched = await _fffFetchJson(url);
    } catch (e) {
      console.error('Matchs parse', e.message);
      break;
    }
    if (!fetched.ok) {
      console.error(
        'Matchs HTTP',
        fetched.status,
        url,
        fetched.parseError || '',
      );
      break;
    }

    for (const m of fetched.data?.['hydra:member'] ?? []) {
      const r = await _writeMatch(db, m, seenIds, cfg);
      if (r.written) stats.written += 1;
      if (r.reason === 'new') stats.newDoc += 1;
      if (r.reason === 'updated') stats.updated += 1;
      if (r.reason === 'unchanged') stats.unchanged += 1;
      if (r.reason === 'frozen') stats.frozen += 1;
      if (r.reason === 'manual') stats.manual += 1;
    }

    const next = fetched.data?.['hydra:view']?.['hydra:next'];
    url = next ? `${FFF_HOST}${next}` : null;
  }

  console.log(
    `FFF matchs : ${stats.written} écrit(s) (${stats.newDoc} nouveau(x), ${stats.updated} modif(s)), ` +
    `${stats.unchanged} inchangé(s), ${stats.frozen} ancien(s) gelé(s), ${stats.manual} manuel(s)`,
  );
}

/** Extrait stade + ville depuis un match API DOFA (champs variables). */
function _extractVenueFromFffMatch(match) {
  const m = match || {};
  const homeClub = m.home?.club || m.home?.equipe?.club || {};
  const terrain = m.terrain || m.stade || m.venue || {};
  const pick = (...vals) => {
    for (const v of vals) {
      if (v == null) continue;
      if (typeof v === 'object') {
        const nested =
          v.nom || v.name || v.libelle || v.label || v.short_name || '';
        if (String(nested).trim()) return String(nested).trim();
        continue;
      }
      const s = String(v).trim();
      if (s) return s;
    }
    return '';
  };
  const lieu = pick(
    m.lieu,
    m.stadium,
    m.stadiumName,
    m.terrain_nom,
    terrain,
    terrain.nom,
    terrain.name,
    homeClub.stade,
    homeClub.stadium,
    homeClub.terrain,
    homeClub.venue,
  );
  const ville = pick(
    m.ville,
    m.city,
    m.town,
    m.commune,
    terrain.ville,
    terrain.city,
    terrain.commune,
    homeClub.ville,
    homeClub.city,
    homeClub.town,
    homeClub.commune,
    homeClub.localite,
  );
  return { lieu, ville };
}

/** Données match normalisées pour comparer API ↔ Firestore (sans updatedAt). */
function _fffMatchFieldsFromApi(match, cfg) {
  const homeTeam = match.home?.short_name ?? '';
  const awayTeam = match.away?.short_name ?? '';
  const dateStr = match.date;
  if (!dateStr || !homeTeam || !awayTeam) return null;

  const matchDate = _parseMatchDate(dateStr, match.time);
  const score1 = _parseScore(match.home_score);
  const score2 = _parseScore(match.away_score);
  const isFinished = score1 !== null && score2 !== null;
  const isPast = matchDate < new Date();
  const { lieu, ville } = _extractVenueFromFffMatch(match);

  return {
    team1: homeTeam,
    team2: awayTeam,
    logo1: match.home?.club?.logo ?? null,
    logo2: match.away?.club?.logo ?? null,
    score1,
    score2,
    dateMs: matchDate.getTime(),
    competition: cfg.competitionDisplayName,
    status: isFinished || isPast ? 'finished' : 'upcoming',
    fffId: String(match.ma_no),
    fffSeason: cfg.seasonLabel,
    lieu,
    ville,
  };
}

function _fffMatchFieldsFromDoc(data) {
  const dateMs = data.date?.toMillis?.() ?? 0;
  return {
    team1: data.team1 ?? '',
    team2: data.team2 ?? '',
    logo1: data.logo1 ?? null,
    logo2: data.logo2 ?? null,
    score1: data.score1 ?? null,
    score2: data.score2 ?? null,
    dateMs,
    competition: data.competition ?? '',
    status: data.status ?? 'upcoming',
    fffId: String(data.fffId ?? ''),
    fffSeason: data.fffSeason ?? '',
    lieu: data.lieu ?? data.stadium ?? '',
    ville: data.ville ?? data.city ?? '',
  };
}

function _fffMatchFieldsEqual(a, b) {
  if (!a || !b) return false;
  return (
    a.team1 === b.team1 &&
    a.team2 === b.team2 &&
    a.logo1 === b.logo1 &&
    a.logo2 === b.logo2 &&
    a.score1 === b.score1 &&
    a.score2 === b.score2 &&
    a.dateMs === b.dateMs &&
    a.competition === b.competition &&
    a.status === b.status &&
    a.fffId === b.fffId &&
    a.fffSeason === b.fffSeason &&
    (a.lieu || '') === (b.lieu || '') &&
    (a.ville || '') === (b.ville || '')
  );
}

function _isInFffMatchSyncWindow(dateMs, nowMs = Date.now()) {
  const past = nowMs - FFF_SYNC_PAST_DAYS * 86400000;
  const future = nowMs + FFF_SYNC_FUTURE_DAYS * 86400000;
  return dateMs >= past && dateMs <= future;
}

function _rankingRowEquals(prev, row) {
  return (
    (prev.position ?? 0) === (row.position ?? 0) &&
    (prev.team ?? '') === (row.team ?? '') &&
    (prev.logo ?? null) === (row.logo ?? null) &&
    (prev.mj ?? 0) === (row.mj ?? 0) &&
    (prev.v ?? 0) === (row.v ?? 0) &&
    (prev.n ?? 0) === (row.n ?? 0) &&
    (prev.d ?? 0) === (row.d ?? 0) &&
    (prev.bf ?? 0) === (row.bf ?? 0) &&
    (prev.bc ?? 0) === (row.bc ?? 0) &&
    (prev.pts ?? 0) === (row.pts ?? 0) &&
    (prev.forme ?? '') === (row.forme ?? '') &&
    (prev.season ?? '') === (row.season ?? '')
  );
}

async function _writeMatch(db, match, seenIds, cfg) {
  const fffId = match.ma_no;
  if (!fffId || seenIds.has(fffId)) {
    return { written: false, reason: 'duplicate' };
  }
  seenIds.add(fffId);

  const fields = _fffMatchFieldsFromApi(match, cfg);
  if (!fields) return { written: false, reason: 'invalid' };

  const docId = `${cfg.matchDocIdPrefix}${fffId}`;
  const ref = db.collection('matches').doc(docId);
  const existing = await ref.get();
  if (existing.exists && existing.data()?.manual === true) {
    return { written: false, reason: 'manual' };
  }

  const prevFields = existing.exists ? _fffMatchFieldsFromDoc(existing.data()) : null;
  const nowMs = Date.now();

  if (prevFields && _fffMatchFieldsEqual(prevFields, fields)) {
    if (!_isInFffMatchSyncWindow(fields.dateMs, nowMs)) {
      return { written: false, reason: 'frozen' };
    }
    return { written: false, reason: 'unchanged' };
  }

  if (
    prevFields &&
    !_isInFffMatchSyncWindow(fields.dateMs, nowMs) &&
    fields.status === 'finished' &&
    prevFields.status === 'finished'
  ) {
    return { written: false, reason: 'frozen' };
  }

  await ref.set({
    team1: fields.team1,
    team2: fields.team2,
    logo1: fields.logo1,
    logo2: fields.logo2,
    score1: fields.score1,
    score2: fields.score2,
    date: Timestamp.fromMillis(fields.dateMs),
    competition: fields.competition,
    status: fields.status,
    fffId: fields.fffId,
    fffSeason: fields.fffSeason,
    ...(fields.lieu ? { lieu: fields.lieu, stadium: fields.lieu } : {}),
    ...(fields.ville ? { ville: fields.ville, city: fields.ville } : {}),
    updatedAt: Timestamp.now(),
  }, { merge: true });

  return { written: true, reason: prevFields ? 'updated' : 'new' };
}

// "2025-08-24" ou "2025-08-24T00:00:00+00:00" + "16H00" → Date (jour civil Europe/Paris)
function _parseMatchDate(dateStr, timeStr) {
  const parts = String(dateStr ?? '').match(/(\d{4})-(\d{2})-(\d{2})/);
  if (!parts) {
    return new Date(dateStr);
  }
  const y = parseInt(parts[1], 10);
  const mo = parseInt(parts[2], 10) - 1;
  const day = parseInt(parts[3], 10);
  let h = 15;
  let min = 0;
  if (timeStr) {
    const tm = String(timeStr).match(/(\d+)H(\d+)/i);
    if (tm) {
      h = parseInt(tm[1], 10);
      min = parseInt(tm[2], 10);
    }
  }
  const probe = new Date(Date.UTC(y, mo, day, 12, 0, 0));
  const offset = _getParisOffsetHours(probe);
  return new Date(Date.UTC(y, mo, day, h - offset, min, 0, 0));
}

function _getParisOffsetHours(date) {
  const year = date.getUTCFullYear();
  // Dernier dimanche de mars à 1h UTC (= 2h CET → passage en CEST)
  const marchLast = new Date(Date.UTC(year, 2, 31));
  while (marchLast.getUTCDay() !== 0) marchLast.setUTCDate(marchLast.getUTCDate() - 1);
  marchLast.setUTCHours(1, 0, 0, 0);
  // Dernier dimanche d'octobre à 1h UTC (= 3h CEST → passage en CET)
  const octLast = new Date(Date.UTC(year, 9, 31));
  while (octLast.getUTCDay() !== 0) octLast.setUTCDate(octLast.getUTCDate() - 1);
  octLast.setUTCHours(1, 0, 0, 0);
  return (date >= marchLast && date < octLast) ? 2 : 1;
}

function _parseScore(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseInt(raw);
  return isNaN(n) ? null : n;
}

function _isSedanCssaReminderMatch(m) {
  const t1 = String(m.team1 || '').toUpperCase();
  const t2 = String(m.team2 || '').toUpperCase();
  return t1.includes('SEDAN') || t1.includes('CSSA') ||
         t2.includes('SEDAN') || t2.includes('CSSA');
}

function _defaultMatchReminderTitle() {
  return '⚽ Match Sedan';
}

function _defaultMatchReminderBody(m) {
  const a = m.team1 || '?';
  const b = m.team2 || '?';
  return `${a} vs ${b} — même rendez-vous que sur l’accueil.`;
}
