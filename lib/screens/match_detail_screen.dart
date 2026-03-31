import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/match_model.dart';
import '../models/video_model.dart';
import 'video_web_screen.dart';

const _kRed    = Color(0xFFBA203C);
const _kBg     = Color(0xFF0D0D0D);
const _kCard   = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kGrey   = Color(0xFF888888);
const _kGold   = Color(0xFFC8A436);

class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final m = widget.match;

    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 230,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_rounded,
                    color: Colors.white54, size: 20),
                onPressed: () {
                  final score = m.status == MatchStatus.finished && m.score1 != null
                      ? '${m.score1} - ${m.score2}'
                      : 'à venir';
                  final date = '${m.date.day}/${m.date.month}/${m.date.year}';
                  Share.share(
                    '⚽ ${m.team1} vs ${m.team2}\n'
                    '📅 $date · ${m.competition}\n'
                    'Score : $score\n\n'
                    'Retrouve tous les matchs sur l\'app DVCR !',
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _MatchHero(match: m),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _kGold.withAlpha(60)),
            ),
          ),
        ],
        body: _SummaryTab(match: m),
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
        // Fond stade
        Image.asset(
          'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
          fit: BoxFit.cover,
        ),
        // Dégradé sombre
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(160),
                Colors.black.withAlpha(200),
              ],
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGold.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kGold.withAlpha(100)),
                ),
                child: Text(
                  match.competition.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kGold,
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
                  if (match.status == MatchStatus.upcoming)
                    _VSCenter()
                  else
                    _ScoreCenter(
                      score1: match.score1 ?? 0,
                      score2: match.score2 ?? 0,
                      isLive: match.status == MatchStatus.live,
                    ),
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
                  color: Colors.white54,
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
    final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
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
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: logo != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(logo!, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield, color: Colors.white24, size: 28)),
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
            color: Colors.white.withAlpha(80),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 1,
          color: _kGold.withAlpha(80),
        ),
      ],
    );
  }
}

class _ScoreCenter extends StatelessWidget {
  final int score1;
  final int score2;
  final bool isLive;
  const _ScoreCenter(
      {required this.score1, required this.score2, this.isLive = false});

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
        if (isLive) ...[
          const SizedBox(height: 8),
          _LivePulse(),
        ],
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
        color: isLive ? _kRed.withAlpha(200) : Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive ? _kRed : Colors.white.withAlpha(40),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '$score',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
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
        color: _kRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
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
        if (match.replayVideoId != null)
          _ReplayBanner(videoId: match.replayVideoId!, match: match),
        if (match.stats != null) ...[
          const SizedBox(height: 4),
          _StatsBlock(match: match),
        ],
        const SizedBox(height: 12),
        _InfoBlock(match: match),
        const SizedBox(height: 24),
      ],
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
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments[0] == 'live' || uri.pathSegments[0] == 'shorts')) {
        return uri.pathSegments[1];
      }
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final id    = _extractId(videoId);
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
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => VideoWebScreen(video: video)));
        },
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _kCard,
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(thumb, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _kCard,
                    child: const Icon(Icons.play_circle_outline,
                        color: Colors.white24, size: 48),
                  )),
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
                    border: Border.all(color: Colors.white.withAlpha(80), width: 2),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
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
                        color: _kGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.videocam_rounded,
                          color: Colors.black, size: 14),
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
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: Colors.white.withAlpha(40)),
                      ),
                      child: Text('REPLAY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                          letterSpacing: 1,
                        )),
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
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _InfoRow('Compétition', match.competition),
          Divider(height: 1, color: _kBorder),
          _InfoRow('Statut', _statusLabel(match.status)),
          if (match.score1 != null) ...[
            Divider(height: 1, color: _kBorder),
            _InfoRow('Score',
                '${match.score1} – ${match.score2}',
                valueColor: _kGold),
          ],
        ],
      ),
    );
  }

  String _statusLabel(MatchStatus s) {
    switch (s) {
      case MatchStatus.live:     return 'En direct 🔴';
      case MatchStatus.finished: return 'Terminé';
      case MatchStatus.upcoming: return 'À venir';
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
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: _kGrey)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.white70)),
        ],
      ),
    );
  }
}

// ── STATS ─────────────────────────────────────────────────────────────────────
class _StatsBlock extends StatelessWidget {
  final MatchModel match;
  const _StatsBlock({required this.match});

