import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sedan_squad.dart';
import '../navigation/main_shell_insets.dart';
import '../screens/chat_screen.dart' show AuthLockScreen;
import '../services/live_state_service.dart';
import '../services/match_partner_logos_service.dart';
import '../services/motm_vote_service.dart';
import '../services/sedan_squad_service.dart';
import '../theme/app_colors.dart';
import 'dvcr_network_image.dart';
import 'live_interaction_card_ui.dart';
import 'xi_mini_pitch.dart';

const _kGold = Color(0xFFC8A436);
const _kRed = Color(0xFFBA203C);
const _kRadius = 20.0;

class MotmVoteHomeSlot extends StatelessWidget {
  final bool isAdmin;

  const MotmVoteHomeSlot({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveStateService.watchCurrentSnapshots(),
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
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final msg = error.code == 'permission-denied'
          ? 'Vote impossible : droits insuffisants. Réessaie après mise à jour de l’app.'
          : 'Erreur : ${error.message ?? error.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      useRootNavigator: true,
    context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: MainShellInsets.sheetContentPadding(
            sheetContext,
            left: 20,
            top: 20,
            right: 20,
            extra: 20,
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
    final heroTitle = MotmVoteService.heroDisplayTitle(widget.liveData);
    final sponsorName =
        (widget.liveData['motmVoteSponsorName'] as String? ?? '').trim();
    final voteLogo =
        (widget.liveData['motmVoteSponsorLogo'] as String? ?? '').trim();
    final backgroundImage =
        (widget.liveData['motmVoteBackgroundImage'] as String? ?? '').trim();
    final teams = MotmVoteService.teamMaps(widget.liveData);
    final voteTotal = MotmVoteService.totalVotes(widget.liveData);
    final timerLabel =
        isActive ? _remainingLabel(widget.liveData) : null;
    const fallbackAsset =
        'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg';

    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        final squad = squadSnap.hasError
            ? SedanSquad.empty
            : (squadSnap.data ?? SedanSquad.empty);
        return StreamBuilder(
      stream: MatchPartnerLogosService.instance.watch(),
      builder: (context, logoSnap) {
        final sponsorLogo = MotmVoteService.resolveSponsorLogo(
          voteLogo: voteLogo,
          settingsLogo: logoSnap.data?.motmLogoUrl ?? '',
        );
        return LiveInteractionCardShell(
      backgroundImageUrl:
          backgroundImage.isEmpty ? null : backgroundImage,
      fallbackAsset: fallbackAsset,
      header: LiveInteractionHeroHeader(
        eyebrow: 'HOMME DU MATCH',
        title: heroTitle,
        isLive: isActive,
        sponsorLogoUrl: sponsorLogo.isEmpty ? null : sponsorLogo,
        sponsorLogoRevisionMillis: logoSnap.data?.revisionMillis ?? 0,
        sponsorName: sponsorLogo.isEmpty && sponsorName.isNotEmpty
            ? sponsorName
            : null,
        icon: Icons.emoji_events_rounded,
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
              if (!MotmVoteService.showsPublicWinner(widget.liveData))
                LiveInteractionMetaChip(
                  icon: Icons.groups_rounded,
                  label: teams.length <= 1
                      ? '${teams.length} équipe'
                      : '${teams.length} équipes',
                ),
              if (!MotmVoteService.showsPublicWinner(widget.liveData))
                const LiveInteractionMetaChip(
                  icon: Icons.visibility_off_rounded,
                  label: 'Votes masqués',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (MotmVoteService.showsPublicWinner(widget.liveData))
            _MotmWinnerEncarte(
              playerName: MotmVoteService.winnerNameOf(widget.liveData),
              teamName: MotmVoteService.winnerTeamNameOf(widget.liveData),
              logoUrl: MotmVoteService.winnerCrestUrl(widget.liveData),
              sedanPlayer: MotmVoteService.winnerIsSedan(widget.liveData)
                  ? squad.faceForVoteLabel(
                      MotmVoteService.winnerNameOf(widget.liveData),
                    )
                  : null,
            )
          else ...[
          const LiveInteractionHint(
            text:
                'Choisis ton équipe puis ton joueur. Un seul vote, modifiable tant que le direct est ouvert.',
          ),
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
                        final activeTeamId = selectedTeam == null
                            ? ''
                            : selectedTeamResolvedId;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Équipe',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColorsLight.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LiveInteractionTeamPicker(
                              teams: teams,
                              selectedTeamId: activeTeamId,
                              enabled: isActive,
                              onTeamSelected: (id) => setState(() {
                                _selectedTeamId = id;
                                _selectedCandidateId = '';
                              }),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Joueur',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColorsLight.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedTeam == null)
                              Text(
                                'Sélectionne une équipe pour voir les joueurs.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColorsLight.textMuted,
                                ),
                              )
                            else if (candidates.isEmpty)
                              Text(
                                'Aucun joueur configuré pour cette équipe.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColorsLight.textMuted,
                                ),
                              )
                            else if (MotmVoteService.isSedanMotmTeam(
                              widget.liveData,
                              selectedTeam,
                            ))
                              _MotmSedanCandidateGrid(
                                candidates: candidates,
                                squad: squad,
                                selectedCandidateId: selectedCandidateId,
                                enabled: isActive && !_sending,
                                onVote: _vote,
                              )
                            else
                              ...candidates.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final candidate = entry.value;
                                final candidateId =
                                    (candidate['id'] as String? ?? '').trim();
                                final candidateName =
                                    (candidate['name'] as String? ?? '').trim();
                                final selected =
                                    selectedCandidateId == candidateId &&
                                        candidateId.isNotEmpty;
                                return LiveInteractionChoiceRow(
                                  letter: '${idx + 1}',
                                  label: candidateName.isEmpty
                                      ? 'Joueur ${idx + 1}'
                                      : candidateName,
                                  hint: selected
                                      ? 'Ton vote est enregistré'
                                      : null,
                                  selected: selected,
                                  enabled: isActive && !_sending,
                                  onTap: () => _vote(candidateId),
                                );
                              }),
                          ],
                        );
                      },
                    ),
          ],
        ],
      ),
    );
      },
    );
      },
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

