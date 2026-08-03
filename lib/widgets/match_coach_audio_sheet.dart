import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/match_coach_audio_service.dart';

/// Bottom sheet : enregistre ou importe la parole du coach.
Future<bool> showMatchCoachAudioSheet(
  BuildContext context, {
  required String matchId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141414),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _MatchCoachAudioSheet(matchId: matchId),
  );
  return result == true;
}

class _MatchCoachAudioSheet extends StatefulWidget {
  final String matchId;

  const _MatchCoachAudioSheet({required this.matchId});

  @override
  State<_MatchCoachAudioSheet> createState() => _MatchCoachAudioSheetState();
}

class _MatchCoachAudioSheetState extends State<_MatchCoachAudioSheet> {
  final _recorder = AudioRecorder();
  final _titleCtrl = TextEditingController();
  Timer? _tick;
  bool _recording = false;
  bool _uploading = false;
  int _elapsedSec = 0;
  String? _path;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    _titleCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final ok = await _recorder.hasPermission();
    if (!ok) {
      setState(() => _error = 'Autorise le micro pour enregistrer.');
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final String path;
    if (kIsWeb) {
      path = 'dvcr_coach_$ts.m4a';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/dvcr_coach_$ts.m4a';
    }
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _path = path;
    _elapsedSec = 0;
    _recording = true;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _elapsedSec++);
      if (_elapsedSec >= MatchCoachAudioService.maxDurationSec) {
        await _stopAndUpload();
      }
    });
    setState(() {});
  }

  Future<void> _stopAndUpload() async {
    if (_uploading) return;
    _tick?.cancel();
    final path = await _recorder.stop() ?? _path;
    setState(() {
      _recording = false;
      _uploading = true;
      _error = null;
    });
    if (path == null || path.isEmpty) {
      setState(() {
        _uploading = false;
        _error = 'Aucun enregistrement.';
      });
      return;
    }
    if (_elapsedSec < MatchCoachAudioService.minDurationSec) {
      setState(() {
        _uploading = false;
        _error =
            'Trop court (min ${MatchCoachAudioService.minDurationSec}s).';
      });
      await _deleteTemp(path);
      return;
    }
    try {
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) {
        setState(() {
          _uploading = false;
          _error = 'Aucun enregistrement.';
        });
        return;
      }
      await MatchCoachAudioService.instance.upload(
        matchId: widget.matchId,
        bytes: bytes,
        durationSec: _elapsedSec,
        title: _titleCtrl.text,
      );
      await _deleteTemp(path);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Échec envoi : $e';
        });
      }
    }
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m4a', 'mp3', 'aac', 'mp4'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    var bytes = picked.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        picked.path != null &&
        picked.path!.isNotEmpty) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Fichier inaccessible.');
      return;
    }
    if (bytes.length > MatchCoachAudioService.maxFileBytes) {
      setState(() => _error = 'Fichier trop lourd (max 15 Mo).');
      return;
    }

    setState(() => _uploading = true);
    try {
      final name = picked.name.toLowerCase();
      var contentType = 'audio/mp4';
      var ext = 'm4a';
      if (name.endsWith('.mp3')) {
        contentType = 'audio/mpeg';
        ext = 'mp3';
      } else if (name.endsWith('.aac')) {
        contentType = 'audio/aac';
        ext = 'aac';
      } else if (name.endsWith('.mp4')) {
        contentType = 'audio/mp4';
        ext = 'm4a';
      }
      // Durée inconnue au picker : 0 (pas affiché côté fan).
      await MatchCoachAudioService.instance.upload(
        matchId: widget.matchId,
        bytes: Uint8List.fromList(bytes),
        durationSec: 0,
        title: _titleCtrl.text,
        contentType: contentType,
        extension: ext,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Échec envoi : $e';
        });
      }
    }
  }

  Future<void> _deleteTemp(String path) async {
    if (kIsWeb) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> _cancel() async {
    _tick?.cancel();
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    if (_path != null) await _deleteTemp(_path!);
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PAROLE DU COACH',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFC9A84C),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Discours post-match publié sur l’onglet Résumé de la fiche.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '2–${MatchCoachAudioService.maxDurationSec} s · enregistrement ou fichier',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            enabled: !_recording && !_uploading,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Titre (optionnel)',
              labelStyle:
                  GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              hintText: 'Ex. Réactions à chaud',
              hintStyle:
                  GoogleFonts.inter(fontSize: 12, color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1C1C1C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${_elapsedSec.toString().padLeft(2, '0')}s'
              ' / ${MatchCoachAudioService.maxDurationSec}s',
              style: GoogleFonts.barlowCondensed(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: _recording ? const Color(0xFFE53935) : Colors.white,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orangeAccent,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_uploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _recording ? _stopAndUpload : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: _recording
                          ? const Color(0xFFE53935)
                          : const Color(0xFFC9A84C),
                      foregroundColor:
                          _recording ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _recording ? 'Stop & publier' : 'Enregistrer',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            if (!_recording) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  'Choisir un fichier audio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC9A84C),
                  side: BorderSide(color: const Color(0xFFC9A84C).withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
