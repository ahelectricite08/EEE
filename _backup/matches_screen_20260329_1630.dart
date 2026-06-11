import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import '../models/video_model.dart';
import '../services/match_service.dart';
import '../services/user_service.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';
import 'video_web_screen.dart';

const _kRed   = Color(0xFFBA203C);
const _kGreen = Color(0xFF0A4438);
const _kBg    = Color(0xFF0D1814);
const _kCard  = Color(0xFF142019);
const _kBorder= Color(0xFF1C2E26);
const _kGrey  = Color(0xFF888896);

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});
  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: _kGreen,
            elevation: 0,
            titleSpacing: 0,
            toolbarHeight: 52,
            // Titre visible quand la photo est scrollée
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('RÉSULTATS',
                    style: GoogleFonts.permanentMarker(
                      fontSize: 24,
                      color: Colors.white,
                    )),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('CSSA', style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            // Photo hero
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/terrain.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(-1.0, 0.0),
                    errorBuilder: (_, __, ___) => Container(
                      color: _kGreen,
                      child: Center(child: Icon(Icons.emoji_events_rounded,
                          size: 48, color: _kRed.withAlpha(80))),
                    ),
                  ),
                  // Gradient haut
                  Positioned.fill(child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.center,
                        colors: [Colors.black.withAlpha(160), Colors.transparent],
                      ),
                    ),
                  )),
                  // Gradient bas
                  Positioned.fill(child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black.withAlpha(230), Colors.transparent],
                        stops: const [0.0, 0.55],
                      ),
                    ),
                  )),
                ],
              ),
            ),
            // TabBar pincé en bas
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: Container(
                color: _kBg,
                child: Column(
                  children: [
                    Container(height: 1, color: _kBorder),
                    TabBar(
                      controller: _tab,
                      indicatorColor: _kGreen,
                      indicatorWeight: 2,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1,
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1,
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFF666666),
                      tabs: const [
                        Tab(text: 'À VENIR'),
                        Tab(text: 'RÉSULTATS'),
                        Tab(text: 'CLASSEMENT'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _UpcomingTab(),
            _ResultsTab(),
            _RankingTab(),
          ],
        ),
      ),
    );
  }
}

// ── À VENIR ───────────────────────────────────────────────────────────────────
class _UpcomingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: MatchService.upcoming(),
      builder: (context, snap) {
        final matches = snap.hasData && snap.data!.isNotEmpty
            ? snap.data!
            : MatchModel.mockUpcoming;

        // group by date
        final groups = <DateTime, List<MatchModel>>{};
        for (final m in matches) {
          final day = DateTime(m.date.year, m.date.month, m.date.day);
          groups.putIfAbsent(day, () => []).add(m);
        }
        final days = groups.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final dayMatches = groups[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MatchDateHeader(date: day),
                ...dayMatches.map((m) => MatchCard(
                  match: m,
                  greenHeader: true,
                  onTap: () => _openDetail(context, m),
                )),
              ],
            );
          },
        );
      },
    );
  }

  void _openDetail(BuildContext context, MatchModel match) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
    );
  }
}

