import 'package:flutter/material.dart';

import '../../../../models/best_scorer_challenge_config.dart';
import '../../../../services/best_scorer_challenge_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';

List<BestScorerPlayer> _uniquePlayers(List<BestScorerPlayer> players) {
  final seen = <String>{};
  final out = <BestScorerPlayer>[];
  for (final p in players) {
    if (p.id.isEmpty || !seen.add(p.id)) continue;
    out.add(p);
  }
  return out;
}

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
    final unique = _uniquePlayers(widget.config.players);
    if (unique.isNotEmpty) {
      _selectedId = unique.first.id;
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
            style: PronoType.body.copyWith(
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
          content: Text(BestScorerChallengeService.userFacingWriteError(e)),
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
          content: Text(BestScorerChallengeService.userFacingWriteError(e)),
          backgroundColor: PronoTokens.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = _uniquePlayers(widget.config.players);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selectedId = players.any((p) => p.id == _selectedId)
        ? _selectedId
        : (players.isEmpty ? null : players.first.id);

    return PronoThemeScope(
      pageAccent: PronoPageAccent.accueil,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 48,
                    color: PronoPageAccent.accueil.color,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bienvenue sur les pronos par DVCR !',
                    textAlign: TextAlign.center,
                    style: PronoType.headline,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'On te challenge dès maintenant — qui va finir '
                    'meilleur buteur cette saison ?',
                    textAlign: TextAlign.center,
                    style: PronoType.body.copyWith(
                      color: PronoTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Ton choix',
                    style: PronoType.meta.copyWith(color: PronoTokens.textSoft),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    isExpanded: true,
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
                    style: PronoType.body.copyWith(fontWeight: FontWeight.w600),
                    items: players
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    style: PronoType.caption.copyWith(
                      color: PronoTokens.textSoft,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                            style: PronoType.label.copyWith(fontSize: 15),
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
                      style: PronoType.label.copyWith(
                        fontSize: 15,
                        color: PronoTokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu dois parier ou ignorer pour accéder aux pronos.',
                    textAlign: TextAlign.center,
                    style: PronoType.meta.copyWith(color: PronoTokens.textSoft),
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

String _lockedPickBlurb(String playerName) {
  final n = playerName.trim();
  if (n.isEmpty) return 'C’est verrouillé. On croise les doigts.';
  return 'C’est verrouillé — plus on touche, plus ça porte malheur. '
      'Que le filet tremble pour $n.';
}

/// Pastille Accueil — pari figé (plus de modification).
class BestScorerChallengeHomeChip extends StatelessWidget {
  final String uid;

  const BestScorerChallengeHomeChip({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BestScorerChallengeConfig>(
      stream: BestScorerChallengeService.watchConfig(),
      builder: (context, cfgSnap) {
        if (cfgSnap.hasError) return const SizedBox.shrink();
        final config = cfgSnap.data ?? BestScorerChallengeConfig.defaults;
        if (!config.enabled) return const SizedBox.shrink();

        return StreamBuilder<BestScorerPick?>(
          stream: BestScorerChallengeService.watchPick(uid),
          builder: (context, pickSnap) {
            if (pickSnap.hasError) return const SizedBox.shrink();
            final response = BestScorerChallengeService.responseForSeason(
              pickSnap.data,
              config,
            );

            if (response == null || !response.isPicked) {
              return const SizedBox.shrink();
            }

            final name = response.playerName.trim().isEmpty
                ? '—'
                : response.playerName.trim();

            if (config.isResolved) {
              final won = response.playerId == config.resolvedPlayerId;
              final winner = (config.resolvedPlayerName ?? '').trim();
              return _LockedPickCard(
                playerName: name,
                blurb: won
                    ? 'Tu l’avais vu. +${BestScorerChallengeConfig.bonusPoints} pts, '
                        't’es un devin.'
                    : (winner.isEmpty
                        ? 'Cette fois le filet a choisi quelqu’un d’autre.'
                        : 'Cette fois c’est $winner qui a fini devant. '
                            'T’avais misé $name — on retient le culot.'),
              );
            }

            return _LockedPickCard(
              playerName: name,
              blurb: _lockedPickBlurb(name),
            );
          },
        );
      },
    );
  }
}

class _LockedPickCard extends StatelessWidget {
  final String playerName;
  final String blurb;

  const _LockedPickCard({
    required this.playerName,
    required this.blurb,
  });

  @override
  Widget build(BuildContext context) {
    final accent = PronoPageAccent.accueil.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PronoTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
        border: Border.all(color: PronoTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_rounded, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TON VOTE DU MEILLEUR BUTEUR',
                    style: PronoType.kicker.copyWith(
                      color: PronoTokens.textSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playerName,
                    style: PronoType.fixture,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    blurb,
                    style: PronoType.caption.copyWith(
                      color: PronoTokens.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
