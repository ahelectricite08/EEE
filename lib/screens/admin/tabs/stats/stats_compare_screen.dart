import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import 'stats_admin_helpers.dart';
import 'stats_compare_view.dart';

/// Écran plein page comparaison — comme l’éditeur d’article.
class StatsCompareScreen extends StatelessWidget {
  final List<AdminMatchRowData> selectedRows;

  const StatsCompareScreen({super.key, required this.selectedRows});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        backgroundColor: adminBg,
        foregroundColor: adminTextPrimary,
        elevation: 0,
        title: Text(
          'COMPARAISON',
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: StatsCompareView(selectedRows: selectedRows),
      ),
    );
  }
}
