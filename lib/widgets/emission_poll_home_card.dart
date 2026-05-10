import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/chat_screen.dart' show AuthLockScreen;
import '../services/emission_poll_service.dart';
import '../theme/app_colors.dart';

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
    final options = EmissionPollService.optionMaps(widget.emissionData);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColorsLight.card,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppColorsLight.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                color: AppColors.gold,
              ),
            ),
            if (backgroundImage.isNotEmpty)
              ClipRRect(
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        backgroundImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColorsLight.cardMuted),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white.withAlpha(35),
                              AppColorsLight.card,
                            ],
                            stops: const [0.0, 0.62, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: AppColorsLight.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColorsLight.border),
                    ),
                    child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColorsLight.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColorsLight.border,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.poll_rounded,
                                    color: AppColors.green,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'SONDAGE ÉMISSION',
                                              style:
                                                  GoogleFonts.barlowCondensed(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.green,
                                                letterSpacing: 1.2,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                          _StatusTag(
                                            label: isActive
                                                ? 'LIVE'
                                                : 'SONDAGE',
                                            active: isActive,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        title,
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppColorsLight.textPrimary,
                                          height: 1.05,
                                          letterSpacing: 0.15,
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color:
                                                AppColorsLight.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (widget.isAdmin) ...[
                                  const SizedBox(width: 8),
                                  _PollAdminEditChip(onTap: _openAdminEditor),
                                ],
                              ],
                            ),
                          ),
                  if (sponsorName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PollPill(icon: Icons.campaign_rounded, label: sponsorName),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    decoration: BoxDecoration(
                      color: AppColorsLight.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColorsLight.border),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PollPill(
                          icon: Icons.list_alt_rounded,
                          label: '${options.length} choix',
                        ),
                        _PollPill(
                          icon: isActive
                              ? Icons.timer_rounded
                              : Icons.lock_clock_rounded,
                          label: isActive
                              ? _remainingLabel(widget.emissionData)
                              : 'Sondage clos',
                          highlight: isActive,
                        ),
                        const _PollPill(
                          icon: Icons.visibility_off_rounded,
                          label: 'Votes privés',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: AppColorsLight.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColorsLight.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Choisis une réponse puis valide. Les votes restent masqués pendant le direct.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColorsLight.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: !isActive || _sending
                                    ? null
                                    : () => _vote(optionId),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFFFF9E8)
                                        : AppColorsLight.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? _kGold.withAlpha(200)
                                          : AppColorsLight.border,
                                      width: selected ? 1.5 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: _kGold.withAlpha(28),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: AppColorsLight.cardMuted,
                                          border: Border.all(
                                            color: AppColorsLight.border,
                                          ),
                                        ),
                                        child: Text(
                                          letter,
                                          style:
                                              GoogleFonts.barlowCondensed(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.green,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? _kGold.withAlpha(40)
                                              : AppColorsLight.cardMuted,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? _kGold
                                                : AppColorsLight.border,
                                          ),
                                        ),
                                        child: Icon(
                                          selected
                                              ? Icons.check_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          color: selected
                                              ? AppColors.green
                                              : AppColorsLight.textMuted,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (option['label'] as String? ?? '')
                                                  .trim(),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColorsLight.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              selected
                                                  ? 'Ton choix est bien pris en compte'
                                                  : 'Appuie pour participer au sondage',
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                color:
                                                    AppColorsLight.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? _kGold
                                              : AppColorsLight.cardMuted,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? _kGold
                                                : AppColorsLight.border,
                                          ),
                                          boxShadow: selected
                                              ? [
                                                  BoxShadow(
                                                    color: _kGold.withAlpha(50),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          selected ? 'CHOISI' : 'VOTER',
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? Colors.black
                                                : AppColors.green,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  if (!isActive &&
                      EmissionPollService.shouldRevealResults(
                        widget.emissionData,
                      ) &&
                      ((widget.emissionData['pollWinnerLabel'] as String? ?? '')
                          .trim()
                          .isNotEmpty)) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kGold.withAlpha(120)),
                      ),
                      child: Text(
                        'Résultat final : ${(widget.emissionData['pollWinnerLabel'] as String).trim()}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColorsLight.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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

class _PollPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _PollPill({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFFF9E8)
            : AppColorsLight.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? _kGold.withAlpha(140) : AppColorsLight.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? AppColors.green : AppColorsLight.textSecondary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColorsLight.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusTag({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFFF5F5)
            : AppColorsLight.cardMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? _kRed.withAlpha(140) : AppColorsLight.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _kRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.barlowCondensed(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: active ? _kRed : AppColors.green,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PollAdminEditChip extends StatelessWidget {
  final VoidCallback onTap;

  const _PollAdminEditChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _kGold.withAlpha(18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kGold.withAlpha(70)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_rounded, size: 14, color: _kGold),
              const SizedBox(width: 6),
              Text(
                'EDITER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kGold,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
