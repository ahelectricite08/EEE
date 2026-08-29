import '../utils/youtube_parser.dart';

/// Saison d’adhésion foot FR : 1er juillet N → 30 juin N+1 (`2026-2027`).
abstract final class AdherentSeason {
  static final _id = RegExp(r'^(\d{4})-(\d{4})$');

  static String idFor(DateTime date) {
    final start = date.month >= 7 ? date.year : date.year - 1;
    return '$start-${start + 1}';
  }

  static String get currentId => idFor(DateTime.now());

  static bool isValidId(String raw) {
    final m = _id.firstMatch(raw.trim());
    if (m == null) return false;
    final a = int.parse(m.group(1)!);
    return int.parse(m.group(2)!) == a + 1;
  }

  static int _startYear(String id) {
    final m = _id.firstMatch(id.trim());
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  /// Plus récente d’abord.
  static int compareNewestFirst(String a, String b) =>
      _startYear(b).compareTo(_startYear(a));

  static List<String> suggestedIds({DateTime? now}) {
    final n = now ?? DateTime.now();
    final start = n.month >= 7 ? n.year : n.year - 1;
    return [
      for (var i = -2; i <= 4; i++) '${start + i}-${start + i + 1}',
    ];
  }
}

class AdherentVodSeason {
  final String id;
  final String playlistId;

  const AdherentVodSeason({
    required this.id,
    this.playlistId = '',
  });

  bool get hasPlaylist => playlistId.trim().isNotEmpty;

  String get label => id.trim();

  factory AdherentVodSeason.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final id = (m['id'] ?? m['season'] ?? '').toString().trim();
    return AdherentVodSeason(
      id: id,
      playlistId: YoutubeParser.extractPlaylistId(
            (m['playlistId'] ?? m['playlistUrl'] ?? '').toString(),
          ) ??
          '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id.trim(),
        'playlistId': playlistId.trim(),
      };
}

/// VOD réservées aux adhérents — `app_config/adherent_vod`.
class AdherentVodConfig {
  static const String firestoreDocId = 'adherent_vod';

  final bool enabled;
  final String playlistId;
  final bool forceLockedPreview;
  final List<AdherentVodSeason> seasons;

  const AdherentVodConfig({
    this.enabled = false,
    this.playlistId = '',
    this.forceLockedPreview = false,
    this.seasons = const [],
  });

  static const AdherentVodConfig defaults = AdherentVodConfig();

  /// Switch admin ON → la section existe dans DVCR TV (même sans playlist).
  bool get showInApp => enabled;

  List<AdherentVodSeason> get visibleSeasons {
    final withPl = seasons.where((s) => s.hasPlaylist && s.id.isNotEmpty).toList()
      ..sort((a, b) => AdherentSeason.compareNewestFirst(a.id, b.id));
    if (withPl.isNotEmpty) return withPl;
    final legacy = playlistId.trim();
    if (legacy.isEmpty) return const [];
    return [
      AdherentVodSeason(id: AdherentSeason.currentId, playlistId: legacy),
    ];
  }

  bool get hasPlaylist => visibleSeasons.isNotEmpty;

  factory AdherentVodConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final legacy = YoutubeParser.extractPlaylistId(
          (data['playlistId'] ?? data['playlistUrl'] ?? '').toString(),
        ) ??
        '';
    final seasons = <AdherentVodSeason>[];
    final raw = data['seasons'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final s = AdherentVodSeason.fromMap(Map<String, dynamic>.from(item));
        if (s.id.isEmpty || !AdherentSeason.isValidId(s.id)) continue;
        seasons.add(s);
      }
    }
    if (seasons.isEmpty && legacy.isNotEmpty) {
      seasons.add(
        AdherentVodSeason(id: AdherentSeason.currentId, playlistId: legacy),
      );
    }
    seasons.sort((a, b) => AdherentSeason.compareNewestFirst(a.id, b.id));
    return AdherentVodConfig(
      enabled: data['enabled'] == true,
      playlistId: seasons.isNotEmpty ? seasons.first.playlistId : legacy,
      forceLockedPreview: data['forceLockedPreview'] == true,
      seasons: seasons,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'playlistId':
            (visibleSeasons.isNotEmpty ? visibleSeasons.first.playlistId : playlistId)
                .trim(),
        'forceLockedPreview': forceLockedPreview,
        'seasons': seasons
            .where((s) => s.id.isNotEmpty)
            .map((s) => s.toMap())
            .toList(),
      };
}

class AdherentVodAccess {
  final bool staffPreview;
  final Set<String> paidSeasons;

  const AdherentVodAccess({
    this.staffPreview = false,
    this.paidSeasons = const {},
  });

  static const locked = AdherentVodAccess();

  bool canWatch(String seasonId) {
    if (staffPreview) return true;
    return paidSeasons.contains(seasonId.trim());
  }
}
