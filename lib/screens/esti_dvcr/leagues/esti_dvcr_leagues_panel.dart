import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/esti_dvcr_league_service.dart';
import '../../../services/tournament_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF062921);
const _kSurface = Color(0xFF0D3D32);
const _kTeal    = Color(0xFF0A4438);
const _kRed     = Color(0xFFBA203C);
const _kGold    = Color(0xFFC8A436);
const _kMuted   = Color(0xFF7AADA0);

/// Onglet "LIGUES" dans ESTI'DVCR.
class EstiDvcrLeaguesPanel extends StatefulWidget {
  final String tournamentId;
  const EstiDvcrLeaguesPanel({super.key, required this.tournamentId});

  @override
  State<EstiDvcrLeaguesPanel> createState() => _EstiDvcrLeaguesPanelState();
}

class _EstiDvcrLeaguesPanelState extends State<EstiDvcrLeaguesPanel> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EstiDvcrLeague>>(
      stream: EstiDvcrLeagueService.myLeaguesStream(),
      builder: (context, snap) {
        final leagues = snap.data ?? [];

        return Stack(
          children: [
            leagues.isEmpty
                ? _EmptyState(onCreateTap: () => _showCreateDialog(context), onJoinTap: () => _showJoinDialog(context))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: leagues.length,
                    itemBuilder: (_, i) => _LeagueCard(
                      league: leagues[i],
                      tournamentId: widget.tournamentId,
                    ),
                  ),

            // ── Boutons flottants : masqués si déjà dans une ligue ────
            if (leagues.isEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.add_rounded,
                        label: 'CRÉER',
                        onTap: () => _showCreateDialog(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.link_rounded,
                        label: 'REJOINDRE',
                        color: _kTeal,
                        onTap: () => _showJoinDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  Future<void> _showCreateDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _CreateLeagueDialog(ctrl: ctrl),
    );
    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;

    try {
      final league = await EstiDvcrLeagueService.createLeague(
        name: result.trim(),
        tournamentId: widget.tournamentId,
      );
      if (!mounted) return;
      _showLeagueCreated(context, league);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString());
    }
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => _JoinLeagueDialog(ctrl: ctrl),
    );
    if (code == null || code.trim().isEmpty) return;
    if (!mounted) return;

    try {
      await EstiDvcrLeagueService.joinLeague(code.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ligue rejointe !'), backgroundColor: Color(0xFF0A4438)),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString());
    }
  }

  void _showLeagueCreated(BuildContext context, EstiDvcrLeague league) {
    showDialog(
      context: context,
      builder: (_) => _LeagueCodeDialog(league: league),
    );
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFBA203C)),
    );
  }
}

// ── Carte ligue ───────────────────────────────────────────────────────────────
class _LeagueCard extends StatelessWidget {
  final EstiDvcrLeague league;
  final String tournamentId;
  const _LeagueCard({required this.league, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGold.withAlpha(40)),
        ),
        child: Row(
          children: [
            // Icône ligue
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kGold.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGold.withAlpha(60)),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: _kGold, size: 22),
            ),
            const SizedBox(width: 12),

            // Nom + membres
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    league.name,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 12, color: _kMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${league.memberCount} membre${league.memberCount > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 11, color: _kMuted),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        league.code,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kGold.withAlpha(180),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _LeagueDetailScreen(
        league: league,
        tournamentId: tournamentId,
      ),
    ));
  }
}

// ── Écran détail ligue ────────────────────────────────────────────────────────
class _LeagueDetailScreen extends StatefulWidget {
  final EstiDvcrLeague league;
  final String tournamentId;
  const _LeagueDetailScreen({required this.league, required this.tournamentId});

