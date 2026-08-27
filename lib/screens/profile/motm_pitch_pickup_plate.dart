import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/live_state_service.dart';
import '../../services/motm_vote_service.dart';
import 'profile_palette.dart';
import 'profile_type.dart';

/// Plaque opérationnelle profil : qui aller chercher en bord de terrain.
class MotmPitchPickupPlate extends StatefulWidget {
  const MotmPitchPickupPlate({super.key});

  @override
  State<MotmPitchPickupPlate> createState() => _MotmPitchPickupPlateState();
}

class _MotmPitchPickupPlateState extends State<MotmPitchPickupPlate> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveStateService.watchCurrentSnapshots(),
      builder: (context, snap) {
        final exists = snap.data?.exists == true;
        final data = exists ? snap.data?.data() : null;
        if (!exists || data == null) {
          return const SizedBox.shrink();
        }
        if ((data['motmVoteStatus'] as String? ?? '').trim() == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MotmVoteService.ensureVoteState(data);
          });
        }
        final view = MotmVoteService.pitchPickupView(data, now: _now);
        if (!view.liveActive) return const SizedBox.shrink();
        return _MotmPickupCard(view: view);
      },
    );
  }
}

class _MotmPickupCard extends StatelessWidget {
  final MotmPitchPickupView view;

  const _MotmPickupCard({required this.view});

  @override
  Widget build(BuildContext context) {
    final split = MotmVoteService.splitPlayerLabel(view.playerName);
    final status = _statusChip();

    return DecoratedBox(
      decoration: profilePaper(
        edge: view.phase == MotmPitchPickupPhase.ready
            ? profileGold.withValues(alpha: 0.45)
            : profileHairline,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 14,
                  color: profileGoldDeep,
                ),
                const SizedBox(width: 6),
                Text('HOMME DU MATCH', style: ProfileType.kicker),
                const Spacer(),
                Text(
                  'BORD TERRAIN',
                  style: ProfileType.kicker.copyWith(
                    color: profileGreenBright,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: profileHairline),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (split.number.isNotEmpty && view.hasPlayer) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: profileGreen,
                      border: Border.all(color: profileGreenDeep),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        split.number,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headline(split.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileType.title.copyWith(
                          fontSize: view.hasPlayer ? 28 : 22,
                          height: 0.95,
                        ),
                      ),
                      if (view.teamName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          view.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ProfileType.label.copyWith(
                            color: profileMutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (view.winnerShareLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          view.winnerShareLabel,
                          style: ProfileType.label.copyWith(
                            color: profileGoldDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: status.bg,
                border: Border.all(color: status.edge),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: Text(
                  status.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: status.ink,
                  ),
                ),
              ),
            ),
            if (view.winnerShareLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                view.winnerShareLabel,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: profileGreenDeep,
                  letterSpacing: 0.2,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(_caption, style: ProfileType.caption),
          ],
        ),
      ),
    );
  }

  String _headline(String splitName) {
    switch (view.phase) {
      case MotmPitchPickupPhase.ready:
        return splitName.toUpperCase();
      case MotmPitchPickupPhase.voting:
      case MotmPitchPickupPhase.pending:
        return 'Pas encore désigné';
      case MotmPitchPickupPhase.idle:
        return 'Pas de vote';
    }
  }

  ({String label, Color ink, Color bg, Color edge}) _statusChip() {
    switch (view.phase) {
      case MotmPitchPickupPhase.voting:
        return (
          label: 'IL RESTE ${view.remainingLabel}',
          ink: profileGreenDeep,
          bg: const Color(0xFFE4F0EA),
          edge: profileGreenBright.withValues(alpha: 0.35),
        );
      case MotmPitchPickupPhase.pending:
        return (
          label: 'DÉPOUILLEMENT',
          ink: profileGoldDeep,
          bg: const Color(0xFFF6EED4),
          edge: profileGold.withValues(alpha: 0.4),
        );
      case MotmPitchPickupPhase.ready:
        return (
          label: 'VOTE TERMINÉ',
          ink: profileGreenDeep,
          bg: const Color(0xFFE4F0EA),
          edge: profileGreenBright.withValues(alpha: 0.35),
        );
      case MotmPitchPickupPhase.idle:
        return (
          label: 'EN ATTENTE',
          ink: profileMutedText,
          bg: profileSurfaceMuted,
          edge: profileHairline,
        );
    }
  }

  String get _caption {
    switch (view.phase) {
      case MotmPitchPickupPhase.voting:
        return 'Vote en cours — attendre le résultat avant d’aller le chercher.';
      case MotmPitchPickupPhase.pending:
        return 'Vote clos, le vainqueur arrive.';
      case MotmPitchPickupPhase.ready:
        return 'À récupérer en bord de terrain.';
      case MotmPitchPickupPhase.idle:
        return 'Aucun Homme du match à chercher pour l’instant.';
    }
  }
}
