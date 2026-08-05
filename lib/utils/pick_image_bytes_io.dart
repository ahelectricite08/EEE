import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Image choisie (mobile / desktop) via FilePicker + bytes.
class PickedImageBytes {
  const PickedImageBytes({
    required this.bytes,
    required this.extension,
    required this.name,
  });

  final Uint8List bytes;
  final String extension;
  final String name;
}

/// PNG / JPG / WebP. Retourne `null` si annulation.
Future<PickedImageBytes?> pickImageBytes({
  List<String> allowedExtensions = const ['png', 'jpg', 'jpeg', 'webp'],
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Fichier vide — réessaie.');
  }

  final name = file.name;
  final ext = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : (file.extension ?? 'png').toLowerCase();

  return PickedImageBytes(bytes: bytes, extension: ext, name: name);
}
