import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dvcr_share_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../models/match_model.dart';
import '../../models/video_model.dart';
import '../../services/favorites_service.dart';
import '../../services/notification_service.dart';
import '../../utils/open_prono_for_match.dart';
import '../../navigation/prono_championship_rollout.dart';
import '../../services/feature_flags_service.dart';
import '../../utils/share_helper.dart';
import '../video_web_screen.dart';
import 'match_detail_palette.dart';

class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  Future<void> _addToCalendar(BuildContext context, MatchModel m) async {
    final start = m.date;
    final end   = m.date.add(const Duration(hours: 2));

    String _fmt(DateTime dt) =>
        DateFormat("yyyyMMdd'T'HHmmss").format(dt.toUtc()) + 'Z';

    final title   = Uri.encodeComponent('${m.team1} vs ${m.team2}');
    final details = Uri.encodeComponent('${m.competition} · Retrouve le match sur l\'app DVCR');
    final dates   = '${_fmt(start)}/${_fmt(end)}';

    final googleUrl =
        'https://www.google.com/calendar/render?action=TEMPLATE'
        '&text=$title&dates=$dates&details=$details';

    final icsContent =
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n'
        'DTSTART:${_fmt(start)}\r\nDTEND:${_fmt(end)}\r\n'
        'SUMMARY:${m.team1} vs ${m.team2}\r\n'
        'DESCRIPTION:${m.competition}\r\n'
        'END:VEVENT\r\nEND:VCALENDAR';

    // Essaie Google Calendar en priorité
    final uri = Uri.parse(googleUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback : partage le fichier .ics
    await DvcrShare.share(
      icsContent,
      subject: 'DVCR · ${m.team1} vs ${m.team2}',
      attachShareCard: false,
    );
  }

  Future<MatchReminderMode?> _pickReminderMode() async {
    final prefs = await SharedPreferences.getInstance();
    var selected = MatchReminderMode.fromKey(
      prefs.getString('notif_match_remind_mode'),
    );
    if (!mounted) return null;

    final result = await showModalBottomSheet<MatchReminderMode>(
      context: context,
      backgroundColor: MatchDetailPalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHOISIR UN RAPPEL',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: MatchDetailPalette.gold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisis quand tu veux être prévenu pour ce match favori.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              ...MatchReminderMode.values.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setModalState(() => selected = mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected == mode
                            ? MatchDetailPalette.gold.withAlpha(16)
                            : Colors.white.withAlpha(4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected == mode ? MatchDetailPalette.gold : MatchDetailPalette.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected == mode
                                ? Icons.check_circle_rounded
                                : Icons.notifications_active_outlined,
                            color: selected == mode ? MatchDetailPalette.gold : Colors.white70,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              mode.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MatchDetailPalette.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'ENREGISTRER',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
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

    return Scaffold(
      backgroundColor: MatchDetailPalette.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: MatchDetailPalette.greenDeep,
            expandedHeight: 230,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Bouton calendrier — uniquement pour les matchs à venir
              if (m.status == MatchStatus.upcoming)
                IconButton(
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  tooltip: 'Ajouter à mon agenda',
                  onPressed: () => _addToCalendar(context, m),
                ),
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
                onPressed: () => DvcrShare.share(ShareHelper.matchText(m)),
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
                      color: isFav ? MatchDetailPalette.gold : Colors.white54,
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
            flexibleSpace: FlexibleSpaceBar(background: _MatchHero(match: m)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: MatchDetailPalette.gold.withAlpha(60)),
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
                  decoration: BoxDecoration(
                    color: MatchDetailPalette.gold.withAlpha(10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MatchDetailPalette.gold.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: MatchDetailPalette.gold.withAlpha(18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: MatchDetailPalette.gold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rappel actif pour ce match',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: MatchDetailPalette.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ce favori declenchera une notification ${reminderMode.label.toLowerCase()}.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: MatchDetailPalette.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(child: _SummaryTab(match: m)),
          ],
        ),
      ),
    );
  }
}

// ── Hero match header ─────────────────────────────────────────────────────────
class _MatchHero extends StatelessWidget {
  final MatchModel match;
  const _MatchHero({required this.match});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond stade (dynamique selon équipe domicile)
        StreamBuilder<QuerySnapshot>(
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
            final effectiveUrl = (url == null || url.isEmpty)
                ? match.stadiumImageUrl
                : url;
            if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
              return Image.network(
                effectiveUrl,
                fit: BoxFit.cover,
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
        ),
        // Dégradé sombre
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(42),
                MatchDetailPalette.green.withAlpha(155),
                MatchDetailPalette.greenDeep.withAlpha(220),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Contenu
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Badge compétition
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: MatchDetailPalette.gold.withAlpha(110)),
                ),
                child: Text(
                  match.competition.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MatchDetailPalette.gold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Équipes + score
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HeroTeam(name: match.team1, logo: match.logo1),
                  const SizedBox(width: 16),
                  if (match.status == MatchStatus.upcoming && !match.earlyPublish)
                    _VSCenter()
                  else if (match.score1 != null || match.status == MatchStatus.live)
                    _ScoreCenter(
                      score1: match.score1 ?? 0,
                      score2: match.score2 ?? 0,
                      isLive: match.status == MatchStatus.live,
                    )
                  else
                    _PendingScoreCenter(),
                  const SizedBox(width: 16),
                  _HeroTeam(name: match.team2, logo: match.logo2),
                ],
              ),
              const SizedBox(height: 14),
              // Date
              Text(
                _formatDate(match.date),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withAlpha(220),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} · '
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }
}

