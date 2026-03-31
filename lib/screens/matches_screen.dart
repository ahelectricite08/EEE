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
import '../utils/youtube_parser.dart';
import '../theme/app_colors.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: true,
        toolbarHeight: 52,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
              fit: BoxFit.cover,
              alignment: Alignment(0, -0.3),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(140),
                    Colors.black.withAlpha(200),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RÉSULTATS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 2,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(30),
                border: Border.all(color: AppColors.gold, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('DVCR', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppColors.gold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── TabBar (sticky) ────────────────────────────────────────────
          TabBar(
            controller: _tab,
            indicatorColor: AppColors.gold,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.grey,
            tabs: const [
              Tab(text: 'À VENIR'),
              Tab(text: 'RÉSULTATS'),
              Tab(text: 'CLASSEMENT'),
            ],
          ),
          Container(height: 1, color: AppColors.border),
          // ── Tab content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UpcomingTab(),
                _ResultsTab(),
                const _RankingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── DERNIER MATCH card ────────────────────────────────────────────────────────
class _LastMatchCard extends StatefulWidget {
  @override
  State<_LastMatchCard> createState() => _LastMatchCardState();
}

class _LastMatchCardState extends State<_LastMatchCard> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.canModerate().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
  }

  void _editReplayLink(BuildContext context, MatchModel match) {
    final ctrl = TextEditingController(text: match.replayVideoId ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Lien résumé vidéo',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'URL ou ID YouTube',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333))),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.gold)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              final raw = ctrl.text.trim();
              final id = YoutubeParser.extractId(raw);
              if (id != null) {
                await FirebaseFirestore.instance
                    .collection('matches').doc(match.id)
                    .update({'replayVideoId': id});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Lien enregistré ✓'),
                    backgroundColor: Color(0xFF333333)));
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Enregistrer', style: TextStyle(color: AppColors.gold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: MatchService.results(),
      builder: (context, snap) {
        final matches = snap.hasData && snap.data!.isNotEmpty
            ? snap.data!
            : MatchModel.mockResults;
        // Uniquement les matchs de Sedan
        final sedanMatches = matches.where((m) =>
          m.team1.toUpperCase().contains('SEDAN') ||
          m.team1.toUpperCase().contains('CSSA') ||
          m.team2.toUpperCase().contains('SEDAN') ||
          m.team2.toUpperCase().contains('CSSA')).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final last = sedanMatches.isNotEmpty ? sedanMatches.first : null;

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              // ── Zone photo + score ─────────────────────────────────────
              Stack(
                children: [
                  Image.asset(
                    'assets/images/att.V2GyXUlbF3n-UWtFB9NYVr72mNoxTxJBBQ2jcWSoJso.JPG',
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.6, -0.5),
                    errorBuilder: (_, __, ___) => Container(height: 120, color: AppColors.card),
                  ),
                  // Dégradé gauche lisibilité
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.black.withAlpha(20),
                            Colors.black.withAlpha(180),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Dégradé bas vers footer sombre
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(200),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: last != null
                              ? () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => MatchDetailScreen(match: last)))
                              : null,
                          child: Row(
                            children: [
                              Text('DERNIER MATCH',
                                style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white70, letterSpacing: 1.5,
                                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (last != null)
                          Row(
                            children: [
                              Expanded(child: _LastMatchTeam(
                                name: last.team1, logo: last.logo1,
                                align: CrossAxisAlignment.start)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '${last.score1 ?? 0} - ${last.score2 ?? 0}',
                                  style: GoogleFonts.inter(
                                    fontSize: 32, fontWeight: FontWeight.w800,
                                    color: Colors.white, height: 1,
                                    shadows: const [Shadow(color: Colors.black, blurRadius: 8)])),
                              ),
                              Expanded(child: _LastMatchTeam(
                                name: last.team2, logo: last.logo2,
                                align: CrossAxisAlignment.end)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // ── Footer sombre avec boutons ─────────────────────────────
              Container(
                color: const Color(0xFF111111),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: last != null
                    ? Row(
                        children: [
                          Expanded(
                            child: _GoldButton(
                              label: last.replayVideoId != null
                                  ? 'VOIR RÉSUMÉ VIDÉO'
                                  : _isAdmin ? 'AJOUTER VIDÉO' : 'RÉSUMÉ VIDÉO',
                              icon: last.replayVideoId != null
                                  ? Icons.chevron_right
                                  : _isAdmin ? Icons.add : null,
                              onTap: last.replayVideoId != null
                                  ? () {
                                      final video = VideoModel(
                                        id: last.id,
                                        title: '${last.team1} - ${last.team2}',
                                        youtubeId: last.replayVideoId!,
                                        duration: '', date: last.date,
                                        category: 'resume',
                                      );
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => VideoWebScreen(video: video)));
                                    }
                                  : _isAdmin
                                      ? () => _editReplayLink(context, last)
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GoldButton(
                              label: 'VOIR STATS',
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => MatchDetailScreen(match: last))),
                            ),
                          ),
                        ],
                      )
                    : Center(child: Text('Aucun résultat',
                        style: GoogleFonts.inter(color: AppColors.grey, fontSize: 13))),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _GoldButton({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.gold, letterSpacing: 0.5)),
            if (icon != null) ...[
              const SizedBox(width: 2),
              Icon(icon, color: AppColors.gold, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _LastMatchTeam extends StatelessWidget {
  final String name;
  final String? logo;
  final CrossAxisAlignment align;
  const _LastMatchTeam({required this.name, this.logo, required this.align});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: logo != null
              ? Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.network(logo!, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _initials()))
              : _initials(),
        ),
        const SizedBox(height: 6),
        Text(name,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          textAlign: align == CrossAxisAlignment.start
              ? TextAlign.left : TextAlign.right),
      ],
    );
  }

  Widget _initials() {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, name.length.clamp(0, 2));
    return Center(
      child: Text(initials.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white38)));
  }
}

