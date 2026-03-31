/// Utilitaire pour la manipulation des liens YouTube
class YoutubeParser {
  /// Extrait l'ID d'une vidéo YouTube à partir d'une URL (standard, short, ou partagée)
  static String? extractId(String input) {
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    if (uri != null && uri.queryParameters['v'] != null) return uri.queryParameters['v'];
    if (input.contains('youtu.be/')) return input.split('youtu.be/').last.split('?').first.trim();
    if (input.contains('/shorts/')) return input.split('/shorts/').last.split('?').first.trim();
    return input.trim();
  }
}