// ── RÉSULTATS ─────────────────────────────────────────────────────────────────
class _ResultsTab extends StatefulWidget {
  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.canModerate().then((v) { if (mounted) setState(() => _isAdmin = v); });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: MatchService.results(),
      builder: (context, snap) {
        final matches = snap.hasData && snap.data!.isNotEmpty
            ? snap.data!
            : MatchModel.mockResults;

        final groups = <DateTime, List<MatchModel>>{};
        for (final m in matches) {
          final day = DateTime(m.date.year, m.date.month, m.date.day);
          groups.putIfAbsent(day, () => []).add(m);
        }
        final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final dayMatches = groups[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MatchDateHeader(date: day),
                ...dayMatches.map((m) => GestureDetector(
                  onLongPress: _isAdmin ? () => _editReplay(context, m) : null,
                  child: MatchCard(
                    match: m,
                    greenHeader: true,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => MatchDetailScreen(match: m))),
                    onReplay: m.replayVideoId != null
                        ? () => _openReplay(context, m)
                        : null,
                  ),
                )),
              ],
            );
          },
        );
      },
    );
  }

  void _openReplay(BuildContext context, MatchModel match) {
    final video = VideoModel(
      id: match.id,
      title: '${match.team1} - ${match.team2}',
      youtubeId: match.replayVideoId!,
      duration: '',
      date: match.date,
      category: 'resume',
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoWebScreen(video: video)));
  }

  void _editReplay(BuildContext context, MatchModel match) {
    final ctrl = TextEditingController(text: match.replayVideoId ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: Text('Lien replay', style: GoogleFonts.inter(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'URL ou ID YouTube',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333))),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _kRed)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final raw = ctrl.text.trim();
              final id = _extractYoutubeId(raw);
              if (id != null) {
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(match.id)
                    .update({'replayVideoId': id});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Replay enregistré ✓'), backgroundColor: const Color(0xFF333333)));
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Enregistrer', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }

  String? _extractYoutubeId(String input) {
    if (input.isEmpty) return null;
    // Paramètre v= dans l'URL
    final uri = Uri.tryParse(input);
    if (uri != null && uri.queryParameters['v'] != null) {
      return uri.queryParameters['v'];
    }
    // youtu.be/XXXXX
    if (input.contains('youtu.be/')) {
      return input.split('youtu.be/').last.split('?').first.trim();
    }
    // /shorts/XXXXX
    if (input.contains('/shorts/')) {
      return input.split('/shorts/').last.split('?').first.trim();
    }
    // ID direct — tout ce qui reste (on fait confiance à l'admin)
    return input.trim();
  }
}

// ── CLASSEMENT ────────────────────────────────────────────────────────────────
const _kSeasons = ['2025-2026', '2026-2027'];

