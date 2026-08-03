import 'package:cloud_firestore/cloud_firestore.dart';

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
    players.sort((a, b) {
      final na = a.number ?? 999;
      final nb = b.number ?? 999;
      if (na != nb) return na.compareTo(nb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
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