  @override
  State<_LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<_LeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  EstiDvcrLeague get league => widget.league;
  String get tournamentId => widget.tournamentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kTeal,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          league.name.toUpperCase(),
          style: GoogleFonts.barlowCondensed(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        bottom: TabBar(
          controller: _tc,
          indicatorColor: _kGold,
          labelColor: Colors.white,
          unselectedLabelColor: _kMuted,
          labelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
          tabs: const [
            Tab(text: 'CLASSEMENT'),
            Tab(text: 'PRONOS'),
          ],
        ),
        actions: [
          // Copier le code
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copier le code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: league.code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code ${league.code} copié !'),
                  backgroundColor: _kTeal,
                ),
              );
            },
          ),
          // Quitter
          PopupMenuButton<String>(
            color: _kSurface,
            onSelected: (v) async {
              if (v == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: _kSurface,
                    title: Text('Quitter la ligue ?', style: GoogleFonts.barlowCondensed(color: Colors.white, fontWeight: FontWeight.w900)),
                    content: Text('Tu perdras l\'accès au classement de cette ligue.', style: GoogleFonts.inter(color: _kMuted, fontSize: 13)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: _kMuted))),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Quitter', style: GoogleFonts.inter(color: _kRed, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await EstiDvcrLeagueService.leaveLeague(league.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'leave',
                child: Row(children: [
                  const Icon(Icons.exit_to_app_rounded, color: Color(0xFFBA203C), size: 18),
                  const SizedBox(width: 8),
                  Text('Quitter la ligue', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          // ── Onglet CLASSEMENT ─────────────────────────────────────────
          _LeagueClassementTab(league: league, tournamentId: tournamentId),
          // ── Onglet PRONOS ─────────────────────────────────────────────
          _LeaguePronosTab(league: league, tournamentId: tournamentId),
        ],
      ),
    );
  }
}

