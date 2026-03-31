import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/user_service.dart';

// ── Palette (dark theme) ──────────────────────────────────────────────────────
const _kBg     = Color(0xFF0D0D0D);
const _kCard   = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kRed    = Color(0xFFBA203C);
const _kGold   = Color(0xFFC8A436);
const _kGreen  = Color(0xFF0A4438);
const _kGrey   = Color(0xFF888888);

// ── Écran principal pronostics ────────────────────────────────────────────────
class PronoScreen extends StatefulWidget {
  const PronoScreen({super.key});
  @override
  State<PronoScreen> createState() => _PronoScreenState();
}

class _PronoScreenState extends State<PronoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  User? _user;
  String _displayName = 'Membre';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) { setState(() => _loading = false); return; }
    final data = await UserService.getUserDataByUid(u.uid);
    final fn = data?['firstName'] as String? ?? '';
    final ln = data?['lastName']  as String? ?? '';
    setState(() {
      _user        = u;
      _displayName = fn.isNotEmpty
          ? '$fn${ln.isNotEmpty ? ' ${ln[0]}.' : ''}'
          : 'Membre';
      _loading     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 52,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(140), Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'PRONOSTICS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 2,
                shadows: [const Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kGold.withAlpha(30),
                border: Border.all(color: _kGold, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('DVCR', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: _kGold, letterSpacing: 1)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              Container(height: 1, color: _kGold.withAlpha(60)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _kBorder),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: _kGold,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: _kGrey,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
                    tabs: const [
                      Tab(text: 'MES PRONOS'),
                      Tab(text: 'CLASSEMENT'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kRed, strokeWidth: 2))
          : _user == null
              ? _buildAuthWall()
              : TabBarView(
                  controller: _tab,
                  children: [
                    _MatchesPronoTab(uid: _user!.uid, displayName: _displayName),
                    _LeaderboardTab(currentUid: _user!.uid),
                  ],
                ),
    );
  }

  Widget _buildAuthWall() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _kRed.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: _kRed.withAlpha(76), width: 2),
              ),
              child: const Icon(Icons.lock_rounded, color: _kRed, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Connecte-toi pour pronostiquer',
              style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onglet "MES PRONOS" ───────────────────────────────────────────────────────
class _MatchesPronoTab extends StatelessWidget {
  final String uid;
  final String displayName;
  const _MatchesPronoTab({required this.uid, required this.displayName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kRed, strokeWidth: 2),
          );
        }
        // Filtre + déduplication
        final seen = <String>{};
        final docs = (snap.data?.docs ?? []).where((d) {
          final data = d.data() as Map;
          final comp = (data['competition'] as String? ?? '').toUpperCase();
          if (comp.contains('COUPE')) return false;
          final key = '${data['team1']}|${data['team2']}|${data['date']}';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_soccer_outlined,
                    size: 72, color: _kBorder),
                const SizedBox(height: 20),
                Text(
                  'Aucun match à venir',
                  style: GoogleFonts.inter(
                    fontSize: 20, color: _kGrey, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucun match au calendrier pour le moment',
                  style: GoogleFonts.inter(fontSize: 13, color: _kGrey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            return _MatchPronoCard(
              matchId:     doc.id,
              match:       doc.data() as Map<String, dynamic>,
              uid:         uid,
              displayName: displayName,
            );
          },
        );
      },
    );
  }
}

// ── Carte match avec prono ────────────────────────────────────────────────────
class _MatchPronoCard extends StatelessWidget {
  final String matchId;
  final Map<String, dynamic> match;
  final String uid;
  final String displayName;