// ── À VENIR ───────────────────────────────────────────────────────────────────
class _UpcomingTab extends StatefulWidget {
  @override
  State<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<_UpcomingTab> {
  DateTime? _selectedDate;
  String? _selectedComp;
  String? _selectedTeam;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: MatchService.allUpcoming(),
      builder: (context, snap) {
        final allMatches = snap.hasData && snap.data!.isNotEmpty
            ? snap.data!
            : MatchModel.mockAllUpcoming;

        // Compétitions et équipes disponibles
        final comps = allMatches.map((m) => m.competition).toSet().toList()..sort();
        final teams = allMatches
            .expand((m) => [m.team1, m.team2])
            .toSet().toList()..sort();

        // Filtrage
        var filtered = allMatches.where((m) {
          if (_selectedComp != null && m.competition != _selectedComp) return false;
          if (_selectedTeam != null &&
              m.team1 != _selectedTeam && m.team2 != _selectedTeam) return false;
          if (_selectedDate != null) {
            final d = _selectedDate!;
            return m.date.year == d.year &&
                   m.date.month == d.month &&
                   m.date.day == d.day;
          }
          return true;
        }).toList()..sort((a, b) => a.date.compareTo(b.date));

        // Group by date
        final groups = <DateTime, List<MatchModel>>{};
        for (final m in filtered) {
          final day = DateTime(m.date.year, m.date.month, m.date.day);
          groups.putIfAbsent(day, () => []).add(m);
        }
        final days = groups.keys.toList()..sort();

        return filtered.isEmpty
            ? Column(
                children: [
                  _CalendarStrip(
                    matches: allMatches,
                    selectedDate: _selectedDate,
                    onDateSelected: (d) => setState(() {
                      _selectedDate = (_selectedDate?.year == d.year &&
                          _selectedDate?.month == d.month &&
                          _selectedDate?.day == d.day) ? null : d;
                    }),
                  ),
                  _FilterRow(
                    competitions: comps,
                    teams: teams,
                    selectedComp: _selectedComp,
                    selectedTeam: _selectedTeam,
                    onCompChanged: (v) => setState(() => _selectedComp = v),
                    onTeamChanged: (v) => setState(() => _selectedTeam = v),
                  ),
                  Container(height: 1, color: AppColors.border),
                  Expanded(
                    child: _NoMatchMessage(
                      allMatches: allMatches,
                      selectedDate: _selectedDate,
                      onJumpToDate: (d) => setState(() => _selectedDate = d),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // Calendrier et filtres scrollent avec la liste
                  _CalendarStrip(
                    matches: allMatches,
                    selectedDate: _selectedDate,
                    onDateSelected: (d) => setState(() {
                      _selectedDate = (_selectedDate?.year == d.year &&
                          _selectedDate?.month == d.month &&
                          _selectedDate?.day == d.day) ? null : d;
                    }),
                  ),
                  _FilterRow(
                    competitions: comps,
                    teams: teams,
                    selectedComp: _selectedComp,
                    selectedTeam: _selectedTeam,
                    onCompChanged: (v) => setState(() => _selectedComp = v),
                    onTeamChanged: (v) => setState(() => _selectedTeam = v),
                  ),
                  Container(height: 1, color: AppColors.border),
                  ...days.expand((day) {
                    final dayMatches = groups[day]!;
                    return [
                      _MatchSectionHeader(date: day),
                      ...dayMatches.map((m) => MatchCard(
                        match: m,
                        greenHeader: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => MatchDetailScreen(match: m))),
                      )),
                    ];
                  }),
                ],
              );
      },
    );
  }
}

