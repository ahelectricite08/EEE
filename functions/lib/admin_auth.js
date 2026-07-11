const { HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');

function _isUserAdmin(userDoc) {
  if (!userDoc.exists) return false;
  const data = userDoc.data() || {};
  if (data.role === 'admin') return true;
  if (Array.isArray(data.roles) && data.roles.includes('admin')) return true;
  return false;
}

/** Callable admin : vérifie auth Firebase + rôle admin. */
async function _requireAdminCall(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_isUserAdmin(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  return { db, userDoc };
}

/** Types XP autorisés depuis le client (callable awardXp). Le reste = triggers serveur only. */
const CLIENT_AWARD_XP_EVENTS = new Set([
  'vote_prono',
  'chat_message',
  'article_read',
  'daily_login',
  'share_app',
  'match_comment',
  'emission_poll_vote',
  'motm_vote',
  'replay_watched',
  'profile_complete',
  'favorite_team_set',
]);

function _toSafeString(value) {
  if (value === null || value === undefined) return '';
  return value.toString().trim();
}

function _pickPrimaryRole(roles) {
  const priority = [
    'admin',
    'community_manager',
    'editor',
    'statisticien',
    'team_dvcr',
    'partenaire',
    'donateur',
    'supporter',
  ];
  return priority.find((role) => roles.includes(role)) || 'supporter';
}

function _isTeamDvcrUserData(userData) {
  if (!userData || typeof userData !== 'object') return false;
  if (Array.isArray(userData.roles)) {
    const roles = userData.roles
      .map((r) => String(r || '').trim().toLowerCase())
      .filter(Boolean);
    if (roles.includes('team_dvcr') || roles.includes('teamdvcr')) return true;
  }
  const role = String(userData.role || '').trim().toLowerCase();
  if (role === 'team_dvcr' || role === 'teamdvcr') return true;
  if (userData.dvcrTeamMember === true) return true;
  return false;
}

function _normalizeTargetUserIds(data) {
  const raw = data?.targetUserIds;
  if (!Array.isArray(raw)) return null;
  const ids = [...new Set(raw.map((id) => String(id || '').trim()).filter(Boolean))];
  return ids.length ? ids.slice(0, 500) : null;
}

module.exports = {
  _isUserAdmin,
  _requireAdminCall,
  CLIENT_AWARD_XP_EVENTS,
  _toSafeString,
  _pickPrimaryRole,
  _isTeamDvcrUserData,
  _normalizeTargetUserIds,
};
