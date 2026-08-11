import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/match_model.dart';
import '../navigation/main_shell_insets.dart';
import '../screens/matches/match_detail_palette.dart';

/// Apps GPS ouvertes depuis la fiche match (« Y aller »).
enum StadiumMapsApp {
  googleMaps,
  appleMaps,
  waze,
}

extension StadiumMapsAppX on StadiumMapsApp {
  String get labelFr {
    switch (this) {
      case StadiumMapsApp.googleMaps:
        return 'Google Maps';
      case StadiumMapsApp.appleMaps:
        return 'Apple Plans';
      case StadiumMapsApp.waze:
        return 'Waze';
    }
  }

  IconData get icon {
    switch (this) {
      case StadiumMapsApp.googleMaps:
        return Icons.map_rounded;
      case StadiumMapsApp.appleMaps:
        return Icons.map_outlined;
      case StadiumMapsApp.waze:
        return Icons.navigation_rounded;
    }
  }
}

/// Lance Google Maps / Apple Plans / Waze via `url_launcher`.
///
/// Coyote (`coyote://` / `icoyote://`) n’a pas de schéma public documenté
/// pour une recherche ou une navigation — volontairement omis.
abstract final class StadiumMapsLauncher {
  StadiumMapsLauncher._();

  static const _homeStadiumFallback = 'Stade Louis Dugauguez';
  static const _homeCityFallback = 'Sedan';

  /// `lieu`/`stadium` + `ville`/`city` ; domicile CSSA → fallback stade Sedan.
  static String? resolveQuery(MatchModel match) {
    final lieu = (match.lieu ?? '').trim();
    final ville = (match.ville ?? match.city ?? '').trim();
    if (lieu.isNotEmpty && ville.isNotEmpty) {
      if (lieu.toLowerCase().contains(ville.toLowerCase())) return lieu;
      return '$lieu, $ville';
    }
    if (lieu.isNotEmpty) return lieu;
    if (ville.isNotEmpty) return ville;
    if (match.isSedanHome) {
      return '$_homeStadiumFallback, $_homeCityFallback';
    }
    return null;
  }

  static bool canNavigate(MatchModel match) =>
      (resolveQuery(match) ?? '').isNotEmpty;

  static List<StadiumMapsApp> availableApps() {
    if (kIsWeb) return const [StadiumMapsApp.googleMaps, StadiumMapsApp.waze];
    final apps = <StadiumMapsApp>[StadiumMapsApp.googleMaps];
    if (Platform.isIOS || Platform.isMacOS) {
      apps.add(StadiumMapsApp.appleMaps);
    }
    apps.add(StadiumMapsApp.waze);
    return apps;
  }

  static Uri _uriFor(StadiumMapsApp app, String query) {
    final q = Uri.encodeComponent(query);
    switch (app) {
      case StadiumMapsApp.googleMaps:
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$q',
        );
      case StadiumMapsApp.appleMaps:
        return Uri.parse('https://maps.apple.com/?q=$q');
      case StadiumMapsApp.waze:
        return Uri.parse('https://waze.com/ul?q=$q&navigate=yes');
    }
  }

  static Future<bool> open(StadiumMapsApp app, String query) async {
    final uri = _uriFor(app, query);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Bottom sheet choix d’app — labels FR.
  static Future<void> showPicker(BuildContext context, MatchModel match) {
    final query = resolveQuery(match);
    if (query == null || query.isEmpty) return Future.value();

    final apps = availableApps();
    return showDvcrModalBottomSheet<void>(
      context: context,
      backgroundColor: MatchDetailPalette.card,
      builder: (ctx) {
        return Padding(
          padding: MainShellInsets.sheetContentPadding(ctx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MatchDetailPalette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Y ALLER',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MatchDetailPalette.gold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                query,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MatchDetailPalette.grey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ...apps.map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: MatchDetailPalette.bg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final ok = await open(app, query);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Impossible d’ouvrir ${app.labelFr}.',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              app.icon,
                              color: MatchDetailPalette.green,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                app.labelFr,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: MatchDetailPalette.text,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: MatchDetailPalette.grey.withAlpha(160),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
