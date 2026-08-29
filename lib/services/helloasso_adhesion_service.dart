import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/adherent_vod.dart';

/// Config HelloAsso / adhésion — `app_config/helloasso_adhesion`.
///
/// Champs document Firestore :
/// - `adherentExpiresAt` (Timestamp) — fin de statut adhérent (cotisation)
/// - `adhesionCampaignEndsAt` (Timestamp) — fin de campagne d’adhésion (splash)
/// - `bannerEnabled` (bool) — afficher le bandeau accueil
/// - `splashEnabled` (bool) — écran plein écran à l’ouverture (indépendant)
/// - `helloAssoUrl` (string) — formulaire d’adhésion HelloAsso
/// - `helloAssoSupportUrl` (string) — paiement soutien / don (après campagne)
/// - `title`, `subtitle`, `ctaLabel` (strings) — textes bandeau adhésion
/// - `supportTitle`, `supportSubtitle`, `supportCtaLabel` — bandeau après campagne
/// - `splashTitle`, `splashSubtitle`, `splashCtaLabel` — textes écran ouverture
/// - `splashImageUrl` (string) — photo plein écran
/// - `memberCount` (int) — compteur manuel
/// - `memberCountLabel` (string) — libellé sous le compteur
/// - `useCustomBackground` (bool), `backgroundUrl` (string, Storage)
/// - `trackingEnabled` (bool), `utmSource`, `utmMedium`, `utmCampaign`
/// - `updatedAt` (server timestamp)
class HelloAssoAdhesionConfig {
  final DateTime adherentExpiresAt;
  final DateTime adhesionCampaignEndsAt;
  final bool bannerEnabled;
  final bool splashEnabled;
  final String helloAssoUrl;
  final String helloAssoSupportUrl;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String supportTitle;
  final String supportSubtitle;
  final String supportCtaLabel;
  final String splashTitle;
  final String splashSubtitle;
  final String splashCtaLabel;
  final String splashImageUrl;
  final int memberCount;
  final String memberCountLabel;
  final bool useCustomBackground;
  final String backgroundUrl;
  final bool trackingEnabled;
  final String utmSource;
  final String utmMedium;
  final String utmCampaign;

  const HelloAssoAdhesionConfig({
    required this.adherentExpiresAt,
    required this.adhesionCampaignEndsAt,
    this.bannerEnabled = false,
    this.splashEnabled = false,
    this.helloAssoUrl = '',
    this.helloAssoSupportUrl = '',
    this.title = 'Rejoins la famille DVCR',
    this.subtitle = 'Adhère au club et soutiens le projet',
    this.ctaLabel = 'Adhérer',
    this.supportTitle = 'Tu veux nous soutenir ?',
    this.supportSubtitle = 'Soutiens-nous ici :',
    this.supportCtaLabel = 'Soutenir',
    this.splashTitle = 'Rejoins dès maintenant l’association',
    this.splashSubtitle = 'Soutiens DVCR et le projet CSSA',
    this.splashCtaLabel = 'Adhérer',
    this.splashImageUrl = '',
    this.memberCount = 0,
    this.memberCountLabel = 'personnes ont rejoint',
    this.useCustomBackground = false,
    this.backgroundUrl = '',
    this.trackingEnabled = true,
    this.utmSource = 'dvcr_app',
    this.utmMedium = 'banner',
    this.utmCampaign = 'adhesion_home',
  });

  static const String defaultBackgroundAsset =
      'assets/images/adhesion_banner_bg.png';

  static final DateTime defaultExpiresAt =
      DateTime.utc(2027, 6, 1, 21, 59, 59);

  /// 31 décembre 23:59:59 de l’année de début de saison (juil. N → juin N+1).
  static DateTime defaultCampaignEndsAt({DateTime? now}) {
    final n = now ?? DateTime.now();
    final seasonStartYear = n.month >= 7 ? n.year : n.year - 1;
    return DateTime(seasonStartYear, 12, 31, 23, 59, 59);
  }

