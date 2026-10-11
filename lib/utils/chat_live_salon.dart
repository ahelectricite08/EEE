/// Quel salon chat permanent ouvrir le jour de match (plus de salon `live_{id}`).
enum ChatLiveSalonKind {
  coupe,
  r1,
  reserve,
}

abstract final class ChatLiveSalon {
  ChatLiveSalon._();

  static const fallbackSalonId = 'general';

  static bool isTemporaryId(String id) => id.startsWith('live_');

  static ChatLiveSalonKind kindFor({
    String? competition,
    String? benevoleType,
    String? team1,
    String? team2,
  }) {
    final blob = [
      competition,
      benevoleType,
      team1,
      team2,
    ].whereType<String>().join(' ').toLowerCase();

    if (blob.contains('réserve') ||
        blob.contains('reserve') ||
        blob.contains('régional 2') ||
        blob.contains('regional 2') ||
        RegExp(r'\br2\b').hasMatch(blob)) {
      return ChatLiveSalonKind.reserve;
    }
    if (blob.contains('coupe')) {
      return ChatLiveSalonKind.coupe;
    }
    return ChatLiveSalonKind.r1;
  }

  static int _nameScore(ChatLiveSalonKind kind, String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return 0;
    switch (kind) {
      case ChatLiveSalonKind.coupe:
        if (n.contains('coupe de france')) return 20;
        if (n.contains('coupe')) return 12;
        return 0;
      case ChatLiveSalonKind.r1:
        if (n.contains('homiris')) return 20;
        if (n.contains('régional 1') || n.contains('regional 1')) return 16;
        if (RegExp(r'\br1\b').hasMatch(n) || n == 'r1') return 14;
        return 0;
      case ChatLiveSalonKind.reserve:
        if (n.contains('réserve') || n.contains('reserve')) return 20;
        if (n.contains('régional 2') || n.contains('regional 2')) return 12;
        if (RegExp(r'\br2\b').hasMatch(n)) return 10;
        return 0;
    }
  }

  /// Meilleur salon existant pour ce type, sinon `general`.
  static String pickSalonId({
    required ChatLiveSalonKind kind,
    required List<({String id, String name})> salons,
  }) {
    var bestId = fallbackSalonId;
    var bestScore = 0;
    for (final s in salons) {
      if (isTemporaryId(s.id)) continue;
      final score = _nameScore(kind, s.name);
      if (score > bestScore) {
        bestScore = score;
        bestId = s.id;
      }
    }
    return bestId;
  }
}
