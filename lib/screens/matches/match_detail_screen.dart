import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/match_model.dart';
import '../../models/match_stats_schema.dart';
import '../../models/match_lineup.dart';
import '../../models/video_model.dart';
import '../../services/favorites_service.dart';
import '../../services/notification_service.dart';
import '../../utils/open_prono_for_match.dart';
import '../../navigation/prono_championship_rollout.dart';
import '../../services/feature_flags_service.dart';
import '../../services/match_stats_repository.dart';
import '../video_web_screen.dart';
import '../../widgets/match_lineups_detail_card.dart';
import '../../widgets/square_partner_logo.dart';
import '../../widgets/match_rating_summary.dart';
import '../../widgets/match_coach_audio_card.dart';
import '../../widgets/match_event_audio_play_button.dart';
import '../../widgets/match_event_video_play_button.dart';
import '../../widgets/match_highlight_resume_sheet.dart';
import '../../widgets/best_goal_vote_section.dart';
import '../../widgets/lineup_prediction_game.dart';
import '../../widgets/lineup_xi_official_note.dart';
import '../../models/lineup_xi_verdict.dart';
import '../../services/match_commentary_service.dart';
import '../../services/match_highlight_service.dart';
import '../../services/live_banner_format.dart';
import '../../services/live_match_phase.dart';
import '../../services/live_radio_service.dart';
import '../../services/lineup_prediction_service.dart';
import '../../services/sedan_squad_service.dart';
import '../../models/sedan_squad.dart';
import '../../utils/match_device_calendar.dart';
import '../../utils/stadium_maps_launcher.dart';
import 'match_detail_hero.dart';
import 'match_detail_palette.dart';
import 'match_detail_theme.dart';
import 'match_detail_type.dart';
import 'match_detail_ui.dart';
import 'match_souvenir_screen.dart';
import 'match_kickoff_weather_line.dart';
import 'match_tv_block.dart';
import 'match_weather_poll_block.dart';
import '../../widgets/dugauguez_place_card.dart';
import 'matches_helpers.dart';

