import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_shared_widgets.dart';
import '../../admin_users_hero_card.dart';
import '../../../../services/role_permissions_service.dart';
import '../../../../services/sponsor_service.dart';
import '../../../../services/vote_history_service.dart';

class UsersTab extends StatefulWidget {
  const UsersTab();

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  static const _visibleRoles = [
    'supporter',
    'donateur',
    'partenaire',
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

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: adminGold),
          );
        }
        final allDocs = snap.data!.docs;

        final docs = _query.isEmpty
            ? allDocs
            : allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final display = (data['displayName'] ?? data['name'] ?? '')
                    .toString()
                    .toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final first =
                    (data['firstName'] ?? '').toString().toLowerCase();
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
        final partenaires = countRole('partenaire');
        final donateurs = countRole('donateur');

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: AdminUsersHeroCard(
                total: allDocs.length,
                admins: admins,
                teamDvcr: teamDvcr,
                partenaires: partenaires,
                donateurs: donateurs,
              ),
            ),
            const SliverToBoxAdapter(child: _RolesPermissionsCenter()),
            const SliverToBoxAdapter(child: _SponsorsAdminCenter()),
            const SliverToBoxAdapter(child: _VoteHistoryCenter()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: adminBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style:
                        GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par prénom, nom ou email…',
                      hintStyle:
                          GoogleFonts.inter(fontSize: 12, color: adminGrey),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: adminGrey,
                        size: 18,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: adminGrey,
                                size: 16,
                              ),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: adminBg,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: adminBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: adminBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: adminGold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (docs.isEmpty)
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
        );
      },
    );
  }
}

// ── Rôles & Permissions ───────────────────────────────────────────────────────
class _RolesPermissionsCenter extends StatelessWidget {
  const _RolesPermissionsCenter();

