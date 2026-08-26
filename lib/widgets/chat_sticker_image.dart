import 'package:flutter/material.dart';

import 'dvcr_network_image.dart';

/// Sticker / logo chat (souvent Wix) : ratio conservé, sans rognage.
class ChatStickerImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final BorderRadius borderRadius;
  final Widget? errorFallback;

  const ChatStickerImage({
    super.key,
    required this.imageUrl,
    this.size = 20,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.errorFallback,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) return errorFallback ?? const SizedBox.shrink();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DvcrNetworkImage(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          cacheWidth: dvcrImageCacheWidth(context, size, min: 32, max: 256),
          errorBuilder: (context, error, stackTrace) =>
              errorFallback ??
              Icon(
                Icons.broken_image_outlined,
                size: size * 0.85,
                color: Colors.grey,
              ),
        ),
      ),
    );
  }
}
