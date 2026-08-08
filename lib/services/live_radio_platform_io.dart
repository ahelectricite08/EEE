import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'live_radio_hls_player.dart';
import 'live_radio_service.dart';
import 'live_sfx_service.dart';
import 'podcast_controller.dart';

/// Implémentation native : WHIP (publish) + WHEP (écoute) + HLS (fallback).
LiveRadioPlatform createLiveRadioPlatform() => LiveRadioPlatformIo();

abstract class LiveRadioPlatform {
  void Function()? onDisconnected;

  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  });

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setMonitorEnabled(bool enabled);

  Future<void> setMonitorVolume(double volume);

  Future<void> disconnect();
}

class LiveRadioPlatformIo implements LiveRadioPlatform {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _whipResourceUrl;
  String? _whepResourceUrl;
  Map<String, String>? _whipAuthHeaders;
  final LiveRadioHlsPlayer _hls = LiveRadioHlsPlayer();

  /// Lecture WHEP (remote audio → renderer).
  RTCVideoRenderer? _listenRenderer;

  /// Retour casque : loopback WebRTC local (send PC ↔ recv PC).
  /// Attacher le micro local à un [RTCVideoRenderer] ne joue PAS l’audio
  /// sur Android/iOS — le loopback force une piste « remote » jouable.
  RTCPeerConnection? _monitorSendPc;
  RTCPeerConnection? _monitorRecvPc;
  RTCVideoRenderer? _monitorRenderer;
  MediaStream? _monitorStream;
  bool _monitorEnabled = false;
  double _monitorVolume = 0.7;
  bool _micTrackEnabled = true;

  @override
  void Function()? onDisconnected;

  Future<_ListenTargets> _resolveListenTargets() async {
    final snap =
        await FirebaseFirestore.instance.collection('live').doc('current').get();
    if (!snap.exists) {
      throw StateError('Aucun match en direct');
    }
    final data = snap.data() ?? {};
    if (data['radioLive'] != true) {
      throw StateError('Radio commentaire éteinte');
    }
    final hlsUrl = (data['radioHlsUrl'] ?? '').toString().trim();
    if (hlsUrl.isEmpty) {
      throw StateError('URL HLS radio manquante');
    }
    final whipUrl = (data['radioWhipUrl'] ?? '').toString().trim();
    var whepUrl = (data['radioWhepUrl'] ?? '').toString().trim();
    if (whepUrl.isEmpty) {
      whepUrl = _deriveWhepUrl(whipUrl: whipUrl, hlsUrl: hlsUrl);
    }
    return _ListenTargets(hlsUrl: hlsUrl, whepUrl: whepUrl);
  }