// ── Classement de la ligue ────────────────────────────────────────────────────
class _LeagueClassementTab extends StatelessWidget {
  final EstiDvcrLeague league;
  final String tournamentId;
  const _LeagueClassementTab({required this.league, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Invite card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kGold.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGold.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.share_rounded, color: _kGold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite tes amis', style: GoogleFonts.inter(fontSize: 11, color: _kMuted)),
                    Text(
                      'Code : ${league.code}',
                      style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: league.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Code ${league.code} copié !'), backgroundColor: _kTeal),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kGold.withAlpha(80)),
                  ),
                  child: Text('COPIER', style: GoogleFonts.barlowCondensed(fontSize: 12, fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<TournamentEntry>>(
            stream: EstiDvcrLeagueService.leagueLeaderboardStream(league.id, tournamentId),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _kGold));
              final entries = snap.data!;
              if (entries.isEmpty) return Center(child: Text('Aucun résultat encore', style: GoogleFonts.inter(color: _kMuted, fontSize: 13)));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: entries.length,
                itemBuilder: (_, i) => _LeagueRankRow(entry: entries[i], rank: i + 1),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Pronos des membres par match terminé ──────────────────────────────────────
class _LeaguePronosTab extends StatefulWidget {
  final EstiDvcrLeague league;
  final String tournamentId;
  const _LeaguePronosTab({required this.league, required this.tournamentId});

  @override
  State<_LeaguePronosTab> createState() => _LeaguePronosTabState();
}

class _LeaguePronosTabState extends State<_LeaguePronosTab> {
  // matchId → list of {uid, displayName, score1, score2, points}
  Map<String, List<Map<String, dynamic>>>? _pronosByMatch;
  List<TournamentMatch>? _finishedMatches;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Récupérer les membres de la ligue
      final leagueDoc = await FirebaseFirestore.instance
          .collection('esti_dvcr_leagues')
          .doc(widget.league.id)
          .get();
      final memberUids = ((leagueDoc.data()?['memberUids'] as List?)
              ?.map((e) => e.toString())
              .toSet()) ??
          {};

      // 2. Matchs terminés
      final matchesSnap = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .get();

      final matches = matchesSnap.docs
          .map(TournamentMatch.fromDoc)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // 3. Pour chaque match, récupérer les pronos des membres
      final pronosByMatch = <String, List<Map<String, dynamic>>>{};
      for (final m in matches) {
        final predsSnap = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId)
            .collection('predictions')
            .where('matchId', isEqualTo: m.id)
            .get();

        final preds = predsSnap.docs
            .where((d) => memberUids.contains(d.data()['uid']))
            .map((d) => d.data())
            .toList()
          ..sort((a, b) => (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0));

        pronosByMatch[m.id] = preds;
      }

      if (mounted) {
        setState(() {
          _finishedMatches = matches;
          _pronosByMatch = pronosByMatch;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));
    final matches = _finishedMatches ?? [];
    if (matches.isEmpty) {
      return Center(child: Text('Aucun match terminé pour le moment.', style: GoogleFonts.inter(color: _kMuted, fontSize: 13)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: matches.length,
      itemBuilder: (_, i) {
        final m = matches[i];
        final preds = _pronosByMatch?[m.id] ?? [];
        return _MatchPronosCard(match: m, preds: preds);
      },
    );
  }
}

// ── Carte match + pronos des membres ─────────────────────────────────────────
class _MatchPronosCard extends StatelessWidget {
  final TournamentMatch match;
  final List<Map<String, dynamic>> preds;
  const _MatchPronosCard({required this.match, required this.preds});

  static const _fmt = 'EEE d MMM';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header match
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: _kTeal,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${match.team1}  ${match.result1} – ${match.result2}  ${match.team2}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kGold.withAlpha(80)),
                  ),
                  child: Text(
                    'TERMINÉ',
                    style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          // Pronos des membres
          if (preds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Aucun prono pour ce match', style: GoogleFonts.inter(fontSize: 12, color: _kMuted)),
            )
          else
            ...preds.map((p) {
              final pts = p['points'] as int? ?? 0;
              final s1 = p['score1'] as int? ?? 0;
              final s2 = p['score2'] as int? ?? 0;
              final name = p['displayName'] as String? ?? 'Membre';
              final ptColor = pts == 3 ? _kGold : pts == 1 ? const Color(0xFF4CAF50) : _kMuted;
              final ptLabel = pts == 3 ? '+3' : pts == 1 ? '+1' : '0';
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    Text(
                      '$s1 – $s2',
                      style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white.withAlpha(200)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ptColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: ptColor.withAlpha(80)),
                      ),
                      child: Text(ptLabel, style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w900, color: ptColor)),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ── Ligne rang ────────────────────────────────────────────────────────────────
class _LeagueRankRow extends StatelessWidget {
  final TournamentEntry entry;
  final int rank;
  const _LeagueRankRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isTop3 ? _kSurface.withAlpha(220) : _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? _kGold.withAlpha(50) : Colors.white.withAlpha(15),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kMuted,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(220)),
                ),
                if (entry.exactScores > 0)
                  Text(
                    '${entry.exactScores} score${entry.exactScores > 1 ? 's' : ''} exact${entry.exactScores > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 10, color: _kGold, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTop3 ? _kGold.withAlpha(30) : _kRed.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isTop3 ? _kGold.withAlpha(80) : _kRed.withAlpha(60)),
            ),
            child: Text(
              '${entry.points} pts',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isTop3 ? _kGold : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  const _EmptyState({required this.onCreateTap, required this.onJoinTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 56, color: _kGold.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'Aucune ligue',
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white.withAlpha(180),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Crée une ligue et invite tes potes, ou rejoins-en une avec un code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton action ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _kRed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog créer ligue ────────────────────────────────────────────────────────
class _CreateLeagueDialog extends StatelessWidget {
  final TextEditingController ctrl;
  const _CreateLeagueDialog({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CRÉER UNE LIGUE',
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 30,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nom de la ligue',
                labelStyle: GoogleFonts.inter(color: _kMuted, fontSize: 13),
                counterStyle: GoogleFonts.inter(color: _kMuted, fontSize: 10),
                filled: true,
                fillColor: _kTeal.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kGold.withAlpha(60)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kGold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Annuler', style: GoogleFonts.inter(color: _kMuted)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _kRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context, ctrl.text),
                    child: Text('CRÉER', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog rejoindre ligue ────────────────────────────────────────────────────
class _JoinLeagueDialog extends StatelessWidget {
  final TextEditingController ctrl;
  const _JoinLeagueDialog({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REJOINDRE UNE LIGUE',
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.barlowCondensed(
                color: _kGold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                labelText: 'Code à 6 caractères',
                labelStyle: GoogleFonts.inter(color: _kMuted, fontSize: 13),
                counterStyle: GoogleFonts.inter(color: _kMuted, fontSize: 10),
                filled: true,
                fillColor: _kTeal.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kGold.withAlpha(60)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kGold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Annuler', style: GoogleFonts.inter(color: _kMuted)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _kTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context, ctrl.text),
                    child: Text('REJOINDRE', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog code créé ──────────────────────────────────────────────────────────
class _LeagueCodeDialog extends StatelessWidget {
  final EstiDvcrLeague league;
  const _LeagueCodeDialog({required this.league});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: _kGold, size: 40),
            const SizedBox(height: 12),
            Text(
              league.name,
              style: GoogleFonts.barlowCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ligue créée ! Partage ce code à tes amis :',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: league.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Code ${league.code} copié !'), backgroundColor: _kTeal),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _kGold.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGold.withAlpha(80)),
                ),
                child: Text(
                  league.code,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _kGold,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Appuie pour copier',
              style: GoogleFonts.inter(fontSize: 10, color: _kMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