class _RankingTab extends StatefulWidget {
  const _RankingTab();
  @override
  State<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<_RankingTab> {
  String _season = '2025-2026';

  static final _mock = [
    _RankEntry('1',  'SEDAN ARDENNES CS',    19, 14,3,2, 46, 8, 45, 'VVVNV'),
    _RankEntry('2',  'Sarreguemines FC',     19,  9,5,5, 31,22, 32, 'NVVNV'),
    _RankEntry('3',  'Amnéville CSO',        19,  9,4,6, 28,24, 31, 'VDVNV'),
    _RankEntry('4',  'AS Cheminots Metz',    19,  8,5,6, 29,26, 29, 'NVDVN'),
    _RankEntry('5',  'FC Saint-Avold',       19,  7,5,7, 27,28, 26, 'VDNVD'),
    _RankEntry('6',  'Forbach FC',           19,  7,4,8, 24,27, 25, 'NNVDN'),
    _RankEntry('7',  'CS Obernai',           19,  7,3,9, 22,29, 24, 'DNDNV'),
    _RankEntry('8',  'Laxou FC',             19,  6,5,8, 20,27, 23, 'DVDDN'),
    _RankEntry('9',  'AS Yutz',              19,  5,7,7, 23,28, 22, 'DNDDD'),
    _RankEntry('10', 'Metz Handball',        19,  5,5,9, 18,30, 20, 'DDDND'),
    _RankEntry('11', 'Thionville FC',        19,  5,4,10,17,32, 19, 'DDDND'),
    _RankEntry('12', 'Épinal AS',            19,  4,5,10,16,33, 17, 'DDDDD'),
    _RankEntry('13', 'Haguenau FC',          19,  3,4,12,14,38, 13, 'DDDDD'),
    _RankEntry('14', 'Lingolsheim SC',       19,  2,2,15,10,44,  8, 'DDDDD'),
  ];

  String? _zone(int pos, int total) {
    if (pos == 1) return 'barrage';
    if (pos >= total - 1) return 'relegation';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Sélecteur de saison ──────────────────────────────────────────
        Container(
          color: _kBg,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: _kSeasons.map((s) {
              final selected = s == _season;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _season = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? _kRed.withAlpha(20) : Colors.transparent,
                      border: Border.all(
                        color: selected ? _kRed : _kBorder,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? _kRed : _kGrey,
                      )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // ── Classement ──────────────────────────────────────────────────
        _LeagueLabel(season: _season),
        _RankingHeader(),
        _ZoneLegend(season: _season),
        Expanded(
          child: FutureBuilder<Map<String, String>>(
            // Construit un map teamName → logo depuis les matchs de la saison
            future: FirebaseFirestore.instance.collection('matches').get().then((snap) {
              final map = <String, String>{};
              for (final doc in snap.docs) {
                final d = doc.data();
                if (d['team1'] != null && d['logo1'] != null) map[d['team1']] = d['logo1'];
                if (d['team2'] != null && d['logo2'] != null) map[d['team2']] = d['logo2'];
              }
              return map;
            }),
            builder: (context, logoSnap) {
              final logoMap = logoSnap.data ?? {};
              return StreamBuilder<QuerySnapshot>(
                stream: _season == '2025-2026'
                    ? FirebaseFirestore.instance.collection('ranking').snapshots()
                    : FirebaseFirestore.instance
                        .collection('ranking')
                        .where('season', isEqualTo: _season)
                        .snapshots(),
                builder: (context, snap) {
                  final List<_RankEntry> entries;
                  if (snap.hasData && snap.data!.docs.isNotEmpty) {
                    // Filtre côté client : exclut les docs d'autres saisons
                    final filtered = snap.data!.docs.where((d) {
                      final s = (d.data() as Map)['season'] as String?;
                      return s == null || s == _season;
                    }).toList()
                      ..sort((a, b) {
                        final pa = (a.data() as Map)['position'] as int? ?? 99;
                        final pb = (b.data() as Map)['position'] as int? ?? 99;
                        return pa.compareTo(pb);
                      });
                    final sorted = filtered;
                    entries = sorted.map((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final team = m['team'] as String? ?? '';
                      final logo = m['logo'] as String? ?? logoMap[team];
                      return _RankEntry(
                        '${m['position'] ?? 0}', team,
                        m['mj'] ?? 0, m['v'] ?? 0, m['n'] ?? 0, m['d'] ?? 0,
                        m['bf'] ?? 0, m['bc'] ?? 0, m['pts'] ?? 0,
                        m['forme'] ?? '',
                        logo: logo,
                      );
                    }).toList();
                  } else if (snap.connectionState == ConnectionState.waiting) {
                    entries = [];
                  } else {
                    entries = _season == '2025-2026' ? _mock : [];
                  }

                  if (entries.isEmpty) {
                    return Center(
                      child: Text('Aucun classement pour $_season',
                        style: GoogleFonts.inter(color: _kGrey, fontSize: 14)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _RankingRow(
                      entry: entries[i],
                      isCSSA: entries[i].team.toUpperCase().contains('SEDAN ARDENNES') ||
                              entries[i].team.toUpperCase().contains('CSSA'),
                      zone: _zone(int.tryParse(entries[i].pos) ?? 99, entries.length),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeagueLabel extends StatelessWidget {
  final String season;
  const _LeagueLabel({required this.season});

  // Nom de la compétition par saison (mis à jour manuellement si besoin)
  static const _compNames = {
    '2025-2026': 'Régional 1 · Grand Est',
    '2026-2027': '— · Grand Est',
  };

  @override
  Widget build(BuildContext context) {
    // Pour la journée : lit competition/{season}, fallback sur competition/meta
    final docId = season == '2025-2026' ? 'meta' : season;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: _kBg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: Text(_compNames[season] ?? 'Grand Est',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: _kGrey)),
          ),
          const Spacer(),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('competition').doc(docId).snapshots(),
            builder: (context, snap) {
              final j = snap.data?.data() != null
                  ? (snap.data!.data() as Map)['journee'] ?? ''
                  : '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kBorder, width: 1),
                ),
                child: Text(j != '' ? 'J$j' : '—',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: _kGrey,
                    fontWeight: FontWeight.w600)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ZoneLegend extends StatelessWidget {
  final String season;
  const _ZoneLegend({required this.season});

  @override
  Widget build(BuildContext context) {
    final topLabel = 'Barrage';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _LegendDot(color: const Color(0xFF6B9E6B), label: topLabel),
          const SizedBox(width: 16),
          _LegendDot(color: const Color(0xFFAA3A3A), label: 'Relégation'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(
            fontSize: 11, color: _kGrey)),
      ],
    );
  }
}

class _RankingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: _kGrey, letterSpacing: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _kBg,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('#', style: s)),
          const SizedBox(width: 8),
          Expanded(child: Text('ÉQUIPE', style: s)),
          SizedBox(width: 28, child: Center(child: Text('MJ', style: s))),
          SizedBox(width: 28, child: Center(child: Text('V', style: s))),
          SizedBox(width: 28, child: Center(child: Text('N', style: s))),
          SizedBox(width: 28, child: Center(child: Text('D', style: s))),
          SizedBox(width: 34, child: Center(child: Text('DIFF', style: s))),
          SizedBox(width: 34, child: Center(
            child: Text('PTS', style: s.copyWith(color: _kRed)))),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final _RankEntry entry;
  final bool isCSSA;
  final String? zone;

  const _RankingRow({required this.entry, this.isCSSA = false, this.zone});

  @override
  Widget build(BuildContext context) {
    final pos     = int.tryParse(entry.pos) ?? 99;
    final diff    = entry.bf - entry.bc;
    final diffStr = diff > 0 ? '+$diff' : '$diff';

    final Color? zoneColor = zone == 'barrage'
        ? const Color(0xFF6B9E6B)
        : zone == 'relegation' ? const Color(0xFFAA3A3A) : null;

    return Container(
      decoration: BoxDecoration(
        color: isCSSA ? _kRed.withAlpha(15) : Colors.transparent,
        border: Border(
          left: BorderSide(color: zoneColor ?? Colors.transparent, width: 3),
          bottom: BorderSide(color: _kBorder, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 28,
            child: pos <= 3
                ? _MedalIcon(pos: pos)
                : Center(child: Text(entry.pos,
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _kGrey)))),
          const SizedBox(width: 6),
          // Initiales
          _TeamInitials(name: entry.team, isCSSA: isCSSA, logo: entry.logo),
          const SizedBox(width: 8),
          // Nom
          Expanded(child: Text(entry.team,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isCSSA ? FontWeight.w800 : FontWeight.w500,
              color: isCSSA ? Colors.white : _kGrey),
            overflow: TextOverflow.ellipsis,
            maxLines: 1)),
          // Stats
          SizedBox(width: 26, child: _Stat(entry.mj.toString())),
          SizedBox(width: 26, child: _Stat(entry.v.toString(),
              color: entry.v > 0 ? const Color(0xFF6B9E6B) : null)),
          SizedBox(width: 26, child: _Stat(entry.n.toString())),
          SizedBox(width: 26, child: _Stat(entry.d.toString(),
              color: entry.d > 0 ? _kRed.withAlpha(200) : null)),
          SizedBox(width: 36, child: _Stat(diffStr,
              color: diff > 0 ? const Color(0xFF6B9E6B)
                  : diff < 0 ? _kRed.withAlpha(200) : null)),
          // Points — badge rouge si CSSA
          SizedBox(width: 32,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isCSSA ? 6 : 0, vertical: isCSSA ? 3 : 0),
                decoration: isCSSA ? BoxDecoration(
                  color: _kRed, borderRadius: BorderRadius.circular(4)) : null,
                child: Text(entry.pts.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: isCSSA ? Colors.white : Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalIcon extends StatelessWidget {
  final int pos;
  const _MedalIcon({required this.pos});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFB8B8B8),
      const Color(0xFFCD7F32),
    ];
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: colors[pos - 1].withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: colors[pos - 1].withAlpha(120), width: 1),
      ),
      child: Center(
        child: Text(
          '$pos',
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: colors[pos - 1],
          ),
        ),
      ),
    );
  }
}

class _TeamInitials extends StatelessWidget {
  final String name;
  final bool isCSSA;
  final String? logo;
  const _TeamInitials({required this.name, this.isCSSA = false, this.logo});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, name.length.clamp(0, 2));
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: logo != null ? _kCard : (isCSSA ? _kRed.withAlpha(20) : _kBg),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: logo != null ? _kBorder : (isCSSA ? _kRed.withAlpha(80) : _kBorder),
          width: 1,
        ),
      ),
      child: logo != null
          ? Padding(
              padding: const EdgeInsets.all(2),
              child: Image.network(logo!, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(child: Text(initials.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10,
                    fontWeight: FontWeight.w700, color: Colors.white38)))),
            )
          : Center(
              child: Text(initials.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isCSSA ? _kRed : _kGrey)),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final Color? color;
  const _Stat(this.value, {this.color});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: color ?? _kGrey,
        ),
      ),
    );
  }
}

class _RankEntry {
  final String pos, team, forme;
  final String? logo;
  final int mj, v, n, d, bf, bc, pts;
  _RankEntry(this.pos, this.team, this.mj, this.v, this.n, this.d,
      this.bf, this.bc, this.pts, this.forme, {this.logo});
}