class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;
  /// Index de l'onglet à afficher à l'ouverture (0 = Résumé, 1 = Composition, 2 = Prochain).
  final int initialTab;
  const MatchDetailScreen({
    super.key,
    required this.match,
    this.initialTab = 0,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<MatchReminderMode?> _pickReminderMode() async {
    final prefs = await SharedPreferences.getInstance();
    var selected = MatchReminderMode.fromKey(
      prefs.getString('notif_match_remind_mode'),
    );
    if (!mounted) return null;

    final result = await showModalBottomSheet<MatchReminderMode>(
      useRootNavigator: true,
      context: context,
      backgroundColor: MatchDetailTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHOISIR UN RAPPEL', style: MatchDetailType.title),
              const SizedBox(height: 8),
              Text(
                'Notif sur ton téléphone. Le coup d’envoi part déjà tout seul.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MatchDetailPalette.grey,
                ),
              ),
              const SizedBox(height: 14),
              ...MatchReminderMode.values.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setModalState(() => selected = mode),
                    child: DecoratedBox(
                      decoration: MatchDetailTheme.paper(
                        edge: selected == mode
                            ? MatchDetailTheme.green
                            : MatchDetailTheme.hairline,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              selected == mode
                                  ? Icons.check_circle_rounded
                                  : Icons.notifications_active_outlined,
                              color: selected == mode
                                  ? MatchDetailTheme.green
                                  : MatchDetailTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(mode.label, style: MatchDetailType.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              MatchDetailPaperButton(
                label: 'Enregistrer',
                ink: true,
                onTap: () => Navigator.pop(ctx, selected),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      await prefs.setString('notif_match_remind_mode', result.key);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;

    final topPad = MediaQuery.paddingOf(context).top;
    const toolbarH = 48.0;
    const bodyH = 228.0;
    const stripeH = MatchDetailTheme.stripeHeight;

    return Scaffold(
      backgroundColor: MatchDetailTheme.scaffold,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            stretch: false,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: toolbarH,
            expandedHeight: topPad + toolbarH + bodyH + stripeH,
            clipBehavior: Clip.hardEdge,
            titleSpacing: 0,
            centerTitle: false,
            title: MatchDetailPinnedToolbar(
              nameplate: m.competition.trim().isEmpty ? 'MATCH' : m.competition,
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              ListenableBuilder(
                listenable: FeatureFlagsService.notifier,
                builder: (context, _) {
                  if (!PronoChampionshipRollout.isHubVisible ||
                      m.status != MatchStatus.upcoming) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(
                      Icons.sports_soccer_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Pronostiquer',
                    onPressed: () {
                      if (isMatchPronoWindowOpen(m.date)) {
                        openPronoForMatch(
                          context,
                          matchId: m.id,
                          openSheet: true,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Les pronos s’ouvrent 7 jours avant le coup d’envoi.',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                tooltip: 'Partager',
                onPressed: () => showMatchShareActions(context, m),
              ),
              StreamBuilder<bool>(
                stream: FavoritesService.watchIsFavorite(
                  FavoriteType.match,
                  m.id,
                ),
                builder: (context, snap) {
                  final isFav = snap.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav ? Colors.white : Colors.white70,
                      size: 20,
                    ),
                    onPressed: () async {
                      final wasFav = snap.data ?? false;
                      if (!wasFav) {
                        final mode = await _pickReminderMode();
                        if (mode == null) return;
                        await FavoritesService.toggle(
                          type: FavoriteType.match,
                          itemId: m.id,
                          title: '${m.team1} vs ${m.team2}',
                          subtitle: m.competition,
                          routeHint: 'match',
                          extra: {
                            'team1': m.team1,
                            'team2': m.team2,
                            'date': m.date.toIso8601String(),
                            'reminderMode': mode.key,
                          },
                        );
                        await NotificationService.scheduleMatchReminder(
                          matchId: m.id,
                          team1: m.team1,
                          team2: m.team2,
                          matchDate: m.date,
                          mode: mode,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Rappel programme ${mode.label.toLowerCase()}.',
                            ),
                          ),
                        );
                      } else {
                        await FavoritesService.toggle(
                          type: FavoriteType.match,
                          itemId: m.id,
                          title: '${m.team1} vs ${m.team2}',
                          subtitle: m.competition,
                          routeHint: 'match',
                        );
                        await NotificationService.cancelMatchReminder(m.id);
                      }
                    },
                  );
                },
              ),
            ],
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                MatchDetailHeroFlexibleSpace(match: m),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: stripeH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: MatchDetailTheme.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            StreamBuilder<FavoriteEntry?>(
              stream: FavoritesService.watchEntry(FavoriteType.match, m.id),
              builder: (context, snap) {
                final favorite = snap.data;
                if (favorite == null) return const SizedBox.shrink();
                final reminderMode = MatchReminderMode.fromKey(
                  favorite.data['reminderMode'] as String?,
                );
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: MatchDetailTheme.paper(
                    sedan: isSedanMatch(m),
                    edge: MatchDetailTheme.green.withValues(alpha: 0.35),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: MatchDetailTheme.green,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rappel actif pour ce match',
                              style: MatchDetailType.label,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ce favori declenchera une notification ${reminderMode.label.toLowerCase()}.',
                              style: MatchDetailType.meta,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const MatchFicheSouvenirPartnerStrip(),
            // CTA souvenir : visible quel que soit l’onglet (sous le hero score).
            MatchSouvenirHeroCta(match: m),
            // ── Onglets ─────────────────────────────────────────────────────
            MatchDetailUnderlineTabs(
              controller: _tabs,
              labels: const ['Résumé', 'Composition', 'Prochain'],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _MatchDayTab(match: m),
                  _LineUpTab(match: m),
                  _NextMatchTab(match: m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero match header ─────────────────────────────────────────────────────────
// ── Image stade seule (persiste en mode réduit) ──────────────────────────────
class _MatchHeroImage extends StatelessWidget {
  final MatchModel match;
  const _MatchHeroImage({required this.match});

  @override
  Widget build(BuildContext context) {
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
        if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
          return Image.network(
            effectiveUrl,
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.6),
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
              fit: BoxFit.cover,
            ),
          );
        }
        return Image.asset(
          'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
          fit: BoxFit.cover,
        );
      },
    );
  }
}

// ── Titre compact (SliverAppBar réduit) ──────────────────────────────────────
class _HeroCompactTitle extends StatelessWidget {
  final MatchModel match;
  const _HeroCompactTitle({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MatchDetailPalette.gold.withAlpha(160), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: MatchDetailPalette.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            match.competition.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu hero étendu ───────────────────────────────────────────────────────
class _MatchHeroContent extends StatelessWidget {
  final MatchModel match;
  const _MatchHeroContent({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live;
    final isUpcoming = match.status == MatchStatus.upcoming && !match.earlyPublish;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
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
        if (linked && liveData != null) {
          s1 = (liveData['scoreHome'] as num? ?? s1).toInt();
          s2 = (liveData['scoreAway'] as num? ?? s2).toInt();
          minute = (liveData['minute'] ?? '').toString().trim();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ── Logos + score ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Équipe 1
                    Expanded(child: _HeroTeam(name: match.team1, logo: match.logo1, alignEnd: false)),

                    // Score central
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: isUpcoming && !linked
                          ? _HeroVsBlock(date: match.date)
                          : _HeroScoreBlock(
                              s1: s1, s2: s2,
                              isLive: showAsLive,
                              minute: minute,
                            ),
                    ),

                    // Équipe 2
                    Expanded(child: _HeroTeam(name: match.team2, logo: match.logo2, alignEnd: true)),
                  ],
                ),

                const SizedBox(height: 16),

                if (linked && liveData != null && liveData['radioLive'] == true) ...[
                  _MatchHeroRadioListenButton(),
                  const SizedBox(height: 12),
                ],

                // Ligne info bas
                if (!showAsLive)
                  Text(
                    _formatDate(match.date),
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(160), letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime d) {
    const days = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    const months = ['janvier','février','mars','avril','mai','juin',
        'juillet','août','septembre','octobre','novembre','décembre'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} · '
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }
}

class _MatchHeroRadioListenButton extends StatelessWidget {
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
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: MatchDetailPalette.red,
                        ),
                      );
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: listening
                    ? Colors.white.withAlpha(22)
                    : MatchDetailPalette.gold,
                borderRadius: BorderRadius.circular(999),
                border: listening
                    ? Border.all(color: Colors.white.withAlpha(55))
                    : null,
              ),
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
                    color: listening || connecting
                        ? Colors.white
                        : Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connecting
                        ? 'CONNEXION…'
                        : listening
                            ? 'EN DIRECT — AUDIO'
                            : 'ÉCOUTER EN AUDIO',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: listening || connecting
                          ? Colors.white
                          : Colors.black,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroTeam extends StatelessWidget {
  final String name;
  final String? logo;
  final bool alignEnd;
  const _HeroTeam({required this.name, this.logo, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: logo != null
                  ? Image.network(logo!, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Color(0xFF173C31), size: 26))
                  : const Icon(Icons.shield, color: Color(0xFF173C31), size: 26),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name.toUpperCase(),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 15, fontWeight: FontWeight.w800,
            color: Colors.white, height: 1.05,
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

// Score live ou terminé
class _HeroScoreBlock extends StatelessWidget {
  final int s1, s2;
  final bool isLive;
  final String minute;
  const _HeroScoreBlock({
    required this.s1, required this.s2,
    this.isLive = false, this.minute = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Score
        Text(
          '$s1  –  $s2',
          style: GoogleFonts.barlowCondensed(
            fontSize: 62, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1.0, letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        if (isLive) ...[
          // Badge LIVE + minute
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFBA203C),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: const Color(0xFFBA203C).withAlpha(80), blurRadius: 12)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  minute.isNotEmpty ? 'EN DIRECT · $minute\'' : 'EN DIRECT',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Text(
              'TERMINÉ',
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.white70, letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Heure de coup d'envoi pour match à venir
class _HeroVsBlock extends StatelessWidget {
  final DateTime date;
  const _HeroVsBlock({required this.date});

  @override
  Widget build(BuildContext context) {
    final diff = date.difference(DateTime.now());
    final days = diff.inDays;
    final String countdown = diff.isNegative
        ? ''
        : days == 0
            ? '${diff.inHours}h'
            : '${days}j';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}',
          style: GoogleFonts.barlowCondensed(
            fontSize: 54, fontWeight: FontWeight.w900,
            color: Colors.white, height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        if (countdown.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: MatchDetailPalette.green.withAlpha(180),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF1E6B56).withAlpha(200)),
            ),
            child: Text(
              'DANS $countdown',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

// ── RÉSUMÉ tab ────────────────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final MatchModel match;
  const _SummaryTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Cartons récap + homme du match (score déjà dans le hero)
        _MatchLiveSummary(match: match),
        MatchRatingDetailCardStream(matchId: match.id),
        MatchLineupsDetailCard(
          matchId: match.id,
          team1: match.team1,
          team2: match.team2,
        ),
        if (match.replayVideoId != null)
          _ReplayBanner(videoId: match.replayVideoId!, match: match),
        const SizedBox(height: 4),
        _MatchStatsSection(match: match),
        const SizedBox(height: 12),
        _InfoBlock(match: match),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Timeline en direct ────────────────────────────────────────────────────────
class _LiveTimeline extends StatelessWidget {
  final MatchModel match;
  const _LiveTimeline({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        final data = snap.data!.data() as Map<String, dynamic>;
        final team1 = (data['team1'] as String? ?? '').toUpperCase();
        final team2 = (data['team2'] as String? ?? '').toUpperCase();

        // Vérifie que c'est bien ce match
        final liveMatchId = (data['matchId'] as String? ?? '').trim();
        final sameMatch = liveMatchId.isNotEmpty
            ? liveMatchId == match.id
            : team1.contains(match.team1.toUpperCase().split(' ').first) ||
                  match.team1.toUpperCase().contains(team1.split(' ').first);
        if (!sameMatch) return const SizedBox();

        final home = (data['scoreHome'] ?? 0) as int;
        final away = (data['scoreAway'] ?? 0) as int;
        final minute = (data['minute'] ?? 0) as int;
        final phase = LiveMatchPhase((data['lastEvent'] ?? '').toString());
        final isHalftime = phase.isHalftime;
        final clockLabel = LiveBannerFormat.minuteLabelFromMap(data);

        // Masquer si aucun événement, score 0-0 et minute 0 (match pas vraiment commencé)
        final raw0 = data['events'];
        final hasEvt = raw0 is List && (raw0 as List).isNotEmpty;
        if (!hasEvt &&
            home == 0 &&
            away == 0 &&
            minute == 0 &&
            !phase.chronoLocked) {
          return const SizedBox();
        }
        final yellowH = (data['yellowHome'] ?? 0) as int;
        final yellowA = (data['yellowAway'] ?? 0) as int;
        final redH = (data['redHome'] ?? 0) as int;
        final redA = (data['redAway'] ?? 0) as int;

        // Construit la liste d'événements
        final raw = data['events'];
        final liveEvents = raw is List
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .where(
                    (e) => MatchStatsSchema.isTrackedGameEvent(e['type']),
                  )
                  .toList()
            : <Map<String, dynamic>>[];

        final List<_TimelineEvent> events = [];
        for (final g in liveEvents) {
          events.add(
            _TimelineEvent(
              minute: (g['minute'] as int?) ?? 0,
              type: g['type'] as String? ?? 'goal',
              team: g['team'] as String? ?? '',
              player: MatchStatsSchema.eventPlayerLine(g),
              isHome: (g['team'] as String? ?? '').toUpperCase().contains(
                team1.split(' ').first,
              ),
            ),
          );
        }
        if (isHalftime) {
          events.add(
            _TimelineEvent(
              minute: 45,
              type: 'halftime',
              team: '',
              player: '',
              isHome: true,
            ),
          );
        }
        events.sort(
          (a, b) => b.minute.compareTo(a.minute),
        ); // plus récent en haut

        // Masquer tout le bandeau si aucun événement à afficher
        // (sauf MI-TEMPS / FIN : le tampon de phase doit rester visible)
        if (events.isEmpty && !phase.chronoLocked) return const SizedBox();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: MatchDetailTheme.paper(
            edge: MatchDetailTheme.red.withValues(alpha: 0.35),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    const MatchDetailStamp(label: 'EN DIRECT', live: true),
                    const Spacer(),
                    if (phase.chronoLocked)
                      MatchDetailStamp(
                        label: clockLabel,
                        live: phase.isMatchEnded,
                        background: phase.isMatchEnded
                            ? null
                            : const Color(0xFFFFE8D0),
                        foreground: phase.isMatchEnded
                            ? null
                            : const Color(0xFFB45309),
                      )
                    else if (clockLabel.endsWith("'"))
                      MatchDetailStamp(
                        label: 'DIRECT · $clockLabel',
                        live: true,
                      ),
                  ],
                ),
              ),
              // Score central
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // DOM cartons
                    _MiniCards(yellow: yellowH, red: redH),
                    // Score
                    Row(
                      children: [
                        Text(
                          '$home',
                          style: MatchDetailType.headline.copyWith(fontSize: 36),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '—',
                            style: MatchDetailType.title.copyWith(
                              color: MatchDetailTheme.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          '$away',
                          style: MatchDetailType.headline.copyWith(fontSize: 36),
                        ),
                      ],
                    ),
                    // EXT cartons
                    _MiniCards(yellow: yellowA, red: redA),
                  ],
                ),
              ),
              // Noms équipes
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      team1,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                    Text(
                      team2,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Timeline événements
              if (events.isNotEmpty) ...[
                Container(height: 1, color: MatchDetailPalette.border),
                ...events.map(
                  (e) => _TimelineTile(event: e, team1: team1, team2: team2),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineEvent {
  final int minute;
  final String type; // 'goal', 'yellow', 'red', 'halftime'
  final String team, player;
  final bool isHome;
  const _TimelineEvent({
    required this.minute,
    required this.type,
    required this.team,
    required this.player,
    required this.isHome,
  });
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEvent event;
  final String team1, team2;
  const _TimelineTile({
    required this.event,
    required this.team1,
    required this.team2,
  });

  @override
  Widget build(BuildContext context) {
    if (event.type == 'halftime') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              border: Border.all(color: Colors.orange.withAlpha(80)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⏸  MI-TEMPS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    final accent = _MatchEventGlyph.accentFor(event.type);

    final isHome = event.isHome;
    final minuteBox = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Center(
        child: Text(
          "${event.minute}'",
          style: GoogleFonts.barlowCondensed(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: isHome
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isHome) ...[
              Text(
                event.player,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MatchDetailPalette.text,
                ),
              ),
              const SizedBox(width: 6),
              _MatchEventGlyph(type: event.type, size: 15),
            ] else ...[
              _MatchEventGlyph(type: event.type, size: 15),
              const SizedBox(width: 6),
              Text(
                event.player,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MatchDetailPalette.text,
                ),
              ),
            ],
          ],
        ),
        Text(
          isHome ? team1 : team2,
          style: GoogleFonts.inter(fontSize: 10, color: MatchDetailPalette.grey),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: isHome
            ? [minuteBox, const SizedBox(width: 12), Expanded(child: content)]
            : [Expanded(child: content), const SizedBox(width: 12), minuteBox],
      ),
    );
  }
}

// ── Résumé post-match (données enregistrées depuis le live) ──────────────────
class _MatchLiveSummary extends StatelessWidget {
  final MatchModel match;
  const _MatchLiveSummary({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final d = snap.data!.data() as Map<String, dynamic>?;
        if (d == null) return const SizedBox();

        final manOfTheMatchName =
            (d['manOfTheMatchName'] as String? ?? '').trim();
        final manOfTheMatchPartnerName =
            (d['manOfTheMatchPartnerName'] as String? ?? '').trim();
        final manOfTheMatchPartnerLogo =
            (d['manOfTheMatchPartnerLogo'] as String? ?? '').trim();
        final showMotm = d['showMotm'] != false;
        final hasMotm = manOfTheMatchName.isNotEmpty && showMotm;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (context, liveSnap) {
            final liveData = liveSnap.data?.data();
            final liveMatchId =
                (liveData?['matchId'] as String? ?? '').trim();
            final isLiveMatch = liveMatchId == match.id.trim();

            // Cartons : depuis live/current si match actif, sinon depuis doc match
            int yellowH, yellowA, redH, redA;
            if (isLiveMatch && liveData != null) {
              final liveEvents =
                  MatchStatsSchema.parseGameEvents(liveData['events']);
              yellowH = liveEvents
                  .where((e) =>
                      e['type'] == 'yellow' &&
                      MatchStatsSchema.isHomeTeamEvent(
                          e, match.team1, match.team2))
                  .length;
              yellowA = liveEvents
                  .where((e) =>
                      e['type'] == 'yellow' &&
                      !MatchStatsSchema.isHomeTeamEvent(
                          e, match.team1, match.team2))
                  .length;
              redH = liveEvents
                  .where((e) =>
                      e['type'] == 'red' &&
                      MatchStatsSchema.isHomeTeamEvent(
                          e, match.team1, match.team2))
                  .length;
              redA = liveEvents
                  .where((e) =>
                      e['type'] == 'red' &&
                      !MatchStatsSchema.isHomeTeamEvent(
                          e, match.team1, match.team2))
                  .length;
              // Fallback sur les champs du doc si le live n'a pas encore d'événements
              if (yellowH + yellowA + redH + redA == 0) {
                yellowH = (d['yellowHome'] ?? 0) as int;
                yellowA = (d['yellowAway'] ?? 0) as int;
                redH = (d['redHome'] ?? 0) as int;
                redA = (d['redAway'] ?? 0) as int;
              }
            } else {
              yellowH = (d['yellowHome'] ?? 0) as int;
              yellowA = (d['yellowAway'] ?? 0) as int;
              redH = (d['redHome'] ?? 0) as int;
              redA = (d['redAway'] ?? 0) as int;
            }

            final hasCards = yellowH + yellowA + redH + redA > 0;
            if (!hasMotm && !hasCards) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: MatchDetailPalette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MatchDetailPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCards) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            match.team1.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: MatchDetailPalette.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _MiniCards(yellow: yellowH, red: redH),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            match.team2.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: MatchDetailPalette.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _MiniCards(yellow: yellowA, red: redA),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (hasMotm) ...[
                if (hasCards)
                  Container(height: 1, color: MatchDetailPalette.border),
                _ManOfTheMatchCard(
                  player: manOfTheMatchName,
                  partnerName: manOfTheMatchPartnerName,
                  partnerLogo: manOfTheMatchPartnerLogo,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
          },
        );
      },
    );
  }
}

class _MiniCards extends StatelessWidget {
  final int yellow, red;
  const _MiniCards({required this.yellow, required this.red});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (yellow > 0) ...[
        ...List.generate(
          yellow,
          (_) => Container(
            width: 10,
            height: 14,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
      if (red > 0) ...[
        ...List.generate(
          red,
          (_) => Container(
            width: 10,
            height: 14,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: MatchDetailPalette.red,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
      if (yellow == 0 && red == 0) const SizedBox(width: 24),
    ],
  );
}

class _ManOfTheMatchCard extends StatelessWidget {
  final String player;
  final String partnerName;
  final String partnerLogo;

  const _ManOfTheMatchCard({
    required this.player,
    required this.partnerName,
    required this.partnerLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (partnerLogo.isNotEmpty) ...[
            SquarePartnerLogo(
              url: partnerLogo,
              lockSquare: false,
              size: 42,
              maxWidth: 84,
              maxHeight: 42,
              background: MatchDetailPalette.bg,
              borderColor: MatchDetailPalette.border,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOMME DU MATCH',
                  style: MatchDetailType.kicker.copyWith(
                    color: MatchDetailTheme.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MatchDetailPalette.text,
                  ),
                ),
                if (partnerName.isNotEmpty)
                  Text(
                    'Avec $partnerName',
                    style: GoogleFonts.inter(fontSize: 11, color: MatchDetailPalette.grey),
                  ),
              ],
            ),
          ),
          const Icon(Icons.emoji_events_outlined, color: MatchDetailTheme.green, size: 18),
        ],
      ),
    );
  }
}

class _ReplayBanner extends StatelessWidget {
  final String videoId;
  final MatchModel match;
  const _ReplayBanner({required this.videoId, required this.match});

  String _extractId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      if (uri.queryParameters.containsKey('v'))
        return uri.queryParameters['v']!;
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments[0] == 'live' || uri.pathSegments[0] == 'shorts')) {
        return uri.pathSegments[1];
      }
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final id = _extractId(videoId);
    final thumb = 'https://img.youtube.com/vi/$id/mqdefault.jpg';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: () {
          final video = VideoModel(
            id: match.id,
            title: '${match.team1} - ${match.team2}',
            youtubeId: id,
            duration: '',
            date: match.date,
            category: 'resume',
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VideoWebScreen(video: video)),
          );
        },
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: MatchDetailPalette.card,
            border: Border.all(color: MatchDetailPalette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                thumb,
                fit: BoxFit.cover,
                cacheWidth: matchDetailHeroCacheWidth(context),
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => Container(
                  color: MatchDetailPalette.card,
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              ),
              // Dégradé bas
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(200)],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // Bouton play central
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withAlpha(80),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              // Label bas
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MatchDetailPalette.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.black,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VOIR LE MATCH',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Text(
                        'REPLAY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final MatchModel match;
  const _InfoBlock({required this.match});

  @override
  Widget build(BuildContext context) {
    final lieu = (match.lieu ?? '').trim();
    final ville = (match.ville ?? match.city ?? '').trim();
    final adresse = (match.adresse ?? '').trim();
    final canGo = StadiumMapsLauncher.canNavigate(match);
    final canCal = MatchDeviceCalendar.canAdd(match);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: MatchDetailTheme.paper(sedan: isSedanMatch(match)),
      child: Column(
        children: [
          _InfoRow('Compétition', match.competition),
          Divider(height: 1, color: MatchDetailPalette.border),
          _InfoRow('Statut', _statusLabel(match.status)),
          if (match.score1 != null) ...[
            Divider(height: 1, color: MatchDetailPalette.border),
            _InfoRow(
              'Score',
              '${match.score1} – ${match.score2}',
              valueColor: MatchDetailTheme.green,
            ),
          ],
          if (lieu.isNotEmpty) ...[
            Divider(height: 1, color: MatchDetailPalette.border),
            _InfoRow('Lieu', lieu),
          ],
          if (ville.isNotEmpty) ...[
            Divider(height: 1, color: MatchDetailPalette.border),
            _InfoRow('Ville', ville),
          ],
          if (adresse.isNotEmpty) ...[
            Divider(height: 1, color: MatchDetailPalette.border),
            _InfoRow('Adresse', adresse),
          ],
          MatchTvBlock(streamBroadcast: match.streamBroadcast),
          MatchKickoffWeatherLine(match: match),
          MatchWeatherPollBlock(match: match),
          DugauguezPlaceFicheSlot(match: match),
          if (canGo || canCal) ...[
            Divider(height: 1, color: MatchDetailPalette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canGo)
                    MatchDetailPaperButton(
                      label: 'Y aller',
                      icon: Icons.directions_rounded,
                      ink: true,
                      onTap: () =>
                          StadiumMapsLauncher.showPicker(context, match),
                    ),
                  if (canGo && canCal) const SizedBox(height: 8),
                  if (canCal)
                    MatchDetailPaperButton(
                      label: 'Ajouter au calendrier',
                      icon: Icons.event_outlined,
                      onTap: () =>
                          MatchDeviceCalendar.addToDevice(context, match),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(MatchStatus s) {
    switch (s) {
      case MatchStatus.live:
        return 'DIRECT';
      case MatchStatus.finished:
        return 'TERMINE';
      case MatchStatus.upcoming:
        return 'A VENIR';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MatchDetailPalette.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? MatchDetailPalette.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── STATS ─────────────────────────────────────────────────────────────────────
class _StatsBlock extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> events;
  final String team1;
  final String team2;
  final String matchId;

  const _StatsBlock({
    required this.stats,
    this.events = const [],
    this.team1 = '',
    this.team2 = '',
    this.matchId = '',
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final customStats = _extractDetailCustomStats(s['customStats']);

    Widget section(String label, IconData _) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: MatchDetailSectionHeader(title: label),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: MatchDetailTheme.paper(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (events.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: MatchDetailSectionHeader(title: 'Faits de jeu'),
            ),
            const SizedBox(height: 10),
            _MatchGameEventsTimeline(
              matchId: matchId,
              events: events,
              team1: team1,
              team2: team2,
            ),
            Container(height: 1, color: MatchDetailPalette.border),
          ],

          // ── Stats ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Possession ───────────────────────────────────
                section('POSSESSION', Icons.timer_rounded),
                _StatBar(label: 'Possession',
                  v1: (s['possession1'] as num? ?? 50).toDouble(),
                  v2: () {
                    final p2 = (s['possession2'] as num?)?.toDouble();
                    final p1 = (s['possession1'] as num?)?.toDouble();
                    if (p2 != null && p2 > 0) return p2;
                    if (p1 != null && p1 > 0) return (100 - p1).clamp(0, 100).toDouble();
                    return 50.0;
                  }(),
                  isPercent: true),

                // ── Tirs ─────────────────────────────────────────
                section('TIRS', Icons.sports_soccer_rounded),
                _StatBar(label: 'Tirs',
                  v1: (s['tirs1'] as num? ?? 0).toDouble(),
                  v2: (s['tirs2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Cadrés',
                  v1: (s['tirsCadres1'] as num? ?? 0).toDouble(),
                  v2: (s['tirsCadres2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Poteaux',
                  v1: (s['poteau1'] as num? ?? 0).toDouble(),
                  v2: (s['poteau2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Contrées',
                  v1: (s['blocked1'] as num? ?? 0).toDouble(),
                  v2: (s['blocked2'] as num? ?? 0).toDouble()),

                // ── Passes ───────────────────────────────────────
                section('PASSES', Icons.swap_horiz_rounded),
                _StatBar(label: 'Réussies',
                  v1: (s['passes1'] as num? ?? 0).toDouble(),
                  v2: (s['passes2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Ratées',
                  v1: (s['passInacc1'] as num? ?? 0).toDouble(),
                  v2: (s['passInacc2'] as num? ?? 0).toDouble()),

                // ── Centres ──────────────────────────────────────
                section('CENTRES', Icons.open_with_rounded),
                _StatBar(label: 'Réussis',
                  v1: (s['crossAcc1'] as num? ?? 0).toDouble(),
                  v2: (s['crossAcc2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Ratés',
                  v1: (s['crossInacc1'] as num? ?? 0).toDouble(),
                  v2: (s['crossInacc2'] as num? ?? 0).toDouble()),

                // ── Duels ────────────────────────────────────────
                section('DUELS', Icons.sports_mma_rounded),
                _StatBar(label: 'Gagnés',
                  v1: (s['duelWon1'] as num? ?? 0).toDouble(),
                  v2: (s['duelWon2'] as num? ?? 0).toDouble()),

                // ── Événements ───────────────────────────────────
                section('ÉVÉNEMENTS', Icons.flag_rounded),
                _StatBar(label: 'Corners',
                  v1: (s['corners1'] as num? ?? 0).toDouble(),
                  v2: (s['corners2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Hors-jeu',
                  v1: (s['horsJeu1'] as num? ?? 0).toDouble(),
                  v2: (s['horsJeu2'] as num? ?? 0).toDouble()),
                const SizedBox(height: 14),
                _StatBar(label: 'Fautes',
                  v1: (s['fautes1'] as num? ?? 0).toDouble(),
                  v2: (s['fautes2'] as num? ?? 0).toDouble()),
                if ((s['arretsGardien1'] as num? ?? 0) + (s['arretsGardien2'] as num? ?? 0) > 0) ...[
                  const SizedBox(height: 14),
                  _StatBar(label: 'Arrêts gardien',
                    v1: (s['arretsGardien1'] as num? ?? 0).toDouble(),
                    v2: (s['arretsGardien2'] as num? ?? 0).toDouble()),
                ],

                if (customStats.isNotEmpty) ...[
                  section('AUTRES', Icons.bar_chart_rounded),
                  ...customStats.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CustomStatBar(
                      label: row.label,
                      value1: row.value1,
                      value2: row.value2,
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchStatsSection extends StatelessWidget {
  final MatchModel match;
  const _MatchStatsSection({required this.match});

  @override
  Widget build(BuildContext context) {
    // Double stream : stats publiées (match doc) + live direct (live/current)
    return StreamBuilder<MatchStatsDisplay>(
      stream: MatchStatsRepository.instance.watchWithLivePreview(match.id),
      builder: (context, snapDisplay) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (context, snapLive) {
            final display = snapDisplay.data ?? MatchStatsDisplay.hidden;
            final liveData = snapLive.data?.data();

            // Vérifie si ce match est le match live actif
            final liveMatchId =
                (liveData?['matchId'] as String? ?? '').trim();
            final isLiveMatch = liveMatchId == match.id.trim();

            // Événements live directs depuis live/current
            List<Map<String, dynamic>> liveEvents = [];
            Map<String, dynamic> liveStats = {};
            if (isLiveMatch && liveData != null) {
              liveEvents = MatchStatsSchema.parseGameEvents(liveData['events']);
              liveStats = MatchStatsSchema.normalizeMap(
                (liveData['stats'] ?? liveData['statsPreview'])
                    as Map<String, dynamic>?,
              );
            }

            // Fusion événements : doc match + live
            final mergedEvents = MatchStatsSchema.mergeGameEvents(
              display.events,
              liveEvents,
            );

            // Stats : priorité live si disponibles
            final mergedStats =
                liveStats.isNotEmpty ? liveStats : display.stats;

            final hasContent =
                mergedStats.isNotEmpty || mergedEvents.isNotEmpty;

            if (!hasContent && !display.shouldShow) return const SizedBox();

            return _StatsBlock(
              stats: mergedStats,
              events: mergedEvents,
              team1: match.team1,
              team2: match.team2,
              matchId: match.id,
            );
          },
        );
      },
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double v1;
  final double v2;
  final bool isPercent;

  const _StatBar({
    required this.label,
    required this.v1,
    required this.v2,
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = v1 + v2;
    final ratio1 = total == 0 ? 0.5 : v1 / total;
    final ratio2 = 1.0 - ratio1;

    return Column(
      children: [
        Row(
          children: [
            Text(
              isPercent ? '${v1.toInt()}%' : v1.toInt().toString(),
              style: MatchDetailType.numeral.copyWith(fontSize: 16),
            ),
            const Spacer(),
            Text(
              label.toUpperCase(),
              style: MatchDetailType.kicker,
            ),
            const Spacer(),
            Text(
              isPercent ? '${v2.toInt()}%' : v2.toInt().toString(),
              style: MatchDetailType.numeral.copyWith(
                fontSize: 16,
                color: MatchDetailTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Row(
            children: [
              Expanded(
                flex: (ratio1 * 100).round().clamp(1, 99),
                child: Container(height: 3, color: MatchDetailTheme.green),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: (ratio2 * 100).round().clamp(1, 99),
                child: Container(height: 3, color: MatchDetailTheme.surfaceMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomStatBar extends StatelessWidget {
  final String label;
  final String value1;
  final String value2;

  const _CustomStatBar({
    required this.label,
    required this.value1,
    required this.value2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              value1,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MatchDetailPalette.gold,
              ),
            ),
            const Spacer(),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: MatchDetailPalette.grey,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              value2,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: MatchDetailPalette.border,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

class _DetailCustomStatRow {
  final String label;
  final String value1;
  final String value2;
  const _DetailCustomStatRow({
    required this.label,
    required this.value1,
    required this.value2,
  });
}

List<_DetailCustomStatRow> _extractDetailCustomStats(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map((row) {
        return _DetailCustomStatRow(
          label: (row['label'] as String? ?? '').trim(),
          value1: (row['value1'] ?? '').toString(),
          value2: (row['value2'] ?? '').toString(),
        );
      })
      .where((row) => row.label.isNotEmpty)
      .toList();
}

// ── FAITS DE JEU ─────────────────────────────────────────────────────────────
class _EventsTab extends StatelessWidget {
  final MatchModel match;
  const _EventsTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, liveSnap) {
        if (liveSnap.hasData && liveSnap.data!.exists) {
          final data = liveSnap.data!.data() as Map<String, dynamic>;
          final liveMatchId = (data['matchId'] as String? ?? '').trim();
          if (liveMatchId == match.id) {
            final liveEvents = _extractGameEvents(data['events'], match);
            return _EventsList(events: liveEvents, match: match);
          }
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('matches')
              .doc(match.id)
              .get(),
          builder: (context, snap) {
            final d = snap.data?.data() as Map<String, dynamic>?;
            final savedEvents = _extractGameEvents(
              d?['events'] ?? d?['liveEvents'],
              match,
            );
            return _EventsList(events: savedEvents, match: match);
          },
        );
      },
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<_GameEvent> events;
  final MatchModel match;

  const _EventsList({required this.events, required this.match});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucun fait de jeu pour ce match',
            style: GoogleFonts.inter(fontSize: 13, color: MatchDetailPalette.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: events.length,
      itemBuilder: (_, i) => _EventRow(event: events[i], match: match),
    );
  }
}

class _EventRow extends StatelessWidget {
  final _GameEvent event;
  final MatchModel match;
  const _EventRow({required this.event, required this.match});

  @override
  Widget build(BuildContext context) {
    final isTeam1 = event.team == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (isTeam1) ...[
            _EventContent(event: event, alignRight: false),
            const SizedBox(width: 12),
          ],
          _MinuteBadge(minute: event.minute),
          if (!isTeam1) ...[
            const SizedBox(width: 12),
            _EventContent(event: event, alignRight: true),
          ],
        ],
      ),
    );
  }
}

class _EventContent extends StatelessWidget {
  final _GameEvent event;
  final bool alignRight;
  const _EventContent({required this.event, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: alignRight
            ? [
                _MatchEventGlyph(type: event.type, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    event.player,
                    style: GoogleFonts.inter(fontSize: 13, color: MatchDetailPalette.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]
            : [
                Flexible(
                  child: Text(
                    event.player,
                    style: GoogleFonts.inter(fontSize: 13, color: MatchDetailPalette.grey),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _MatchEventGlyph(type: event.type, size: 16),
              ],
      ),
    );
  }
}

class _MinuteBadge extends StatelessWidget {
  final int minute;
  const _MinuteBadge({required this.minute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: MatchDetailPalette.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MatchDetailPalette.border),
      ),
      child: Text(
        "$minute'",
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MatchDetailPalette.grey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GameEvent {
  final int minute;
  final String type;
  final String player;
  final int team;
  const _GameEvent({
    required this.minute,
    required this.type,
    required this.player,
    required this.team,
  });
}

bool _isHomeEventForMatch(Map<String, dynamic> event, MatchModel match) {
  final rawBool = event['isHome'];
  if (rawBool is bool) return rawBool;

  final side = (event['side'] ?? event['teamSide'] ?? event['teamSlot'])
      ?.toString()
      .trim()
      .toLowerCase();
  if (side == 'home' || side == 'left' || side == 'team1') return true;
  if (side == 'away' || side == 'right' || side == 'team2') return false;

  final teamIndex = event['teamIndex'];
  if (teamIndex is num) return teamIndex.toInt() == 0;

  final teamRaw = (event['team'] ?? event['teamName'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final team1 = match.team1.trim().toUpperCase();
  final team2 = match.team2.trim().toUpperCase();

  if (teamRaw.isNotEmpty) {
    if (teamRaw == team1) return true;
    if (teamRaw == team2) return false;
    if (team1.isNotEmpty && teamRaw.contains(team1.split(' ').first)) {
      return true;
    }
    if (team2.isNotEmpty && teamRaw.contains(team2.split(' ').first)) {
      return false;
    }
  }

  return true;
}

List<_GameEvent> _extractGameEvents(dynamic raw, MatchModel match) {
  final maps = MatchStatsSchema.parseGameEvents(raw);

  final events = maps.map((e) {
    final isTeam1 = _isHomeEventForMatch(e, match);
    final name = MatchStatsSchema.eventPlayerLine(e);
    return _GameEvent(
      minute: (e['minute'] as num?)?.toInt() ?? 0,
      type: (e['type'] as String? ?? 'goal').toString(),
      player: name.isEmpty ? 'Inconnu' : name,
      team: isTeam1 ? 0 : 1,
    );
  }).toList();

  events.sort((a, b) => a.minute.compareTo(b.minute));
  return events;
}

// ── COMPO ─────────────────────────────────────────────────────────────────────
class _CompoTab extends StatelessWidget {
  final MatchModel match;
  const _CompoTab({required this.match});

  static const _team1Players = [
    '1 · Gardien — J. Moreau',
    '2 · Défenseur — T. Petit',
    '5 · Défenseur — A. Blanc',
    '4 · Défenseur — C. Noir',
    '3 · Défenseur — P. Gris',
    '8 · Milieu — M. Dupont',
    '6 · Milieu — K. Lambert',
    '10 · Milieu — L. Simon',
    '7 · Attaquant — S. Rouge',
    '9 · Attaquant — B. Verte',
    '11 · Attaquant — J. Bleu',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CompoSection(teamName: match.team1, players: _team1Players),
        const SizedBox(height: 16),
        _CompoSection(teamName: match.team2, players: _team1Players),
      ],
    );
  }
}

class _CompoSection extends StatelessWidget {
  final String teamName;
  final List<String> players;
  const _CompoSection({required this.teamName, required this.players});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MatchDetailPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MatchDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              teamName.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          Divider(height: 1, color: MatchDetailPalette.border),
          ...players.asMap().entries.map(
            (e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (e.key < players.length - 1)
                  Divider(height: 1, color: MatchDetailPalette.border, indent: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// ONGLETS — Tab bar + 3 vues
// ══════════════════════════════════════════════════════════════════════════════

class _MatchTabBar extends StatelessWidget {
  final TabController controller;
  const _MatchTabBar({required this.controller});

  static const _labels = ['Résumé', 'Composition', 'Prochain'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MatchDetailPalette.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            children: List.generate(_labels.length, (i) {
              final selected = controller.index == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.animateTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(left: i > 0 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? MatchDetailPalette.greenDeep
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? MatchDetailPalette.greenDeep
                            : MatchDetailPalette.border,
                      ),
                    ),
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : MatchDetailPalette.grey,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Onglet Match Day ──────────────────────────────────────────────────────────

class _MatchDayTab extends StatelessWidget {
  final MatchModel match;
  const _MatchDayTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _LiveTimeline(match: match),
        MatchCoachAudioCard(
          matchId: match.id,
          margin: const EdgeInsets.only(bottom: 16),
        ),
        MatchRatingDetailCardStream(matchId: match.id),
        _MatchLiveSummary(match: match),
        // Faits Direct (buteurs, cartons, hors-jeu…) — indépendants des stats.
        _MatchGameEventsSection(match: match),
        _BestGoalVoteOnMatchDay(match: match),
        _MatchMediaResumeSection(matchId: match.id),
        _MatchDayStatsSection(match: match),
        if (match.replayVideoId != null)
          _ReplayBanner(videoId: match.replayVideoId!, match: match),
        const SizedBox(height: 8),
        _InfoBlock(match: match),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Résumé séquentiel des clips vMix + stats audio/vidéo.
class _MatchMediaResumeSection extends StatelessWidget {
  final String matchId;
  const _MatchMediaResumeSection({required this.matchId});

  @override
  Widget build(BuildContext context) {
    // Stats écoutes/vues : admin only (Direct). Ici uniquement le résumé fan.
    return StreamBuilder<List<MatchHighlightClip>>(
      stream: MatchHighlightService.instance.watchPlaylist(matchId),
      builder: (context, clipSnap) {
        final clips = clipSnap.data ?? const <MatchHighlightClip>[];
        if (clips.isEmpty) return const SizedBox.shrink();
        final totalSec =
            clips.fold<int>(0, (a, c) => a + c.durationSec);
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: MatchDetailTheme.paper(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MatchDetailSectionHeader(title: 'Temps forts'),
              const SizedBox(height: 4),
              MatchDetailPaperButton(
                label: 'Résumé du match (${clips.length} clips'
                    '${totalSec > 0 ? ' · ${totalSec}s' : ''})',
                icon: Icons.playlist_play_rounded,
                ink: true,
                onTap: () => showMatchHighlightResume(
                  context,
                  matchId: matchId,
                  clips: clips,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Timeline des faits de jeu saisis au Direct / éditeur — sans attendre le statisticien.
class _MatchGameEventsSection extends StatelessWidget {
  final MatchModel match;
  const _MatchGameEventsSection({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchStatsDisplay>(
      stream: MatchStatsRepository.instance.watchWithLivePreview(match.id),
      builder: (context, snapDisplay) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (context, snapLive) {
            final display = snapDisplay.data ?? MatchStatsDisplay.hidden;
            final liveData = snapLive.data?.data();
            final liveMatchId =
                (liveData?['matchId'] as String? ?? '').trim();
            final isLiveMatch = liveMatchId == match.id.trim();

            List<Map<String, dynamic>> liveEvents = const [];
            if (isLiveMatch && liveData != null) {
              liveEvents =
                  MatchStatsSchema.parseGameEvents(liveData['events']);
            }

            final events = MatchStatsSchema.mergeGameEvents(
              display.events,
              liveEvents,
            );
            if (events.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: MatchDetailTheme.paper(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: MatchDetailSectionHeader(title: 'Faits de jeu'),
                  ),
                  const SizedBox(height: 10),
                  _MatchGameEventsTimeline(
                    matchId: match.id,
                    events: events,
                    team1: match.team1,
                    team2: match.team2,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Wrapper : vote but du match sous les faits (buts cliquables).
class _BestGoalVoteOnMatchDay extends StatelessWidget {
  final MatchModel match;
  const _BestGoalVoteOnMatchDay({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchStatsDisplay>(
      stream: MatchStatsRepository.instance.watchWithLivePreview(match.id),
      builder: (context, snapDisplay) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (context, snapLive) {
            final display = snapDisplay.data ?? MatchStatsDisplay.hidden;
            final liveData = snapLive.data?.data();
            final liveMatchId =
                (liveData?['matchId'] as String? ?? '').trim();
            final isLiveMatch = liveMatchId == match.id.trim();
            List<Map<String, dynamic>> liveEvents = const [];
            if (isLiveMatch && liveData != null) {
              liveEvents =
                  MatchStatsSchema.parseGameEvents(liveData['events']);
            }
            final events = MatchStatsSchema.mergeGameEvents(
              display.events,
              liveEvents,
            );
            return BestGoalVoteSection(
              matchId: match.id,
              team1: match.team1,
              team2: match.team2,
              events: events,
              matchStatus: match.status.name,
            );
          },
        );
      },
    );
  }
}

/// Icône type de fait de jeu — DA fiche match (MiniCards / palette existante).
/// Pas de nouvelle esthétique Stories : juste un glyphe distinct par type.
class _MatchEventGlyph extends StatelessWidget {
  final String type;
  final double size;

  const _MatchEventGlyph({required this.type, this.size = 14});

  static String normalize(String raw) =>
      MatchStatsSchema.normalizeGameEventType(raw);

  static Color accentFor(String raw) {
    switch (normalize(raw)) {
      case 'yellow':
        return const Color(0xFFE8C82A);
      case 'red':
        return MatchDetailPalette.red;
      case 'substitution':
        return const Color(0xFF4A90D9);
      case 'goal_cancelled':
      case 'goal_disallowed':
        return const Color(0xFFEF9A9A);
      case 'offside':
        return const Color(0xFFFF9800);
      case 'own_goal':
        return const Color(0xFFBA68C8);
      default:
        return MatchDetailPalette.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = normalize(type);
    final accent = accentFor(type);
    // Cartons : rectangles pleins comme [_MiniCards], plus lisibles que crop_portrait.
    if (t == 'yellow' || t == 'red') {
      final fill = t == 'yellow' ? const Color(0xFFFFC107) : MatchDetailPalette.red;
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: size * 0.58,
            height: size * 0.86,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: accent.withAlpha(160), width: 0.6),
            ),
          ),
        ),
      );
    }

    final IconData icon = switch (t) {
      'substitution' => Icons.swap_horiz_rounded,
      'goal_cancelled' || 'goal_disallowed' => Icons.block_rounded,
      'offside' => Icons.flag_rounded,
      _ => Icons.sports_soccer_rounded,
    };
    return Icon(icon, size: size, color: accent);
  }
}

class _MatchGameEventsTimeline extends StatelessWidget {
  final String matchId;
  final List<Map<String, dynamic>> events;
  final String team1;
  final String team2;

  const _MatchGameEventsTimeline({
    required this.matchId,
    required this.events,
    required this.team1,
    required this.team2,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, MatchCommentaryClip>>(
      stream: MatchCommentaryService.instance.watchByEventId(matchId),
      builder: (context, audioSnap) {
        return StreamBuilder<Map<String, MatchHighlightClip>>(
          stream: MatchHighlightService.instance.watchByEventId(matchId),
          builder: (context, videoSnap) {
            final audioClips = audioSnap.data ?? const {};
            final videoClips = videoSnap.data ?? const {};
            return Column(
              children: events.map((g) {
                final type =
                    (g['type'] as String? ?? 'goal').trim().toLowerCase();
                final isHome =
                    MatchStatsSchema.isHomeTeamEvent(g, team1, team2);
                final accent = _MatchEventGlyph.accentFor(type);
                final player = MatchStatsSchema.eventPlayerLine(g);
                final minute = "${g['minute'] ?? '?'}'";
                final label = player.isEmpty ? 'Inconnu' : player;
                final eventId = (g['id'] ?? '').toString().trim();
                final audio =
                    eventId.isEmpty ? null : audioClips[eventId];
                final video =
                    eventId.isEmpty ? null : videoClips[eventId];
                final mediaBtns = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (audio != null)
                      MatchEventAudioPlayButton(
                        matchId: matchId,
                        clip: audio,
                        accent: accent,
                        compact: true,
                      ),
                    if (audio != null && video != null)
                      const SizedBox(width: 4),
                    if (video != null)
                      MatchEventVideoPlayButton(
                        matchId: matchId,
                        clip: video,
                        accent: accent,
                        compact: true,
                      ),
                  ],
                );

                Widget minuteChip() => Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent.withAlpha(70)),
                      ),
                      child: Center(
                        child: Text(
                          minute,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      if (isHome) ...[
                        minuteChip(),
                        const SizedBox(width: 8),
                        _MatchEventGlyph(type: type, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MatchDetailPalette.text,
                            ),
                          ),
                        ),
                        if (audio != null || video != null) ...[
                          const SizedBox(width: 6),
                          mediaBtns,
                        ],
                      ] else ...[
                        if (audio != null || video != null) ...[
                          mediaBtns,
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MatchDetailPalette.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _MatchEventGlyph(type: type, size: 14),
                        const SizedBox(width: 8),
                        minuteChip(),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _MatchDayStatsSection extends StatelessWidget {
  final MatchModel match;
  const _MatchDayStatsSection({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .snapshots(),
      builder: (context, matchSnap) {
        final matchDoc = matchSnap.data?.data() ?? {};
        return StreamBuilder<MatchStatsDisplay>(
          stream: MatchStatsRepository.instance.watchWithLivePreview(match.id),
          builder: (context, statsSnap) {
            final display = statsSnap.data ?? MatchStatsDisplay.hidden;
            final lineups = MatchLineups.mergeDocs(matchDoc, null);

            if (!display.shouldShow && !lineups.hasAnyContent) {
              return const SizedBox.shrink();
            }

            return _MatchDayStatsCard(
              match: match,
              stats: display.shouldShow ? display.stats : {},
              lineups: lineups,
            );
          },
        );
      },
    );
  }
}

class _MatchDayStatsCard extends StatelessWidget {
  final MatchModel match;
  final Map<String, dynamic> stats;
  final MatchLineups lineups;

  const _MatchDayStatsCard({
    required this.match,
    required this.stats,
    required this.lineups,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final hasFormation =
        lineups.home.formation.isNotEmpty || lineups.away.formation.isNotEmpty;
    final hasStats = s.isNotEmpty;

    if (!hasFormation && !hasStats) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: MatchDetailTheme.paper(sedan: isSedanMatch(match)),
      child: Column(
        children: [
          if (hasFormation) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.team1,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: MatchDetailPalette.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lineups.home.formation.isNotEmpty)
                          Text(
                            lineups.home.formation,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: MatchDetailPalette.gold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        match.status == MatchStatus.finished
                            ? 'RÉSULTAT FINAL'
                            : match.status == MatchStatus.live
                                ? 'EN DIRECT'
                                : 'STATISTIQUES',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: MatchDetailPalette.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          match.team2,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: MatchDetailPalette.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lineups.away.formation.isNotEmpty)
                          Text(
                            lineups.away.formation,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: MatchDetailPalette.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: MatchDetailPalette.border),
          ],
          if (hasStats) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      size: 13, color: MatchDetailPalette.gold),
                  const SizedBox(width: 6),
                  Text(
                    'STATISTIQUES',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: MatchDetailPalette.gold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _MatchDayStatRows(stats: s),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchDayStatRows extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _MatchDayStatRows({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    double v(String k) => (s[k] as num?)?.toDouble() ?? 0;

    final rows = <(String, double, double, bool)>[
      ('Tirs', v('tirs1'), v('tirs2'), false),
      ('Tirs cadrés', v('tirsCadres1'), v('tirsCadres2'), false),
      ('Possession', v('possession1'), v('possession2'), true),
      ('Passes', v('passes1'), v('passes2'), false),
      ('Corners', v('corners1'), v('corners2'), false),
      ('Hors-jeu', v('horsJeu1'), v('horsJeu2'), false),
      ('Fautes', v('fautes1'), v('fautes2'), false),
      ('Arrêts gardien', v('arretsGardien1'), v('arretsGardien2'), false),
      ('Duels gagnés', v('duelWon1'), v('duelWon2'), false),
    ].where((r) => r.$2 > 0 || r.$3 > 0).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: rows
          .map((r) => _MatchDayStatBar(
                label: r.$1,
                v1: r.$2,
                v2: r.$3,
                isPercent: r.$4,
              ))
          .toList(),
    );
  }
}

class _MatchDayStatBar extends StatelessWidget {
  final String label;
  final double v1;
  final double v2;
  final bool isPercent;

  const _MatchDayStatBar({
    required this.label,
    required this.v1,
    required this.v2,
    this.isPercent = false,
  });

  static const _colorHome = MatchDetailTheme.green;
  static const _colorAway = MatchDetailTheme.ink;
  static const _colorMuted = MatchDetailTheme.surfaceMuted;

  @override
  Widget build(BuildContext context) {
    final total = v1 + v2;
    final frac1 = total == 0 ? 0.5 : (v1 / total).clamp(0.0, 1.0);
    final win1 = v1 > v2;
    final win2 = v2 > v1;
    String fmt(double v) => isPercent ? '${v.toInt()}%' : v.toInt().toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Valeur domicile
          SizedBox(
            width: 36,
            child: Text(
              fmt(v1),
              textAlign: TextAlign.left,
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: win1 ? _colorHome : MatchDetailPalette.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Barre centrale
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: MatchDetailPalette.grey,
                  ),
                ),
                const SizedBox(height: 5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final totalW = constraints.maxWidth;
                    final w1 = totalW * frac1;
                    final w2 = totalW * (1 - frac1);
                    return Row(
                      children: [
                        // Barre gauche (domicile) — grandit depuis la droite
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: w1,
                              height: 7,
                              decoration: BoxDecoration(
                                color: win1 ? _colorHome : _colorMuted,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Trait central
                        Container(
                          width: 2,
                          height: 14,
                          decoration: BoxDecoration(
                            color: MatchDetailPalette.border,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        // Barre droite (extérieur) — grandit depuis la gauche
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: w2,
                              height: 7,
                              decoration: BoxDecoration(
                                color: win2 ? _colorAway : _colorMuted,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Valeur extérieur
          SizedBox(
            width: 36,
            child: Text(
              fmt(v2),
              textAlign: TextAlign.right,
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: win2 ? _colorAway : MatchDetailPalette.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet Line Up ────────────────────────────────────────────────────────────

class _LineUpTab extends StatelessWidget {
  final MatchModel match;
  const _LineUpTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .snapshots(),
      builder: (context, matchSnap) {
        if (matchSnap.hasError) {
          return _compositionUnavailablePlaceholder();
        }
        final matchDoc = matchSnap.data?.data() ?? {};
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('match_stats')
              .doc(match.id)
              .snapshots(),
          builder: (context, statsSnap) {
            final statsData =
                statsSnap.hasError ? null : statsSnap.data?.data();
            final lineups = MatchLineups.mergeDocs(matchDoc, statsData);
            final sedanMatch = LineupPredictionService.isSedanMatch(match);
            final officialSedan =
                LineupPredictionService.hasOfficialSedanLineup(lineups, match);

            // XI probable tant que le XI Sedan officiel (≥11 titulaires)
            // n’est pas publié. L’adversaire n’a jamais de jeu XI probable.
            if (sedanMatch && !officialSedan) {
              return ListenableBuilder(
                listenable: FeatureFlagsService.notifier,
                builder: (context, _) {
                  if (!PronoChampionshipRollout.isHubVisible) {
                    if (lineups.hasAnyContent) {
                      return _OfficialLineupsView(
                        match: match,
                        lineups: lineups,
                      );
                    }
                    return _compositionUnavailablePlaceholder();
                  }
                  return LineupPredictionGame(
                    match: match,
                    lineups: lineups,
                    matchDoc: matchDoc,
                  );
                },
              );
            }

            if (!lineups.hasAnyContent) {
              return _compositionUnavailablePlaceholder();
            }

            return _OfficialLineupsView(
              match: match,
              lineups: lineups,
              showSedanXiVerdict: sedanMatch && officialSedan,
            );
          },
        );
      },
    );
  }
}

/// Compos officielles **des deux côtés**. Verdict XI probable uniquement Sedan.
class _OfficialLineupsView extends StatelessWidget {
  final MatchModel match;
  final MatchLineups lineups;
  final bool showSedanXiVerdict;

  const _OfficialLineupsView({
    required this.match,
    required this.lineups,
    this.showSedanXiVerdict = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        final squad = squadSnap.hasError
            ? SedanSquad.empty
            : (squadSnap.data ?? SedanSquad.empty);
        final homeStarters = MatchStatsSchema.isSedanTeamLabel(match.team1)
            ? squad.sortLineupLabels(lineups.home.starters)
            : lineups.home.starters;
        final awayStarters = MatchStatsSchema.isSedanTeamLabel(match.team2)
            ? squad.sortLineupLabels(lineups.away.starters)
            : lineups.away.starters;
        final homeSubs = MatchStatsSchema.isSedanTeamLabel(match.team1)
            ? squad.sortLineupLabels(lineups.home.substitutes)
            : lineups.home.substitutes;
        final awaySubs = MatchStatsSchema.isSedanTeamLabel(match.team2)
            ? squad.sortLineupLabels(lineups.away.substitutes)
            : lineups.away.substitutes;
        final sedanIsHome = lineupSedanIsHome(match);

        Widget list({
          LineupXiVerdict? verdict,
          Set<String> sedanHits = const {},
        }) {
          final note = showSedanXiVerdict &&
                  PronoChampionshipRollout.isHubVisible
              ? verdict
              : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _LineUpHeader(
                team1: match.team1,
                team2: match.team2,
                formation1: lineups.home.formation,
                formation2: lineups.away.formation,
              ),
              if (note != null) ...[
                const SizedBox(height: 12),
                LineupXiSedanNote(
                  verdict: note,
                  sedanIsHome: sedanIsHome,
                ),
              ],
              const SizedBox(height: 12),
              _LineUpSection(
                label: 'TITULAIRES',
                home: homeStarters,
                away: awayStarters,
                highlight: true,
                hitLabels: sedanHits,
                markHitsOnHome: sedanIsHome,
              ),
              if (homeSubs.isNotEmpty || awaySubs.isNotEmpty) ...[
                const SizedBox(height: 12),
                _LineUpSection(
                  label: 'REMPLAÇANTS',
                  home: homeSubs,
                  away: awaySubs,
                  highlight: false,
                ),
              ],
              if (lineups.home.coach.isNotEmpty ||
                  lineups.away.coach.isNotEmpty) ...[
                const SizedBox(height: 12),
                _LineUpCoachRow(
                  coach1: lineups.home.coach,
                  coach2: lineups.away.coach,
                ),
              ],
            ],
          );
        }

        if (!showSedanXiVerdict) return list();

        return ListenableBuilder(
          listenable: FeatureFlagsService.notifier,
          builder: (context, _) {
            if (!PronoChampionshipRollout.isHubVisible) {
              return list();
            }
            return LineupXiOfficialBridge(
              match: match,
              lineups: lineups,
              builder: (context, verdict, sedanHits) => list(
                verdict: verdict,
                sedanHits: sedanHits,
              ),
            );
          },
        );
      },
    );
  }
}

Widget _compositionUnavailablePlaceholder() {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.groups_outlined,
          size: 48,
          color: MatchDetailPalette.grey.withAlpha(80),
        ),
        const SizedBox(height: 12),
        Text(
          'Composition non disponible',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MatchDetailPalette.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Elle sera affichée dès sa publication.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MatchDetailPalette.grey.withAlpha(160),
          ),
        ),
      ],
    ),
  );
}

class _LineUpHeader extends StatelessWidget {
  final String team1;
  final String team2;
  final String formation1;
  final String formation2;

  const _LineUpHeader({
    required this.team1,
    required this.team2,
    required this.formation1,
    required this.formation2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: MatchDetailTheme.paper(
        sedan: isSedanTeam(team1) || isSedanTeam(team2),
      ),
      child: Row(
        children: [
          // Équipe domicile
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team1,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: MatchDetailPalette.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (formation1.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formation1,
                    style: MatchDetailType.numeral.copyWith(
                      color: isSedanTeam(team1)
                          ? MatchDetailTheme.green
                          : MatchDetailTheme.text,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Séparateur central
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'VS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: MatchDetailPalette.grey,
                letterSpacing: 1,
              ),
            ),
          ),
          // Équipe extérieure
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  team2,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: MatchDetailPalette.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (formation2.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formation2,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: MatchDetailPalette.grey,
                      height: 1,
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

class _LineUpSection extends StatelessWidget {
  final String label;
  final List<String> home;
  final List<String> away;
  final bool highlight;

  /// Titulaires Sedan trouvés dans le XI probable — jamais l’adversaire.
  final Set<String> hitLabels;
  final bool markHitsOnHome;

  const _LineUpSection({
    required this.label,
    required this.home,
    required this.away,
    required this.highlight,
    this.hitLabels = const {},
    this.markHitsOnHome = false,
  });

  static (String, String) _parsePlayer(String raw) {
    final trimmed = raw.trim();
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx > 0 && spaceIdx <= 3) {
      final num = trimmed.substring(0, spaceIdx);
      if (int.tryParse(num) != null) {
        return (num, trimmed.substring(spaceIdx + 1).trim());
      }
    }
    return ('', trimmed);
  }

  @override
  Widget build(BuildContext context) {
    if (home.isEmpty && away.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Icon(
                highlight ? Icons.sports_soccer_rounded : Icons.swap_horiz_rounded,
                size: 12,
                color: highlight ? MatchDetailPalette.green : MatchDetailPalette.grey,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: highlight ? MatchDetailPalette.green : MatchDetailPalette.grey,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        // ── Deux colonnes de cartes ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne domicile
            Expanded(
              child: _PlayerColumn(
                players: home,
                isHome: true,
                isStarter: highlight,
                parsePlayer: _parsePlayer,
                hitLabels: highlight && markHitsOnHome ? hitLabels : const {},
              ),
            ),
            const SizedBox(width: 8),
            // Colonne extérieur
            Expanded(
              child: _PlayerColumn(
                players: away,
                isHome: false,
                isStarter: highlight,
                parsePlayer: _parsePlayer,
                hitLabels: highlight && !markHitsOnHome ? hitLabels : const {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  final List<String> players;
  final bool isHome;
  final bool isStarter;
  final (String, String) Function(String) parsePlayer;
  final Set<String> hitLabels;

  const _PlayerColumn({
    required this.players,
    required this.isHome,
    required this.isStarter,
    required this.parsePlayer,
    this.hitLabels = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    final numColor = isHome ? MatchDetailTheme.green : MatchDetailTheme.ink;

    return Column(
      children: players.map((raw) {
        final (num, name) = parsePlayer(raw);
        final displayName = name.isNotEmpty ? name : raw;
        final hit = hitLabels.contains(raw);

        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isHome ? MatchDetailTheme.sedanPaper : MatchDetailTheme.surface,
            border: const Border(
              bottom: BorderSide(color: MatchDetailTheme.hairline, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (num.isNotEmpty) ...[
                SizedBox(
                  width: 22,
                  child: Text(
                    num,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: numColor,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isStarter ? FontWeight.w600 : FontWeight.w400,
                    color: isStarter
                        ? MatchDetailPalette.text
                        : MatchDetailPalette.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hit) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: MatchDetailTheme.green,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LineUpCoachRow extends StatelessWidget {
  final String coach1;
  final String coach2;
  const _LineUpCoachRow({required this.coach1, required this.coach2});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _CoachChip(name: coach1, isHome: true)),
        const SizedBox(width: 8),
        Expanded(child: _CoachChip(name: coach2, isHome: false)),
      ],
    );
  }
}

class _CoachChip extends StatelessWidget {
  final String name;
  final bool isHome;
  const _CoachChip({required this.name, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final color = isHome ? MatchDetailTheme.green : MatchDetailTheme.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: MatchDetailTheme.paper(sedan: isHome),
      child: Row(
        children: [
          Icon(Icons.sports_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COACH',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: MatchDetailPalette.grey,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  name.isNotEmpty ? name : '—',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MatchDetailPalette.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet Prochain match ─────────────────────────────────────────────────────

class _NextMatchTab extends StatelessWidget {
  final MatchModel match;
  const _NextMatchTab({required this.match});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Après ce match s’il est encore à venir, sinon à partir de maintenant.
    final after = match.date.isAfter(now) ? match.date : now;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.fromDate(after))
          .orderBy('date')
          .limit(80)
          .snapshots(),
      builder: (context, snap) {
        final next = (snap.data?.docs ?? [])
            .map((d) {
              try {
                return MatchModel.fromFirestore(d);
              } catch (_) {
                return null;
              }
            })
            .whereType<MatchModel>()
            .where(isSedanMatch)
            .where((m) => m.id != match.id)
            .take(3)
            .toList();

        if (next.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 48,
                    color: MatchDetailPalette.grey.withAlpha(80)),
                const SizedBox(height: 12),
                Text(
                  'Aucun match à venir planifié',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MatchDetailPalette.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: MatchDetailSectionHeader(title: 'Prochains matchs'),
            ),
            ...next.map((m) => _NextMatchCard(match: m)),
          ],
        );
      },
    );
  }
}

class _NextMatchCard extends StatelessWidget {
  final MatchModel match;
  const _NextMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final date = longDateLabel(match.date);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchDetailScreen(match: match),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: MatchDetailTheme.paper(sedan: isSedanMatch(match)),
        child: Column(
          children: [
            Row(
              children: [
                MatchDetailCrest(
                  url: match.logo1,
                  teamName: match.team1,
                  size: MatchDetailTheme.crestCard,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    match.team1,
                    textAlign: TextAlign.left,
                    style: MatchDetailType.title.copyWith(fontSize: 16),
                    maxLines: 2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'VS',
                    style: MatchDetailType.kicker.copyWith(
                      color: MatchDetailTheme.text,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.team2,
                    textAlign: TextAlign.right,
                    style: MatchDetailType.title.copyWith(fontSize: 16),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 10),
                MatchDetailCrest(
                  url: match.logo2,
                  teamName: match.team2,
                  size: MatchDetailTheme.crestCard,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 11, color: MatchDetailPalette.grey),
                const SizedBox(width: 5),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MatchDetailPalette.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (match.competition.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                match.competition,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MatchDetailPalette.grey.withAlpha(160),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