// ── Message "aucun match ce jour" ────────────────────────────────────────────
class _NoMatchMessage extends StatelessWidget {
  final List<MatchModel> allMatches;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onJumpToDate;

  const _NoMatchMessage({
    required this.allMatches,
    required this.selectedDate,
    required this.onJumpToDate,
  });

  @override
  Widget build(BuildContext context) {
    const months = ['jan','fév','mar','avr','mai','juin',
                    'juil','aoû','sep','oct','nov','déc'];
    const days   = ['lun','mar','mer','jeu','ven','sam','dim'];

    // Prochain match après la date sélectionnée (ou après aujourd'hui)
    final ref = selectedDate ?? DateTime.now();
    final next = allMatches
        .where((m) => m.date.isAfter(ref))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final nextMatch = next.isNotEmpty ? next.first : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, color: AppColors.grey, size: 40),
            const SizedBox(height: 12),
            Text(
              selectedDate != null
                  ? 'Aucun match ce jour'
                  : 'Aucun match à venir',
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            if (nextMatch != null) ...[
              const SizedBox(height: 8),
              Text(
                'Prochain match le ${days[nextMatch.date.weekday - 1]} '
                '${nextMatch.date.day} ${months[nextMatch.date.month - 1]}',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => onJumpToDate(DateTime(
                  nextMatch.date.year,
                  nextMatch.date.month,
                  nextMatch.date.day,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gold, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Voir ce match',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Calendar strip ────────────────────────────────────────────────────────────
class _CalendarStrip extends StatelessWidget {
  final List<MatchModel> matches;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarStrip({
    required this.matches,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    const monthLabels = ['JAN','FÉV','MAR','AVR','MAI','JUIN',
                         'JUIL','AOÛ','SEP','OCT','NOV','DÉC'];
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3));
    final dates = List.generate(21, (i) => startDay.add(Duration(days: i)));

    // Jours ayant un match
    final matchDays = matches.map((m) =>
      DateTime(m.date.year, m.date.month, m.date.day)).toSet();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: AppColors.grey, size: 14),
              const SizedBox(width: 6),
              Text('CALENDRIER',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              itemBuilder: (context, i) {
                final date = dates[i];
                final isSelected = selectedDate != null &&
                    date.year == selectedDate!.year &&
                    date.month == selectedDate!.month &&
                    date.day == selectedDate!.day;
                final hasMatch = matchDays.contains(date);
                final dayLabel = dayLabels[date.weekday - 1];
                final monthLabel = monthLabels[date.month - 1];

                return GestureDetector(
                  onTap: () => onDateSelected(date),
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.gold : AppColors.border, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.black : AppColors.grey)),
                        const SizedBox(height: 2),
                        Text('${date.day}',
                          style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.black : Colors.white)),
                        Text(monthLabel,
                          style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.black54 : AppColors.grey)),
                        if (hasMatch && !isSelected)
                          Container(
                            width: 4, height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.gold, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final List<String> competitions;
  final List<String> teams;
  final String? selectedComp;
  final String? selectedTeam;
  final ValueChanged<String?> onCompChanged;
  final ValueChanged<String?> onTeamChanged;

  const _FilterRow({
    required this.competitions,
    required this.teams,
    required this.selectedComp,
    required this.selectedTeam,
    required this.onCompChanged,
    required this.onTeamChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          _FilterChip(
            label: selectedComp ?? 'Compétition',
            active: selectedComp != null,
            onTap: () => _showPicker(
              context: context,
              title: 'Compétition',
              options: competitions,
              selected: selectedComp,
              onSelected: onCompChanged,
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: selectedTeam ?? 'Équipe',
            active: selectedTeam != null,
            onTap: () => _showPicker(
              context: context,
              title: 'Équipe',
              options: teams,
              selected: selectedTeam,
              onSelected: onTeamChanged,
            ),
          ),
        ],
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(title,
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                const Spacer(),
                if (selected != null)
                  GestureDetector(
                    onTap: () { onSelected(null); Navigator.pop(context); },
                    child: Text('Réinitialiser',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gold))),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: options.map((opt) => ListTile(
                onTap: () { onSelected(opt); Navigator.pop(context); },
                title: Text(opt,
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: opt == selected ? AppColors.gold : Colors.white)),
                trailing: opt == selected
                    ? const Icon(Icons.check, color: AppColors.gold, size: 18)
                    : null,
              )).toList(),
            ),
          ),
          SafeArea(child: const SizedBox(height: 8)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.gold.withAlpha(30) : Colors.transparent,
          border: Border.all(color: active ? AppColors.gold : AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? AppColors.gold : Colors.white70),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down,
              color: active ? AppColors.gold : Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _MatchSectionHeader extends StatelessWidget {
  final DateTime date;
  const _MatchSectionHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    const days   = ['LUNDI','MARDI','MERCREDI','JEUDI','VENDREDI','SAMEDI','DIMANCHE'];
    const months = ['JAN','FÉV','MAR','AVR','MAI','JUIN','JUIL','AOÛ','SEP','OCT','NOV','DÉC'];
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(date.year, date.month, date.day);
    final diff  = day.difference(today).inDays;

    final String label;
    if (diff == 0)       label = "AUJOURD'HUI";
    else if (diff == 1)  label = 'DEMAIN';
    else if (diff == -1) label = 'HIER';
    else label = '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Row(
        children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1)),
        ],
      ),
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
  String? _selectedComp;
  String? _selectedTeam;

  @override
  void initState() {
    super.initState();
    UserService.canModerate().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MatchModel>>(
      stream: MatchService.allResults(),
      builder: (context, snap) {
        final allMatches = snap.hasData && snap.data!.isNotEmpty
            ? snap.data!
            : MatchModel.mockResults;

        final comps = allMatches.map((m) => m.competition).toSet().toList()..sort();
        final teams = allMatches
            .expand((m) => [m.team1, m.team2])
            .toSet().toList()..sort();

        // Filtrage
        final filtered = allMatches.where((m) {
          if (_selectedComp != null && m.competition != _selectedComp) return false;
          if (_selectedTeam != null &&
              m.team1 != _selectedTeam && m.team2 != _selectedTeam) return false;
          return true;
        }).toList();

        final groups = <DateTime, List<MatchModel>>{};
        for (final m in filtered) {
          final day = DateTime(m.date.year, m.date.month, m.date.day);
          groups.putIfAbsent(day, () => []).add(m);
        }
        final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        return filtered.isEmpty
            ? Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        _LastMatchCard(),
                        _FilterRow(
                          competitions: comps,
                          teams: teams,
                          selectedComp: _selectedComp,
                          selectedTeam: _selectedTeam,
                          onCompChanged: (v) => setState(() => _selectedComp = v),
                          onTeamChanged: (v) => setState(() => _selectedTeam = v),
                        ),
                        Container(height: 1, color: AppColors.border),
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(child: Text('Aucun résultat',
                              style: GoogleFonts.inter(color: AppColors.grey, fontSize: 14))),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 0, bottom: 24),
                itemCount: days.length + 1, // +1 pour le header
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(
                      children: [
                        _LastMatchCard(),
                        _FilterRow(
                          competitions: comps,
                          teams: teams,
                          selectedComp: _selectedComp,
                          selectedTeam: _selectedTeam,
                          onCompChanged: (v) => setState(() => _selectedComp = v),
                          onTeamChanged: (v) => setState(() => _selectedTeam = v),
                        ),
                        Container(height: 1, color: AppColors.border),
                      ],
                    );
                  }
                  final day = days[i - 1];
                  final dayMatches = groups[day]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MatchSectionHeader(date: day),
                      ...dayMatches.map((m) => MatchCard(
                        match: m,
                        greenHeader: true,
                        isAdmin: _isAdmin,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => MatchDetailScreen(match: m))),
                        onReplay: m.replayVideoId != null
                            ? () => _openReplay(context, m)
                            : null,
                        onAddReplay: _isAdmin
                            ? () => _editReplay(context, m)
                            : null,
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
      duration: '', date: match.date, category: 'resume',
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoWebScreen(video: video)));
  }

