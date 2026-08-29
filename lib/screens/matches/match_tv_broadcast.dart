import '../social/social_links_catalog.dart';

/// Logos TV de la fiche match — URLs du catalogue NOS RÉSEAUX, jamais par match.
abstract final class MatchTvBroadcast {
  static const ids = <String>['youtube', 'facebook', 'twitch'];

  /// Rangée visuelle : YouTube, Facebook, Twitch — même sans URL Twitch.
  static List<SocialNetworkSpec> row(Iterable<SocialNetworkSpec> social) {
    final byId = {for (final s in kSocialCatalogDefaults) s.id: s};
    for (final s in social) {
      byId[s.id] = s;
    }
    return [
      for (final id in ids)
        if (byId[id] != null && byId[id]!.enabled) byId[id]!,
    ];
  }

  static List<SocialNetworkSpec> platforms(Iterable<SocialNetworkSpec> social) {
    return row(social).where((s) => s.isOpenable).toList(growable: false);
  }
}