  static final HelloAssoAdhesionConfig defaults = HelloAssoAdhesionConfig(
    adherentExpiresAt: defaultExpiresAt,
    adhesionCampaignEndsAt: defaultCampaignEndsAt(),
  );

  bool get canOpenHelloAsso => helloAssoUrl.trim().isNotEmpty;

  bool get canOpenSupport => helloAssoSupportUrl.trim().isNotEmpty;

  /// Campagne d’adhésion encore ouverte (indépendant de [adherentExpiresAt]).
  bool isAdhesionCampaignOpen([DateTime? now]) {
    final n = now ?? DateTime.now();
    return !n.isAfter(adhesionCampaignEndsAt);
  }

  /// Splash « Devenez adhérent » : switch + URL adhésion + campagne ouverte.
  bool shouldShowSplash([DateTime? now]) =>
      splashEnabled && canOpenHelloAsso && isAdhesionCampaignOpen(now);

  /// Bandeau accueil pour un non-adhérent (adhérents actifs : toujours masqué).
  bool shouldShowHomeBanner({
    required bool isAdherentActive,
    DateTime? now,
  }) {
    if (isAdherentActive || !bannerEnabled) return false;
    if (isAdhesionCampaignOpen(now)) return canOpenHelloAsso;
    return canOpenSupport;
  }

  String get bannerDisplayTitle =>
      isAdhesionCampaignOpen() ? title : supportTitle;

  String get bannerDisplaySubtitle =>
      isAdhesionCampaignOpen() ? subtitle : supportSubtitle;

  String get bannerDisplayCta =>
      isAdhesionCampaignOpen() ? ctaLabel : supportCtaLabel;

