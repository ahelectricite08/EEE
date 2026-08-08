import 'dart:async';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
// ignore: deprecated_member_use
import 'dart:js_util' as js_util;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Son de test admin web : oscillateur → WHIP via proxy Cloud Functions (CORS).
///
/// WebRTC + MediaStream restent en JS natif (évite le cast dart:html
/// `MediaStream` / `MediaStreamTrack` qui casse en build minifié).
class LiveRadioTestTone extends ChangeNotifier {
  LiveRadioTestTone._();
  static final LiveRadioTestTone instance = LiveRadioTestTone._();

  static const _jsKey = '__dvcrLiveRadioTestTone';

  bool _running = false;
  int _generation = 0;
  Timer? _autoStop;
  String? _whipLocation;

  bool get isRunning => _running;

  Future<void> start({Duration duration = const Duration(seconds: 20)}) async {
    await stop();
    final gen = ++_generation;
    _running = true;
    notifyListeners();

    try {
      final session = await _startJsSession();
      if (gen != _generation) {
        _invokeJsStop();
        return;
      }

      final sdp = (session['sdp'] ?? '').toString().trim();
      if (sdp.isEmpty) {
        throw StateError('Offre WebRTC vide');
      }

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('postLiveRadioWhipOffer');
      final result = await callable.call(<String, dynamic>{'sdp': sdp});
      if (gen != _generation) {
        _invokeJsStop();
        return;
      }

      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = (data['sdp'] ?? '').toString().trim();
      if (answer.isEmpty) {
        throw StateError('Réponse WHIP vide');
      }
      final location = (data['location'] ?? '').toString().trim();
      _whipLocation = location.isEmpty ? null : location;

      await _setJsRemoteAnswer(answer);

      _autoStop?.cancel();
      _autoStop = Timer(duration, () {
        stop();
      });
    } on FirebaseFunctionsException catch (e) {
      await stop();
      final msg = (e.message ?? '').trim();
      throw StateError(
        msg.isNotEmpty ? msg : 'Son test impossible (${e.code})',
      );
    } catch (e) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation++;
    _autoStop?.cancel();
    _autoStop = null;

    final location = _whipLocation;
    _whipLocation = null;

    if (location != null && location.isNotEmpty) {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('deleteLiveRadioWhipSession');
        await callable.call(<String, dynamic>{'location': location});
      } catch (_) {}
    }

    _invokeJsStop();

    if (_running) {
      _running = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _startJsSession() async {
    // Tout le graphe audio + PC reste en JS → SDP string seulement vers Dart.
    final promise = js.context.callMethod('eval', [
      r'''
      (async function () {
        var key = '__dvcrLiveRadioTestTone';
        try {
          if (window[key] && typeof window[key].stop === 'function') {
            window[key].stop();
          }
        } catch (e) {}

        var AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) throw new Error('AudioContext indisponible');
        var ctx = new AC();
        if (ctx.state === 'suspended' && ctx.resume) {
          try { await ctx.resume(); } catch (e) {}
        }

        var osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.value = 880;
        var gain = ctx.createGain();
        gain.gain.value = 0.18;
        var dest = ctx.createMediaStreamDestination();
        osc.connect(gain);
        gain.connect(dest);
        osc.start();

        var pc = new RTCPeerConnection({
          sdpSemantics: 'unified-plan',
          iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
        });
        dest.stream.getAudioTracks().forEach(function (t) {
          pc.addTrack(t, dest.stream);
        });

        var offer = await pc.createOffer({
          offerToReceiveAudio: false,
          offerToReceiveVideo: false
        });
        await pc.setLocalDescription(offer);

        await new Promise(function (resolve) {
          if (pc.iceGatheringState === 'complete') {
            resolve();
            return;
          }
          var done = false;
          var finish = function () {
            if (done) return;
            done = true;
            resolve();
          };
          pc.addEventListener('icecandidate', function (ev) {
            if (!ev.candidate) finish();
          });
          pc.addEventListener('icegatheringstatechange', function () {
            if (pc.iceGatheringState === 'complete') finish();
          });
          setTimeout(finish, 8000);
        });

        var stop = function () {
          try { osc.stop(0); } catch (e) {}
          try { osc.disconnect(); } catch (e) {}
          try { gain.disconnect(); } catch (e) {}
          try { pc.close(); } catch (e) {}
          try { ctx.close(); } catch (e) {}
          try { delete window[key]; } catch (e) {}
        };

        window[key] = {
          pc: pc,
          stop: stop,
          setRemoteAnswer: async function (answerSdp) {
            await pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
          }
        };

        var local = pc.localDescription;
        return { sdp: local && local.sdp ? local.sdp : '' };
      })()
      ''',
    ]);

    final raw = await js_util.promiseToFuture(promise);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is js.JsObject) {
      return <String, dynamic>{
        'sdp': raw['sdp'],
      };
    }
    // dartify for JS objects from promise
    final dartified = js_util.dartify(raw);
    if (dartified is Map) {
      return Map<String, dynamic>.from(dartified);
    }
    throw StateError('Session Son test invalide');
  }

  Future<void> _setJsRemoteAnswer(String answerSdp) async {
    final session = js.context[_jsKey];
    if (session == null) {
      throw StateError('Session Son test perdue');
    }
    final fn = (session as js.JsObject)['setRemoteAnswer'];
    if (fn == null) {
      throw StateError('Session Son test invalide');
    }
    final result = (fn as js.JsFunction).apply([answerSdp], thisArg: session);
    if (result != null) {
      await js_util.promiseToFuture(result);
    }
  }

  void _invokeJsStop() {
    try {
      final session = js.context[_jsKey];
      if (session is js.JsObject) {
        final stop = session['stop'];
        if (stop is js.JsFunction) {
          stop.apply([], thisArg: session);
        }
      }
    } catch (_) {}
    try {
      js.context[_jsKey] = null;
    } catch (_) {}
  }
}
