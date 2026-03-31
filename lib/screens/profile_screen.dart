import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/seed_service.dart';
import '../widgets/donation_banner.dart';
import 'prono_screen.dart' show PronoScreen;

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0D0D0D);
const _kCard   = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kGold   = Color(0xFFC8A436);
const _kRed    = Color(0xFFBA203C);
const _kGrey   = Color(0xFF666666);

// ── Helpers rôle ──────────────────────────────────────────────────────────────
Color _roleColor(UserRole r) {
  switch (r) {
    case UserRole.admin:            return const Color(0xFFEF5350);
    case UserRole.communityManager: return const Color(0xFF64B5F6);
    case UserRole.editor:           return const Color(0xFF00BCD4);
    case UserRole.partenaire:       return _kGold;
    case UserRole.donateur:         return const Color(0xFF81C784);
    case UserRole.supporter:        return _kGrey;
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
  bool _seedingEmission = false;
  bool _notifLive   = true;
  bool _notifAlerts = true;
  bool _notifActus  = true;

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
        _notifLive   = prefs.getBool('notif_live')   ?? true;
        _notifAlerts = prefs.getBool('notif_alerts') ?? true;
        _notifActus  = prefs.getBool('notif_actus')  ?? true;
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

  Future<void> _toggleNotifAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_alerts', value);
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('dvcr_alerts');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_alerts');
    }
    if (mounted) setState(() => _notifAlerts = value);
  }

  Future<void> _toggleNotifActus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_actus', value);
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('dvcr_articles');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_articles');
    }
    if (mounted) setState(() => _notifActus = value);
  }

  Future<void> _seedLive() async {
    String autoTeam1 = '';
    String autoTeam2 = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        final m = doc.data();
        final team1 = m['team1'] as String? ?? '';
        final team2 = m['team2'] as String? ?? '';
        if (team1.toLowerCase().contains('sedan') || team2.toLowerCase().contains('sedan')) {
          autoTeam1 = team1;
          autoTeam2 = team2;
          break;
        }
      }
    } catch (_) {}

    final urlCtrl   = TextEditingController();
    final team1Ctrl = TextEditingController(text: autoTeam1);
    final team2Ctrl = TextEditingController(text: autoTeam2);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _kBorder),
        ),
        title: Text('Démarrer un live',
            style: GoogleFonts.barlowCondensed(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
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
            child: Text('Annuler', style: GoogleFonts.inter(color: _kGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('CONFIRMER',
                style: GoogleFonts.inter(color: _kGold, fontWeight: FontWeight.w700)),
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

  Future<void> _seedEmission() async {
    final urlCtrl   = TextEditingController();
    final titleCtrl = TextEditingController(text: 'ÉMISSION DVCR');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _kBorder),
        ),
        title: Text('Démarrer une émission',
            style: GoogleFonts.barlowCondensed(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LiveField(controller: titleCtrl, label: 'Titre de l\'émission'),
            const SizedBox(height: 10),
            _LiveField(controller: urlCtrl, label: 'URL du stream',
                hint: 'YouTube, Twitch…'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: _kGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('CONFIRMER',
                style: GoogleFonts.inter(color: _kGold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _seedingEmission = true);
    try {
      await FirebaseFirestore.instance.collection('live').doc('emission').set({
        'url':       urlCtrl.text.trim(),
        'title':     titleCtrl.text.trim().isEmpty ? 'ÉMISSION DVCR' : titleCtrl.text.trim(),
        'viewers':   0,
        'startedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _seedingEmission = false);
    }
  }

  Future<void> _clearEmission() async {
    setState(() => _seedingEmission = true);
    try {
      await FirebaseFirestore.instance.collection('live').doc('emission').delete();
    } finally {
      if (mounted) setState(() => _seedingEmission = false);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 1.5))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero header ─────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHero(user)),

                // ── Pronos stats ─────────────────────────────────────────────
                if (user != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _PronoStatsSection(uid: user.uid),
                    ),
                  ),

                // ── Compte ───────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildCompteSection(user),
                  ),
                ),

                // ── Admin : score live ────────────────────────────────────────
                if (_role == UserRole.admin || _role == UserRole.communityManager)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _LiveScoreControls(),
                    ),
                  ),

                // ── Admin : début/fin match ───────────────────────────────────
                if (_role == UserRole.admin || _role == UserRole.communityManager)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _seedButton(),
                    ),
                  ),

                // ── Admin : début/fin émission ────────────────────────────────
                if (_role == UserRole.admin || _role == UserRole.communityManager)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _emissionButton(),
                    ),
                  ),

                // ── Admin : signalements ──────────────────────────────────────
                if (_role == UserRole.admin)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _ReportsSection(),
                    ),
                  ),

                // ── Bannière don ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                    child: DonationBanner(
                      donationUrl: 'https://www.helloasso.com',
                      photoAsset: 'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                      title: 'SOUTENEZ DVCR',
                      subtitle: 'Chaque don nous aide à grandir',
                    ),
                  ),
                ),

                // ── Déconnexion ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: GestureDetector(
                      onTap: _logout,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Se déconnecter',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _kRed.withAlpha(180),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }

  // ── Hero header avec texture ───────────────────────────────────────────────
  Widget _buildHero(User? user) {
    final firstName = (_userData?['firstName'] ?? '') as String;
    final lastName  = (_userData?['lastName']  ?? '') as String;
    final fullName  = '$firstName $lastName'.trim();
    final initials  = (firstName.isNotEmpty ? firstName[0] : '') +
                      (lastName.isNotEmpty  ? lastName[0]  : '');
    final visible   = (_roles.length > 1
        ? _roles.where((r) => r != UserRole.supporter).toList()
        : _roles.toList())
      ..sort((a, b) => UserService.rolePriority.indexOf(a)
          .compareTo(UserService.rolePriority.indexOf(b)));
    final roleColor = _roleColor(_role);

    return Stack(
      children: [
        // Texture de fond
        SizedBox(
          height: 220,
          width: double.infinity,
          child: Image.asset(
            'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111)),
          ),
        ),
        // Overlay dégradé
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(180),
                Colors.black.withAlpha(200),
              ],
            ),
          ),
        ),
        // Bouton retour
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 18),
            ),
          ),
        ),
        // Contenu centré
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Avatar
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCard,
                  border: Border.all(color: _kGold, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials.toUpperCase().isEmpty ? '?' : initials.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: _kGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Nom
              Text(
                fullName.isEmpty ? (user?.email ?? 'Membre DVCR') : fullName.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              // Badge(s) rôle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: visible.map((r) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleColor(r).withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _roleColor(r).withAlpha(120)),
                  ),
                  child: Text(
                    _roleLabel(r).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _roleColor(r), letterSpacing: 1,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        // Ligne dorée en bas
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(height: 1, color: _kGold.withAlpha(60)),
        ),
      ],
    );
  }

  // ── Section compte ────────────────────────────────────────────────────────
  Widget _buildCompteSection(User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('COMPTE'),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            children: [
              _infoRow(
                icon: Icons.alternate_email_rounded,
                label: 'Email',
                value: user?.email ?? '—',
              ),
              Container(height: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _infoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Membre depuis',
                value: _memberSince(),
              ),
              Container(height: 1, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _notifRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _kGold),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: _kGrey)),
          const Spacer(),
          Text(value,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifRow() {
    return Column(
      children: [
        _notifSwitch(
          icon: Icons.notifications_rounded,
          label: 'Début de match / émission',
          value: _notifLive,
          onChanged: _toggleNotif,
        ),
        _notifSwitch(
          icon: Icons.sports_soccer_rounded,
          label: 'Alertes en direct (buts, mi-temps…)',
          value: _notifAlerts,
          onChanged: _toggleNotifAlerts,
        ),
        _notifSwitch(
          icon: Icons.article_rounded,
          label: 'Nouvelles actus publiées',
          value: _notifActus,
          onChanged: _toggleNotifActus,
        ),
      ],
    );
  }

  Widget _notifSwitch({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _kGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 13, color: _kGrey)),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: _kGold,
              activeTrackColor: _kGold.withAlpha(60),
              inactiveThumbColor: const Color(0xFF444444),
              inactiveTrackColor: _kBorder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
              color: _kGold, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _kGrey, letterSpacing: 1.5,
            )),
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
        final isLive    = snap.hasData && snap.data!.exists;
        final isLoading = _seedingLive;

        return GestureDetector(
          onTap: isLoading ? null : (isLive ? _clearLive : _seedLive),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isLive ? _kRed.withAlpha(15) : _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isLive ? _kRed.withAlpha(60) : _kBorder,
              ),
            ),
            child: isLoading
                ? const Center(child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 1.5)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isLive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 16,
                        color: isLive ? _kRed : Colors.white54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isLive ? 'FIN DE MATCH' : 'DÉBUT DU MATCH',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isLive ? _kRed : Colors.white54,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _emissionButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live').doc('emission').snapshots(),
      builder: (context, snap) {
        final isLive    = snap.hasData && snap.data!.exists;
        final isLoading = _seedingEmission;

        return GestureDetector(
          onTap: isLoading ? null : (isLive ? _clearEmission : _seedEmission),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isLive ? _kRed.withAlpha(15) : _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isLive ? _kRed.withAlpha(60) : _kBorder,
              ),
            ),
            child: isLoading
                ? const Center(child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 1.5)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isLive ? Icons.stop_rounded : Icons.live_tv_rounded,
                        size: 16,
                        color: isLive ? _kRed : Colors.white54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isLive ? 'FIN DE L\'ÉMISSION' : 'DÉBUT DE L\'ÉMISSION',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isLive ? _kRed : Colors.white54,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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

        final int pts, exact, total, rank;
        if (index == -1) {
          pts = exact = total = rank = 0;
        } else {
          final d = docs[index].data() as Map<String, dynamic>;
          rank  = index + 1;
          pts   = d['points']           as int? ?? 0;
          exact = d['exactScores']      as int? ?? 0;
          total = d['totalPredictions'] as int? ?? 0;
        }

        String rankLabel;
        if (rank == 0)      rankLabel = '—';
        else if (rank == 1) rankLabel = '1ER';
        else                rankLabel = '${rank}ÈME';

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PronoScreen())),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3, height: 14,
                    decoration: BoxDecoration(
                      color: _kGold, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text('PRONOSTICS',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _kGrey, letterSpacing: 1.5,
                    )),
                  const Spacer(),
                  Text('VOIR →',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kGold, letterSpacing: 0.5,
                    )),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    _StatCell(label: 'CLASSEMENT', value: rankLabel, highlight: true),
                    Container(width: 1, height: 56, color: _kBorder),
                    _StatCell(label: 'POINTS', value: '$pts'),
                    Container(width: 1, height: 56, color: _kBorder),
                    _StatCell(label: 'PRONOS', value: '$total'),
                    Container(width: 1, height: 56, color: _kBorder),
                    _StatCell(label: 'EXACTS', value: '$exact'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _StatCell({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: highlight ? _kGold : Colors.white,
              )),
            const SizedBox(height: 3),
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: _kGrey, letterSpacing: 0.5,
              )),
          ],
        ),
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
            Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: _kRed, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text('SIGNALEMENTS',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _kGrey, letterSpacing: 1.5,
                  )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kRed.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _kRed.withAlpha(80)),
                  ),
                  child: Text('${docs.length}',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kRed,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['reportedName'] ?? 'Membre',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 4),
                    Text('"${d['messageText'] ?? ''}"',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: _kGrey,
                            fontStyle: FontStyle.italic),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _kRed.withAlpha(80)),
                            ),
                            child: Text('Bannir 24h',
                              style: GoogleFonts.inter(
                                fontSize: 12, color: _kRed,
                                fontWeight: FontWeight.w600,
                              )),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => doc.reference.update({'status': 'ignored'}),
                          child: Text('Ignorer',
                            style: GoogleFonts.inter(fontSize: 12, color: _kGrey)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text('SCORE EN DIRECT',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _kGrey, letterSpacing: 1.5,
                  )),
                const Spacer(),
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('LIVE', style: GoogleFonts.inter(
                  fontSize: 10, color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w700, letterSpacing: 1,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Column(children: [
                        Text(t1.length > 10 ? '${t1.substring(0, 10)}.' : t1,
                          style: GoogleFonts.inter(
                            fontSize: 11, color: _kGrey,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('$home', style: GoogleFonts.barlowCondensed(
                              fontSize: 42, fontWeight: FontWeight.w900,
                              color: Colors.white, height: 1,
                            )),
                          ),
                          _ScoreBtn(
                            icon: Icons.add_rounded,
                            onTap: () => SeedService.updateLiveScore(home + 1, away),
                            primary: true,
                          ),
                        ]),
                      ])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('—', style: GoogleFonts.inter(
                          fontSize: 20, color: _kBorder,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                      Expanded(child: Column(children: [
                        Text(t2.length > 10 ? '${t2.substring(0, 10)}.' : t2,
                          style: GoogleFonts.inter(
                            fontSize: 11, color: _kGrey,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('$away', style: GoogleFonts.barlowCondensed(
                              fontSize: 42, fontWeight: FontWeight.w900,
                              color: Colors.white, height: 1,
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
                  const SizedBox(height: 16),
                  Container(height: 1, color: _kBorder),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => SeedService.notifyHalftime(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.pause_rounded, size: 12, color: _kGrey),
                        const SizedBox(width: 6),
                        Text('MI-TEMPS', style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: _kGrey, letterSpacing: 1,
                        )),
                      ]),
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
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: onTap == null
              ? _kBorder
              : primary ? _kGold.withAlpha(30) : _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap == null ? Colors.transparent
                : primary ? _kGold.withAlpha(120) : _kBorder,
          ),
        ),
        child: Icon(icon,
          color: onTap == null ? _kGrey
              : primary ? _kGold : Colors.white54,
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
      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: _kGrey, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _kBorder, fontSize: 12),
        filled: true,
        fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
      ),
    );
  }
}