  @override
  Widget build(BuildContext context) {
    const roles = [
      (
        'admin',
        'ADMIN',
        Icons.workspace_premium_rounded,
        adminRed,
        ['Tous les onglets', 'Rôles', 'Notifs', 'Utilisateurs'],
      ),
      (
        'editor',
        'ÉDITEUR',
        Icons.edit_note_rounded,
        Color(0xFF00BCD4),
        ['Articles', 'Commentaires', 'Édition contenu'],
      ),
      (
        'community_manager',
        'CM',
        Icons.shield_rounded,
        Color(0xFF2979FF),
        ['Communauté', 'Matchs', 'Modération'],
      ),
      (
        'statisticien',
        'STATS',
        Icons.query_stats_rounded,
        Color(0xFF9C27B0),
        ['Direct', 'Stats', 'Suivi live'],
      ),
      (
        'team_dvcr',
        'TEAM DVCR',
        Icons.bolt_rounded,
        adminGold,
        ['Badge visible', 'Signalement messages'],
      ),
      (
        'partenaire',
        'PARTENAIRE',
        Icons.handshake_rounded,
        Color(0xFFFF9100),
        ['Badge visible'],
      ),
      (
        'donateur',
        'FIDÈLE',
        Icons.favorite_rounded,
        Color(0xFF4CAF50),
        ['Badge visible', 'Chat membre'],
      ),
      (
        'supporter',
        'SUPPORTER',
        Icons.person_rounded,
        adminGrey,
        ['Compte standard'],
      ),
    ];

    return StreamBuilder<Map<String, List<String>>>(
      stream: RolePermissionsService.stream(),
      builder: (context, snap) {
        final config =
            snap.data ?? RolePermissionsService.defaultPermissions;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [adminGold.withAlpha(14), adminCard],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RÔLES & PERMISSIONS',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: adminTextPrimary,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tu peux maintenant modifier les fonctions disponibles par rôle. Les onglets admin suivent cette configuration.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ...roles.map((role) {
                final roleKey = role.$1;
                final icon = role.$3;
                final color = role.$4;
                final perms = config[roleKey] ?? const <String>[];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _RolePermissionsDialog(
                        roleKey: roleKey,
                        roleLabel: role.$2,
                        color: color,
                        selected: perms,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withAlpha(32),
                                  color.withAlpha(16),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: color.withAlpha(80)),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        role.$2,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(18),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: color.withAlpha(70),
                                        ),
                                      ),
                                      child: Text(
                                        '${perms.length} droits',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.edit_rounded,
                                      color: adminGrey,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (perms.isEmpty)
                                  Text(
                                    'Aucune fonction active',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: adminGrey,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: perms.map((perm) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(14),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: color.withAlpha(60),
                                          ),
                                        ),
                                        child: Text(
                                          _permissionLabel(perm),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: adminGrey,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: role.$5
                                      .map(
                                        (hint) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                adminBorder.withAlpha(50),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            hint,
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              color: adminGrey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  String _permissionLabel(String permission) {
    switch (permission) {
      case RolePermissionsService.adminAccess:
        return 'Accès admin';
      case RolePermissionsService.adminDashboard:
        return 'Dashboard';
      case RolePermissionsService.adminDirect:
        return 'Direct';
      case RolePermissionsService.adminArticles:
        return 'Articles';
      case RolePermissionsService.adminMatches:
        return 'Matchs';
      case RolePermissionsService.adminStats:
        return 'Stats';
      case RolePermissionsService.adminNotifs:
        return 'Notifications';
      case RolePermissionsService.adminUsers:
        return 'Users';
      case RolePermissionsService.adminCommunity:
        return 'Communauté';
      case RolePermissionsService.chatAccess:
        return 'Accès chat';
      case RolePermissionsService.commentsModerate:
        return 'Modération commentaires';
      default:
        return permission;
    }
  }
}

// ── Dialog permissions d'un rôle ─────────────────────────────────────────────
class _RolePermissionsDialog extends StatefulWidget {
  final String roleKey;
  final String roleLabel;
  final Color color;
  final List<String> selected;

  const _RolePermissionsDialog({
    required this.roleKey,
    required this.roleLabel,
    required this.color,
    required this.selected,
  });

  @override
  State<_RolePermissionsDialog> createState() =>
      _RolePermissionsDialogState();
}

class _RolePermissionsDialogState extends State<_RolePermissionsDialog> {
  late Set<String> _selected;
  bool _saving = false;

  static const _items = [
    (RolePermissionsService.adminAccess, 'Accès admin'),
    (RolePermissionsService.adminDashboard, 'Dashboard'),
    (RolePermissionsService.adminDirect, 'Direct'),
    (RolePermissionsService.adminArticles, 'Articles'),
    (RolePermissionsService.adminMatches, 'Matchs'),
    (RolePermissionsService.adminStats, 'Stats'),
    (RolePermissionsService.adminNotifs, 'Notifications'),
    (RolePermissionsService.adminUsers, 'Utilisateurs'),
    (RolePermissionsService.adminCommunity, 'Communauté'),
    (RolePermissionsService.chatAccess, 'Accès chat'),
    (RolePermissionsService.commentsModerate, 'Modération commentaires'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await RolePermissionsService.setRolePermissions(
      widget.roleKey,
      _selected.toList(),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: adminCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions ${widget.roleLabel}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ..._items.map((item) {
              final key = item.$1;
              final checked = _selected.contains(key);
              return CheckboxListTile(
                dense: true,
                value: checked,
                activeColor: widget.color,
                checkColor: adminOnAccent,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.$2,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: adminGrey,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(key);
                    } else {
                      _selected.remove(key);
                    }
                  });
                },
              );
            }),
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
                    backgroundColor: widget.color,
                    foregroundColor: adminOnAccent,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: adminOnAccent,
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
      ),
    );
  }

