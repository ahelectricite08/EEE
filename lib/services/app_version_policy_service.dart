import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/version_compare.dart';
import 'app_update_dismiss_service.dart';

/// Politique de version lue dans `app_config/app_version` (admin).
///
/// - [AppUpdateRequired] : blocage + lien store (build &lt; minimum obligatoire).
/// - [AppUpdateOptional] : bannière « Plus tard » (build &lt; dernier publié).
///
/// La pause des notifications push est gérée à part
/// (`app_config/admin_maintenance.notificationsPaused` — tableau de bord admin).
class AppVersionEvaluation {
  final AppUpdateRequired? required;
  final AppUpdateOptional? optional;

  const AppVersionEvaluation({this.required, this.optional});

  static const none = AppVersionEvaluation();

  bool get mustBlock => required != null;
  bool get hasOptionalBanner => optional != null && required == null;
}

class AppUpdateRequired {
  final String title;
  final String message;
  final String storeUrl;
  final String? imageUrl;
  final int imageRevisionMillis;
  final String currentVersionLabel;
  final String requiredVersionLabel;

  const AppUpdateRequired({
    required this.title,
    required this.message,
    required this.storeUrl,
    this.imageUrl,
    this.imageRevisionMillis = 0,
    required this.currentVersionLabel,
    required this.requiredVersionLabel,
  });
}

class AppUpdateOptional {
  final String title;
  final String message;
  final String storeUrl;
  final String? imageUrl;
  final int imageRevisionMillis;
  final int latestBuild;
  final String currentVersionLabel;

  const AppUpdateOptional({
    required this.title,
    required this.message,
    required this.storeUrl,
    this.imageUrl,
    this.imageRevisionMillis = 0,
    required this.latestBuild,
    required this.currentVersionLabel,
  });
}

class AppVersionPolicyService {
  static const String docId = 'app_version';

  static const String defaultStoreAndroid =
      'https://play.google.com/store/apps/details?id=fr.drapeauvert.dvcr';

  /// À renseigner dans l’admin dès que l’app est sur l’App Store (ID numérique).
  static const String defaultStoreIos =
      'https://apps.apple.com/app/dvcr/id0000000000';

  static DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection('app_config').doc(docId);

  static Stream<Map<String, dynamic>> configStream() => ref
      .snapshots(includeMetadataChanges: true)
      .map((s) => Map<String, dynamic>.from(s.data() ?? const {}));

  static Future<AppVersionEvaluation> evaluateCurrent() async {
    if (kIsWeb) return AppVersionEvaluation.none;

    PackageInfo info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('DVCR: package_info error: $e');
      return AppVersionEvaluation.none;
    }

    Map<String, dynamic> data;
    try {
      final snap =
          await ref.get(const GetOptions(source: Source.serverAndCache));
      data = Map<String, dynamic>.from(snap.data() ?? const {});
    } catch (e) {
      debugPrint('DVCR: app_version policy read error: $e');
      return AppVersionEvaluation.none;
    }

    return _evaluate(info, data);
  }

  static Future<AppVersionEvaluation> _evaluate(
    PackageInfo info,
    Map<String, dynamic> data,
  ) async {
    if (data['enabled'] != true) return AppVersionEvaluation.none;

    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final currentVersion = info.version;
    final currentLabel = '$currentVersion (build ${info.buildNumber})';

    final isIos = !kIsWeb && Platform.isIOS;
    final suffix = isIos ? 'Ios' : 'Android';
    final storeUrl = _str(
      data['storeUrl$suffix'],
      isIos ? defaultStoreIos : defaultStoreAndroid,
    );

    final minBuild = _int(data['minBuild$suffix']);
    final latestBuild = _int(data['latestBuild$suffix']);
    final minVersion = _str(data['minVersion$suffix'], '');

    final titleRequired = _str(data['titleRequired'], _str(data['title'], ''));
    final messageRequired = _str(
      data['messageRequired'],
      _str(data['message'], ''),
    );
    final titleOptional = _str(
      data['titleOptional'],
      'Nouvelle version disponible',
    );
    final messageOptional = _str(
      data['messageOptional'],
      'Une mise à jour DVCR est disponible sur le store. '
          'Profite des dernières corrections et fonctionnalités.',
    );
    final imageUrl = _optionalUrl(data['updateImageUrl']);
    final imageRevisionMillis = _revisionMillis(data['updatedAt']);

    AppUpdateRequired? required;
    if (minBuild != null && minBuild > 0 && currentBuild < minBuild) {
      required = AppUpdateRequired(
        title: titleRequired.isEmpty ? 'Mise à jour requise' : titleRequired,
        message: messageRequired.isEmpty
            ? 'Cette version de DVCR n’est plus supportée. '
                'Installe la dernière version depuis le store pour continuer.'
            : messageRequired,
        storeUrl: storeUrl,
        imageUrl: imageUrl,
        imageRevisionMillis: imageRevisionMillis,
        currentVersionLabel: currentLabel,
        requiredVersionLabel: 'build $minBuild minimum',
      );
      return AppVersionEvaluation(required: required);
    }

    if (minVersion.isNotEmpty &&
        compareSemanticVersions(currentVersion, minVersion) < 0) {
      required = AppUpdateRequired(
        title: titleRequired.isEmpty ? 'Mise à jour requise' : titleRequired,
        message: messageRequired.isEmpty
            ? 'Cette version de DVCR n’est plus supportée. '
                'Installe la dernière version depuis le store pour continuer.'
            : messageRequired,
        storeUrl: storeUrl,
        imageUrl: imageUrl,
        imageRevisionMillis: imageRevisionMillis,
        currentVersionLabel: currentLabel,
        requiredVersionLabel: 'version $minVersion minimum',
      );
      return AppVersionEvaluation(required: required);
    }

    AppUpdateOptional? optional;
    if (latestBuild != null &&
        latestBuild > 0 &&
        currentBuild < latestBuild) {
      final dismissed = await AppUpdateDismissService.getDismissedBuild();
      if (dismissed == null || dismissed < latestBuild) {
        optional = AppUpdateOptional(
          title: titleOptional,
          message: messageOptional,
          storeUrl: storeUrl,
          imageUrl: imageUrl,
          imageRevisionMillis: imageRevisionMillis,
          latestBuild: latestBuild,
          currentVersionLabel: currentLabel,
        );
      }
    }

    return AppVersionEvaluation(optional: optional);
  }

  static int _revisionMillis(dynamic updatedAt) {
    if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
    return 0;
  }

  static String? _optionalUrl(dynamic v) {
    if (v is! String) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return s;
  }

  static String _str(dynamic v, String fallback) {
    if (v is! String || v.trim().isEmpty) return fallback;
    return v.trim();
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static Future<void> savePolicy(Map<String, dynamic> patch) async {
    await ref.set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

