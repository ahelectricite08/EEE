import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../services/role_permissions_service.dart';
import '../../admin_controller.dart';
import '../../admin_actions.dart';
import '../../staff_postes.dart';

/// Postes du back-office : ce que chaque rôle voit, en français.
class StaffPermissionsPanel extends StatelessWidget {
  const StaffPermissionsPanel({super.key});

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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(adminPaperRadius),
                border: Border.all(color: adminHairline),
              ),
              child: Text(
                canEdit
                    ? 'Un poste = une personne. Coche les pages qu’elle a le droit d’ouvrir. Team DVCR / bénévoles n’entrent jamais ici (espace Bénévoles dans l’app).'
                    : 'Consultation. Seul un admin peut modifier les postes.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: adminGrey,
                ),
              ),
            ),
            for (final poste in StaffPostes.all)
              _PosteCard(
                poste: poste,
                currentPerms: rolesData[poste.firestoreKey] ?? const [],
                canEdit: canEdit,
              ),
          ],
        );
      },
    );
  }
}

class _PosteCard extends StatefulWidget {
  final StaffPosteDef poste;
  final List<String> currentPerms;
  final bool canEdit;

  const _PosteCard({
    required this.poste,
    required this.currentPerms,
    required this.canEdit,
  });

  @override
  State<_PosteCard> createState() => _PosteCardState();
}

class _PosteCardState extends State<_PosteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final poste = widget.poste;
    final isAdmin = poste.role.name == 'admin' || poste.firestoreKey == 'admin';
    final pages = RolePermissionsService.allPermissions
        .where((p) => p.startsWith('admin.') && p != RolePermissionsService.adminAccess)
        .toList();
    final activeCount = isAdmin
        ? pages.length
        : pages.where(widget.currentPerms.contains).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? poste.color.withAlpha(90) : adminHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: poste.color.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(poste.icon, color: poste.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poste.label.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: adminTextPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          poste.mission,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.35,
                            color: adminGrey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAdmin
                              ? 'Toutes les pages'
                              : '$activeCount page${activeCount > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: poste.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: adminGrey,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: adminHairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in poste.does)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '· ',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: poste.color,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.35,
                                color: adminTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'PAGES',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: adminGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pages.map((perm) {
                      final isActive =
                          isAdmin || widget.currentPerms.contains(perm);
                      return GestureDetector(
                        onTap: !widget.canEdit || isAdmin
                            ? null
                            : () async {
                                final next =
                                    List<String>.from(widget.currentPerms);
                                if (isActive) {
                                  next.remove(perm);
                                } else {
                                  next.add(perm);
                                }
                                if (!next.contains(
                                  RolePermissionsService.adminAccess,
                                )) {
                                  next.add(RolePermissionsService.adminAccess);
                                }
                                await RolePermissionsService.setRolePermissions(
                                  poste.firestoreKey,
                                  next,
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? poste.color.withAlpha(22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isActive
                                  ? poste.color.withAlpha(90)
                                  : adminHairline,
                            ),
                          ),
                          child: Text(
                            RolePermissionsService.labelOf(perm),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive ? poste.color : adminGrey,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