  void _editReplay(BuildContext context, MatchModel match) {
    final ctrl = TextEditingController(text: match.replayVideoId ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
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
              borderSide: BorderSide(color: AppColors.red)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              final raw = ctrl.text.trim();
              final id = YoutubeParser.extractId(raw);
              if (id != null) {
                await FirebaseFirestore.instance
                    .collection('matches').doc(match.id)
                    .update({'replayVideoId': id});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Replay enregistré ✓'),
                    backgroundColor: Color(0xFF333333)));
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Enregistrer', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
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
  late Future<Map<String, String>> _logoMapFuture;

  @override
  void initState() {
    super.initState();
    // On initialise le futur une seule fois pour éviter de re-scanner
    // tous les matchs à chaque build de l'onglet.
    _logoMapFuture = _fetchLogoMap();
  }

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

  Future<Map<String, String>> _fetchLogoMap() async {
    final snap = await FirebaseFirestore.instance.collection('matches').get();
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['team1'] != null && d['logo1'] != null) map[d['team1']] = d['logo1'];
      if (d['team2'] != null && d['logo2'] != null) map[d['team2']] = d['logo2'];
    }
    return map;
  }

  String? _zone(int pos, int total) {
    if (pos == 1) return 'barrage';
    if (pos >= total - 1) return 'relegation';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RankingHeader(),
        Expanded(
          child: FutureBuilder<Map<String, String>>(
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
                    final filtered = snap.data!.docs.where((d) {
                      final s = (d.data() as Map)['season'] as String?;
                      return s == null || s == _season;
                    }).toList()
                      ..sort((a, b) {
                        final pa = (a.data() as Map)['position'] as int? ?? 99;
                        final pb = (b.data() as Map)['position'] as int? ?? 99;
                        return pa.compareTo(pb);
                      });
                    entries = filtered.map((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final team = m['team'] as String? ?? '';
                      final logo = m['logo'] as String? ?? logoMap[team];
                      return _RankEntry(
                        '${m['position'] ?? 0}', team,
                        m['mj'] ?? 0, m['v'] ?? 0, m['n'] ?? 0, m['d'] ?? 0,
                        m['bf'] ?? 0, m['bc'] ?? 0, m['pts'] ?? 0,
                        m['forme'] ?? '', logo: logo,
                      );
                    }).toList();
                  } else if (snap.connectionState == ConnectionState.waiting) {
                    entries = [];
                  } else {
                    entries = _season == '2025-2026' ? _mock : [];
                  }

                  if (entries.isEmpty) {
                    return Center(child: Text('Aucun classement pour $_season',
                      style: GoogleFonts.inter(color: AppColors.grey, fontSize: 14)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: entries.length + 1, // +1 pour le header
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        // Saisons + league + légende scrollent avec la liste
                        return Column(
                          children: [
                            Container(
                              color: AppColors.background,
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
                                          color: selected ? AppColors.gold.withAlpha(20) : Colors.transparent,
                                          border: Border.all(
                                            color: selected ? AppColors.gold : AppColors.border, width: 1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(s,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? AppColors.gold : AppColors.grey)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            _LeagueLabel(season: _season),
                            _ZoneLegend(season: _season),
                          ],
                        );
                      }
                      return _RankingRow(
                        entry: entries[i - 1],
                        isCSSA: entries[i - 1].team.toUpperCase().contains('SEDAN ARDENNES') ||
                                entries[i - 1].team.toUpperCase().contains('CSSA'),
                        zone: _zone(int.tryParse(entries[i - 1].pos) ?? 99, entries.length),
                      );
                    },
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

  static const _compNames = {
    '2025-2026': 'Régional 1 · Grand Est',
    '2026-2027': '— · Grand Est',
  };

  @override
  Widget build(BuildContext context) {
    final docId = season == '2025-2026' ? 'meta' : season;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: AppColors.background,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Text(_compNames[season] ?? 'Grand Est',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.grey)),
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
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(j != '' ? 'J$j' : '—',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.grey, fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _LegendDot(color: const Color(0xFF4CAF70), label: 'Barrage'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.red, label: 'Relégation'),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.grey)),
      ],
    );
  }
}

