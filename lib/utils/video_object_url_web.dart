import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? createVideoObjectUrl(Uint8List bytes, {String mime = 'video/mp4'}) {
  if (bytes.isEmpty) return null;
  final blob = html.Blob([bytes], mime);
  return html.Url.createObjectUrlFromBlob(blob);
}

void revokeVideoObjectUrl(String? url) {
  if (url == null || url.isEmpty) return;
  html.Url.revokeObjectUrl(url);
}
