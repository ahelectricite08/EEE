import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration FFF / saison lue depuis [app_config/fff_season].
/// Valeurs par défaut = comportement historique (R1 Grand Est 2025-2026).
class FffSeasonConfig {
  final int fffCompetitionId;
  final int fffPhaseId;
  final int fffPouleId;
  final int fffClubNo;
  final String seasonLabel;
  final String competitionDisplayName;
  /// Préfixe document Firestore match, ex. `fff_` → ids `fff_{ma_no}`.
  final String matchDocIdPrefix;

  const FffSeasonConfig({
    required this.fffCompetitionId,
    required this.fffPhaseId,
    required this.fffPouleId,
    required this.fffClubNo,
    required this.seasonLabel,
    required this.competitionDisplayName,
    required this.matchDocIdPrefix,
  });

  static const FffSeasonConfig defaults = FffSeasonConfig(
    fffCompetitionId: 436257,
    fffPhaseId: 1,
    fffPouleId: 1,
    fffClubNo: 500266,
    seasonLabel: '2025-2026',
    competitionDisplayName: 'Régional 1',
    matchDocIdPrefix: 'fff_',
  );

  /// Matchs sans champ `fffSeason` (pré-sync FFF / import) : même libellé que [defaults.seasonLabel]
  /// pour éviter deux constantes à maintenir. Quand tu changes la saison par défaut dans le code,
  /// le « bac » legacy suit.
  static String get implicitLegacySeasonLabel => defaults.seasonLabel;

  /// Filtre app / admin : un doc `matches` appartient à [seasonLabel] ?
  static bool matchDocBelongsToSeason(
    Map<String, dynamic> data,
    String seasonLabel,
  ) {
    final fs = data['fffSeason'] as String?;
    if (fs != null && fs.trim().isNotEmpty) {
      return fs.trim() == seasonLabel;
    }
    return seasonLabel == implicitLegacySeasonLabel;
  }

  /// Puces saison : active ([cfg]) + archives `ranking_archive`.
  static List<String> seasonChips(
    FffSeasonConfig cfg,
    Iterable<String> rankingArchiveDocIds,
  ) {
    final archived = rankingArchiveDocIds.toList()..sort();
    return [
      cfg.seasonLabel,
      ...archived.where((id) => id != cfg.seasonLabel),
    ];
  }

  factory FffSeasonConfig.fromFirestoreData(Map<String, dynamic>? d) {
    if (d == null || d.isEmpty) return defaults;
    int n(String key, int fallback) {
      final v = d[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    String s(String key, String fallback) {
      final v = d[key]?.toString().trim();
      return (v == null || v.isEmpty) ? fallback : v;
    }

    var prefix = s('matchDocIdPrefix', defaults.matchDocIdPrefix);
    if (!prefix.endsWith('_')) prefix = '${prefix}_';

    return FffSeasonConfig(
      fffCompetitionId: n('fffCompetitionId', defaults.fffCompetitionId),
      fffPhaseId: n('fffPhaseId', defaults.fffPhaseId),
      fffPouleId: n('fffPouleId', defaults.fffPouleId),
      fffClubNo: n('fffClubNo', defaults.fffClubNo),
      seasonLabel: s('seasonLabel', defaults.seasonLabel),
      competitionDisplayName:
          s('competitionDisplayName', defaults.competitionDisplayName),
      matchDocIdPrefix: prefix,
    );
  }

  factory FffSeasonConfig.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    return FffSeasonConfig.fromFirestoreData(snap.data());
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'fffCompetitionId': fffCompetitionId,
      'fffPhaseId': fffPhaseId,
      'fffPouleId': fffPouleId,
      'fffClubNo': fffClubNo,
      'seasonLabel': seasonLabel,
      'competitionDisplayName': competitionDisplayName,
      'matchDocIdPrefix': matchDocIdPrefix,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String matchDocumentId(String fffMaNo) => '$matchDocIdPrefix$fffMaNo';
}