  const _MatchPronoCard({
    required this.matchId,
    required this.match,
    required this.uid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final date      = match['date'] as Timestamp;
    final matchDate = date.toDate();
    final now       = DateTime.now();
    final locked    = matchDate.isBefore(now);
    final daysLeft  = matchDate.difference(now).inDays;
    final tooEarly  = !locked && daysLeft >= 7;
    final opensOn   = matchDate.subtract(const Duration(days: 7));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .doc('${matchId}_$uid')
          .snapshots(),
      builder: (context, predSnap) {
        final hasPred = predSnap.hasData && predSnap.data!.exists;
        final pred    = hasPred ? predSnap.data!.data() as Map<String, dynamic> : null;

        final team1 = (match['team1'] ?? 'Équipe 1').toString();
        final team2 = (match['team2'] ?? 'Équipe 2').toString();
        final logo1 = match['logo1'] as String?;
        final logo2 = match['logo2'] as String?;
        final comp  = (match['competition'] ?? 'Championnat').toString();

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Header : compétition + date ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withAlpha(160), BlendMode.darken),
                  ),
                ),
                child: Row(
                  children: [
                    Text(comp.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white70, letterSpacing: 1)),
                    const Spacer(),
                    // Badge état
                    if (locked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(100),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.lock_rounded, size: 9, color: _kGrey),
                          const SizedBox(width: 4),
                          Text('FERMÉ', style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _kGrey, letterSpacing: 1)),
                        ]),
                      )
                    else if (tooEarly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withAlpha(40)),
                        ),
                        child: Text(
                          'Dispo le ${DateFormat("dd MMM", 'fr_FR').format(opensOn)}',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                      )
                    else if (hasPred)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kGold.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _kGold.withAlpha(100)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_rounded, size: 9, color: _kGold),
                          const SizedBox(width: 4),
                          Text('PRONOSTIQUÉ', style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _kGold, letterSpacing: 1)),
                        ]),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Text(
                        DateFormat("dd MMM · HH'h'mm", 'fr_FR').format(matchDate),
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                    ),
                  ],
                ),
              ),

              // ── Corps : équipes + score ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    // Team 1
                    Expanded(
                      child: Row(
                        children: [
                          _PronoLogo(logo: logo1, name: team1),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(team1.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: Colors.white),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    // Score
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: hasPred && !tooEarly
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _kGold.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _kGold.withAlpha(100)),
                              ),
                              child: Text(
                                '${pred!['score1Pred']} – ${pred['score2Pred']}',
                                style: GoogleFonts.inter(
                                  fontSize: 20, fontWeight: FontWeight.w800,
                                  color: _kGold),
                              ),
                            )
                          : Text('–',
                              style: GoogleFonts.inter(
                                fontSize: 22, color: _kBorder,
                                fontWeight: FontWeight.w700)),
                    ),
                    // Team 2
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(team2.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: Colors.white),
                              textAlign: TextAlign.end,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 10),
                          _PronoLogo(logo: logo2, name: team2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Badge points ──
              if (hasPred && pred!['points'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PointsBadge(pts: pred['points'] as int),
                ),

              // ── Footer action ──
              if (!locked && !tooEarly)
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: _kBorder)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hasPred ? Icons.edit_rounded : Icons.sports_soccer_rounded,
                                  size: 14,
                                  color: hasPred ? _kGrey : _kGold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasPred ? 'Modifier' : 'PRONOSTIQUER',
                                  style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: hasPred ? _kGrey : _kGold,
                                    letterSpacing: hasPred ? 0 : 0.8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (hasPred) ...[
                        Container(width: 1, height: 20, color: _kBorder),
                        GestureDetector(
                          onTap: () => _sharePred(team1, team2,
                              pred!['score1Pred'] as int, pred['score2Pred'] as int, matchDate),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Icon(Icons.share_rounded, size: 16, color: _kGrey),
                          ),
                        ),
                        Container(width: 1, height: 20, color: _kBorder),
                        GestureDetector(
                          onTap: _cancelPred,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Icon(Icons.close_rounded, size: 16, color: _kGrey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelPred() async {
    await FirebaseFirestore.instance
        .collection('predictions')
        .doc('${matchId}_$uid')
        .delete();
  }

  void _sharePred(String t1, String t2, int s1, int s2, DateTime date) {
    final dateStr = DateFormat("dd MMM yyyy", 'fr_FR').format(date);
    final text =
        '🔮 Mon pronostic DVCR pour $t1 vs $t2 ($dateStr) :\n'
        '⚽ $t1 $s1 - $s2 $t2\n\n'
        'Rejoins la communauté sur l\'app DVCR !';
    Share.share(text);
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PronoSheet(
        matchId:     matchId,
        match:       match,
        uid:         uid,
        displayName: displayName,
      ),
    );
  }
}

class _PronoLogo extends StatelessWidget {
  final String? logo;
  final String name;
  const _PronoLogo({this.logo, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: logo != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(logo!, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                      child: Text(initials,
                          style: GoogleFonts.inter(fontSize: 10,
                              fontWeight: FontWeight.w700, color: _kGrey)))))
          : Center(child: Text(initials,
              style: GoogleFonts.inter(fontSize: 10,
                  fontWeight: FontWeight.w700, color: _kGrey))),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int s1, s2;
  const _ScoreChip({required this.s1, required this.s2});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$s1 - $s2',
        style: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
        ),
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  final int pts;
  const _PointsBadge({required this.pts});
  @override
  Widget build(BuildContext context) {
    final Color c;
    final String label;
    if (pts == 3) {
      c = _kGold;
      label = '+3 pts · score exact';
    } else if (pts == 1) {
      c = _kGold;
      label = '+1 pt · bon résultat';
    } else {
      c = _kGrey;
      label = '0 pt';
    }
    return Text(
      label,
      style: GoogleFonts.inter(fontSize: 11, color: c),
    );
  }
}