class _MotmWinnerEncarte extends StatelessWidget {
  final String playerName;
  final String teamName;
  final String logoUrl;
  final SedanSquadPlayer? sedanPlayer;

  const _MotmWinnerEncarte({
    required this.playerName,
    required this.teamName,
    required this.logoUrl,
    this.sedanPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final name = playerName.trim().isEmpty ? 'Joueur' : playerName.trim();
    final team = teamName.trim();
    final url = logoUrl.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColorsLight.cardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsLight.border),
      ),
      child: Row(
        children: [
          if (sedanPlayer != null) ...[
            SedanPlayerFace(
              player: sedanPlayer,
              size: 56,
              occupied: true,
              selected: true,
            ),
            const SizedBox(width: 14),
          ] else ...[
            SizedBox(
              width: 56,
              height: 56,
              child: url.isEmpty
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColorsLight.scaffold,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColorsLight.border),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.green,
                        size: 28,
                      ),
                    )
                  : DvcrNetworkImage(
                      url,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      cacheWidth: dvcrCrestCacheWidth(context, 56),
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shield_outlined,
                        color: AppColors.green,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÉLU',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: _kGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: AppColorsLight.textPrimary,
                  ),
                ),
                if (team.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    team,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColorsLight.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

/// Grille portraits CSSA — même langage que le XI prono (ivoire + anneau).
class _MotmSedanCandidateGrid extends StatelessWidget {
  final List<Map<String, dynamic>> candidates;
  final SedanSquad squad;
  final String selectedCandidateId;
  final bool enabled;
  final ValueChanged<String> onVote;

  const _MotmSedanCandidateGrid({
    required this.candidates,
    required this.squad,
    required this.selectedCandidateId,
    required this.enabled,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final candidate in candidates)
              _MotmSedanCandidateCell(
                candidate: candidate,
                squad: squad,
                selected: selectedCandidateId ==
                    (candidate['id'] as String? ?? '').trim(),
                enabled: enabled,
                onVote: onVote,
              ),
          ],
        ),
        if (selectedCandidateId.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Ton vote est enregistré',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColorsLight.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _MotmSedanCandidateCell extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final SedanSquad squad;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onVote;

  const _MotmSedanCandidateCell({
    required this.candidate,
    required this.squad,
    required this.selected,
    required this.enabled,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final id = (candidate['id'] as String? ?? '').trim();
    final rawName = (candidate['name'] as String? ?? '').trim();
    final playerId = (candidate['playerId'] as String? ?? '').trim();
    final player = squad.faceForVoteLabel(
      rawName.isEmpty ? 'Joueur' : rawName,
      playerId: playerId.isEmpty ? null : playerId,
    );
    final split = MotmVoteService.splitPlayerLabel(
      rawName.isEmpty ? player.name : rawName,
    );
    final caption = split.name.isNotEmpty ? split.name : rawName;

    return SizedBox(
      width: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && id.isNotEmpty ? () => onVote(id) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SedanPlayerFace(
                  player: player,
                  size: 52,
                  occupied: true,
                  selected: selected,
                ),
                const SizedBox(height: 6),
                Text(
                  caption.isEmpty ? 'Joueur' : caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: selected
                        ? AppColorsLight.textPrimary
                        : AppColorsLight.textSecondary,
                  ),
                ),
              ],
            ),
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
