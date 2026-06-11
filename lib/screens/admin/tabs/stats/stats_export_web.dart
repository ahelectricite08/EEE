import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadPng(List<int> bytes, String filename) async {
  final base64 = base64Encode(bytes);
  (html.AnchorElement()
        ..href = 'data:image/png;base64,$base64'
        ..download = filename)
      .click();
}
