/// Correction opérateur (mauvais tap) — pas un fait de match (VAR / but refusé).
///
/// Type Firestore conservé : `goal_cancelled` (score, FCM, Live Activity).
/// Libellé opérateur : [uiLabel]. Public / push : [pushTitle] + [pushBody].
abstract final class LiveEntryError {
  static const type = 'goal_cancelled';

  static const uiLabel = 'ERREUR SAISIE';
  static const confirmTitle = 'Erreur de saisie ?';
  static const confirmYes = 'Oui, corriger';
  static const confirmNo = 'Non';

  static const pushTitle = 'OUPS.';
  static const pushBody = 'DVCR s\'est emmêlé les crayons. On corrige.';
  static const tickerLine = 'OUPS.';

  static const correctableTypes = {
    'goal',
    'yellow',
    'red',
    'substitution',
  };

  static bool canCorrect(String type) => correctableTypes.contains(type);
}
