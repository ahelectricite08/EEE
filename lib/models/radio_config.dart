/// Config radio commentaire MediaMTX — `app_config/radio`.
///
/// URLs publiques (HLS écoute + WHIP publish). Les secrets d’auth publish
/// restent côté Cloud Functions (`MEDIAMTX_PUBLISH_*`).
class RadioConfig {
  static const firestoreDocId = 'radio';

  /// Ex. `https://radio.example.com:8889/dvcr-radio/whip`
  final String whipUrl;

  /// Ex. `https://radio.example.com:8888/dvcr-radio/index.m3u8`
  final String hlsUrl;

  /// Base MediaMTX (optionnel) — si [whipUrl]/[hlsUrl] vides, dérivés avec [streamName].
  final String baseUrl;

  /// Nom de chemin MediaMTX (défaut `dvcr-radio`).
  final String streamName;

  const RadioConfig({
    this.whipUrl = '',
    this.hlsUrl = '',
    this.baseUrl = '',
    this.streamName = 'dvcr-radio',
  });

  factory RadioConfig.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final stream = (m['streamName'] ?? 'dvcr-radio').toString().trim();
    final streamName = stream.isEmpty ? 'dvcr-radio' : stream;
    final base = (m['baseUrl'] ?? '').toString().trim().replaceAll(RegExp(r'/+$'), '');
    var whip = (m['whipUrl'] ?? '').toString().trim();
    var hls = (m['hlsUrl'] ?? '').toString().trim();

    if (base.isNotEmpty) {
      // MediaMTX : WHIP :8889 / HLS :8888 — si base sans port, on garde tels quels
      // les templates classiques lorsqu’un seul host est fourni.
      if (whip.isEmpty) {
        whip = _deriveWhip(base, streamName);
      }
      if (hls.isEmpty) {
        hls = _deriveHls(base, streamName);
      }
    }

    return RadioConfig(
      whipUrl: whip,
      hlsUrl: hls,
      baseUrl: base,
      streamName: streamName,
    );
  }

  Map<String, dynamic> toMap() => {
        'whipUrl': whipUrl,
        'hlsUrl': hlsUrl,
        'baseUrl': baseUrl,
        'streamName': streamName,
      };

  bool get hasListenUrl => hlsUrl.isNotEmpty;
  bool get hasPublishUrl => whipUrl.isNotEmpty;

  /// Remplace le port (ou en ajoute un) sur une URL de base.
  static String _withPort(String base, int port) {
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme) {
      return '$base:$port';
    }
    return uri.replace(port: port).toString().replaceAll(RegExp(r'/+$'), '');
  }

  static String _deriveWhip(String base, String stream) {
    // Si la base contient déjà :8889 ou un chemin, privilégier whipUrl explicite.
    final root = _withPort(base, 8889);
    return '$root/$stream/whip';
  }

  static String _deriveHls(String base, String stream) {
    final root = _withPort(base, 8888);
    return '$root/$stream/index.m3u8';
  }
}