  /// MediaMTX : `…/whip` → `…/whep`, ou HLS `:8888/…/index.m3u8` → `:8889/…/whep`.
  static String _deriveWhepUrl({
    required String whipUrl,
    required String hlsUrl,
  }) {
    final whip = whipUrl.trim();
    if (whip.isNotEmpty) {
      if (whip.toLowerCase().endsWith('/whip')) {
        return '${whip.substring(0, whip.length - 5)}/whep';
      }
      final u = Uri.tryParse(whip);
      if (u != null) {
        final segs = [...u.pathSegments.where((s) => s.isNotEmpty)];
        if (segs.isNotEmpty && segs.last.toLowerCase() == 'whip') {
          segs[segs.length - 1] = 'whep';
          return u.replace(pathSegments: segs).toString();
        }
      }
    }
    final hls = Uri.tryParse(hlsUrl.trim());
    if (hls == null || !(hls.isScheme('http') || hls.isScheme('https'))) {
      return '';
    }
    final segs = hls.pathSegments
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'index.m3u8')
        .toList();
    if (segs.isEmpty) return '';
    return hls
        .replace(
          port: 8889,
          pathSegments: [...segs, 'whep'],
        )
        .toString();
  }

  Future<Map<String, dynamic>> _fetchPublishConfig() async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('getLiveRadioPublishConfig');
    final result = await callable.call(<String, dynamic>{});
    return Map<String, dynamic>.from(result.data as Map);
  }

  String _mapFunctionsError(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').trim();
    if (msg.contains('MediaMTX non configuré') ||
        msg.toLowerCase().contains('whip')) {
      return msg.isNotEmpty ? msg : 'MediaMTX non configuré';
    }
    if (msg.isNotEmpty) return msg;
    return 'Connexion radio impossible (${e.code})';
  }

  Future<void> _waitIceGatheringComplete(RTCPeerConnection pc) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final done = Completer<void>();
    pc.onIceGatheringState = (RTCIceGatheringState? state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !done.isCompleted) {
        done.complete();
      }
    };
    try {
      await done.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // SDP partiel OK pour la plupart des MediaMTX.
    }
  }

  /// Libère AVAudioSession (podcast / jingle) avant WebRTC — sinon iOS quitte.
  Future<void> _releaseCompetingAudio() async {
    try {
      await PodcastController.instance.stopLiveRadio();
    } catch (_) {}
    try {
      if (PodcastController.instance.isPlaying) {
        await PodcastController.instance.pause();
      }
    } catch (_) {}
    try {
      await LiveSfxService.instance.stopPlayback();
    } catch (_) {}
    // Laisse iOS basculer la catégorie audio.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  /// playAndRecord / playback — sans [Helper.ensureAudioSession] ni speaker
  /// *avant* getUserMedia (hasLocalAudioTrack=false → mauvaise catégorie).
  Future<void> _configureAudioSession({
    required bool publishing,
    required bool preferSpeaker,
    bool activateHardware = false,
  }) async {
    try {
      if (WebRTC.platformIsAndroid) {
        await Helper.setAndroidAudioConfiguration(
          publishing
              ? AndroidAudioConfiguration.communication
              : AndroidAudioConfiguration.media,
        );
      }
    } catch (e) {
      debugPrint('LiveRadio android audio cfg: $e');
    }
    try {
      if (WebRTC.platformIsIOS) {
        await Helper.setAppleAudioIOMode(
          publishing
              ? AppleAudioIOMode.localAndRemote
              : AppleAudioIOMode.remoteOnly,
          preferSpeakerOutput: preferSpeaker,
        );
        if (activateHardware) {
          await Helper.ensureAudioSession();
          try {
            await Helper.setSpeakerphoneOn(preferSpeaker);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('LiveRadio ios audio cfg: $e');
    }
  }

  Future<void> _ensureMicrophonePermission() async {
    if (kIsWeb) return;
    try {
      if (WebRTC.platformIsAndroid) {
        final ok = await Helper.requestCapturePermission();
        if (!ok) {
          throw StateError(
            'Micro refusé — autorise le micro dans les réglages Android.',
          );
        }
        return;
      }
    } catch (e) {
      if (e is StateError) rethrow;
      debugPrint('LiveRadio android mic perm: $e');
    }
    if (!Platform.isIOS && !Platform.isAndroid) return;
    var status = await Permission.microphone.status;
    if (status.isGranted) return;
    if (status.isPermanentlyDenied) {
      throw StateError(
        'Micro refusé — active-le dans Réglages → DVCR → Microphone.',
      );
    }
    status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw StateError(
        'Micro nécessaire pour commenter — autorise l’accès micro.',
      );
    }
  }

  /// Unified-plan : parfois `streams` vide — fabrique un MediaStream jouable.
  Future<MediaStream> _streamFromTrackEvent(RTCTrackEvent event) async {
    if (event.streams.isNotEmpty) {
      return event.streams.first;
    }
    final stream = await createLocalMediaStream(
      'dvcr-${event.track.id ?? DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      await stream.addTrack(event.track);
    } catch (e) {
      debugPrint('LiveRadio streamFromTrack addTrack: $e');
      try {
        await stream.dispose();
      } catch (_) {}
      rethrow;
    }
    return stream;
  }

  Future<void> _connectWhip({required bool enableMic}) async {
    await disconnect();
    // Retour casque : jamais auto au publish — uniquement via setMonitorEnabled.
    _monitorEnabled = false;

    Map<String, dynamic> cfg;
    try {
      cfg = await _fetchPublishConfig();
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_mapFunctionsError(e));
    }

    final whipUrl = (cfg['whipUrl'] ?? '').toString().trim();
    if (whipUrl.isEmpty) {
      throw StateError('URL WHIP manquante — configure app_config/radio');
    }

    final headers = <String, String>{
      'Content-Type': 'application/sdp',
    };
    final authorization = (cfg['authorization'] ?? '').toString().trim();
    if (authorization.isNotEmpty) {
      headers['Authorization'] = authorization;
    }
    _whipAuthHeaders = Map<String, String>.from(headers)
      ..remove('Content-Type');

    await _releaseCompetingAudio();
    await _ensureMicrophonePermission();

    // playAndRecord (catégorie) seulement — pas ensureAudioSession/speaker avant GUM.
    await _configureAudioSession(
      publishing: true,
      preferSpeaker: false,
      activateHardware: false,
    );

    RTCPeerConnection? pc;
    try {
      pc = await createPeerConnection({
        'sdpSemantics': 'unified-plan',
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });
      _pc = pc;

      // Pas de disconnect auto pendant le handshake (évite courses iOS).
      pc.onConnectionState = null;

      late final MediaStream stream;
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        });
      } catch (e) {
        debugPrint('LiveRadio getUserMedia failed: $e');
        throw StateError(
          'Impossible d’accéder au micro — vérifie l’autorisation '
          'et qu’aucune autre app n’utilise le micro.',
        );
      }
      _localStream = stream;
      _micTrackEnabled = enableMic;

      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isEmpty) {
        throw StateError('Aucune piste micro — réessaie Activer le micro.');
      }
      for (final track in audioTracks) {
        track.enabled = enableMic;
        // addTrack(track, stream) obligatoire — sinon crash natif iOS/Android.
        await pc.addTrack(track, stream);
      }

      // Session active maintenant que la piste locale existe.
      await _configureAudioSession(
        publishing: true,
        preferSpeaker: false,
        activateHardware: true,
      );

      final offer = await pc.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await pc.setLocalDescription(offer);
      await _waitIceGatheringComplete(pc);
      final local = await pc.getLocalDescription();
      final sdp = local?.sdp;
      if (sdp == null || sdp.isEmpty) {
        throw StateError('Offre WebRTC vide');
      }

      final response = await http.post(
        Uri.parse(whipUrl),
        headers: headers,
        body: sdp,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'WHIP refusé (${response.statusCode}) — vérifie MediaMTX',
        );
      }

      final location = response.headers['location'];
      if (location != null && location.trim().isNotEmpty) {
        final loc = location.trim();
        _whipResourceUrl = loc.startsWith('http')
            ? loc
            : Uri.parse(whipUrl).resolve(loc).toString();
      }

      await pc.setRemoteDescription(
        RTCSessionDescription(response.body, 'answer'),
      );

      final mediaOk = await _waitPeerConnected(pc);
      if (!mediaOk) {
        throw StateError(
          'WHIP connecté en HTTP mais média coupé (ICE). '
          'Vérifie firewall UDP 8189 / webrtcAdditionalHosts sur le VPS.',
        );
      }

      pc.onConnectionState = (RTCPeerConnectionState? state) {
        if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          disconnect().then((_) => onDisconnected?.call());
        }
      };
      // Monitor / loopback : PAS ici — trop fragile sur iOS au démarrage WHIP.
      debugPrint('LiveRadio WHIP connected (monitor off until toggle)');
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  Future<bool> _waitPeerConnected(RTCPeerConnection pc) async {
    if (pc.connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      return true;
    }
    final done = Completer<bool>();
    final prev = pc.onConnectionState;
    pc.onConnectionState = (RTCPeerConnectionState? state) {
      if (state != null) {
        prev?.call(state);
      }
      if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          !done.isCompleted) {
        done.complete(true);
      } else if ((state ==
                  RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              state ==
                  RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
              state ==
                  RTCPeerConnectionState
                      .RTCPeerConnectionStateDisconnected) &&
          !done.isCompleted) {
        done.complete(false);
      }
    };
    try {
      return await done.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Connecting ≠ succès — les fans n’entendent rien tant que ICE n’est pas Connected.
          return pc.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnected;
        },
      );
    } finally {
      pc.onConnectionState = prev;
    }
  }

  Future<void> _connectListen() async {
    final wasPublishing = _pc != null || _whipResourceUrl != null;
    await disconnect();
    if (wasPublishing) {
      debugPrint(
        'LiveRadio: publish arrêté sur cet appareil avant écoute',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await _releaseCompetingAudio();
    final targets = await _resolveListenTargets();
    debugPrint(
      'LiveRadio listen whep=${targets.whepUrl} hls=${targets.hlsUrl}',
    );

    // iOS : WHEP d’abord ; en échec → HLS (évite quit natif).
    if (targets.whepUrl.isNotEmpty) {
      try {
        await _connectWhep(targets.whepUrl);
        return;
      } catch (e) {
        debugPrint('LiveRadio WHEP failed, fallback HLS: $e');
        await _teardownWhepOnly();
      }
    }

    _hls.onEnded = () {
      disconnect().then((_) => onDisconnected?.call());
    };
    await _hls.play(targets.hlsUrl);
  }

  Future<void> _connectWhep(String whepUrl) async {
    const attempts = 20; // ~45 s : attend le commentateur WHIP
    Object? lastError;

    for (var i = 0; i < attempts; i++) {
      // radioLive peut être coupé pendant l’attente.
      final live = await _isRadioStillLive();
      if (!live) {
        throw StateError('Radio commentaire éteinte');
      }

      RTCPeerConnection? pc;
      RTCVideoRenderer? renderer;
      try {
        // Playback fans : catégorie playback — hardware après piste remote.
        await _configureAudioSession(
          publishing: false,
          preferSpeaker: true,
          activateHardware: false,
        );

        pc = await createPeerConnection({
          'sdpSemantics': 'unified-plan',
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
        });
        renderer = RTCVideoRenderer();
        await renderer.initialize();

        final streamReady = Completer<MediaStream>();
        pc.onTrack = (RTCTrackEvent event) async {
          if (event.track.kind != 'audio') return;
          try {
            final stream = await _streamFromTrackEvent(event);
            if (!streamReady.isCompleted) {
              streamReady.complete(stream);
            }
          } catch (e) {
            if (!streamReady.isCompleted) {
              streamReady.completeError(e);
            }
          }
        };

        await pc.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.RecvOnly,
          ),
        );

        final offer = await pc.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false,
        });
        await pc.setLocalDescription(offer);
        await _waitIceGatheringComplete(pc);
        final local = await pc.getLocalDescription();
        final sdp = local?.sdp;
        if (sdp == null || sdp.isEmpty) {
          throw StateError('Offre WHEP vide');
        }

        final response = await http
            .post(
              Uri.parse(whepUrl),
              headers: const {'Content-Type': 'application/sdp'},
              body: sdp,
            )
            .timeout(const Duration(seconds: 8));

        final body = response.body;
        final lower = body.toLowerCase();
        final noStream = response.statusCode == 404 ||
            lower.contains('no stream') ||
            lower.contains('not available') ||
            lower.contains('no one is publishing');

        if (noStream) {
          debugPrint(
            'LiveRadio WHEP waiting for publisher try ${i + 1}/$attempts',
          );
          await _disposePc(pc);
          await _disposeRenderer(renderer);
          pc = null;
          renderer = null;
          if (i < attempts - 1) {
            await Future<void>.delayed(
              Duration(milliseconds: 1200 + (i * 200).clamp(0, 2000)),
            );
          }
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'WHEP refusé (${response.statusCode})',
          );
        }

        final location = response.headers['location'];
        if (location != null && location.trim().isNotEmpty) {
          final loc = location.trim();
          _whepResourceUrl = loc.startsWith('http')
              ? loc
              : Uri.parse(whepUrl).resolve(loc).toString();
        }

        await pc.setRemoteDescription(
          RTCSessionDescription(body, 'answer'),
        );

        MediaStream? remote;
        try {
          remote = await streamReady.future.timeout(
            const Duration(seconds: 12),
          );
        } on TimeoutException {
          // Certains builds livrent la piste sans stream — on garde le PC.
          debugPrint('LiveRadio WHEP: onTrack timeout — keep PC');
        }

        if (remote != null) {
          try {
            renderer.srcObject = remote;
            for (final t in remote.getAudioTracks()) {
              t.enabled = true;
              try {
                await Helper.setVolume(1.0, t);
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('LiveRadio WHEP renderer attach: $e');
          }
        }

        final mediaOk = await _waitPeerConnected(pc);
        if (!mediaOk) {
          throw StateError(
            'WHEP ICE échoué — vérifie UDP 8189 / webrtcAdditionalHosts',
          );
        }

        await _configureAudioSession(
          publishing: false,
          preferSpeaker: true,
          activateHardware: true,
        );
        try {
          await Helper.setSpeakerphoneOnButPreferBluetooth();
        } catch (_) {
          try {
            await Helper.setSpeakerphoneOn(true);
          } catch (_) {}
        }

        _pc = pc;
        _listenRenderer = renderer;
        pc.onConnectionState = (RTCPeerConnectionState? state) {
          if (state ==
                  RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              state ==
                  RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
              state ==
                  RTCPeerConnectionState
                      .RTCPeerConnectionStateDisconnected) {
            disconnect().then((_) => onDisconnected?.call());
          }
        };
        debugPrint('LiveRadio WHEP connected try ${i + 1}');
        return;
      } catch (e) {
        lastError = e;
        debugPrint('LiveRadio WHEP try ${i + 1}/$attempts: $e');
        await _disposePc(pc);
        await _disposeRenderer(renderer);
        final msg = e.toString().toLowerCase();
        final waitable = msg.contains('no stream') ||
            msg.contains('404') ||
            msg.contains('waiting') ||
            msg.contains('timeout') ||
            msg.contains('socket') ||
            msg.contains('connection');
        if (!waitable) rethrow;
        if (i < attempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 1200 + (i * 200).clamp(0, 2000)),
          );
        }
      }
    }

    throw StateError(
      lastError?.toString() ??
          'En attente du commentateur — active le micro sur le téléphone, '
              'puis réessaie.',
    );
  }

  Future<bool> _isRadioStillLive() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .get();
      return snap.exists && (snap.data()?['radioLive'] == true);
    } catch (_) {
      return true;
    }
  }

  Future<void> _teardownWhepOnly() async {
    final resource = _whepResourceUrl;
    _whepResourceUrl = null;
    if (resource != null && resource.isNotEmpty) {
      try {
        await http.delete(Uri.parse(resource));
      } catch (_) {}
    }
    final renderer = _listenRenderer;
    _listenRenderer = null;
    await _disposeRenderer(renderer);
    final pc = _pc;
    _pc = null;
    await _disposePc(pc);
  }

  Future<void> _disposePc(RTCPeerConnection? pc) async {
    if (pc == null) return;
    try {
      pc.onConnectionState = null;
      pc.onIceGatheringState = null;
      pc.onTrack = null;
      await pc.close();
    } catch (_) {}
  }

  Future<void> _disposeRenderer(RTCVideoRenderer? renderer) async {
    if (renderer == null) return;
    try {
      renderer.srcObject = null;
      await renderer.dispose();
    } catch (_) {}
  }

  @override
  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  }) async {
    if (role == LiveRadioRole.publisher) {
      await _connectWhip(enableMic: enableMic);
    } else {
      await _connectListen();
    }
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _micTrackEnabled = enabled;
    final tracks = _localStream?.getAudioTracks() ?? const [];
    for (final t in tracks) {
      t.enabled = enabled;
    }
    await _syncMonitorTrackEnabled();
  }

  @override
  Future<void> setMonitorEnabled(bool enabled) async {
    _monitorEnabled = enabled;
    if (!enabled) {
      await _stopMonitor();
      return;
    }
    if (_localStream == null || _pc == null || _whipResourceUrl == null) {
      // Publish pas encore stable — ignore (évite crash loopback).
      debugPrint('LiveRadio monitor ignored: publish not ready');
      _monitorEnabled = false;
      throw StateError(
        'Active d’abord le micro (WHIP), puis le retour casque.',
      );
    }
    // Laisse ICE/ADM se stabiliser avant un 2ᵉ PC loopback (crash iOS).
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!_monitorEnabled || _localStream == null || _pc == null) return;
    await _startMonitor();
    if (_monitorRenderer == null && _monitorRecvPc == null) {
      _monitorEnabled = false;
      throw StateError(
        'Retour casque indisponible sur cet appareil — '
        'le micro reste en direct pour les fans.',
      );
    }
  }

  @override
  Future<void> setMonitorVolume(double volume) async {
    _monitorVolume = volume.clamp(0.0, 1.0);
    await _applyMonitorVolume();
  }

  /// Loopback WebRTC : clone micro → PC send → PC recv → piste « remote ».
  ///
  /// Isolé du publish WHIP : toute erreur est avalée (pas de quit).
  /// Sur iOS, clone + 2 PC est fragile — best-effort only.
  Future<void> _startMonitor() async {
    final src = _localStream;
    if (src == null) return;
    await _stopMonitor();
    try {
      try {
        if (WebRTC.platformIsIOS) {
          await Helper.setAppleAudioIOMode(
            AppleAudioIOMode.localAndRemote,
            preferSpeakerOutput: false,
          );
          await Helper.ensureAudioSession();
        }
      } catch (_) {}

      MediaStream? clone;
      try {
        clone = await src.clone();
      } catch (e) {
        debugPrint('LiveRadio monitor clone failed: $e');
        return;
      }
      _monitorStream = clone;

      final cfg = <String, dynamic>{
        'sdpSemantics': 'unified-plan',
        'iceServers': <Map<String, dynamic>>[],
      };
      final sendPc = await createPeerConnection(cfg);
      final recvPc = await createPeerConnection(cfg);
      _monitorSendPc = sendPc;
      _monitorRecvPc = recvPc;

      sendPc.onIceCandidate = (RTCIceCandidate? c) {
        if (c != null) {
          try {
            recvPc.addCandidate(c);
          } catch (_) {}
        }
      };
      recvPc.onIceCandidate = (RTCIceCandidate? c) {
        if (c != null) {
          try {
            sendPc.addCandidate(c);
          } catch (_) {}
        }
      };

      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _monitorRenderer = renderer;

      final gotRemote = Completer<MediaStream>();
      recvPc.onTrack = (RTCTrackEvent event) async {
        if (event.track.kind != 'audio') return;
        try {
          final stream = await _streamFromTrackEvent(event);
          try {
            renderer.srcObject = stream;
          } catch (_) {}
          if (!gotRemote.isCompleted) gotRemote.complete(stream);
        } catch (e) {
          if (!gotRemote.isCompleted) gotRemote.completeError(e);
        }
      };

      await recvPc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );
      final tracks = clone.getAudioTracks();
      if (tracks.isEmpty) {
        debugPrint('LiveRadio monitor: no audio tracks on clone');
        await _stopMonitor();
        return;
      }
      for (final track in tracks) {
        track.enabled = _monitorEnabled && _micTrackEnabled;
        await sendPc.addTrack(track, clone);
      }

      final offer = await sendPc.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await sendPc.setLocalDescription(offer);
      await recvPc.setRemoteDescription(offer);
      final answer = await recvPc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await recvPc.setLocalDescription(answer);
      await sendPc.setRemoteDescription(answer);

      try {
        final remote = await gotRemote.future.timeout(
          const Duration(seconds: 5),
        );
        try {
          renderer.srcObject = remote;
        } catch (_) {}
      } on TimeoutException {
        debugPrint('LiveRadio monitor: onTrack lent — continue');
      }

      await _syncMonitorTrackEnabled();
      await _applyMonitorVolume();
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (_) {}
      debugPrint('LiveRadio monitor loopback started vol=$_monitorVolume');
    } catch (e, st) {
      debugPrint('LiveRadio monitor failed: $e\n$st');
      await _stopMonitor();
    }
  }

  Future<void> _syncMonitorTrackEnabled() async {
    final on = _monitorEnabled && _micTrackEnabled;
    for (final t in _monitorStream?.getAudioTracks() ?? const []) {
      t.enabled = on;
    }
    // Coupe aussi la piste remote si micro coupé / retour off.
    for (final t
        in _monitorRenderer?.srcObject?.getAudioTracks() ?? const []) {
      t.enabled = on;
    }
  }

  Future<void> _applyMonitorVolume() async {
    // Volume retour = pistes remote du loopback uniquement (pas le WHIP).
    final tracks =
        _monitorRenderer?.srcObject?.getAudioTracks() ?? const [];
    for (final t in tracks) {
      try {
        await Helper.setVolume(_monitorVolume, t);
      } catch (_) {}
    }
  }

  Future<void> _stopMonitor() async {
    final renderer = _monitorRenderer;
    _monitorRenderer = null;
    await _disposeRenderer(renderer);

    final send = _monitorSendPc;
    _monitorSendPc = null;
    await _disposePc(send);
    final recv = _monitorRecvPc;
    _monitorRecvPc = null;
    await _disposePc(recv);

    final stream = _monitorStream;
    _monitorStream = null;
    if (stream != null) {
      try {
        for (final t in stream.getTracks()) {
          await t.stop();
        }
        await stream.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> disconnect() async {
    await _stopMonitor();

    final whipResource = _whipResourceUrl;
    final whepResource = _whepResourceUrl;
    final auth = _whipAuthHeaders;
    _whipResourceUrl = null;
    _whepResourceUrl = null;
    _whipAuthHeaders = null;

    if (whipResource != null && whipResource.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse(whipResource),
          headers: auth ?? const {},
        );
      } catch (_) {}
    }
    if (whepResource != null && whepResource.isNotEmpty) {
      try {
        await http.delete(Uri.parse(whepResource));
      } catch (_) {}
    }

    await _hls.stop();
    _hls.onEnded = null;

    final listenRenderer = _listenRenderer;
    _listenRenderer = null;
    await _disposeRenderer(listenRenderer);

    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        await t.stop();
      }
      await stream.dispose();
    }

    final pc = _pc;
    _pc = null;
    await _disposePc(pc);
  }
}

class _ListenTargets {
  final String hlsUrl;
  final String whepUrl;
  const _ListenTargets({required this.hlsUrl, required this.whepUrl});
}
