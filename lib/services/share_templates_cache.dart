import 'dart:async';

import 'app_settings_service.dart';
import '../utils/share_template_settings.dart';

/// Dernière version des modèles de partage (Firestore `app_config/share_text_templates`).
class ShareTemplatesCache {
  ShareTemplatesCache._();

  static StreamSubscription<ShareTemplateSettings>? _sub;
  static ShareTemplateSettings _value = ShareTemplateSettings.defaults;

  static ShareTemplateSettings get settings => _value;

  static void start() {
    _sub ??= AppSettingsService.shareTemplatesStream().listen((s) {
      _value = s;
    });
  }

  static Future<void> refresh() async {
    _value = await AppSettingsService.getShareTemplatesOnce();
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
