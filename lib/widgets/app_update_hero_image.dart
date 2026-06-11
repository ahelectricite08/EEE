import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/remote_image_url.dart';

/// Image bannière / écran mise à jour — URL externe (ex. lien direct Wix static).
class AppUpdateHeroImage extends StatelessWidget {
  final String? imageUrl;
  final int revisionMillis;
  final double height;
  final BorderRadius borderRadius;

  const AppUpdateHeroImage({
    super.key,
    required this.imageUrl,
    this.revisionMillis = 0,
    this.height = 120,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(14)),
  });

  static bool hasUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasUrl(imageUrl)) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.network(
          cacheBustedImageUrl(imageUrl!.trim(), revisionMillis),
          fit: BoxFit.cover,
          headers: kDvcrImageHttpHeaders,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return ColoredBox(
              color: AppColors.card,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold.withAlpha(180),
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
