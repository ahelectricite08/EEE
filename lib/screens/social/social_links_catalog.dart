import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// URLs officielles déjà en prod — ne pas changer.
abstract final class SocialLinkUrls {
  static const site = 'https://www.dvcr.fr';
  static const facebook = 'https://www.facebook.com/drapeauvertcartonrouge';
  static const youtube = 'https://www.youtube.com/@drapeauvertcartonrouge';
  static const soundcloud = 'https://soundcloud.com/drapeauvertcartonrouge';
  static const applePodcasts =
      'https://podcasts.apple.com/fr/podcast/dvcr-lemission/id1770530094';
}

enum SocialBrand {
  youtube,
  instagram,
  tiktok,
  facebook,
  twitch,
  site,
  x,
  discord,
  soundcloud,
  applePodcasts,
}

enum SocialCardKind { feature, sheet }

class SocialNetworkSpec {
  final String id;
  final SocialBrand brand;
  final String title;
  final String handle;
  final String subtitle;
  final String cta;
  final String url;
  final bool enabled;
  final SocialCardKind kind;
  final String section;

  const SocialNetworkSpec({
    required this.id,
    required this.brand,
    required this.title,
    required this.handle,
    required this.subtitle,
    required this.cta,
    required this.url,
    this.enabled = true,
    this.kind = SocialCardKind.sheet,
    this.section = '',
  });

  bool get isOpenable => enabled && url.trim().isNotEmpty;

  SocialNetworkSpec copyWith({
    String? handle,
    String? url,
    bool? enabled,
  }) {
    return SocialNetworkSpec(
      id: id,
      brand: brand,
      title: title,
      handle: handle ?? this.handle,
      subtitle: subtitle,
      cta: cta,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      kind: kind,
      section: section,
    );
  }
}

/// Ordre éditorial média — pas alphabétique.
const kSocialCatalogDefaults = <SocialNetworkSpec>[
  SocialNetworkSpec(
    id: 'youtube',
    brand: SocialBrand.youtube,
    title: 'YouTube',
    handle: '@drapeauvertcartonrouge',
    subtitle: 'Lives, émissions, résumés et Shorts',
    cta: 'Voir la chaîne',
    url: SocialLinkUrls.youtube,
    kind: SocialCardKind.feature,
    section: 'Vidéo',
  ),
  SocialNetworkSpec(
    id: 'instagram',
    brand: SocialBrand.instagram,
    title: 'Instagram',
    handle: '',
    subtitle: 'Photos, stories et coulisses',
    cta: 'Suivre',
    url: '',
    section: 'Réseaux',
  ),
  SocialNetworkSpec(
    id: 'tiktok',
    brand: SocialBrand.tiktok,
    title: 'TikTok',
    handle: '',
    subtitle: 'Extraits et formats courts',
    cta: 'Suivre',
    url: '',
    section: 'Réseaux',
  ),
  SocialNetworkSpec(
    id: 'facebook',
    brand: SocialBrand.facebook,
    title: 'Facebook',
    handle: 'drapeauvertcartonrouge',
    subtitle: 'Actu, annonces et communauté',
    cta: 'Suivre',
    url: SocialLinkUrls.facebook,
    section: 'Réseaux',
  ),
  SocialNetworkSpec(
    id: 'twitch',
    brand: SocialBrand.twitch,
    title: 'Twitch',
    handle: '',
    subtitle: 'Lives et rediffusions',
    cta: 'Voir la chaîne',
    url: '',
    section: 'Vidéo',
  ),
  SocialNetworkSpec(
    id: 'site',
    brand: SocialBrand.site,
    title: 'Site officiel',
    handle: 'dvcr.fr',
    subtitle: 'Actus, blog et pages DVCR',
    cta: 'Visiter le site',
    url: SocialLinkUrls.site,
    section: 'Site',
  ),
  SocialNetworkSpec(
    id: 'x',
    brand: SocialBrand.x,
    title: 'X',
    handle: '',
    subtitle: 'Fil officiel',
    cta: 'Suivre',
    url: '',
    section: 'Réseaux',
  ),
  SocialNetworkSpec(
    id: 'discord',
    brand: SocialBrand.discord,
    title: 'Discord',
    handle: '',
    subtitle: 'Salon de la communauté',
    cta: 'Rejoindre',
    url: '',
    section: 'Réseaux',
  ),
  SocialNetworkSpec(
    id: 'soundcloud',
    brand: SocialBrand.soundcloud,
    title: 'SoundCloud',
    handle: 'drapeauvertcartonrouge',
    subtitle: 'Les émissions en audio',
    cta: 'Écouter',
    url: SocialLinkUrls.soundcloud,
    section: 'Émission',
  ),
  SocialNetworkSpec(
    id: 'applePodcasts',
    brand: SocialBrand.applePodcasts,
    title: 'Apple Podcasts',
    handle: 'DVCR L\'ÉMISSION',
    subtitle: 'S’abonner depuis Apple',
    cta: 'S’abonner',
    url: SocialLinkUrls.applePodcasts,
    section: 'Émission',
  ),
];

abstract final class SocialLinksActions {
  static Future<void> open(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      _toast(context, 'Impossible d\'ouvrir ce lien pour le moment.');
      return;
    }
    if (!await canLaunchUrl(uri)) {
      if (context.mounted) {
        _toast(context, 'Impossible d\'ouvrir ce lien pour le moment.');
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void copy(BuildContext context, String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    Clipboard.setData(ClipboardData(text: trimmed));
    HapticFeedback.lightImpact();
    _toast(context, 'Lien copié dans le presse-papiers');
  }

  static void _toast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
