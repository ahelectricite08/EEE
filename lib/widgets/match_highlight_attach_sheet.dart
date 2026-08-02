import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../services/match_highlight_service.dart';

/// Picker MP4 (export vMix) lié à un fait de jeu.
Future<bool> showMatchHighlightAttachSheet(
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
    builder: (ctx) => _MatchHighlightAttachSheet(
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

class _MatchHighlightAttachSheet extends StatefulWidget {
  final String matchId;
  final String eventId;
  final String type;
  final int minute;
  final String player;
  final String team;

  const _MatchHighlightAttachSheet({
    required this.matchId,
    required this.eventId,
    required this.type,
    required this.minute,
    required this.player,
    required this.team,
  });

  @override
  State<_MatchHighlightAttachSheet> createState() =>
      _MatchHighlightAttachSheetState();
}

class _MatchHighlightAttachSheetState extends State<_MatchHighlightAttachSheet> {
  File? _file;
  String? _fileName;
  int _durationSec = 0;
  bool _uploading = false;
  String? _error;
  VideoPlayerController? _preview;

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      setState(() => _error = 'Fichier inaccessible.');
      return;
    }
    final file = File(path);
    final size = await file.length();
    if (size > MatchHighlightService.maxFileBytes) {
      setState(() => _error = 'Fichier trop lourd (max 40 Mo).');
      return;
    }
    await _preview?.dispose();
    final ctrl = VideoPlayerController.file(file);
    try {
      await ctrl.initialize();
      final secs = ctrl.value.duration.inSeconds;
      if (secs > MatchHighlightService.maxDurationSec) {
        await ctrl.dispose();
        setState(() {
          _error =
              'Clip trop long (${secs}s). Max ${MatchHighlightService.maxDurationSec}s.';
          _file = null;
          _fileName = null;
          _preview = null;
        });
        return;
      }
      setState(() {
        _file = file;
        _fileName = result.files.single.name;
        _durationSec = secs;
        _preview = ctrl;
      });
    } catch (e) {
      await ctrl.dispose();
      setState(() {
        _error = 'Lecture vidéo impossible.';
        _file = null;
        _preview = null;
      });
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await MatchHighlightService.instance.uploadClip(
        matchId: widget.matchId,
        eventId: widget.eventId,
        file: file,
        durationSec: _durationSec,
        type: widget.type,
        minute: widget.minute,
        player: widget.player,
        team: widget.team,
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
            'CLIP VMIX',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFC9A84C),
              letterSpacing: 1.2,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          ],
          const SizedBox(height: 8),
          Text(
            'MP4 10–${MatchHighlightService.maxDurationSec}s · visible sur la fiche + résumé',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          if (_preview != null && _preview!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: _preview!.value.aspectRatio == 0
                    ? 16 / 9
                    : _preview!.value.aspectRatio,
                child: VideoPlayer(_preview!),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  _fileName ?? 'Aucun fichier sélectionné',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          if (_durationSec > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Durée : ${_durationSec}s',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 18),
          if (_uploading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Annuler',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pick,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC9A84C),
                      side: const BorderSide(color: Color(0xFFC9A84C)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Choisir',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _file == null ? null : _upload,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A84C),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Publier',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
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
