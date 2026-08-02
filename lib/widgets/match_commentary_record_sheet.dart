import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/match_commentary_service.dart';

/// Bottom sheet : enregistre 2–40 s de commentaire audio pour un fait de jeu.
Future<bool> showMatchCommentaryRecordSheet(
  BuildContext context, {
  required String matchId,
  required String eventId,
  String type = '',
  int minute = 0,
  String player = '',
  String team = '',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141414),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _MatchCommentaryRecordSheet(
      matchId: matchId,
      eventId: eventId,
      type: type,
      minute: minute,
      player: player,
      team: team,
    ),
  );
  return result == true;
}

/// Propose d’enregistrer juste après la saisie d’un event.
Future<void> offerMatchCommentaryAfterEvent(
  BuildContext context, {
  required Map<String, dynamic> event,
}) async {
  final matchId = (event['matchId'] ?? '').toString().trim();
  final eventId = (event['id'] ?? '').toString().trim();
  if (matchId.isEmpty || eventId.isEmpty || !context.mounted) return;

  final want = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        'Commentaire audio ?',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      content: Text(
        'Enregistrer un clip (max ${MatchCommentaryService.maxDurationSec}s) '
        'lié à cette action pour la fiche match.',
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Plus tard', style: GoogleFonts.inter(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC9A84C)),
          child: Text(
            'Commenter',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
  if (want != true || !context.mounted) return;

  await showMatchCommentaryRecordSheet(
    context,
    matchId: matchId,
    eventId: eventId,
    type: (event['type'] ?? '').toString(),
    minute: (event['minute'] as num?)?.toInt() ?? 0,
    player: (event['player'] ?? '').toString(),
    team: (event['team'] ?? '').toString(),
  );
}

class _MatchCommentaryRecordSheet extends StatefulWidget {
  final String matchId;
  final String eventId;
  final String type;
  final int minute;
  final String player;
  final String team;

  const _MatchCommentaryRecordSheet({
    required this.matchId,
    required this.eventId,
    required this.type,
    required this.minute,
    required this.player,
    required this.team,
  });

  @override
  State<_MatchCommentaryRecordSheet> createState() =>
      _MatchCommentaryRecordSheetState();
}

class _MatchCommentaryRecordSheetState
    extends State<_MatchCommentaryRecordSheet> {
  final _recorder = AudioRecorder();
  Timer? _tick;
  bool _recording = false;
  bool _uploading = false;
  int _elapsedSec = 0;
  String? _path;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final ok = await _recorder.hasPermission();
    if (!ok) {
      setState(() => _error = 'Autorise le micro pour commenter.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/dvcr_comment_${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      if (_elapsedSec >= MatchCommentaryService.maxDurationSec) {
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
    if (path == null || !File(path).existsSync()) {
      setState(() {
        _uploading = false;
        _error = 'Aucun enregistrement.';
      });
      return;
    }
    if (_elapsedSec < MatchCommentaryService.minDurationSec) {
      setState(() {
        _uploading = false;
        _error = 'Trop court (min ${MatchCommentaryService.minDurationSec}s).';
      });
      try {
        await File(path).delete();
      } catch (_) {}
      return;
    }
    try {
      await MatchCommentaryService.instance.uploadClip(
        matchId: widget.matchId,
        eventId: widget.eventId,
        file: File(path),
        durationSec: _elapsedSec,
        type: widget.type,
        minute: widget.minute,
        player: widget.player,
        team: widget.team,
      );
      try {
        await File(path).delete();
      } catch (_) {}
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

  Future<void> _cancel() async {
    _tick?.cancel();
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    if (_path != null) {
      try {
        await File(_path!).delete();
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final label = [
      if (widget.minute > 0) "${widget.minute}'",
      if (widget.player.trim().isNotEmpty) widget.player.trim(),
      if (widget.type.trim().isNotEmpty) widget.type,
    ].join(' · ');

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
            'COMMENTAIRE AUDIO',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFC9A84C),
              letterSpacing: 1.2,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '2–${MatchCommentaryService.maxDurationSec} secondes · publié sur la fiche match',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${_elapsedSec.toString().padLeft(2, '0')}s'
              ' / ${MatchCommentaryService.maxDurationSec}s',
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
              style: GoogleFonts.inter(fontSize: 12, color: Colors.orangeAccent),
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
          else
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
                      foregroundColor: _recording ? Colors.white : Colors.black,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
