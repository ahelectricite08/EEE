import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/app_settings_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';
import '../../admin_stat_widgets.dart';
import '../../dashboard_matches_finished_by_season.dart';
import '../../widgets/dashboard_match_day_card.dart';
import '../../widgets/admin_system_health_panel.dart';
import '../../admin_navigation.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  /// Une seule instance par ouverture dâ€™onglet â€” Ã©vite de relancer les
  /// `count()` Ã  chaque rebuild (sinon tuiles vides / jamais terminÃ©es).
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
        // â”€â”€ En-tÃªte pilotage (lÃ©ger, sans halo) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (_, snap) {
            final isLive = snap.data?.exists ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PilotageOverviewCard(isLive: isLive),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: _AdminMaintenanceCard(),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: DashboardMatchDayCard(),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: AdminSystemHealthPanel(),
        ),

        // â”€â”€ Stats rapides â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

        // â”€â”€ Derniers inscrits â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

        // â”€â”€ DerniÃ¨res notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        const AdminSectionTitle(label: 'DERNIÃˆRES NOTIFICATIONS'),
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
                'Aucune notification envoyÃ©e',
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
        const _PronosShortcutCard(),
      ],
    );
  }
}

class _PronosShortcutCard extends StatelessWidget {
  const _PronosShortcutCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AdminNavigation.goToPronos(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A317).withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  color: Color(0xFFE8A317),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRONOS & JEUX',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: adminTextPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Championnat, duels, ligues, Coupe du monde 2026',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: adminGrey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte dâ€™accueil Pilotage : sobre, lisible, sans effet Â« nÃ©on Â».
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
                ? 'Le flux public suit le document live â€” scores et votes se mettent Ã  jour ici et dans lâ€™app.'
                : 'Lance un match depuis lâ€™onglet Live pour activer le hub : cette page reflÃ¨te alors lâ€™Ã©tat en temps rÃ©el.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: adminGrey,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const _AdminRecomputeLeaguesButton(),
        ],
      ),
    );
  }
}

/// Coupe toutes les push FCM (Cloud Functions) pendant les tests admin.
class _AdminMaintenanceCard extends StatefulWidget {
  const _AdminMaintenanceCard();

  @override
  State<_AdminMaintenanceCard> createState() => _AdminMaintenanceCardState();
}

class _AdminMaintenanceCardState extends State<_AdminMaintenanceCard> {
  bool _saving = false;
  bool _savingBypass = false;

  Future<void> _setBypassToCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connecte-toi pour dÃ©finir ton tÃ©lÃ©phone exemptÃ©.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _savingBypass = true);
    try {
      await AppSettingsService.setMaintenanceBypassUid(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ton compte est exemptÃ© des push en maintenance.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBypass = false);
    }
  }

  Future<void> _toggle(bool paused) async {
    if (_saving) return;
    if (paused) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: adminCard,
          title: Text(
            'Activer le mode maintenance ?',
            style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
          ),
          content: Text(
            'Aucune notification push ne partira (live, actus, stats, rappels matchâ€¦), '
            'sauf sur le compte Â« tÃ©lÃ©phone de test Â» dÃ©fini ci-dessous. '
            'Pense Ã  le dÃ©sactiver quand tu as fini.',
            style: GoogleFonts.inter(color: adminGrey, fontSize: 12, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('ACTIVER', style: GoogleFonts.inter(color: adminGold)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      await AppSettingsService.setNotificationsPaused(paused);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: AppSettingsService.adminMaintenanceStream(),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final paused = data['notificationsPaused'] == true;
        final bypassUid = (data['maintenanceBypassUid'] ?? '').toString().trim();
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final bypassIsMe = bypassUid.isNotEmpty && bypassUid == myUid;
        final accent = paused ? const Color(0xFFE8A317) : adminBorderLight;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: paused ? const Color(0xFF2A2210) : adminCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: paused ? accent.withAlpha(120) : adminBorderLight,
              width: paused ? 1.5 : 1,
            ),
            boxShadow: adminCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    paused
                        ? Icons.build_circle_rounded
                        : Icons.notifications_off_outlined,
                    color: paused ? accent : adminGrey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paused
                              ? 'NOTIFICATIONS EN PAUSE'
                              : 'PAUSE NOTIFICATIONS PUSH',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: paused ? accent : adminGold,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          paused
                              ? 'Push coupÃ©es pour tout le monde, sauf le compte exemptÃ© ci-dessous.'
                              : 'Coupe les push pour tous pendant tes tests (live, actus, statsâ€¦).',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: paused ? adminTextPrimary : adminGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: paused,
                    onChanged: _saving ? null : _toggle,
                    activeTrackColor: accent.withAlpha(140),
                    thumbColor: WidgetStateProperty.resolveWith(
                      (states) => paused ? accent : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: adminBorder.withAlpha(120), height: 1),
              const SizedBox(height: 10),
              Text(
                'TÃ‰LÃ‰PHONE DE TEST (EXEMPTÃ‰)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                bypassUid.isEmpty
                    ? 'Aucun compte exemptÃ© â€” en maintenance, personne ne reÃ§oit les push automatiques.'
                    : bypassIsMe
                        ? 'Ton compte est exemptÃ© : tu reÃ§ois encore les push sur tes appareils enregistrÃ©s.'
                        : 'Compte exemptÃ© : ${bypassUid.length > 12 ? '${bypassUid.substring(0, 8)}â€¦' : bypassUid}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminTextPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _savingBypass ? null : _setBypassToCurrentUser,
                    icon: _savingBypass
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.phone_iphone_rounded, size: 16),
                    label: Text(
                      'UTILISER MON COMPTE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (bypassUid.isNotEmpty)
                    TextButton(
                      onPressed: _savingBypass
                          ? null
                          : () => AppSettingsService.setMaintenanceBypassUid(null),
                      child: Text(
                        'RETIRER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: adminGrey,
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

/// Recalcul `private_leagues.rankingStats` (Cloud Function, admin uniquement).
class _AdminRecomputeLeaguesButton extends StatefulWidget {
  const _AdminRecomputeLeaguesButton();

  @override
  State<_AdminRecomputeLeaguesButton> createState() =>
      _AdminRecomputeLeaguesButtonState();
}

class _AdminRecomputeLeaguesButtonState extends State<_AdminRecomputeLeaguesButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final fn = FirebaseFunctions.instance
          .httpsCallable('adminRecomputeLeaguePowerRankings');
      final res = await fn.call();
      final map = Map<String, dynamic>.from(res.data as Map? ?? {});
      final n = map['leaguesProcessed'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n != null
                ? 'Stats ligues recalculÃ©es ($n ligue(s))'
                : 'Stats ligues recalculÃ©es',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recalcul ligues : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: adminGold,
                ),
              )
            : const Icon(Icons.calculate_outlined, size: 18),
        label: Text(
          'Recalcul stats classement des ligues',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Support link card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
          content: Text('Lien soutenir mis Ã  jour'),
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
                    'URL soutien (dÃ©sactivÃ©e dans lâ€™app)',
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
                'Les cartes de soutien nâ€™ouvrent plus de lien externe (conformitÃ© App Store). '
                'Champ conservÃ© pour archive uniquement.',
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
