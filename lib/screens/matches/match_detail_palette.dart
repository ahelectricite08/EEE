import 'package:flutter/material.dart';

import 'match_detail_theme.dart';

/// Alias historique — les couleurs suivent [MatchDetailTheme].
/// `gold` pointe vers l’accent club (plus d’or cheap).
abstract final class MatchDetailPalette {
  static const Color red = MatchDetailTheme.red;
  static const Color bg = MatchDetailTheme.scaffold;
  static const Color card = MatchDetailTheme.surface;
  static const Color border = MatchDetailTheme.hairline;
  static const Color grey = MatchDetailTheme.textMuted;
  static const Color text = MatchDetailTheme.text;
  static const Color green = MatchDetailTheme.green;
  static const Color greenDeep = MatchDetailTheme.greenDeep;
  static const Color gold = MatchDetailTheme.accent;
}
