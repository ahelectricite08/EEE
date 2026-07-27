import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../navigation/community_chat_rollout.dart';
import '../../../../navigation/prono_championship_rollout.dart';
import '../../../../services/feature_flags_service.dart';

/// Chat Communauté — Réglages → Application.
class CommunityChatRolloutAdminSection extends StatelessWidget {
  const CommunityChatRolloutAdminSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHAT COMMUNAUTÉ',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminOrange,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visible par défaut. Désactiver masque l’onglet Communauté dans l’app.',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
            ),
            const SizedBox(height: 10),
            _RolloutFlagTile(
              flagKey: CommunityChatRollout.flagKey,
              title: 'Onglet Communauté (chat)',
              subtitle:
                  'Tribune membres · notifs « Communauté » dans Compte.',
              value: CommunityChatRollout.isVisible,
              onChanged: snap.hasData
                  ? (v) => FeatureFlagsService.setFlag(
                        CommunityChatRollout.flagKey,
                        v,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// Pronos championnat — onglet admin Pronos → Visibilité.
class PronoHubRolloutAdminSection extends StatelessWidget {
  const PronoHubRolloutAdminSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRONOS CHAMPIONNAT',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminGold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Masqué par défaut jusqu’à activation. Ligues, duels, classement club.',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
            ),
            const SizedBox(height: 10),
            _RolloutFlagTile(
              flagKey: PronoChampionshipRollout.hubFlagKey,
              title: 'Onglet Pronos (championnat)',
              subtitle:
                  'Barre du bas · notifs Pronos · raccourcis accueil / calendrier.',
              value: PronoChampionshipRollout.isHubVisible,
              onChanged: snap.hasData
                  ? (v) => FeatureFlagsService.setFlag(
                        PronoChampionshipRollout.hubFlagKey,
                        v,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _RolloutFlagTile extends StatelessWidget {
  final String flagKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _RolloutFlagTile({
    required this.flagKey,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  flagKey,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: adminGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.35),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Liste `seasons` + archivage admin (`status` → archived).
class CompetitionSeasonsSection extends StatefulWidget {
  const CompetitionSeasonsSection();

  @override
  State<CompetitionSeasonsSection> createState() =>
      _CompetitionSeasonsSectionState();
}

class _CompetitionSeasonsSectionState extends State<CompetitionSeasonsSection> {
  String? _archivingId;

  Future<void> _archiveSeason(String seasonId, String label) async {
    setState(() => _archivingId = seasonId);
    try {
      await FirebaseFirestore.instance.collection('seasons').doc(seasonId).set(
        {
          'status': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saison « $label » archivée')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'permission-denied'
          ? 'Accès refusé — rôle admin requis.'
          : 'Erreur Firestore : ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur archivage : $e')),
      );
    } finally {
      if (mounted) setState(() => _archivingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAISONS (COMPÉTITIONS)',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminOrange,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Collection seasons — archivage admin (Firestore, réservé admin).',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('seasons')
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Text(
                'Aucune saison. Crée un document dans `seasons` (label, status, …) depuis la console ou un import.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            return Column(
              children: docs.map((d) {
                final m = d.data();
                final label = (m['label'] ?? d.id).toString();
                final status = (m['status'] ?? 'draft').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status != 'archived')
                        TextButton(
                          onPressed: _archivingId == d.id
                              ? null
                              : () => _archiveSeason(d.id, label),
                          child: _archivingId == d.id
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'ARCHIVER',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    color: adminRed,
                                    fontSize: 11,
                                  ),
                                ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
