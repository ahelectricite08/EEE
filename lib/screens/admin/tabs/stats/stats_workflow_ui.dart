import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import 'stats_admin_helpers.dart';

/// Barre 3 étapes : Préparer → En direct → Officiel.
class StatsWorkflowStepper extends StatelessWidget {
  final StatsWorkflowStep step;

  const StatsWorkflowStepper({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StepDot(label: 'Préparer', active: step.index >= 0, done: step.index > 0)),
        _connector(step.index > 0),
        Expanded(child: _StepDot(label: 'En direct', active: step.index >= 1, done: step.index > 1)),
        _connector(step.index > 1),
        Expanded(child: _StepDot(label: 'Officiel', active: step.index >= 2, done: step.index >= 2)),
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
class StatsMatchDayHero extends StatelessWidget {
  final AdminMatchRowData row;
  final StatsWorkflowStep step;
  final VoidCallback onPrimary;
  final VoidCallback? onSync;
  final VoidCallback? onFinalize;
  final VoidCallback? onReopen;

  const StatsMatchDayHero({
    super.key,
    required this.row,
    required this.step,
    required this.onPrimary,
    this.onSync,
    this.onFinalize,
    this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final isOfficial = step == StatsWorkflowStep.official;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sports_soccer_rounded, color: adminGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'MATCH DU JOUR',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: adminGold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statsWorkflowColor(step).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statsWorkflowColor(step).withAlpha(90)),
                ),
                child: Text(
                  statsWorkflowLabel(step).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statsWorkflowColor(step),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${row.t1} vs ${row.t2}',
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${row.date} · Score ${row.score}',
            style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          ),
          const SizedBox(height: 16),
          StatsWorkflowStepper(step: step),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPrimary,
            icon: Icon(
              isOfficial ? Icons.lock_open_rounded : Icons.play_arrow_rounded,
              size: 20,
            ),
            label: Text(statsPrimaryAction(step)),
            style: FilledButton.styleFrom(
              backgroundColor: adminGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (!isOfficial && (onSync != null || onFinalize != null)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onSync != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSync,
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
                if (onSync != null && onFinalize != null)
                  const SizedBox(width: 8),
                if (onFinalize != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onFinalize,
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
          if (isOfficial && onReopen != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onReopen,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Rouvrir pour corriger'),
              style: OutlinedButton.styleFrom(
                foregroundColor: adminGold,
                side: BorderSide(color: adminGold.withAlpha(120)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            step == StatsWorkflowStep.prepare
                ? 'Arrivée au stade : ouvre la saisie, les champs se remplissent pendant le match.'
                : step == StatsWorkflowStep.live
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
    );
  }
}