  static DateTime _readDateTime(dynamic raw, DateTime fallback) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  factory HelloAssoAdhesionConfig.fromMap(Map<String, dynamic>? data) {
    final expires = _readDateTime(
      data?['adherentExpiresAt'] ?? data?['expiresAt'],
      defaultExpiresAt,
    );
    final campaignEnds = _readDateTime(
      data?['adhesionCampaignEndsAt'],
      defaultCampaignEndsAt(),
    );

    final countRaw = data?['memberCount'];
    var memberCount = 0;
    if (countRaw is int) {
      memberCount = countRaw;
    } else if (countRaw is num) {
      memberCount = countRaw.round();
    } else if (countRaw is String) {
      memberCount = int.tryParse(countRaw.trim()) ?? 0;
    }
    if (memberCount < 0) memberCount = 0;

    return HelloAssoAdhesionConfig(
      adherentExpiresAt: expires,
      adhesionCampaignEndsAt: campaignEnds,
      bannerEnabled: data?['bannerEnabled'] == true,
      splashEnabled: data?['splashEnabled'] == true,
      helloAssoUrl: (data?['helloAssoUrl'] ?? '').toString(),
      helloAssoSupportUrl: (data?['helloAssoSupportUrl'] ?? '').toString(),
      title: (data?['title'] ?? defaults.title).toString(),
      subtitle: (data?['subtitle'] ?? defaults.subtitle).toString(),
      ctaLabel: (data?['ctaLabel'] ?? defaults.ctaLabel).toString(),
      supportTitle: (data?['supportTitle'] ?? defaults.supportTitle).toString(),
      supportSubtitle:
          (data?['supportSubtitle'] ?? defaults.supportSubtitle).toString(),
      supportCtaLabel:
          (data?['supportCtaLabel'] ?? defaults.supportCtaLabel).toString(),
      splashTitle: (data?['splashTitle'] ?? defaults.splashTitle).toString(),
      splashSubtitle:
          (data?['splashSubtitle'] ?? defaults.splashSubtitle).toString(),
      splashCtaLabel:
          (data?['splashCtaLabel'] ?? defaults.splashCtaLabel).toString(),
      splashImageUrl: (data?['splashImageUrl'] ?? '').toString(),
      memberCount: memberCount,
      memberCountLabel:
          (data?['memberCountLabel'] ?? defaults.memberCountLabel).toString(),
      useCustomBackground: data?['useCustomBackground'] == true,
      backgroundUrl: (data?['backgroundUrl'] ?? '').toString(),
      trackingEnabled: data?['trackingEnabled'] != false,
      utmSource: (data?['utmSource'] ?? defaults.utmSource).toString(),
      utmMedium: (data?['utmMedium'] ?? defaults.utmMedium).toString(),
      utmCampaign: (data?['utmCampaign'] ?? defaults.utmCampaign).toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adherentExpiresAt': Timestamp.fromDate(adherentExpiresAt),
      'adhesionCampaignEndsAt': Timestamp.fromDate(adhesionCampaignEndsAt),
      'bannerEnabled': bannerEnabled,
      'splashEnabled': splashEnabled,
      'helloAssoUrl': helloAssoUrl.trim(),
      'helloAssoSupportUrl': helloAssoSupportUrl.trim(),
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'ctaLabel': ctaLabel.trim(),
      'supportTitle': supportTitle.trim(),
      'supportSubtitle': supportSubtitle.trim(),
      'supportCtaLabel': supportCtaLabel.trim(),
      'splashTitle': splashTitle.trim(),
      'splashSubtitle': splashSubtitle.trim(),
      'splashCtaLabel': splashCtaLabel.trim(),
      'splashImageUrl': splashImageUrl.trim(),
      'memberCount': memberCount < 0 ? 0 : memberCount,
      'memberCountLabel': memberCountLabel.trim(),
      'useCustomBackground': useCustomBackground,
      'backgroundUrl': backgroundUrl.trim(),
      'trackingEnabled': trackingEnabled,
      'utmSource': utmSource.trim(),
      'utmMedium': utmMedium.trim(),
      'utmCampaign': utmCampaign.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  HelloAssoAdhesionConfig copyWith({
    DateTime? adherentExpiresAt,
    DateTime? adhesionCampaignEndsAt,
    bool? bannerEnabled,
    bool? splashEnabled,
    String? helloAssoUrl,
    String? helloAssoSupportUrl,
    String? title,
    String? subtitle,
    String? ctaLabel,
    String? supportTitle,
    String? supportSubtitle,
    String? supportCtaLabel,
    String? splashTitle,
    String? splashSubtitle,
    String? splashCtaLabel,
    String? splashImageUrl,
    int? memberCount,
    String? memberCountLabel,
    bool? useCustomBackground,
    String? backgroundUrl,
    bool? trackingEnabled,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
  }) {
    return HelloAssoAdhesionConfig(
      adherentExpiresAt: adherentExpiresAt ?? this.adherentExpiresAt,
      adhesionCampaignEndsAt:
          adhesionCampaignEndsAt ?? this.adhesionCampaignEndsAt,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      splashEnabled: splashEnabled ?? this.splashEnabled,
      helloAssoUrl: helloAssoUrl ?? this.helloAssoUrl,
      helloAssoSupportUrl: helloAssoSupportUrl ?? this.helloAssoSupportUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      supportTitle: supportTitle ?? this.supportTitle,
      supportSubtitle: supportSubtitle ?? this.supportSubtitle,
      supportCtaLabel: supportCtaLabel ?? this.supportCtaLabel,
      splashTitle: splashTitle ?? this.splashTitle,
      splashSubtitle: splashSubtitle ?? this.splashSubtitle,
      splashCtaLabel: splashCtaLabel ?? this.splashCtaLabel,
      splashImageUrl: splashImageUrl ?? this.splashImageUrl,
      memberCount: memberCount ?? this.memberCount,
      memberCountLabel: memberCountLabel ?? this.memberCountLabel,
      useCustomBackground: useCustomBackground ?? this.useCustomBackground,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      utmSource: utmSource ?? this.utmSource,
      utmMedium: utmMedium ?? this.utmMedium,
      utmCampaign: utmCampaign ?? this.utmCampaign,
    );
  }

  /// URL HelloAsso avec paramètres UTM (phase 1 — pas de metadata checkout côté app).
  String buildTrackedUrl({String? mediumOverride, String? urlOverride}) {
    var url = (urlOverride ?? helloAssoUrl).trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    if (!trackingEnabled) return uri.toString();

    final params = Map<String, String>.from(uri.queryParameters);
    if (utmSource.trim().isNotEmpty) {
      params['utm_source'] = utmSource.trim();
    }
    final medium = (mediumOverride ?? utmMedium).trim();
    if (medium.isNotEmpty) {
      params['utm_medium'] = medium;
    }
    if (utmCampaign.trim().isNotEmpty) {
      params['utm_campaign'] = utmCampaign.trim();
    }
    return uri.replace(queryParameters: params).toString();
  }

  String buildBannerTrackedUrl({DateTime? now}) {
    if (isAdhesionCampaignOpen(now)) return buildTrackedUrl();
    return buildTrackedUrl(
      urlOverride: helloAssoSupportUrl,
      mediumOverride: 'support_banner',
    );
  }
}

/// Flag mémoire process : « Plus tard » jusqu’au prochain cold start.
class AdhesionSplashSession {
  AdhesionSplashSession._();
  static final instance = AdhesionSplashSession._();

  bool dismissedThisSession = false;

  void dismiss() => dismissedThisSession = true;

  bool get shouldOffer => !dismissedThisSession;
}

class HelloAssoAdhesionService {
  HelloAssoAdhesionService._();
  static final HelloAssoAdhesionService instance = HelloAssoAdhesionService._();

  static const _configPath = 'app_config/helloasso_adhesion';

  /// URL publique du webhook (sans secret) — europe-west1.
  static String webhookUrlForProject(String projectId) =>
      'https://europe-west1-$projectId.cloudfunctions.net/helloAssoWebhook';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      FirebaseFirestore.instance.doc(_configPath);

  HelloAssoAdhesionConfig _lastConfig = HelloAssoAdhesionConfig.defaults;

  HelloAssoAdhesionConfig get lastKnownConfig => _lastConfig;

  Stream<HelloAssoAdhesionConfig> configStream() {
    return _configRef.snapshots().map((s) {
      _lastConfig = HelloAssoAdhesionConfig.fromMap(s.data());
      return _lastConfig;
    });
  }

  Future<HelloAssoAdhesionConfig> loadConfig() async {
    final snap = await _configRef.get();
    return HelloAssoAdhesionConfig.fromMap(snap.data());
  }

  Future<void> saveConfig(HelloAssoAdhesionConfig config) async {
    await _configRef.set(config.toMap(), SetOptions(merge: true));
  }

  /// Enregistre la date de fin et la propage aux adhérents actuellement actifs.
  Future<void> saveConfigAndRefreshActiveAdherents(
    HelloAssoAdhesionConfig config,
  ) async {
    await saveConfig(config);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('helloAsso.isAdherentActive', isEqualTo: true)
        .limit(500)
        .get();
    if (snap.docs.isEmpty) return;

    final ts = Timestamp.fromDate(config.adherentExpiresAt);
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = snap.docs.skip(i).take(400);
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'helloAsso.adherentExpiresAt': ts,
          'helloAsso.lastSyncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Log un clic bandeau / splash avant ouverture externe HelloAsso.
  Future<void> logBannerClick({String slot = 'home'}) async {
    try {
      await FirebaseFirestore.instance.collection('adhesion_clicks').add({
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'platform': defaultTargetPlatform.name,
        'slot': slot,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> clicksStream({int limit = 500}) {
    return FirebaseFirestore.instance
        .collection('adhesion_clicks')
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> donationsStream({int limit = 300}) {
    return FirebaseFirestore.instance
        .collection('donations')
        .where('source', isEqualTo: 'helloasso')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingMatchesStream() {
    return FirebaseFirestore.instance
        .collection('helloasso_pending_matches')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static bool isAdherentActive(Map<String, dynamic>? userData) {
    final ha = userData?['helloAsso'];
    if (ha is! Map) return false;
    final now = DateTime.now();
    if (ha['isAdherentActive'] == true) {
      final exp = ha['adherentExpiresAt'];
      if (exp is Timestamp && exp.toDate().isBefore(now)) return false;
      return true;
    }
    return false;
  }

  /// `true` once the signed-in user is an active HelloAsso member.
  /// Guests emit `false`. Until the first event, treat as unknown (hide promo).
  Stream<bool> watchCurrentUserIsAdherentActive() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<bool>.value(false);
      }
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snap) => isAdherentActive(snap.data()));
    });
  }

  /// Saisons réellement payées (`2026-2027`). L’expiration du statut courant
  /// ne retire pas les années déjà cotisées.
  static Set<String> paidSeasons(
    Map<String, dynamic>? userData, {
    DateTime? now,
  }) {
    final ha = userData?['helloAsso'];
    if (ha is! Map) return {};
    final out = <String>{};
    final raw = ha['adherentSeasons'];
    if (raw is List) {
      for (final item in raw) {
        final id = item.toString().trim();
        if (AdherentSeason.isValidId(id)) out.add(id);
      }
    }
    if (out.isEmpty && isAdherentActive(userData)) {
      final exp = ha['adherentExpiresAt'];
      if (exp is Timestamp) {
        out.add(AdherentSeason.idFor(exp.toDate()));
      } else {
        out.add(AdherentSeason.idFor(now ?? DateTime.now()));
      }
    }
    return out;
  }

  static double adherentTotalPaid(Map<String, dynamic>? userData) {
    final ha = userData?['helloAsso'];
    if (ha is Map) {
      final v = ha['adherentTotalPaid'] ?? ha['totalPaid'];
      if (v is num) return v.toDouble();
    }
    final legacy = userData?['totalDonations'];
    if (legacy is num) return legacy.toDouble();
    return 0;
  }

  static const numbersFileImportSource = 'numbers_file_import';

  /// Import CSV sans colonne montant : le backend a stocké 0, ce n’est pas un vrai 0 €.
  static bool isImportedAmountUnknown(Map<String, dynamic> data) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    if (amount > 0) return false;
    final importSource = (data['importSource'] ?? '').toString();
    final meta = data['metadata'];
    final metaSource =
        meta is Map ? (meta['source'] ?? '').toString() : '';
    final paymentId = (data['paymentId'] ?? '').toString();
    return importSource == numbersFileImportSource ||
        metaSource == numbersFileImportSource ||
        paymentId.startsWith('numbers_import_');
  }

  /// Libellé club : jamais « 0,00 € » pour un import sans montant.
  static String adhesionAmountLabel(
    Map<String, dynamic> data, {
    required String Function(double amount) formatMoney,
  }) {
    if (isImportedAmountUnknown(data)) {
      return 'Import HelloAsso · montant inconnu';
    }
    return formatMoney((data['amount'] as num?)?.toDouble() ?? 0);
  }

  Future<Map<String, dynamic>> linkPendingToAppEmail({
    required String pendingMatchId,
    required String appEmail,
  }) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('adminLinkHelloAssoPending');
    final result = await callable.call(<String, dynamic>{
      'pendingMatchId': pendingMatchId,
      'appEmail': appEmail.trim(),
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'ok': true};
  }

  /// Paiements attribués à l'app (metadata.source == dvcr_app ou champ sourceApp).
  static bool isAppAttributedPayment(Map<String, dynamic> data) {
    final meta = data['metadata'];
    if (meta is Map) {
      final src = (meta['source'] ?? '').toString().trim().toLowerCase();
      if (src == 'dvcr_app') return true;
    }
    return (data['sourceApp'] ?? '').toString().trim().toLowerCase() == 'dvcr_app';
  }
}
