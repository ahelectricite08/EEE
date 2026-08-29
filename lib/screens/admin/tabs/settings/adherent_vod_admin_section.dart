import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/adherent_vod.dart';
import '../../../../services/adherent_vod_service.dart';
import '../../../../utils/youtube_parser.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

class _SeasonDraft {
  String id;
  final TextEditingController playlist;

  _SeasonDraft({required this.id, String playlist = ''})
      : playlist = TextEditingController(text: playlist);
}

/// TV / vidéos — VOD adhérents (playlists par saison).
class AdherentVodAdminSection extends StatefulWidget {
  const AdherentVodAdminSection({super.key});

  @override
  State<AdherentVodAdminSection> createState() =>
      _AdherentVodAdminSectionState();
}

class _AdherentVodAdminSectionState extends State<AdherentVodAdminSection> {
  StreamSubscription<AdherentVodConfig>? _sub;
  AdherentVodConfig _config = AdherentVodConfig.defaults;
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _forceLocked = false;
  String? _error;
  final List<_SeasonDraft> _rows = [];
  bool _syncedOnce = false;

  @override
  void initState() {
    super.initState();
    _sub = AdherentVodService.instance.watch().listen((v) {
      if (!mounted) return;
      if (!_syncedOnce || _rows.isEmpty) {
        _replaceRows(v);
        _syncedOnce = true;
      }
      setState(() {
        _config = v;
        _enabled = v.enabled;
        _forceLocked = v.forceLockedPreview;
        _loading = false;
        _error = null;
      });
    });
  }

  void _replaceRows(AdherentVodConfig v) {
    for (final r in _rows) {
      r.playlist.dispose();
    }
    _rows
      ..clear()
      ..addAll([
        for (final s in v.seasons)
          _SeasonDraft(id: s.id, playlist: s.playlistId),
      ]);
    if (_rows.isEmpty && v.playlistId.trim().isNotEmpty) {
      _rows.add(
        _SeasonDraft(
          id: AdherentSeason.currentId,
          playlist: v.playlistId,
        ),
      );
    }
    if (_rows.isEmpty) {
      _rows.add(_SeasonDraft(id: AdherentSeason.currentId));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final r in _rows) {
      r.playlist.dispose();
    }
    super.dispose();
  }

  Future<void> _setEnabled(bool v) async {
    setState(() {
      _enabled = v;
      _saving = true;
      _error = null;
    });
    try {
      await AdherentVodService.instance.setEnabled(v);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enabled = _config.enabled;
        _error = 'Impossible d’enregistrer : $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setForceLocked(bool v) async {
    setState(() {
      _forceLocked = v;
      _saving = true;
      _error = null;
    });
    try {
      await AdherentVodService.instance.setForceLockedPreview(v);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _forceLocked = _config.forceLockedPreview;
        _error = 'Impossible d’enregistrer : $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSeason() {
    final used = _rows.map((r) => r.id).toSet();
    final next = AdherentSeason.suggestedIds().firstWhere(
      (id) => !used.contains(id),
      orElse: () {
        final last = used.isEmpty
            ? AdherentSeason.currentId
            : (used.toList()..sort()).last;
        final start = int.tryParse(last.split('-').first) ?? DateTime.now().year;
        return '${start + 1}-${start + 2}';
      },
    );
    setState(() => _rows.add(_SeasonDraft(id: next)));
  }

  Future<void> _saveSeasons() async {
    for (final r in _rows) {
      if (r.playlist.text.trim().isNotEmpty &&
          YoutubeParser.extractPlaylistId(r.playlist.text) == null) {
        setState(() {
          _error =
              'Playlist invalide pour ${r.id} (PLxxxx ou URL YouTube playlist).';
        });
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AdherentVodService.instance.setSeasons([
        for (final r in _rows)
          AdherentVodSeason(id: r.id, playlistId: r.playlist.text),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saisons VOD enregistrées',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Saisons : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = AdherentSeason.suggestedIds();
    return SettingsCard(
      title: 'VOD ADHÉRENTS · ASSOCIATION DVCR',
      icon: Icons.lock_rounded,
      color: AdminUniverse.contenuDiffusion.color,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Une playlist YouTube par saison d’adhésion '
                    '(2026-2027, 2027-2028…). '
                    'Qui n’a pas cotisé une année ne voit pas les VOD de cette année, '
                    'même s’il a payé une autre saison. '
                    'Le webhook HelloAsso attribue la saison selon la date de fin '
                    'd’adhésion. Admin / CM : aperçu lecture. '
                    'Playlists Publiques ou Non répertoriées — pas Privées. '
                    'app_config/${AdherentVodConfig.firestoreDocId}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Afficher les VOD adhérents',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'Visible dans DVCR TV — une grille par saison'
                          : 'Masqué — rien dans l’app',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                    value: _enabled,
                    activeThumbColor: adminGold,
                    onChanged: _saving ? null : _setEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Aperçu cadenas (même staff)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _forceLocked
                          ? 'Tout le monde voit l’état verrouillé — y compris toi'
                          : 'Admin / CM voient toutes les saisons',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                    value: _forceLocked,
                    activeThumbColor: adminGold,
                    onChanged: _saving ? null : _setForceLocked,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PLAYLISTS PAR SAISON',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: adminGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _seasonRow(_rows[i], i, options),
                    ),
                  TextButton.icon(
                    onPressed: _saving ? null : _addSeason,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Ajouter une saison',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 11, color: adminRed),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving ? null : _saveSeasons,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: adminGold,
                          borderRadius: BorderRadius.circular(adminPaperRadius),
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'ENREGISTRER LES SAISONS',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _seasonRow(_SeasonDraft row, int index, List<String> options) {
    final ids = {
      ...options,
      row.id,
      for (final r in _rows) r.id,
    }.toList()
      ..sort((a, b) => AdherentSeason.compareNewestFirst(a, b));
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        border: Border.all(color: adminHairline),
        borderRadius: BorderRadius.circular(adminPaperRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('season-$index-${row.id}'),
                  initialValue: ids.contains(row.id) ? row.id : ids.first,
                  decoration: InputDecoration(
                    labelText: 'Saison',
                    labelStyle: GoogleFonts.inter(fontSize: 12),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final id in ids)
                      DropdownMenuItem(
                        value: id,
                        child: Text(id, style: GoogleFonts.inter(fontSize: 13)),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => row.id = v);
                        },
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            row.playlist.dispose();
                            _rows.removeAt(index);
                          });
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AdminField(
            ctrl: row.playlist,
            label: 'Playlist YouTube (ID ou URL)',
            hint: 'PLxxxx ou https://www.youtube.com/playlist?list=…',
            keyboardType: TextInputType.url,
            accent: AdminUniverse.contenuDiffusion.color,
          ),
        ],
      ),
    );
  }
}