// ── Bottom sheet saisie prono ─────────────────────────────────────────────────
class _PronoSheet extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> match;
  final String uid;
  final String displayName;
  const _PronoSheet({
    required this.matchId,
    required this.match,
    required this.uid,
    required this.displayName,
  });
  @override
  State<_PronoSheet> createState() => _PronoSheetState();
}

class _PronoSheetState extends State<_PronoSheet> {
  int  _s1 = 1, _s2 = 1;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final doc = await FirebaseFirestore.instance
        .collection('predictions')
        .doc('${widget.matchId}_${widget.uid}')
        .get();
    if (doc.exists && mounted) {
      final d = doc.data()!;
      setState(() {
        _s1 = (d['score1Pred'] as int?) ?? 1;
        _s2 = (d['score2Pred'] as int?) ?? 1;
      });
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final docRef = FirebaseFirestore.instance
        .collection('predictions')
        .doc('${widget.matchId}_${widget.uid}');
    final snap = await docRef.get();
    final season = widget.match['fffSeason'] as String? ?? '2025-2026';

    if (snap.exists) {
      await docRef.update({
        'score1Pred': _s1,
        'score2Pred': _s2,
        'updatedAt':  FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'matchId':     widget.matchId,
        'uid':         widget.uid,
        'displayName': widget.displayName,
        'score1Pred':  _s1,
        'score2Pred':  _s2,
        'points':      null,
        'season':      season,
        'matchDate':   widget.match['date'],
        'team1':       widget.match['team1'] ?? '',
        'team2':       widget.match['team2'] ?? '',
        'createdAt':   FieldValue.serverTimestamp(),
        'updatedAt':   FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.pop(context);
      final t1 = widget.match['team1'] ?? '';
      final t2 = widget.match['team2'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Prono enregistré : $t1 $_s1 - $_s2 $t2',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: _kGreen,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final team1 = widget.match['team1'] as String? ?? 'Équipe 1';
    final team2 = widget.match['team2'] as String? ?? 'Équipe 2';
    final date  = widget.match['date'] as Timestamp;

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'TON PRONOSTIC',
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat("dd MMMM yyyy · HH'h'mm", 'fr_FR').format(date.toDate()),
            style: GoogleFonts.inter(fontSize: 12, color: _kGrey),
          ),
          const SizedBox(height: 28),
          if (!_loaded)
            const CircularProgressIndicator(color: _kRed, strokeWidth: 2)
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        team1.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _Stepper(value: _s1, onChanged: (v) => setState(() => _s1 = v)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '-',
                    style: GoogleFonts.inter(
                      fontSize: 38, color: _kGrey, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        team2.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _Stepper(value: _s2, onChanged: (v) => setState(() => _s2 = v)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          // Rappel système de points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _PointHint(icon: '⭐', pts: '3 pts', label: 'Score exact'),
                _PointHint(icon: '✓', pts: '1 pt',  label: 'Bon résultat'),
                _PointHint(icon: '✗', pts: '0 pt',  label: 'Mauvais prono'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _saving ? _kBorder : _kRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _saving
                  ? const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2,
                        ),
                      ),
                    )
                  : Text(
                      'VALIDER MON PRONO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointHint extends StatelessWidget {
  final String icon, pts, label;
  const _PointHint({required this.icon, required this.pts, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(pts, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
        )),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _kGrey)),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          enabled: value > 0,
          onTap: value > 0 ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 18),
        Text(
          '$value',
          style: GoogleFonts.inter(
            fontSize: 42, fontWeight: FontWeight.w700, color: _kGold,
          ),
        ),
        const SizedBox(width: 18),
        _StepBtn(
          icon: Icons.add_rounded,
          enabled: true,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(icon,
          color: enabled ? Colors.white : _kGrey,
          size: 20),
      ),
    );
  }
}

// ── Onglet Classement ─────────────────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  final String currentUid;
  const _LeaderboardTab({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .orderBy('points', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kRed, strokeWidth: 2),
          );
        }
        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 72, color: _kBorder),
                const SizedBox(height: 20),
                Text(
                  'Pas encore de classement',
                  style: GoogleFonts.inter(
                    fontSize: 20, color: _kGrey, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pronostique les matchs pour apparaître ici !',
                  style: GoogleFonts.inter(fontSize: 13, color: _kGrey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d    = docs[i].data() as Map<String, dynamic>;
            final rank = i + 1;
            final isMe = d['uid'] == currentUid;

            final Color medalColor;
            if (rank == 1)      medalColor = const Color(0xFFFFD700);
            else if (rank == 2) medalColor = const Color(0xFFB8B8B8);
            else if (rank == 3) medalColor = const Color(0xFFCD7F32);
            else                medalColor = _kGrey;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isMe ? _kGold.withAlpha(15) : _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? _kGold.withAlpha(100) : _kBorder,
                  width: isMe ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Barre gauche or si c'est moi
                    if (isMe)
                      Positioned(
                        left: 0, top: 0, bottom: 0,
                        child: Container(width: 3, color: _kGold),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(isMe ? 17 : 14, 12, 14, 12),
                      child: Row(
                        children: [
                          // Rang / médaille
                          SizedBox(
                            width: 32,
                            child: rank <= 3
                                ? Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: medalColor.withAlpha(25),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: medalColor.withAlpha(80)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text('$rank',
                                      style: GoogleFonts.inter(
                                        fontSize: 15, fontWeight: FontWeight.w700,
                                        color: isMe ? _kGold : _kGrey)),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Nom + stats
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      d['displayName'] as String? ?? 'Membre',
                                      style: GoogleFonts.inter(
                                        fontSize: 14, fontWeight: FontWeight.w700,
                                        color: isMe ? _kGold : Colors.white),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: _kGold.withAlpha(30),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: _kGold.withAlpha(80)),
                                        ),
                                        child: Text('MOI',
                                          style: GoogleFonts.inter(
                                            fontSize: 8, fontWeight: FontWeight.w800,
                                            color: _kGold, letterSpacing: 1)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d['totalPredictions'] ?? 0} pronos · '
                                  '${d['exactScores'] ?? 0} exact(s) · '
                                  '${d['goodResults'] ?? 0} résultat(s)',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          // Points
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMe ? _kGold : medalColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${d['points'] ?? 0} pts',
                              style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: isMe ? Colors.black : medalColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Widget bannière (utilisé dans chat_screen.dart) ───────────────────────────
class PronoBanner extends StatelessWidget {
  final String uid;
  const PronoBanner({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        // Premier match championnat
        final docs = snap.data!.docs.where((d) {
          final comp = ((d.data() as Map)['competition'] as String? ?? '').toUpperCase();
          return !comp.contains('COUPE');
        }).toList();
        if (docs.isEmpty) return const SizedBox.shrink();

        final nextDoc = docs.first;
        final m       = nextDoc.data() as Map<String, dynamic>;
        final date    = m['date'] as Timestamp;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PronoScreen()),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF2A2A2A)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.sports_soccer_rounded, color: Color(0xFFC8A436), size: 15),
                const SizedBox(width: 8),
                Text(
                  'PRONOS',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: const Color(0xFFC8A436), letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 13, color: const Color(0xFF2A2A2A)),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('predictions')
                        .doc('${nextDoc.id}_$uid')
                        .snapshots(),
                    builder: (_, predSnap) {
                      final hasPred = predSnap.hasData && predSnap.data!.exists;
                      final String matchLabel =
                          '${m['team1'] ?? ''} vs ${m['team2'] ?? ''}';
                      if (hasPred) {
                        final p = predSnap.data!.data() as Map<String, dynamic>;
                        return Text(
                          '$matchLabel · ${p['score1Pred']}-${p['score2Pred']}',
                          style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return Text(
                        '$matchLabel · Pronostiquer →',
                        style: GoogleFonts.inter(
                          fontSize: 13, color: _kGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
