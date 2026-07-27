/// Actions sensibles du panel admin (RBAC granulaire).
enum AdminAction {
  /// Attribuer rôles staff (admin, CM, éditeur, stats).
  assignStaffRoles,
  /// Attribuer rôles communauté (supporter, team_dvcr).
  assignCommunityRoles,
  /// Supprimer compte Firebase (Auth + profil).
  deleteFirebaseUser,
  /// Ajuster manuellement l'XP d'un membre.
  manualXpAdjust,
  /// Éditer la matrice RBAC (permissions par rôle).
  editRbacMatrix,
  /// Piloter le live (démarrer/arrêter, score, votes…).
  pilotLive,
  /// Push manuelles espace bénévoles.
  benevoleNotifs,
}
