import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/first_scorer_bet.dart';
import '../../../../models/sedan_squad.dart';
import '../../../../services/sedan_squad_service.dart';
import '../../../../widgets/sedan_squad_player_picker.dart';
import '../../admin_palette.dart';

/// Override manuel du 1er buteur (si les faits de jeu ne suffisent pas).
class FirstScorerOverrideEditor extends StatelessWidget {
  final String? kind;
  final String? playerId;
  final String? playerName;
  final ValueChanged<({String? kind, String? playerId, String? playerName})>
      onChanged;

  const FirstScorerOverrideEditor({
    super.key,
    required this.kind,
    required this.playerId,
    required this.playerName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, snap) {
        final squad = snap.data ?? SedanSquad.empty;
        final auto = kind == null || kind!.isEmpty;
        final opponent = kind == FirstScorerBetPick.kindOpponent;
        final sedan = kind == FirstScorerBetPick.kindSedan;

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1ER BUTEUR (PARI)',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Par défaut : premier but des faits de jeu. Utilise ce choix '
                  'seulement si le live est incomplet.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: adminGrey,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      label: 'Auto (live)',
                      selected: auto,
                      onTap: () => onChanged((
                        kind: null,
                        playerId: null,
                        playerName: null,
                      )),
                    ),
                    _chip(
                      label: 'Adversaire',
                      selected: opponent,
                      onTap: () => onChanged((
                        kind: FirstScorerBetPick.kindOpponent,
                        playerId: null,
                        playerName: null,
                      )),
                    ),
                    _chip(
                      label: sedan && (playerName ?? '').isNotEmpty
                          ? playerName!
                          : 'Joueur CSSA',
                      selected: sedan,
                      onTap: () async {
                        final p = await showSedanSquadSinglePicker(
                          context,
                          title: '1er buteur CSSA',
                          accent: adminGold,
                        );
                        if (p == null) return;
                        if (!context.mounted) return;
                        onChanged((
                          kind: FirstScorerBetPick.kindSedan,
                          playerId: p.id,
                          playerName: p.name,
                        ));
                      },
                    ),
                  ],
                ),
                if (squad.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Effectif Sedan vide — saisis-le dans Stades / effectif.',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? adminGold.withAlpha(28) : adminCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? adminGold : adminHairline,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? adminGold : adminTextPrimary,
          ),
        ),
      ),
    );
  }
}

void applyFirstScorerOverrideToPayload({
  required Map<String, dynamic> payload,
  required bool isUpdate,
  required String? kind,
  required String? playerId,
  required String? playerName,
}) {
  if (kind == FirstScorerBetPick.kindOpponent) {
    payload['firstScorerOverride'] = {'kind': FirstScorerBetPick.kindOpponent};
    return;
  }
  if (kind == FirstScorerBetPick.kindSedan &&
      (playerName ?? '').trim().isNotEmpty) {
    payload['firstScorerOverride'] = {
      'kind': FirstScorerBetPick.kindSedan,
      'playerId': (playerId ?? '').trim(),
      'playerName': playerName!.trim(),
    };
    return;
  }
  if (isUpdate) {
    payload['firstScorerOverride'] = FieldValue.delete();
  }
}
