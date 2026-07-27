import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../services/role_permissions_service.dart';
import '../../admin_controller.dart';
import '../../admin_actions.dart';

/// Matrice RBAC — édition admin uniquement.
class StaffPermissionsPanel extends StatelessWidget {
  const StaffPermissionsPanel({super.key});

  static const _roles = [
    {'key': 'admin', 'label': 'Admin', 'emoji': '👑'},
    {'key': 'community_manager', 'label': 'Community Manager', 'emoji': '🛡️'},
    {'key': 'editor', 'label': 'Éditeur', 'emoji': '✏️'},
    {'key': 'statisticien', 'label': 'Statisticien', 'emoji': '📊'},
    {'key': 'team_dvcr', 'label': 'Team DVCR', 'emoji': '⚡'},
    {'key': 'supporter', 'label': 'Membre', 'emoji': '⚽'},
  ];

  @override
  Widget build(BuildContext context) {
    final canEdit =
        AdminController.maybeOf(context)?.canAction(AdminAction.editRbacMatrix) ??
            false;

    return StreamBuilder<Map<String, List<String>>>(
      stream: RolePermissionsService.stream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: adminGold),
          );
        }
        final rolesData = snap.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: adminBlue.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: adminBlue.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: adminBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canEdit
                          ? 'Les permissions contrôlent l\'accès aux onglets du panel admin. Toute modification est immédiate.'
                          : 'Consultation réservée aux administrateurs pour modifier la matrice.',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                  ),
                ],
              ),
            ),
            ..._roles.map((role) {
              final roleKey = role['key'] as String;
              final perms = rolesData[roleKey] ?? <String>[];
              return _StaffRolePermRow(
                roleKey: roleKey,
                label: role['label'] as String,
                emoji: role['emoji'] as String,
                currentPerms: perms,
                allPerms: RolePermissionsService.allPermissions,
                readOnly: !canEdit,
              );
            }),
          ],
        );
      },
    );
  }
}

class _StaffRolePermRow extends StatefulWidget {
  final String roleKey;
  final String label;
  final String emoji;
  final List<String> currentPerms;
  final List<String> allPerms;
  final bool readOnly;

  const _StaffRolePermRow({
    required this.roleKey,
    required this.label,
    required this.emoji,
    required this.currentPerms,
    required this.allPerms,
    required this.readOnly,
  });

  @override
  State<_StaffRolePermRow> createState() => _StaffRolePermRowState();
}

class _StaffRolePermRowState extends State<_StaffRolePermRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.roleKey == 'admin';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _expanded ? adminOrange.withAlpha(60) : adminBorder),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: adminTextPrimary,
                          ),
                        ),
                        Text(
                          isAdmin
                              ? 'Toutes les permissions'
                              : '${widget.currentPerms.length} permission(s)',
                          style:
                              GoogleFonts.inter(fontSize: 11, color: adminGrey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: adminGrey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: adminBorder),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.allPerms.map((perm) {
                  final isActive =
                      isAdmin || widget.currentPerms.contains(perm);
                  return GestureDetector(
                    onTap: widget.readOnly || isAdmin
                        ? null
                        : () async {
                            final newPerms =
                                List<String>.from(widget.currentPerms);
                            if (isActive) {
                              newPerms.remove(perm);
                            } else {
                              newPerms.add(perm);
                            }
                            await RolePermissionsService.setRolePermissions(
                              widget.roleKey,
                              newPerms,
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isAdmin ? adminGold : adminBlue).withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive
                              ? (isAdmin ? adminGold : adminBlue).withAlpha(80)
                              : adminBorder,
                        ),
                      ),
                      child: Text(
                        perm.replaceAll('.', ' · '),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? (isAdmin ? adminGold : adminBlue)
                              : adminGrey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
