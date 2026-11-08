import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';
import 'admin_theme.dart';

/// Chrome commun des pages annexes (éditeur article, match, stats…).
class AdminAnnexScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final List<Widget> actions;
  final Widget body;
  final Widget? bottomBar;

  const AdminAnnexScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.accent = adminGreen,
    this.actions = const [],
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.wrap(Theme.of(context)),
      child: Scaffold(
        backgroundColor: adminBg,
        appBar: AppBar(
          backgroundColor: adminBg,
          foregroundColor: adminTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: adminTextPrimary),
            onPressed: () => Navigator.maybePop(context),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 0.5,
                  height: 1.05,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ],
          ),
          actions: actions,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: Container(height: 3, color: accent),
          ),
        ),
        body: body,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}
