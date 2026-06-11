/// Utilitaire pour la manipulation des liens YouTube
class YoutubeParser {
  static bool _isYoutubeHost(String host) {
    final h = host.toLowerCase();
    return h.contains('youtube') || h == 'youtu.be';
  }

  /// Retire `si`, `feature`, UTMs… (lien « Partager » YouTube → traçage du compte).
  static String sanitizeShareUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !_isYoutubeHost(uri.host)) return trimmed;

    final qp = Map<String, String>.from(uri.queryParameters);
    const stripKeys = {'si', 'feature', 'pp', 'gclid', 'fbclid', 'igshid'};
    for (final k in stripKeys) {
      qp.remove(k);
    }
    qp.removeWhere((k, _) => k.toLowerCase().startsWith('utm_'));

    final clean = Uri(
      scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: qp.isEmpty ? null : qp,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );
    var out = clean.toString();
    if (out.endsWith('?')) out = out.substring(0, out.length - 1);
    return out;
  }

  /// Extrait l'ID d'une vidéo YouTube à partir d'une URL (standard, short, ou partagée)
  static String? extractId(String input) {
    if (input.isEmpty) return null;
    final sanitized = sanitizeShareUrl(input);
    final uri = Uri.tryParse(sanitized);
    if (uri != null && uri.queryParameters['v'] != null) {
      return uri.queryParameters['v'];
    }
    if (sanitized.contains('youtu.be/')) {
      return sanitized.split('youtu.be/').last.split('?').first.trim();
    }
    if (sanitized.contains('/shorts/')) {
      return sanitized.split('/shorts/').last.split('?').first.trim();
    }
    return sanitized.trim();
  }
}