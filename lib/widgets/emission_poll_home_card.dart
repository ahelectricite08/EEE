import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/chat_screen.dart' show AuthLockScreen;
import '../services/emission_poll_service.dart';
import '../theme/app_colors.dart';
import 'live_interaction_card_ui.dart';

const _kGold = Color(0xFFC8A436);
const _kRed = Color(0xFFBA203C);
const _kGrey = Color(0xFF9CA39A);
const _kBorder = Color(0xFF2A2824);
const _kText = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFF1E1E1E);
const _kRadius = 20.0;

class EmissionPollHomeSlot extends StatelessWidget {
  final bool isAdmin;

  const EmissionPollHomeSlot({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('emission')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null || !EmissionPollService.hasVisiblePoll(data)) {
          return const SizedBox.shrink();
        }

        if (EmissionPollService.isPollActive(data)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            EmissionPollService.ensurePollState(data);
          });
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: EmissionPollHomeCard(emissionData: data, isAdmin: isAdmin),
        );
      },
    );
  }
}

class EmissionPollHomeCard extends StatefulWidget {
  final Map<String, dynamic> emissionData;
  final bool isAdmin;

  const EmissionPollHomeCard({
    super.key,
    required this.emissionData,
    this.isAdmin = false,
  });

  @override
  State<EmissionPollHomeCard> createState() => _EmissionPollHomeCardState();
}

