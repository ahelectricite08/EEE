import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_policy_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_update_hero_image.dart';

/// Écran bloquant : mise à jour obligatoire (store).
class ForceUpdateScreen extends StatelessWidget {
  final AppUpdateRequired update;
  final VoidCallback? onRetry;

  const ForceUpdateScreen({
    super.key,
    required this.update,
    this.onRetry,
  });

  static const _gold = AppColors.gold;
  static const _green = AppColors.green;

  @override
  Widget build(BuildContext context) {
    final hasImage = AppUpdateHeroImage.hasUrl(update.imageUrl);

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  if (hasImage) ...[
                    AppUpdateHeroImage(
                      imageUrl: update.imageUrl,
                      revisionMillis: update.imageRevisionMillis,
                      height: 180,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _green.withAlpha(40),
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold.withAlpha(90)),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 44,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    update.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    update.message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.grey,
                    ),
                  ),
                  if (update.currentVersionLabel.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _InfoChip(
                      label: 'Ta version',
                      value: update.currentVersionLabel,
                    ),
                    const SizedBox(height: 8),
                    _InfoChip(
                      label: 'Version minimale',
                      value: update.requiredVersionLabel,
                    ),
                  ],
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _openStore(update.storeUrl),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Ouvrir le store',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onRetry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: BorderSide(color: _gold.withAlpha(120)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Vérifier à nouveau',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.grey),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
