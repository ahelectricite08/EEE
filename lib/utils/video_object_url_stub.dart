import 'dart:typed_data';

/// Stub hors web : pas d'object URL.
String? createVideoObjectUrl(Uint8List bytes, {String mime = 'video/mp4'}) =>
    null;

void revokeVideoObjectUrl(String? url) {}