  @override
  Widget build(BuildContext context) {
    final s = match.stats!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATISTIQUES',
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _kGrey, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _StatBar(
            label: 'Possession',
            v1: (s['possession1'] as int? ?? 50).toDouble(),
            v2: (s['possession2'] as int? ?? 50).toDouble(),
            isPercent: true,
          ),
          const SizedBox(height: 14),
          _StatBar(
            label: 'Tirs',
            v1: (s['tirs1'] as int? ?? 0).toDouble(),
            v2: (s['tirs2'] as int? ?? 0).toDouble(),
          ),
          const SizedBox(height: 14),
          _StatBar(
            label: 'Passes',
            v1: (s['passes1'] as int? ?? 0).toDouble(),
            v2: (s['passes2'] as int? ?? 0).toDouble(),
          ),
          const SizedBox(height: 14),
          _StatBar(
            label: 'Corners',
            v1: (s['corners1'] as int? ?? 0).toDouble(),
            v2: (s['corners2'] as int? ?? 0).toDouble(),
          ),
          const SizedBox(height: 14),
          _StatBar(
            label: 'Fautes',
            v1: (s['fautes1'] as int? ?? 0).toDouble(),
            v2: (s['fautes2'] as int? ?? 0).toDouble(),
          ),
        ],
      ),
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
    final total  = v1 + v2;
    final ratio1 = total == 0 ? 0.5 : v1 / total;
    final ratio2 = 1.0 - ratio1;

    return Column(
      children: [
        Row(
          children: [
            Text(
              isPercent ? '${v1.toInt()}%' : v1.toInt().toString(),
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: _kGold),
            ),
            const Spacer(),
            Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: _kGrey, letterSpacing: 1)),
            const Spacer(),
            Text(
              isPercent ? '${v2.toInt()}%' : v2.toInt().toString(),
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Colors.white54),
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
                child: Container(height: 4, color: _kGold),
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

// ── FAITS DE JEU ─────────────────────────────────────────────────────────────
class _EventsTab extends StatelessWidget {
  final MatchModel match;
  const _EventsTab({required this.match});

  static const _mockEvents = [
    _GameEvent(minute: 12, type: 'goal',   player: 'M. Dupont',  team: 0),
    _GameEvent(minute: 34, type: 'yellow', player: 'A. Berger',  team: 1),
    _GameEvent(minute: 56, type: 'goal',   player: 'K. Lambert', team: 0),
    _GameEvent(minute: 67, type: 'goal',   player: 'P. Martin',  team: 1),
    _GameEvent(minute: 78, type: 'red',    player: 'S. Blanc',   team: 1),
    _GameEvent(minute: 89, type: 'goal',   player: 'L. Simon',   team: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _mockEvents.length,
      itemBuilder: (_, i) => _EventRow(event: _mockEvents[i], match: match),
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
    final icon  = _eventIcon(event.type);
    final color = _eventColor(event.type);

    return Expanded(
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: alignRight
            ? [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Flexible(child: Text(event.player,
                    style: GoogleFonts.inter(fontSize: 13, color: _kGrey),
                    overflow: TextOverflow.ellipsis)),
              ]
            : [
                Flexible(child: Text(event.player,
                    style: GoogleFonts.inter(fontSize: 13, color: _kGrey),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 16),
              ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'goal':   return Icons.sports_soccer_rounded;
      case 'yellow': return Icons.crop_portrait_rounded;
      case 'red':    return Icons.crop_portrait_rounded;
      default:       return Icons.swap_horiz;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'goal':   return _kGold;
      case 'yellow': return const Color(0xFFFFC107);
      case 'red':    return _kRed;
      default:       return _kGrey;
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
        color: _kCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        "$minute'",
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey),
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
    required this.minute, required this.type,
    required this.player, required this.team});
}

// ── COMPO ─────────────────────────────────────────────────────────────────────
class _CompoTab extends StatelessWidget {
  final MatchModel match;
  const _CompoTab({required this.match});

  static const _team1Players = [
    '1 · Gardien — J. Moreau',   '2 · Défenseur — T. Petit',
    '5 · Défenseur — A. Blanc',  '4 · Défenseur — C. Noir',
    '3 · Défenseur — P. Gris',   '8 · Milieu — M. Dupont',
    '6 · Milieu — K. Lambert',   '10 · Milieu — L. Simon',
    '7 · Attaquant — S. Rouge',  '9 · Attaquant — B. Verte',
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
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(teamName.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 1)),
          ),
          Divider(height: 1, color: _kBorder),
          ...players.asMap().entries.map((e) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Text(e.value,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70)),
              ),
              if (e.key < players.length - 1)
                Divider(height: 1, color: _kBorder, indent: 14),
            ],
          )),
        ],
      ),
    );
  }
}
