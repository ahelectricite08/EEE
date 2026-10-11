const { getFirestore } = require('firebase-admin/firestore');

const FFF_BASE  = 'https://api-dofa.fff.fr/api';
const FFF_HOST  = 'https://api-dofa.fff.fr';  // pour les liens hydra:next
const FFF_CP    = 449966;  // Régional 1 Homiris Grand Est 2026-2027
const FFF_PH    = 1;
const FFF_GP    = 1;       // Poule A (CSSA's group)
const FFF_CLUB  = 500266;  // CS Sedan Ardennes
const FFF_R2_CP = 449972;  // Régional 2 Grand Est 2026-2027 (Poule A)

const FFF_CONFIG_DOC = 'fff_season';
const FFF_LIFECYCLE_DOC = 'season_lifecycle';

async function _loadFffSeasonConfig(db) {
  const snap = await db.collection('app_config').doc(FFF_CONFIG_DOC).get();
  const d = snap.data() || {};
  // 436257 / 436258 = saison 2025-2026 périmée : on bascule 2026-2027.
  let cp = Number(d.fffCompetitionId) || FFF_CP;
  if (cp === 436257) cp = FFF_CP;
  const ph = Number(d.fffPhaseId) || FFF_PH;
  const gp = Number(d.fffPouleId) || FFF_GP;
  const clubNo = Number(d.fffClubNo) || FFF_CLUB;
  const seasonLabel =
    (d.seasonLabel && String(d.seasonLabel).trim()) || '2026-2027';
  const competitionDisplayName =
    (d.competitionDisplayName && String(d.competitionDisplayName).trim()) ||
    'Régional 1';
  let prefix =
    (d.matchDocIdPrefix && String(d.matchDocIdPrefix).trim()) || 'fff_';
  if (!prefix.endsWith('_')) prefix = `${prefix}_`;
  // R2 / réserve : ranking_r2 + calendrier matches_r2 (Sedan uniquement).
  // 2025-2026 Grand Est R2 : 436258 (périmé). 2026-2027 : 449972 (Poule A = 1).
  const r2Raw = Number(d.fffR2CompetitionId);
  let r2Cp = Number.isFinite(r2Raw) && r2Raw > 0 ? r2Raw : FFF_R2_CP;
  if (r2Cp === 436258) r2Cp = FFF_R2_CP;
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
  FFF_R2_CP,
  FFF_CONFIG_DOC,
  FFF_LIFECYCLE_DOC,
  _loadFffSeasonConfig,
};
