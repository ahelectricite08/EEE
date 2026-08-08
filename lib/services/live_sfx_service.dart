import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Sons live (jingles) — signal Firestore `live/current.sfx` → lecture fans.
///
/// TTL ~15 s pour éviter qu’un late joiner rejoue un vieux but.
/// Staff qui déclenche : [playLocalImmediate] pour feedback immédiat (indépendant
/// du retour casque micro) + bandeau « ne parle pas ».
class LiveSfxService extends ChangeNotifier {
  LiveSfxService._();
  static final LiveSfxService instance = LiveSfxService._();

  static const assetBut = 'sounds/but_cssa.mp3';
  static const maxAge = Duration(seconds: 15);
  /// Durée visuelle de secours si onPlayerComplete ne fire pas (~durée clip).
  static const fallbackPlaying = Duration(seconds: 10);

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<void>? _completeSub;
  String? _lastPlayedKey;
  DateTime? _skipFirestoreUntil;
  bool _started = false;
  bool _playing = false;
  String? _playingId;
  Timer? _playingFallback;

  bool get isPlaying => _playing;
  String? get playingId => _playingId;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
    } catch (_) {}
    _completeSub?.cancel();
    _completeSub = _player.onPlayerComplete.listen((_) {
      _setPlaying(false);
    });

    _sub = FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .snapshots()
        .listen(_onSnap, onError: (_) {});
  }

  /// Lecture locale immédiate (staff) — volume média système, pas le publish WHIP.
  Future<void> playLocalImmediate(String id) async {
    await start();
    final sfxId = id.trim().toLowerCase();
    if (sfxId != 'but') return;
    // Évite le double play quand le snapshot Firestore revient juste après.
    _skipFirestoreUntil = DateTime.now().add(const Duration(seconds: 20));
    await _playAsset(sfxId);
  }

  void _onSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    unawaited(_maybePlay(data['sfx']));
  }

  Future<void> _maybePlay(dynamic raw) async {
    if (raw is! Map) return;
    final id = (raw['id'] ?? '').toString().trim().toLowerCase();
    if (id.isEmpty || id != 'but') return;

    DateTime? at;
    final atRaw = raw['at'];
    if (atRaw is Timestamp) {
      at = atRaw.toDate();
    } else if (atRaw is DateTime) {
      at = atRaw;
    } else if (atRaw is int) {
      at = DateTime.fromMillisecondsSinceEpoch(atRaw);
    }
    if (at == null) return;

    final age = DateTime.now().difference(at);
    if (age.isNegative) {
      if (age.abs() > const Duration(seconds: 5)) return;
    } else if (age > maxAge) {
      return;
    }

    final key = '$id@${at.millisecondsSinceEpoch}';
    if (_lastPlayedKey == key) return;

    final skipUntil = _skipFirestoreUntil;
    if (skipUntil != null && DateTime.now().isBefore(skipUntil)) {
      _lastPlayedKey = key;
      return;
    }

    _lastPlayedKey = key;
    await _playAsset(id);
  }

  Future<void> _playAsset(String id) async {
    if (id != 'but') return;
    try {
      await _player.stop();
      _setPlaying(true, id: id);
      await _player.play(AssetSource(assetBut));
      _playingFallback?.cancel();
      _playingFallback = Timer(fallbackPlaying, () {
        if (_playing) _setPlaying(false);
      });
    } catch (e) {
      _setPlaying(false);
      debugPrint('LiveSfx play error: $e');
    }
  }

  void _setPlaying(bool value, {String? id}) {
    _playing = value;
    _playingId = value ? (id ?? _playingId) : null;
    if (!value) {
      _playingFallback?.cancel();
      _playingFallback = null;
    }
    notifyListeners();
  }

  /// Coupe le jingle en cours (libère AVAudioSession avant WHIP/WebRTC).
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } catch (_) {}
    _setPlaying(false);
  }

  Future<void> shutdown() async {
    _playingFallback?.cancel();
    await _completeSub?.cancel();
    _completeSub = null;
    await _sub?.cancel();
    _sub = null;
    _started = false;
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
