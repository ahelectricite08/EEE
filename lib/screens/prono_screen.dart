// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'prono/prono_palette.dart';
import 'prono/prono_shell.dart';
import 'public_profile_screen.dart';
import '../models/match_model.dart';
import '../services/prono_social_activity_service.dart';
import '../services/prono_social_service.dart';
import '../services/user_service.dart';
import '../services/match_service.dart';
part 'prono/prono_matches_tab.dart';
part 'prono/prono_match_cards.dart';
part 'prono/prono_progress_tab.dart';
part 'prono/prono_community_tab.dart';
part 'prono/prono_social_pages.dart';

// ── Palette (dark theme) ──────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0D);
const _kCard = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kRed = pronoRed;
const _kGold = pronoGold;
const _kGreen = pronoGreen;
const _kGrey = pronoGrey;
const _kText = pronoText;
const _kMutedText = pronoMutedText;
const _kSurfaceMuted = pronoSurfaceMuted;

Stream<String?> _watchPronoStadiumUrl(String teamName) => FirebaseFirestore
    .instance
    .collection('teams')
    .where('name', isEqualTo: teamName)
    .limit(1)
    .snapshots()
    .map((s) {
      if (s.docs.isEmpty) return null;
      final url = (s.docs.first.data()['stadiumImageUrl'] as String?)?.trim();
      return (url == null || url.isEmpty) ? null : url;
    });

String _friendPresenceLabel({
  required bool online,
  required Timestamp? lastSeen,
}) {
  return online ? 'En ligne' : 'Hors ligne';
}

// ── Écran principal pronostics ────────────────────────────────────────────────
class PronoScreen extends StatefulWidget {
  final int initialTab;

  const PronoScreen({super.key, this.initialTab = 0});
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
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _loadUser();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }
    final data = await UserService.getUserDataByUid(u.uid);
    final resolvedName = PronoSocialService.resolveDisplayName(
      data: data,
      email: u.email,
    );
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      if ((data?['email'] ?? '').toString().trim().isEmpty &&
          (u.email ?? '').isNotEmpty)
        'email': u.email,
      if ((data?['displayName'] ?? '').toString().trim().isEmpty)
        'displayName': resolvedName,
      'pronoProfile': {
        'displayName': resolvedName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    setState(() {
      _user = u;
      _displayName = resolvedName;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compactTabs = screenWidth < 360;
    final pages = _user == null
        ? const [SizedBox.shrink(), SizedBox.shrink(), SizedBox.shrink()]
        : [
            _MatchesPronoTab(uid: _user!.uid, displayName: _displayName),
            _ProgressPronoTab(uid: _user!.uid),
            _CommunityPronoTab(
              uid: _user!.uid,
              displayName: _displayName,
              onOpenMatches: () => _tab.animateTo(0),
            ),
          ];

    return PronoShellScaffold(
      controller: _tab,
      compactTabs: compactTabs,
      loading: _loading,
      isAuthenticated: _user != null,
      authWall: _buildAuthWall(),
      onBack: () => Navigator.pop(context),
      pages: pages,
    );

    // ignore: dead_code
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
            Image.asset(
              'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'PRONOSTICS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
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
              child: Text(
                'DVCR',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kGold,
                  letterSpacing: 1,
                ),
              ),
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
                    isScrollable: compactTabs,
                    tabAlignment: compactTabs
                        ? TabAlignment.start
                        : TabAlignment.fill,
                    labelPadding: EdgeInsets.symmetric(
                      horizontal: compactTabs ? 14 : 0,
                    ),
                    indicator: BoxDecoration(
                      color: _kGold,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: _kGrey,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: GoogleFonts.inter(
                      fontSize: compactTabs ? 11 : 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: compactTabs ? 0.4 : 1,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: compactTabs ? 11 : 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: compactTabs ? 0.4 : 1,
                    ),
                    tabs: const [
                      Tab(text: 'JOUER'),
                      Tab(text: 'PROGRESSION'),
                      Tab(text: 'COMMUNAUTÉ'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kRed, strokeWidth: 2),
            )
          : _user == null
          ? _buildAuthWall()
          : TabBarView(
              controller: _tab,
              children: [
                _MatchesPronoTab(uid: _user!.uid, displayName: _displayName),
                _ProgressPronoTab(uid: _user!.uid),
                _CommunityPronoTab(
                  uid: _user!.uid,
                  displayName: _displayName,
                  onOpenMatches: () => _tab.animateTo(0),
                ),
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
              width: 72,
              height: 72,
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
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _kText,
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
class _LegacyMatchesPronoTab extends StatefulWidget {
  final String uid;
  final String displayName;
  const _LegacyMatchesPronoTab({required this.uid, required this.displayName});

  @override
  State<_LegacyMatchesPronoTab> createState() => _LegacyMatchesPronoTabState();
}

class _LegacyMatchesPronoTabState extends State<_LegacyMatchesPronoTab> {
  String _competition = 'TOUS';
  String _sort = 'PROCHES';

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
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _PronoSeasonCommandCard(uid: widget.uid),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: _PronoQuickGuideCard(),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _PronoSeasonInsightsCard(uid: widget.uid),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: _PronoEmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Impossible de charger les matchs',
                  subtitle:
                      'Les données pronos ne remontent pas pour l\'instant. Réessaie dans un instant.',
                ),
              ),
            ],
          );
        }
        // Filtre + déduplication
        final seen = <String>{};
        final allDocs = (snap.data?.docs ?? []).where((d) {
          final data = d.data() as Map;
          final key = '${data['team1']}|${data['team2']}|${data['date']}';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).toList();

        final competitions = <String>{
          'TOUS',
          ...allDocs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['competition'] ?? 'Championnat')
                .toString()
                .toUpperCase();
          }),
        }.toList();

        var docs = allDocs.where((d) {
          if (_competition == 'TOUS') return true;
          final data = d.data() as Map<String, dynamic>;
          return (data['competition'] ?? '').toString().toUpperCase() ==
              _competition;
        }).toList();

        docs.sort((a, b) {
          final da = ((a.data() as Map<String, dynamic>)['date'] as Timestamp)
              .toDate();
          final db = ((b.data() as Map<String, dynamic>)['date'] as Timestamp)
              .toDate();
          if (_sort == 'LOINTAINS') return db.compareTo(da);
          if (_sort == 'A-Z') {
            final ta = ((a.data() as Map<String, dynamic>)['team1'] ?? '')
                .toString();
            final tb = ((b.data() as Map<String, dynamic>)['team1'] ?? '')
                .toString();
            return ta.compareTo(tb);
          }
          return da.compareTo(db);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_soccer_outlined, size: 72, color: _kBorder),
                const SizedBox(height: 20),
                Text(
                  'Aucun match à venir',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    color: _kGrey,
                    fontWeight: FontWeight.w600,
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _PronoSeasonCommandCard(uid: widget.uid),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _PronoQuickGuideCard(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _PronoSeasonInsightsCard(uid: widget.uid),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _PronoFilterBar(
                competitions: competitions,
                selectedCompetition: _competition,
                selectedSort: _sort,
                onCompetitionChanged: (value) {
                  setState(() => _competition = value);
                },
                onSortChanged: (value) {
                  setState(() => _sort = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            ...docs.map((doc) {
              return _ModernMatchPronoCard(
                matchId: doc.id,
                match: doc.data() as Map<String, dynamic>,
                uid: widget.uid,
                displayName: widget.displayName,
              );
            }),
          ],
        );
      },
    );
  }
}

class _LegacyPronoSeasonCommandCard extends StatelessWidget {
  final String uid;

  const _LegacyPronoSeasonCommandCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.userDocStream(uid),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final social =
            (userData?['social'] as Map<String, dynamic>?) ?? const {};
        final friendsCount =
            (social['friends'] as List?)?.whereType<String>().length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.leaguesForUser(uid),
          builder: (context, leagueSnap) {
            final leaguesCount = leagueSnap.data?.docs.length ?? 0;
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: PronoSocialService.leaderboardEntryStream(uid),
              builder: (context, boardSnap) {
                final data =
                    boardSnap.data?.data() ?? const <String, dynamic>{};
                final points = (data['points'] as num?)?.toInt() ?? 0;
                final duels = (data['duelWins'] as num?)?.toInt() ?? 0;
                final exact = (data['exactScores'] as num?)?.toInt() ?? 0;
                final total = (data['totalPredictions'] as num?)?.toInt() ?? 0;
                final statusLine = total == 0
                    ? 'La saison collective est ouverte. Pose ton premier score et entre dans le classement global.'
                    : 'Tu restes dans la course avec $points points, $exact score${exact > 1 ? 's' : ''} exact${exact > 1 ? 's' : ''} et $duels duel${duels > 1 ? 's' : ''} gagne${duels > 1 ? 's' : ''}.';

                return PronoSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PronoSectionTitle(
                        eyebrow: 'SAISON COLLECTIVE',
                        title: 'Tout le monde joue ensemble',
                        subtitle:
                            'Un classement global qui tourne en continu, des ligues entre potes, des duels validés des deux côtés et une vraie dynamique sociale.',
                      ),
                      const SizedBox(height: 14),
                      Text(
                        statusLine,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: PronoMetricChip(
                              label: 'POINTS SAISON',
                              value: '$points',
                              accent: _kGold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PronoMetricChip(
                              label: 'AMIS ACTIFS',
                              value: '$friendsCount',
                              accent: _kGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PronoMetricChip(
                              label: 'LIGUES',
                              value: '$leaguesCount',
                              accent: _kText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LegacyPronoFilterBar extends StatelessWidget {
  final List<String> competitions;
  final String selectedCompetition;
  final String selectedSort;
  final ValueChanged<String> onCompetitionChanged;
  final ValueChanged<String> onSortChanged;

  const _LegacyPronoFilterBar({
    required this.competitions,
    required this.selectedCompetition,
    required this.selectedSort,
    required this.onCompetitionChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PronoSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'TABLEAU DE MATCHS',
            title: 'Choisis ton prochain prono',
            subtitle:
                'Filtre les affiches ouvertes puis trie-les selon l\'urgence ou la compétition qui t\'intéresse.',
          ),
          const SizedBox(height: 14),
          Text(
            'COMPETITIONS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: competitions.map((competition) {
              final active = competition == selectedCompetition;
              return _TogglePill(
                label: competition,
                active: active,
                onTap: () => onCompetitionChanged(competition),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'TRI',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['PROCHES', 'LOINTAINS', 'A-Z'].map((sort) {
              return _TogglePill(
                label: sort,
                active: sort == selectedSort,
                onTap: () => onSortChanged(sort),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegacyPronoEmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LegacyPronoEmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return PronoSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _kGold.withAlpha(16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _kGold, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _kMutedText,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PronoSocialHub extends StatefulWidget {
  final String uid;
  final String displayName;
  final VoidCallback? onOpenMatches;

  const _PronoSocialHub({
    required this.uid,
    required this.displayName,
    this.onOpenMatches,
  });

  @override
  State<_PronoSocialHub> createState() => _PronoSocialHubState();
}

class _PronoSocialHubState extends State<_PronoSocialHub> {
  final _searchCtrl = TextEditingController();
  final _leagueNameCtrl = TextEditingController();
  final _leagueCodeCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _joiningLeague = false;
  String _activePanel = 'overview';

  String get uid => widget.uid;
  String get displayName => widget.displayName;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _leagueNameCtrl.dispose();
    _leagueCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await PronoSocialService.searchUsers(query);
      if (mounted)
        setState(
          () => _searchResults = results
              .where((u) => (u['uid'] ?? '') != uid)
              .toList(),
        );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _challengeFriend(String friendUid, String friendName) async {
    final all = await MatchService.allUpcoming().first;
    // Ouvert : pas encore commencé (avant le coup d'envoi) et dans les 7 prochains jours
    final now = DateTime.now();
    final matches = all.where((m) {
      final daysLeft = m.date.difference(now).inDays;
      return now.isBefore(m.date) && daysLeft <= 7;
    }).toList();
    if (!mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun match ouvert aux pronos pour le moment'),
        ),
      );
      return;
    }

    // Sélecteur de match
    await showModalBottomSheet(
      context: context,
      backgroundColor: pronoSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 18),
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHOISIR UN MATCH',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _kText,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Défier $friendName sur…',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _kMutedText,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              ...matches.take(8).map((match) {
                final label = '${match.team1} vs ${match.team2}';
                final dateStr =
                    '${match.date.day}/${match.date.month}/${match.date.year}';
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await PronoSocialService.createDuel(
                        ownerUid: uid,
                        ownerName: displayName,
                        opponentUid: friendUid,
                        opponentName: friendName,
                        matchId: match.id,
                        matchLabel: label,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Défi envoyé à $friendName !'),
                            backgroundColor: _kGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _kSurfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _kGold.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kGold.withAlpha(50)),
                          ),
                          child: const Icon(
                            Icons.sports_soccer_rounded,
                            color: _kGold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kText,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _kMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _kMutedText,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createLeagueInline() async {
    final name = _leagueNameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final code = await PronoSocialService.createLeague(
        ownerUid: uid,
        ownerName: displayName,
        name: name,
      );
      _leagueNameCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ligue creee. Code invitation : $code'),
          backgroundColor: _kGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _joinLeagueInline() async {
    final code = _leagueCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty || _joiningLeague) return;
    setState(() => _joiningLeague = true);
    try {
      final ok = await PronoSocialService.joinLeague(
        uid: uid,
        displayName: displayName,
        code: code,
      );
      if (ok) {
        _leagueCodeCtrl.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Ligue rejointe avec succes.' : 'Code de ligue introuvable.',
          ),
          backgroundColor: ok ? _kGreen : _kRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _joiningLeague = false);
    }
  }

  Widget _buildStructuredHub(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'CENTRE SOCIAL',
            title: 'Tout est rangé au même endroit',
            subtitle:
                'Choisis simplement la rubrique qui t\'intéresse. Le contenu reste ici, dans la page, sans empiler des fenêtres partout.',
          ),
          const SizedBox(height: 14),
          PronoSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NAVIGATION RAPIDE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _kMutedText,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SocialActionCard(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Vue d ensemble',
                        subtitle: 'Le plus important',
                        onTap: () => setState(() => _activePanel = 'overview'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SocialActionCard(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Amis',
                        subtitle: 'Invitations et reseau',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PronoFriendsPage(
                              currentUid: uid,
                              displayName: displayName,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SocialActionCard(
                        icon: Icons.sports_martial_arts_rounded,
                        title: 'Duels',
                        subtitle: 'Accepter et suivre',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PronoDuelsPage(
                              currentUid: uid,
                              displayName: displayName,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SocialActionCard(
                        icon: Icons.groups_rounded,
                        title: 'Ligues',
                        subtitle: 'Creer ou rejoindre',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PronoLeaguesPage(
                              currentUid: uid,
                              displayName: displayName,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SocialActionCard(
                        icon: Icons.emoji_events_rounded,
                        title: 'Classement',
                        subtitle: 'Lire le tableau global',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PronoLeaderboardPage(currentUid: uid),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kSurfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RUBRIQUE ACTIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _kMutedText,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              switch (_activePanel) {
                                'friends' => 'AMIS',
                                'duels' => 'DUELS',
                                'leagues' => 'LIGUES',
                                'leaderboard' => 'CLASSEMENT',
                                _ => 'VUE D ENSEMBLE',
                              },
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Le contenu se met juste dessous.',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _kMutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildOverviewPanel(),
        ],
      ),
    );
  }

  Widget _buildOverviewPanel() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.userDocStream(uid),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.friendRequestsForUser(uid),
          builder: (context, requestSnap) {
            final requests = requestSnap.data?.docs ?? const [];
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: PronoSocialService.leaguesForUser(uid),
              builder: (context, leagueSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: PronoSocialService.duelsForUser(uid),
                  builder: (context, duelSnap) {
                    final duelDocs = duelSnap.data?.docs ?? const [];
                    final pendingToAnswer = duelDocs.where((doc) {
                      final data = doc.data();
                      return (data['status'] ?? '') == 'pending' &&
                          (data['opponentUid'] ?? '') == uid;
                    }).length;

                    return Column(
                      children: [
                        _SocialGameCenterCard(
                          uid: uid,
                          title: 'QG SOCIAL',
                          subtitle:
                              'Ton niveau, tes objectifs et ta progression sociale sont visibles ici d un seul coup.',
                          actionHint: requests.isEmpty && pendingToAnswer == 0
                              ? 'Aucune urgence. Tu peux ajouter un ami, ouvrir une ligue ou lancer un duel.'
                              : '${requests.length} demande(s) d ami et $pendingToAnswer duel(s) t attendent.',
                        ),
                        const SizedBox(height: 12),
                        _SocialNextStepCard(
                          eyebrow: 'A TRAITER MAINTENANT',
                          title: requests.isEmpty && pendingToAnswer == 0
                              ? 'Continue a faire monter ton jeu'
                              : 'Des actions t attendent',
                          body: requests.isEmpty && pendingToAnswer == 0
                              ? 'Le plus simple pour progresser : poser tes pronos, ajouter un ami, puis faire vivre une ligue ou un duel.'
                              : '${requests.length} demande(s) d ami et $pendingToAnswer duel(s) demandent une reponse. Plus tu reponds vite, plus l espace social reste vivant.',
                          actionLabel: requests.isEmpty && pendingToAnswer == 0
                              ? 'PROCHAIN PALIER : FAIRE GRANDIR TON RESEAU'
                              : 'REPONDS D ABORD AUX DEMANDES EN ATTENTE',
                        ),
                        const SizedBox(height: 12),
                        _SocialActivityFeedCard(uid: uid),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsPanel() {
    return PronoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'AMIS',
            title: 'Ton carnet de contacts',
            subtitle:
                'Tout est ici : demandes recues, amis confirmes et ajout d un nouveau membre.',
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(uid),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final social =
                  (userData?['social'] as Map<String, dynamic>?) ?? const {};
              final friendNames =
                  (social['friendNames'] as Map<String, dynamic>?) ?? const {};
              final friendIds =
                  (social['friends'] as List?)?.whereType<String>().toList() ??
                  const <String>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.friendRequestsForUser(uid),
                builder: (context, receivedSnap) {
                  final received = receivedSnap.data?.docs ?? const [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FriendsSectionTitle(
                        title: 'Demandes recues',
                        count: received.length,
                      ),
                      const SizedBox(height: 8),
                      if (received.isEmpty)
                        const _FriendsEmptyLabel(text: 'Aucune demande recue.')
                      else
                        ...received.map((request) {
                          final data = request.data();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PendingFriendRow(
                              requestId: request.id,
                              currentUid: uid,
                              currentName: displayName,
                              otherUid: (data['fromUid'] ?? '').toString(),
                              otherName: (data['fromName'] ?? 'Utilisateur')
                                  .toString(),
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      _FriendsSectionTitle(
                        title: 'Amis confirmes',
                        count: friendIds.length,
                      ),
                      const SizedBox(height: 8),
                      if (friendIds.isEmpty)
                        const _FriendsEmptyLabel(
                          text: 'Aucun ami confirme pour le moment.',
                        )
                      else
                        ...friendIds.map((friendUid) {
                          final friendName =
                              (friendNames[friendUid] ?? 'Ami DVCR').toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CompactSocialRow(
                              title: friendName,
                              subtitle:
                                  'Utilise l onglet DUELS pour le defier sur un match.',
                              action: 'OK',
                              onTap: () {},
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 14),
          _SocialField(controller: _searchCtrl, label: 'Nom ou email'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final found = await PronoSocialService.searchUsers(
                _searchCtrl.text,
              );
              if (!mounted) return;
              setState(() {
                _searchResults = found
                    .where((user) => (user['uid'] ?? '') != uid)
                    .toList();
              });
            },
            child: _PrimaryAction(label: 'RECHERCHER UN MEMBRE'),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._searchResults.map((user) {
              final otherUid = (user['uid'] ?? '').toString();
              final otherName = PronoSocialService.resolveDisplayName(
                data: user,
                fallback: 'Membre DVCR',
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CompactSocialRow(
                  title: otherName,
                  subtitle: 'Envoyer une invitation a ce membre.',
                  action: otherUid == uid ? 'TOI' : 'AJOUTER',
                  onTap: otherUid.isEmpty || otherUid == uid
                      ? () {}
                      : () async {
                          await PronoSocialService.sendFriendRequest(
                            fromUid: uid,
                            fromName: displayName,
                            toUid: otherUid,
                            toName: otherName,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invitation envoyee a $otherName'),
                              backgroundColor: _kGreen,
                            ),
                          );
                        },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDuelsPanel(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.duelsForUser(uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final pending = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final active = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final finished = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (final doc in docs) {
          final data = doc.data();
          final status = (data['status'] ?? 'pending').toString();
          if (status == 'cancelled' || status == 'declined') {
            doc.reference.delete();
            continue;
          }
          if (status == 'pending') {
            pending.add(doc);
          } else if (status == 'in_progress') {
            active.add(doc);
          } else {
            finished.add(doc);
          }
        }

        return PronoSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PronoSectionTitle(
                eyebrow: 'DUELS',
                title: 'Tes face-a-face',
                subtitle:
                    'Les duels en attente, en cours et terminés sont bien séparés pour être lus facilement.',
              ),
              const SizedBox(height: 12),
              _FriendsSectionTitle(title: 'En attente', count: pending.length),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                const _FriendsEmptyLabel(text: 'Aucun duel en attente.')
              else
                ...pending.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DuelHubRow(
                      uid: uid,
                      duel: {'id': doc.id, ...doc.data()},
                      onTap: () {},
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _FriendsSectionTitle(title: 'En cours', count: active.length),
              const SizedBox(height: 8),
              if (active.isEmpty)
                const _FriendsEmptyLabel(text: 'Aucun duel en cours.')
              else
                ...active.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DuelHubRow(
                      uid: uid,
                      duel: {'id': doc.id, ...doc.data()},
                      onTap: () {},
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _FriendsSectionTitle(title: 'Termines', count: finished.length),
              const SizedBox(height: 8),
              if (finished.isEmpty)
                const _FriendsEmptyLabel(text: 'Aucun duel termine.')
              else
                ...finished
                    .take(8)
                    .map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DuelHubRow(
                          uid: uid,
                          duel: {'id': doc.id, ...doc.data()},
                          onTap: () {},
                        ),
                      ),
                    ),
              if (widget.onOpenMatches != null) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: widget.onOpenMatches,
                  child: _PrimaryAction(
                    label: 'ALLER AUX MATCHS A PRONOSTIQUER',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaguesPanel(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.leaguesForUser(uid),
      builder: (context, snap) {
        final leagues = snap.data?.docs ?? const [];
        return PronoSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PronoSectionTitle(
                eyebrow: 'LIGUES',
                title: 'Tes competitions privees',
                subtitle:
                    'Tu peux creer une ligue, en rejoindre une avec un code, puis retrouver la liste de tes ligues juste dessous.',
              ),
              const SizedBox(height: 12),
              _SocialField(
                controller: _leagueNameCtrl,
                label: 'Nom de la nouvelle ligue',
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _createLeagueInline,
                child: _PrimaryAction(label: 'CREER MA LIGUE'),
              ),
              const SizedBox(height: 14),
              _SocialField(
                controller: _leagueCodeCtrl,
                label: 'Code de ligue a rejoindre',
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _joinLeagueInline,
                child: _SecondaryAction(
                  label: _joiningLeague
                      ? 'REJOINDRE...'
                      : 'REJOINDRE AVEC LE CODE',
                ),
              ),
              const SizedBox(height: 14),
              _FriendsSectionTitle(
                title: 'Mes ligues actives',
                count: leagues.length,
              ),
              const SizedBox(height: 8),
              if (leagues.isEmpty)
                const _FriendsEmptyLabel(
                  text: 'Tu n es dans aucune ligue pour le moment.',
                )
              else
                ...leagues.map((league) {
                  final data = league.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CompactSocialRow(
                      title: (data['name'] ?? 'Ligue privee').toString(),
                      subtitle:
                          'Code ${(data['code'] ?? '-')} · ${(data['memberCount'] ?? 0)} membre(s)',
                      action: 'VOIR',
                      onTap: () => _showLeagueDetails(context, league.id, data),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildStructuredHub(context);

    // ignore: dead_code
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'QG COMMUNAUTE',
            title: 'Ligues, amis, duels',
            subtitle:
                'Toute la partie sociale vit ici: tu crees ta ligue, tu ajoutes des amis, tu acceptes des duels et tu fais monter la tension.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SocialActionCard(
                  icon: Icons.groups_rounded,
                  title: 'Ligues privees',
                  subtitle: 'Creer ou rejoindre une ligue',
                  onTap: () => _showLeagueDialog(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SocialActionCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Amis',
                  subtitle: 'Voir et gerer tes amis',
                  onTap: () => _showFriendsManager(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SocialActionCard(
                  icon: Icons.emoji_events_rounded,
                  title: 'Duels',
                  subtitle: 'Choisis un match pour lancer un duel',
                  onTap: () {
                    if (widget.onOpenMatches != null) {
                      widget.onOpenMatches!();
                      return;
                    }
                    _showDuelsHub(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(uid),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final social =
                  (userData?['social'] as Map<String, dynamic>?) ?? const {};
              final friends = (social['friends'] as List?)?.length ?? 0;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.leaguesForUser(uid),
                builder: (context, leagueSnap) {
                  final leagues = leagueSnap.data?.docs.length ?? 0;
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: PronoSocialService.friendRequestsForUser(uid),
                    builder: (context, requestSnap) {
                      final requests = requestSnap.data?.docs ?? const [];
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: PronoSocialService.duelsForUser(uid),
                        builder: (context, duelSnap) {
                          final duels = duelSnap.data?.docs.length ?? 0;
                          return PronoSectionCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MiniStat(
                                        label: 'AMIS',
                                        value: '$friends',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MiniStat(
                                        label: 'LIGUES',
                                        value: '$leagues',
                                      ),
                                    ),
                                    Expanded(
                                      child: _MiniStat(
                                        label: 'DUELS',
                                        value: '$duels',
                                      ),
                                    ),
                                  ],
                                ),
                                if (requests.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'DEMANDES EN ATTENTE',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _kMutedText,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  ...requests.take(2).map((request) {
                                    final data = request.data();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _PendingFriendRow(
                                        requestId: request.id,
                                        currentUid: uid,
                                        currentName: displayName,
                                        otherUid: (data['fromUid'] ?? '')
                                            .toString(),
                                        otherName:
                                            (data['fromName'] ?? 'Utilisateur')
                                                .toString(),
                                      ),
                                    );
                                  }),
                                ],
                                if ((leagueSnap.data?.docs ?? const [])
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'TES LIGUES ACTIVES',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _kMutedText,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  ...leagueSnap.data!.docs.take(2).map((
                                    league,
                                  ) {
                                    final data = league.data();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _CompactSocialRow(
                                        title: (data['name'] ?? 'Ligue privee')
                                            .toString(),
                                        subtitle:
                                            'Code ${(data['code'] ?? '-')} · ${(data['memberCount'] ?? 0)} membre(s)',
                                        action: 'VOIR',
                                        onTap: () => _showLeagueDetails(
                                          context,
                                          league.id,
                                          data,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                if ((duelSnap.data?.docs ?? const [])
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'DUELS CHAUDS',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _kMutedText,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  ...duelSnap.data!.docs
                                      .where((duel) {
                                        final status =
                                            (duel.data()['status'] ?? '')
                                                .toString();
                                        // Supprimer immédiatement les duels annulés/refusés
                                        if (status == 'cancelled' ||
                                            status == 'declined') {
                                          duel.reference.delete();
                                          return false;
                                        }
                                        return true;
                                      })
                                      .take(5)
                                      .map((duel) {
                                        final data = duel.data();
                                        final status =
                                            (data['status'] ?? 'pending')
                                                .toString();
                                        final isPending = status == 'pending';
                                        final isOpponent =
                                            (data['opponentUid'] ?? '') == uid;
                                        final myStatus =
                                            (data['winnerUid'] == uid)
                                            ? 'GAGNE'
                                            : (status == 'draw')
                                            ? 'NUL'
                                            : (status == 'won')
                                            ? 'PERDU'
                                            : (status == 'cancelled')
                                            ? 'ANNULE'
                                            : (status == 'declined')
                                            ? 'REFUSE'
                                            : (status == 'in_progress')
                                            ? 'EN COURS'
                                            : 'EN ATTENTE';
                                        // Duel en attente dont l'utilisateur est l'opposant → ACCEPTER/REFUSER
                                        if (isPending && isOpponent) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: _kSurfaceMuted,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: _kGold.withAlpha(80),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .sports_soccer_rounded,
                                                        color: _kGold,
                                                        size: 13,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          (data['matchLabel'] ??
                                                                  'Duel')
                                                              .toString(),
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: _kText,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${data['ownerName'] ?? 'Joueur'} te défie !',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: _kGold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              PronoSocialService.acceptDuel(
                                                                duelId: duel.id,
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFF4CAF50,
                                                                  ).withAlpha(
                                                                    22,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFF4CAF50,
                                                                    ).withAlpha(
                                                                      80,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'ACCEPTER',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color:
                                                                    const Color(
                                                                      0xFF4CAF50,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              PronoSocialService.declineDuel(
                                                                duelId: duel.id,
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: _kRed
                                                                  .withAlpha(
                                                                    18,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color: _kRed
                                                                    .withAlpha(
                                                                      70,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'REFUSER',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: _kRed,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: _CompactSocialRow(
                                            title:
                                                (data['matchLabel'] ?? 'Duel')
                                                    .toString(),
                                            subtitle:
                                                '${data['ownerName'] ?? 'Membre'} vs ${data['opponentName'] ?? 'Membre'} · $myStatus',
                                            action: 'DETAIL',
                                            onTap: () => _showDuelDetails(
                                              context,
                                              duel.id,
                                            ),
                                          ),
                                        );
                                      }),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),

          // ── Amis avec présence + Défier ───────────────────────────────────
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(uid),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final social =
                  (userData?['social'] as Map<String, dynamic>?) ?? const {};
              final friendNames =
                  (social['friendNames'] as Map<String, dynamic>?) ?? const {};
              final friends =
                  (social['friends'] as List?)?.whereType<String>().toList() ??
                  const <String>[];

              if (friends.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  PronoSectionCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PronoSectionTitle(
                          eyebrow: 'MES AMIS',
                          title: 'Ton premier cercle',
                          subtitle:
                              'Repere qui est dispo, relance un ami et transforme un match en duel en un clic.',
                        ),
                        const SizedBox(height: 10),
                        ...friends.asMap().entries.map((entry) {
                          final index = entry.key;
                          final friendUid = entry.value;
                          final name = (friendNames[friendUid] ?? 'Ami DVCR')
                              .toString();
                          final initials = name.trim().isNotEmpty
                              ? name
                                    .trim()
                                    .split(' ')
                                    .map((w) => w.isNotEmpty ? w[0] : '')
                                    .take(2)
                                    .join()
                                    .toUpperCase()
                              : '?';
                          return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(friendUid)
                                .snapshots(),
                            builder: (context, fSnap) {
                              final fData = fSnap.data?.data();
                              final isOnline =
                                  fData?['isOnline'] as bool? ?? false;
                              final lastSeen = fData?['lastSeen'] as Timestamp?;
                              final online =
                                  isOnline &&
                                  lastSeen != null &&
                                  DateTime.now()
                                          .difference(lastSeen.toDate())
                                          .inMinutes <
                                      5;
                              return Container(
                                margin: EdgeInsets.only(
                                  bottom: index == friends.length - 1 ? 0 : 8,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _kSurfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _kBorder),
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: _kGold.withAlpha(20),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              initials,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _kGold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 11,
                                            height: 11,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: online
                                                  ? const Color(0xFF4CAF50)
                                                  : Colors.white24,
                                              border: Border.all(
                                                color: pronoSurface,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _kText,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _friendPresenceLabel(
                                              online: online,
                                              lastSeen: lastSeen,
                                            ),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: online
                                                  ? const Color(0xFF4CAF50)
                                                  : _kMutedText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _challengeFriend(friendUid, name),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _kGold.withAlpha(18),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: _kGold.withAlpha(70),
                                          ),
                                        ),
                                        child: Text(
                                          'DEFIER',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: _kGold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Stats duels W/N/D ─────────────────────────────────────────────
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelsForUser(uid),
            builder: (context, duelSnap) {
              final duels = duelSnap.data?.docs ?? const [];
              int wins = 0, draws = 0, losses = 0;
              for (final d in duels) {
                final data = d.data();
                if (data['winnerUid'] == uid)
                  wins++;
                else if (data['loserUid'] == uid)
                  losses++;
                else if (data['status'] == 'draw')
                  draws++;
              }
              final total = wins + draws + losses;
              if (total == 0) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: pronoSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATS DUELS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kGold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ton historique d affrontements montre ta forme dans les matchs en un contre un.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _kMutedText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _WDLChip(
                              label: 'V',
                              count: wins,
                              color: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 8),
                            _WDLChip(
                              label: 'N',
                              count: draws,
                              color: const Color(0xFFFF9800),
                            ),
                            const SizedBox(width: 8),
                            _WDLChip(label: 'D', count: losses, color: _kRed),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              if (wins > 0)
                                Flexible(
                                  flex: wins,
                                  child: Container(
                                    height: 6,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              if (draws > 0)
                                Flexible(
                                  flex: draws,
                                  child: Container(
                                    height: 6,
                                    color: const Color(0xFFFF9800),
                                  ),
                                ),
                              if (losses > 0)
                                Flexible(
                                  flex: losses,
                                  child: Container(height: 6, color: _kRed),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Recherche d'amis directe ──────────────────────────────────────
          const SizedBox(height: 14),
          PronoSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: PronoSectionTitle(
                    eyebrow: 'TROUVER DES AMIS',
                    title: 'Agrandis ton reseau',
                    subtitle:
                        'Cherche un membre, envoie une invitation et transforme ton classement en vrai terrain de rivalites.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(color: _kText, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un joueur…',
                            hintStyle: TextStyle(
                              color: _kMutedText,
                              fontSize: 13,
                            ),
                            prefixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _kGold,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.search_rounded,
                                    color: _kMutedText,
                                    size: 18,
                                  ),
                            filled: true,
                            fillColor: _kSurfaceMuted,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                              borderSide: BorderSide(
                                color: _kGold.withAlpha(120),
                              ),
                            ),
                          ),
                          onChanged: _searchUsers,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    decoration: BoxDecoration(
                      color: _kSurfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      children: _searchResults.take(6).map((u) {
                        final name = PronoSocialService.resolveDisplayName(
                          data: u,
                          fallback: 'Joueur',
                        );
                        final otherUid = (u['uid'] ?? '').toString();
                        return GestureDetector(
                          onTap: () async {
                            await PronoSocialService.sendFriendRequest(
                              fromUid: uid,
                              fromName: displayName,
                              toUid: otherUid,
                              toName: name,
                            );
                            if (!context.mounted || !mounted) return;
                            setState(() {
                              _searchResults = [];
                              _searchCtrl.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invitation envoyée à $name'),
                                backgroundColor: _kGreen,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _kGold.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _kGold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _kText,
                                    ),
                                  ),
                                ),
                                Text(
                                  'INVITER',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _kGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Rejoindre une ligue par code ──────────────────────────────────
          PronoSectionCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PronoSectionTitle(
                  eyebrow: 'REJOINDRE UNE LIGUE',
                  title: 'Entre par un code',
                  subtitle:
                      'Colle un code de ligue et bascule instantanément dans la compétition entre potes.',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _leagueCodeCtrl,
                        style: TextStyle(color: _kText, fontSize: 13),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Code de la ligue…',
                          hintStyle: TextStyle(
                            color: _kMutedText,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.tag_rounded,
                            color: _kMutedText,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _kSurfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
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
                            borderSide: BorderSide(
                              color: _kGold.withAlpha(120),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _joiningLeague
                          ? null
                          : () async {
                              final code = _leagueCodeCtrl.text
                                  .trim()
                                  .toUpperCase();
                              if (code.isEmpty) return;
                              setState(() => _joiningLeague = true);
                              try {
                                await PronoSocialService.joinLeague(
                                  uid: uid,
                                  displayName: displayName,
                                  code: code,
                                );
                                if (!context.mounted || !mounted) return;
                                _leagueCodeCtrl.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ligue rejointe !'),
                                    backgroundColor: Color(0xFF0A4438),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Code invalide ou ligue introuvable',
                                    ),
                                    backgroundColor: _kRed,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _joiningLeague = false);
                                }
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _kGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _joiningLeague
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'REJOINDRE',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showLeagueDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      backgroundColor: pronoSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                'Ligues privees',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cree ton espace entre potes ou rejoins une ligue existante avec un code.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _kMutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _SocialField(controller: nameCtrl, label: 'Nom de la ligue'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final code = await PronoSocialService.createLeague(
                    ownerUid: uid,
                    ownerName: displayName,
                    name: name,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ligue creee. Code invitation : $code'),
                        backgroundColor: _kGreen,
                      ),
                    );
                  }
                },
                child: _PrimaryAction(label: 'CREER MA LIGUE'),
              ),
              const SizedBox(height: 18),
              _SocialField(controller: codeCtrl, label: 'Code a rejoindre'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final joinCode = codeCtrl.text.trim().toUpperCase();
                  final ok = await PronoSocialService.joinLeague(
                    uid: uid,
                    displayName: displayName,
                    code: joinCode,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Ligue rejointe avec succes.'
                              : 'Code de ligue introuvable.',
                        ),
                        backgroundColor: ok ? _kGreen : _kRed,
                      ),
                    );
                  }
                },
                child: _SecondaryAction(label: 'REJOINDRE AVEC LE CODE'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLeagueDetails(
    BuildContext context,
    String leagueId,
    Map<String, dynamic> league,
  ) async {
    final memberIds = (league['memberIds'] as List?) ?? const [];
    final ownerUid = (league['ownerUid'] ?? '').toString();
    await showModalBottomSheet(
      context: context,
      backgroundColor: pronoSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            bool sedanOnly = false;
            return FractionallySizedBox(
              heightFactor: 0.88,
              child: StatefulBuilder(
                builder: (ctx, setInner) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: FutureBuilder<List<LeagueStandingEntry>>(
                      future: PronoSocialService.leagueLeaderboardFiltered(
                        memberIds,
                        sedanOnly: sedanOnly,
                      ),
                      builder: (context, snap) {
                        final rows = snap.data ?? const <LeagueStandingEntry>[];
                        final loading =
                            snap.connectionState == ConnectionState.waiting;
                        final leagueName = (league['name'] ?? 'Ligue privee')
                            .toString();
                        final leagueCode = (league['code'] ?? '-').toString();
                        final memberCount =
                            (league['memberCount'] as num?)?.toInt() ??
                            memberIds.length;
                        final myIndex = rows.indexWhere(
                          (row) => row.uid == uid,
                        );
                        final me = myIndex >= 0 ? rows[myIndex] : null;
                        final leader = rows.isNotEmpty ? rows.first : null;
                        final myRankLabel = myIndex >= 0
                            ? '#${myIndex + 1}'
                            : 'A classer';
                        final gapToLeader =
                            (leader != null &&
                                me != null &&
                                leader.uid != me.uid)
                            ? leader.points - me.points
                            : 0;
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Handle ──────────────────────────────────
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: _kBorder,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),

                              // ── En-tête sobre ───────────────────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          leagueName,
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: _kText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Code : $leagueCode',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _kMutedText,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Rang
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: myIndex == 0
                                          ? _kGold.withAlpha(20)
                                          : _kSurfaceMuted,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: myIndex == 0
                                            ? _kGold.withAlpha(80)
                                            : _kBorder,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'RANG',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: _kMutedText,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          myRankLabel,
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: myIndex == 0
                                                ? _kGold
                                                : _kText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // ── Métriques rapides ────────────────────────
                              Row(
                                children: [
                                  _LeagueSummaryStat(
                                    label: 'MEMBRES',
                                    value: '$memberCount',
                                    accent: _kText,
                                  ),
                                  const SizedBox(width: 8),
                                  _LeagueSummaryStat(
                                    label: 'LEADER',
                                    value: leader?.displayName ?? '—',
                                    accent: _kGold,
                                  ),
                                  const SizedBox(width: 8),
                                  _LeagueSummaryStat(
                                    label: 'ÉCART',
                                    value: me == null
                                        ? '—'
                                        : gapToLeader <= 0
                                        ? '1er'
                                        : '-$gapToLeader',
                                    accent: gapToLeader <= 3
                                        ? _kGold
                                        : _kMutedText,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // ── Toggle filtre ────────────────────────────
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: _kSurfaceMuted,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _kBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setInner(() => sedanOnly = false),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !sedanOnly
                                                ? _kGold.withAlpha(22)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: !sedanOnly
                                                  ? _kGold
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Text(
                                            'TOUS LES PRONOS',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: !sedanOnly
                                                  ? _kGold
                                                  : _kMutedText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setInner(() => sedanOnly = true),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: sedanOnly
                                                ? _kGold.withAlpha(22)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: sedanOnly
                                                  ? _kGold
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Text(
                                            'SEDAN',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: sedanOnly
                                                  ? _kGold
                                                  : _kMutedText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // ── Classement ───────────────────────────────
                              if (loading)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(
                                      color: _kGold,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else if (rows.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Aucun classement pour le moment.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _kMutedText,
                                    ),
                                  ),
                                )
                              else
                                ...rows.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  final isMe = row.uid == uid;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? _kGold.withAlpha(12)
                                          : _kSurfaceMuted,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMe
                                            ? _kGold.withAlpha(60)
                                            : _kBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            index == 0
                                                ? '🥇'
                                                : index == 1
                                                ? '🥈'
                                                : index == 2
                                                ? '🥉'
                                                : '${index + 1}',
                                            style: GoogleFonts.barlowCondensed(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: index == 0
                                                  ? _kGold
                                                  : _kMutedText,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row.displayName +
                                                    (isMe ? ' (moi)' : ''),
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isMe ? _kGold : _kText,
                                                ),
                                              ),
                                              Text(
                                                '${row.totalPredictions} pronos · ${row.exactScores} exacts',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: _kMutedText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${row.points} pts',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: index == 0 ? _kGold : _kText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 16),
                              _LeagueHistorySection(memberIds: memberIds),
                              if (ownerUid == uid) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () async {
                                    await PronoSocialService.deleteLeague(
                                      leagueId: leagueId,
                                      ownerUid: uid,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  child: _SecondaryAction(
                                    label: 'SUPPRIMER LA LIGUE',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDuelDetails(BuildContext context, String duelId) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: pronoSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelStream(duelId),
            builder: (context, snap) {
              final duel = snap.data?.data();
              if (duel == null) {
                return Text(
                  'Duel introuvable',
                  style: GoogleFonts.inter(color: Colors.white),
                );
              }
              final status = (duel['status'] ?? 'pending').toString();
              final label = status == 'won'
                  ? ((duel['winnerUid'] == uid) ? 'GAGNE' : 'PERDU')
                  : status == 'draw'
                  ? 'NUL'
                  : status == 'cancelled'
                  ? 'ANNULE'
                  : status == 'in_progress'
                  ? 'EN COURS'
                  : 'EN ATTENTE';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _kBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    (duel['matchLabel'] ?? 'Duel prive').toString(),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusPill(label: label),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LeagueSummaryStat(
                          label: 'STATUT',
                          value: label,
                          accent: label == 'GAGNE'
                              ? _kGreen
                              : label == 'PERDU'
                              ? _kRed
                              : _kGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LeagueSummaryStat(
                          label: 'RECOMPENSE',
                          value: '+${duel['duelXpReward'] ?? 3} XP',
                          accent: _kGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DuelLine(
                    name: (duel['ownerName'] ?? 'Joueur 1').toString(),
                    score: (duel['ownerScore'] ?? '-').toString(),
                    points: duel['ownerPoints']?.toString() ?? '-',
                  ),
                  const SizedBox(height: 8),
                  _DuelLine(
                    name: (duel['opponentName'] ?? 'Joueur 2').toString(),
                    score: (duel['opponentScore'] ?? '-').toString(),
                    points: duel['opponentPoints']?.toString() ?? '-',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Recompense duel : +${duel['duelXpReward'] ?? 3} XP',
                    style: GoogleFonts.inter(fontSize: 12, color: _kGold),
                  ),
                  if ((duel['ownerUid'] ?? '') == uid &&
                      status != 'won' &&
                      status != 'draw' &&
                      status != 'cancelled') ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        await FirebaseFirestore.instance
                            .collection('prono_duels')
                            .doc(duelId)
                            .delete();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: _SecondaryAction(label: 'SUPPRIMER LE DUEL'),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showDuelsHub(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: pronoSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelsForUser(uid),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? const [];
              final pending = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final active = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final finished = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              for (final doc in docs) {
                final data = doc.data();
                final status = (data['status'] ?? 'pending').toString();
                // Supprimer immédiatement les duels annulés ou refusés
                if (status == 'cancelled' || status == 'declined') {
                  doc.reference.delete();
                  continue;
                }
                if (status == 'pending') {
                  pending.add(doc);
                } else if (status == 'in_progress') {
                  active.add(doc);
                } else {
                  finished.add(doc);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _kBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Mes duels',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Suis tes duels et choisis un match pour en lancer un nouveau.',
                    style: GoogleFonts.inter(fontSize: 12, color: _kMutedText),
                  ),
                  const SizedBox(height: 14),
                  _FriendsSectionTitle(
                    title: 'En attente',
                    count: pending.length,
                  ),
                  const SizedBox(height: 8),
                  if (pending.isEmpty)
                    const _FriendsEmptyLabel(text: 'Aucun duel en attente.')
                  else
                    ...pending
                        .take(5)
                        .map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DuelHubRow(
                              uid: uid,
                              duel: {'id': doc.id, ...doc.data()},
                              onTap: () => _showDuelDetails(context, doc.id),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  _FriendsSectionTitle(title: 'En cours', count: active.length),
                  const SizedBox(height: 8),
                  if (active.isEmpty)
                    const _FriendsEmptyLabel(text: 'Aucun duel en cours.')
                  else
                    ...active
                        .take(5)
                        .map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DuelHubRow(
                              uid: uid,
                              duel: {'id': doc.id, ...doc.data()},
                              onTap: () => _showDuelDetails(context, doc.id),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  _FriendsSectionTitle(
                    title: 'Termines',
                    count: finished.length,
                  ),
                  const SizedBox(height: 8),
                  if (finished.isEmpty)
                    const _FriendsEmptyLabel(text: 'Aucun duel termine.')
                  else
                    ...finished.take(5).map((doc) {
                      final data = doc.data();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DuelHubRow(
                          uid: uid,
                          duel: {'id': doc.id, ...data},
                          onTap: () => _showDuelDetails(context, doc.id),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Choisis un match ci-dessous puis appuie sur DEFI AMI.',
                          ),
                          backgroundColor: _kGreen,
                        ),
                      );
                    },
                    child: _PrimaryAction(label: 'CHOISIR UN MATCH'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showFriendsManager(BuildContext context) async {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    await showModalBottomSheet(
      context: context,
      backgroundColor: pronoSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _kBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Mes amis',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gere ton reseau, tes invitations et tes amis confirmes depuis un seul panneau.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _kMutedText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: PronoSocialService.userDocStream(uid),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data();
                      final social =
                          (userData?['social'] as Map<String, dynamic>?) ??
                          const {};
                      final friendNames =
                          (social['friendNames'] as Map<String, dynamic>?) ??
                          const {};
                      final friendIds =
                          (social['friends'] as List?)
                              ?.whereType<String>()
                              .toList() ??
                          const <String>[];
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: PronoSocialService.friendRequestsForUser(uid),
                        builder: (context, receivedSnap) {
                          final received = receivedSnap.data?.docs ?? const [];
                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream:
                                PronoSocialService.sentFriendRequestsForUser(
                                  uid,
                                ),
                            builder: (context, sentSnap) {
                              final sent = sentSnap.data?.docs ?? const [];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FriendsSectionTitle(
                                      title: 'Demandes recues',
                                      count: received.length,
                                    ),
                                    const SizedBox(height: 8),
                                    if (received.isEmpty)
                                      _FriendsEmptyLabel(
                                        text: 'Aucune demande recue.',
                                      )
                                    else
                                      ...received.map((request) {
                                        final data = request.data();
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: _PendingFriendRow(
                                            requestId: request.id,
                                            currentUid: uid,
                                            currentName: displayName,
                                            otherUid: (data['fromUid'] ?? '')
                                                .toString(),
                                            otherName:
                                                (data['fromName'] ??
                                                        'Utilisateur')
                                                    .toString(),
                                          ),
                                        );
                                      }),
                                    const SizedBox(height: 12),
                                    _FriendsSectionTitle(
                                      title: 'Invitations envoyees',
                                      count: sent.length,
                                    ),
                                    const SizedBox(height: 8),
                                    if (sent.isEmpty)
                                      _FriendsEmptyLabel(
                                        text: 'Aucune invitation en attente.',
                                      )
                                    else
                                      ...sent.map((request) {
                                        final data = request.data();
                                        final targetName =
                                            (data['toName'] ?? 'Utilisateur')
                                                .toString();
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kSurfaceMuted,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(color: _kBorder),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  targetName,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _kText,
                                                  ),
                                                ),
                                              ),
                                              _ChipLabel(
                                                label: 'EN ATTENTE',
                                                color: _kGold,
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    const SizedBox(height: 12),
                                    _FriendsSectionTitle(
                                      title: 'Amis confirmes',
                                      count: friendIds.length,
                                    ),
                                    const SizedBox(height: 8),
                                    if (friendIds.isEmpty)
                                      _FriendsEmptyLabel(
                                        text:
                                            'Aucun ami confirme pour le moment.',
                                      )
                                    else
                                      ...friendIds.map((friendUid) {
                                        final friendName =
                                            (friendNames[friendUid] ??
                                                    'Ami DVCR')
                                                .toString();
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kSurfaceMuted,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(color: _kBorder),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  friendName,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _kText,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  await PronoSocialService.removeFriend(
                                                    currentUid: uid,
                                                    otherUid: friendUid,
                                                  );
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _kRed.withAlpha(18),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: _kRed.withAlpha(
                                                        90,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'RETIRER',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: _kRed,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  _SocialField(controller: searchCtrl, label: 'Nom ou email'),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final found = await PronoSocialService.searchUsers(
                        searchCtrl.text,
                      );
                      setModalState(() => results = found);
                    },
                    child: _PrimaryAction(label: 'RECHERCHER'),
                  ),
                  const SizedBox(height: 12),
                  ...results.map((user) {
                    final otherUid = (user['uid'] ?? '').toString();
                    final otherName = PronoSocialService.resolveDisplayName(
                      data: user,
                      fallback: 'Membre DVCR',
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherName.isEmpty ? 'Membre DVCR' : otherName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: otherUid.isEmpty || otherUid == uid
                                ? null
                                : () async {
                                    await PronoSocialService.sendFriendRequest(
                                      fromUid: uid,
                                      fromName: displayName,
                                      toUid: otherUid,
                                      toName: otherName,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Invitation envoyee a $otherName',
                                          ),
                                          backgroundColor: _kGreen,
                                        ),
                                      );
                                    }
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _kGold.withAlpha(24),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _kGold.withAlpha(90)),
                              ),
                              child: Text(
                                otherUid == uid ? 'TOI' : 'AJOUTER',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _kGold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SocialActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SocialActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _kGold.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _kGold, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 10, color: _kMutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _kGold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kMutedText,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSocialRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _CompactSocialRow({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kSurfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: _kMutedText),
                  ),
                ],
              ),
            ),
            Text(
              action,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kGold.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withAlpha(100)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _kGold,
        ),
      ),
    );
  }
}

class _DuelLine extends StatelessWidget {
  final String name;
  final String score;
  final String points;

  const _DuelLine({
    required this.name,
    required this.score,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
          Text(
            score,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _kGold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$points pt',
            style: GoogleFonts.inter(fontSize: 11, color: _kMutedText),
          ),
        ],
      ),
    );
  }
}

class _PendingFriendRow extends StatelessWidget {
  final String requestId;
  final String currentUid;
  final String currentName;
  final String otherUid;
  final String otherName;

  const _PendingFriendRow({
    required this.requestId,
    required this.currentUid,
    required this.currentName,
    required this.otherUid,
    required this.otherName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$otherName veut devenir ton ami',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await PronoSocialService.acceptFriendRequest(
                requestId: requestId,
                currentUid: currentUid,
                currentName: currentName,
                otherUid: otherUid,
                otherName: otherName,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ACCEPTER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await PronoSocialService.declineFriendRequest(
                requestId: requestId,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pronoSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                'REFUSER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kMutedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _FriendsSectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: 1.1,
            ),
          ),
        ),
        _ChipLabel(label: '$count', color: _kGold),
      ],
    );
  }
}

class _FriendsEmptyLabel extends StatelessWidget {
  final String text;

  const _FriendsEmptyLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, color: _kMutedText),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _DuelHubRow extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> duel;
  final VoidCallback onTap;

  const _DuelHubRow({
    required this.uid,
    required this.duel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = (duel['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final isOpponent = (duel['opponentUid'] ?? '') == uid;
    final label = status == 'won'
        ? ((duel['winnerUid'] == uid) ? 'GAGNE' : 'PERDU')
        : status == 'draw'
        ? 'NUL'
        : status == 'cancelled'
        ? 'ANNULE'
        : status == 'declined'
        ? 'REFUSE'
        : status == 'in_progress'
        ? 'EN COURS'
        : 'EN ATTENTE';

    // Si duel en attente et utilisateur est l'opposant → card avec Accept/Decline
    if (isPending && isOpponent) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGold.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: _kGold,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (duel['matchLabel'] ?? 'Duel').toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'DUEL EN ATTENTE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${duel['ownerName'] ?? 'Joueur'} te défie !',
              style: GoogleFonts.inter(fontSize: 11, color: _kGold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => PronoSocialService.acceptDuel(
                      duelId: duel['id']?.toString() ?? '',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withAlpha(80),
                        ),
                      ),
                      child: Text(
                        'ACCEPTER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => PronoSocialService.declineDuel(
                      duelId: duel['id']?.toString() ?? '',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _kRed.withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kRed.withAlpha(70)),
                      ),
                      child: Text(
                        'REFUSER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: label == 'EN COURS'
                ? _kGold.withAlpha(70)
                : label == 'GAGNE'
                ? _kGreen.withAlpha(90)
                : _kBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: label == 'EN COURS'
                    ? _kGold.withAlpha(18)
                    : label == 'GAGNE'
                    ? _kGreen.withAlpha(18)
                    : Colors.white.withAlpha(4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                label == 'EN COURS'
                    ? Icons.bolt_rounded
                    : label == 'GAGNE'
                    ? Icons.emoji_events_rounded
                    : label == 'PERDU'
                    ? Icons.close_rounded
                    : Icons.sports_martial_arts_rounded,
                size: 17,
                color: label == 'EN COURS'
                    ? _kGold
                    : label == 'GAGNE'
                    ? _kGreen
                    : label == 'PERDU'
                    ? _kRed
                    : Colors.white70,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (duel['matchLabel'] ?? 'Duel').toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${duel['ownerName'] ?? 'Membre'} vs ${duel['opponentName'] ?? 'Membre'}',
                    style: GoogleFonts.inter(fontSize: 11, color: _kGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(label: label),
          ],
        ),
      ),
    );
  }
}

class _SocialField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _SocialField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: _kText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: _kMutedText, fontSize: 12),
        filled: true,
        fillColor: _kSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kGold),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;

  const _PrimaryAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kGold,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _kGold.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;

  const _SecondaryAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _kText,
        ),
      ),
    );
  }
}

class _LegacyCommunityPronoTab extends StatelessWidget {
  final String uid;
  final String displayName;
  final VoidCallback onOpenMatches;

  const _LegacyCommunityPronoTab({
    required this.uid,
    required this.displayName,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _CommunityPulseCard(uid: uid),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: _CommunityModesCard(),
        ),
        const SizedBox(height: 14),
        _PronoSocialHub(
          uid: uid,
          displayName: displayName,
          onOpenMatches: onOpenMatches,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _CommunityLeaderboardSection(currentUid: uid),
        ),
      ],
    );
  }
}

class _LegacyCommunityModesCard extends StatelessWidget {
  const _LegacyCommunityModesCard();

  @override
  Widget build(BuildContext context) {
    return PronoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'MECANIQUES SOCIALES',
            title: 'Plusieurs façons de jouer',
            subtitle:
                'Le systeme prono doit rester simple a prendre en main mais riche a vivre: collectif permanent, cercle prive, duel cible et reseau d’amis.',
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: PronoMetricChip(
                  label: 'CLASSEMENT',
                  value: 'Global',
                  accent: pronoGold,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: PronoMetricChip(
                  label: 'LIGUES',
                  value: 'Entre potes',
                  accent: pronoGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                child: PronoMetricChip(
                  label: 'DUELS',
                  value: 'Double accord',
                  accent: pronoText,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: PronoMetricChip(
                  label: 'AMIS',
                  value: 'Rivalites',
                  accent: pronoRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegacyCommunityPulseCard extends StatelessWidget {
  final String uid;

  const _LegacyCommunityPulseCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.userDocStream(uid),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final social =
            (userData?['social'] as Map<String, dynamic>?) ?? const {};
        final friends = (social['friends'] as List?)?.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.leaguesForUser(uid),
          builder: (context, leagueSnap) {
            final leagues = leagueSnap.data?.docs ?? const [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: PronoSocialService.duelsForUser(uid),
              builder: (context, duelSnap) {
                final duels = duelSnap.data?.docs ?? const [];
                final activeDuels = duels.where((doc) {
                  final status = (doc.data()['status'] ?? '').toString();
                  return status == 'pending' ||
                      status == 'in_progress' ||
                      status == 'won' ||
                      status == 'draw';
                }).length;

                return PronoSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PronoSectionTitle(
                        eyebrow: 'COMMUNAUTE ACTIVE',
                        title: 'Le vestiaire prono',
                        subtitle:
                            'Gere tes ligues, relance tes amis et transforme les matchs Sedan en rendez-vous communautaires plus vivants.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'LIGUES',
                              value: '${leagues.length}',
                            ),
                          ),
                          Expanded(
                            child: _MiniStat(label: 'AMIS', value: '$friends'),
                          ),
                          Expanded(
                            child: _MiniStat(
                              label: 'DUELS',
                              value: '$activeDuels',
                            ),
                          ),
                        ],
                      ),
                      if (leagues.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIGUE A SURVEILLER',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _kMutedText,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (leagues.first.data()['name'] ?? 'Ligue privee')
                                    .toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${leagues.first.data()['memberCount'] ?? 0} membres - code ${leagues.first.data()['code'] ?? '-'}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _kMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LegacyCommunityLeaderboardSection extends StatelessWidget {
  final String currentUid;

  const _LegacyCommunityLeaderboardSection({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .orderBy('points', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final topThree = docs.take(3).toList();

        return PronoSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLASSEMENT GÉNÉRAL',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kGold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Retrouve ici les meilleurs joueurs et ton rang dans la communauté.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _kMutedText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (topThree.isNotEmpty) ...[
                Row(
                  children: topThree.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final d = entry.value.data() as Map<String, dynamic>;
                    final isMe = d['uid'] == currentUid;
                    final medalColor = rank == 1
                        ? const Color(0xFFFFD700)
                        : rank == 2
                        ? const Color(0xFFC0C0C0)
                        : const Color(0xFFCD7F32);
                    return Expanded(
                      child: GestureDetector(
                        onTap: isMe
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(
                                    uid: d['uid'] as String? ?? entry.value.id,
                                    displayName: d['displayName'] as String?,
                                  ),
                                ),
                              ),
                        child: Container(
                          margin: EdgeInsets.only(right: rank == 3 ? 0 : 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe
                                ? medalColor.withAlpha(20)
                                : _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMe ? medalColor : _kBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '#$rank',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: medalColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (d['displayName'] ?? 'Membre').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d['points'] ?? 0} pts',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: medalColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (docs.isEmpty)
                Text(
                  'Le classement apparaitra ici dès que la saison prendra vie.',
                  style: GoogleFonts.inter(fontSize: 12, color: _kGrey),
                )
              else
                ...docs.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final d = entry.value.data() as Map<String, dynamic>;
                  final isMe = d['uid'] == currentUid;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? _kGold.withAlpha(14) : _kSurfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMe ? _kGold.withAlpha(90) : _kBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$rank',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isMe ? _kGold : _kText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (d['displayName'] ?? 'Membre').toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d['totalPredictions'] ?? 0} pronos · ${d['exactScores'] ?? 0} exacts',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _kMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${d['points'] ?? 0} pts',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isMe ? _kGold : _kText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _LeagueHistorySection extends StatelessWidget {
  final List<dynamic> memberIds;

  const _LeagueHistorySection({required this.memberIds});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeagueHistoryMatch>>(
      future: PronoSocialService.leagueHistory(memberIds),
      builder: (context, snap) {
        final history = snap.data ?? const <LeagueHistoryMatch>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historique de la ligue',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kGold,
              ),
            ),
            const SizedBox(height: 10),
            if (history.isEmpty)
              Text(
                'Pas encore d\'historique a afficher entre les membres.',
                style: GoogleFonts.inter(fontSize: 12, color: _kGrey),
              )
            else
              ...history.map((match) {
                final dateLabel = match.matchDate == null
                    ? '-'
                    : DateFormat(
                        'dd MMM · HH:mm',
                        'fr_FR',
                      ).format(match.matchDate!);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kSurfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${match.team1} vs ${match.team2}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${match.predictions.length} membre(s) ont joue ce match',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _kMutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pronoSurface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Text(
                              dateLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _kGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...match.predictions.map((pred) {
                        final pointsLabel = pred.points == null
                            ? 'en attente'
                            : '+${pred.points} pt${pred.points == 1 ? '' : 's'}';
                        final pointsColor = pred.points == null
                            ? _kGrey
                            : _kGold;
                        final predictionLabel = pred.points == null
                            ? 'prono masque'
                            : '${pred.score1Pred}-${pred.score2Pred}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pred.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _kText,
                                  ),
                                ),
                              ),
                              Text(
                                predictionLabel,
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: pred.points == null ? _kGrey : _kText,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: pointsColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: pointsColor.withAlpha(70),
                                  ),
                                ),
                                child: Text(
                                  pointsLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: pointsColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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

class _LeagueSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _LeagueSummaryStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: pronoSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueNarrativeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _LeagueNarrativeChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kGold.withAlpha(24) : _kSurfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? _kGold : _kBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: active ? _kGold : _kText,
          ),
        ),
      ),
    );
  }
}

class _PronoSeasonInsightsCard extends StatelessWidget {
  final String uid;

  const _PronoSeasonInsightsCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.userDocStream(uid),
      builder: (context, userSnap) {
        final globalXp = (userSnap.data?.data()?['xp'] as num?)?.toInt();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.leaderboardEntryStream(uid),
          builder: (context, boardSnap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: PronoSocialService.pronoConfigStream(),
              builder: (context, configSnap) {
                final config = configSnap.data?.data();
                final data =
                    boardSnap.data?.data() ?? const <String, dynamic>{};
                final step = PronoSocialService.levelStepXp(config: config);
                final xp =
                    globalXp ??
                    PronoSocialService.xpFromStatsWithConfig(
                      data,
                      config: config,
                    );
                final level = step > 0 ? (xp ~/ step) + 1 : 1;
                final xpRemaining = (level * step) - xp;
                return PronoSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PronoSectionTitle(
                        eyebrow: 'SAISON EN DIRECT',
                        title: 'Ta course continue',
                        subtitle:
                            'Le classement collectif tourne tout le temps. Chaque bon score ou duel peut faire bouger ton statut.',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _kGold.withAlpha(18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _kGold.withAlpha(90)),
                          ),
                          child: Text(
                            'NIVEAU $level',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _kGold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      PronoMetricChip(
                        label: 'XP AVANT LE NIVEAU SUIVANT',
                        value: '${xpRemaining < 0 ? 0 : xpRemaining} XP',
                        accent: _kGold,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PronoQuickGuideCard extends StatelessWidget {
  const _PronoQuickGuideCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        title: '1. Pronostique',
        body: 'Joue avant la fermeture et pose ton score en quelques secondes.',
      ),
      (
        title: '2. Monte',
        body:
            'Les bons résultats, les exacts et les duels font grimper ton XP.',
      ),
      (title: '3. Brille', body: 'Domine ta ligue et remonte le classement.'),
    ];

    return PronoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'COMMENT CA MARCHE',
            title: 'Une boucle simple',
            subtitle:
                'Tu joues, tu marques, tu compares. L’objectif est de rendre la gamification forte sans rendre l’écran lourd.',
            trailing: Text(
              '20 sec',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _kMutedText,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...steps.map((step) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _kGold.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      step.title.substring(0, 1),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _kGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.body,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _kMutedText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LegacyProgressPronoTab extends StatelessWidget {
  final String uid;

  const _LegacyProgressPronoTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.userDocStream(uid),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final pronoProfile =
            (userData?['pronoProfile'] as Map<String, dynamic>?) ?? const {};
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: PronoSocialService.leaderboardEntryStream(uid),
          builder: (context, boardSnap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: PronoSocialService.pronoConfigStream(),
              builder: (context, configSnap) {
                final config = configSnap.data?.data();
                final data = <String, dynamic>{
                  ...(boardSnap.data?.data() ?? const <String, dynamic>{}),
                  ...pronoProfile,
                  'friendsCount':
                      ((userData?['social']
                                  as Map<String, dynamic>?)?['friends']
                              as List?)
                          ?.length ??
                      0,
                };

                // XP global (toutes sources : pronos, articles, chat, badges…)
                final xp =
                    (userData?['xp'] as num?)?.toInt() ??
                    PronoSocialService.xpFromStatsWithConfig(
                      data,
                      config: config,
                    );
                final step = PronoSocialService.levelStepXp(config: config);
                final level = step > 0 ? (xp ~/ step) + 1 : 1;
                final xpInLevel = xp - (level - 1) * step;
                final progress = step > 0
                    ? (xpInLevel / step).clamp(0.0, 1.0)
                    : 0.0;
                final points = (data['points'] as num?)?.toInt() ?? 0;
                final total = (data['totalPredictions'] as num?)?.toInt() ?? 0;
                final exact = (data['exactScores'] as num?)?.toInt() ?? 0;
                final good = (data['goodResults'] as num?)?.toInt() ?? 0;
                final duelWins = (data['duelWins'] as num?)?.toInt() ?? 0;
                final accuracy = PronoSocialService.accuracy(data);
                final friendsCount =
                    (data['friendsCount'] as num?)?.toInt() ?? 0;
                final rhythmLabel = total == 0
                    ? 'Demarrage'
                    : total >= 20
                    ? 'Cadence forte'
                    : total >= 8
                    ? 'Bien lance'
                    : 'En chauffe';
                final rhythmAccent = total == 0
                    ? _kMutedText
                    : total >= 20
                    ? _kGreen
                    : _kGold;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                  children: [
                    PronoSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PronoSectionTitle(
                            eyebrow: 'PROGRESSION ACTIVE',
                            title: 'Ta saison perso',
                            subtitle:
                                'Une lecture plus simple de ton niveau, de tes objectifs immédiats et de ta dynamique dans le classement collectif.',
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: _kGold.withAlpha(18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _kGold.withAlpha(90),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'L$level',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: _kGold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      PronoSocialService.levelLabel(
                                        level,
                                        config: config,
                                      ).toUpperCase(),
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: _kText,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$xpInLevel / $step XP dans ce palier',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _kMutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 9,
                              backgroundColor: _kSurfaceMuted,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                _kGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LegacyProgressSeasonStoryCard(
                      level: level,
                      xp: xp,
                      step: step,
                      points: points,
                      total: total,
                      duelWins: duelWins,
                      config: config,
                    ),
                    const SizedBox(height: 12),
                    PronoSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PronoSectionTitle(
                            eyebrow: 'TABLEAU DE BORD',
                            title: 'Ton rythme de saison',
                            subtitle:
                                'On lit ici ton volume de jeu, ta precision, tes victoires en duel et ton impact dans le reseau prono.',
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: PronoMetricChip(
                                  label: 'CADENCE',
                                  value: rhythmLabel,
                                  accent: rhythmAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PronoMetricChip(
                                  label: 'RESEAU',
                                  value: '$friendsCount amis',
                                  accent: _kText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressMetricCard(
                            label: 'POINTS',
                            value: '$points',
                            accent: _kGold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProgressMetricCard(
                            label: 'PRONOS',
                            value: '$total',
                            accent: _kText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProgressMetricCard(
                            label: 'RÉUSSITE',
                            value: '${accuracy.toStringAsFixed(0)}%',
                            accent: _kGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressMetricCard(
                            label: 'EXACTS',
                            value: '$exact',
                            accent: _kRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProgressMetricCard(
                            label: 'BONS RÉSULTATS',
                            value: '$good',
                            accent: _kGold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProgressMetricCard(
                            label: 'DUELS',
                            value: '$duelWins',
                            accent: _kText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PronoSectionCard(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _kGold.withAlpha(16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: _kGold,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ta progression se met a jour automatiquement a chaque prono, resultat ou action dans l\'appli.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _kMutedText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LegacyProgressMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _LegacyProgressMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyNarrativeStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  const _LegacyNarrativeStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _kMutedText,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyProgressSeasonStoryCard extends StatelessWidget {
  final int level;
  final int xp;
  final int step;
  final int points;
  final int total;
  final int duelWins;
  final Map<String, dynamic>? config;

  const _LegacyProgressSeasonStoryCard({
    required this.level,
    required this.xp,
    required this.step,
    required this.points,
    required this.total,
    required this.duelWins,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final xpRemaining = (level * step) - xp;
    final story = total == 0
        ? 'La saison commence maintenant. Ton premier prono lancera ta progression.'
        : duelWins > 0
        ? 'Tu tiens deja le rythme avec $duelWins duel${duelWins > 1 ? 's' : ''} gagne${duelWins > 1 ? 's' : ''}.'
        : 'Tu as deja engrange $points point${points > 1 ? 's' : ''}. Encore un effort pour faire bouger le classement.';

    return PronoSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PronoSectionTitle(
            eyebrow: 'POINT DE SITUATION',
            title: 'Ou tu en es',
            subtitle:
                'On garde ici une lecture narrative de ta saison pour que la progression soit plus vivante que juste des chiffres.',
          ),
          const SizedBox(height: 12),
          Text(
            story,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _kMutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NarrativeStatCard(
                  title: 'OBJECTIF IMMEDIAT',
                  value: '${xpRemaining < 0 ? 0 : xpRemaining} XP',
                  subtitle: 'pour atteindre le niveau ${level + 1}',
                  accent: _kGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NarrativeStatCard(
                  title: 'DYNAMIQUE',
                  value: total == 0 ? 'Demarrage' : 'En rythme',
                  subtitle: total == 0
                      ? 'pose ton premier score pour lancer la machine'
                      : '$total pronos deja joues dans ta saison',
                  accent: _kRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WDLChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _WDLChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
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
    final date = match['date'] as Timestamp;
    final matchDate = date.toDate();
    final now = DateTime.now();
    final locked = !now.isBefore(matchDate);
    final daysLeft = matchDate.difference(now).inDays;
    final tooEarly = !locked && daysLeft >= 7;
    final opensOn = matchDate.subtract(const Duration(days: 7));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .doc('${matchId}_$uid')
          .snapshots(),
      builder: (context, predSnap) {
        final hasPred = predSnap.hasData && predSnap.data!.exists;
        final pred = hasPred
            ? predSnap.data!.data() as Map<String, dynamic>
            : null;

        final team1 = (match['team1'] ?? 'Équipe 1').toString();
        final team2 = (match['team2'] ?? 'Équipe 2').toString();
        final logo1 = match['logo1'] as String?;
        final logo2 = match['logo2'] as String?;
        final comp = (match['competition'] ?? 'Championnat').toString();

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Header : compétition + date ──
              StreamBuilder<String?>(
                stream: _watchPronoStadiumUrl(team1),
                builder: (context, stadiumSnap) {
                  final stadiumUrl = stadiumSnap.data?.trim();
                  final ImageProvider headerImage =
                      stadiumUrl != null && stadiumUrl.isNotEmpty
                      ? NetworkImage(stadiumUrl)
                      : const AssetImage(
                          'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
                        );

                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: headerImage,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withAlpha(160),
                          BlendMode.darken,
                        ),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(20),
                          Colors.black.withAlpha(70),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          comp.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        // Badge etat
                        if (locked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(100),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 9,
                                  color: _kGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'FERME',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _kGrey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (tooEarly)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(160),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withAlpha(40),
                              ),
                            ),
                            child: Text(
                              'Dispo le ${DateFormat("dd MMM", "fr_FR").format(opensOn)}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (hasPred)
                          const SizedBox.shrink(),
                        if (!locked && !tooEarly) ...[
                          const SizedBox(width: 6),
                          _CountdownBadge(closeAt: matchDate),
                        ],
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withAlpha(40),
                            ),
                          ),
                          child: Text(
                            DateFormat(
                              "dd MMM - HH'h'mm",
                              "fr_FR",
                            ).format(matchDate),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Corps : equipes + score
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _PronoLogo(logo: logo1, name: team1),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                team1.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: hasPred && !tooEarly
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _kGold.withAlpha(18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _kGold.withAlpha(90),
                                  ),
                                ),
                                child: Text(
                                  "${pred!['score1Pred']} - ${pred['score2Pred']}",
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: _kGold,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(90),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'VS',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white54,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                team2.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _PronoLogo(logo: logo2, name: team2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer action
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: hasPred
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(110),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withAlpha(10)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _kGold.withAlpha(18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: _kGold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TON PRONO',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _kGrey,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${pred!['score1Pred']} - ${pred['score2Pred']}",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _PopularPickStrip(matchId: matchId),
              ),

              if (!locked && !tooEarly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: hasPred
                                  ? Colors.white.withAlpha(6)
                                  : _kGold,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasPred
                                    ? Colors.white.withAlpha(10)
                                    : _kGold.withAlpha(90),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hasPred
                                      ? Icons.edit_rounded
                                      : Icons.sports_soccer_rounded,
                                  size: 15,
                                  color: hasPred ? Colors.white70 : _kBg,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  hasPred ? 'MODIFIER' : 'PRONOSTIQUER',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: hasPred ? Colors.white : _kBg,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            _openDuelSheet(context, '$team1 vs $team2'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withAlpha(10),
                            ),
                          ),
                          child: Text(
                            'DUEL',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _kGold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      if (hasPred) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _sharePred(
                            team1,
                            team2,
                            pred!['score1Pred'] as int,
                            pred['score2Pred'] as int,
                            matchDate,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withAlpha(10),
                              ),
                            ),
                            child: Icon(
                              Icons.share_rounded,
                              size: 16,
                              color: _kGrey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cancelPred,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withAlpha(10),
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _kGrey,
                            ),
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
        matchId: matchId,
        match: match,
        uid: uid,
        displayName: displayName,
      ),
    );
  }

  Future<void> _openDuelSheet(BuildContext context, String matchLabel) async {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final social =
        (userSnap.data()?['social'] as Map<String, dynamic>?) ?? const {};
    final friendNames =
        (social['friendNames'] as Map<String, dynamic>?) ?? const {};
    final friendIds =
        (social['friends'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    if (!context.mounted) return;
    if (friendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute d\'abord un ami pour lancer un duel.'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lancer un duel',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                matchLabel,
                style: GoogleFonts.inter(fontSize: 12, color: _kGrey),
              ),
              const SizedBox(height: 12),
              ...friendIds.map((friendUid) {
                final friendName = (friendNames[friendUid] ?? 'Ami DVCR')
                    .toString();
                return GestureDetector(
                  onTap: () async {
                    await PronoSocialService.createDuel(
                      ownerUid: uid,
                      ownerName: displayName,
                      opponentUid: friendUid,
                      opponentName: friendName,
                      matchId: matchId,
                      matchLabel: matchLabel,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Duel envoye a $friendName'),
                          backgroundColor: _kGreen,
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            friendName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: _kGold),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _LegacyModernMatchPronoCard extends StatelessWidget {
  final String matchId;
  final Map<String, dynamic> match;
  final String uid;
  final String displayName;

  const _LegacyModernMatchPronoCard({
    required this.matchId,
    required this.match,
    required this.uid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final date = match['date'] as Timestamp;
    final matchDate = date.toDate();
    final now = DateTime.now();
    final locked = !now.isBefore(matchDate);
    final daysLeft = matchDate.difference(now).inDays;
    final tooEarly = !locked && daysLeft >= 7;
    final opensOn = matchDate.subtract(const Duration(days: 7));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .doc('${matchId}_$uid')
          .snapshots(),
      builder: (context, predSnap) {
        final hasPred = predSnap.hasData && predSnap.data!.exists;
        final pred = hasPred
            ? predSnap.data!.data() as Map<String, dynamic>
            : null;
        final team1 = (match['team1'] ?? 'Équipe 1').toString();
        final team2 = (match['team2'] ?? 'Équipe 2').toString();
        final logo1 = match['logo1'] as String?;
        final logo2 = match['logo2'] as String?;
        final comp = (match['competition'] ?? 'Championnat').toString();
        final actionLabel = hasPred
            ? 'Modifier mon prono'
            : tooEarly
            ? 'Ouverture le ${DateFormat("dd MMM", "fr_FR").format(opensOn)}'
            : 'Pronostiquer maintenant';
        final actionSubtitle = hasPred
            ? 'Ton score est pose. Tu peux encore le corriger avant la cloture.'
            : tooEarly
            ? 'Le match est encore trop loin. Reviens quelques jours avant le coup d envoi.'
            : 'Le prono est ouvert. Pose ton score en quelques secondes.';

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          decoration: BoxDecoration(
            color: pronoSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: pronoBorder),
            boxShadow: [
              BoxShadow(
                color: pronoGreenDeep.withAlpha(18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              StreamBuilder<String?>(
                stream: _watchPronoStadiumUrl(team1),
                builder: (context, stadiumSnap) {
                  final stadiumUrl = stadiumSnap.data?.trim();
                  final ImageProvider headerImage =
                      stadiumUrl != null && stadiumUrl.isNotEmpty
                      ? NetworkImage(stadiumUrl)
                      : const AssetImage(
                          'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
                        );

                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: headerImage,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          pronoGreenDeep.withAlpha(110),
                          BlendMode.srcATop,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MatchHeaderPill(label: comp.toUpperCase()),
                              _MatchHeaderPill(
                                label: DateFormat(
                                  "dd MMM - HH'h'mm",
                                  "fr_FR",
                                ).format(matchDate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (locked)
                          const _MatchStatePill(
                            icon: Icons.lock_rounded,
                            label: 'Ferme',
                          )
                        else if (tooEarly)
                          _MatchStatePill(
                            icon: Icons.schedule_rounded,
                            label:
                                'Dispo le ${DateFormat("dd MMM", "fr_FR").format(opensOn)}',
                          )
                        else
                          _CountdownBadge(closeAt: matchDate),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pronoBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _PronoLogo(logo: logo1, name: team1),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                team1.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _kText,
                                  height: 1.15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: hasPred && !tooEarly
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _kGold.withAlpha(18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _kGold.withAlpha(90),
                                  ),
                                ),
                                child: Text(
                                  "${pred!['score1Pred']} - ${pred['score2Pred']}",
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: _kGold,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: pronoSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: pronoBorder),
                                ),
                                child: Text(
                                  'VS',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _kMutedText,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                team2.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _kText,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _PronoLogo(logo: logo2, name: team2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _kSurfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pronoBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: hasPred
                                  ? _kGold.withAlpha(18)
                                  : _kGreen.withAlpha(18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hasPred
                                  ? Icons.check_rounded
                                  : tooEarly
                                  ? Icons.schedule_rounded
                                  : Icons.flash_on_rounded,
                              size: 18,
                              color: hasPred ? _kGold : _kGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  actionLabel.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _kText,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasPred
                                      ? "${pred!['score1Pred']} - ${pred['score2Pred']} · $actionSubtitle"
                                      : actionSubtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _kMutedText,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PopularPickStrip(matchId: matchId),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    if (!locked && !tooEarly)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: hasPred ? _kGreen : _kGold,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasPred
                                    ? _kGreen.withAlpha(160)
                                    : _kGold.withAlpha(160),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hasPred
                                      ? Icons.edit_rounded
                                      : Icons.sports_soccer_rounded,
                                  size: 16,
                                  color: hasPred ? Colors.white : _kBg,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasPred
                                      ? 'MODIFIER MON PRONO'
                                      : 'PRONOSTIQUER',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: hasPred ? Colors.white : _kBg,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!locked && !tooEarly) const SizedBox(width: 10),
                    if (!locked && !tooEarly)
                      GestureDetector(
                        onTap: () =>
                            _openDuelSheet(context, '$team1 vs $team2'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: pronoBorder),
                          ),
                          child: Text(
                            'DUEL',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _kGreen,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    if (hasPred) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _sharePred(
                          team1,
                          team2,
                          pred!['score1Pred'] as int,
                          pred['score2Pred'] as int,
                          matchDate,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: pronoBorder),
                          ),
                          child: Icon(
                            Icons.share_rounded,
                            size: 16,
                            color: _kMutedText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _cancelPred,
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: pronoBorder),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: _kRed,
                          ),
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
        'Mon pronostic DVCR pour $t1 vs $t2 ($dateStr) :\n'
        '$t1 $s1 - $s2 $t2\n\n'
        'Rejoins la communauté sur l\'app DVCR !';
    Share.share(text);
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PronoSheet(
        matchId: matchId,
        match: match,
        uid: uid,
        displayName: displayName,
      ),
    );
  }

  Future<void> _openDuelSheet(BuildContext context, String matchLabel) async {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final social =
        (userSnap.data()?['social'] as Map<String, dynamic>?) ?? const {};
    final friendNames =
        (social['friendNames'] as Map<String, dynamic>?) ?? const {};
    final friendIds =
        (social['friends'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    if (!context.mounted) return;
    if (friendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute d\'abord un ami pour lancer un duel.'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lancer un duel',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                matchLabel,
                style: GoogleFonts.inter(fontSize: 12, color: _kGrey),
              ),
              const SizedBox(height: 12),
              ...friendIds.map((friendUid) {
                final friendName = (friendNames[friendUid] ?? 'Ami DVCR')
                    .toString();
                return GestureDetector(
                  onTap: () async {
                    await PronoSocialService.createDuel(
                      ownerUid: uid,
                      ownerName: displayName,
                      opponentUid: friendUid,
                      opponentName: friendName,
                      matchId: matchId,
                      matchLabel: matchLabel,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Duel envoye a $friendName'),
                          backgroundColor: _kGreen,
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            friendName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: _kGold),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _LegacyMatchHeaderPill extends StatelessWidget {
  final String label;

  const _LegacyMatchHeaderPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LegacyMatchStatePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LegacyMatchStatePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyCountdownBadge extends StatelessWidget {
  final DateTime closeAt;

  const _LegacyCountdownBadge({required this.closeAt});

  @override
  Widget build(BuildContext context) {
    final diff = closeAt.difference(DateTime.now());
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60).abs();
    final label = hours >= 24
        ? 'Cloture dans ${diff.inDays}j'
        : 'Cloture dans ${hours.abs()}h ${minutes.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kRed.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kRed.withAlpha(90)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kRed,
        ),
      ),
    );
  }
}

class _LegacyPopularPickStrip extends StatelessWidget {
  final String matchId;

  const _LegacyPopularPickStrip({required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PronoPopularPick>>(
      stream: PronoSocialService.popularPickStream(matchId),
      builder: (context, snap) {
        final picks = snap.data ?? const <PronoPopularPick>[];
        if (picks.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _kSurfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pronoBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, size: 14, color: _kGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pas encore de tendance populaire',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: _kMutedText),
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _kSurfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pronoBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TENDANCE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kMutedText,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: picks.map((pick) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pronoSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: pronoBorder),
                    ),
                    child: Text(
                      '${pick.label} · ${pick.votes} votes · ${(pick.share * 100).round()}%',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegacyPronoLogo extends StatelessWidget {
  final String? logo;
  final String name;
  const _LegacyPronoLogo({this.logo, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: logo != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                logo!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kGrey,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kGrey,
                ),
              ),
            ),
    );
  }
}

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
  int _s1 = 1, _s2 = 1;
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'matchId': widget.matchId,
        'uid': widget.uid,
        'displayName': widget.displayName,
        'score1Pred': _s1,
        'score2Pred': _s2,
        'points': null,
        'season': season,
        'matchDate': widget.match['date'],
        'team1': widget.match['team1'] ?? '',
        'team2': widget.match['team2'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final isNew = !snap.exists;
    await PronoSocialService.registerPrediction(
      uid: widget.uid,
      displayName: widget.displayName,
      isNewPrediction: isNew,
    );

    if (isNew) {
      try {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('awardXp').call({'eventType': 'vote_prono'});
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
      final t1 = widget.match['team1'] ?? '';
      final t2 = widget.match['team2'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prono enregistré : $t1 $_s1 - $_s2 $t2',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: _kGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final team1 = widget.match['team1'] as String? ?? 'Équipe 1';
    final team2 = widget.match['team2'] as String? ?? 'Équipe 2';
    final date = widget.match['date'] as Timestamp;

    const _bg = Color(0xFFF5F2E9);
    const _surface = Color(0xFFFFFFFF);
    const _border = Color(0xFFDDD8CC);
    const _text = Color(0xFF173C31);
    const _muted = Color(0xFF6E776F);

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kRed.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: _kRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TON PRONOSTIC',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _text,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      DateFormat(
                        "dd MMMM yyyy · HH'h'mm",
                        'fr_FR',
                      ).format(date.toDate()),
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!_loaded)
            const Center(
              child: CircularProgressIndicator(color: _kRed, strokeWidth: 2),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          team1.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          child: _Stepper(
                            value: _s1,
                            onChanged: (v) => setState(() => _s1 = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '–',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 32,
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          team2.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          child: _Stepper(
                            value: _s2,
                            onChanged: (v) => setState(() => _s2 = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Points hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PointHint(
                  icon: Icons.star_rounded,
                  iconColor: _kGold,
                  pts: '3 pts',
                  label: 'Score exact',
                  light: true,
                ),
                Container(width: 1, height: 28, color: _border),
                _PointHint(
                  icon: Icons.check_circle_rounded,
                  iconColor: _kGreen,
                  pts: '1 pt',
                  label: 'Bon résultat',
                  light: true,
                ),
                Container(width: 1, height: 28, color: _border),
                _PointHint(
                  icon: Icons.cancel_rounded,
                  iconColor: _kRed,
                  pts: '0 pt',
                  label: 'Mauvais prono',
                  light: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bouton valider
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _saving ? _border : _kRed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _saving
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Text(
                      'VALIDER MON PRONO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
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
  final IconData icon;
  final Color iconColor;
  final String pts, label;
  final bool light;
  const _PointHint({
    required this.icon,
    required this.iconColor,
    required this.pts,
    required this.label,
    this.light = false,
  });
  @override
  Widget build(BuildContext context) {
    final textColor = light ? const Color(0xFF173C31) : Colors.white;
    final mutedColor = light ? const Color(0xFF6E776F) : _kGrey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 2),
        Text(
          pts,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: mutedColor)),
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
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: _kGold,
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(icon, color: enabled ? Colors.white : _kGrey, size: 20),
      ),
    );
  }
}

// ── Onglet Classement ─────────────────────────────────────────────────────────
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
          final comp = ((d.data() as Map)['competition'] as String? ?? '')
              .toUpperCase();
          return !comp.contains('COUPE');
        }).toList();
        if (docs.isEmpty) return const SizedBox.shrink();

        final nextDoc = docs.first;
        final m = nextDoc.data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PronoScreen(initialTab: 0),
              ),
            );
          },
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
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xFFC8A436),
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  'PRONOS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC8A436),
                    letterSpacing: 1.5,
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
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return Text(
                        '$matchLabel · Pronostiquer →',
                        style: GoogleFonts.inter(fontSize: 13, color: _kGrey),
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

