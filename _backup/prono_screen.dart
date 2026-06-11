import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/user_service.dart';

// ── Palette (cohérente avec chat_screen) ──────────────────────────────────────
const _kBg     = Color(0xFF0C0C0F);
const _kCard   = Color(0xFF16161A);
const _kBorder = Color(0xFF1E1E24);
const _kRed    = Color(0xFFBA203C);
const _kGold   = Color(0xFFFFD700);
const _kGreen  = Color(0xFF4CAF50);

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
        backgroundColor: const Color(0xFF0F0F12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PRONOSTICS',
          style: GoogleFonts.barlowCondensed(
            fontSize: 20, fontWeight: FontWeight.w900,
            color: Colors.white, letterSpacing: 2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(24),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.barlowCondensed(
                  fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                ),
                unselectedLabelStyle: GoogleFonts.barlowCondensed(
                  fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5,
                ),
                tabs: const [
                  Tab(text: 'MES PRONOS'),
                  Tab(text: 'CLASSEMENT'),
                ],
              ),
            ),
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
                color: _kRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _kRed.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.lock_rounded, color: _kRed, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Connecte-toi pour pronostiquer',
              style: GoogleFonts.barlowCondensed(
                fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
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
        // Filtre côté client pour exclure les matchs de coupe
        final docs = (snap.data?.docs ?? []).where((d) {
          final comp = ((d.data() as Map)['competition'] as String? ?? '').toUpperCase();
          return !comp.contains('COUPE');
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer_outlined,
                    size: 72, color: Colors.white12),
                const SizedBox(height: 20),
                Text(
                  'Aucun match à venir',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20, color: Colors.white38, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucun match au calendrier pour le moment',
                  style: GoogleFonts.barlow(fontSize: 13, color: Colors.white24),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 32),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: _kCard,
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + état
              Row(
                children: [
                  Text(
                    DateFormat("dd MMM · HH'h'mm", 'fr_FR').format(matchDate),
                    style: GoogleFonts.barlow(
                      fontSize: 12, color: Colors.white38,
                    ),
                  ),
                  const Spacer(),
                  if (locked)
                    const Icon(Icons.lock_rounded, size: 11, color: Colors.white24)
                  else if (hasPred && !tooEarly)
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: _kGreen, shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Équipes + score
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (match['team1'] ?? 'Équipe 1').toString().toUpperCase(),
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: hasPred && !tooEarly
                        ? Text(
                            '${pred!['score1Pred']} - ${pred['score2Pred']}',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 20, fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '-',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 20, color: Colors.white24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  Expanded(
                    child: Text(
                      (match['team2'] ?? 'Équipe 2').toString().toUpperCase(),
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Badge points
              if (hasPred && pred!['points'] != null) ...[
                const SizedBox(height: 8),
                _PointsBadge(pts: pred['points'] as int),
              ],
              // Zone action
              const SizedBox(height: 12),
              if (tooEarly)
                Text(
                  'Disponible le ${DateFormat("dd MMM", 'fr_FR').format(opensOn)}',
                  style: GoogleFonts.barlow(fontSize: 11, color: Colors.white24),
                )
              else if (!locked)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openSheet(context),
                      child: Text(
                        hasPred ? 'Modifier mon prono' : 'Pronostiquer →',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: hasPred ? Colors.white54 : _kRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (hasPred) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _cancelPred(),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.barlow(
                            fontSize: 12, color: Colors.white24,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _sharePred(
                          match['team1'] as String? ?? '',
                          match['team2'] as String? ?? '',
                          pred!['score1Pred'] as int,
                          pred['score2Pred'] as int,
                          matchDate,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.share_rounded,
                                size: 14, color: Colors.white24),
                            const SizedBox(width: 4),
                            Text(
                              'Partager',
                              style: GoogleFonts.barlow(
                                fontSize: 12, color: Colors.white24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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

class _ScoreChip extends StatelessWidget {
  final int s1, s2;
  const _ScoreChip({required this.s1, required this.s2});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$s1 - $s2',
        style: GoogleFonts.barlowCondensed(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
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
      c = _kGreen;
      label = '+1 pt · bon résultat';
    } else {
      c = Colors.white24;
      label = '0 pt';
    }
    return Text(
      label,
      style: GoogleFonts.barlow(fontSize: 11, color: c),
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
          style: GoogleFonts.barlow(fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1E1E24),
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
        color: Color(0xFF12121A),
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
            style: GoogleFonts.barlowCondensed(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat("dd MMMM yyyy · HH'h'mm", 'fr_FR').format(date.toDate()),
            style: GoogleFonts.barlow(fontSize: 12, color: Colors.white38),
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
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 15, fontWeight: FontWeight.w800,
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
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 38, color: Colors.white24, fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        team2.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 15, fontWeight: FontWeight.w800,
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
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
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
                color: _saving ? Colors.white12 : _kRed,
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
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 16, fontWeight: FontWeight.w900,
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
        Text(pts, style: GoogleFonts.barlowCondensed(
          fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
        )),
        Text(label, style: GoogleFonts.barlow(fontSize: 10, color: Colors.white38)),
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
          style: GoogleFonts.barlowCondensed(
            fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white,
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
          color: enabled ? (icon == Icons.add_rounded ? _kRed : Colors.white12) : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
          color: enabled ? Colors.white : Colors.white24, size: 20),
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
                const Icon(Icons.emoji_events_outlined,
                    size: 72, color: Colors.white12),
                const SizedBox(height: 20),
                Text(
                  'Pas encore de classement',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20, color: Colors.white38, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pronostique les matchs pour apparaître ici !',
                  style: GoogleFonts.barlow(fontSize: 13, color: Colors.white24),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d    = docs[i].data() as Map<String, dynamic>;
            final rank = i + 1;
            final isMe = d['uid'] == currentUid;

            final Color rankColor;
            if (rank == 1)      rankColor = _kGold;
            else if (rank == 2) rankColor = const Color(0xFFCCCCCC);
            else if (rank == 3) rankColor = const Color(0xFFCD7F32);
            else                rankColor = Colors.white30;

            final String rankLabel =
                rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? _kRed.withOpacity(0.10) : _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? _kRed.withOpacity(0.45) : _kBorder,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      rankLabel,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: rank <= 3 ? 22 : 16,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['displayName'] as String? ?? 'Membre',
                          style: GoogleFonts.barlow(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white : Colors.white70,
                          ),
                        ),
                        Text(
                          '${d['totalPredictions'] ?? 0} pronos · '
                          '${d['exactScores'] ?? 0} exact(s) · '
                          '${d['goodResults'] ?? 0} résultat(s)',
                          style: GoogleFonts.barlow(
                            fontSize: 11, color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: rankColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${d['points'] ?? 0} pts',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 16, fontWeight: FontWeight.w900, color: rankColor,
                      ),
                    ),
                  ),
                ],
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
            color: const Color(0xFF0F0F12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.sports_soccer_rounded, color: _kRed, size: 16),
                const SizedBox(width: 10),
                Text(
                  'PRONOS',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: _kRed, letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 13, color: Colors.white12),
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
                          style: GoogleFonts.barlow(
                            fontSize: 13, color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return Text(
                        '$matchLabel · Pronostiquer →',
                        style: GoogleFonts.barlow(
                          fontSize: 13, color: Colors.white38,
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
