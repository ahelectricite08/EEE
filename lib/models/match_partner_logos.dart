import 'package:cloud_firestore/cloud_firestore.dart';

/// Logos partenaires par défaut (note du match + homme du match).
/// Firestore `app_config/match_partner_logos`.
/// Le logo souvenir reste sur `app_config/souvenir_branding`.
class MatchPartnerLogos {
  static const String firestoreDocId = 'match_partner_logos';
  static const String storageFolder = 'match_partner_logos';

  final String matchRatingLogoUrl;
  final String matchRatingLogoPath;
  final String motmLogoUrl;
  final String motmLogoPath;
  final int revisionMillis;

  const MatchPartnerLogos({
    this.matchRatingLogoUrl = '',
    this.matchRatingLogoPath = '',
    this.motmLogoUrl = '',
    this.motmLogoPath = '',
    this.revisionMillis = 0,
  });

  static const MatchPartnerLogos defaults = MatchPartnerLogos();

  bool get hasMatchRatingLogo => matchRatingLogoUrl.trim().isNotEmpty;
  bool get hasMotmLogo => motmLogoUrl.trim().isNotEmpty;

  factory MatchPartnerLogos.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return MatchPartnerLogos(
      matchRatingLogoUrl: (data['matchRatingLogoUrl'] ?? '').toString().trim(),
      matchRatingLogoPath:
          (data['matchRatingLogoPath'] ?? '').toString().trim(),
      motmLogoUrl: (data['motmLogoUrl'] ?? '').toString().trim(),
      motmLogoPath: (data['motmLogoPath'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFrom(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'matchRatingLogoUrl': matchRatingLogoUrl.trim(),
        'matchRatingLogoPath': matchRatingLogoPath.trim(),
        'motmLogoUrl': motmLogoUrl.trim(),
        'motmLogoPath': motmLogoPath.trim(),
      };

  static int _revisionMillisFrom(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    return 0;
  }
}

enum MatchPartnerLogoSlot { matchRating, motm }
