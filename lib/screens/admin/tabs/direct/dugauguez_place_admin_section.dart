import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/dugauguez_place.dart';
import '../../../../services/dugauguez_place_service.dart';
import '../../../../widgets/dugauguez_place_card.dart';
import '../../admin_palette.dart';

/// Direct : switch TEST (sticker téléphone) + comparaison des 4 seaux.
/// Toujours visible, live ou pas — c’est le but du TEST.
class DugauguezPlaceAdminSection extends StatelessWidget {
  final Map<String, dynamic>? liveData;

  const DugauguezPlaceAdminSection({super.key, this.liveData});

  @override
  Widget build(BuildContext context) {
    final liveMatchId = (liveData?['matchId'] as String? ?? '').trim();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DugauguezPlaceService.instance.testRef.snapshots(),
      builder: (context, snap) {
        final on = DugauguezPlaceService.isForceTest(snap.data?.data());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MA PLACE DUGAUGUEZ',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminGold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sondage tribune (« où tu regardes »). Domicile CSSA, H-30 → KO+20. '
              'Les supporters votent sans voir les scores — comparaison plus bas. '
              'Le switch TEST marche même sans match live.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: adminGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _TestForceSwitch(
              on: on,
              streamError: snap.hasError,
              onChanged: (v) => _setForce(context, v),
            ),
            if (on) ...[
              const SizedBox(height: 12),
              const DugauguezPlaceSticker(
                matchId: DugauguezPlaceService.testMatchId,
                team1: 'CSSA',
                team2: 'TEST',
                preview: true,
              ),
            ],
            const SizedBox(height: 14),
            _ComparisonPanel(liveMatchId: liveMatchId, liveData: liveData),
          ],
        );
      },
    );
  }

  Future<void> _setForce(BuildContext context, bool on) async {
    try {
      await DugauguezPlaceService.instance.setForceTest(on);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de changer le switch : $e',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
  }
}

class _TestForceSwitch extends StatelessWidget {
  final bool on;
  final bool streamError;
  final ValueChanged<bool> onChanged;

  const _TestForceSwitch({
    required this.on,
    required this.streamError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: on ? adminGold.withAlpha(28) : adminCard,
        borderRadius: BorderRadius.circular(adminPaperRadius),
        border: Border.all(
          color: on ? adminGold : adminInk.withAlpha(40),
          width: on ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEST — sticker téléphone',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: adminInk,
                        letterSpacing: 0.4,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      on
                          ? 'ON — le sticker s’affiche sur l’app (rebuild du téléphone si rien).'
                          : 'OFF — sticker de test éteint. Allume pour forcer hors fenêtre.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: adminGrey,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    on ? 'ON' : 'OFF',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: on ? adminGreen : adminGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  Switch(
                    value: on,
                    onChanged: onChanged,
                    activeThumbColor: adminInk,
                    activeTrackColor: adminGold,
                  ),
                ],
              ),
            ],
          ),
          if (streamError) ...[
            const SizedBox(height: 8),
            Text(
              'Lecture Firestore en erreur — tu peux quand même basculer le switch.',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: adminRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  final String liveMatchId;
  final Map<String, dynamic>? liveData;

  const _ComparisonPanel({
    required this.liveMatchId,
    required this.liveData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DugauguezPlaceService.instance.watchRecentSummaries(),
      builder: (context, snap) {
        final docs = [...(snap.data?.docs ?? const [])];
        docs.sort((a, b) {
          final ta = a.data()['updatedAt'];
          final tb = b.data()['updatedAt'];
          final da = ta is Timestamp ? ta.toDate() : DateTime(1970);
          final db = tb is Timestamp ? tb.toDate() : DateTime(1970);
          return db.compareTo(da);
        });
        DocumentSnapshot<Map<String, dynamic>>? picked;
        if (liveMatchId.isNotEmpty) {
          for (final d in docs) {
            if (d.id == liveMatchId) {
              picked = d;
              break;
            }
          }
        }
        picked ??= docs.isEmpty ? null : docs.first;
        if (picked == null) {
          final t1 = (liveData?['team1'] ?? '').toString();
          final t2 = (liveData?['team2'] ?? '').toString();
          final label = t1.isNotEmpty && t2.isNotEmpty
              ? '$t1 – $t2 (live, 0 vote)'
              : 'Live ou dernier match';
          return DugauguezPlaceComparisonBars(
            counts: DugauguezPlaceCounts.empty(),
            matchLabel: label,
          );
        }
        final data = picked.data() ?? const <String, dynamic>{};
        final t1 = (data['team1'] ?? liveData?['team1'] ?? '').toString();
        final t2 = (data['team2'] ?? liveData?['team2'] ?? '').toString();
        final isLive = picked.id == liveMatchId;
        final name = t1.isNotEmpty && t2.isNotEmpty ? '$t1 – $t2' : picked.id;
        return DugauguezPlaceComparisonBars(
          counts: DugauguezPlaceCounts.fromMap(
            data['counts'] as Map<String, dynamic>?,
          ),
          matchLabel: isLive ? 'Live · $name' : 'Dernier · $name',
        );
      },
    );
  }
}
