import 'package:cloud_firestore/cloud_firestore.dart';

/// Branding souvenir match — feature + logo **partenaire** optionnel.
/// Firestore `app_config/souvenir_branding`.
class SouvenirBranding {
  static const String firestoreDocId = 'souvenir_branding';
  static const String storageFolder = 'match_souvenir';
  static const String defaultStorageFileName = 'partner_logo.png';

  /// Activer l’entrée fan « Créer mon souvenir » (CTA + menu partage).
  /// Défaut `true` si absent du doc (comportement historique).
  final bool featureEnabled;

  /// Afficher le logo partenaire sur le cadre souvenir.
  final bool enabled;

  /// URL publique Storage du logo partenaire.
  final String logoUrl;

  /// Chemin Storage (ex. `match_souvenir/partner_logo.png`).
  final String logoPath;

  /// Pour invalider le cache image côté app.
  final int revisionMillis;

  const SouvenirBranding({
    this.featureEnabled = true,
    this.enabled = false,
    this.logoUrl = '',
    this.logoPath = '',
    this.revisionMillis = 0,
  });

  static const SouvenirBranding defaults = SouvenirBranding();

  bool get hasLogo => logoUrl.trim().isNotEmpty;

  /// Cadre souvenir + bandeau fiche : toggle ON + URL présente.
  bool get showOnFrame => enabled && hasLogo;

  /// Bandeau PARTENAIRE sous le hero fiche. Rien si switch OFF ou URL vide.
  bool get showOnFiche {
    if (!showOnFrame) return false;
    final url = logoUrl.trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  factory SouvenirBranding.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return SouvenirBranding(
      featureEnabled: _featureEnabledFrom(data['featureEnabled']),
      enabled: data['enabled'] == true,
      logoUrl: (data['logoUrl'] ?? '').toString().trim(),
      logoPath: (data['logoPath'] ?? '').toString().trim(),
      revisionMillis: _revisionMillisFrom(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'featureEnabled': featureEnabled,
        'enabled': enabled,
        'logoUrl': logoUrl.trim(),
        'logoPath': logoPath.trim(),
      };

  SouvenirBranding copyWith({
    bool? featureEnabled,
    bool? enabled,
    String? logoUrl,
    String? logoPath,
    int? revisionMillis,
  }) {
    return SouvenirBranding(
      featureEnabled: featureEnabled ?? this.featureEnabled,
      enabled: enabled ?? this.enabled,
      logoUrl: logoUrl ?? this.logoUrl,
      logoPath: logoPath ?? this.logoPath,
      revisionMillis: revisionMillis ?? this.revisionMillis,
    );
  }

  /// Absent / null → ON (rétrocompat). Seul `false` explicite désactive.
  static bool _featureEnabledFrom(dynamic v) {
    if (v == null) return true;
    return v == true;
  }

  static int _revisionMillisFrom(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    return 0;
  }
}