class _EmissionPollHomeCardState extends State<EmissionPollHomeCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant EmissionPollHomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (!EmissionPollService.isPollActive(widget.emissionData)) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _vote(String optionId) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await EmissionPollService.castVote(optionId: optionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ton vote émission a bien été enregistré.'),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openAdminEditor() async {
    final titleCtrl = TextEditingController(
      text: (widget.emissionData['pollTitle'] as String? ?? '').trim(),
    );
    final subtitleCtrl = TextEditingController(
      text: (widget.emissionData['pollSubtitle'] as String? ?? '').trim(),
    );
    final sponsorCtrl = TextEditingController(
      text: (widget.emissionData['pollSponsorName'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (widget.emissionData['pollBackgroundImage'] as String? ?? '')
          .trim(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              var saving = false;

              Future<void> save() async {
                if (saving) return;
                setSheetState(() => saving = true);
                try {
                  await FirebaseFirestore.instance
                      .collection('live')
                      .doc('emission')
                      .set({
                        'pollTitle': titleCtrl.text.trim(),
                        'pollSubtitle': subtitleCtrl.text.trim(),
                        'pollSponsorName': sponsorCtrl.text.trim(),
                        'pollBackgroundImage': backgroundCtrl.text.trim(),
                      }, SetOptions(merge: true));
                  if (!mounted || !context.mounted || !sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Carte sondage rapide mise à jour.'),
                    ),
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => saving = false);
                  }
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Éditer le sondage rapide',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu peux changer le titre, le sous-titre, le sponsor et l\'image de fond directement ici.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PollAdminField(
                      controller: titleCtrl,
                      label: 'Titre',
                      hint: 'Question du direct',
                    ),
                    const SizedBox(height: 12),
                    _PollAdminField(
                      controller: subtitleCtrl,
                      label: 'Sous titre',
                      hint: 'Petit texte optionnel',
                    ),
                    const SizedBox(height: 12),
                    _PollAdminField(
                      controller: sponsorCtrl,
                      label: 'Nom du sponsor',
                      hint: 'Nom affiche',
                    ),
                    const SizedBox(height: 12),
                    _PollAdminField(
                      controller: backgroundCtrl,
                      label: 'URL image de fond',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          saving ? 'ENREGISTREMENT...' : 'ENREGISTRER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    titleCtrl.dispose();
    subtitleCtrl.dispose();
    sponsorCtrl.dispose();
    backgroundCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = EmissionPollService.isPollActive(widget.emissionData);
    final title = (widget.emissionData['pollTitle'] as String? ?? '').trim();
    final subtitle = (widget.emissionData['pollSubtitle'] as String? ?? '')
        .trim();
    final backgroundImage =
        ((widget.emissionData['pollBackgroundImage'] as String? ?? '').trim())
            .isNotEmpty
        ? (widget.emissionData['pollBackgroundImage'] as String).trim()
        : 'https://static.wixstatic.com/media/e91e00_5df52471e9f346068fdaa2274b9e6245~mv2.jpg';
    final sponsorName =
        (widget.emissionData['pollSponsorName'] as String? ?? '').trim();
    final sponsorLogo =
        (widget.emissionData['pollSponsorLogo'] as String? ?? '').trim();
    final options = EmissionPollService.optionMaps(widget.emissionData);
    final voteTotal = EmissionPollService.totalVotes(widget.emissionData);
    final timerLabel = isActive
        ? _remainingLabel(widget.emissionData)
        : null;

    return LiveInteractionCardShell(
      backgroundImageUrl: backgroundImage,
      header: LiveInteractionHeroHeader(
        eyebrow: 'SONDAGE ÉMISSION',
        title: title.isEmpty ? 'Sondage en cours' : title,
        subtitle: subtitle.isEmpty ? null : subtitle,
        isLive: isActive,
        sponsorLogoUrl: sponsorLogo.isNotEmpty ? sponsorLogo : null,
        sponsorName: sponsorName.isNotEmpty ? sponsorName : null,
        icon: Icons.poll_rounded,
        trailing: widget.isAdmin
            ? LiveInteractionAdminChip(onTap: _openAdminEditor)
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveInteractionMetaRow(
            chips: [
              if (timerLabel != null)
                LiveInteractionMetaChip(
                  icon: Icons.timer_rounded,
                  label: timerLabel,
                  highlight: isActive,
                ),
              LiveInteractionMetaChip(
                icon: Icons.how_to_vote_rounded,
                label: voteTotal <= 1 ? '$voteTotal vote' : '$voteTotal votes',
              ),
              LiveInteractionMetaChip(
                icon: Icons.list_alt_rounded,
                label: '${options.length} réponses',
              ),
              LiveInteractionMetaChip(
                icon: Icons.visibility_off_rounded,
                label: 'Votes masqués',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const LiveInteractionHint(
            text:
                'Tape une réponse pour voter. Les résultats restent cachés pendant le direct.',
          ),
          if (FirebaseAuth.instance.currentUser == null)
                    _GuestPollPrompt(
                      isActive: isActive,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthLockScreen(),
                        ),
                      ),
                    )
                  else
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('live')
                          .doc('emission')
                          .collection('pollVotes')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final voteData = snap.data?.data();
                        final sameSession =
                            (voteData?['sessionId'] as String? ?? '').trim() ==
                            ((widget.emissionData['pollSessionId'] as String? ??
                                    '')
                                .trim());
                        final selectedOptionId = sameSession
                            ? (voteData?['optionId'] as String? ?? '').trim()
                            : '';

                        return Column(
                          children: options.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final letter = String.fromCharCode(
                              65 + (index % 26),
                            );
                            final optionId = (option['id'] as String? ?? '')
                                .trim();
                            final selected = selectedOptionId == optionId;
                            final label =
                                (option['label'] as String? ?? '').trim();
                            return LiveInteractionChoiceRow(
                              letter: letter,
                              label: label.isEmpty ? 'Option $letter' : label,
                              hint: selected
                                  ? 'Ton vote est enregistré'
                                  : null,
                              selected: selected,
                              enabled: isActive && !_sending,
                              onTap: () => _vote(optionId),
                            );
                          }).toList(),
                        );
                      },
                    ),
          if (!isActive &&
              EmissionPollService.shouldRevealResults(widget.emissionData) &&
              ((widget.emissionData['pollWinnerLabel'] as String? ?? '')
                  .trim()
                  .isNotEmpty)) ...[
            const SizedBox(height: 4),
            LiveInteractionResultBanner(
              text:
                  'Résultat : ${(widget.emissionData['pollWinnerLabel'] as String).trim()}',
            ),
          ],
        ],
      ),
    );
  }

  String _remainingLabel(Map<String, dynamic> data) {
    final endsAt = data['pollEndsAt'];
    if (endsAt is! Timestamp) return '10:00';
    final remaining = endsAt.toDate().difference(_now);
    if (remaining.isNegative) return '00:00';
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PollAdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _PollAdminField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13, color: _kText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _kGrey),
            filled: true,
            fillColor: _kSurfaceMuted,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kGold),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestPollPrompt extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _GuestPollPrompt({required this.isActive, required this.onTap});

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
            isActive ? 'Connecte-toi pour participer' : 'Le sondage est clos',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColorsLight.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isActive
                ? 'Le sondage émission est réservé aux membres connectés.'
                : 'Tu pourras participer au prochain direct.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColorsLight.textSecondary,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
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
        ],
      ),
    );
  }
}
