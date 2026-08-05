import 'dart:async';
import 'dart:typed_data' show ByteBuffer, Uint8List;

// Même pattern que home_banner_section_web (FilePicker cassé en web release).
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Image choisie via `<input type="file">` (évite FilePicker `_instance`
/// non enregistré en build web release → LateInitializationError).
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
  final accept = allowedExtensions.map((e) => '.$e').join(',');
  final input = html.FileUploadInputElement()..accept = accept;
  input.click();

  final file = await input.onChange.first.then((_) => input.files?.first);
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;

  // ignore: avoid_dynamic_calls
  final bytes = Uint8List.view(
    (reader.result as dynamic).buffer as ByteBuffer,
  );
  if (bytes.isEmpty) {
    throw StateError('Fichier vide');
  }

  final name = file.name;
  final ext = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : 'png';
  if (!allowedExtensions.map((e) => e.toLowerCase()).contains(ext)) {
    throw StateError('Format non supporté ($ext)');
  }

  return PickedImageBytes(bytes: bytes, extension: ext, name: name);
}
