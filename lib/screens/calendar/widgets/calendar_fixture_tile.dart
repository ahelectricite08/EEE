import 'package:flutter/material.dart';

import '../../../models/match_model.dart';
import '../../../services/dvcr_share_service.dart';
import '../../../utils/match_competition.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/dvcr_network_image.dart';
import '../../../widgets/dvcr_share_favorite_controls.dart';
import '../../match_detail_screen.dart';
import '../../matches/matches_helpers.dart';
import '../calendar_helpers.dart';
import '../theme/calendar_theme.dart';
import '../theme/calendar_type.dart';

/// Carte-programme CSSA — contenant ivoire + écussons + bandeau stade si data.
class CalendarFixtureTile extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  final bool featured;
  final bool compact;
  final Widget? footer;
  final bool showShare;
  final bool showFavorite;

  const CalendarFixtureTile({
    super.key,
    required this.match,
    this.onTap,
    this.featured = false,
    this.compact = false,
    this.footer,
    this.showShare = true,
    this.showFavorite = true,
  });

  static VoidCallback openDetail(BuildContext context, MatchModel match) {
    return () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final embedded = embeddedStadiumUrl(match);
    if (embedded != null) {
      return _FixturePaper(
        match: match,
        stadiumImageUrl: embedded,
        onTap: onTap,
        featured: featured,
        compact: compact,
        footer: footer,
        showShare: showShare,
        showFavorite: showFavorite,
      );
    }

    return StreamBuilder<String?>(
      stream: watchHomeStadiumImage(match.team1),
      builder: (context, snapshot) {
        return _FixturePaper(
          match: match,
          stadiumImageUrl: snapshot.data,
          onTap: onTap,
          featured: featured,
          compact: compact,
          footer: footer,
          showShare: showShare,
          showFavorite: showFavorite,
        );
      },
    );
  }
}

class _FixturePaper extends StatelessWidget {
  final MatchModel match;
  final String? stadiumImageUrl;
  final VoidCallback? onTap;
  final bool featured;
  final bool compact;
  final Widget? footer;
  final bool showShare;
  final bool showFavorite;

