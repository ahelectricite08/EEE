import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/dvcr_share_service.dart';

import '../../models/match_model.dart';
import '../../models/video_model.dart';
import '../../services/match_service.dart';
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
    if (_favoriteTeam != null && _favoriteTeam!.isNotEmpty) {
      _selectedTeam = _favoriteTeam;
    }
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

    final previous = _favoriteTeam;
    setState(() {
      _favoriteTeam = next;
      if (_selectedTeam == null || _selectedTeam == previous) {
        _selectedTeam = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Résultats : requête par mois (sinon allResults() est limité à 100 docs → mois anciens vides).
    final stream = widget.mode == MatchesViewMode.upcoming
        ? MatchService.allUpcoming()
        : MatchService.forMonth(
            widget.focusMonth.year,
            widget.focusMonth.month,
          );

    final fallback = widget.mode == MatchesViewMode.upcoming
        ? MatchModel.mockAllUpcoming
        : MatchModel.mockResults;

    return StreamBuilder<SeasonLifecycleConfig>(
      stream: SeasonLifecycleService.stream(),
      builder: (context, lifeSnap) {
        final life =
            lifeSnap.data ?? SeasonLifecycleConfig.defaults;
        final between = life.betweenSeasons;

        return StreamBuilder<List<MatchModel>>(
          key: ValueKey<Object>(
            '${widget.mode.name}_${widget.focusMonth.year}_${widget.focusMonth.month}_$between',
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
            List<MatchModel> source =
                snapshot.hasData && snapshot.data!.isNotEmpty
                    ? snapshot.data!
                    : (noMockBetween ? <MatchModel>[] : fallback);
        if (widget.mode == MatchesViewMode.results) {
          source = source
              .where((m) => m.status == MatchStatus.finished)
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
                    (match) => Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _MatchesEventCard(
                        match: match,
                        mode: widget.mode,
                        isAdmin: _isAdmin,
                      ),
                    ),
                  ),
                ];
              }),
          ],
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
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFCFFFE),
            kMatchesIntroSurface,
            Color(0xFFF0F7F4),
          ],
          stops: [0.0, 0.56, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kMatchesIntroBorder),
        boxShadow: [
          BoxShadow(
            color: kMatchesGreen.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: kMatchesGreen,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kMatchesGold.withAlpha(36),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: kMatchesGold.withAlpha(110),
                          ),
                        ),
                        child: Text(
                          isUpcoming
                              ? 'CALENDRIER MATCH'
                              : 'ESPACE RESULTATS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: kMatchesGreenDeep,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isUpcoming
                            ? 'Tous les rendez-vous a ne pas manquer.'
                            : 'Tous les scores des matchs déjà joués.',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kMatchesText,
                          height: 1,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isUpcoming
                            ? 'Filtre par competition ou equipe et retrouve chaque affiche du club.'
                            : 'Parcours les resultats, ouvre les stats et retrouve les replays en un geste.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: kMatchesMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: kMatchesCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kMatchesText,
                      ),
                    ),
                    const Spacer(),
                    if (selected != null)
                      TextButton(
                        onPressed: () {
                          onSelected(null);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Reinitialiser',
                          style: GoogleFonts.inter(
                            color: kMatchesGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((option) {
                    final isSelected = selected == option;
                    return ListTile(
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                      title: Text(
                        option,
                        style: GoogleFonts.inter(
                          color: isSelected ? kMatchesGreen : kMatchesText,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: kMatchesGreen,
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ],
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
    final hasStadiumImage =
        stadiumImageUrl != null && stadiumImageUrl.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: (isUpcoming || isSedanMatch)
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchDetailScreen(match: match),
                ),
              )
            : null,
        child: Ink(
          decoration: BoxDecoration(
            color: kMatchesCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kMatchesBorder),
            boxShadow: const [
              BoxShadow(
                color: kMatchesShadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  gradient: match.status == MatchStatus.live
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            kMatchesRed,
                            Color(0xFF8E2236),
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            kMatchesCardHeaderStart,
                            kMatchesCardHeaderEnd,
                          ],
                        ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(23),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 32,
                      ),
                      tooltip: 'Partager ce match',
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () =>
                          DvcrShare.share(ShareHelper.matchText(match)),
                    ),
                    Expanded(
                      child: Text(
                        shortDateLabel(match.date),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _TopTag(
                      label: competitionShortLabel(match.competition),
                      background: match.status == MatchStatus.live
                          ? Colors.white.withAlpha(26)
                          : kMatchesGold.withAlpha(52),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    _TopTag(
                      label: isUpcoming
                          ? matchTimeLabel(match.date)
                          : 'TERMINE',
                      background: match.status == MatchStatus.live
                          ? Colors.white
                          : kMatchesGold.withAlpha(236),
                      color: match.status == MatchStatus.live
                          ? accent
                          : kMatchesText,
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  if (hasStadiumImage)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(23),
                        ),
                        child: Image.network(
                          stadiumImageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (hasStadiumImage)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(23),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withAlpha(150),
                              Colors.white.withAlpha(214),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _TeamColumn(
                                name: match.team1,
                                logo: match.logo1,
                                highlight: isSedanHome,
                                alignEnd: false,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    isUpcoming
                                        ? matchTimeLabel(match.date)
                                        : (match.score1 != null
                                              ? '${match.score1} - ${match.score2}'
                                              : '? - ?'),
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: kMatchesText,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isUpcoming
                                        ? 'Coup d\'envoi'
                                        : (match.score1 != null
                                              ? 'Score final'
                                              : 'Résultat prochainement'),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: kMatchesMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _TeamColumn(
                                name: match.team2,
                                logo: match.logo2,
                                highlight: isSedanAway,
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isUpcoming)
                          PronoChampionshipRollout.isHubVisible
                              ? _UpcomingMatchPronoCta(
                                  label: _pronoStatusLabel(match.date),
                                  match: match,
                                )
                              : const SizedBox.shrink()
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(190),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kMatchesBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isSedanMatch
                                        ? 'Detail du match, stats et replay disponibles ici'
                                        : 'Score final uniquement pour cette affiche',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: kMatchesText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isUpcoming || isSedanMatch)
                              SizedBox(
                                width: 172,
                                child: _ActionButton(
                                  label: isUpcoming
                                      ? 'Voir la fiche'
                                      : 'Voir les stats',
                                  filled: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MatchDetailScreen(match: match),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (!isUpcoming &&
                                isSedanMatch &&
                                match.replayVideoId != null)
                              SizedBox(
                                width: 172,
                                child: _ActionButton(
                                  label: 'Voir le replay',
                                  filled: true,
                                  onTap: () => _openReplay(context, match),
                                ),
                              ),
                            if (!isUpcoming &&
                                isSedanMatch &&
                                isAdmin &&
                                match.replayVideoId == null)
                              _ActionButton(
                                label: 'Ajouter replay',
                                onTap: () => _editReplay(context, match),
                              ),
                          ],
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(190),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMatchesBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      canTap ? Icons.sports_soccer_rounded : Icons.schedule_rounded,
                      size: 16,
                      color: canTap ? kMatchesText : kMatchesMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kMatchesText,
                        ),
                      ),
                    ),
                    if (canTap)
                      Icon(Icons.chevron_right_rounded, size: 18, color: kMatchesMuted),
                  ],
                ),
              ),
              if (!canTap)
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(160),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 11,
                              color: Color(0xFF888888),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Ouverture 7 j avant',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
