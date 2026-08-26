import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'social_links_catalog.dart';

/// Overlay Firestore optionnel — `app_config/social_links` et
/// `app_settings/social_links`. Doc absente = catalogue par défaut.
///
/// Un réseau n’est masqué que si l’admin le désactive explicitement.
/// Une URL vide dans Firestore ne remplace pas l’URL par défaut
/// (évite d’effacer un lien officiel par un champ oublié).
class SocialLinksOverlay {
  const SocialLinksOverlay(this._byId);

  final Map<String, _OverlayEntry> _byId;

  static const empty = SocialLinksOverlay({});

  factory SocialLinksOverlay.fromMaps(Iterable<Map<String, dynamic>> maps) {
    final merged = <String, _OverlayEntry>{};
    for (final data in maps) {
      if (data.isEmpty) continue;
      for (final spec in kSocialCatalogDefaults) {
        final next = _readEntry(data, spec);
        if (next == null) continue;
        final prev = merged[spec.id];
        merged[spec.id] = _OverlayEntry(
          url: (next.url ?? prev?.url),
          enabled: next.enabled ?? prev?.enabled,
          handle: (next.handle ?? prev?.handle),
        );
      }
    }
    return SocialLinksOverlay(merged);
  }

  List<SocialNetworkSpec> resolve() {
    return resolveAll().where((s) => s.isOpenable).toList(growable: false);
  }

  /// Catalogue complet (y compris réseaux désactivés) — admin.
  List<SocialNetworkSpec> resolveAll() {
    return [
      for (final spec in kSocialCatalogDefaults)
        spec.copyWith(
          url: _byId[spec.id]?.url ?? spec.url,
          enabled: _byId[spec.id]?.enabled ?? spec.enabled,
          handle: _handleFor(spec),
        ),
    ];
  }

  String _handleFor(SocialNetworkSpec spec) {
    final overlay = _byId[spec.id]?.handle?.trim();
    if (overlay != null && overlay.isNotEmpty) return overlay;
    if (spec.handle.trim().isNotEmpty) return spec.handle;
    return _handleFromUrl(_byId[spec.id]?.url ?? spec.url, spec.brand);
  }

  static _OverlayEntry? _readEntry(
    Map<String, dynamic> data,
    SocialNetworkSpec spec,
  ) {
    final keys = _keysFor(spec);
    String? url;
    String? handle;
    bool? enabled;

    for (final key in keys) {
      final raw = data[key];
      if (raw is String && raw.trim().startsWith('http')) {
        url ??= raw.trim();
      } else if (raw is Map) {
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        url ??= _http(map['url'] ?? map['href'] ?? map['link']);
        handle ??= _nonEmpty(map['handle'] ?? map['username'] ?? map['at']);
        enabled ??= _bool(map['enabled']) ??
            _bool(map['visible']) ??
            _bool(map['show']) ??
            (_bool(map['hidden']) == true ? false : null) ??
            (_bool(map['disabled']) == true ? false : null);
      }
    }

    enabled ??= _bool(data['${spec.id}Enabled']) ??
        _bool(data['${spec.id}Visible']);

    final hiddenMap = data['hidden'];
    if (hiddenMap is Map && hiddenMap[spec.id] == true) enabled = false;
    final enabledMap = data['enabled'];
    if (enabledMap is Map && enabledMap[spec.id] == false) enabled = false;
    final visibleMap = data['visible'];
    if (visibleMap is Map && visibleMap[spec.id] == false) enabled = false;

    if (url == null && handle == null && enabled == null) return null;
    return _OverlayEntry(url: url, enabled: enabled, handle: handle);
  }

  static List<String> _keysFor(SocialNetworkSpec spec) {
    switch (spec.id) {
      case 'youtube':
        return ['youtube', 'youtubeUrl', 'youtube_url'];
      case 'instagram':
        return ['instagram', 'instagramUrl', 'instagram_url', 'insta'];
      case 'tiktok':
        return ['tiktok', 'tiktokUrl', 'tiktok_url'];
      case 'facebook':
        return ['facebook', 'facebookUrl', 'facebook_url', 'fb'];
      case 'site':
        return ['site', 'siteUrl', 'site_url', 'website', 'wix', 'wixUrl'];
      case 'x':
        return ['x', 'twitter', 'xUrl', 'twitterUrl', 'twitter_url'];
      case 'discord':
        return ['discord', 'discordUrl', 'discord_url'];
      case 'soundcloud':
        return ['soundcloud', 'soundcloudUrl', 'soundcloud_url'];
      case 'applePodcasts':
        return [
          'applePodcasts',
          'applePodcastsUrl',
          'apple_podcasts',
          'apple',
          'podcast',
          'podcasts',
        ];
      default:
        return [spec.id, '${spec.id}Url'];
    }
  }

