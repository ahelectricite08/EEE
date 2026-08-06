import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/best_scorer_challenge_config.dart';
import '../../../../services/best_scorer_challenge_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';

/// Écran plein page bloquant — aucun accès Prono tant que non répondu.
class BestScorerChallengeGatePage extends StatefulWidget {
  final String uid;
  final BestScorerChallengeConfig config;

  const BestScorerChallengeGatePage({
    super.key,
    required this.uid,
    required this.config,
  });

  @override
  State<BestScorerChallengeGatePage> createState() =>
      _BestScorerChallengeGatePageState();
}

class _BestScorerChallengeGatePageState
    extends State<BestScorerChallengeGatePage> {
  String? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.config.players.isNotEmpty) {
      _selectedId = widget.config.players.first.id;
    }
  }

  Future<void> _confirmPick() async {
    final id = _selectedId;
    if (id == null) return;
    final player = widget.config.playerById(id);
    if (player == null) return;

    setState(() => _saving = true);
    try {
      await BestScorerChallengeService.savePick(
        uid: widget.uid,
        seasonId: widget.config.seasonId,
        player: player,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: PronoTokens.accentDeep,
          content: Text(
            'C’est noté — ton pari : ${player.name}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: PronoTokens.onAccent,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’enregistrer : $e'),
          backgroundColor: PronoTokens.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _ignore() async {
    setState(() => _saving = true);
    try {
      await BestScorerChallengeService.saveIgnored(
        uid: widget.uid,
        seasonId: widget.config.seasonId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’ignorer : $e'),
          backgroundColor: PronoTokens.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.config.players;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PronoThemeScope(
      pageAccent: PronoPageAccent.accueil,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 1),
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: PronoPageAccent.accueil.color,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bienvenue sur les pronos par DVCR !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: PronoTokens.text,
                      height: 1.05,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'On te challenge dès maintenant — qui va finir '
                    'meilleur buteur cette saison ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.45,
                      color: PronoTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Ton choix',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PronoTokens.textSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: players.any((p) => p.id == _selectedId)
                        ? _selectedId
                        : (players.isEmpty ? null : players.first.id),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: PronoTokens.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PronoTokens.radiusMd),
                        borderSide: BorderSide(color: PronoTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PronoTokens.radiusMd),
                        borderSide: BorderSide(color: PronoTokens.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PronoTokens.radiusMd),
                        borderSide: BorderSide(
                          color: PronoPageAccent.accueil.color,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    dropdownColor: PronoTokens.surfaceElevated,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PronoTokens.text,
                    ),
                    items: players
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged:
                        _saving ? null : (v) => setState(() => _selectedId = v),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '+${BestScorerChallengeConfig.bonusPoints} points au classement '
                    'général si tu as raison en fin de saison.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.35,
                      color: PronoTokens.textSoft,
                    ),
                  ),
                  const Spacer(flex: 2),
                  FilledButton(
                    onPressed: _saving || players.isEmpty ? null : _confirmPick,
                    style: PronoTheme.primaryCtaStyle(
                      pageAccent: PronoPageAccent.accueil,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PronoTokens.onAccent,
                            ),
                          )
                        : Text(
                            'Je valide mon pari',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _saving ? null : _ignore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PronoTokens.textMuted,
                      side: BorderSide(color: PronoTokens.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PronoTokens.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Ignorer',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu dois parier ou ignorer pour accéder aux pronos.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: PronoTokens.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet pour modifier un pari déjà fait (après le portail).
Future<void> showBestScorerChallengeEditSheet({
  required BuildContext context,
  required String uid,
  required BestScorerChallengeConfig config,
  required BestScorerPick currentPick,
}) async {
  if (!config.isGateActive || !currentPick.isPicked) return;

  await showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return PronoThemeScope(
        pageAccent: PronoPageAccent.accueil,
        child: _BestScorerEditSheet(
          uid: uid,
          config: config,
          initialPick: currentPick,
        ),
      );
    },
  );
}

class _BestScorerEditSheet extends StatefulWidget {
  final String uid;
  final BestScorerChallengeConfig config;
  final BestScorerPick initialPick;

  const _BestScorerEditSheet({
    required this.uid,
    required this.config,
    required this.initialPick,
  });

  @override
  State<_BestScorerEditSheet> createState() => _BestScorerEditSheetState();
}

class _BestScorerEditSheetState extends State<_BestScorerEditSheet> {
  String? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialPick.playerId;
  }

  Future<void> _confirm() async {
    final id = _selectedId;
    if (id == null) return;
    final player = widget.config.playerById(id);
    if (player == null) return;

    setState(() => _saving = true);
    try {
      await BestScorerChallengeService.savePick(
        uid: widget.uid,
        seasonId: widget.config.seasonId,
        player: player,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: PronoTokens.accentDeep,
          content: Text(
            'Pari mis à jour : ${player.name}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: PronoTokens.onAccent,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’enregistrer : $e'),
          backgroundColor: PronoTokens.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final players = widget.config.players;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: PronoTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(PronoTokens.radiusLg),
          border: Border.all(color: PronoTokens.border),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Modifier ton pari',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: players.any((p) => p.id == _selectedId)
                      ? _selectedId
                      : (players.isEmpty ? null : players.first.id),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: PronoTokens.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
                      borderSide: BorderSide(color: PronoTokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
                      borderSide: BorderSide(color: PronoTokens.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  dropdownColor: PronoTokens.surfaceElevated,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PronoTokens.text,
                  ),
                  items: players
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: _saving ? null : (v) => setState(() => _selectedId = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving || players.isEmpty ? null : _confirm,
                  style: PronoTheme.primaryCtaStyle(
                    pageAccent: PronoPageAccent.accueil,
                  ),
                  child: Text(
                    'Enregistrer',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Annuler',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: PronoTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille Accueil — uniquement si le fan a parié (pas si ignoré).
class BestScorerChallengeHomeChip extends StatelessWidget {
  final String uid;

  const BestScorerChallengeHomeChip({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BestScorerChallengeConfig>(
      stream: BestScorerChallengeService.watchConfig(),
      builder: (context, cfgSnap) {
        final config = cfgSnap.data ?? BestScorerChallengeConfig.defaults;
        if (!config.enabled) return const SizedBox.shrink();

        return StreamBuilder<BestScorerPick?>(
          stream: BestScorerChallengeService.watchPick(uid),
          builder: (context, pickSnap) {
            final response = BestScorerChallengeService.responseForSeason(
              pickSnap.data,
              config,
            );

            if (config.isResolved) {
              if (response == null || !response.isPicked) {
                return const SizedBox.shrink();
              }
              final won = response.playerId == config.resolvedPlayerId;
              return _ChipBody(
                icon: Icons.emoji_events_rounded,
                label: won
                    ? 'Défi buteur : gagné ! +${BestScorerChallengeConfig.bonusPoints} pts'
                    : 'Ton pari : ${response.playerName}',
                onTap: null,
              );
            }

            if (response == null || !response.isPicked) {
              return const SizedBox.shrink();
            }

            return _ChipBody(
              icon: Icons.sports_soccer_rounded,
              label: 'Ton pari : ${response.playerName}',
              onTap: config.isGateActive
                  ? () => showBestScorerChallengeEditSheet(
                        context: context,
                        uid: uid,
                        config: config,
                        currentPick: response,
                      )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _ChipBody extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ChipBody({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = PronoPageAccent.accueil.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: PronoTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
            border: Border.all(color: PronoTokens.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PronoTokens.text,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: PronoTokens.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