class _RankingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: AppColors.grey, letterSpacing: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.gold.withAlpha(60)),
        ),
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
            child: Text('PTS', style: s.copyWith(color: AppColors.gold)))),
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
        ? const Color(0xFF4CAF70)
        : zone == 'relegation' ? AppColors.red : null;

    return Container(
      decoration: BoxDecoration(
        color: isCSSA ? AppColors.gold.withAlpha(18) : Colors.transparent,
        border: Border(
          left: BorderSide(color: zoneColor ?? (isCSSA ? AppColors.gold : Colors.transparent), width: 3),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: pos <= 3
                ? _MedalIcon(pos: pos)
                : Center(child: Text(entry.pos,
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.grey)))),
          const SizedBox(width: 6),
          _TeamInitials(name: entry.team, isCSSA: isCSSA, logo: entry.logo),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.team,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isCSSA ? FontWeight.w800 : FontWeight.w500,
              color: isCSSA ? AppColors.gold : AppColors.grey),
            overflow: TextOverflow.ellipsis, maxLines: 1)),
          SizedBox(width: 26, child: _Stat(entry.mj.toString())),
          SizedBox(width: 26, child: _Stat(entry.v.toString(),
              color: entry.v > 0 ? const Color(0xFF6B9E6B) : null)),
          SizedBox(width: 26, child: _Stat(entry.n.toString())),
          SizedBox(width: 26, child: _Stat(entry.d.toString(),
              color: entry.d > 0 ? AppColors.red.withAlpha(200) : null)),
          SizedBox(width: 36, child: _Stat(diffStr,
              color: diff > 0 ? const Color(0xFF6B9E6B)
                  : diff < 0 ? AppColors.red.withAlpha(200) : null)),
          SizedBox(width: 38, child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isCSSA ? 7 : 0, vertical: isCSSA ? 4 : 0),
              decoration: isCSSA ? BoxDecoration(
                color: AppColors.gold, borderRadius: BorderRadius.circular(4)) : null,
              child: Text(entry.pts.toString(),
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: isCSSA ? const Color(0xFF0D0D0D) : Colors.white70),
                maxLines: 1,
              ),
            ),
          )),
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
        color: colors[pos - 1].withAlpha(30), shape: BoxShape.circle,
        border: Border.all(color: colors[pos - 1].withAlpha(120), width: 1)),
      child: Center(child: Text('$pos',
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700, color: colors[pos - 1]))),
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
        color: logo != null ? AppColors.card : (isCSSA ? AppColors.gold.withAlpha(20) : AppColors.background),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: logo != null ? AppColors.border : (isCSSA ? AppColors.gold.withAlpha(120) : AppColors.border),
          width: 1)),
      child: logo != null
          ? Padding(
              padding: const EdgeInsets.all(2),
              child: Image.network(logo!, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(child: Text(initials.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10,
                    fontWeight: FontWeight.w700, color: Colors.white38)))))
          : Center(child: Text(initials.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isCSSA ? AppColors.gold : AppColors.grey))),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final Color? color;
  const _Stat(this.value, {this.color});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(value,
      style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: color ?? AppColors.grey)));
  }
}

class _RankEntry {
  final String pos, team, forme;
  final String? logo;
  final int mj, v, n, d, bf, bc, pts;
  _RankEntry(this.pos, this.team, this.mj, this.v, this.n, this.d,
      this.bf, this.bc, this.pts, this.forme, {this.logo});
}
