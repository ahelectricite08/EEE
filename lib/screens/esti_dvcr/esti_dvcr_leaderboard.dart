import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/dvcr_share_service.dart';
import '../../services/esti_dvcr_league_service.dart';
import '../../services/tournament_service.dart';
import '../../utils/share_helper.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kEstiTeal = Color(0xFF0A4438);
const _kEstiRed = Color(0xFFBA203C);
const _kEstiGold = Color(0xFFC8A436);
const _kEstiSurface = Color(0xFF0D3D32);
const _kEstiMuted = Color(0xFF7AADA0);

/// Sentinelles
const _kFinaleDay = -1;
const _kTopLiguesDay = -2;

class EstiDvcrLeaderboard extends StatefulWidget {
  final String tournamentId;
  const EstiDvcrLeaderboard({super.key, required this.tournamentId});

  @override
  State<EstiDvcrLeaderboard> createState() => _EstiDvcrLeaderboardState();
}

class _EstiDvcrLeaderboardState extends State<EstiDvcrLeaderboard> {
  int _selectedDay = 0; // 0 = général, -1 = phase finale, >0 = journée
  String? _selectedLeagueId; // non-null = classement ligue

  // Journées détectées dynamiquement via Stream (se met à jour si l'admin ajoute des matchs)
  List<int> _availableDays = [];
  bool _hasFinale = false;
  StreamSubscription<({List<int> days, bool hasFinale})>? _daysSub;

  @override
  void initState() {
    super.initState();
    _daysSub = TournamentService.availableMatchDaysPhasesStream(widget.tournamentId)
        .listen((result) {
      if (mounted) {
        setState(() {
          _availableDays = result.days;
          _hasFinale = result.hasFinale;
        });
      }
    });
  }

  @override
  void dispose() {
    _daysSub?.cancel();
    super.dispose();
  }

  void _selectDay(int day) => setState(() {
        _selectedDay = day;
        _selectedLeagueId = null;
      });

