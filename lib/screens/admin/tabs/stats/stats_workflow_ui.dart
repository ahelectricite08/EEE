import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import 'stats_admin_helpers.dart';
/// Barre 3 étapes (indicateur visuel — pas de 2e rangée « onglets » en dessous).
class StatsWorkflowStepper extends StatelessWidget {
  final StatsWorkflowStep step;

  const StatsWorkflowStepper({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepDot(
            label: statsWorkflowLabel(StatsWorkflowStep.prepare),
            active: step.index >= 0,
            done: step.index > 0,
          ),
        ),
        _connector(step.index > 0),
        Expanded(
          child: _StepDot(
            label: statsWorkflowLabel(StatsWorkflowStep.live),
            active: step.index >= 1,
            done: step.index > 1,
          ),
        ),
        _connector(step.index > 1),
        Expanded(
          child: _StepDot(
            label: statsWorkflowLabel(StatsWorkflowStep.official),
            active: step.index >= 2,
            done: step.index >= 2,
          ),
        ),
      ],
    );
  }

  Widget _connector(bool done) => Container(
    width: 20,
    height: 2,
    margin: const EdgeInsets.only(bottom: 18),
    color: done ? adminGold.withAlpha(180) : adminBorder,
  );
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _StepDot({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? adminGreenAccent
        : active
            ? adminGold
            : adminGrey;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color.withAlpha(40) : adminSurface,
            border: Border.all(color: color, width: active ? 2 : 1),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded, size: 16, color: color)
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? color : adminBorder,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: active ? adminTextPrimary : adminGrey,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// Carte match du jour — point d’entrée unique pour les statisticiens.
class StatsMatchDayHero extends StatefulWidget {
  final AdminMatchRowData row;
  final StatsWorkflowStep step;
  final String? heroTitle;
  final VoidCallback onPrimary;
  final VoidCallback? onSync;
  final VoidCallback? onFinalize;
  final VoidCallback? onReopen;

  const StatsMatchDayHero({
    super.key,
    required this.row,
    required this.step,
    this.heroTitle,
    required this.onPrimary,
    this.onSync,
    this.onFinalize,
    this.onReopen,
  });

  @override
  State<StatsMatchDayHero> createState() => _StatsMatchDayHeroState();
}

class _StatsMatchDayHeroState extends State<StatsMatchDayHero> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isOfficial = widget.step == StatsWorkflowStep.official;
    final stepColor = statsWorkflowColor(widget.step);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            adminGold.withAlpha(28),
            adminCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: adminGold.withAlpha(90)),
        boxShadow: adminCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(Icons.sports_soccer_rounded, color: adminGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.heroTitle ?? 'MATCH DU JOUR',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: adminGold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_expanded) ...[
                      Expanded(
                        child: Text(
                          '${widget.row.t1} vs ${widget.row.t2} · ${widget.row.score}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: adminTextPrimary,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stepColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: stepColor.withAlpha(90)),
                      ),
                      child: Text(
                        statsWorkflowLabel(widget.step).toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: stepColor,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _expanded
                          ? 'Réduire pour voir la liste'
                          : 'Développer le match du jour',
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: adminGrey,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeInCubic,
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 220),
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${widget.row.t1} vs ${widget.row.t2}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.row.date} · Score ${widget.row.score}',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  ),
                  const SizedBox(height: 16),
                  StatsWorkflowStepper(step: widget.step),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.onPrimary,
                    icon: Icon(
                      isOfficial
                          ? Icons.lock_open_rounded
                          : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(statsPrimaryAction(widget.step)),
                    style: FilledButton.styleFrom(
                      backgroundColor: adminGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (!isOfficial &&
                      (widget.onSync != null || widget.onFinalize != null)) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (widget.onSync != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onSync,
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Publier dans l\'app'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4A90D9),
                                side: BorderSide(
                                  color: const Color(0xFF4A90D9).withAlpha(140),
                                ),
                              ),
                            ),
                          ),
                        if (widget.onSync != null && widget.onFinalize != null)
                          const SizedBox(width: 8),
                        if (widget.onFinalize != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onFinalize,
                              icon: const Icon(Icons.flag_rounded, size: 16),
                              label: const Text('Terminer'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: adminGreenAccent,
                                side: BorderSide(
                                  color: adminGreenAccent.withAlpha(140),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (isOfficial && widget.onReopen != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: widget.onReopen,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Rouvrir la saisie (rapide)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: adminGold,
                        side: BorderSide(color: adminGold.withAlpha(120)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    widget.step == StatsWorkflowStep.prepare
                        ? 'Arrivée au stade : ouvre la saisie, les champs se remplissent pendant le match.'
                        : widget.step == StatsWorkflowStep.live
                            ? 'Pendant le match : saisie auto-enregistrée, publication toutes les 5 min.'
                            : 'Match terminé. Rouvre si tu dois corriger une stat.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: adminGrey,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onPrimary,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(
                        statsPrimaryAction(widget.step),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: adminGold,
                        side: BorderSide(color: adminGold.withAlpha(120)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