  void _openUserXpPanel(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet<void>(
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
              if (v == 'roles') _openRoleDialog(context, d);
              if (v == 'xp_user') _openUserXpPanel(context, d);
              if (v == 'payments') _openPaymentsPanel(context, d);
            },
            itemBuilder: (_) => [
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
    final helloAsso =
        (userData['helloAsso'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
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
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
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
                        _MiniInfoPill(
                          icon: helloAsso['isDonateurActive'] == true
                              ? Icons.verified_rounded
                              : Icons.hourglass_disabled_rounded,
                          label: helloAsso['isDonateurActive'] == true
                              ? 'Donateur actif'
                              : 'Donateur inactif',
                        ),
                        if ((helloAsso['lastPaymentId'] ?? '').toString().isNotEmpty)
                          _MiniInfoPill(
                            icon: Icons.receipt_long_rounded,
                            label: 'Paiement #${helloAsso['lastPaymentId']}',
                          ),
                      ],
                    ),
                    if (helloAsso['donateurExpiresAt'] != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Expiration : ${_formatAdminDate(_asDateTime(helloAsso['donateurExpiresAt']))}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: adminGreyLight,
                        ),
                      ),
                    ],
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

  const _RolePickerDialog({
    required this.uid,
    required this.currentRoles,
    required this.visibleRoles,
    required this.adminRoles,
    required this.roleColor,
    required this.roleLabel,
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
      'partenaire',
      'donateur',
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
                    backgroundColor: adminGold,
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

// ── Gestion des sponsors ──────────────────────────────────────────────────────
class _SponsorsAdminCenter extends StatelessWidget {
  const _SponsorsAdminCenter();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SponsorService.stream(),
      builder: (context, snap) {
        final sponsors = snap.data ?? const <Map<String, dynamic>>[];
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'SPONSORS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: adminTextPrimary,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openSponsorEditor(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: adminGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AJOUTER',
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
              const SizedBox(height: 6),
              Text(
                'Enregistre une fois tes sponsors et reutilise-les dans les votes, emissions et cartes.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              if (sponsors.isEmpty)
                Text(
                  'Aucun sponsor enregistre pour le moment.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                )
              else
                ...sponsors.map((sponsor) {
                  final color = adminColorFromHex(
                    (sponsor['colorHex'] as String? ?? '').trim(),
                  );
                  final active = sponsor['active'] != false;
                  final logo =
                      (sponsor['logoUrl'] as String? ?? '').trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withAlpha(18),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: color.withAlpha(80)),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: logo.isEmpty
                                ? Icon(
                                    Icons.campaign_rounded,
                                    color: color,
                                    size: 18,
                                  )
                                : Image.network(
                                    logo,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.broken_image_rounded,
                                      color: color,
                                      size: 18,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (sponsor['name'] as String? ?? '')
                                            .trim(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
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
                                        color: active
                                            ? color.withAlpha(18)
                                            : adminBorder.withAlpha(38),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: active
                                              ? color.withAlpha(80)
                                              : adminBorder,
                                        ),
                                      ),
                                      child: Text(
                                        active ? 'ACTIF' : 'INACTIF',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: active ? color : adminGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if ((sponsor['colorHex'] as String? ??
                                            '')
                                        .trim()
                                        .isNotEmpty)
                                      _MiniInfoPill(
                                        icon: Icons.palette_rounded,
                                        label: (sponsor['colorHex']
                                                as String? ??
                                            ''),
                                      ),
                                    if ((sponsor['linkUrl'] as String? ??
                                            '')
                                        .trim()
                                        .isNotEmpty)
                                      const _MiniInfoPill(
                                        icon: Icons.link_rounded,
                                        label: 'Lien actif',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _openSponsorEditor(
                              context,
                              sponsor: sponsor,
                            ),
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: adminGold,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await SponsorService.deleteSponsor(
                                (sponsor['id'] as String? ?? '').trim(),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sponsor supprime.'),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: adminRed,
                              size: 18,
                            ),
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

  Future<void> _openSponsorEditor(
    BuildContext context, {
    Map<String, dynamic>? sponsor,
  }) async {
    final id = (sponsor?['id'] as String? ?? '').trim();
    final nameCtrl = TextEditingController(
      text: (sponsor?['name'] as String? ?? '').trim(),
    );
    final logoCtrl = TextEditingController(
      text: (sponsor?['logoUrl'] as String? ?? '').trim(),
    );
    final colorCtrl = TextEditingController(
      text: (sponsor?['colorHex'] as String? ?? '').trim(),
    );
    final linkCtrl = TextEditingController(
      text: (sponsor?['linkUrl'] as String? ?? '').trim(),
    );
    var active = sponsor?['active'] != false;
    var saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: adminCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id.isEmpty ? 'NOUVEAU SPONSOR' : 'MODIFIER LE SPONSOR',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                AdminField(ctrl: nameCtrl, label: 'Nom du sponsor'),
                const SizedBox(height: 10),
                AdminField(ctrl: logoCtrl, label: 'Logo (URL)'),
                const SizedBox(height: 10),
                AdminField(
                    ctrl: colorCtrl,
                    label: 'Couleur (hex, ex: #C8A436)'),
                const SizedBox(height: 10),
                AdminField(ctrl: linkCtrl, label: 'Lien (optionnel)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        active ? 'Sponsor actif' : 'Sponsor inactif',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: active,
                      onChanged: (value) =>
                          setModalState(() => active = value),
                      activeThumbColor: adminGold,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(ctx),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.inter(color: adminGrey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                await SponsorService.saveSponsor(
                                  id: id,
                                  name: nameCtrl.text.trim(),
                                  logoUrl: logoCtrl.text.trim(),
                                  colorHex: colorCtrl.text.trim(),
                                  linkUrl: linkCtrl.text.trim(),
                                  active: active,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sponsor enregistre.'),
                                  ),
                                );
                              } on StateError catch (error) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(error.message.toString()),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: adminGold,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(
                        'Enregistrer',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    logoCtrl.dispose();
    colorCtrl.dispose();
    linkCtrl.dispose();
  }
}

// ── Historique des votes ──────────────────────────────────────────────────────
class _VoteHistoryCenter extends StatelessWidget {
  const _VoteHistoryCenter();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: VoteHistoryService.streamRecent(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HISTORIQUE DES VOTES',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: adminTextPrimary,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tu retrouves ici les derniers votes clos avec leur gagnant, sponsor et volume de participation.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Text(
                  'Aucun vote archive pour le moment.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                )
              else
                ...docs.take(12).map((doc) {
                  final data = doc.data();
                  final sponsorColor = adminColorFromHex(
                    (data['sponsorColorHex'] as String? ?? '').trim(),
                  );
                  final closedAt = data['closedAt'];
                  final date = closedAt is Timestamp
                      ? closedAt.toDate()
                      : DateTime.now();
                  final type =
                      (data['type'] as String? ?? '').trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: sponsorColor.withAlpha(18),
                                  borderRadius:
                                      BorderRadius.circular(999),
                                  border: Border.all(
                                    color: sponsorColor.withAlpha(90),
                                  ),
                                ),
                                child: Text(
                                  type == 'motm_matchday'
                                      ? 'HOMME DU MATCH'
                                      : 'SONDAGE EMISSION',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: sponsorColor,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (data['title'] as String? ?? '').trim(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: adminTextPrimary,
                            ),
                          ),
                          if ((data['subtitle'] as String? ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              (data['subtitle'] as String).trim(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if ((data['sponsorName'] as String? ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _MiniInfoPill(
                                  icon: Icons.campaign_rounded,
                                  label: (data['sponsorName'] as String)
                                      .trim(),
                                ),
                              _MiniInfoPill(
                                icon: Icons.how_to_vote_rounded,
                                label:
                                    '${(data['totalVotes'] as num?)?.toInt() ?? 0} votes',
                              ),
                              if ((data['winnerName'] as String? ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _MiniInfoPill(
                                  icon: Icons.emoji_events_rounded,
                                  label: (data['winnerName'] as String)
                                      .trim(),
                                ),
                            ],
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
}

// ── Pill info générique ───────────────────────────────────────────────────────
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
                  backgroundColor: adminGold.withAlpha(30),
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
                            '(Admin → XP → Niveaux, URL par niveau). Il n’y a plus '
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          adminGold.withAlpha(25),
                          adminGold.withAlpha(10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: adminGold.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up_rounded, color: adminGold, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$currentXp XP',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: adminGold,
                              ),
                            ),
                            Text(
                              'Niveau $level',
                              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Modifier l’XP',
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
                              borderSide: const BorderSide(color: adminGold),
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE1C15A), adminGold],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _savingXp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'OK',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
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
