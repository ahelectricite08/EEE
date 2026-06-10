import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/dvcr_share_service.dart';

import '../../models/fff_season_config.dart';
import '../../models/match_model.dart';
import '../../models/video_model.dart';
import '../../services/match_service.dart';
import '../../services/season_config_service.dart';
import '../../utils/match_calendar_filter.dart';
import '../../services/user_preferences_service.dart';
import '../../services/user_service.dart';
import '../../utils/open_prono_for_match.dart';
import '../../navigation/prono_championship_rollout.dart';
import '../../models/season_lifecycle_config.dart';
import '../../services/season_lifecycle_service.dart';
import '../../utils/share_helper.dart';
import '../../utils/youtube_parser.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../match_detail_screen.dart';
import '../video_web_screen.dart';
import 'matches_helpers.dart';
import 'matches_palette.dart';

Stream<String?> _watchHomeStadiumImage(String teamName) => FirebaseFirestore
    .instance
    .collection('teams')
    .where('name', isEqualTo: teamName)
    .limit(1)
    .snapshots()
    .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final url = (snapshot.docs.first.data()['stadiumImageUrl'] as String?)
          ?.trim();
      return (url == null || url.isEmpty) ? null : url;
    });

DateTime _pronoOpenAt(DateTime matchDate) => DateTime(
  matchDate.year,
  matchDate.month,
  matchDate.day,
).subtract(const Duration(days: 7));

bool _isPronoOpen(DateTime matchDate) {
  final now = DateTime.now();
  return now.isAfter(_pronoOpenAt(matchDate)) && now.isBefore(matchDate);
}

String _pronoStatusLabel(DateTime matchDate) {
  if (_isPronoOpen(matchDate)) return 'Pronostiquer';
  final now = DateTime.now();
  final openAt = _pronoOpenAt(matchDate);
  if (!now.isBefore(openAt)) return 'Bientôt fermé';
  final diff = openAt.difference(now);
  final days = diff.inDays;
  if (days <= 0) return 'À pronostiquer bientôt';
  if (days == 1) return 'A pronostiquer dans 1 jour';
  return 'A pronostiquer dans $days jours';
}

class MatchesFeedTab extends StatefulWidget {
  final MatchesViewMode mode;
  final DateTime focusMonth;

  const MatchesFeedTab({
    super.key,
    required this.mode,
    required this.focusMonth,
  });

  @override
  State<MatchesFeedTab> createState() => _MatchesFeedTabState();
}

