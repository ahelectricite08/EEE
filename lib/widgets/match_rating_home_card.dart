import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/chat_screen.dart' show AuthLockScreen;
import '../services/match_rating_service.dart';
import '../theme/app_colors.dart';
import 'live_interaction_card_ui.dart';

const _kGold = Color(0xFFC8A436);

/// Accueil : note du match (1–10) après fin de match.
class MatchRatingHomeSlot extends StatelessWidget {
  const MatchRatingHomeSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null || !MatchRatingService.hasVisibleRating(data)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: MatchRatingHomeCard(liveData: data),
        );
      },
    );
  }
}

class MatchRatingHomeCard extends StatefulWidget {
  final Map<String, dynamic> liveData;

  const MatchRatingHomeCard({super.key, required this.liveData});

  @override
  State<MatchRatingHomeCard> createState() => _MatchRatingHomeCardState();
}

class _MatchRatingHomeCardState extends State<MatchRatingHomeCard> {
  bool _sending = false;

  Future<void> _rate(int value) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await MatchRatingService.castRating(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note enregistrée : $value/10')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (widget.liveData['matchRatingTitle'] as String? ?? '').trim().isEmpty
        ? MatchRatingService.defaultTitle
        : (widget.liveData['matchRatingTitle'] as String? ?? '').trim();
    final bg =
        (widget.liveData['matchRatingBackgroundImage'] as String? ?? '').trim();
    final total = MatchRatingService.totalVotes(widget.liveData);
    const fallbackAsset =
        'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg';

    return LiveInteractionCardShell(
      backgroundImageUrl: bg.isEmpty ? null : bg,
      fallbackAsset: fallbackAsset,
      header: LiveInteractionHeroHeader(
        eyebrow: 'NOTE DU MATCH',
        title: title,
        isLive: true,
        sponsorName: 'DVCR',
        icon: Icons.star_rate_rounded,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total > 0)
            LiveInteractionMetaRow(
              chips: [
                LiveInteractionMetaChip(
                  icon: Icons.how_to_vote_rounded,
                  label: total <= 1 ? '$total note' : '$total notes',
                ),
              ],
            ),
          const SizedBox(height: 12),
          const LiveInteractionHint(
            text: 'Donne une note de 1 à 10 pour ce match.',
          ),
          const SizedBox(height: 12),
          if (FirebaseAuth.instance.currentUser == null)
            _GuestRatingPrompt(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthLockScreen()),
              ),
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('live')
                  .doc('current')
                  .collection('matchRatings')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, voteSnap) {
                final voteData = voteSnap.data?.data();
                final sessionId =
                    (widget.liveData['matchRatingSessionId'] as String? ?? '')
                        .trim();
                final sameSession =
                    (voteData?['sessionId'] as String? ?? '').trim() ==
                    sessionId;
                final selected = sameSession
                    ? (voteData?['rating'] as num?)?.toInt() ?? 0
                    : 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(10, (index) {
                        final value = index + 1;
                        final isSelected = selected == value;
                        return _RatingChip(
                          value: value,
                          selected: isSelected,
                          enabled: !_sending,
                          onTap: () => _rate(value),
                        );
                      }),
                    ),
                    if (selected >= 1 && selected <= 10) ...[
                      const SizedBox(height: 10),
                      LiveInteractionResultBanner(
                        text: 'Ta note : $selected/10',
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final int value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RatingChip({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF9E8) : AppColorsLight.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? _kGold.withAlpha(220)
                  : AppColorsLight.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            '$value',
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: selected ? AppColors.green : AppColorsLight.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestRatingPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _GuestRatingPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColorsLight.cardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsLight.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connecte-toi pour noter',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColorsLight.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'La note du match est réservée aux membres connectés.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColorsLight.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'SE CONNECTER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
