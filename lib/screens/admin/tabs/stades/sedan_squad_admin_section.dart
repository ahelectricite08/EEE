import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/sedan_squad.dart';
import '../../../../services/sedan_squad_service.dart';
import '../../../../utils/pick_image_bytes.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Admin — effectif Sedan (`app_config/sedan_squad`).
/// Utilisé pour les faits de jeu live, la composition et le jeu « XI probable ».
class SedanSquadAdminSection extends StatefulWidget {
  const SedanSquadAdminSection({super.key});

  @override
  State<SedanSquadAdminSection> createState() => _SedanSquadAdminSectionState();
}

class _SedanSquadAdminSectionState extends State<SedanSquadAdminSection> {
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _photoBusyId;
  List<SedanSquadPlayer> _players = [];
  StreamSubscription<SedanSquad>? _sub;

  static const _positions = ['GB', 'DEF', 'MIL', 'ATT'];

  @override
  void initState() {
    super.initState();
    _sub = SedanSquadService.watch().listen((squad) {
      if (!mounted) return;
      setState(() {
        _players = List<SedanSquadPlayer>.from(squad.players);
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SedanSquadService.save(SedanSquad(players: _players));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Effectif Sedan enregistré (${_players.length} joueur${_players.length > 1 ? 's' : ''}).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: adminRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addPlayer() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final exists = _players.any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce joueur est déjà dans l’effectif.'),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    final number = int.tryParse(_numberCtrl.text.trim());
    final position = _positionCtrl.text.trim().toUpperCase();
    setState(() {
      _players = [
        ..._players,
        SedanSquadPlayer(
          id: SedanSquadService.newPlayerId(name),
          name: name,
          number: (number != null && number > 0) ? number : null,
          position: position.isEmpty ? null : position,
        ),
      ];
      _nameCtrl.clear();
      _numberCtrl.clear();
      _positionCtrl.clear();
    });
  }

  void _removePlayer(String id) {
    setState(() => _players = _players.where((p) => p.id != id).toList());
  }

  String _photoError(Object e) {
    if (e is StateError) {
      return switch (e.message) {
        'photo_too_large' => 'Photo trop lourde (2 Mo max).',
        'photo_format' => 'Format refusé — PNG, JPG ou WebP.',
        'photo_empty' => 'Fichier vide — réessaie.',
        'not_authenticated' => 'Connecte-toi pour uploader.',
        _ => 'Erreur : $e',
      };
    }
    return 'Erreur : $e';
  }

  Future<void> _pickPhoto(SedanSquadPlayer player) async {
    if (_photoBusyId != null) return;
    late final PickedImageBytes picked;
    try {
      final result = await pickImageBytes(
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (result == null) return;
      picked = result;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_photoError(e)), backgroundColor: adminRed),
      );
      return;
    }
    setState(() => _photoBusyId = player.id);
    try {
      final url = await SedanSquadService.uploadPlayerPhoto(
        playerId: player.id,
        bytes: picked.bytes,
        extension: picked.extension,
      );
      if (!mounted) return;
      final next = _players
          .map((p) => p.id == player.id ? p.copyWith(photoUrl: url) : p)
          .toList();
      setState(() => _players = next);
      await SedanSquadService.save(SedanSquad(players: next));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_photoError(e)), backgroundColor: adminRed),
      );
    } finally {
      if (mounted) setState(() => _photoBusyId = null);
    }
  }

  Future<void> _editPlayer(SedanSquadPlayer player) async {
    final nameCtrl = TextEditingController(text: player.name);
    final numberCtrl = TextEditingController(
      text: player.number?.toString() ?? '',
    );
    final positionCtrl = TextEditingController(text: player.position ?? '');
    final photoCtrl = TextEditingController(text: player.photoUrl ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Modifier le joueur',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminField(ctrl: nameCtrl, label: 'Nom'),
            const SizedBox(height: 10),
            AdminField(
              ctrl: numberCtrl,
              label: 'Numéro (optionnel)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            AdminField(
              ctrl: positionCtrl,
              label: 'Poste (GB / DEF / MIL / ATT)',
            ),
            const SizedBox(height: 10),
            AdminField(
              ctrl: photoCtrl,
              label: 'Photo (URL, optionnel)',
              hint: 'https://…',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AdminModuleColors.preparation,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      nameCtrl.dispose();
      numberCtrl.dispose();
      positionCtrl.dispose();
      photoCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    final number = int.tryParse(numberCtrl.text.trim());
    final position = positionCtrl.text.trim().toUpperCase();
    final photoRaw = photoCtrl.text.trim();
    nameCtrl.dispose();
    numberCtrl.dispose();
    positionCtrl.dispose();
    photoCtrl.dispose();
    if (name.isEmpty) return;
    if (photoRaw.isNotEmpty) {
      final warn = remoteImageAdminWarning(photoRaw);
      if (warn != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warn), backgroundColor: adminRed),
        );
        return;
      }
    }
    final photo = photoRaw.isEmpty ? null : photoRaw;
    setState(() {
      _players = _players
          .map(
            (p) => p.id == player.id
                ? SedanSquadPlayer(
                    id: p.id,
                    name: name,
                    number: (number != null && number > 0) ? number : null,
                    position: position.isEmpty ? null : position,
                    photoUrl: photo,
                  )
                : p,
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'EFFECTIF SEDAN',
      icon: Icons.groups_rounded,
      color: AdminModuleColors.preparation,
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
                    'Liste des joueurs CSSA pour le Direct (compo & buteurs), '
                    'et pour le jeu « XI probable » des fans. Une photo par '
                    'joueur s’affiche sur le onze une fois les 11 posés. '
                    'Le XI se verrouille 2 j 12 h avant le match (compos '
                    'souvent la veille), puis à la publication de la compo '
                    'officielle.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.4,
                      color: adminGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: AdminField(
                          ctrl: _numberCtrl,
                          label: 'N°',
                          hint: '9',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AdminField(
                          ctrl: _nameCtrl,
                          label: 'Nom',
                          hint: 'Dupont',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AdminField(
                          ctrl: _positionCtrl,
                          label: 'Poste (optionnel)',
                          hint: 'ATT',
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addPlayer,
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminModuleColors.preparation,
                          foregroundColor: adminOnAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        child: const Icon(Icons.add_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _positions
                        .map(
                          (p) => ActionChip(
                            label: Text(
                              p,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              _positionCtrl.text = p;
                              HapticFeedback.selectionClick();
                            },
                            backgroundColor: adminSurface,
                            side: const BorderSide(color: adminBorder),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'JOUEURS (${_players.length})',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: adminGold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_players.isEmpty)
                    Text(
                      'Aucun joueur — ajoute l’effectif pour activer les pickers.',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                    )
                  else
                    ..._players.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: adminSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: adminBorder),
                          ),
                          child: Row(
                            children: [
                              _AdminPlayerAvatar(
                                player: p,
                                busy: _photoBusyId == p.id,
                                onTap: () => _pickPhoto(p),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: adminTextPrimary,
                                      ),
                                    ),
                                    if (p.number != null ||
                                        p.position != null)
                                      Text(
                                        [
                                          if (p.number != null) '${p.number}',
                                          if (p.position != null) p.position!,
                                        ].join(' · '),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: adminGrey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: p.hasPhoto
                                    ? 'Changer la photo'
                                    : 'Ajouter une photo',
                                onPressed: _photoBusyId == null
                                    ? () => _pickPhoto(p)
                                    : null,
                                icon: Icon(
                                  p.hasPhoto
                                      ? Icons.photo_camera_rounded
                                      : Icons.add_a_photo_outlined,
                                  size: 18,
                                  color: adminGrey,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Modifier',
                                onPressed: () => _editPlayer(p),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: adminGrey,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Retirer',
                                onPressed: () => _removePlayer(p.id),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminModuleColors.preparation,
                        foregroundColor: adminOnAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: adminOnAccent,
                              ),
                            )
                          : Text(
                              'ENREGISTRER L’EFFECTIF',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firestore · app_config/sedan_squad',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AdminPlayerAvatar extends StatelessWidget {
  final SedanSquadPlayer player;
  final bool busy;
  final VoidCallback onTap;

  const _AdminPlayerAvatar({
    required this.player,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AdminModuleColors.preparation;
    final label = player.number != null
        ? '${player.number}'
        : (player.name.trim().isNotEmpty
            ? player.name.trim().substring(0, 1).toUpperCase()
            : '?');
    Widget face() {
      if (player.hasPhoto) {
        return DvcrNetworkImage(
          player.photoUrl!,
          fit: BoxFit.cover,
          width: 36,
          height: 36,
          cacheWidth: dvcrImageCacheWidth(context, 36),
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        );
      }
      return Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      );
    }

    return InkWell(
      onTap: busy ? null : onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withAlpha(30),
          border: Border.all(color: adminBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : face(),
      ),
    );
  }
}
