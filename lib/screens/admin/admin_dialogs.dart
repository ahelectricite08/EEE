import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';

/// Poignée en haut des bottom sheets (cohérence avec le reste du panel).
Widget adminBottomSheetHandle() {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: adminBorder,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

/// Boîte de confirmation — retourne true si confirmé.
Future<bool> adminConfirm(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withAlpha(120),
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: adminCardDecoration(radius: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CONFIRMATION',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminRed,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: adminTextPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: adminTextPrimary,
                            side: const BorderSide(color: adminBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Annuler',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: adminRed,
                            foregroundColor: adminOnAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'CONFIRMER',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}

/// Dialog formulaire — retourne true si validé.
Future<bool> adminShowFormDialog(
  BuildContext context,
  String title,
  List<Widget> fields,
) async {
  return await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withAlpha(120),
        builder: (dialogContext) {
          final maxH = (MediaQuery.sizeOf(dialogContext).height * 0.86)
              .clamp(280.0, 620.0);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480, maxHeight: maxH),
              child: Container(
                decoration: adminCardDecoration(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: adminTextPrimary,
                              letterSpacing: 0.8,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vérifie les champs avant de valider.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: adminGrey,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: adminBorder),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: fields,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: adminBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: adminTextPrimary,
                                side: const BorderSide(color: adminBorder),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Annuler',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: adminGold,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'VALIDER',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
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
        },
      ) ??
      false;
}

/// Helper pour actions async avec gestion d'erreur automatique.
Future<void> adminRunAction(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
  VoidCallback? onDone,
}) async {
  try {
    await action();
    if (context.mounted && successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: adminGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    onDone?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
