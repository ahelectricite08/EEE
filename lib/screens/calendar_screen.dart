import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';

const _kRed   = Color(0xFFBA203C);
const _kGreen = Color(0xFF0A4438);
const _kCard  = Color(0xFF141414);
const _kBorder= Color(0xFF1C1C1C);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focus = DateTime.now();
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'CALENDRIER',
          style: GoogleFonts.oswald(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: StreamBuilder<List<MatchModel>>(
        stream: MatchService.forMonth(_focus.year, _focus.month),
        builder: (context, snap) {
          final matches = snap.hasData && snap.data!.isNotEmpty
              ? snap.data!
              : _mockForMonth(_focus);

          final matchDays = <int>{};
          for (final m in matches) {
            if (m.date.month == _focus.month) {
              matchDays.add(m.date.day);
            }
          }

          // Selected day matches
          List<MatchModel> dayMatches = [];
          if (_selected != null) {
            dayMatches = matches.where((m) =>
                m.date.year == _selected!.year &&
                m.date.month == _selected!.month &&
                m.date.day == _selected!.day).toList();
          }

          return Column(
            children: [
              // Month navigator
              _MonthHeader(
                focus: _focus,
                onPrev: () => setState(() {
                  _focus = DateTime(_focus.year, _focus.month - 1);
                  _selected = null;
                }),
                onNext: () => setState(() {
                  _focus = DateTime(_focus.year, _focus.month + 1);
                  _selected = null;
                }),
              ),
              // Day-of-week labels
              _WeekDayLabels(),
              // Calendar grid
              _CalendarGrid(
                focus: _focus,
                matchDays: matchDays,
                selected: _selected,
                onDayTap: (day) => setState(() {
                  _selected = day;
                }),
              ),
              Container(height: 1, color: _kBorder),
              // Match list for selected day
              Expanded(
                child: _selected == null
                    ? _AllMatchesList(matches: matches, focus: _focus)
                    : _DayMatchesList(matches: dayMatches, day: _selected!),
              ),
            ],
          );
        },
      ),
    );
  }

  List<MatchModel> _mockForMonth(DateTime focus) {
    final all = [...MatchModel.mockUpcoming, ...MatchModel.mockResults];
    return all
        .where((m) => m.date.month == focus.month && m.date.year == focus.year)
        .toList();
  }
}

// ── Month navigator ───────────────────────────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  final DateTime focus;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader(
      {required this.focus, required this.onPrev, required this.onNext});

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPrev,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_months[focus.month - 1]} ${focus.year}',
                style: GoogleFonts.oswald(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onNext,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week day labels ───────────────────────────────────────────────────────────
class _WeekDayLabels extends StatelessWidget {
  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _days.map((d) => Expanded(
          child: Center(
            child: Text(
              d.toUpperCase(),
              style: GoogleFonts.oswald(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF555555),
                letterSpacing: 0.5,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focus;
  final Set<int> matchDays;
  final DateTime? selected;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.focus,
    required this.matchDays,
    required this.selected,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focus.year, focus.month, 1);
    // Monday=1, so offset to Mon start grid
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(focus.year, focus.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - startOffset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final date = DateTime(focus.year, focus.month, dayNum);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = selected != null &&
                  date.year == selected!.year &&
                  date.month == selected!.month &&
                  date.day == selected!.day;
              final hasMatch = matchDays.contains(dayNum);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTap(date),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kRed
                          : isToday
                              ? _kRed.withOpacity(0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: GoogleFonts.barlow(
                            fontSize: 14,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? _kRed
                                    : Colors.white70,
                          ),
                        ),
                        if (hasMatch)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : _kRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (!hasMatch) const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

// ── All matches list (no day selected) ───────────────────────────────────────
class _AllMatchesList extends StatelessWidget {
  final List<MatchModel> matches;
  final DateTime focus;

  const _AllMatchesList({required this.matches, required this.focus});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Text(
          'Aucun match ce mois',
          style: GoogleFonts.barlow(color: Colors.white38, fontSize: 14),
        ),
      );
    }

    final sorted = [...matches]..sort((a, b) => a.date.compareTo(b.date));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sorted.length,
      itemBuilder: (context, i) => MatchCard(
        match: sorted[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MatchDetailScreen(match: sorted[i])),
        ),
      ),
    );
  }
}

// ── Day matches list ──────────────────────────────────────────────────────────
class _DayMatchesList extends StatelessWidget {
  final List<MatchModel> matches;
  final DateTime day;

  const _DayMatchesList({required this.matches, required this.day});

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MatchDateHeader(date: day),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Aucun match ce jour',
              style: GoogleFonts.barlow(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: matches
                  .map((m) => MatchCard(
                        match: m,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MatchDetailScreen(match: m)),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
