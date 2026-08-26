/// En-têtes pour `Image.network` / téléchargements : certains CDN (ex. Wix)
/// refusent ou se comportent mal sans User-Agent « navigateur ».
const kDvcrImageHttpHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 DVCR-App',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// Canva `media.canva.com` : URLs signées, hotlink souvent refusé (403),
/// et `exp=` périme. Ne jamais les passer à [NetworkImage].
bool looksLikeCanvaHotlinkUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return false;
  final uri = Uri.tryParse(t);
  if (uri != null && uri.host.isNotEmpty) {
    final host = uri.host.toLowerCase();
    if (host == 'media.canva.com' || host.endsWith('.canva.com')) {
      return true;
    }
    if (host == 'canva.com' || host == 'www.canva.com') return true;
  }
  final u = t.toLowerCase();
  return u.contains('media.canva.com') ||
      u.contains('canva.com/v2/image-resize');
}

/// Lien signé avec `exp=` (unix seconds) déjà dépassé — Canva, etc.
bool isExpiredSignedImageUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  final expRaw = uri.queryParameters['exp'];
  if (expRaw == null || expRaw.isEmpty) return false;
  final seconds = int.tryParse(expRaw);
  if (seconds == null) return false;
  if (seconds < 1000000000 || seconds > 9999999999) return false;
  final expiry = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  );
  return DateTime.now().toUtc().isAfter(expiry);
}

/// Ne pas lancer de [NetworkImage] : hôte Canva, ou signature `exp` périmée.
bool shouldSkipNetworkImageUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return true;
  return looksLikeCanvaHotlinkUrl(t) || isExpiredSignedImageUrl(t);
}

/// Ajouter `dvcr_rev` casse les HMAC (Canva, AWS, GCS signés).
bool _isSignatureSensitiveUrl(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host.contains('canva.com')) return true;
  final keys = uri.queryParameters.keys.map((k) => k.toLowerCase());
  for (final k in keys) {
    if (k == 'exp' || k == 'sig' || k == 'signature') return true;
    if (k.startsWith('x-amz-') || k.startsWith('x-goog-')) return true;
  }
  return false;
}

/// Évite le cache image Flutter quand Firestore met à jour le même lien
/// (ou pour forcer un rechargement après sauvegarde admin).
String cacheBustedImageUrl(String url, int revisionMillis) {
  final t = url.trim();
  if (t.isEmpty || revisionMillis == 0) return t;
  final uri = Uri.tryParse(t);
  if (uri == null || !uri.hasScheme) return t;
  if (uri.scheme != 'http' && uri.scheme != 'https') return t;
  if (_isSignatureSensitiveUrl(uri)) return t;
  final q = Map<String, String>.from(uri.queryParameters);
  q['dvcr_rev'] = '$revisionMillis';
  return uri.replace(queryParameters: q).toString();
}

/// Heuristique : lien Wix « page » (HTML) au lieu d’une URL d’image directe.
bool looksLikeWixPageNotDirectImage(String url) {
  final u = url.toLowerCase().trim();
  if (u.isEmpty) return false;
  final wixSite = u.contains('wixsite.com') ||
      u.contains('.wix.com/') ||
      u.contains('editorx.com');
  if (!wixSite) return false;
  if (u.contains('static.wixstatic.com')) return false;
  return !(u.endsWith('.jpg') ||
      u.endsWith('.jpeg') ||
      u.endsWith('.png') ||
      u.endsWith('.webp') ||
      u.endsWith('.gif'));
}

/// Message admin si l’URL ne doit pas être collée (Canva, page Wix, expiré).
String? remoteImageAdminWarning(String url) {
  final t = url.trim();
  if (t.isEmpty) return null;
  if (looksLikeCanvaHotlinkUrl(t)) {
    return 'Lien Canva — media.canva.com expire et refuse le hotlink (403). '
        'Uploadez l’image sur Storage (URL stable), ne collez pas Canva.';
  }
  if (isExpiredSignedImageUrl(t)) {
    return 'Lien signé périmé (paramètre exp). Recollez une URL Storage stable.';
  }
  if (looksLikeWixPageNotDirectImage(t)) {
    return 'URL suspecte (page Wix ?) — utilise le lien direct '
        '`static.wixstatic.com/...`.';
  }
  return null;
}

String? firstRemoteImageAdminWarning(Iterable<String> urls) {
  for (final u in urls) {
    final w = remoteImageAdminWarning(u);
    if (w != null) return w;
  }
  return null;
}

/// 403 NetworkImage / Canva : déjà gérés par fallback UI, ne pas spammer.
bool isBenignRemoteImageFailureMessage(String message) {
  final s = message.toLowerCase();
  if (s.contains('media.canva.com') ||
      s.contains('canva.com/v2/image-resize')) {
    return true;
  }
  return s.contains('http request failed, statuscode: 403');
}
