/// En-têtes pour `Image.network` / téléchargements : certains CDN (ex. Wix)
/// refusent ou se comportent mal sans User-Agent « navigateur ».
const kDvcrImageHttpHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 DVCR-App',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// Évite le cache image Flutter quand Firestore met à jour le même lien
/// (ou pour forcer un rechargement après sauvegarde admin).
String cacheBustedImageUrl(String url, int revisionMillis) {
  final t = url.trim();
  if (t.isEmpty || revisionMillis == 0) return t;
  final uri = Uri.tryParse(t);
  if (uri == null || !uri.hasScheme) return t;
  if (uri.scheme != 'http' && uri.scheme != 'https') return t;
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
