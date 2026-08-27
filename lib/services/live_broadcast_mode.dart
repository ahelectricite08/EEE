/// Retransmission vidéo vs live « non retransmis » (radio commentaire).
abstract final class LiveBroadcastMode {
  /// `streamBroadcast == true` (ou URL stream si le flag manque) = retransmis.
  static bool isRetransmitted(Map<String, dynamic>? live) {
    if (live == null) return false;
    if (live['streamBroadcast'] is bool) {
      return live['streamBroadcast'] as bool;
    }
    return ((live['url'] as String?) ?? '').trim().isNotEmpty;
  }
}
