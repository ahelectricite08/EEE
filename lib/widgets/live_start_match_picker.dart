import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/match_model.dart';
import '../screens/admin/admin_palette.dart';
import '../screens/home/home_palette.dart';
import '../services/live_start_service.dart';

/// Liste déroulante pour choisir le match à diffuser (admin / pilotage rapide).
class LiveStartMatchPicker extends StatelessWidget {
  const LiveStartMatchPicker({
    super.key,
    required this.matches,
    required this.value,
    required this.onChanged,
    this.useAdminStyle = false,
  });

  final List<MatchModel> matches;
  final MatchModel? value;
  final ValueChanged<MatchModel?> onChanged;
  final bool useAdminStyle;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: useAdminStyle ? adminOrange.withAlpha(18) : homeRed.withAlpha(18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: useAdminStyle ? adminOrange.withAlpha(80) : homeRed.withAlpha(80),
          ),
        ),
        child: Text(
          'Aucun match prévu dans les ${LiveStartService.pickableDaysAhead} prochains jours. '
          'Ajoute ou déplace un match dans Admin → Match.',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: useAdminStyle ? adminTextPrimary : homeText,
            height: 1.35,
          ),
        ),
      );
    }

    final borderColor = useAdminStyle ? adminBorder : homeBorder;
    final fillColor = useAdminStyle ? adminCardHigh : homeSurface;
    final labelColor = useAdminStyle ? adminGrey : homeMutedText;
    final textColor = useAdminStyle ? adminTextPrimary : homeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<MatchModel>(
          value: value != null && matches.any((m) => m.id == value!.id) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText:
                'Match (${LiveStartService.pickableDaysAhead} prochains jours)',
            labelStyle: GoogleFonts.inter(fontSize: 11, color: labelColor),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          dropdownColor: useAdminStyle ? adminCard : homeSurface,
          style: GoogleFonts.inter(fontSize: 12, color: textColor),
          items: matches
              .map(
                (m) => DropdownMenuItem<MatchModel>(
                  value: m,
                  child: Text(
                    LiveStartMatchPicker.labelFor(m),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        Text(
          'Seuls les matchs d’aujourd’hui et des '
          '${LiveStartService.pickableDaysAhead} prochains jours apparaissent ici.',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: labelColor,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  static String labelFor(MatchModel match) {
    final date = DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(match.date);
    final comp = match.competition.trim();
    final statusSuffix = switch (match.status) {
      MatchStatus.live => ' · EN DIRECT',
      MatchStatus.finished => ' · terminé',
      MatchStatus.upcoming => '',
    };
    final compSuffix = comp.isEmpty ? '' : ' · $comp';
    return '${match.team1} vs ${match.team2} — $date$compSuffix$statusSuffix';
  }
}