class _MatchesFeedTabState extends State<MatchesFeedTab> {
  String? _selectedCompetition;
  String? _selectedTeam;
  String? _favoriteTeam;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.canModerate().then((value) {
      if (mounted) setState(() => _isAdmin = value);
    });
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    UserPreferencesService.instance.addListener(_handleFavoriteTeamChanged);
    unawaited(UserPreferencesService.instance.init());
  }

  @override
  void dispose() {
    UserPreferencesService.instance.removeListener(_handleFavoriteTeamChanged);
    super.dispose();
  }

  void _handleFavoriteTeamChanged() {
    final next = UserPreferencesService.instance.favoriteTeam;
    if (!mounted || _favoriteTeam == next) {
      return;
    }

    setState(() {
      _favoriteTeam = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Résultats : requête par mois (sinon allResults() est limité à 100 docs → mois anciens vides).
    final stream = widget.mode == MatchesViewMode.upcoming
        ? MatchService.upcoming()
        : MatchService.forMonth(
            widget.focusMonth.year,
            widget.focusMonth.month,
          );

    return StreamBuilder<FffSeasonConfig>(
      stream: SeasonConfigService.stream(),
      builder: (context, seasonSnap) {
        final season = seasonSnap.data ?? FffSeasonConfig.defaults;
        return StreamBuilder<SeasonLifecycleConfig>(
          stream: SeasonLifecycleService.stream(),
          builder: (context, lifeSnap) {
            final life =
                lifeSnap.data ?? SeasonLifecycleConfig.defaults;
            final between = life.betweenSeasons;

            return StreamBuilder<List<MatchModel>>(
              key: ValueKey<Object>(
                '${widget.mode.name}_${widget.focusMonth.year}_${widget.focusMonth.month}_${between}_${season.seasonLabel}',
              ),
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                    children: [
                      _MatchesIntroCard(mode: widget.mode),
                      const DVCRMatchCardSkeleton(),
                      const DVCRMatchCardSkeleton(),
                      const DVCRMatchCardSkeleton(),
                    ],
                  );
                }
                final noMockBetween =
                    between && widget.mode == MatchesViewMode.upcoming;
                var source = snapshot.hasData
                    ? snapshot.data!.where((m) {
                        // Saison correcte
                        if (!MatchCalendarFilter.belongsToSeason(
                          m,
                          displaySeason: season.seasonLabel,
                          activeSeasonLabel: season.seasonLabel,
                        )) return false;
                        // Compétition reconnue
                        if (!m.manual &&
                            !MatchCalendarFilter.isListedCompetition(
                                m.competition)) {
                          return false;
                        }
                        // Pas un upcoming périmé
                        if (MatchCalendarFilter.isStaleUpcoming(m)) {
                          return false;
                        }
                        return true;
                      }).toList()
                    : <MatchModel>[];
                if (widget.mode == MatchesViewMode.results) {
                  source = source
                      .where((m) => m.status == MatchStatus.finished)
                      .toList();
                } else {
                  final now = DateTime.now();
                  source = source
                      .where(
                        (m) =>
                            m.status == MatchStatus.live ||
                            (m.status == MatchStatus.upcoming &&
                                !m.date.isBefore(now)),
                      )
                      .toList();
                }
        final competitions =
            source.map((match) => match.competition).toSet().toList()..sort();
        final teams =
            source
                .expand((match) => [match.team1, match.team2])
                .toSet()
                .toList()
              ..sort();
        final filtered = source.where((match) {
          if (_selectedCompetition != null &&
              match.competition != _selectedCompetition) {
            return false;
          }
          if (_selectedTeam != null &&
              !matchIncludesPreferredTeam(match, _selectedTeam)) {
            return false;
          }
          return true;
        }).toList();

        final scoped = filtered
            .where(
              (match) =>
                  match.date.year == widget.focusMonth.year &&
                  match.date.month == widget.focusMonth.month,
            )
            .toList();

        final grouped = groupMatchesByDay(
          scoped,
          descending: widget.mode == MatchesViewMode.results,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: [
            _MatchesIntroCard(mode: widget.mode),
            _MatchesFilterBar(
              competitions: competitions,
              teams: teams,
              selectedCompetition: _selectedCompetition,
              selectedTeam: _selectedTeam,
              favoriteTeam: _favoriteTeam,
              onSelectCompetition: (value) =>
                  setState(() => _selectedCompetition = value),
              onSelectTeam: (value) => setState(() => _selectedTeam = value),
            ),
            if (scoped.isEmpty)
              _EmptyMatchesState(
                mode: widget.mode,
                focusMonth: widget.focusMonth,
                hadAnyBeforeMonth: filtered.isNotEmpty,
                titleOverride: noMockBetween ? life.upcomingWaitTitle : null,
                subtitleOverride:
                    noMockBetween ? life.upcomingWaitSubtitle : null,
              )
            else
              ...grouped.entries.expand((entry) {
                return [
                  _MatchesSectionHeader(label: sectionDateLabel(entry.key)),
                  ...entry.value.map(
                    (match) {
                      final isFeatured =
                          isSedanTeam(match.team1) ||
                          isSedanTeam(match.team2) ||
                          (_favoriteTeam != null &&
                              matchIncludesPreferredTeam(
                                  match, _favoriteTeam));
                      return isFeatured
                          ? Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: _MatchesEventCard(
                                match: match,
                                mode: widget.mode,
                                isAdmin: _isAdmin,
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: _MatchCompactRow(
                                match: match,
                                mode: widget.mode,
                              ),
                            );
                    },
                  ),
                ];
              }),
          ],
        );
              },
            );
          },
        );
      },
    );
  }
}

class _MatchesIntroCard extends StatelessWidget {
  final MatchesViewMode mode;

