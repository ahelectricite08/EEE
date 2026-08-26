/// Barème XP du module Pronos, tel que le serveur l'applique réellement.
///
/// L'XP n'est jamais créditée par le client : elle l'est par `awardXp`
/// (Cloud Functions), qui lit `app_settings/xp_config` — le document que
/// l'administrateur pilote depuis Admin → XP. Ce modèle est le miroir de
/// lecture de ce document pour l'UI : annoncer un barème en dur ferait mentir
/// l'app dès la première modification côté admin.
///
/// Le parsing reproduit `_eventXpFromConfig` (functions/lib/xp_core.js) :
/// une valeur numérique brute est prise telle quelle, une entrée `{xp, enabled}`
/// vaut 0 si elle est désactivée, et tout le reste retombe sur [defaults] —
/// qui doit rester aligné sur `DEFAULT_XP`.
class PronoXpScale {
  /// `prono_correct` — score exact (3 points de classement).
  final int exactScore;

  /// `prono_good_result` — bon résultat 1-N-2 (1 point de classement).
  final int goodResult;

  /// `lineup_xi_perfect` — 11 bons joueurs.
  final int xiPerfect;

  /// `lineup_xi_ten` — 10 bons joueurs.
  final int xiTen;

  /// `lineup_xi_nine` — 9 bons joueurs.
  final int xiNine;

  /// `lineup_xi_played` — moins de 9, lot de participation.
  final int xiPlayed;

  const PronoXpScale({
    required this.exactScore,
    required this.goodResult,
    required this.xiPerfect,
    required this.xiTen,
    required this.xiNine,
    required this.xiPlayed,
  });

  /// Repli lorsque `app_settings/xp_config` est absent, vide ou illisible.
  static const PronoXpScale defaults = PronoXpScale(
    exactScore: 20,
    goodResult: 8,
    xiPerfect: 10,
    xiTen: 6,
    xiNine: 3,
    xiPlayed: 1,
  );

  factory PronoXpScale.fromConfigDoc(Map<String, dynamic>? doc) {
    final events = (doc?['events'] as Map?)?.cast<String, dynamic>();
    if (events == null || events.isEmpty) return defaults;

    int read(String key, int fallback) {
      final raw = events[key];
      if (raw is num) return raw.toInt();
      if (raw is Map) {
        if (raw['enabled'] == false) return 0;
        final xp = raw['xp'];
        if (xp is num) return xp.toInt();
      }
      return fallback;
    }

    return PronoXpScale(
      exactScore: read('prono_correct', defaults.exactScore),
      goodResult: read('prono_good_result', defaults.goodResult),
      xiPerfect: read('lineup_xi_perfect', defaults.xiPerfect),
      xiTen: read('lineup_xi_ten', defaults.xiTen),
      xiNine: read('lineup_xi_nine', defaults.xiNine),
      xiPlayed: read('lineup_xi_played', defaults.xiPlayed),
    );
  }

  /// Même découpage en paliers que `_lineupPredXpEvent`.
  int forXiMatched(int matched) {
    if (matched >= 11) return xiPerfect;
    if (matched >= 10) return xiTen;
    if (matched >= 9) return xiNine;
    return xiPlayed;
  }

  /// Un prono raté ne déclenche aucun événement XP côté serveur : c'est bien 0,
  /// et non une valeur configurable.
  int forPronoPoints(int points) => switch (points) {
        3 => exactScore,
        1 => goodResult,
        _ => 0,
      };
}
