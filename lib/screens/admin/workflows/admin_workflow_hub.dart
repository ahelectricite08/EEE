import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/match_post_media_admin_panel.dart';
import '../../../widgets/match_souvenir_partner_logo_admin_panel.dart';
import '../admin_controller.dart';
import '../admin_module_colors.dart';
import '../admin_module_shell.dart';
import '../admin_nav_model.dart';
import '../admin_palette.dart';
import '../admin_tab_registry.dart';
import 'admin_workflow_model.dart';

/// Hub d’un flux (Préparation / Après-match / Administration).
class AdminWorkflowHubPage extends StatefulWidget {
  final AdminWorkflowId workflowId;

  const AdminWorkflowHubPage({super.key, required this.workflowId});

  @override
  State<AdminWorkflowHubPage> createState() => _AdminWorkflowHubPageState();
}

class _AdminWorkflowHubPageState extends State<AdminWorkflowHubPage> {
  final GlobalKey _mediasSectionKey = GlobalKey();

  void _scrollToMedias() {
    final ctx = _mediasSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflowId = widget.workflowId;
    final def = AdminWorkflows.defOf(workflowId);
    final controller = AdminController.of(context);
    final allowed = controller.allowedIndices.toSet();
    final shortcuts = def.shortcuts
        .where((s) => allowed.contains(s.tabIndex))
        .toList();
    final showApresMedia = workflowId == AdminWorkflowId.apresMatch &&
        allowed.contains(AdminTabIndex.direct);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: def.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.label.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      letterSpacing: 0.6,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    def.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: adminGrey,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (shortcuts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucun outil de ce flux n’est accessible avec vos permissions.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: adminGrey,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(adminPaperRadius),
              border: Border.all(color: adminHairline, width: 1),
            ),
            child: Column(
              children: [
                for (var i = 0; i < shortcuts.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: adminBorder),
                  _ShortcutRow(
                    shortcut: shortcuts[i],
                    accent: def.color,
                    onTap: () {
                      final s = shortcuts[i];
                      if (s.stayOnHub) {
                        if (showApresMedia) _scrollToMedias();
                        return;
                      }
                      if (s.diffusionSubTab != null) {
                        controller.openToolFromHub(
                          s.tabIndex,
                          diffusionSubTab: s.diffusionSubTab,
                        );
                      } else {
                        controller.openToolFromHub(s.tabIndex);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        if (showApresMedia) ...[
          const SizedBox(height: 22),
          KeyedSubtree(
            key: _mediasSectionKey,
            child: AdminModuleSection(
              eyebrow: 'Après-match',
              title: 'Médias & export résumé',
              subtitle:
                  'Audio, clips vMix, parole du coach, export résumé — match terminé.',
              accent: AdminModuleColors.apresMatch,
              wrapInCard: false,
              child: const MatchPostMediaAdminPanel(),
            ),
          ),
          const SizedBox(height: 22),
          AdminModuleSection(
            eyebrow: 'Après-match',
            title: 'Souvenir — logo partenaire',
            subtitle:
                'Activer Créer mon souvenir pour les fans, et gérer le logo '
                'sponsor en haut à droite du cadre.',
            accent: AdminModuleColors.apresMatch,
            wrapInCard: false,
            child: const MatchSouvenirPartnerLogoAdminPanel(),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Tous les outils restent disponibles dans la navigation secondaire.',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: adminGreyLight,
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final AdminWorkflowShortcut shortcut;
  final Color accent;
  final VoidCallback onTap;

  const _ShortcutRow({
    required this.shortcut,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(shortcut.icon, size: 20, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortcut.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shortcut.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: adminGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                shortcut.stayOnHub
                    ? Icons.expand_more_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: adminGreyLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libellé affiché dans la top bar selon surface / onglet.
String adminSurfaceTitle({
  required AdminNavSurface surface,
  required AdminWorkflowId workflow,
  required int tab,
}) {
  if (surface == AdminNavSurface.workflowHub) {
    return AdminWorkflows.defOf(workflow).label;
  }
  for (final def in adminTabDefs) {
    if (def.index == tab) return def.label;
  }
  return 'ADMIN';
}
