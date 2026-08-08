import 'package:flutter/foundation.dart';

/// Stub non-web : le son de test WHIP se lance depuis l’admin web.
class LiveRadioTestTone extends ChangeNotifier {
  LiveRadioTestTone._();
  static final LiveRadioTestTone instance = LiveRadioTestTone._();

  bool get isRunning => false;

  Future<void> start({Duration duration = const Duration(seconds: 20)}) async {
    throw UnsupportedError(
      'Le son de test se lance depuis l’admin web (navigateur).',
    );
  }

  Future<void> stop() async {}
}
