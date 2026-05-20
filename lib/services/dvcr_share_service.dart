import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'app_settings_service.dart';
import 'share_templates_cache.dart';
import '../utils/remote_image_url.dart';

/// Partage unifié : texte + image optionnelle (URL Firestore `app_config/share_card`).
class DvcrShare {
  DvcrShare._();

  static ShareCardSettings? _cachedSettings;
  static DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 4);

  /// À appeler après enregistrement admin pour refléter tout de suite la nouvelle image.
  static void clearSettingsCache() {
    _cachedSettings = null;
    _cacheAt = null;
    unawaited(ShareTemplatesCache.refresh());
  }

  static Future<ShareCardSettings> _loadSettings() async {
    final now = DateTime.now();
    if (_cachedSettings != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      return _cachedSettings!;
    }
    _cachedSettings = await AppSettingsService.getShareCardOnce();
    _cacheAt = now;
    return _cachedSettings!;
  }

  /// Partage [message] ; sur mobile, joint l’image distante si configurée et téléchargeable.
  ///
  /// [attachShareCard] : `false` pour contenus techniques (ex. fichier calendrier .ics).
  static Future<void> share(
    String message, {
    String? subject,
    bool attachShareCard = true,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    if (kIsWeb || !attachShareCard) {
      await Share.share(trimmed, subject: subject);
      return;
    }

    final settings = await _loadSettings();
    final url = settings.imageUrl.trim();
    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      await Share.share(trimmed, subject: subject);
      return;
    }

    final fetchUrl = cacheBustedImageUrl(url, settings.revisionMillis);

    try {
      final res = await http
          .get(
            Uri.parse(fetchUrl),
            headers: kDvcrImageHttpHeaders,
          )
          .timeout(const Duration(seconds: 14));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        await Share.share(trimmed, subject: subject);
        return;
      }
      final lower = fetchUrl.toLowerCase();
      final ext = lower.contains('.png') && !lower.contains('.jpg')
          ? 'png'
          : 'jpg';
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final tmp = File(
        '${Directory.systemTemp.path}/dvcr_share_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await Share.shareXFiles(
        [XFile(tmp.path, mimeType: mime, name: 'dvcr.$ext')],
        text: trimmed,
        subject: subject,
      );
      try {
        await tmp.delete();
      } catch (_) {}
    } catch (_) {
      await Share.share(trimmed, subject: subject);
    }
  }
}
