import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dvcr/navigation/main_shell_insets.dart';
import '../../admin_palette.dart';
import '../../admin_shared_widgets.dart';
import '../../admin_users_hero_card.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_components.dart';
import '../../admin_controller.dart';
import '../../admin_actions.dart';
import '../../../../services/admin_user_firebase_actions_service.dart';

class UsersTab extends StatefulWidget {
  const UsersTab();

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  static const _usersPageSize = 200;

  static const _visibleRoles = [
    'supporter',
    'team_dvcr',
  ];
  static const _adminRoles = [
    'editor',
    'community_manager',
    'statisticien',
    'admin',
  ];

  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _totalUsersCount;
  bool _refreshing = false;
  bool _loading = true;
  List<QueryDocumentSnapshot> _allDocs = [];
  StreamSubscription<QuerySnapshot>? _usersSub;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
    unawaited(_reloadTotalCount());
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        // Ne pas remplacer une liste complète par un snapshot cache partiel.
        final total = _totalUsersCount;
        if (_allDocs.isNotEmpty &&
            total != null &&
            snap.docs.length < total &&
            snap.docs.length < _allDocs.length) {
          return;
        }
        setState(() {
          _allDocs = snap.docs;
          _loading = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
    unawaited(_refreshUsersFromServer(silent: true));
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadTotalCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      if (mounted) setState(() => _totalUsersCount = snap.count);
    } catch (_) {}
  }

  Future<List<QueryDocumentSnapshot>> _fetchAllUserPages({
    required bool fromServer,
  }) async {
    final out = <QueryDocumentSnapshot>[];
    var query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(_usersPageSize);
    while (true) {
      final snap = await query.get(
        fromServer
            ? const GetOptions(source: Source.server)
            : const GetOptions(source: Source.serverAndCache),
      );
      out.addAll(snap.docs);
      if (snap.docs.length < _usersPageSize) break;
      query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(snap.docs.last)
          .limit(_usersPageSize);
    }
    return out;
  }

