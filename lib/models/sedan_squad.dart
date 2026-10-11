import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/player_name_normalize.dart';

/// Joueur de l'effectif Sedan — `app_config/sedan_squad`.
class SedanSquadPlayer {
  final String id;
  final String name;
  final int? number;
  final String? position;
  /// Portrait optionnel (Storage `sedan_squad/` ou URL collée en admin).
  final String? photoUrl;

  const SedanSquadPlayer({
    required this.id,
    required this.name,
    this.number,
    this.position,
    this.photoUrl,
  });

  bool get hasPhoto {
    final u = photoUrl?.trim();
    return u != null && u.isNotEmpty;
  }

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
    final photo = (m['photoUrl'] ?? m['photo'] ?? '').toString().trim();
    return SedanSquadPlayer(
      id: (m['id'] ?? '').toString().trim(),
      name: (m['name'] ?? '').toString().trim(),
      number: (number != null && number > 0) ? number : null,
      position: pos.isEmpty ? null : pos,
      photoUrl: photo.isEmpty ? null : photo,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (number != null) 'number': number,
        if (position != null && position!.isNotEmpty) 'position': position,
        if (photoUrl != null && photoUrl!.trim().isNotEmpty)
          'photoUrl': photoUrl!.trim(),
      };

  SedanSquadPlayer copyWith({
    String? name,
    int? number,
    String? position,
    String? photoUrl,
  }) {
    return SedanSquadPlayer(
      id: id,
      name: name ?? this.name,
      number: number ?? this.number,
      position: position ?? this.position,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

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
  static const String storageFolder = 'sedan_squad';

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

  SedanSquadPlayer? matchLineupLabel(String raw, {String? playerId}) {
    final id = (playerId ?? '').trim();
    if (id.isNotEmpty) {
      final hit = byId(id);
      if (hit != null) return hit;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final names = [for (final p in players) p.name];
    final hits = matchPlayerNames(predicted: [trimmed], official: names);
    if (hits.length == 1) {
      final idx = hits.first.officialIndex;
      if (idx >= 0 && idx < players.length) return players[idx];
    }
    return null;
  }

  /// Vote Homme du match / portrait : **côté Sedan uniquement**.
  ///
  /// Sans [sedanSide], on ne cherche pas dans l’effectif (évite de coller
  /// la photo d’un n°9 CSSA sur le n°9 adverse).
  SedanSquadPlayer? matchVoteLabel(
    String raw, {
    bool sedanSide = false,
    String? playerId,
  }) {
    if (!sedanSide) return null;
    final id = (playerId ?? '').trim();
    if (id.isNotEmpty) {
      final hit = byId(id);
      if (hit != null) return hit;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final direct = matchLineupLabel(trimmed);
    if (direct != null) return direct;

    final nameNorm = normalizePlayerName(trimmed);
    if (nameNorm.length < 3) return null;
    final tokens = nameNorm
        .split(' ')
        .where((t) => t.length >= 3)
        .toList();
    if (tokens.isEmpty) return null;
    final last = tokens.last;
    SedanSquadPlayer? found;
    for (final p in players) {
      final pn = normalizePlayerName(p.name);
      if (pn.isEmpty) continue;
      final parts = pn.split(' ');
      final hit = pn == nameNorm || parts.contains(last) || pn.endsWith(last);
      if (!hit) continue;
      if (found != null && found.id != p.id) return null;
      found = p;
    }
    return found;
  }

  /// Disque sans photo : numéro + nom extraits d’un libellé « 9 Koffi ».
  static SedanSquadPlayer placeholderFromLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const SedanSquadPlayer(id: '', name: '');
    }
    final numMatch = RegExp(r'^(\d{1,3})\b').firstMatch(trimmed);
    var name = trimmed;
    int? number;
    if (numMatch != null) {
      number = int.tryParse(numMatch.group(1)!);
      final rest = trimmed.substring(numMatch.end).trim();
      if (rest.isNotEmpty) name = rest;
    }
    return SedanSquadPlayer(
      id: '',
      name: name,
      number: (number != null && number > 0) ? number : null,
    );
  }

  SedanSquadPlayer faceForVoteLabel(
    String raw, {
    String? playerId,
  }) {
    return matchVoteLabel(
          raw,
          sedanSide: true,
          playerId: playerId,
        ) ??
        placeholderFromLabel(raw);
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
