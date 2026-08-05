import 'dart:typed_data';

/// Résultat d’un enregistrement dans la photothèque / galerie.
enum SaveImageToGalleryResult {
  success,
  denied,
  unsupported,
}

/// Stub web / plateformes sans galerie native.
Future<SaveImageToGalleryResult> saveImageToGallery(
  Uint8List bytes, {
  required String name,
}) async =>
    SaveImageToGalleryResult.unsupported;
