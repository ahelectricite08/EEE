import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/best_scorer_challenge_config.dart';
import '../../../../services/best_scorer_challenge_service.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Admin — défi « meilleur buteur » (`app_config/best_scorer_challenge`).
class BestScorerChallengeAdminSection extends StatefulWidget {
  const BestScorerChallengeAdminSection({super.key});

  @override
  State<BestScorerChallengeAdminSection> createState() =>
      _BestScorerChallengeAdminSectionState();
}

class _BestScorerChallengeAdminSectionState
    extends State<BestScorerChallengeAdminSection> {
  final _seasonCtrl = TextEditingController();
  final _playerCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _resolving = false;
  bool _enabled = false;
  List<BestScorerPlayer> _players = [];
  BestScorerChallengeConfig _config = BestScorerChallengeConfig.defaults;
  StreamSubscription<BestScorerChallengeConfig>? _sub;
  String? _resolvePlayerId;

  @override
  void initState() {
    super.initState();
    _sub = BestScorerChallengeService.watchConfig().listen((cfg) {
      if (!mounted) return;
      if (_seasonCtrl.text != cfg.seasonId) {
        _seasonCtrl.text = cfg.seasonId;
      }
      setState(() {
        _config = cfg;
        _enabled = cfg.enabled;
        _players = List<BestScorerPlayer>.from(cfg.players);
        _loading = false;
        if (_resolvePlayerId == null && cfg.resolvedPlayerId != null) {
          _resolvePlayerId = cfg.resolvedPlayerId;
        }
        if (_resolvePlayerId == null && _players.isNotEmpty) {
          _resolvePlayerId = _players.first.id;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _seasonCtrl.dispose();
    _playerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final season = _seasonCtrl.text.trim();
    if (season.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indique un libellé de saison (ex. 2025-2026).'),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await BestScorerChallengeService.saveAdminConfig(
        BestScorerChallengeConfig(
          enabled: _enabled,
          seasonId: season,
          players: _players,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Défi meilleur buteur enregistré.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde : $e'), backgroundColor: adminRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addPlayer() {
    final name = _playerCtrl.text.trim();
    if (name.isEmpty) return;
    final exists = _players.any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce joueur est déjà dans la liste.'),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    final player = BestScorerPlayer(
      id: BestScorerChallengeService.newPlayerId(name),
      name: name,
    );
    setState(() {
      _players = [..._players, player];
      _playerCtrl.clear();
      _resolvePlayerId ??= player.id;
    });
  }

  void _removePlayer(String id) {
    setState(() {
      _players = _players.where((p) => p.id != id).toList();
      if (_resolvePlayerId == id) {
        _resolvePlayerId = _players.isEmpty ? null : _players.first.id;
      }
    });
  }

  Future<void> _resolveWinner() async {
    final playerId = _resolvePlayerId;
    if (playerId == null || playerId.isEmpty) return;
    BestScorerPlayer? player;
    for (final p in _players) {
      if (p.id == playerId) {
        player = p;
        break;
      }
    }
    final name = player?.name ?? playerId;

    if (_config.awardsApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Déjà résolu : ${_config.resolvedPlayerName ?? name} '
            '(points déjà attribués).',
          ),
          backgroundColor: adminGrey,
        ),
      );
      return;
    }

    final ok = await adminConfirm(
      context,
      'Déclarer « $name » meilleur buteur de la saison '
      '« ${_seasonCtrl.text.trim()} » ?\n\n'
      'Les fans qui ont parié correctement recevront '
      '+${BestScorerChallengeConfig.bonusPoints} points au classement général.\n\n'
      'Action irréversible (pas de double attribution).',
    );
    if (!ok || !mounted) return;

    setState(() => _resolving = true);
    try {
      // Persist list/season first so the CF sees the winner in config.players.
      await BestScorerChallengeService.saveAdminConfig(
        BestScorerChallengeConfig(
          enabled: _enabled,
          seasonId: _seasonCtrl.text.trim(),
          players: _players,
        ),
      );
      final data =
          await BestScorerChallengeService.resolveWinner(playerId: playerId);
      if (!mounted) return;
      final awarded = data['awardedCount'] ?? 0;
      final already = data['alreadyApplied'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: adminGreenAccent,
          content: Text(
            already
                ? 'Déjà résolu — $awarded fan(s) avaient reçu les points.'
                : 'Meilleur buteur déclaré : $name · +${BestScorerChallengeConfig.bonusPoints} pts pour $awarded fan(s).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? e.code),
          backgroundColor: adminRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: adminRed),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'DÉFI MEILLEUR BUTEUR',
      icon: Icons.emoji_events_rounded,
      color: AdminUniverse.jeux.color,
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
                    'À l’activation, les fans voient un défi d’accueil dans Pronos : '
                    'qui finira meilleur buteur ? En fin de saison, déclare le '
                    'vainqueur pour attribuer +${BestScorerChallengeConfig.bonusPoints} pts.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.4,
                      color: adminGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Défi actif',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'Visible dans l’onglet Pronos (si hub activé).'
                          : 'Masqué — les fans ne voient pas le défi.',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                    ),
                    value: _enabled,
                    activeColor: adminGold,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _seasonCtrl,
                    label: 'Saison (ex. 2025-2026)',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'LISTE DES JOUEURS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: adminGold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AdminField(
                          ctrl: _playerCtrl,
                          label: 'Nom du joueur',
                          hint: 'ex. Dupont',
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addPlayer,
                        style: FilledButton.styleFrom(
                          backgroundColor: adminGold,
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
                  const SizedBox(height: 10),
                  if (_players.isEmpty)
                    Text(
                      'Aucun joueur — ajoute des noms pour le menu déroulant fans.',
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
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: adminTextPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _config.awardsApplied
                                    ? null
                                    : () => _removePlayer(p.id),
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
                        backgroundColor: AdminUniverse.jeux.color,
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
                              'ENREGISTRER LE DÉFI',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: adminBorder, height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'DÉCLARER LE MEILLEUR BUTEUR',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: adminRed,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _config.awardsApplied
                        ? 'Résolu : ${_config.resolvedPlayerName ?? '—'} '
                            '(${_config.awardsAppliedAt != null ? 'points attribués' : 'ok'}).'
                        : 'En fin de saison — sélectionne le vainqueur réel. '
                            '+${BestScorerChallengeConfig.bonusPoints} pts aux bons paris.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.4,
                      color: adminGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_players.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _players.any((p) => p.id == _resolvePlayerId)
                          ? _resolvePlayerId
                          : _players.first.id,
                      decoration: InputDecoration(
                        labelText: 'Meilleur buteur de la saison',
                        labelStyle:
                            GoogleFonts.inter(fontSize: 12, color: adminGrey),
                        filled: true,
                        fillColor: adminSurface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: adminBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: adminGold, width: 1.4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                      ),
                      dropdownColor: adminSurface,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: adminTextPrimary,
                      ),
                      items: _players
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: _config.awardsApplied
                          ? null
                          : (v) => setState(() => _resolvePlayerId = v),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_resolving ||
                              _config.awardsApplied ||
                              _players.isEmpty)
                          ? null
                          : _resolveWinner,
                      style: FilledButton.styleFrom(
                        backgroundColor: adminRed,
                        foregroundColor: adminOnAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _resolving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: adminOnAccent,
                              ),
                            )
                          : Text(
                              'DÉCLARER & ATTRIBUER +${BestScorerChallengeConfig.bonusPoints} PTS',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firestore · app_config/best_scorer_challenge',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                ],
              ),
            ),
    );
  }
}
