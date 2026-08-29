import 'package:flutter/material.dart';

import '../../models/season_palmares.dart';
import '../../navigation/main_shell_insets.dart';
import '../../services/season_palmares_service.dart';
import '../calendar/theme/calendar_theme.dart';
import '../calendar/theme/calendar_type.dart';
import '../calendar/widgets/calendar_ui.dart';
import 'matches_helpers.dart';

/// Onglet calendrier «Récap** : notes du match + Hommes du match, saison en cours.
class MatchesRecapTab extends StatelessWidget {
  const MatchesRecapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SeasonPalmares>(
      stream: SeasonPalmaresService.watchCurrentSeason(),
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MainShellInsets.tabScrollTail(context, extra: 8),
            ),
            children: const [
              CalendarErrorState(
                title: 'Récap indisponible',
                body:
                    'Impossible de charger les notes et les Hommes du match. '
                    'Vérifie ta connexion et réessaie.',
              ),
            ],
          );
        }

        if (!snap.hasData) {
          return ListView(
            padding: EdgeInsets.only(
              top: 8,
              bottom: MainShellInsets.tabScrollTail(context, extra: 8),
            ),
            children: const [CalendarLoadingTape(rows: 6)],
          );
        }

        final palmares = snap.data!;
        if (palmares.isEmpty) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MainShellInsets.tabScrollTail(context, extra: 8),
            ),
            children: [
              CalendarEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Encore personne',
                body:
                    'Saison ${palmares.seasonLabel}\n'
                    'Personne n’a encore été Homme du match en Régional 1, '
                    'et aucune note n’a été déposée. Votez samedi.',
              ),
            ],
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            CalendarTheme.gutter,
            16,
            CalendarTheme.gutter,
            MainShellInsets.tabScrollTail(context, extra: 8),
          ),
          children: [
            _SeasonNoteCard(palmares: palmares),
            const SizedBox(height: 22),
            const CalendarSectionHeader(title: 'Homme du match'),
            const SizedBox(height: 8),
            if (palmares.hdm.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pas encore de trophée cette saison — votez samedi.',
                  style: CalendarType.caption,
                ),
              )
            else
              ...palmares.hdm.map((row) => _HdmTile(tally: row)),
            const SizedBox(height: 18),
            CalendarSectionHeader(
              title: 'Notes du match',
              countLabel: palmares.ratedMatchCount == 0
                  ? null
                  : '${palmares.ratedMatchCount} match'
                      '${palmares.ratedMatchCount > 1 ? 's' : ''}',
            ),
            const SizedBox(height: 8),
            if (palmares.noteHistory.isEmpty)
              Text(
                'Aucune note déposée pour l’instant.',
                style: CalendarType.caption,
              )
            else
              ...palmares.noteHistory.map((row) => _NoteHistoryTile(row: row)),
          ],
        );
      },
    );
  }
}

class _SeasonNoteCard extends StatelessWidget {
  const _SeasonNoteCard({required this.palmares});

  final SeasonPalmares palmares;

  @override
  Widget build(BuildContext context) {
    final hasNote = palmares.averageNote != null;
    return Container(
      decoration: CalendarTheme.fixturePaper(sedan: true),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAISON ${palmares.seasonLabel}',
            style: CalendarType.kicker.copyWith(color: CalendarTheme.text),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasNote ? palmares.averageNoteLabel : '—',
                style: CalendarType.display.copyWith(
                  color: hasNote ? CalendarTheme.green : CalendarTheme.textMuted,
                ),
              ),
              if (hasNote) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ 10',
                    style: CalendarType.meta.copyWith(
                      color: CalendarTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasNote
                ? (palmares.ratedMatchCount == 1
                    ? 'Moyenne R1 · 1 match noté'
                    : 'Moyenne R1 · ${palmares.ratedMatchCount} matchs notés')
                : 'Les notes du match arriveront après le premier vote.',
            style: CalendarType.caption,
          ),
          if (palmares.hdm.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: CalendarTheme.hairline),
            const SizedBox(height: 10),
            Text(
              palmares.hdm.take(3).map((p) {
                final times = p.count > 1 ? ' (${p.count})' : '';
                return '${p.name}$times';
              }).join('  ·  '),
              style: CalendarType.label,
            ),
            const SizedBox(height: 4),
            Text(
              palmares.hdm.length == 1
                  ? 'Dernier Homme du match'
                  : 'Les plus titrés',
              style: CalendarType.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _HdmTile extends StatelessWidget {
  const _HdmTile({required this.tally});

  final HdmPlayerTally tally;

  @override
  Widget build(BuildContext context) {
    final times = tally.count == 1 ? '1 fois' : '${tally.count} fois';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: CalendarTheme.fixturePaper(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tally.name, style: CalendarType.fixture),
              ),
              Text(
                times,
                style: CalendarType.meta.copyWith(
                  color: CalendarTheme.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tally.matches
                .map(
                  (m) =>
                      '${shortDateLabel(m.date)} · ${m.fixtureLabel}',
                )
                .join('\n'),
            style: CalendarType.caption,
          ),
        ],
      ),
    );
  }
}

class _NoteHistoryTile extends StatelessWidget {
  const _NoteHistoryTile({required this.row});

  final RatedMatchRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: CalendarTheme.fixturePaper(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.fixtureLabel, style: CalendarType.label),
                const SizedBox(height: 3),
                Text(shortDateLabel(row.date), style: CalendarType.meta),
              ],
            ),
          ),
          Text(
            SeasonPalmares.formatClubNote(row.average),
            style: CalendarType.rank.copyWith(color: CalendarTheme.green),
          ),
        ],
      ),
    );
  }
}
