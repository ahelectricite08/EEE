import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/chat_screen.dart' show AuthLockScreen;
import '../services/motm_vote_service.dart';
import '../theme/app_colors.dart';

const _kGold = Color(0xFFC8A436);
const _kRed = Color(0xFFBA203C);
const _kRadius = 20.0;

class MotmVoteHomeSlot extends StatelessWidget {
  final bool isAdmin;

  const MotmVoteHomeSlot({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null || !MotmVoteService.hasVisibleVote(data)) {
          return const SizedBox.shrink();
        }

        if ((data['motmVoteStatus'] as String? ?? '').trim() == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MotmVoteService.ensureVoteState(data);
          });
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: MotmVoteHomeCard(liveData: data, isAdmin: isAdmin),
        );
      },
    );
  }
}

class MotmVoteHomeCard extends StatefulWidget {
  final Map<String, dynamic> liveData;
  final bool isAdmin;

  const MotmVoteHomeCard({
    super.key,
    required this.liveData,
    this.isAdmin = false,
  });

  @override
  State<MotmVoteHomeCard> createState() => _MotmVoteHomeCardState();
}

class _MotmVoteHomeCardState extends State<MotmVoteHomeCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _sending = false;
  String _selectedTeamId = '';
  String _selectedCandidateId = '';

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant MotmVoteHomeCard oldWidget) {
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
    if (!MotmVoteService.isVoteActive(widget.liveData)) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _vote(String candidateId) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await MotmVoteService.castVote(candidateId: candidateId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton vote a bien été enregistré.')),
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
      text: (widget.liveData['motmVoteTitle'] as String? ?? '').trim(),
    );
    final sponsorNameCtrl = TextEditingController(
      text: (widget.liveData['motmVoteSponsorName'] as String? ?? '').trim(),
    );
    final sponsorLogoCtrl = TextEditingController(
      text: (widget.liveData['motmVoteSponsorLogo'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (widget.liveData['motmVoteBackgroundImage'] as String? ?? '')
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
                      .doc('current')
                      .set({
                        'motmVoteTitle': titleCtrl.text.trim(),
                        'motmVoteSponsorName': sponsorNameCtrl.text.trim(),
                        'motmVoteSponsorLogo': sponsorLogoCtrl.text.trim(),
                        'motmVoteBackgroundImage': backgroundCtrl.text.trim(),
                      }, SetOptions(merge: true));
                  if (!mounted || !context.mounted || !sheetContext.mounted) {
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Carte joueur du match mise à jour.'),
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
                      'Éditer la carte joueur du match',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu peux changer le titre, le sponsor et l\'image de fond quand tu veux.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AdminField(
                      controller: titleCtrl,
                      label: 'Titre',
                      hint: 'Joueur du match',
                    ),
                    const SizedBox(height: 12),
                    _AdminField(
                      controller: sponsorNameCtrl,
                      label: 'Nom du sponsor',
                      hint: 'MANEO',
                    ),
                    const SizedBox(height: 12),
                    _AdminField(
                      controller: sponsorLogoCtrl,
                      label: 'URL logo sponsor',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 12),
                    _AdminField(
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
    sponsorNameCtrl.dispose();
    sponsorLogoCtrl.dispose();
    backgroundCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = MotmVoteService.isVoteActive(widget.liveData);
    final title =
        (widget.liveData['motmVoteTitle'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultTitle
        : (widget.liveData['motmVoteTitle'] as String).trim();
    final sponsorName =
        (widget.liveData['motmVoteSponsorName'] as String? ?? 'MANEO').trim();
    final sponsorLogo =
        (widget.liveData['motmVoteSponsorLogo'] as String? ?? '').trim();
    final backgroundImage =
        (widget.liveData['motmVoteBackgroundImage'] as String? ?? '').trim();
    final teams = MotmVoteService.teamMaps(widget.liveData);

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
            ClipRRect(
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildBackgroundImage(backgroundImage),
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
                                    Icons.emoji_events_rounded,
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
                                              'HOMME DU MATCH',
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
                                          _VoteStatusTag(
                                            label: isActive
                                                ? 'LIVE'
                                                : 'VOTE',
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
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (widget.isAdmin) ...[
                                      _AdminEditChip(onTap: _openAdminEditor),
                                      const SizedBox(height: 8),
                                    ],
                                    _SponsorBadge(
                                      sponsorLogo: sponsorLogo,
                                      sponsorName: sponsorName,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                        _InfoPill(
                          icon: Icons.shield_rounded,
                          label: '${teams.length} équipes proposées',
                        ),
                        _InfoPill(
                          icon: isActive
                              ? Icons.timer_rounded
                              : Icons.lock_clock_rounded,
                          label: isActive
                              ? _remainingLabel(widget.liveData)
                              : 'Vote clos',
                          highlight: isActive,
                        ),
                        const _InfoPill(
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
                            'Choisis une équipe, puis un seul joueur. Les autres supporters ne voient pas les votes.',
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
                  const SizedBox(height: 16),
                  if (FirebaseAuth.instance.currentUser == null)
                    _GuestVotePrompt(
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
                          .doc('current')
                          .collection('motmVotes')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, voteSnap) {
                        final voteData = voteSnap.data?.data();
                        final sameSession =
                            (voteData?['sessionId'] as String? ?? '').trim() ==
                            ((widget.liveData['motmVoteSessionId'] as String? ??
                                    '')
                                .trim());
                        final selectedCandidateId = sameSession
                            ? (voteData?['candidateId'] as String? ?? '').trim()
                            : '';
                        final selectedTeamId = sameSession
                            ? (voteData?['teamId'] as String? ?? '').trim()
                            : '';
                        final selectedTeam = _resolveSelectedTeam(
                          teams,
                          selectedTeamId,
                        );
                        final selectedTeamResolvedId =
                            (selectedTeam?['id'] as String? ?? '').trim();
                        final candidates = selectedTeam == null
                            ? const <Map<String, dynamic>>[]
                            : MotmVoteService.candidatesForTeam(
                                widget.liveData,
                                selectedTeamResolvedId,
                              );
                        final resolvedCandidateId = _resolveSelectedCandidateId(
                          candidates,
                          selectedCandidateId,
                        );
                        final resolvedCandidate = resolvedCandidateId.isEmpty
                            ? null
                            : MotmVoteService.candidateById(
                                widget.liveData,
                                resolvedCandidateId,
                              );

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColorsLight.cardMuted,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColorsLight.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _VoteStepLabel(
                                index: '1',
                                label: 'Choisis une équipe',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  for (var i = 0; i < teams.length; i++)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: i == teams.length - 1
                                              ? 0
                                              : 10,
                                        ),
                                        child: _TeamVoteButton(
                                          slotLetter: String.fromCharCode(
                                            65 + (i % 26),
                                          ),
                                          label:
                                              (teams[i]['name'] as String? ??
                                                      '')
                                                  .trim(),
                                          selected:
                                              (teams[i]['id'] as String? ?? '')
                                                  .trim() ==
                                              selectedTeamResolvedId,
                                          enabled: isActive,
                                          onTap: () => setState(() {
                                            _selectedTeamId =
                                                (teams[i]['id'] as String? ??
                                                        '')
                                                    .trim();
                                            _selectedCandidateId = '';
                                          }),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _VoteStepLabel(
                                index: '2',
                                label: 'Choisis un joueur',
                              ),
                              const SizedBox(height: 10),
                              if (selectedTeam == null)
                                _EmptyPlayerState(
                                  label:
                                      'Sélectionne une équipe pour afficher ses joueurs.',
                                )
                              else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColorsLight.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColorsLight.border,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: resolvedCandidateId.isEmpty
                                          ? null
                                          : resolvedCandidateId,
                                      isExpanded: true,
                                      dropdownColor: AppColorsLight.card,
                                      iconEnabledColor: AppColors.green,
                                      hint: Text(
                                        'Sélectionne un joueur',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColorsLight.textMuted,
                                        ),
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColorsLight.textPrimary,
                                      ),
                                      items: candidates.map((candidate) {
                                        final candidateId =
                                            (candidate['id'] as String? ?? '')
                                                .trim();
                                        final candidateName =
                                            (candidate['name'] as String? ?? '')
                                                .trim();
                                        return DropdownMenuItem<String>(
                                          value: candidateId,
                                          child: Text(
                                            candidateName,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColorsLight.textPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: !isActive
                                          ? null
                                          : (value) => setState(() {
                                              _selectedCandidateId =
                                                  value?.trim() ?? '';
                                            }),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sélectionne un joueur puis appuie sur le bouton pour valider ton vote.',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColorsLight.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap:
                                      !isActive ||
                                          _sending ||
                                          resolvedCandidateId.isEmpty
                                      ? null
                                      : () => _vote(resolvedCandidateId),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color:
                                          resolvedCandidateId.isEmpty ||
                                              !isActive
                                          ? AppColorsLight.cardMuted
                                          : resolvedCandidateId ==
                                                selectedCandidateId
                                          ? const Color(0xFFFFF9E8)
                                          : AppColorsLight.cardMuted,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColorsLight.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: resolvedCandidateId.isEmpty
                                                ? AppColorsLight.card
                                                : resolvedCandidateId ==
                                                      selectedCandidateId
                                                ? _kGold.withAlpha(35)
                                                : AppColorsLight.card,
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                            border: Border.all(
                                              color: AppColorsLight.border,
                                            ),
                                          ),
                                          child: Icon(
                                            resolvedCandidateId ==
                                                        selectedCandidateId &&
                                                    selectedCandidateId
                                                        .isNotEmpty
                                                ? Icons.check_rounded
                                                : Icons.person_rounded,
                                            color:
                                                resolvedCandidateId ==
                                                        selectedCandidateId &&
                                                    selectedCandidateId
                                                        .isNotEmpty
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
                                                (resolvedCandidate?['name']
                                                                as String? ??
                                                            '')
                                                        .trim()
                                                        .isEmpty
                                                    ? 'Choisis un joueur pour voter'
                                                    : (resolvedCandidate!['name']
                                                              as String)
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
                                                resolvedCandidateId.isEmpty
                                                    ? 'Sélectionne un joueur dans la liste'
                                                    : 'Valide ton choix pour compter ton vote',
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
                                            color: resolvedCandidateId.isEmpty
                                                ? AppColorsLight.cardMuted
                                                : resolvedCandidateId ==
                                                      selectedCandidateId
                                                ? _kGold
                                                : AppColorsLight.cardMuted,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: resolvedCandidateId.isEmpty
                                                  ? AppColorsLight.border
                                                  : resolvedCandidateId ==
                                                        selectedCandidateId
                                                  ? _kGold
                                                  : AppColorsLight.border,
                                            ),
                                          ),
                                          child: Text(
                                            resolvedCandidateId.isEmpty
                                                ? 'CHOISIR'
                                                : resolvedCandidateId ==
                                                      selectedCandidateId
                                                ? 'VOTE OK'
                                                : 'VOTER',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: resolvedCandidateId.isEmpty
                                                  ? AppColorsLight.textMuted
                                                  : resolvedCandidateId ==
                                                        selectedCandidateId
                                                  ? Colors.black
                                                  : AppColors.green,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                !isActive
                                    ? 'Le vote est termine.'
                                    : selectedCandidateId.isEmpty
                                    ? 'Ton choix reste prive. Tu peux encore changer tant que le vote est ouvert.'
                                    : 'Vote enregistre pour ${(voteData?['candidateName'] as String? ?? '').trim()}. Tu peux modifier ton choix avant la cloture.',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: AppColorsLight.textMuted,
                                  height: 1.35,
                                ),
                              ),
                              if (!isActive &&
                                  MotmVoteService.shouldRevealWinner(
                                    widget.liveData,
                                  ) &&
                                  ((widget.liveData['motmVoteWinnerName']
                                              as String? ??
                                          '')
                                      .trim()
                                      .isNotEmpty)) ...[
                                const SizedBox(height: 14),
                                _WinnerBanner(liveData: widget.liveData),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _resolveSelectedTeam(
    List<Map<String, dynamic>> teams,
    String votedTeamId,
  ) {
    if (teams.isEmpty) return null;
    final desiredId = _selectedTeamId.isNotEmpty
        ? _selectedTeamId
        : votedTeamId;
    if (desiredId.isNotEmpty) {
      for (final team in teams) {
        if ((team['id'] as String? ?? '').trim() == desiredId) {
          return team;
        }
      }
    }
    return teams.first;
  }

  String _resolveSelectedCandidateId(
    List<Map<String, dynamic>> candidates,
    String votedCandidateId,
  ) {
    if (candidates.isEmpty) return '';
    final desiredId = _selectedCandidateId.isNotEmpty
        ? _selectedCandidateId
        : votedCandidateId;
    if (desiredId.isNotEmpty) {
      for (final candidate in candidates) {
        if ((candidate['id'] as String? ?? '').trim() == desiredId) {
          return desiredId;
        }
      }
    }
    return '';
  }

  Widget _buildBackgroundImage(String backgroundImage) {
    const fallbackPath =
        'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg';
    if (backgroundImage.isEmpty) {
      return Image.asset(
        fallbackPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.network(
      backgroundImage,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        fallbackPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  String _remainingLabel(Map<String, dynamic> liveData) {
    final endsAt = liveData['motmVoteEndsAt'];
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

class _GuestVotePrompt extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _GuestVotePrompt({required this.isActive, required this.onTap});

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
            isActive ? 'Connecte-toi pour voter' : 'Le vote est clos',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColorsLight.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isActive
                ? 'Le vote Homme du match est réservé aux membres connectés.'
                : 'Le vote est termine pour ce match.',
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

class _TeamVoteButton extends StatelessWidget {
  final String slotLetter;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TeamVoteButton({
    required this.slotLetter,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF9E8)
              : AppColorsLight.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _kGold.withAlpha(180)
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
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColorsLight.cardMuted,
                border: Border.all(color: AppColorsLight.border),
              ),
              child: Text(
                slotLetter,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.green,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColorsLight.textPrimary,
                  letterSpacing: 0.2,
                  height: 1.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlayerState extends StatelessWidget {
  final String label;
  const _EmptyPlayerState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColorsLight.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsLight.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppColorsLight.textSecondary,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _InfoPill({
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

class _VoteStepLabel extends StatelessWidget {
  final String index;
  final String label;

  const _VoteStepLabel({required this.index, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColorsLight.cardMuted,
            shape: BoxShape.circle,
            border: Border.all(color: AppColorsLight.border),
          ),
          alignment: Alignment.center,
          child: Text(
            index,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.green,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColorsLight.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _VoteStatusTag extends StatelessWidget {
  final String label;
  final bool active;

  const _VoteStatusTag({required this.label, required this.active});

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

class _AdminEditChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AdminEditChip({required this.onTap});

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

class _AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _AdminField({
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withAlpha(6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withAlpha(12)),
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

class _WinnerBanner extends StatelessWidget {
  final Map<String, dynamic> liveData;
  const _WinnerBanner({required this.liveData});

  @override
  Widget build(BuildContext context) {
    final winnerName = (liveData['motmVoteWinnerName'] as String? ?? '').trim();
    final winnerTeam = (liveData['motmVoteWinnerTeamName'] as String? ?? '')
        .trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withAlpha(120)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColorsLight.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColorsLight.border),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winnerName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColorsLight.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  winnerTeam.isEmpty ? 'Homme du match' : winnerTeam,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColorsLight.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorBadge extends StatelessWidget {
  final String sponsorLogo;
  final String sponsorName;

  const _SponsorBadge({required this.sponsorLogo, required this.sponsorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColorsLight.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColorsLight.border),
      ),
      child: sponsorLogo.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                sponsorLogo,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    _SponsorFallback(name: sponsorName),
              ),
            )
          : _SponsorFallback(name: sponsorName),
    );
  }
}

class _SponsorFallback extends StatelessWidget {
  final String name;
  const _SponsorFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColorsLight.cardMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColorsLight.border),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? 'M' : name.characters.first.toUpperCase(),
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.green,
          ),
        ),
      ),
    );
  }
}
