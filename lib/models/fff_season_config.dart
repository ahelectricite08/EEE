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

  /// `false` = plus d’appels API FFF (cron ni manuel sans force côté Functions).
  final bool fffSyncEnabled;

  const FffSeasonConfig({
    required this.fffCompetitionId,
    required this.fffPhaseId,
    required this.fffPouleId,
    required this.fffClubNo,
    required this.seasonLabel,
    required this.competitionDisplayName,
    required this.matchDocIdPrefix,
    this.fffSyncEnabled = true,
  });

  static const FffSeasonConfig defaults = FffSeasonConfig(
    fffCompetitionId: 436257,
    fffPhaseId: 1,
    fffPouleId: 1,
    fffClubNo: 500266,
    seasonLabel: '2025-2026',
    competitionDisplayName: 'Régional 1',
    matchDocIdPrefix: 'fff_',
    fffSyncEnabled: true,
  );

  FffSeasonConfig copyWith({
    int? fffCompetitionId,
    int? fffPhaseId,
    int? fffPouleId,
    int? fffClubNo,
    String? seasonLabel,
    String? competitionDisplayName,
    String? matchDocIdPrefix,
    bool? fffSyncEnabled,
  }) {
    return FffSeasonConfig(
      fffCompetitionId: fffCompetitionId ?? this.fffCompetitionId,
      fffPhaseId: fffPhaseId ?? this.fffPhaseId,
      fffPouleId: fffPouleId ?? this.fffPouleId,
      fffClubNo: fffClubNo ?? this.fffClubNo,
      seasonLabel: seasonLabel ?? this.seasonLabel,
      competitionDisplayName:
          competitionDisplayName ?? this.competitionDisplayName,
      matchDocIdPrefix: matchDocIdPrefix ?? this.matchDocIdPrefix,
      fffSyncEnabled: fffSyncEnabled ?? this.fffSyncEnabled,
    );
  }

  /// Matchs sans champ `fffSeason` (pré-sync FFF / import) : même libellé que [defaults.seasonLabel]
  /// pour éviter deux constantes à maintenir. Quand tu changes la saison par défaut dans le code,
  /// le « bac » legacy suit.
  static String get implicitLegacySeasonLabel => defaults.seasonLabel;

  /// Filtre app / admin : un doc `matches` appartient à [seasonLabel] ?
  static bool matchDocBelongsToSeason(
    Map<String, dynamic> data,
    String seasonLabel, {
    String? activeSeasonLabel,
  }) {
    final fs = data['fffSeason'] as String?;
    if (fs != null && fs.trim().isNotEmpty) {
      return fs.trim() == seasonLabel;
    }
    if (data['manual'] == true &&
        activeSeasonLabel != null &&
        activeSeasonLabel.trim().isNotEmpty &&
        seasonLabel.trim() == activeSeasonLabel.trim()) {
      return true;
    }
    final ts = data['date'];
    if (ts is Timestamp &&
        activeSeasonLabel != null &&
        seasonLabel.trim() == activeSeasonLabel.trim() &&
        dateInSeason(ts.toDate(), seasonLabel)) {
      return true;
    }
    return seasonLabel == implicitLegacySeasonLabel;
  }

  /// Saison foot FR : juillet [année1] → fin juin [année2] (ex. « 2025-2026 »).
  static bool dateInSeason(DateTime date, String seasonLabel) {
    final years = parseSeasonYears(seasonLabel);
    if (years == null) return false;
    final start = DateTime(years.$1, 7, 1);
    final end = DateTime(years.$2, 7, 1);
    return !date.isBefore(start) && date.isBefore(end);
  }

  static (int, int)? parseSeasonYears(String seasonLabel) {
    final nums = RegExp(r'\d{4}')
        .allMatches(seasonLabel)
        .map((m) => int.tryParse(m.group(0) ?? ''))
        .whereType<int>()
        .toList();
    if (nums.length >= 2) return (nums[0], nums[1]);
    if (nums.length == 1) return (nums[0], nums[0] + 1);
    return null;
  }

  /// Saison en cours d’après la date (juillet → juin). Ex. 27 août 2026 → `2026-2027`.
  static String frenchFootballSeasonLabel([DateTime? at]) {
    final d = at ?? DateTime.now();
    final startYear = d.month >= 7 ? d.year : d.year - 1;
    return '$startYear-${startYear + 1}';
  }

  /// Saison affichée à l’arrivée sur le classement : calendrier FR, puis la plus récente
  /// de la liste (pas le premier item d’une archive ancienne type 2025-2026).
  static String arrivalSeason({
    required Iterable<String> available,
    String? configSeasonLabel,
    DateTime? now,
  }) {
    final calendar = frenchFootballSeasonLabel(now);
    final chips = available
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (chips.contains(calendar)) return calendar;

    String? latest;
    var latestYear = -1;
    for (final s in chips) {
      final y = parseSeasonYears(s)?.$1 ?? -1;
      if (y > latestYear) {
        latestYear = y;
        latest = s;
      }
    }
    if (latest != null) return latest;

    final cfg = configSeasonLabel?.trim();
    if (cfg != null && cfg.isNotEmpty) return cfg;
    return calendar;
  }

  /// Puces saison : saison calendaire + config FFF + archives, plus récente d’abord.
  static List<String> seasonChips(
    FffSeasonConfig cfg,
    Iterable<String> rankingArchiveDocIds, {
    DateTime? now,
  }) {
    final ids = <String>{
      frenchFootballSeasonLabel(now),
      cfg.seasonLabel.trim(),
      ...rankingArchiveDocIds.map((id) => id.trim()),
    }..removeWhere((id) => id.isEmpty);
    final list = ids.toList()
      ..sort((a, b) {
        final ya = parseSeasonYears(a)?.$1 ?? 0;
        final yb = parseSeasonYears(b)?.$1 ?? 0;
        if (ya != yb) return yb.compareTo(ya);
        return b.compareTo(a);
      });
    return list;
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

    bool b(String key, bool def) {
      final v = d[key];
      if (v is bool) return v;
      return def;
    }

    return FffSeasonConfig(
      fffCompetitionId: n('fffCompetitionId', defaults.fffCompetitionId),
      fffPhaseId: n('fffPhaseId', defaults.fffPhaseId),
      fffPouleId: n('fffPouleId', defaults.fffPouleId),
      fffClubNo: n('fffClubNo', defaults.fffClubNo),
      seasonLabel: s('seasonLabel', defaults.seasonLabel),
      competitionDisplayName:
          s('competitionDisplayName', defaults.competitionDisplayName),
      matchDocIdPrefix: prefix,
      fffSyncEnabled: b('fffSyncEnabled', defaults.fffSyncEnabled),
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
      'fffSyncEnabled': fffSyncEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String matchDocumentId(String fffMaNo) => '$matchDocIdPrefix$fffMaNo';
}
