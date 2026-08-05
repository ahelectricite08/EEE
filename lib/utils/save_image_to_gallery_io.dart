import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Résultat d’un enregistrement dans la photothèque / galerie.
enum SaveImageToGalleryResult {
  success,
  denied,
  unsupported,
}

/// Enregistre une image dans la galerie (iOS / Android) via [gal].
Future<SaveImageToGalleryResult> saveImageToGallery(
  Uint8List bytes, {
  required String name,
}) async {
  final hasAccess = await Gal.hasAccess();
  if (!hasAccess) {
    final granted = await Gal.requestAccess();
    if (!granted) return SaveImageToGalleryResult.denied;
  }
  await Gal.putImageBytes(bytes, name: name);
  return SaveImageToGalleryResult.success;
}