class _HeroTeam extends StatelessWidget {
  final String name;
  final String? logo;
  const _HeroTeam({required this.name, this.logo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: logo != null ? Colors.white : Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(42)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: logo != null
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    logo!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield,
                      color: Colors.white24,
                      size: 28,
                    ),
                  ),
                )
              : const Icon(Icons.shield, color: Colors.white24, size: 28),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VSCenter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'VS',
          style: GoogleFonts.permanentMarker(
            fontSize: 28,
            color: Colors.white.withAlpha(210),
          ),
        ),
        const SizedBox(height: 4),
        Container(width: 30, height: 1, color: MatchDetailPalette.gold.withAlpha(80)),
      ],
    );
  }
}

class _PendingScoreCenter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Résultat',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        Text(
          'disponible prochainement',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

class _ScoreCenter extends StatelessWidget {
  final int score1;
  final int score2;
  final bool isLive;
  const _ScoreCenter({
    required this.score1,
    required this.score2,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScoreBox(score: score1, isLive: isLive),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '-',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  color: Colors.white38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _ScoreBox(score: score2, isLive: isLive),
          ],
        ),
        if (isLive) ...[const SizedBox(height: 8), _LivePulse()],
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final int score;
  final bool isLive;
  const _ScoreBox({required this.score, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isLive ? MatchDetailPalette.red.withAlpha(200) : Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive ? MatchDetailPalette.red : Colors.white.withAlpha(48),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '$score',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isLive ? Colors.white : MatchDetailPalette.greenDeep,
          ),
        ),
      ),
    );
  }
}

