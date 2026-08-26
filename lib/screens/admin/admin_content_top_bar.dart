import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_nav_model.dart';
import 'admin_palette.dart';
import 'widgets/admin_global_search.dart';

/// Top bar desktop : titre surface + recherche / retour profil.
class AdminContentTopBar extends StatelessWidget {
  final String tabLabel;
  final bool showBackToProfile;

  const AdminContentTopBar({
    super.key,
    required this.tabLabel,
    required this.showBackToProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: adminBg,
        border: Border(bottom: BorderSide(color: adminHairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tabLabel,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 0.4,
                height: 1,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Rechercher',
            onPressed: () => showAdminGlobalSearch(context),
            icon: const Icon(Icons.search_rounded, color: adminGrey, size: 20),
          ),
          if (showBackToProfile)
            IconButton(
              tooltip: 'Retour au profil',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.person_rounded,
                color: adminGrey,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet liste des outils (mobile).
Future<void> showAdminAllToolsSheet({
  required BuildContext context,
  required List<AdminTabDef> tabs,
  required ValueChanged<int> onSelected,
}) {
  return showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    backgroundColor: adminCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'Sections',
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
              ),
            ),
          ),
          for (final group in groupAdminTabsByUniverse(tabs)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
              child: Text(
                group.$1.label.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: group.$1.color,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            for (final t in group.$2)
              ListTile(
                dense: true,
                leading: Icon(t.icon, size: 20, color: group.$1.color),
                title: Text(
                  t.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(t.index);
                },
              ),
          ],
        ],
      ),
    ),
  );
}
