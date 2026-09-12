import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/live_entry_error.dart';
import '../screens/admin/admin_palette.dart';
import '../screens/home/home_palette.dart';

Future<bool> showLiveEntryErrorConfirm(
  BuildContext context, {
  bool adminStyle = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: adminStyle ? adminCard : homeSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) {
      final surface = adminStyle ? adminCard : homeSurface;
      final text = adminStyle ? adminTextPrimary : homeText;
      final muted = adminStyle ? adminGrey : homeMutedText;
      final hairline = adminStyle ? adminBorder : homeHairline;
      final filet = adminStyle ? adminGreenAccent : homeGreen;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                LiveEntryError.uiLabel,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: text,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LiveEntryError.confirmTitle,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'On retire ce fait du fil. Le score et les cartons sont recalculés. '
                'Tout le monde reçoit : ${LiveEntryError.pushTitle} ${LiveEntryError.pushBody}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: muted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PaperBtn(
                      label: LiveEntryError.confirmNo,
                      onTap: () => Navigator.pop(ctx, false),
                      border: hairline,
                      text: muted,
                      surface: surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaperBtn(
                      label: LiveEntryError.confirmYes,
                      onTap: () => Navigator.pop(ctx, true),
                      border: filet,
                      text: filet,
                      surface: surface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok == true;
}

class _PaperBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color border;
  final Color text;
  final Color surface;

  const _PaperBtn({
    required this.label,
    required this.onTap,
    required this.border,
    required this.text,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ),
      ),
    );
  }
}