class _LivePulse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MatchDetailPalette.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'EN DIRECT',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
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
        // Résumé post-match (si match terminé avec données live)
        _MatchLiveSummary(match: match),
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

        // Masquer si aucun événement, score 0-0 et minute 0 (match pas vraiment commencé)
        final raw0 = data['events'];
        final hasEvt = raw0 is List && (raw0 as List).isNotEmpty;
        if (!hasEvt &&
            home == 0 &&
            away == 0 &&
            minute == 0 &&
            data['lastEvent'] != 'halftime') {
          return const SizedBox();
        }
        final yellowH = (data['yellowHome'] ?? 0) as int;
        final yellowA = (data['yellowAway'] ?? 0) as int;
        final redH = (data['redHome'] ?? 0) as int;
        final redA = (data['redAway'] ?? 0) as int;
        final isHalftime = data['lastEvent'] == 'halftime';

        // Construit la liste d'événements
        final raw = data['events'];
        final liveEvents = raw is List
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .where(
                    (e) => const {'goal', 'yellow', 'red'}.contains(e['type']),
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
              player: g['player'] as String? ?? '',
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
        if (events.isEmpty) return const SizedBox();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: MatchDetailPalette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MatchDetailPalette.red.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: MatchDetailPalette.red.withAlpha(18),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: MatchDetailPalette.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EN DIRECT',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: MatchDetailPalette.red,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    if (minute > 0 && !isHalftime)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: MatchDetailPalette.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: MatchDetailPalette.red.withAlpha(90)),
                        ),
                        child: Text(
                          "DIRECT • $minute'",
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    if (isHalftime)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(30),
                          border: Border.all(
                            color: Colors.orange.withAlpha(150),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MI-TEMPS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.orange,
                            letterSpacing: 1,
                          ),
                        ),
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
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '—',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.white24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '$away',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
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

    final icon = switch (event.type) {
      'yellow' => Icons.crop_portrait_rounded,
      'red' => Icons.crop_portrait_rounded,
      _ => Icons.sports_soccer_rounded,
    };
    final accent = switch (event.type) {
      'yellow' => const Color(0xFFFFC107),
      'red' => MatchDetailPalette.red,
      _ => MatchDetailPalette.gold,
    };

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
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: accent, size: 15),
            ] else ...[
              Icon(icon, color: accent, size: 15),
              const SizedBox(width: 6),
              Text(
                event.player,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
    // Ne s'affiche que si le match est terminé
    if (match.status != MatchStatus.finished) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final d = snap.data!.data() as Map<String, dynamic>?;
        if (d == null) return const SizedBox();

        final rawEvents = d['events'] ?? d['liveEvents'];

        final events =
            (rawEvents is List ? rawEvents : <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .where(
                  (e) => const {'goal', 'yellow', 'red'}.contains(e['type']),
                )
                .toList()
              ..sort(
                (a, b) => (a['minute'] as int? ?? 0).compareTo(
                  b['minute'] as int? ?? 0,
                ),
              );
        final manOfTheMatchName = (d['manOfTheMatchName'] as String? ?? '')
            .trim();
        final manOfTheMatchPartnerName =
            (d['manOfTheMatchPartnerName'] as String? ?? '').trim();
        final manOfTheMatchPartnerLogo =
            (d['manOfTheMatchPartnerLogo'] as String? ?? '').trim();

        final s1 = (d['liveScore1'] ?? d['score1'] ?? match.score1 ?? 0) as int;
        final s2 = (d['liveScore2'] ?? d['score2'] ?? match.score2 ?? 0) as int;
        final yellowH = (d['yellowHome'] ?? 0) as int;
        final yellowA = (d['yellowAway'] ?? 0) as int;
        final redH = (d['redHome'] ?? 0) as int;
        final redA = (d['redAway'] ?? 0) as int;

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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      color: MatchDetailPalette.gold,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                    Text(
                      'RÉSUMÉ DU MATCH',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: MatchDetailPalette.gold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Score final + cartons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniCards(yellow: yellowH, red: redH),
                    Row(
                      children: [
                        Text(
                          '$s1',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '—',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              color: Colors.white24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '$s2',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    _MiniCards(yellow: yellowA, red: redA),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      match.team1.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                    Text(
                      match.team2.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (manOfTheMatchName.isNotEmpty && d['showMotm'] != false) ...[
                Container(height: 1, color: MatchDetailPalette.border),
                _ManOfTheMatchCard(
                  player: manOfTheMatchName,
                  partnerName: manOfTheMatchPartnerName,
                  partnerLogo: manOfTheMatchPartnerLogo,
                ),
              ],
              Container(height: 1, color: MatchDetailPalette.border),
              // Timeline événements
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Aucun fait de jeu enregistré',
                    style: GoogleFonts.inter(fontSize: 12, color: MatchDetailPalette.grey),
                  ),
                )
              else
                ...events.map((g) {
                  final isHome = (g['team'] as String? ?? '')
                      .toUpperCase()
                      .contains(match.team1.toUpperCase().split(' ').first);
                  final type = (g['type'] as String? ?? 'goal').toString();
                  final accent = _eventAccent(type);
                  final icon = _eventIcon(type);
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
                        "${g['minute'] ?? '?'}'",
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
                        children: isHome
                            ? [
                                Icon(icon, color: accent, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  g['player'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ]
                            : [
                                Text(
                                  g['player'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(icon, color: accent, size: 15),
                              ],
                      ),
                      Text(
                        '${g['team'] ?? ''} • ${_eventLabel(type)}',
                        style: GoogleFonts.inter(fontSize: 10, color: MatchDetailPalette.grey),
                      ),
                    ],
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: isHome
                          ? [
                              minuteBox,
                              const SizedBox(width: 12),
                              Expanded(child: content),
                            ]
                          : [
                              Expanded(child: content),
                              const SizedBox(width: 12),
                              minuteBox,
                            ],
                    ),
                  );
                }).toList(),
              const SizedBox(height: 8),
            ],
          ),
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

IconData _eventIcon(String type) {
  switch (type) {
    case 'yellow':
    case 'red':
      return Icons.crop_portrait_rounded;
    default:
      return Icons.sports_soccer_rounded;
  }
}

Color _eventAccent(String type) {
  switch (type) {
    case 'yellow':
      return const Color(0xFFFFC107);
    case 'red':
      return MatchDetailPalette.red;
    default:
      return MatchDetailPalette.gold;
  }
}

String _eventLabel(String type) {
  switch (type) {
    case 'yellow':
      return 'Carton jaune';
    case 'red':
      return 'Carton rouge';
    default:
      return 'But';
  }
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                partnerLogo,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: MatchDetailPalette.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    size: 18,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOMME DU MATCH',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: MatchDetailPalette.gold,
                    letterSpacing: 1.5,
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
          const Icon(Icons.emoji_events_rounded, color: MatchDetailPalette.gold, size: 18),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MatchDetailPalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MatchDetailPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
              valueColor: MatchDetailPalette.gold,
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

  const _StatsBlock({
    required this.stats,
    this.events = const [],
    this.team1 = '',
    this.team2 = '',
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final customStats = _extractDetailCustomStats(s['customStats']);

    Widget section(String label, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 11, color: MatchDetailPalette.gold),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: MatchDetailPalette.gold, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: MatchDetailPalette.gold.withAlpha(40))),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MatchDetailPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MatchDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline événements ───────────────────────────
          if (events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, size: 11, color: MatchDetailPalette.gold),
                  const SizedBox(width: 5),
                  Text('FAITS DE JEU',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: MatchDetailPalette.gold, letterSpacing: 1.2)),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, color: MatchDetailPalette.gold.withAlpha(40))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...events.map((g) {
              final type = (g['type'] as String? ?? 'goal');
              final isHome = (g['team'] as String? ?? '')
                  .toUpperCase()
                  .contains(team1.toUpperCase().split(' ').first);
              final accent = type == 'yellow'
                  ? const Color(0xFFE8C82A)
                  : type == 'red'
                      ? MatchDetailPalette.red
                      : MatchDetailPalette.gold;
              final icon = type == 'yellow' || type == 'red'
                  ? Icons.crop_portrait_rounded
                  : Icons.sports_soccer_rounded;
              final player = (g['player'] as String? ?? '').trim();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    if (isHome) ...[
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withAlpha(70)),
                        ),
                        child: Center(child: Text("${g['minute'] ?? '?'}'",
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 11, fontWeight: FontWeight.w900, color: accent))),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 13, color: accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(player.isEmpty ? 'Inconnu' : player,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: MatchDetailPalette.text))),
                    ] else ...[
                      Expanded(child: Text(player.isEmpty ? 'Inconnu' : player,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: MatchDetailPalette.text))),
                      const SizedBox(width: 6),
                      Icon(icon, size: 13, color: accent),
                      const SizedBox(width: 8),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withAlpha(70)),
                        ),
                        child: Center(child: Text("${g['minute'] ?? '?'}'",
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 11, fontWeight: FontWeight.w900, color: accent))),
                      ),
                    ],
                  ],
                ),
              );
            }),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(match.id)
          .snapshots(),
      builder: (context, matchSnap) {
        final matchData = matchSnap.data?.data() as Map<String, dynamic>?;
        // Toggle visibilité stats sur la carte
        if (matchData?['showStats'] == false) return const SizedBox();
        final st = (matchData?['status'] ?? 'upcoming').toString();
        final early = matchData?['earlyPublish'] == true;
        if (st == 'upcoming' && !early) return const SizedBox();

        // Uniquement les données sauvegardées — le live est géré par _LiveTimeline
        List<Map<String, dynamic>> _parseEvents(dynamic raw) =>
            (raw is List ? raw : <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .where((e) => const {'goal', 'yellow', 'red'}.contains(e['type']))
                .toList()
              ..sort((a, b) => (a['minute'] as int? ?? 0)
                  .compareTo(b['minute'] as int? ?? 0));

        // Uniquement les stats sauvegardées via l'admin (pas match.stats qui peut avoir de vieilles données)
        final fetchedStats = (matchData?['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final fetchedEvents = _parseEvents(matchData?['events']);

        if (fetchedStats.isEmpty && fetchedEvents.isEmpty) return const SizedBox();
        return _StatsBlock(
          stats: fetchedStats,
          events: fetchedEvents,
          team1: match.team1,
          team2: match.team2,
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
              isPercent ? '${v2.toInt()}%' : v2.toInt().toString(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MatchDetailPalette.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: (ratio1 * 100).round(),
                child: Container(height: 4, color: MatchDetailPalette.gold),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: (ratio2 * 100).round(),
                child: Container(height: 4, color: const Color(0xFF2A2A2A)),
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
    final icon = _eventIcon(event.type);
    final color = _eventColor(event.type);

    return Expanded(
      child: Row(
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: alignRight
            ? [
                Icon(icon, color: color, size: 16),
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
                Icon(icon, color: color, size: 16),
              ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'goal':
        return Icons.sports_soccer_rounded;
      case 'yellow':
        return Icons.crop_portrait_rounded;
      case 'red':
        return Icons.crop_portrait_rounded;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'goal':
        return MatchDetailPalette.gold;
      case 'yellow':
        return const Color(0xFFFFC107);
      case 'red':
        return MatchDetailPalette.red;
      default:
        return MatchDetailPalette.grey;
    }
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
  final maps = raw is List
      ? raw
            .whereType<Map<String, dynamic>>()
            .where((e) => const {'goal', 'yellow', 'red'}.contains(e['type']))
            .toList()
      : <Map<String, dynamic>>[];

  final events = maps.map((e) {
    final isTeam1 = _isHomeEventForMatch(e, match);
    return _GameEvent(
      minute: (e['minute'] as num?)?.toInt() ?? 0,
      type: (e['type'] as String? ?? 'goal').toString(),
      player: (e['player'] as String? ?? 'Inconnu').toString(),
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
