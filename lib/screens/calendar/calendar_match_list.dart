import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dvcr_share_service.dart';

import '../../models/match_model.dart';
import '../../utils/share_helper.dart';
import '../../widgets/dvcr_share_favorite_controls.dart';
import '../match_detail_screen.dart';
import 'calendar_helpers.dart';
import 'calendar_palette.dart';

class MatchSectionsList extends StatelessWidget {
  final List<MatchModel> matches;
  final CalendarViewMode mode;
  final DateTime? selectedDay;

  const MatchSectionsList({
    super.key,
    required this.matches,
    required this.mode,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: kSedanIvory,
                  shape: BoxShape.circle,
                  border: Border.all(color: kSedanGold, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: kSedanGold.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  mode == CalendarViewMode.upcoming
                      ? Icons.event_busy_rounded
                      : Icons.sports_score_rounded,
                  color: kSedanGreenDeep,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                selectedDay != null
                    ? 'Aucun match ce jour'
                    : mode == CalendarViewMode.upcoming
                    ? 'Aucune rencontre a venir'
                    : 'Aucun resultat sur cette periode',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kSedanText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Change de mois, filtre par compétition ou touche un jour pour affiner la liste.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kSedanMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <DateTime, List<MatchModel>>{};
    for (final match in matches) {
      final key = DateTime(match.date.year, match.date.month, match.date.day);
      grouped.putIfAbsent(key, () => []).add(match);
    }
    final days = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final sectionMatches = grouped[day]!
          ..sort((a, b) => a.date.compareTo(b.date));
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionDatePill(date: day),
              const SizedBox(height: 10),
              ...sectionMatches.map(
                (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SedanFixtureCard(match: match),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SedanFixtureCard extends StatelessWidget {
  final MatchModel match;

  const SedanFixtureCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final isFinished = match.status == MatchStatus.finished;
    final isLive = match.status == MatchStatus.live;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kSedanCard,
          borderRadius: BorderRadius.circular(22),
          border: Border(
            left: const BorderSide(color: kSedanGold, width: 6),
            top: BorderSide(color: kSedanBorder),
            right: BorderSide(color: kSedanBorder),
            bottom: BorderSide(color: kSedanBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: kSedanGreenDeep.withAlpha(22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                ),
                gradient: const LinearGradient(
                  colors: [kSedanGreen, kSedanGreenDeep],
                ),
                border: Border(
                  bottom: BorderSide(color: kSedanGold.withAlpha(70)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      match.competition,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () =>
                          DvcrShare.share(ShareHelper.matchText(match)),
                      child: Tooltip(
                        message: 'Partager ce match',
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.ios_share_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isLive)
                    const _StatusBadge(label: 'DIRECT', color: kSedanRed)
                  else if (isFinished)
                    _StatusBadge(
                      label: 'TERMINÉ',
                      color: Colors.white.withAlpha(55),
                      bordered: true,
                    )
                  else
                    _StatusBadge(
                      label: 'À VENIR',
                      color: Colors.white.withAlpha(40),
                      bordered: true,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TeamSide(
                          name: match.team1,
                          logoUrl: match.logo1,
                          alignEnd: false,
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Column(
                          children: [
                            Text(
                              isFinished
                                  ? (match.score1 != null
                                      ? '${match.score1} - ${match.score2}'
                                      : '? - ?')
                                  : timeLabel(match.date),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: isFinished ? 34 : 28,
                                fontWeight: FontWeight.w900,
                                color: kSedanText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              isFinished
                                  ? Icons.sports_score_rounded
                                  : isLive
                                  ? Icons.live_tv_rounded
                                  : Icons.notifications_active_rounded,
                              color: isLive ? kSedanRed : kSedanGreen,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _TeamSide(
                          name: match.team2,
                          logoUrl: match.logo2,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: kSedanIvory,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.emoji_events_outlined,
                                color: kSedanGreen,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    matchSubtitle(match),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kSedanGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isFinished
                                        ? 'Voir le detail complet du match'
                                        : 'Tape pour ouvrir la fiche rencontre',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: kSedanMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      DvcrMatchShareFavoriteRow(
                        match: match,
                        mutedIconColor: kSedanGreen,
                        activeFavoriteColor: kSedanGold,
                        iconSize: 19,
                        showShare: false,
                      ),
                    ],
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

class _SectionDatePill extends StatelessWidget {
  final DateTime date;

  const _SectionDatePill({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: kSedanGold,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSedanGreenDeep, width: 2),
        boxShadow: [
          BoxShadow(
            color: kSedanGold.withAlpha(120),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 18,
            color: kSedanGreenDeep,
          ),
          const SizedBox(width: 10),
          Text(
            fullDateLabel(date),
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: kSedanGreenDeep,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamSide extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool alignEnd;

  const _TeamSide({
    required this.name,
    required this.logoUrl,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: kSedanIvory,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kSedanBorder),
          ),
          child: logoUrl != null && logoUrl!.trim().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => _fallbackLogo(),
                  ),
                )
              : _fallbackLogo(),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: kSedanText,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _fallbackLogo() {
    return const Icon(Icons.shield_outlined, color: kSedanGreen, size: 26);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool bordered;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: bordered
            ? Border.all(color: Colors.white.withAlpha(100))
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

