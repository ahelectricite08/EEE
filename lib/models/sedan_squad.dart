import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/player_name_normalize.dart';

/// Joueur de l'effectif Sedan — `app_config/sedan_squad`.
class SedanSquadPlayer {
  final String id;
  final String name;
  final int? number;
  final String? position;

  const SedanSquadPlayer({
    required this.id,
    required this.name,
    this.number,
    this.position,
  });

  factory SedanSquadPlayer.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final numRaw = m['number'];
    int? number;
    if (numRaw is num) {
      number = numRaw.toInt();
    } else if (numRaw is String) {
      number = int.tryParse(numRaw.trim());
    }
    final pos = (m['position'] ?? '').toString().trim();
    return SedanSquadPlayer(
      id: (m['id'] ?? '').toString().trim(),
      name: (m['name'] ?? '').toString().trim(),
      number: (number != null && number > 0) ? number : null,
      position: pos.isEmpty ? null : pos,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (number != null) 'number': number,
        if (position != null && position!.isNotEmpty) 'position': position,
      };

  bool get isValid => id.isNotEmpty && name.isNotEmpty;

  /// Libellé admin / picker : « 9 Dupont · ATT ».
  String get displayLabel {
    final buf = StringBuffer();
    if (number != null) buf.write('$number ');
    buf.write(name);
    if (position != null && position!.isNotEmpty) {
      buf.write(' · $position');
    }
    return buf.toString();
  }

  /// Nom pour composition / faits de jeu (numéro optionnel devant).
  String get lineupName {
    if (number != null) return '$number $name';
    return name;
  }
}

/// Postes effectif / XI probable — ordre d’affichage.
class SedanSquadPositions {
  static const order = ['GB', 'DEF', 'MIL', 'ATT'];

  static const labels = {
    'GB': 'Gardiens',
    'DEF': 'Défenseurs',
    'MIL': 'Milieux',
    'ATT': 'Attaquants',
  };

  static String normalize(String? pos) => (pos ?? '').trim().toUpperCase();

  static int rank(String? pos) {
    final i = order.indexOf(normalize(pos));
    return i < 0 ? order.length : i;
  }

  static String groupLabel(String? pos) {
    final key = normalize(pos);
    return labels[key] ?? 'Autres';
  }
}

/// Effectif CSSA — `app_config/sedan_squad`.
class SedanSquad {
  static const String firestoreDocId = 'sedan_squad';

  final List<SedanSquadPlayer> players;
  final DateTime? updatedAt;

  const SedanSquad({
    this.players = const [],
    this.updatedAt,
  });

  static const SedanSquad empty = SedanSquad();

  bool get isEmpty => players.isEmpty;

  List<SedanSquadPlayer> get sortedByPosition {
    final list = [...players];
    list.sort(_compareByPositionThenNumber);
    return list;
  }

  /// Groupes GB → DEF → MIL → ATT → Autres (sections vides omises).
  List<(String label, List<SedanSquadPlayer> players)> groupedByPosition() {
    final buckets = <String, List<SedanSquadPlayer>>{
      for (final k in SedanSquadPositions.order) k: [],
      '_': [],
    };
    for (final p in sortedByPosition) {
      final key = SedanSquadPositions.normalize(p.position);
      if (buckets.containsKey(key)) {
        buckets[key]!.add(p);
      } else {
        buckets['_']!.add(p);
      }
    }
    final out = <(String, List<SedanSquadPlayer>)>[];
    for (final k in SedanSquadPositions.order) {
      final group = buckets[k]!;
      if (group.isEmpty) continue;
      out.add((SedanSquadPositions.labels[k]!, group));
    }
    if (buckets['_']!.isNotEmpty) {
      out.add(('Autres', buckets['_']!));
    }
    return out;
  }

  SedanSquadPlayer? matchLineupLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final numMatch = RegExp(r'^(\d{1,3})\b').firstMatch(trimmed);
    final number = numMatch != null ? int.tryParse(numMatch.group(1)!) : null;
    final nameNorm = normalizePlayerName(trimmed);
    for (final p in players) {
      if (number != null && p.number == number) return p;
    }
    if (nameNorm.isEmpty) return null;
    for (final p in players) {
      if (normalizePlayerName(p.name) == nameNorm) return p;
    }
    return null;
  }

  List<String> sortLineupLabels(List<String> labels) {
    final tagged = [
      for (final raw in labels)
        (raw, SedanSquadPositions.rank(matchLineupLabel(raw)?.position)),
    ];
    tagged.sort((a, b) {
      final c = a.$2.compareTo(b.$2);
      if (c != 0) return c;
      return a.$1.toLowerCase().compareTo(b.$1.toLowerCase());
    });
    return [for (final e in tagged) e.$1];
  }

  static int _compareByPositionThenNumber(
    SedanSquadPlayer a,
    SedanSquadPlayer b,
  ) {
    final c = SedanSquadPositions.rank(a.position)
        .compareTo(SedanSquadPositions.rank(b.position));
    if (c != 0) return c;
    final na = a.number ?? 999;
    final nb = b.number ?? 999;
    if (na != nb) return na.compareTo(nb);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  SedanSquadPlayer? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory SedanSquad.fromMap(Map<String, dynamic>? d) {
    if (d == null || d.isEmpty) return empty;
    final raw = d['players'];
    final players = <SedanSquadPlayer>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final p = SedanSquadPlayer.fromMap(Map<String, dynamic>.from(item));
          if (p.isValid) players.add(p);
        }
      }
    }
    players.sort(_compareByPositionThenNumber);
    DateTime? updatedAt;
    final ts = d['updatedAt'];
    if (ts is Timestamp) updatedAt = ts.toDate();
    return SedanSquad(players: players, updatedAt: updatedAt);
  }

  Map<String, dynamic> toFirestoreMap() => {
        'players': players.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