  const _MatchesIntroCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = mode == MatchesViewMode.upcoming;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kMatchesGreenDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kMatchesGold.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(
            isUpcoming
                ? Icons.calendar_month_rounded
                : Icons.emoji_events_rounded,
            color: kMatchesGold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpcoming ? 'CALENDRIER' : 'RÉSULTATS',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: kMatchesGold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  isUpcoming
                      ? 'Tous les matchs à venir'
                      : 'Scores & stats des matchs joués',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchesFilterBar extends StatelessWidget {
  final List<String> competitions;
  final List<String> teams;
  final String? selectedCompetition;
  final String? selectedTeam;
  final String? favoriteTeam;
  final ValueChanged<String?> onSelectCompetition;
  final ValueChanged<String?> onSelectTeam;

  const _MatchesFilterBar({
    required this.competitions,
    required this.teams,
    required this.selectedCompetition,
    required this.selectedTeam,
    required this.onSelectCompetition,
    required this.onSelectTeam,
    this.favoriteTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isFavActive =
        favoriteTeam != null &&
        teamMatchesPreference(selectedTeam ?? '', favoriteTeam);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (favoriteTeam != null) ...[
              _FilterActionChip(
                label: '⭐ Mon équipe',
                active: isFavActive,
                onTap: () => onSelectTeam(isFavActive ? null : favoriteTeam),
              ),
              const SizedBox(width: 8),
            ],
            _FilterActionChip(
              label: selectedCompetition ?? 'Tout',
              active: selectedCompetition != null,
              onTap: () => _showPicker(
                context: context,
                title: 'Competition',
                options: competitions,
                selected: selectedCompetition,
                onSelected: onSelectCompetition,
              ),
            ),
            const SizedBox(width: 8),
            _FilterActionChip(
              label: selectedTeam ?? 'Equipe',
              active: selectedTeam != null && !isFavActive,
              onTap: () => _showPicker(
                context: context,
                title: 'Equipe',
                options: teams,
                selected: selectedTeam,
                onSelected: onSelectTeam,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F2E9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Poignée ─────────────────────────────────────────────
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kMatchesBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kMatchesText,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (selected != null)
                        GestureDetector(
                          onTap: () {
                            onSelected(null);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kMatchesGreen.withAlpha(18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Réinitialiser',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kMatchesGreen,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: kMatchesMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: kMatchesBorder),
                // ── Liste ───────────────────────────────────────────────
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: kMatchesBorder, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final option = options[i];
                      final isSelected = selected == option;
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? kMatchesGreen
                                        : kMatchesText,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: kMatchesGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterActionChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterActionChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kMatchesText : kMatchesCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? kMatchesGold.withAlpha(200) : kMatchesBorder,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: kMatchesGold.withAlpha(55),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : kMatchesText,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? kMatchesGold : kMatchesMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchesSectionHeader extends StatelessWidget {
  final String label;

  const _MatchesSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: kMatchesGold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kMatchesText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne compacte pour matchs hors équipe featured ───────────────────────────
class _MatchCompactRow extends StatelessWidget {
  final MatchModel match;
  final MatchesViewMode mode;

  const _MatchCompactRow({required this.match, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isResult = mode == MatchesViewMode.results;
    final score1 = match.score1;
    final score2 = match.score2;
    final hasScore = score1 != null && score2 != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kMatchesCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kMatchesBorder),
      ),
      child: Row(
        children: [
          // Logo équipe 1
          _MicroLogo(logo: match.logo1, name: match.team1),
          const SizedBox(width: 8),
          // Nom équipe 1
          Expanded(
            child: Text(
              match.team1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kMatchesText,
              ),
            ),
          ),
          // Score ou heure
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: isResult && hasScore
                ? Text(
                    '$score1 - $score2',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: kMatchesText,
                      height: 1,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kMatchesGreenDeep,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      matchTimeLabel(match.date),
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
          ),
          // Nom équipe 2
          Expanded(
            child: Text(
              match.team2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kMatchesText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Logo équipe 2
          _MicroLogo(logo: match.logo2, name: match.team2),
        ],
      ),
    );
  }
}

class _MicroLogo extends StatelessWidget {
  final String? logo;
  final String name;

  const _MicroLogo({required this.logo, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kMatchesBorder),
      ),
      child: logo != null && logo!.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(3),
              child: Image.network(
                logo!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _FallbackBadge(name: name),
              ),
            )
          : _FallbackBadge(name: name),
    );
  }
}

class _MatchesEventCard extends StatelessWidget {
  final MatchModel match;
  final MatchesViewMode mode;
  final bool isAdmin;

  const _MatchesEventCard({
    required this.match,
    required this.mode,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final isUpcoming = mode == MatchesViewMode.upcoming;
    final isSedanHome = isSedanTeam(match.team1);
    final isSedanAway = isSedanTeam(match.team2);
    final isSedanMatch = isSedanHome || isSedanAway;
    final isLive = match.status == MatchStatus.live;
    final accent = isLive ? kMatchesRed : kMatchesGreen;
    final embeddedImage = match.stadiumImageUrl?.trim();
    final hasEmbeddedImage = embeddedImage != null && embeddedImage.isNotEmpty;

    if (hasEmbeddedImage) {
      return _buildCard(
        context,
        isUpcoming: isUpcoming,
        isSedanHome: isSedanHome,
        isSedanAway: isSedanAway,
        isSedanMatch: isSedanMatch,
        accent: accent,
        stadiumImageUrl: embeddedImage,
      );
    }

    return StreamBuilder<String?>(
      stream: _watchHomeStadiumImage(match.team1),
      builder: (context, snapshot) {
        return _buildCard(
          context,
          isUpcoming: isUpcoming,
          isSedanHome: isSedanHome,
          isSedanAway: isSedanAway,
          isSedanMatch: isSedanMatch,
          accent: accent,
          stadiumImageUrl: snapshot.data,
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required bool isUpcoming,
    required bool isSedanHome,
    required bool isSedanAway,
    required bool isSedanMatch,
    required Color accent,
    required String? stadiumImageUrl,
  }) {
    void openDetail() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
        );

    // ── Mode RÉSULTATS : carte compacte ─────────────────────────────────────
    if (!isUpcoming) {
      final score1 = match.score1;
      final score2 = match.score2;
      final hasScore = score1 != null && score2 != null;

      // Résultat pour Sedan (si applicable)
      Color? resultColor;
      String? resultLabel;
      if (isSedanMatch && hasScore) {
        final sedanScore = isSedanHome ? score1 : score2;
        final oppScore = isSedanHome ? score2 : score1;
        if (sedanScore > oppScore) {
          resultColor = const Color(0xFF2E7D32);
          resultLabel = 'V';
        } else if (sedanScore == oppScore) {
          resultColor = const Color(0xFF8A7A00);
          resultLabel = 'N';
        } else {
          resultColor = kMatchesRed;
          resultLabel = 'D';
        }
      }

      final hasStadiumImage =
          stadiumImageUrl != null && stadiumImageUrl.isNotEmpty;

      return GestureDetector(
        onTap: isSedanMatch ? openDetail : null,
        child: Container(
          decoration: BoxDecoration(
            color: kMatchesCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kMatchesBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
            children: [
              // ── Header fin ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: kMatchesGreenDeep,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    Text(
                      shortDateLabel(match.date),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kMatchesGold.withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        competitionShortLabel(match.competition),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: kMatchesGold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (resultLabel != null)
                      Container(
                        width: 28,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: resultColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          resultLabel,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          DvcrShare.share(ShareHelper.matchText(match)),
                      child: Icon(Icons.ios_share_rounded,
                          size: 16,
                          color: Colors.white.withAlpha(160)),
                    ),
                  ],
                ),
              ),

              // ── Corps : logos + score ─────────────────────────────────
              Stack(
                children: [
                  if (hasStadiumImage)
                    Positioned.fill(
                      child: Image.network(
                        stadiumImageUrl,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, 0.6),
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  if (hasStadiumImage)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  children: [
                    // Équipe 1
                    Expanded(
                      child: Row(
                        children: [
                          _SmallLogo(
                            logo: match.logo1,
                            name: match.team1,
                            highlight: isSedanHome,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              match.team1,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSedanHome
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: kMatchesText,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Score
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        hasScore
                            ? '${match.score1} - ${match.score2}'
                            : '? - ?',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: kMatchesText,
                          height: 1,
                        ),
                      ),
                    ),

                    // Équipe 2
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              match.team2,
                              maxLines: 2,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSedanAway
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: kMatchesText,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _SmallLogo(
                            logo: match.logo2,
                            name: match.team2,
                            highlight: isSedanAway,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                ], // fin Stack corps
              ),

              // ── Actions (Sedan uniquement) ────────────────────────────
              if (isSedanMatch) ...[
                Divider(
                    height: 1,
                    color: kMatchesBorder,
                    indent: 14,
                    endIndent: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: openDetail,
                          child: Row(
                            children: [
                              Icon(Icons.bar_chart_rounded,
                                  size: 14, color: kMatchesGreen),
                              const SizedBox(width: 5),
                              Text(
                                'Stats & détail',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: kMatchesGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (match.replayVideoId != null)
                        GestureDetector(
                          onTap: () => _openReplay(context, match),
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 14, color: kMatchesGold),
                              const SizedBox(width: 5),
                              Text(
                                'Replay',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: kMatchesGold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isAdmin)
                        GestureDetector(
                          onTap: () => _editReplay(context, match),
                          child: Text(
                            '+ Ajouter replay',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kMatchesMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          ), // fin ClipRRect
        ),
      );
    }

    // ── Mode À VENIR : carte premium ───────────────────────────────────────
    final hasStadiumImage =
        stadiumImageUrl != null && stadiumImageUrl.isNotEmpty;
    final isLiveMatch = match.status == MatchStatus.live;

    return GestureDetector(
      onTap: openDetail,
      child: Container(
        decoration: BoxDecoration(
          color: kMatchesGreenDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLiveMatch
                ? kMatchesRed.withAlpha(180)
                : kMatchesGold.withAlpha(50),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ── Image stade en fond (zone body uniquement) ─────────────
              if (hasStadiumImage)
                Positioned.fill(
                  child: Image.network(
                    stadiumImageUrl,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, 0.6),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              // Overlay gradient sombre
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kMatchesGreenDeep.withAlpha(242),
                        kMatchesGreenDeep.withAlpha(200),
                        kMatchesGreenDeep.withAlpha(230),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Row(
                      children: [
                        // Live badge
                        if (isLiveMatch) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kMatchesRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '● LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Date
                        Text(
                          shortDateLabel(match.date),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withAlpha(180),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Compétition
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: kMatchesGold.withAlpha(45),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: kMatchesGold.withAlpha(80)),
                          ),
                          child: Text(
                            competitionShortLabel(match.competition),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: kMatchesGold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              DvcrShare.share(ShareHelper.matchText(match)),
                          child: Icon(
                            Icons.ios_share_rounded,
                            size: 15,
                            color: Colors.white.withAlpha(130),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Corps : logos + heure ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Équipe 1
                        Expanded(
                          child: _TeamColumnDark(
                            name: match.team1,
                            logo: match.logo1,
                            highlight: isSedanHome,
                            alignEnd: false,
                          ),
                        ),

                        // Centre : heure
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kMatchesGold,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  matchTimeLabel(match.date),
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: kMatchesGreenDeep,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "coup d'envoi",
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(130),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Équipe 2
                        Expanded(
                          child: _TeamColumnDark(
                            name: match.team2,
                            logo: match.logo2,
                            highlight: isSedanAway,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Prono + action ──────────────────────────────────────
                  if (PronoChampionshipRollout.isHubVisible) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      child: _UpcomingMatchPronoCta(
                        label: _pronoStatusLabel(match.date),
                        match: match,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Barre action bas
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Voir la fiche',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: kMatchesGold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _openReplay(BuildContext context, MatchModel match) {
    final youtubeId = match.replayVideoId;
    if (youtubeId == null || youtubeId.isEmpty) return;
    final video = VideoModel(
      id: match.id,
      title: '${match.team1} - ${match.team2}',
      youtubeId: youtubeId,
      duration: '',
      date: match.date,
      category: 'resume',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoWebScreen(video: video)),
    );
  }

  void _editReplay(BuildContext context, MatchModel match) {
    final controller = TextEditingController(text: match.replayVideoId ?? '');
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kMatchesCard,
          title: Text(
            'Lien replay',
            style: GoogleFonts.inter(
              color: kMatchesText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'URL ou ID YouTube'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: kMatchesMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                final raw = controller.text.trim();
                final id = YoutubeParser.extractId(raw);
                if (id == null) {
                  Navigator.pop(context);
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(match.id)
                    .update({'replayVideoId': id});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Replay enregistre')),
                  );
                }
              },
              child: Text(
                'Enregistrer',
                style: GoogleFonts.inter(
                  color: kMatchesGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color color;

  const _TopTag({
    required this.label,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final String? logo;
  final bool highlight;
  final bool alignEnd;

  const _TeamColumn({
    required this.name,
    required this.logo,
    required this.highlight,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? kMatchesGold : kMatchesBorder,
              width: highlight ? 2 : 1,
            ),
          ),
          child: logo != null && logo!.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    logo!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _FallbackBadge(name: name),
                  ),
                )
              : _FallbackBadge(name: name),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kMatchesText,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _TeamColumnDark extends StatelessWidget {
  final String name;
  final String? logo;
  final bool highlight;
  final bool alignEnd;

  const _TeamColumnDark({
    required this.name,
    required this.logo,
    required this.highlight,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? kMatchesGold : kMatchesBorder,
              width: highlight ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: logo != null && logo!.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(7),
                  child: Image.network(
                    logo!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _FallbackBadge(name: name),
                  ),
                )
              : _FallbackBadge(name: name),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: 90,
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? Colors.white : Colors.white.withAlpha(200),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallLogo extends StatelessWidget {
  final String? logo;
  final String name;
  final bool highlight;

  const _SmallLogo({
    required this.logo,
    required this.name,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? kMatchesGold : kMatchesBorder,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: logo != null && logo!.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.network(
                logo!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _FallbackBadge(name: name),
              ),
            )
          : _FallbackBadge(name: name),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  final String name;

  const _FallbackBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        teamInitials(name),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: kMatchesMuted,
        ),
      ),
    );
  }
}

// ── Accès prono sur match à venir (ouvre la feuille prono si la fenêtre est ouverte) ──
class _UpcomingMatchPronoCta extends StatelessWidget {
  final String label;
  final MatchModel match;

  const _UpcomingMatchPronoCta({required this.label, required this.match});

  @override
  Widget build(BuildContext context) {
    final canTap = _isPronoOpen(match.date);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (canTap) {
            openPronoForMatch(context, matchId: match.id, openSheet: true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Les pronos s’ouvrent 7 jours avant le coup d’envoi.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: canTap
                ? kMatchesGold.withAlpha(30)
                : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: canTap
                  ? kMatchesGold.withAlpha(100)
                  : Colors.white.withAlpha(30),
            ),
          ),
          child: Row(
            children: [
              Icon(
                canTap
                    ? Icons.sports_soccer_rounded
                    : Icons.lock_outline_rounded,
                size: 14,
                color:
                    canTap ? kMatchesGold : Colors.white.withAlpha(100),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  canTap ? label : 'Ouverture 7 j avant le match',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: canTap
                        ? Colors.white
                        : Colors.white.withAlpha(120),
                  ),
                ),
              ),
              if (canTap)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: kMatchesGold,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? Colors.white : kMatchesText,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: filled ? Colors.white : kMatchesText),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: filled ? kMatchesText : Colors.white,
                letterSpacing: 0.35,
              ),
            ),
            ...[
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: filled ? kMatchesGold : Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyMatchesState extends StatelessWidget {
  final MatchesViewMode mode;
  final DateTime focusMonth;
  final bool hadAnyBeforeMonth;
  final String? titleOverride;
  final String? subtitleOverride;

  const _EmptyMatchesState({
    required this.mode,
    required this.focusMonth,
    required this.hadAnyBeforeMonth,
    this.titleOverride,
    this.subtitleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat(
      'MMMM yyyy',
      'fr_FR',
    ).format(focusMonth);

    final title = titleOverride ??
        (hadAnyBeforeMonth
            ? 'Aucun match en $monthTitle'
            : (mode == MatchesViewMode.upcoming
                  ? 'Aucun rendez-vous ici'
                  : 'Aucun résultat pour ce filtre'));

    final subtitle = subtitleOverride ??
        (hadAnyBeforeMonth
            ? 'Change de mois avec les flèches sous les onglets, ou assouplis compétition / équipe.'
            : 'Essaie une autre compétition ou une autre équipe pour relancer la liste.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          color: kMatchesCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kMatchesBorder),
        ),
        child: Column(
          children: [
            Icon(
              mode == MatchesViewMode.upcoming
                  ? Icons.event_busy_rounded
                  : Icons.sports_score_rounded,
              color: kMatchesGold,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kMatchesText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kMatchesMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
