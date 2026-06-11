import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/admin/admin_palette.dart';
import '../utils/remote_image_url.dart';

/// Aperçu image réseau admin (lien direct Wix `static.wixstatic.com`, etc.).
Widget adminBoundedImagePreview({
  required String url,
  required int revisionMillis,
  double aspectRatio = 3 / 2,
  double maxWidth = 280,
  double maxHeight = 132,
}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth;
        final capW = parentW.isFinite ? min(parentW, maxWidth) : maxWidth;
        var w = capW;
        var h = w / aspectRatio;
        if (h > maxHeight) {
          h = maxHeight;
          w = h * aspectRatio;
        }
        return SizedBox(
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              cacheBustedImageUrl(url.trim(), revisionMillis),
              fit: BoxFit.cover,
              headers: kDvcrImageHttpHeaders,
              errorBuilder: (context, error, stackTrace) => Container(
                color: adminGrey.withAlpha(40),
                alignment: Alignment.center,
                child: Text(
                  'Aperçu indisponible',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