  static String _handleFromUrl(String url, SocialBrand brand) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return '';
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) {
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    }
    var last = segs.last;
    if (last == 'streams' || last == 'shorts' || last == 'videos') {
      last = segs.length > 1 ? segs[segs.length - 2] : last;
    }
    if (brand == SocialBrand.youtube ||
        brand == SocialBrand.instagram ||
        brand == SocialBrand.tiktok) {
      return last.startsWith('@') ? last : '@$last';
    }
    if (brand == SocialBrand.site) {
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    }
    return last.startsWith('@') ? last.substring(1) : last;
  }

  static String? _http(Object? v) {
    final s = v?.toString().trim() ?? '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return null;
  }

  static String? _nonEmpty(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static bool? _bool(Object? v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'oui') return true;
      if (s == 'false' || s == '0' || s == 'non') return false;
    }
    return null;
  }
}

class _OverlayEntry {
  const _OverlayEntry({this.url, this.enabled, this.handle});
  final String? url;
  final bool? enabled;
  final String? handle;
}

abstract final class SocialLinksSettings {
  static const configDocId = 'social_links';

  static Stream<List<SocialNetworkSpec>> watchVisible() {
    final db = FirebaseFirestore.instance;
    return Stream<List<SocialNetworkSpec>>.multi((controller) {
      Map<String, dynamic> config = const {};
      Map<String, dynamic> settings = const {};
      var gotConfig = false;
      var gotSettings = false;

      void emit() {
        if (!gotConfig || !gotSettings) return;
        controller.add(
          SocialLinksOverlay.fromMaps([config, settings]).resolve(),
        );
      }

      final subConfig = db
          .collection('app_config')
          .doc(configDocId)
          .snapshots()
          .listen((snap) {
        config = snap.data() ?? const {};
        gotConfig = true;
        emit();
      }, onError: (_) {
        gotConfig = true;
        emit();
      });
      final subSettings = db
          .collection('app_settings')
          .doc(configDocId)
          .snapshots()
          .listen((snap) {
        settings = snap.data() ?? const {};
        gotSettings = true;
        emit();
      }, onError: (_) {
        gotSettings = true;
        emit();
      });

      controller
        ..onCancel = () {
          subConfig.cancel();
          subSettings.cancel();
        }
        ..add(SocialLinksOverlay.empty.resolve());
    });
  }

  /// Catalogue admin (réseaux masqués inclus).
  static Stream<List<SocialNetworkSpec>> watchAll() {
    final db = FirebaseFirestore.instance;
    return Stream<List<SocialNetworkSpec>>.multi((controller) {
      Map<String, dynamic> config = const {};
      Map<String, dynamic> settings = const {};
      var gotConfig = false;
      var gotSettings = false;

      void emit() {
        if (!gotConfig || !gotSettings) return;
        controller.add(
          SocialLinksOverlay.fromMaps([config, settings]).resolveAll(),
        );
      }

      final subConfig = db
          .collection('app_config')
          .doc(configDocId)
          .snapshots()
          .listen((snap) {
        config = snap.data() ?? const {};
        gotConfig = true;
        emit();
      }, onError: (_) {
        gotConfig = true;
        emit();
      });
      final subSettings = db
          .collection('app_settings')
          .doc(configDocId)
          .snapshots()
          .listen((snap) {
        settings = snap.data() ?? const {};
        gotSettings = true;
        emit();
      }, onError: (_) {
        gotSettings = true;
        emit();
      });

      controller
        ..onCancel = () {
          subConfig.cancel();
          subSettings.cancel();
        }
        ..add(SocialLinksOverlay.empty.resolveAll());
    });
  }

  /// Écrit `app_config/social_links` — mêmes clés que le reader overlay.
  static Future<void> saveOverlay(List<SocialNetworkSpec> specs) async {
    final payload = <String, dynamic>{
      for (final spec in specs)
        spec.id: {
          'url': spec.url.trim(),
          'handle': spec.handle.trim(),
          'enabled': spec.enabled,
        },
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc(configDocId)
        .set(payload, SetOptions(merge: true));
  }
}
