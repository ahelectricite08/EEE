import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/sedan_squad.dart';
import '../../../../services/sedan_squad_service.dart';
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

  Future<void> _editPlayer(SedanSquadPlayer player) async {
    final nameCtrl = TextEditingController(text: player.name);
    final numberCtrl = TextEditingController(
      text: player.number?.toString() ?? '',
    );
    final positionCtrl = TextEditingController(text: player.position ?? '');
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
      return;
    }
    final name = nameCtrl.text.trim();
    final number = int.tryParse(numberCtrl.text.trim());
    final position = positionCtrl.text.trim().toUpperCase();
    nameCtrl.dispose();
    numberCtrl.dispose();
    positionCtrl.dispose();
    if (name.isEmpty) return;
    setState(() {
      _players = _players
          .map(
            (p) => p.id == player.id
                ? SedanSquadPlayer(
                    id: p.id,
                    name: name,
                    number: (number != null && number > 0) ? number : null,
                    position: position.isEmpty ? null : position,
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
                    'et pour le jeu « XI probable » des fans. Le XI se '
                    'verrouille 2 j 12 h avant le match (compos souvent la '
                    'veille), puis à la publication de la compo officielle.',
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
                              if (p.number != null) ...[
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AdminModuleColors.preparation
                                        .withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${p.number}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AdminModuleColors.preparation,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
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
                                    if (p.position != null)
                                      Text(
                                        p.position!,
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
