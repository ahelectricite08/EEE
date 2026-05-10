import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/app_settings_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';
import '../../admin_stat_widgets.dart';
import '../../dashboard_matches_finished_by_season.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  /// Une seule instance par ouverture d’onglet — évite de relancer les
  /// `count()` à chaque rebuild (sinon tuiles vides / jamais terminées).
  late final Future<String> _usersCountFuture = FirebaseFirestore.instance
      .collection('users')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _articlesPublishedFuture = FirebaseFirestore
      .instance
      .collection('articles')
      .where('status', isEqualTo: 'published')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _notifsTodayFuture = () async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final snap = await FirebaseFirestore.instance
        .collection('notifications_queue')
        .where('status', isEqualTo: 'sent')
        .where(
          'sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .count()
        .get();
    return '${snap.count}';
  }();

  late final Future<String> _pronoLeaderboardFuture = FirebaseFirestore
      .instance
      .collection('prono_leaderboard')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _reportsPendingFuture = FirebaseFirestore.instance
      .collection('reports')
      .where('status', isEqualTo: 'pending')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _notifsPendingFuture = FirebaseFirestore.instance
      .collection('notifications_queue')
      .where('status', isEqualTo: 'pending')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _articlesDraftFuture = FirebaseFirestore.instance
      .collection('articles')
      .where('status', isEqualTo: 'draft')
      .count()
      .get()
      .then((s) => '${s.count}');

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // ── En-tête pilotage (léger, sans halo) ─────────────────────────────
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (_, snap) {
            final isLive = snap.data?.exists ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: _PilotageOverviewCard(isLive: isLive),
            );
          },
        ),

        // ── Stats rapides ──────────────────────────────────────────────────────
        AdminStatRow(
          stats: [
            AdminStatFuture(
              label: 'UTILISATEURS',
              icon: Icons.people_rounded,
              color: adminGold,
              future: _usersCountFuture,
            ),
            AdminStatFuture(
              label: 'ARTICLES',
              icon: Icons.article_rounded,
              color: const Color(0xFF4A90D9),
              future: _articlesPublishedFuture,
            ),
            AdminStatFuture(
              label: 'NOTIFS AUJOURD\'HUI',
              icon: Icons.notifications_rounded,
              color: const Color(0xFF7B61FF),
              future: _notifsTodayFuture,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdminStatRow(
          stats: [
            DashboardMatchesFinishedBySeason(),
            AdminStatFuture(
              label: 'PRONOS',
              icon: Icons.casino_rounded,
              color: Colors.orange,
              future: _pronoLeaderboardFuture,
            ),
            AdminStatStream(
              label: 'Hub live',
              icon: Icons.podcasts_rounded,
              color: adminRed,
              stream: FirebaseFirestore.instance
                  .collection('live')
                  .snapshots()
                  .map((s) => s.docs.isNotEmpty ? 'Actif' : 'Inactif'),
              activeColor: (v) => v == 'Actif' ? adminRed : adminGrey,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdminStatRow(
          stats: [
            AdminStatFuture(
              label: 'SIGN. EN ATTENTE',
              icon: Icons.flag_rounded,
              color: const Color(0xFFFFB74D),
              future: _reportsPendingFuture,
            ),
            AdminStatFuture(
              label: 'NOTIFS EN FILE',
              icon: Icons.pending_actions_rounded,
              color: Colors.orange,
              future: _notifsPendingFuture,
            ),
            AdminStatFuture(
              label: 'ARTICLES BROUILLON',
              icon: Icons.drafts_rounded,
              color: adminGrey,
              future: _articlesDraftFuture,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Derniers inscrits ──────────────────────────────────────────────────
        const AdminSectionTitle(label: 'DERNIERS INSCRITS'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: adminGold),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['displayName'] ?? d['name'] ?? '';
                final email = d['email'] ?? '';
                final role = d['role'] ?? 'supporter';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: adminGold.withAlpha(30),
                        child: Text(
                          (name.isNotEmpty
                                  ? name[0]
                                  : email.isNotEmpty
                                  ? email[0]
                                  : '?')
                              .toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: adminGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? name : email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: adminTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (name.isNotEmpty)
                              Text(
                                email,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      AdminStatusChip(
                        label: role.toUpperCase(),
                        color: role == 'admin'
                            ? adminRed
                            : role == 'partenaire'
                            ? adminGold
                            : adminGrey,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Dernières notifications ────────────────────────────────────────────
        const AdminSectionTitle(label: 'DERNIÈRES NOTIFICATIONS'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications_queue')
              .orderBy('sentAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            if (snap.data!.docs.isEmpty) {
              return Text(
                'Aucune notification envoyée',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final status = d['status'] ?? 'pending';
                final statusColor = status == 'sent'
                    ? const Color(0xFF4CAF50)
                    : status == 'error'
                    ? adminRed
                    : Colors.orange;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['title'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: adminTextPrimary,
                              ),
                            ),
                            Text(
                              d['body'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AdminStatusChip(
                        label: status.toUpperCase(),
                        color: statusColor,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Social Prono ───────────────────────────────────────────────────────
        const AdminSectionTitle(label: 'SOCIAL PRONO'),
        const SizedBox(height: 10),
        const _SupportLinkAdminCard(),
        const SizedBox(height: 12),
        AdminStatRow(
          stats: [
            AdminStatFuture(
              label: 'LIGUES',
              icon: Icons.groups_rounded,
              color: adminGold,
              future: FirebaseFirestore.instance
                  .collection('private_leagues')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'DUELS',
              icon: Icons.emoji_events_rounded,
              color: Colors.orange,
              future: FirebaseFirestore.instance
                  .collection('prono_duels')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'AMIS',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF4A90D9),
              future: () async {
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .limit(50)
                    .get();
                int friends = 0;
                for (final doc in snap.docs) {
                  final social =
                      (doc.data()['social'] as Map<String, dynamic>?) ?? const {};
                  friends += ((social['friends'] as List?)?.length ?? 0);
                }
                return '${(friends / 2).round()}';
              }(),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Ligues privées récentes
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('private_leagues')
              .orderBy('updatedAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ligues privées récentes',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (d['name'] ?? 'Ligue privée').toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: adminTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Code ${(d['code'] ?? '-').toString()} · ${(d['memberCount'] ?? 0)} membre(s)',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const AdminStatusChip(label: 'LIGUE', color: adminGold),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Derniers duels
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('prono_duels')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Derniers duels',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${d['ownerName'] ?? 'Membre'} vs ${d['opponentName'] ?? 'Membre'} · ${d['matchLabel'] ?? ''}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: adminGrey,
                            ),
                          ),
                        ),
                        AdminStatusChip(
                          label: (d['status'] ?? 'pending')
                              .toString()
                              .toUpperCase(),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const _PronoSeasonResetCard(),
      ],
    );
  }
}

/// Carte d’accueil Pilotage : sobre, lisible, sans effet « néon ».
class _PilotageOverviewCard extends StatelessWidget {
  final bool isLive;

  const _PilotageOverviewCard({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: adminBorderLight),
        boxShadow: adminCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'PILOTAGE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGold,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isLive ? adminRed.withAlpha(16) : adminSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isLive ? adminRed.withAlpha(55) : adminBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isLive ? adminRed : adminGrey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isLive ? 'Live actif' : 'Hors antenne',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLive ? adminRed : adminGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Drapeau Vert Carton Rouge',
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
              height: 1.05,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLive
                ? 'Le flux public suit le document live — scores et votes se mettent à jour ici et dans l’app.'
                : 'Lance un match depuis l’onglet Live pour activer le hub : cette page reflète alors l’état en temps réel.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: adminGrey,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Support link card ─────────────────────────────────────────────────────────
class _SupportLinkAdminCard extends StatefulWidget {
  const _SupportLinkAdminCard();

  @override
  State<_SupportLinkAdminCard> createState() => _SupportLinkAdminCardState();
}

class _SupportLinkAdminCardState extends State<_SupportLinkAdminCard> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppSettingsService.saveSupport(
        SupportSettings(supportUrl: _ctrl.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien soutenir mis à jour'),
          backgroundColor: adminGreen,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SupportSettings>(
      stream: AppSettingsService.supportStream(),
      builder: (context, snap) {
        final supportUrl = snap.data?.supportUrl ?? '';
        if (!_initialized ||
            (!_saving && _ctrl.text.trim() != supportUrl.trim())) {
          _ctrl.text = supportUrl;
          _initialized = true;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: adminGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Lien bouton Soutenir',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ce lien sera utilisé par le bouton SOUTENIR dans toutes les cartes SOUTENEZ DVCR de l\'app.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AdminField(ctrl: _ctrl, label: 'URL soutien / don')),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _saving ? adminBorder : adminGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              'ENREGISTRER',
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
        );
      },
    );
  }
}

// ── Reset saison prono ────────────────────────────────────────────────────────

class _PronoSeasonResetCard extends StatefulWidget {
  const _PronoSeasonResetCard();

  @override
  State<_PronoSeasonResetCard> createState() => _PronoSeasonResetCardState();
}

class _PronoSeasonResetCardState extends State<_PronoSeasonResetCard> {
  late final TextEditingController _seasonCtrl;
  bool _loading = false;
  int? _previewLeaderboardCount;
  int? _previewLeaguesCount;

  @override
  void initState() {
    super.initState();
    _seasonCtrl = TextEditingController(text: _seasonLabel());
    _loadPreviewCounts();
  }

  Future<void> _loadPreviewCounts() async {
    try {
      final lb = await FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .count()
          .get();
      final lg = await FirebaseFirestore.instance
          .collection('private_leagues')
          .count()
          .get();
      if (!mounted) return;
      setState(() {
        _previewLeaderboardCount = lb.count;
        _previewLeaguesCount = lg.count;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewLeaderboardCount = null;
        _previewLeaguesCount = null;
      });
    }
  }

  @override
  void dispose() {
    _seasonCtrl.dispose();
    super.dispose();
  }

  String _seasonLabel() {
    final now = DateTime.now();
    if (now.month >= 7) return '${now.year}-${now.year + 1}';
    return '${now.year - 1}-${now.year}';
  }

  Future<void> _runReset() async {
    final season = _seasonCtrl.text.trim();
    if (season.isEmpty) return;

    final ok = await adminConfirm(
      context,
      'Archiver et vider les classements pour la saison « $season » ?\n\n'
      'Seront réinitialisés : le classement général (prono_leaderboard) et les '
      'totaux de classement des ligues (rankingStats).\n\n'
      'Seront conservés : XP utilisateurs, pronos, duels, ligues et membres.',
    );
    if (!ok || !mounted) return;

    setState(() => _loading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('resetPronoSeason');
      final result = await callable.call({'season': season});
      final data = Map<String, dynamic>.from(result.data as Map);
      final counts = Map<String, dynamic>.from((data['counts'] as Map?) ?? const {});
      final archiveId = (data['archiveId'] as String?) ?? '';
      if (!mounted) return;
      final lb = counts['pronoLeaderboard'] ?? 0;
      final leagues = counts['privateLeaguesUpdated'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: adminGreenAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Classements réinitialisés : $lb entrée(s) classement, $leagues ligue(s). '
            'Archive : $archiveId',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
            ),
          ),
          action: archiveId.isEmpty
              ? null
              : SnackBarAction(
                  label: 'Copier ID',
                  textColor: adminTextPrimary,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: archiveId));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: adminGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        content: Text(
                          'ID d’archive copié',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: adminOnAccent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      );
      await _loadPreviewCounts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: adminRed,
          content: Text('Erreur reset saison : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            adminGold.withAlpha(22),
            adminCard,
            adminBlue.withAlpha(12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminBorderLight),
        boxShadow: adminCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: adminGold.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: adminGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIN DE SAISON PRONO',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: adminGold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Classements uniquement',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: adminTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Archive les entrées du classement général, remet les totaux des '
            'ligues à zéro. Les pronos, duels, membres et l’XP ne sont pas modifiés.',
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: adminGrey,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _PreviewChip(
                icon: Icons.emoji_events_outlined,
                label: 'Classement',
                value: _previewLeaderboardCount == null
                    ? '…'
                    : '$_previewLeaderboardCount',
              ),
              _PreviewChip(
                icon: Icons.groups_outlined,
                label: 'Ligues',
                value: _previewLeaguesCount == null
                    ? '…'
                    : '$_previewLeaguesCount',
              ),
              InkWell(
                onTap: _loadPreviewCounts,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 14, color: adminBlue),
                      const SizedBox(width: 4),
                      Text(
                        'Actualiser',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: adminBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdminField(ctrl: _seasonCtrl, label: 'Libellé saison (traçabilité)'),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _runReset,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: adminGoldGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: adminGlowShadow(adminGold),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: adminTextPrimary,
                            ),
                          )
                        : Text(
                            'ARCHIVER\nCLASSEMENTS',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: adminTextPrimary,
                              height: 1.05,
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
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: adminGrey),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: adminGrey,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