  /// Recharge toute la base par pages (lecture serveur, pas seulement le cache).
  Future<void> _refreshUsersFromServer({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent) setState(() => _refreshing = true);
    try {
      final fresh = await _fetchAllUserPages(fromServer: true);
      if (mounted) {
        setState(() {
          _allDocs = fresh;
          _loading = false;
        });
      }
      await _reloadTotalCount();
    } finally {
      if (mounted && !silent) setState(() => _refreshing = false);
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return adminRed;
      case 'community_manager':
        return const Color(0xFF2979FF);
      case 'editor':
        return const Color(0xFF00BCD4);
      case 'statisticien':
        return const Color(0xFF9C27B0);
      case 'team_dvcr':
        return adminGold;
      case 'partenaire':
        return const Color(0xFFFF9100);
      case 'donateur':
        return const Color(0xFF4CAF50);
      default:
        return adminGrey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.workspace_premium_rounded;
      case 'community_manager':
        return Icons.shield_rounded;
      case 'editor':
        return Icons.edit_note_rounded;
      case 'statisticien':
        return Icons.query_stats_rounded;
      case 'team_dvcr':
        return Icons.bolt_rounded;
      case 'partenaire':
        return Icons.handshake_rounded;
      case 'donateur':
        return Icons.favorite_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'ADMIN';
      case 'community_manager':
        return 'CM';
      case 'editor':
        return 'ÉDITEUR';
      case 'statisticien':
        return 'STATS';
      case 'team_dvcr':
        return 'TEAM DVCR';
      case 'partenaire':
        return 'PARTENAIRE';
      case 'donateur':
        return 'FIDÈLE SUPPORTER';
      default:
        return 'SUPPORTER';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _allDocs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: adminGold),
      );
    }

    final allDocs = _allDocs;
    final totalCount = _totalUsersCount ?? allDocs.length;

    final docs = _query.isEmpty
        ? allDocs
        : allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final display = (data['displayName'] ?? data['name'] ?? '')
                .toString()
                .toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final first = (data['firstName'] ?? '').toString().toLowerCase();
            final last = (data['lastName'] ?? '').toString().toLowerCase();
            return display.contains(_query) ||
                email.contains(_query) ||
                first.contains(_query) ||
                last.contains(_query);
          }).toList();

    int countRole(String r) => allDocs
        .where(
          (d) =>
              ((d.data() as Map)['roles'] as List? ??
                      [(d.data() as Map)['role']])
                  .contains(r),
        )
        .length;

    final admins = countRole('admin');
    final teamDvcr = countRole('team_dvcr');
    final supporters = countRole('supporter') +
        countRole('donateur') +
        countRole('partenaire');

    return RefreshIndicator(
      color: adminGold,
      onRefresh: _refreshUsersFromServer,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (_refreshing)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                color: adminGold,
                backgroundColor: adminBorder,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AdminModuleHeader(
                title: 'Membres',
                subtitle:
                    'Liste des membres — recherche par nom ou email.',
                icon: Icons.group_rounded,
                accent: AdminModuleColors.administration,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AdminUsersHeroCard(
              total: totalCount,
              displayed: allDocs.length,
              admins: admins,
              teamDvcr: teamDvcr,
              supporters: supporters,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _query.isEmpty
                    ? (allDocs.length >= totalCount
                        ? '$totalCount membres'
                        : '${allDocs.length} sur $totalCount membres')
                    : '${docs.length} résultat(s) sur ${allDocs.length}',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AdminSearchBar(
                controller: _searchCtrl,
                hint: 'Rechercher par prénom, nom ou email…',
                onChanged: (_) => setState(() {}),
                onClear: () => setState(() {}),
              ),
            ),
          ),
          if (docs.isEmpty && _query.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Aucun résultat',
                  style: GoogleFonts.inter(color: adminGrey),
                ),
              ),
            )
          else if (docs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Aucun résultat',
                  style: GoogleFonts.inter(color: adminGrey),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: docs.length,
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  i == 0 ? 0 : 8,
                  16,
                  i == docs.length - 1 ? 16 : 0,
                ),
                child: _UserTile(
                  doc: docs[i],
                  roleColor: _roleColor,
                  roleIcon: _roleIcon,
                  roleLabel: _roleLabel,
                  visibleRoles: _visibleRoles,
                  adminRoles: _adminRoles,
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

// ── Suppression compte Firebase (admin) ────────────────────────────────────────
class _AdminDeleteUserConfirmDialog extends StatefulWidget {
  final String displayLabel;
  final String uid;

  const _AdminDeleteUserConfirmDialog({
    required this.displayLabel,
    required this.uid,
  });

  @override
  State<_AdminDeleteUserConfirmDialog> createState() =>
      _AdminDeleteUserConfirmDialogState();
}

class _AdminDeleteUserConfirmDialogState
    extends State<_AdminDeleteUserConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ctrl.text.trim() == 'SUPPRIMER';
    return AlertDialog(
      backgroundColor: adminCard,
      title: Text(
        'Supprimer le compte Firebase ?',
        style: GoogleFonts.barlowCondensed(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: adminTextPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.displayLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.uid,
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
            const SizedBox(height: 12),
            Text(
              'Seront supprimés : compte Authentication, document Firestore '
              '`users` et sous-collections favorites, xp_log, badge_log.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: adminGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontSize: 14, color: adminTextPrimary),
              decoration: InputDecoration(
                labelText: 'Tape SUPPRIMER pour confirmer',
                labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: adminBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: adminGold, width: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Annuler',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: adminGrey,
            ),
          ),
        ),
        TextButton(
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Supprimer définitivement',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: adminRed,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _adminSendPasswordResetEmailAction(
  BuildContext context,
  String? rawEmail,
) async {
  final email = (rawEmail ?? '').toString().trim();
  final messenger = ScaffoldMessenger.of(context);
  if (email.isEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Pas d'email sur ce profil — impossible d'envoyer la réinitialisation.",
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  try {
    await AdminUserFirebaseActionsService.sendPasswordResetEmail(email);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Email de réinitialisation envoyé à $email',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.message ?? e.code,
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Erreur : $e', style: GoogleFonts.inter()),
        backgroundColor: adminRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _adminConfirmDeleteFirebaseUser(
  BuildContext context,
  String uid,
  Map<String, dynamic> userData,
) async {
  final dn = (userData['displayName'] as String?)?.trim();
  final em = (userData['email'] as String?)?.trim();
  final label = (dn != null && dn.isNotEmpty) ? dn : (em ?? uid);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AdminDeleteUserConfirmDialog(
      displayLabel: label,
      uid: uid,
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await AdminUserFirebaseActionsService.deleteAuthUserAndFirestoreData(uid);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Compte supprimé (Firebase Auth + données profil) : $label',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } on FirebaseFunctionsException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.message ?? e.code,
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Erreur : $e', style: GoogleFonts.inter()),
        backgroundColor: adminRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Tuile utilisateur ─────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Color Function(String) roleColor;
  final IconData Function(String) roleIcon;
  final String Function(String) roleLabel;
  final List<String> visibleRoles;
  final List<String> adminRoles;

  const _UserTile({
    required this.doc,
    required this.roleColor,
    required this.roleIcon,
    required this.roleLabel,
    required this.visibleRoles,
    required this.adminRoles,
  });

  List<String> _getRoles(Map<String, dynamic> d) {
    final rolesList = d['roles'];
    if (rolesList is List && rolesList.isNotEmpty) {
      return rolesList.whereType<String>().toList();
    }
    final single = d['role'] as String?;
    return single != null ? [single] : ['supporter'];
  }

  Future<void> _openRoleDialog(
    BuildContext context,
    Map<String, dynamic> d,
  ) async {
    final currentRoles = _getRoles(d);
    await showDialog(
      context: context,
      builder: (_) => _RolePickerDialog(
        uid: doc.id,
        currentRoles: currentRoles,
        visibleRoles: visibleRoles,
        adminRoles: adminRoles,
        roleColor: roleColor,
        roleLabel: roleLabel,
        canEditStaffRoles:
            AdminController.maybeOf(context)
                ?.canAction(AdminAction.assignStaffRoles) ??
            false,
      ),
    );
  }

  void _openUserXpPanel(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet<void>(
      useRootNavigator: true,
    context: context,
      backgroundColor: adminBg,
      barrierColor: Colors.black.withAlpha(90),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Material(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: _UserXpPanel(uid: doc.id, userData: d),
      ),
    );
  }

  void _openPaymentsPanel(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet<void>(
      useRootNavigator: true,
    context: context,
      backgroundColor: adminBg,
      barrierColor: Colors.black.withAlpha(90),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Material(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: _UserPaymentsPanel(uid: doc.id, userData: d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AdminController.maybeOf(context);
    final canAssignCommunity =
        ctrl?.canAction(AdminAction.assignCommunityRoles) ?? false;
    final canAssignStaff =
        ctrl?.canAction(AdminAction.assignStaffRoles) ?? false;
    final canManualXp = ctrl?.canAction(AdminAction.manualXpAdjust) ?? false;
    final canDeleteFirebase =
        ctrl?.canAction(AdminAction.deleteFirebaseUser) ?? false;
    final canEditRoles = canAssignCommunity || canAssignStaff;

    final d = doc.data() as Map<String, dynamic>;
    final roles = _getRoles(d);
    final primary = roles.first;
    final email = d['email'] ?? d['uid'] ?? 'Inconnu';
    final display = d['displayName'] ?? d['name'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: roleColor(primary).withAlpha(40),
          child:
              Icon(roleIcon(primary), size: 18, color: roleColor(primary)),
        ),
        title: Text(
          display.isNotEmpty ? display : email,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: adminTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: roles
                  .map(
                    (r) => AdminRoleChip(
                      label: roleLabel(r),
                      color: roleColor(r),
                      icon: roleIcon(r),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        trailing: Theme(
          data: Theme.of(context).copyWith(
            splashColor: adminGold.withAlpha(50),
            highlightColor: adminGold.withAlpha(28),
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surface: adminCard,
              onSurface: adminTextPrimary,
            ),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: adminGrey,
              size: 18,
            ),
            color: adminCard,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: adminBorder),
            ),
            onSelected: (v) {
              if (v == 'roles') {
                _openRoleDialog(context, d);
                return;
              }
              if (v == 'xp_user') {
                _openUserXpPanel(context, d);
                return;
              }
              if (v == 'payments') {
                _openPaymentsPanel(context, d);
                return;
              }
              if (v == 'send_reset') {
                unawaited(_adminSendPasswordResetEmailAction(
                  context,
                  d['email'] as String?,
                ));
                return;
              }
              if (v == 'delete_firebase') {
                unawaited(_adminConfirmDeleteFirebaseUser(context, doc.id, d));
                return;
              }
            },
            itemBuilder: (_) => [
              if (canEditRoles)
                PopupMenuItem(
                  value: 'roles',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.manage_accounts_rounded,
                        size: 16,
                        color: adminGold,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Modifier les rôles',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (canManualXp)
                PopupMenuItem(
                  value: 'xp_user',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: adminGold,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'XP membre',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'payments',
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      size: 16,
                      color: adminGreenAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Paiements',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'send_reset',
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 16,
                      color: adminBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Email réinitialisation mot de passe',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (canDeleteFirebase) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete_firebase',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_forever_rounded,
                        size: 16,
                        color: adminRed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Supprimer compte Firebase (Auth + profil)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: adminRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dialog sélection multi-rôles ──────────────────────────────────────────────
class _UserPaymentsPanel extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const _UserPaymentsPanel({
    required this.uid,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final totalDonations = (userData['totalDonations'] as num?)?.toDouble() ?? 0;
    final displayName =
        (userData['displayName'] ?? userData['name'] ?? userData['email'] ?? uid)
            .toString();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16.0 + MainShellInsets.keyboardBottom(context),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAIEMENTS',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: adminGold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: adminBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniInfoPill(
                          icon: Icons.favorite_rounded,
                          label: 'Total ${totalDonations.toStringAsFixed(2)} €',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('donations')
                      .where('userId', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: adminGold),
                      );
                    }

                    final docs = [...snap.data!.docs];
                    docs.sort((a, b) {
                      final aDate = _paymentSortDate(a.data());
                      final bDate = _paymentSortDate(b.data());
                      return bDate.compareTo(aDate);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Aucun paiement enregistré pour cet utilisateur.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: adminGrey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                        final source = (data['source'] ?? data['method'] ?? 'manuel')
                            .toString();
                        final status =
                            (data['status'] ?? 'inconnu').toString().toUpperCase();
                        final paidAt = _paymentSortDate(data);
                        final expiresAt = _asDateTime(data['expiresAt']);
                        final paymentId =
                            (data['paymentId'] ?? '').toString().trim();
                        final orderId =
                            (data['orderId'] ?? '').toString().trim();

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: adminCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: adminBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${amount.toStringAsFixed(2)} €',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: adminTextPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: adminGreenAccent.withAlpha(18),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: adminGreenAccent.withAlpha(80),
                                      ),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: adminGreenAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MiniInfoPill(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: source.toUpperCase(),
                                  ),
                                  _MiniInfoPill(
                                    icon: Icons.schedule_rounded,
                                    label: _formatAdminDate(paidAt),
                                  ),
                                  if (paymentId.isNotEmpty)
                                    _MiniInfoPill(
                                      icon: Icons.confirmation_number_rounded,
                                      label: 'Payment #$paymentId',
                                    ),
                                  if (orderId.isNotEmpty)
                                    _MiniInfoPill(
                                      icon: Icons.inventory_2_rounded,
                                      label: 'Order #$orderId',
                                    ),
                                ],
                              ),
                              if (expiresAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Expire le ${_formatAdminDate(expiresAt)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: adminGreyLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _paymentSortDate(Map<String, dynamic> data) {
  return _asDateTime(data['paidAt']) ??
      _asDateTime(data['createdAt']) ??
      _asDateTime(data['timestamp']) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatAdminDate(DateTime? date) {
  if (date == null) return 'Date inconnue';
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class _RolePickerDialog extends StatefulWidget {
  final String uid;
  final List<String> currentRoles;
  final List<String> visibleRoles;
  final List<String> adminRoles;
  final Color Function(String) roleColor;
  final String Function(String) roleLabel;
  final bool canEditStaffRoles;

  const _RolePickerDialog({
    required this.uid,
    required this.currentRoles,
    required this.visibleRoles,
    required this.adminRoles,
    required this.roleColor,
    required this.roleLabel,
    this.canEditStaffRoles = false,
  });

  @override
  State<_RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<_RolePickerDialog> {
  late String _communityRole;
  late Set<String> _selectedAdmin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _communityRole = widget.currentRoles.firstWhere(
      (r) => widget.visibleRoles.contains(r),
      orElse: () => 'supporter',
    );
    _selectedAdmin = widget.currentRoles
        .where((r) => widget.adminRoles.contains(r))
        .toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final allRoles = <String>{_communityRole, ..._selectedAdmin}.toList();
    const priority = [
      'admin',
      'community_manager',
      'editor',
      'statisticien',
      'team_dvcr',
      'supporter',
    ];
    final primary = priority.firstWhere(
      (r) => allRoles.contains(r),
      orElse: () => 'supporter',
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .update({
      'role': primary,
      'roles': allRoles,
      'canAccessChat': true,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rôles',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'COMMUNAUTÉ',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: adminGrey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            ...widget.visibleRoles.map(
              (r) => RadioListTile<String>(
                dense: true,
                value: r,
                groupValue: _communityRole,
                activeColor: widget.roleColor(r),
                title: Text(
                  widget.roleLabel(r),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: widget.roleColor(r),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _communityRole = v);
                },
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A)),
            if (widget.canEditStaffRoles) ...[
              Text(
                'FONCTIONS ADMIN',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: adminGrey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              ...widget.adminRoles.map(
                (r) => CheckboxListTile(
                  dense: true,
                  value: _selectedAdmin.contains(r),
                  activeColor: widget.roleColor(r),
                  checkColor: adminOnAccent,
                  title: Text(
                    widget.roleLabel(r),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: widget.roleColor(r),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedAdmin.add(r);
                      } else {
                        _selectedAdmin.remove(r);
                      }
                    });
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(
                    'Annuler',
                    style: GoogleFonts.inter(color: adminGrey),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: adminGreen,
                    foregroundColor: Colors.black,
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
                          'Enregistrer',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700),
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

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: adminBorder.withAlpha(45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: adminBorder.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: adminGold),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminGrey,
            ),
          ),
        ],
      ),
    );
  }
}
// ── Panneau XP membre (visuels de rang = paliers dans XP → Niveaux uniquement) ─
class _UserXpPanel extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const _UserXpPanel({required this.uid, required this.userData});

  @override
  State<_UserXpPanel> createState() => _UserXpPanelState();
}

class _UserXpPanelState extends State<_UserXpPanel> {
  late final TextEditingController _xpCtrl;
  bool _savingXp = false;

  @override
  void initState() {
    super.initState();
    final currentXp = (widget.userData['xp'] as num?)?.toInt() ?? 0;
    _xpCtrl = TextEditingController(text: currentXp.toString());
  }

  @override
  void dispose() {
    _xpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['displayName'] ?? widget.userData['email'] ?? 'Utilisateur';
    final currentXp = (widget.userData['xp'] as num?)?.toInt() ?? 0;
    final level = (widget.userData['level'] as num?)?.toInt() ?? 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: adminBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: adminGreen.withAlpha(30),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: adminGold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                      Text(
                        'Niveau $level · $currentXp XP',
                        style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminBlue.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminBlue.withAlpha(55)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: adminBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Les images de rang viennent uniquement des paliers '
                            '(Admin → XP → Niveaux, URL par niveau). Il n\'y a plus '
                            'de badges séparés à attribuer ici.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: adminGrey,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AdminModuleColors.administration.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AdminModuleColors.administration,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$currentXp XP',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AdminModuleColors.administration,
                              ),
                            ),
                            Text(
                              'Niveau $level',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Modifier l\'XP',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: adminGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _xpCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(fontSize: 14, color: adminTextPrimary),
                          decoration: InputDecoration(
                            labelText: 'XP total',
                            labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                            filled: true,
                            fillColor: adminCard,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: adminBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AdminModuleColors.administration,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            suffix: Text(
                              'XP',
                              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _savingXp ? null : _saveXp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AdminModuleColors.administration,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _savingXp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'OK',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ajout rapide',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: adminGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 25, 50, 100, 250, 500].map((delta) {
                      return GestureDetector(
                        onTap: () {
                          final cur = int.tryParse(_xpCtrl.text) ?? currentXp;
                          _xpCtrl.text = (cur + delta).toString();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: adminGreenAccent.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: adminGreenAccent.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            '+$delta',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: adminGreenAccent,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveXp() async {
    final newXp = int.tryParse(_xpCtrl.text);
    if (newXp == null) return;
    setState(() => _savingXp = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'xp': newXp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('XP mis à jour'), backgroundColor: adminGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: adminRed, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _savingXp = false);
    }
  }
}
