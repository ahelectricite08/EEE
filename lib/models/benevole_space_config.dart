/// Configuration admin de l'espace bénévoles (`app_config/benevole_space`).
class BenevoleSpaceConfig {
  static const String defaultGoogleSheetUrl =
      'https://docs.google.com/spreadsheets/d/1ot2idwooVU81Pc6XMofUvfuf2dHF1lgBjbaHwRRqIgY/edit?gid=1646454361';

  final bool enabled;
  final String googleSheetUrl;
  final String googleSheetTitle;

  const BenevoleSpaceConfig({
    this.enabled = true,
    this.googleSheetUrl = defaultGoogleSheetUrl,
    this.googleSheetTitle = 'Planning bénévoles',
  });

  factory BenevoleSpaceConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return const BenevoleSpaceConfig();
    final url = (data['googleSheetUrl'] ?? '').toString().trim();
    return BenevoleSpaceConfig(
      enabled: data['enabled'] != false,
      googleSheetUrl: url.isEmpty ? defaultGoogleSheetUrl : url,
      googleSheetTitle: (data['googleSheetTitle'] ?? 'Planning bénévoles')
          .toString()
          .trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'googleSheetUrl': googleSheetUrl,
        'googleSheetTitle': googleSheetTitle,
      };
}
