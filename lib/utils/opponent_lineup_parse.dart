import '../models/match_lineup.dart';

/// Découpe un collage FFF / une saisie rapide en noms de joueurs.
///
/// Un nom par ligne, virgules, ou « 1 Martin 2 Dupont ». Les numéros de
/// maillot collés au nom (« 9 MARTIN ») sont conservés.
List<String> parseOpponentLineupNames(String raw, {int max = 18}) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) return const [];

  final chunks = <String>[];
  if (RegExp(r'[\n;\t]').hasMatch(text)) {
    for (final line in text.split(RegExp(r'[\n;]+'))) {
      chunks.addAll(_splitPackedLine(line));
    }
  } else if (_looksLikeCommaList(text)) {
    chunks.addAll(text.split(','));
  } else {
    chunks.addAll(_splitPackedLine(text));
  }

  final out = <String>[];
  final seen = <String>{};
  for (final chunk in chunks) {
    var name = chunk.trim();
    if (name.isEmpty) continue;
    name = name.replaceFirst(RegExp(r'^[\s\-–—*•·]+'), '');
    name = name.replaceFirst(RegExp(r'^\d{1,2}[\.\)\:]\s+'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isEmpty) continue;
    if (MatchLineupSide.isStaffOrCoachLabel(name)) continue;
    final key = name.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(name);
    if (out.length >= max) break;
  }
  return out;
}

bool _looksLikeCommaList(String text) {
  final parts = text.split(',');
  if (parts.length < 3) return false;
  return parts.where((e) => e.trim().isNotEmpty).length >= 3;
}

List<String> _splitPackedLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return const [];
  final packed = trimmed.split(RegExp(r'\s+(?=\d{1,2}\s+[A-Za-zÀ-ÿ])'));
  if (packed.length > 1) return packed;
  return [trimmed];
}
