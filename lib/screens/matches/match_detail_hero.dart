import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/match_model.dart';
import '../../services/app_settings_service.dart';
import '../../services/live_banner_format.dart';
import '../../services/live_match_phase.dart';
import '../../services/live_radio_service.dart';
import '../../widgets/hub_hero_photo.dart';
import '../../widgets/dvcr_network_image.dart';
import '../../utils/remote_image_url.dart';
import 'match_detail_theme.dart';
import 'match_detail_type.dart';
import 'match_detail_ui.dart';
import 'matches_helpers.dart';

/// Photo hero de la fiche. Pas de [FlexibleSpaceBar] : il tue l’opacité
/// au repli et laisse un rectangle vert. Ici la photo reste peinte.
class MatchDetailHeroFlexibleSpace extends StatelessWidget {
  final MatchModel match;
  final double lockupBottom;

  const MatchDetailHeroFlexibleSpace({
    super.key,
    required this.match,
    this.lockupBottom = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final maxExtent = settings?.maxExtent ?? constraints.maxHeight;
        final minExtent = settings?.minExtent ?? constraints.maxHeight;
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final delta = maxExtent - minExtent;
        final t = delta <= 0
            ? 0.0
            : (1 - (current - minExtent) / delta).clamp(0.0, 1.0);

        final alignment = Alignment.lerp(
          const Alignment(0, 0.45),
          const Alignment(0, -0.35),
          t,
        )!;

        final veilTop = 0.28 + 0.30 * t;
        final veilMid = 0.10 + 0.40 * t;
        final veilLow = 0.58 + 0.20 * t;
        const veilBottom = 0.86;
        final lockupOpacity = (1 - t * 1.55).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color(0xFF151515)),
            ),
            Positioned.fill(
              child: _MatchStadiumPhoto(match: match, alignment: alignment),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: veilTop),
                      Colors.black.withValues(alpha: veilMid),
                      Colors.black.withValues(alpha: veilLow),
                      Colors.black.withValues(alpha: veilBottom),
                    ],
                    stops: const [0.0, 0.32, 0.76, 1.0],
                  ),
                ),
              ),
            ),
            if (lockupOpacity > 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: lockupBottom,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: _MatchHeroLockup(match: match),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MatchStadiumPhoto extends StatelessWidget {
  final MatchModel match;
  final Alignment alignment;

  const _MatchStadiumPhoto({
    required this.match,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final cacheW = matchDetailHeroCacheWidth(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .where('name', isEqualTo: match.team1)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final url = snap.hasData && snap.data!.docs.isNotEmpty
            ? (snap.data!.docs.first.data()
                    as Map<String, dynamic>)['stadiumImageUrl']
                ?.toString()
                .trim()
            : null;
        final effectiveUrl =
            (url == null || url.isEmpty) ? match.stadiumImageUrl : url;
        if (effectiveUrl != null &&
            effectiveUrl.isNotEmpty &&
            !shouldSkipNetworkImageUrl(effectiveUrl)) {
          return DvcrNetworkImage(
            effectiveUrl,
            key: ValueKey(effectiveUrl),
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: false,
            cacheWidth: cacheW,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => HubHeroPhoto(
              slot: HubHeroSlot.matchDetail,
              alignment: alignment,
              fallbackAsset:
                  'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
              cacheWidth: cacheW,
              filterQuality: FilterQuality.low,
            ),
          );
        }
        return HubHeroPhoto(
          slot: HubHeroSlot.matchDetail,
          alignment: alignment,
          fallbackAsset: 'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
          cacheWidth: cacheW,
          filterQuality: FilterQuality.low,
        );
      },
    );
  }
}

class _MatchHeroLockup extends StatelessWidget {
  final MatchModel match;

  const _MatchHeroLockup({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live;
    final isUpcoming = match.status == MatchStatus.upcoming && !match.earlyPublish;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('live').doc('current').snapshots(),
      builder: (context, snap) {
        final liveData = snap.data?.data();
        final liveMatchId = (liveData?['matchId'] as String? ?? '').trim();
        final linked = liveMatchId.isNotEmpty &&
            liveMatchId == match.id.trim() &&
            snap.data?.exists == true;
        final showAsLive = isLive || linked;

        int s1 = match.score1 ?? 0;
        int s2 = match.score2 ?? 0;
        String minute = '';
        var liveEnded = false;
        var liveHalftime = false;
        if (linked && liveData != null) {
          s1 = (liveData['scoreHome'] as num? ?? s1).toInt();
          s2 = (liveData['scoreAway'] as num? ?? s2).toInt();
          final phase = LiveMatchPhase((liveData['lastEvent'] ?? '').toString());
          liveEnded = phase.isMatchEnded;
          liveHalftime = phase.isHalftime || phase.isExtraHalftime;
          minute = LiveBannerFormat.minuteLabelFromMap(liveData);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _HeroClub(
                    name: match.team1,
                    logo: match.logo1,
                    alignEnd: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: isUpcoming && !linked
                      ? _HeroKickoff(date: match.date)
                      : _HeroScore(
                          s1: s1,
                          s2: s2,
                          isLive: showAsLive,
                          minute: minute,
                          finished: match.status == MatchStatus.finished,
                          liveEnded: liveEnded,
                          liveHalftime: liveHalftime,
                        ),
                ),
                Expanded(
                  child: _HeroClub(
                    name: match.team2,
                    logo: match.logo2,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            if (linked && liveData != null && liveData['radioLive'] == true) ...[
              const SizedBox(height: 12),
              const _HeroRadioButton(),
            ],
            if (!showAsLive) ...[
              const SizedBox(height: 10),
              Text(
                longDateLabel(match.date),
                style: MatchDetailType.meta.copyWith(
                  color: MatchDetailTheme.heroTextMuted,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HeroClub extends StatelessWidget {
  final String name;
  final String? logo;
  final bool alignEnd;

  const _HeroClub({
    required this.name,
    this.logo,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final sedan = isSedanTeam(name);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: MatchDetailCrest(
            url: logo,
            teamName: name,
            size: MatchDetailTheme.crestHero,
            onPhoto: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name.toUpperCase(),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MatchDetailType.clubName.copyWith(
            color: sedan ? Colors.white : Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ],
    );
  }
}

class _HeroScore extends StatelessWidget {
  final int s1;
  final int s2;
  final bool isLive;
  final String minute;
  final bool finished;
  final bool liveEnded;
  final bool liveHalftime;

  const _HeroScore({
    required this.s1,
    required this.s2,
    required this.isLive,
    required this.minute,
    required this.finished,
    this.liveEnded = false,
    this.liveHalftime = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$s1  –  $s2', style: MatchDetailType.score),
        const SizedBox(height: 8),
        if (isLive && (liveEnded || liveHalftime) && minute.isNotEmpty)
          MatchDetailStamp(
            label: minute,
            live: liveEnded,
            background: liveHalftime ? const Color(0xFFFFE8D0) : null,
            foreground: liveHalftime ? const Color(0xFFB45309) : null,
          )
        else if (isLive)
          MatchDetailStamp(
            label: minute.isNotEmpty && minute.endsWith("'")
                ? 'EN DIRECT · $minute'
                : 'EN DIRECT',
            live: true,
          )
        else if (finished)
          const MatchDetailStamp(label: 'TERMINÉ', ink: true)
        else
          const MatchDetailStamp(label: 'SCORE'),
      ],
    );
  }
}

class _HeroKickoff extends StatelessWidget {
  final DateTime date;

  const _HeroKickoff({required this.date});

  @override
  Widget build(BuildContext context) {
    final diff = date.difference(DateTime.now());
    final days = diff.inDays;
    final countdown = diff.isNegative
        ? ''
        : days == 0
            ? '${diff.inHours}h'
            : '${days}j';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}',
          style: MatchDetailType.kickoff,
        ),
        if (countdown.isNotEmpty) ...[
          const SizedBox(height: 8),
          MatchDetailStamp(label: 'DANS $countdown', ink: true),
        ],
      ],
    );
  }
}

class _HeroRadioButton extends StatelessWidget {
  const _HeroRadioButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LiveRadioService.instance,
      builder: (context, _) {
        final radio = LiveRadioService.instance;
        final listening = radio.isListening;
        final connecting = radio.isConnecting;
        return Center(
          child: GestureDetector(
            onTap: connecting
                ? null
                : () async {
                    try {
                      if (listening) {
                        await radio.stop();
                      } else {
                        await radio.startListening();
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            LiveRadioService.userFacingMessage(e),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: MatchDetailTheme.red,
                        ),
                      );
                    }
                  },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: listening
                    ? MatchDetailTheme.red
                    : Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: listening
                      ? MatchDetailTheme.red
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      connecting
                          ? Icons.hourglass_top_rounded
                          : listening
                              ? Icons.stop_rounded
                              : Icons.headphones_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connecting
                          ? 'CONNEXION…'
                          : listening
                              ? 'EN DIRECT — AUDIO'
                              : 'ÉCOUTER EN AUDIO',
                      style: MatchDetailType.kicker.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