  const _FixturePaper({
    required this.match,
    required this.stadiumImageUrl,
    required this.onTap,
    required this.featured,
    required this.compact,
    required this.footer,
    required this.showShare,
    required this.showFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = match.status == MatchStatus.finished;
    final isLive = match.status == MatchStatus.live;
    final sedanHome = isSedanTeam(match.team1);
    final sedanAway = isSedanTeam(match.team2);
    final sedanMatch = sedanHome || sedanAway;
    final venueStamp = sedanVenueStamp(match);
    final hasPhoto =
        stadiumImageUrl != null && stadiumImageUrl!.trim().isNotEmpty;
    final otherCrest = compact
        ? CalendarTheme.crestCompact
        : CalendarTheme.crestRegular;
    final sedanCrest = compact
        ? CalendarTheme.crestRegular
        : (featured
            ? CalendarTheme.crestFeatured + 4
            : CalendarTheme.crestFeatured);
    final crestSize = sedanMatch ? sedanCrest : otherCrest;

    final lisere = isLive
        ? CalendarTheme.red
        : sedanMatch
            ? CalendarTheme.green
            : CalendarTheme.hairline;

    final edge = isLive
        ? CalendarTheme.red.withValues(alpha: 0.45)
        : sedanMatch
            ? CalendarTheme.ink.withValues(alpha: 0.18)
            : CalendarTheme.hairline;

    final fanResult = sedanFanResultStamp(match);
    final fanResultColor = fanResult == 'Victoire'
        ? CalendarTheme.accent
        : fanResult == 'Nul'
            ? CalendarTheme.textMuted
            : fanResult == 'Défaite'
                ? CalendarTheme.red
                : CalendarTheme.text;

    final timeOrScore = isFinished
        ? (match.score1 != null ? '${match.score1}–${match.score2}' : '?–?')
        : timeLabel(match.date);

    final venue = matchVenueLine(match);
    final photoHeight = sedanMatch
        ? (compact ? 80.0 : CalendarTheme.photoBand)
        : CalendarTheme.photoBandCompact;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CalendarTheme.gutter,
        0,
        CalendarTheme.gutter,
        CalendarTheme.fixtureGap,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CalendarTheme.paperRadius),
          splashColor: CalendarTheme.accent.withValues(alpha: 0.06),
          highlightColor: CalendarTheme.accent.withValues(alpha: 0.04),
          child: Ink(
            decoration: CalendarTheme.fixturePaper(
              edge: edge,
              sedan: sedanMatch,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CalendarTheme.paperRadius),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasPhoto)
                        _StadiumBand(
                          url: stadiumImageUrl!,
                          height: photoHeight,
                          sedanMatch: sedanMatch,
                          venueStamp: venueStamp,
                        ),
                      if (hasPhoto && sedanMatch)
                        const ColoredBox(
                          color: CalendarTheme.green,
                          child: SizedBox(height: 2),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 16,
                          hasPhoto ? 10 : (compact ? 10 : 14),
                          compact ? 12 : 16,
                          compact ? 8 : 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (sedanMatch && !hasPhoto) ...[
                              _CssaMatchKicker(venueStamp: venueStamp),
                              const SizedBox(height: 10),
                            ],
                            _SheetHeader(
                              match: match,
                              isLive: isLive,
                              compact: compact,
                              resultStamp: sedanMatch ? fanResult : null,
                              resultStampColor: fanResultColor,
                            ),
                            if (sedanMatch && venue != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CalendarType.meta.copyWith(
                                  color: CalendarTheme.text,
                                ),
                              ),
                            ],
                            SizedBox(height: compact ? 8 : 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _CrestDisc(
                                      url: match.logo1,
                                      teamName: match.team1,
                                      size: crestSize,
                                      highlight: sedanHome,
                                      showRule: sedanHome,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: _ProgramCenter(
                                    timeOrScore: timeOrScore,
                                    isFinished: isFinished,
                                    isLive: isLive,
                                    compact: compact,
                                    sedanMatch: sedanMatch,
                                    resultStamp: fanResult,
                                    resultStampColor: fanResultColor,
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _CrestDisc(
                                      url: match.logo2,
                                      teamName: match.team2,
                                      size: crestSize,
                                      highlight: sedanAway,
                                      showRule: sedanAway,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _ClubName(
                                    name: match.team1,
                                    highlight: sedanHome,
                                    size: crestSize,
                                    alignEnd: false,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: SizedBox(width: 104),
                                ),
                                Expanded(
                                  child: _ClubName(
                                    name: match.team2,
                                    highlight: sedanAway,
                                    size: crestSize,
                                    alignEnd: true,
                                  ),
                                ),
                              ],
                            ),
                            if (!sedanMatch && venue != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CalendarType.meta,
                              ),
                            ],
                            if (showShare || showFavorite) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Spacer(),
                                  if (showShare)
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
                                        size: 18,
                                        color: CalendarTheme.textSoft,
                                      ),
                                      onPressed: () => DvcrShare.share(
                                        ShareHelper.matchText(match),
                                        context: context,
                                      ),
                                    ),
                                  if (showFavorite)
                                    DvcrMatchShareFavoriteRow(
                                      match: match,
                                      mutedIconColor: CalendarTheme.textSoft,
                                      activeFavoriteColor: CalendarTheme.accent,
                                      iconSize: 18,
                                      showShare: false,
                                    ),
                                ],
                              ),
                            ],
                            if (footer != null) ...[
                              const SizedBox(height: 4),
                              footer!,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: lisere,
                      child: SizedBox(width: sedanMatch ? 3 : 2),
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

class _StadiumBand extends StatelessWidget {
  final String url;
  final double height;
  final bool sedanMatch;
  final String? venueStamp;

  const _StadiumBand({
    required this.url,
    required this.height,
    required this.sedanMatch,
    required this.venueStamp,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DvcrNetworkImage(
            url,
            fit: BoxFit.cover,
            alignment: sedanMatch
                ? const Alignment(0, 0.18)
                : const Alignment(0, 0.45),
            cacheWidth: dvcrStadiumCacheWidth(context),
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(sedanMatch ? 0x730A1C18 : 0x330A1C18),
                  const Color(0x140A1C18),
                  const Color(0xF2F3F5F2),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          if (sedanMatch)
            Positioned(
              top: 12,
              left: 14,
              child: Row(
                children: [
                  CalendarTheme.clubRule(width: 14, height: 2),
                  const SizedBox(width: 8),
                  Text(
                    'CSSA',
                    style: CalendarType.kicker.copyWith(
                      color: CalendarTheme.heroText,
                      letterSpacing: 1.8,
                    ),
                  ),
                  if (venueStamp != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '·  $venueStamp',
                      style: CalendarType.kicker.copyWith(
                        color: CalendarTheme.heroText,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final MatchModel match;
  final bool isLive;
  final bool compact;
  final String? resultStamp;
  final Color? resultStampColor;

  const _SheetHeader({
    required this.match,
    required this.isLive,
    required this.compact,
    required this.resultStamp,
    required this.resultStampColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            MatchCompetition.displayLabel(match.competition).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CalendarType.kicker.copyWith(
              color: CalendarTheme.ink,
              letterSpacing: compact ? 1.2 : 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isLive)
          const _PaperStamp(label: 'DIRECT', live: true)
        else if (resultStamp != null)
          _PaperStamp(
            label: resultStamp!.toUpperCase(),
            tone: resultStamp == 'Victoire'
                ? _StampTone.win
                : resultStamp == 'Défaite'
                    ? _StampTone.loss
                    : _StampTone.draw,
          )
        else if (match.status == MatchStatus.finished)
          const _PaperStamp(label: 'TERMINÉ')
        else
          const _PaperStamp(label: 'À VENIR', ink: true),
      ],
    );
  }
}

class _CssaMatchKicker extends StatelessWidget {
  final String? venueStamp;

  const _CssaMatchKicker({required this.venueStamp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CalendarTheme.clubRule(width: 16, height: 2),
        const SizedBox(width: 8),
        Text(
          'CSSA',
          style: CalendarType.kicker.copyWith(
            color: CalendarTheme.green,
            letterSpacing: 1.6,
          ),
        ),
        if (venueStamp != null) ...[
          Text(
            '  ·  ',
            style: CalendarType.kicker.copyWith(color: CalendarTheme.textSoft),
          ),
          Text(
            venueStamp!,
            style: CalendarType.kicker.copyWith(
              color: CalendarTheme.ink,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgramCenter extends StatelessWidget {
  final String timeOrScore;
  final bool isFinished;
  final bool isLive;
  final bool compact;
  final bool sedanMatch;
  final String? resultStamp;
  final Color? resultStampColor;

  const _ProgramCenter({
    required this.timeOrScore,
    required this.isFinished,
    required this.isLive,
    required this.compact,
    required this.sedanMatch,
    required this.resultStamp,
    required this.resultStampColor,
  });

  @override
  Widget build(BuildContext context) {
    final underScore = resultStamp != null
        ? resultStamp!
        : isFinished
            ? 'Score'
            : isLive
                ? 'En direct'
                : 'Coup d’envoi';
    final underColor = resultStamp != null
        ? (resultStampColor ?? CalendarTheme.text)
        : isLive
            ? CalendarTheme.red
            : CalendarTheme.textSoft;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeOrScore,
              maxLines: 1,
              style: isFinished
                  ? CalendarType.scoreCompact.copyWith(
                      fontSize: compact ? 24 : 34,
                      color: CalendarTheme.text,
                    )
                  : CalendarType.scoreCompact.copyWith(
                      fontSize: compact ? 20 : 28,
                      color: isLive ? CalendarTheme.red : CalendarTheme.ink,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          CalendarTheme.clubRule(
            width: sedanMatch ? 28 : 14,
            height: 1,
            color: sedanMatch ? CalendarTheme.green : CalendarTheme.hairline,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              underScore,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: resultStamp != null
                  ? CalendarType.label.copyWith(
                      color: underColor,
                      fontWeight: FontWeight.w800,
                    )
                  : CalendarType.kicker.copyWith(
                      color: underColor,
                      letterSpacing: 1.0,
                      fontSize: 8,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubName extends StatelessWidget {
  final String name;
  final bool highlight;
  final double size;
  final bool alignEnd;

  const _ClubName({
    required this.name,
    required this.highlight,
    required this.size,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      name.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: CalendarType.fixture.copyWith(
        fontSize: size >= 44 ? 17 : 13,
        color: highlight ? CalendarTheme.green : CalendarTheme.textMuted,
      ),
    );
  }
}

class _CrestDisc extends StatelessWidget {
  static const double _ruleGap = 4;
  static const double _ruleHeight = 2;

  final String? url;
  final String teamName;
  final double size;
  final bool highlight;
  final bool showRule;

  const _CrestDisc({
    required this.url,
    required this.teamName,
    required this.size,
    required this.highlight,
    this.showRule = false,
  });

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    return SizedBox(
      width: size,
      height: size + _ruleGap + _ruleHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: CalendarTheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: highlight
                    ? CalendarTheme.ink.withValues(alpha: 0.28)
                    : CalendarTheme.hairline,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: u != null && u.isNotEmpty
                  ? DvcrNetworkImage(
                      u,
                      fit: BoxFit.contain,
                      cacheWidth: dvcrCrestCacheWidth(context, size),
                      errorBuilder: (_, __, ___) =>
                          _CrestFallback(teamName: teamName),
                    )
                  : _CrestFallback(teamName: teamName),
            ),
          ),
          const SizedBox(height: _ruleGap),
          CalendarTheme.clubRule(
            width: size * 0.5,
            height: _ruleHeight,
            color: showRule ? CalendarTheme.green : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _CrestFallback extends StatelessWidget {
  final String teamName;

  const _CrestFallback({required this.teamName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        teamInitials(teamName),
        style: CalendarType.kicker.copyWith(color: CalendarTheme.textMuted),
      ),
    );
  }
}

enum _StampTone { win, draw, loss }

class _PaperStamp extends StatelessWidget {
  final String label;
  final bool ink;
  final bool live;
  final _StampTone? tone;

  const _PaperStamp({
    required this.label,
    this.ink = false,
    this.live = false,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (live) {
      bg = CalendarTheme.red;
      fg = CalendarTheme.onInk;
    } else if (tone == _StampTone.win) {
      bg = CalendarTheme.green;
      fg = CalendarTheme.onInk;
    } else if (tone == _StampTone.loss) {
      bg = CalendarTheme.red.withValues(alpha: 0.12);
      fg = CalendarTheme.red;
    } else if (tone == _StampTone.draw) {
      bg = CalendarTheme.surfaceMuted;
      fg = CalendarTheme.ink;
    } else if (ink) {
      bg = CalendarTheme.ink;
      fg = CalendarTheme.onInk;
    } else {
      bg = CalendarTheme.surfaceMuted;
      fg = CalendarTheme.textSoft;
    }
    return ColoredBox(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: CalendarType.kicker.copyWith(
            letterSpacing: 1.1,
            color: fg,
          ),
        ),
      ),
    );
  }
}
