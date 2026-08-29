const { getFirestore } = require('firebase-admin/firestore');

const FFF_BASE  = 'https://api-dofa.fff.fr/api';
const FFF_HOST  = 'https://api-dofa.fff.fr';  // pour les liens hydra:next
const FFF_CP    = 436257;  // Régional 1 Homiris Grand Est 2025-2026
const FFF_PH    = 1;
const FFF_GP    = 1;       // Poule A (CSSA's group)
const FFF_CLUB  = 500266;  // CS Sedan Ardennes

const FFF_CONFIG_DOC = 'fff_season';
const FFF_LIFECYCLE_DOC = 'season_lifecycle';

async function _loadFffSeasonConfig(db) {
  const snap = await db.collection('app_config').doc(FFF_CONFIG_DOC).get();
  const d = snap.data() || {};
  const cp = Number(d.fffCompetitionId) || FFF_CP;
  const ph = Number(d.fffPhaseId) || FFF_PH;
  const gp = Number(d.fffPouleId) || FFF_GP;
  const clubNo = Number(d.fffClubNo) || FFF_CLUB;
  const seasonLabel =
    (d.seasonLabel && String(d.seasonLabel).trim()) || '2025-2026';
  const competitionDisplayName =
    (d.competitionDisplayName && String(d.competitionDisplayName).trim()) ||
    'Régional 1';
  let prefix =
    (d.matchDocIdPrefix && String(d.matchDocIdPrefix).trim()) || 'fff_';
  if (!prefix.endsWith('_')) prefix = `${prefix}_`;
  // R2 / réserve : ranking_r2 + calendrier matches_r2. 0 = pas branché.
  // 2025-2026 Grand Est R2 : 436258. 2026-2027 : 449972 (Poule A = 1).
  const r2Cp = Number(d.fffR2CompetitionId) || 0;
  const r2Ph = Number(d.fffR2PhaseId) || 1;
  const r2Gp = Number(d.fffR2PouleId) || 1;
  let r2CompetitionDisplayName =
    (d.r2CompetitionDisplayName && String(d.r2CompetitionDisplayName).trim()) ||
    'Régional 2';
  if (/^r2$/i.test(r2CompetitionDisplayName) || /cs sedan/i.test(r2CompetitionDisplayName)) {
    r2CompetitionDisplayName = 'Régional 2';
  }
  return {
    cp,
    ph,
    gp,
    clubNo,
    seasonLabel,
    competitionDisplayName,
    matchDocIdPrefix: prefix,
    fffSyncEnabled: d.fffSyncEnabled !== false,
    r2Cp,
    r2Ph,
    r2Gp,
    r2CompetitionDisplayName,
  };
}

module.exports = {
  FFF_BASE,
  FFF_HOST,
  FFF_CP,
  FFF_PH,
  FFF_GP,
  FFF_CLUB,
  FFF_CONFIG_DOC,
  FFF_LIFECYCLE_DOC,
  _loadFffSeasonConfig,
};
