import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_dismiss_service.dart';
import '../services/app_version_policy_service.dart';
import '../theme/app_colors.dart';
import 'app_update_hero_image.dart';

/// Bannière non bloquante : nouvelle version sur le store.
class AppUpdateOptionalBanner extends StatelessWidget {
  final AppUpdateOptional prompt;
  final VoidCallback? onDismissed;

  const AppUpdateOptionalBanner({
    super.key,
    required this.prompt,
    this.onDismissed,
  });

  static const _gold = AppColors.gold;

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _later() async {
    await AppUpdateDismissService.dismissUntilNewerThan(prompt.latestBuild);
    onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final hasImage = AppUpdateHeroImage.hasUrl(prompt.imageUrl);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2418),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withAlpha(140)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage)
                AppUpdateHeroImage(
                  imageUrl: prompt.imageUrl,
                  revisionMillis: prompt.imageRevisionMillis,
                  height: 100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasImage)
                          Icon(
                            Icons.system_update_alt_rounded,
                            color: _gold,
                            size: 22,
                          ),
                        if (!hasImage) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prompt.title,
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                prompt.message,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: _later,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: AppColors.grey.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _later,
                          child: Text(
                            'Plus tard',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => _openStore(prompt.storeUrl),
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Mettre à jour',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