  void _selectLeague(String leagueId) => setState(() {
        _selectedLeagueId = leagueId;
        _selectedDay = -99; // sentinel "ligue active"
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EstiDvcrLeague>>(
      stream: EstiDvcrLeagueService.myLeaguesStream(),
      builder: (context, leaguesSnap) {
        final myLeagues = leaguesSnap.data ?? [];

        // Chips journées — uniquement les jours qui ont des matchs dans Firestore
        final dayChips = <({int day, String label})>[
          (day: 0, label: 'GÉNÉRAL'),
          for (final d in _availableDays) (day: d, label: 'J$d'),
          if (_hasFinale) (day: _kFinaleDay, label: 'PHASE FINALE'),
          (day: _kTopLiguesDay, label: 'TOP LIGUES'),
        ];

        return Column(
          children: [
            // ── Sélecteur journée ────────────────────────────────────────
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: dayChips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final chip = dayChips[i];
                  final selected = _selectedLeagueId == null && _selectedDay == chip.day;
                  final isFinale = chip.day == _kFinaleDay;
                  final isLigues = chip.day == _kTopLiguesDay;
                  final chipColor = isLigues || isFinale ? _kEstiGold : _kEstiRed;
                  return GestureDetector(
                    onTap: () => _selectDay(chip.day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? chipColor : _kEstiSurface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? chipColor
                              : (isFinale || isLigues)
                                  ? _kEstiGold.withAlpha(60)
                                  : Colors.white.withAlpha(25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          chip.label,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : (isFinale || isLigues)
                                    ? _kEstiGold
                                    : _kEstiMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Contenu classement + Top ligues ──────────────────────────
            Expanded(
              child: _selectedLeagueId != null
                  ? _LeagueLeaderboard(
                      tournamentId: widget.tournamentId,
                      leagueId: _selectedLeagueId!,
                      onBack: () => setState(() => _selectedLeagueId = null),
                    )
                  : _selectedDay == _kTopLiguesDay
                      ? _TopLiguesSectionFull(
                          tournamentId: widget.tournamentId,
                          myLeagues: myLeagues,
                        )
                      : _ClassementWithLeagues(
                          tournamentId: widget.tournamentId,
                          selectedDay: _selectedDay,
                          myLeagues: myLeagues,
                          onSelectLeague: _selectLeague,
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Vue classement ────────────────────────────────────────────────────────────
class _ClassementWithLeagues extends StatelessWidget {
  final String tournamentId;
  final int selectedDay;
  final List<EstiDvcrLeague> myLeagues;
  final ValueChanged<String> onSelectLeague;

  const _ClassementWithLeagues({
    required this.tournamentId,
    required this.selectedDay,
    required this.myLeagues,
    required this.onSelectLeague,
  });

  @override
  Widget build(BuildContext context) {
    // Leaderboard principal (général / journée / finale)
    Stream<List<TournamentEntry>> mainStream;
    if (selectedDay == 0) {
      mainStream = TournamentService.leaderboardTopStream(tournamentId, limit: 100);
    } else if (selectedDay == _kFinaleDay) {
      mainStream = TournamentService.leaderboardFinaleStream(tournamentId);
    } else {
      mainStream = TournamentService.leaderboardByMatchDayStream(tournamentId, selectedDay);
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<TournamentEntry>>(
      stream: mainStream,
      builder: (ctx, snap) {
        final entries = snap.data ?? [];

        // Trouver le rang de l'utilisateur
        final myIdx = myUid != null
            ? entries.indexWhere((e) => e.uid == myUid)
            : -1;
        final myEntry = myIdx >= 0 ? entries[myIdx] : null;
        final myRank = myIdx >= 0 ? myIdx + 1 : null;

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Classement principal ──────────────────────────────
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: _kEstiGold)),
                  )
                else if (entries.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: const _EmptyLeaderboard(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _LeaderboardRow(
                          entry: entries[i],
                          rank: i + 1,
                          isMe: entries[i].uid == myUid,
                        ),
                        childCount: entries.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),

            // ── Bouton "Partager mon rang" ────────────────────────────
            if (myEntry != null && myRank != null)
              Positioned(
                bottom: 16,
                right: 16,
                child: _ShareRankButton(
                  entry: myEntry,
                  rank: myRank,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Bouton partage rang ───────────────────────────────────────────────────────
class _ShareRankButton extends StatelessWidget {
  final TournamentEntry entry;
  final int rank;
  const _ShareRankButton({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kEstiRed,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          final text = ShareHelper.tournamentRankingShareText(
            tournamentLabel: "ESTI'DVCR",
            rank: rank,
            points: entry.points,
            exactScores: entry.exactScores,
            displayName: entry.displayName,
          );
          DvcrShare.share(text);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ios_share_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'PARTAGER MON RANG',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vue complète Top Ligues (quand chip sélectionné) ─────────────────────────
class _TopLiguesSectionFull extends StatelessWidget {
  final String tournamentId;
  final List<EstiDvcrLeague> myLeagues;

  const _TopLiguesSectionFull({
    required this.tournamentId,
    required this.myLeagues,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _TopLiguesSection(
        tournamentId: tournamentId,
        myLeagues: myLeagues,
      ),
    );
  }
}

// ── Section Top Ligues ────────────────────────────────────────────────────────
class _TopLiguesSection extends StatefulWidget {
  final String tournamentId;
  final List<EstiDvcrLeague> myLeagues;

  const _TopLiguesSection({
    required this.tournamentId,
    required this.myLeagues,
  });

  @override
  State<_TopLiguesSection> createState() => _TopLiguesSectionState();
}

class _TopLiguesSectionState extends State<_TopLiguesSection> {
  List<EstiDvcrLeagueTopScore>? _topLeagues;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final result = await EstiDvcrLeagueService.getTopLeagues(widget.tournamentId);
      if (mounted) setState(() { _topLeagues = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _topLeagues = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Toujours afficher la section (chargement, vide, ou remplie)

    final leagues = _topLeagues ?? [];
    final myLeagueIds = widget.myLeagues.map((l) => l.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: _kEstiGold, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(
                'TOP LIGUES',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withAlpha(200),
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: _kEstiMuted))
              else
                GestureDetector(
                  onTap: _load,
                  child: const Icon(Icons.refresh_rounded, size: 16, color: _kEstiMuted),
                ),
            ],
          ),
        ),
        if (!_loading && leagues.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Crée ou rejoins une ligue pour apparaître ici',
              style: GoogleFonts.inter(fontSize: 12, color: _kEstiMuted),
            ),
          ),
        ...List.generate(leagues.length, (i) {
          final item = leagues[i];
          final isMine = myLeagueIds.contains(item.league.id);
          return GestureDetector(
            onTap: null,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isMine ? _kEstiGold.withAlpha(15) : _kEstiSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMine ? _kEstiGold.withAlpha(80) : Colors.white.withAlpha(15),
                ),
              ),
              child: Row(
                children: [
                  // Rang
                  SizedBox(
                    width: 28,
                    child: Text(
                      i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}',
                      style: i < 3
                          ? const TextStyle(fontSize: 16)
                          : GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: _kEstiMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Icône ligue
                  Icon(Icons.emoji_events_rounded, size: 16, color: isMine ? _kEstiGold : _kEstiMuted),
                  const SizedBox(width: 8),
                  // Nom + membres
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.league.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isMine ? FontWeight.w800 : FontWeight.w600,
                            color: isMine ? Colors.white : Colors.white.withAlpha(200),
                          ),
                        ),
                        Text(
                          '${item.league.memberCount} membre${item.league.memberCount > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(fontSize: 10, color: _kEstiMuted),
                        ),
                      ],
                    ),
                  ),
                  // Score moyen
                  if (item.avgScore > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kEstiGold.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kEstiGold.withAlpha(70)),
                      ),
                      child: Text(
                        '${item.avgScore.toStringAsFixed(1)} pts moy.',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _kEstiGold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Helper commun ─────────────────────────────────────────────────────────────
Widget _buildEntryList(
  AsyncSnapshot<List<TournamentEntry>> snap,
  String? myUid, {
  Color? accentColor,
}) {
  // Erreur Firestore ou spinner initial → on affiche "Aucun résultat"
  if (snap.hasError || (!snap.hasData && snap.connectionState == ConnectionState.waiting)) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _kEstiGold));
  }
  final entries = snap.data ?? [];
  if (entries.isEmpty) return const _EmptyLeaderboard();
  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
    itemCount: entries.length,
    itemBuilder: (context, i) => _LeaderboardRow(
      entry: entries[i],
      rank: i + 1,
      isMe: entries[i].uid == myUid,
      accentColor: accentColor,
    ),
  );
}

// ── Classement général ────────────────────────────────────────────────────────
class _GeneralLeaderboard extends StatelessWidget {
  final String tournamentId;
  const _GeneralLeaderboard({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<TournamentEntry>>(
      stream: TournamentService.leaderboardTopStream(tournamentId, limit: 100),
      builder: (ctx, snap) => _buildEntryList(snap, myUid),
    );
  }
}

// ── Classement journée ────────────────────────────────────────────────────────
class _DayLeaderboard extends StatelessWidget {
  final String tournamentId;
  final int matchDay;
  const _DayLeaderboard({required this.tournamentId, required this.matchDay});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<TournamentEntry>>(
      stream: TournamentService.leaderboardByMatchDayStream(tournamentId, matchDay),
      builder: (ctx, snap) => _buildEntryList(snap, myUid),
    );
  }
}

// ── Classement ligue ──────────────────────────────────────────────────────────
class _LeagueLeaderboard extends StatefulWidget {
  final String tournamentId;
  final String leagueId;
  final VoidCallback onBack;
  const _LeagueLeaderboard({required this.tournamentId, required this.leagueId, required this.onBack});

  @override
  State<_LeagueLeaderboard> createState() => _LeagueLeaderboardState();
}

class _LeagueLeaderboardState extends State<_LeagueLeaderboard> {
  int _selectedDay = 0;

  static const _kDayChips = <({int day, String label})>[
    (day: 0, label: 'GÉNÉRAL'),
    (day: 1, label: 'J1'),
    (day: 2, label: 'J2'),
    (day: 3, label: 'J3'),
    (day: _kFinaleDay, label: 'PHASE FINALE'),
  ];

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        // ── En-tête retour ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                onPressed: widget.onBack,
              ),
              Text(
                'CLASSEMENT DE LA LIGUE',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // ── Chips journée ───────────────────────────────────────────────
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: _kDayChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final chip = _kDayChips[i];
              final selected = _selectedDay == chip.day;
              final isFinale = chip.day == _kFinaleDay;
              final chipColor = isFinale ? _kEstiGold : _kEstiGold;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = chip.day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: selected ? chipColor : _kEstiSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? chipColor : (isFinale ? _kEstiGold.withAlpha(60) : Colors.white.withAlpha(25)),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      chip.label,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : (isFinale ? _kEstiGold : _kEstiMuted),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // ── Liste classement ────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<TournamentEntry>>(
            stream: EstiDvcrLeagueService.leagueLeaderboardStream(
              widget.leagueId,
              widget.tournamentId,
              matchDay: _selectedDay,
            ),
            builder: (ctx, snap) => _buildEntryList(snap, myUid, accentColor: _kEstiGold),
          ),
        ),
      ],
    );
  }
}

// ── Classement phase finale ───────────────────────────────────────────────────
class _FinaleLeaderboard extends StatelessWidget {
  final String tournamentId;
  const _FinaleLeaderboard({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<TournamentEntry>>(
      stream: TournamentService.leaderboardFinaleStream(tournamentId),
      builder: (ctx, snap) => _buildEntryList(snap, myUid, accentColor: _kEstiGold),
    );
  }
}

// ── Ligne classement ──────────────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final TournamentEntry entry;
  final int rank;
  final bool isMe;
  final Color? accentColor;

  const _LeaderboardRow({
    required this.entry,
    required this.rank,
    required this.isMe,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final Color rankColor;
    final String rankLabel;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankLabel = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankLabel = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankLabel = '🥉';
    } else {
      rankColor = _kEstiMuted;
      rankLabel = '$rank';
    }

    final accent = accentColor ?? _kEstiRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? accent.withAlpha(30)
            : isTop3
                ? _kEstiSurface.withAlpha(200)
                : _kEstiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? accent.withAlpha(100)
              : isTop3
                  ? _kEstiGold.withAlpha(50)
                  : Colors.white.withAlpha(15),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 36,
            child: isTop3
                ? Text(rankLabel, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center)
                : Text(
                    rankLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: rankColor,
                    ),
                  ),
          ),
          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kEstiTeal,
              border: Border.all(color: isMe ? accent : Colors.white.withAlpha(30)),
            ),
            child: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      entry.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _DefaultAvatar(name: entry.displayName),
                    ),
                  )
                : _DefaultAvatar(name: entry.displayName),
          ),
          const SizedBox(width: 10),

          // Nom + scores exacts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                    color: isMe ? Colors.white : Colors.white.withAlpha(220),
                  ),
                ),
                if (entry.exactScores > 0)
                  Text(
                    '${entry.exactScores} score${entry.exactScores > 1 ? 's' : ''} exact${entry.exactScores > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 10, color: _kEstiGold, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isTop3 ? _kEstiGold.withAlpha(30) : accent.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isTop3 ? _kEstiGold.withAlpha(80) : accent.withAlpha(60)),
            ),
            child: Text(
              '${entry.points} pts',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isTop3 ? _kEstiGold : Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String name;
  const _DefaultAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: GoogleFonts.barlowCondensed(fontSize: 15, fontWeight: FontWeight.w800, color: _kEstiMuted),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: _kEstiMuted.withAlpha(120)),
          const SizedBox(height: 12),
          Text(
            'Aucun résultat encore',
            style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w700, color: _kEstiMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Le classement se met à jour après chaque match',
            style: GoogleFonts.inter(fontSize: 12, color: _kEstiMuted),
          ),
        ],
      ),
    );
  }
}
