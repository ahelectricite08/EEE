/// Réactions chat — clé emoji canonique + lecture Firestore robuste.
const String kChatReactionHeart = '❤️';

const List<String> kChatDefaultQuickReactions = [
  kChatReactionHeart,
  '🔥',
  '😂',
  '👏',
  '😮',
];

/// Cœur réaction : icône rouge (évite le ❤️ noir hérité du style texte du chat).
bool isChatHeartReaction(String token) =>
    normalizeChatReactionEmoji(token) == kChatReactionHeart;

/// Normalise ❤ / ♥ / ❤️ vers une seule clé (évite les doublons Firestore).
String normalizeChatReactionEmoji(String emoji) {
  final t = emoji.trim();
  if (t.isEmpty) return t;
  if (t == '❤' || t == '♥' || t == '♥️' || t.startsWith('❤')) {
    return kChatReactionHeart;
  }
  return t;
}

List<String> reactionUidsFromFirestore(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Fusionne les variantes du même emoji (ex. cœur) et nettoie les listes d’UID.
Map<String, dynamic> normalizeReactionsMap(Map<String, dynamic> raw) {
  final merged = <String, List<String>>{};
  for (final entry in raw.entries) {
    final key = normalizeChatReactionEmoji(entry.key);
    if (key.isEmpty) continue;
    final uids = reactionUidsFromFirestore(entry.value);
    if (uids.isEmpty) continue;
    final bucket = merged.putIfAbsent(key, () => <String>[]);
    for (final uid in uids) {
      if (!bucket.contains(uid)) bucket.add(uid);
    }
  }
  return {for (final e in merged.entries) e.key: e.value};
}
