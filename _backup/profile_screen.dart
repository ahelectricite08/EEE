import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/seed_service.dart';
import 'prono_screen.dart' show PronoScreen;

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0C0C0F);
const _kCard   = Color(0xFF141418);
const _kBorder = Color(0xFF1E1E24);
const _kRed    = Color(0xFFBA203C);
const _kGrey   = Color(0xFF555560);

// ── Helpers rôle ──────────────────────────────────────────────────────────────
Color _roleColor(UserRole r) {
  switch (r) {
    case UserRole.admin:            return const Color(0xFFEF5350);
    case UserRole.communityManager: return const Color(0xFF64B5F6);
    case UserRole.editor:           return const Color(0xFF00BCD4);
    case UserRole.partenaire:       return const Color(0xFFFFB74D);
    case UserRole.donateur:         return const Color(0xFF81C784);
    case UserRole.supporter:        return const Color(0xFF666670);
  }
}

String _roleLabel(UserRole r) {
  switch (r) {
    case UserRole.admin:            return 'Admin';
    case UserRole.communityManager: return 'CM';
    case UserRole.editor:           return 'Éditeur';
    case UserRole.partenaire:       return 'Partenaire';
    case UserRole.donateur:         return 'Donateur';
    case UserRole.supporter:        return 'Membre';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  UserRole _role = UserRole.supporter;
  Set<UserRole> _roles = {UserRole.supporter};
  bool _loading = true;
  bool _seedingLive = false;
  bool _notifLive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data  = await UserService.getUserData();
    final roles = UserService.parseRolesFromData(data);
    final role  = UserService.primaryRole(roles);
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userData  = data;
        _roles     = roles;
        _role      = role;
        _notifLive = prefs.getBool('notif_live') ?? true;
        _loading   = false;
      });
    }
  }

  Future<void> _toggleNotif(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_live', value);
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('dvcr_live');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_live');
    }
    if (mounted) setState(() => _notifLive = value);
  }

  Future<void> _seedLive() async {
    String autoTeam1 = '';
    String autoTeam2 = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final m = snap.docs.first.data();
        autoTeam1 = m['team1'] as String? ?? '';
        autoTeam2 = m['team2'] as String? ?? '';
      }
    } catch (_) {}

    final urlCtrl   = TextEditingController();
    final team1Ctrl = TextEditingController(text: autoTeam1);
    final team2Ctrl = TextEditingController(text: autoTeam2);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141418),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF1E1E24)),
        ),
        title: Text('Démarrer un live',
            style: GoogleFonts.barlowCondensed(
                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LiveField(controller: urlCtrl, label: 'URL YouTube',
                hint: 'Chaîne DVCR par défaut'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LiveField(controller: team1Ctrl, label: 'Équipe dom.')),
              const SizedBox(width: 8),
              Expanded(child: _LiveField(controller: team2Ctrl, label: 'Équipe ext.')),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler',
                style: GoogleFonts.barlowCondensed(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('CONFIRMER',
                style: GoogleFonts.barlowCondensed(
                    color: _kRed, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _seedingLive = true);
    const defaultUrl = 'https://www.youtube.com/@drapeauvertcartonrouge/streams';
    try {
      await SeedService.startLive(
        url:   urlCtrl.text.trim().isEmpty ? defaultUrl : urlCtrl.text.trim(),
        team1: team1Ctrl.text.trim(),
        team2: team2Ctrl.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _seedingLive = false);
    }
  }

  Future<void> _clearLive() async {
    setState(() => _seedingLive = true);
    try {
      await SeedService.clearLive();
    } finally {
      if (mounted) setState(() => _seedingLive = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header minimal ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 40, height: 40,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(
                    color: _kRed, strokeWidth: 1.5)),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Avatar + nom ──────────────────────────────────────
                      _buildHeader(user),
                      const SizedBox(height: 40),

                      // ── Compte ────────────────────────────────────────────
                      _sectionLabel('Compte'),
                      _row(label: 'Email', value: user?.email ?? '—'),
                      _row(label: 'Membre depuis', value: _memberSince()),
                      _notifRow(),
                      const SizedBox(height: 32),

                      // ── Pronostics ────────────────────────────────────────
                      if (user != null) ...[
                        _PronoStatsSection(uid: user.uid),
                        const SizedBox(height: 32),
                      ],

                      // ── Contrôles live (admin/CM) ─────────────────────────
                      if (_role == UserRole.admin || _role == UserRole.communityManager) ...[
                        _LiveScoreControls(),
                        const SizedBox(height: 12),
                        _seedButton(),
                        const SizedBox(height: 32),
                      ],

                      // ── Signalements (admin) ──────────────────────────────
                      if (_role == UserRole.admin) ...[
                        _ReportsSection(),
                        const SizedBox(height: 32),
                      ],

                      // ── Déconnexion ───────────────────────────────────────
                      GestureDetector(
                        onTap: _logout,
                        child: Text(
                          'Se déconnecter',
                          style: GoogleFonts.barlow(
                            fontSize: 14, color: _kRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── En-tête avatar + nom + rôle ───────────────────────────────────────────
  Widget _buildHeader(User? user) {
    final firstName  = (_userData?['firstName'] ?? '') as String;
    final lastName   = (_userData?['lastName']  ?? '') as String;
    final fullName   = '$firstName $lastName'.trim();
    final initials   = (firstName.isNotEmpty ? firstName[0] : '') +
                       (lastName.isNotEmpty  ? lastName[0]  : '');
    final visible    = (_roles.length > 1
        ? _roles.where((r) => r != UserRole.supporter).toList()
        : _roles.toList())
      ..sort((a, b) => UserService.rolePriority.indexOf(a)
          .compareTo(UserService.rolePriority.indexOf(b)));
    final roleColor  = _roleColor(_role);

    return Row(
      children: [
        // Avatar
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: roleColor.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials.toUpperCase().isEmpty ? '?' : initials.toUpperCase(),
              style: GoogleFonts.barlowCondensed(
                fontSize: 24, fontWeight: FontWeight.w900,
                color: roleColor.withAlpha(180),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Nom + rôle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullName.isEmpty ? (user?.email ?? 'Membre DVCR') : fullName,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              visible.map(_roleLabel).join(' · '),
              style: GoogleFonts.barlow(
                fontSize: 13, color: roleColor.withAlpha(200),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: Colors.white24, letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ── Ligne info ─────────────────────────────────────────────────────────────
  Widget _row({required String label, required String value, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A22))),
      ),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.barlow(fontSize: 13, color: _kGrey)),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.barlow(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ── Toggle notifs ──────────────────────────────────────────────────────────
  Widget _notifRow() {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A22))),
      ),
      child: Row(
        children: [
          Text('Notifications live',
              style: GoogleFonts.barlow(fontSize: 13, color: _kGrey)),
          const Spacer(),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: _notifLive,
              onChanged: _toggleNotif,
              activeColor: Colors.white,
              activeTrackColor: Colors.white24,
              inactiveThumbColor: const Color(0xFF444444),
              inactiveTrackColor: const Color(0xFF2A2A2A),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton début / fin de match ───────────────────────────────────────────
  Widget _seedButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live').doc('current').snapshots(),
      builder: (context, snap) {
        final isLive = snap.hasData && snap.data!.exists;
        final isLoading = _seedingLive;

        return GestureDetector(
          onTap: isLoading ? null : (isLive ? _clearLive : _seedLive),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: isLive ? _kRed.withAlpha(15) : const Color(0xFF161618),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLive
                    ? _kRed.withAlpha(60)
                    : const Color(0xFF242428),
              ),
            ),
            child: isLoading
                ? const Center(child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 1.5)))
                : Center(
                    child: Text(
                      isLive ? 'Fin de match' : 'Début du match',
                      style: GoogleFonts.barlow(
                        fontSize: 14,
                        color: isLive ? _kRed : Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _memberSince() {
    final ts = _userData?['createdAt'];
    if (ts == null) return '—';
    final date = ts.toDate() as DateTime;
    final months = ['jan','fév','mar','avr','mai','juin',
        'juil','aoû','sep','oct','nov','déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Section pronostics ────────────────────────────────────────────────────────
class _PronoStatsSection extends StatelessWidget {
  final String uid;
  const _PronoStatsSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .orderBy('points', descending: true)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final docs  = snap.data!.docs;
        final index = docs.indexWhere((d) => d.id == uid);

        final int pts, exact, good, total, rank;
        if (index == -1) {
          pts = exact = good = total = rank = 0;
        } else {
          final d = docs[index].data() as Map<String, dynamic>;
          rank  = index + 1;
          pts   = d['points']           as int? ?? 0;
          exact = d['exactScores']      as int? ?? 0;
          good  = d['goodResults']      as int? ?? 0;
          total = d['totalPredictions'] as int? ?? 0;
        }

        String rankLabel;
        if (rank == 0)      rankLabel = '—';
        else if (rank == 1) rankLabel = '1er';
        else                rankLabel = '${rank}ème';

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PronoScreen())),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('PRONOSTICS', style: GoogleFonts.barlowCondensed(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: Colors.white24, letterSpacing: 1.5,
                  )),
                  const Spacer(),
                  Text('Voir →', style: GoogleFonts.barlow(
                    fontSize: 11, color: Colors.white24,
                  )),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StatItem(label: 'Classement', value: rankLabel),
                  Container(width: 1, height: 32, color: const Color(0xFF1E1E24)),
                  _StatItem(label: 'Points', value: '$pts'),
                  Container(width: 1, height: 32, color: const Color(0xFF1E1E24)),
                  _StatItem(label: 'Pronos', value: '$total'),
                  Container(width: 1, height: 32, color: const Color(0xFF1E1E24)),
                  _StatItem(label: 'Exacts', value: '$exact'),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFF1A1A20)),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.barlowCondensed(
            fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white,
          )),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.barlow(
            fontSize: 10, color: const Color(0xFF555560),
          )),
        ],
      ),
    );
  }
}

// ── Panel signalements (admin) ────────────────────────────────────────────────
class _ReportsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SIGNALEMENTS (${docs.length})',
              style: GoogleFonts.barlowCondensed(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.white24, letterSpacing: 1.5,
              )),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['reportedName'] ?? 'Membre',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 4),
                    Text('"${d['messageText'] ?? ''}"',
                        style: GoogleFonts.barlow(
                            fontSize: 12, color: Colors.white38,
                            fontStyle: FontStyle.italic),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(d['reportedUid'] as String)
                                .update({
                                  'chatBannedUntil': Timestamp.fromDate(
                                      DateTime.now().add(const Duration(hours: 24))),
                                });
                            await doc.reference.update({'status': 'banned'});
                          },
                          child: Text('Bannir 24h',
                              style: GoogleFonts.barlow(
                                fontSize: 12, color: _kRed,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => doc.reference.update({'status': 'ignored'}),
                          child: Text('Ignorer',
                              style: GoogleFonts.barlow(
                                fontSize: 12, color: Colors.white38,
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(height: 1, color: const Color(0xFF1A1A20)),
          ],
        );
      },
    );
  }
}

