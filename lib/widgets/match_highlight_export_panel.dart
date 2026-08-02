import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/admin/admin_module_colors.dart';
import '../screens/admin/admin_palette.dart';
import '../services/highlight_stinger_service.dart';
import '../services/match_highlight_service.dart';

/// Admin : bibliothèque stinger + export résumé MP4 (clips + stingers).
class MatchHighlightExportPanel extends StatefulWidget {
  final String matchId;
  final bool compact;

  const MatchHighlightExportPanel({
    super.key,
    required this.matchId,
    this.compact = false,
  });

  @override
  State<MatchHighlightExportPanel> createState() =>
      _MatchHighlightExportPanelState();
}

class _MatchHighlightExportPanelState extends State<MatchHighlightExportPanel> {
  bool _busy = false;
  String? _error;

  Future<void> _uploadStinger() async {
    final nameCtrl = TextEditingController(text: 'Stinger DVCR');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Nouveau stinger',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom',
            filled: true,
          ),
          style: GoogleFonts.inter(color: adminTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AdminModuleColors.apresMatch,
            ),
            child: const Text('Choisir MP4'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty || picked.files.single.path == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await HighlightStingerService.instance.uploadStinger(
        file: File(picked.files.single.path!),
        name: nameCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stinger ajouté',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String? stingerId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await HighlightStingerService.instance.exportResume(
        matchId: widget.matchId,
        stingerId: stingerId,
      );
      final url = (res['url'] ?? '').toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              url.isEmpty
                  ? 'Export terminé'
                  : 'Résumé prêt — ouvre le lien pour télécharger',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminGreen,
            action: url.isEmpty
                ? null
                : SnackBarAction(
                    label: 'Ouvrir',
                    textColor: Colors.white,
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mid = widget.matchId.trim();
    if (mid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<HighlightStingerLibrary>(
      stream: HighlightStingerService.instance.watchLibrary(),
      builder: (context, libSnap) {
        final lib = libSnap.data ?? const HighlightStingerLibrary();
        return StreamBuilder<List<MatchHighlightClip>>(
          stream: MatchHighlightService.instance.watchPlaylist(mid),
          builder: (context, clipSnap) {
            final clips = clipSnap.data ?? const <MatchHighlightClip>[];
            return StreamBuilder<Map<String, dynamic>?>(
              stream: HighlightStingerService.instance.watchExport(mid),
              builder: (context, expSnap) {
                final exp = expSnap.data;
                final status = (exp?['status'] ?? '').toString();
                final exportUrl = (exp?['url'] ?? '').toString();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AdminModuleColors.apresMatch.withAlpha(80),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'RÉSUMÉ MP4 + STINGER',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AdminModuleColors.apresMatch,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${clips.length} clip${clips.length > 1 ? 's' : ''} highlight'
                        ' · stinger entre chaque action',
                        style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Stinger actif',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: adminGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (lib.items.isEmpty)
                        Text(
                          'Aucun stinger — uploade un MP4 court (1–2 s).',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: adminTextPrimary,
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: lib.items.any((s) => s.id == lib.selectedId)
                              ? lib.selectedId
                              : lib.items.first.id,
                          dropdownColor: adminCard,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: adminCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: lib.items
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    style: GoogleFonts.inter(
                                      color: adminTextPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (id) {
                                  if (id != null) {
                                    HighlightStingerService.instance
                                        .selectStinger(id);
                                  }
                                },
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _uploadStinger,
                              icon: const Icon(Icons.upload_file_rounded,
                                  size: 16),
                              label: Text(
                                'Uploader stinger',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AdminModuleColors.apresMatch,
                                side: BorderSide(
                                  color: AdminModuleColors.apresMatch
                                      .withAlpha(120),
                                ),
                              ),
                            ),
                          ),
                          if (lib.items.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Supprimer le stinger sélectionné',
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final id = lib.selectedId.isEmpty
                                          ? lib.items.first.id
                                          : lib.selectedId;
                                      await HighlightStingerService.instance
                                          .deleteStinger(id);
                                    },
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: adminRed, size: 20),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _busy ||
                                clips.isEmpty ||
                                lib.items.isEmpty
                            ? null
                            : () => _export(
                                  lib.selectedId.isEmpty
                                      ? lib.items.first.id
                                      : lib.selectedId,
                                ),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.movie_creation_outlined,
                                size: 18),
                        label: Text(
                          status == 'processing'
                              ? 'Export en cours…'
                              : 'Exporter le résumé',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminModuleColors.apresMatch,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      if (status == 'ready' && exportUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(exportUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text(
                            'Télécharger le dernier résumé',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      if (status == 'failed') ...[
                        const SizedBox(height: 6),
                        Text(
                          (exp?['error'] ?? 'Export échoué').toString(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminRed,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminRed,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