// ── Contrôles score en direct (admin/CM) ─────────────────────────────────────
class _LiveScoreControls extends StatelessWidget {
  const _LiveScoreControls();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live').doc('current').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final d    = snap.data!.data() as Map<String, dynamic>;
        final t1   = (d['team1'] as String?)?.toUpperCase() ?? 'DOM.';
        final t2   = (d['team2'] as String?)?.toUpperCase() ?? 'EXT.';
        final home = (d['scoreHome'] as int?) ?? 0;
        final away = (d['scoreAway'] as int?) ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('SCORE EN DIRECT', style: GoogleFonts.barlowCondensed(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: Colors.white24, letterSpacing: 1.5,
                )),
                const Spacer(),
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('LIVE', style: GoogleFonts.barlowCondensed(
                  fontSize: 10, color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w700, letterSpacing: 1,
                )),
              ]),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Domicile
                  Expanded(child: Column(children: [
                    Text(t1.length > 10 ? '${t1.substring(0, 10)}.' : t1,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12, color: Colors.white38,
                        fontWeight: FontWeight.w700,
                      ), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _ScoreBtn(
                        icon: Icons.remove_rounded,
                        onTap: home > 0
                            ? () => SeedService.updateLiveScore(home - 1, away)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('$home', style: GoogleFonts.barlowCondensed(
                          fontSize: 38, fontWeight: FontWeight.w900,
                          color: Colors.white,
                        )),
                      ),
                      _ScoreBtn(
                        icon: Icons.add_rounded,
                        onTap: () => SeedService.updateLiveScore(home + 1, away),
                        primary: true,
                      ),
                    ]),
                  ])),
                  // Séparateur
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('—', style: GoogleFonts.barlowCondensed(
                      fontSize: 24, color: Colors.white12,
                      fontWeight: FontWeight.w900,
                    )),
                  ),
                  // Extérieur
                  Expanded(child: Column(children: [
                    Text(t2.length > 10 ? '${t2.substring(0, 10)}.' : t2,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12, color: Colors.white38,
                        fontWeight: FontWeight.w700,
                      ), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _ScoreBtn(
                        icon: Icons.remove_rounded,
                        onTap: away > 0
                            ? () => SeedService.updateLiveScore(home, away - 1)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('$away', style: GoogleFonts.barlowCondensed(
                          fontSize: 38, fontWeight: FontWeight.w900,
                          color: Colors.white,
                        )),
                      ),
                      _ScoreBtn(
                        icon: Icons.add_rounded,
                        onTap: () => SeedService.updateLiveScore(home, away + 1),
                        primary: true,
                      ),
                    ]),
                  ])),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: _kBorder),
              const SizedBox(height: 16),
              // Bouton mi-temps pleine largeur
              GestureDetector(
                onTap: () => SeedService.notifyHalftime(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.pause_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 5),
                    Text('MI-TEMPS', style: GoogleFonts.barlowCondensed(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white38, letterSpacing: 1,
                    )),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  const _ScoreBtn({required this.icon, this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.white.withAlpha(8)
              : primary ? _kRed.withAlpha(200) : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
          color: onTap == null ? Colors.white24 : Colors.white,
          size: 18),
      ),
    );
  }
}

// ── Champ texte pour la dialog live ───────────────────────────────────────────
class _LiveField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  const _LiveField({required this.controller, required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.barlow(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.barlow(color: Colors.white38, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.barlow(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0C0C0F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1E1E24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1E1E24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kRed, width: 1.5),
        ),
      ),
    );
  }
}
