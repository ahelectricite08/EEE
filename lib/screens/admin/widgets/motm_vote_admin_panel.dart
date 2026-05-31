import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/motm_vote_service.dart';
import '../../../services/sponsor_service.dart';
import '../admin_dialogs.dart';
import '../admin_form_widgets.dart';
import '../admin_palette.dart';

class MotmVoteAdminPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const MotmVoteAdminPanel({required this.data});

  Future<void> _showQuickEditSheet(BuildContext context) async {
    final titleCtrl = TextEditingController(
      text: (data['motmVoteTitle'] as String? ?? '').trim(),
    );
    final sponsorCtrl = TextEditingController(
      text: (data['motmVoteSponsorName'] as String? ?? '').trim(),
    );
    final sponsorLogoCtrl = TextEditingController(
      text: (data['motmVoteSponsorLogo'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (data['motmVoteBackgroundImage'] as String? ?? '').trim(),
    );
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  adminBottomSheetHandle(),
                  Text(
                    'VISUEL DU VOTE',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: adminGold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu peux changer le titre, le sponsor et l\'image de fond sans relancer le vote.',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  ),
                  const SizedBox(height: 14),
                  AdminField(ctrl: titleCtrl, label: 'Titre de la carte'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: sponsorCtrl, label: 'Nom du sponsor'),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: sponsorLogoCtrl,
                    label: 'Logo sponsor (URL)',
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: backgroundCtrl,
                    label: 'Image de fond (URL, optionnel)',
                  ),
                  if (backgroundCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: Image.network(
                          backgroundCtrl.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: adminBg,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: adminGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: saving ? null : () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: adminBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: adminBorder),
                            ),
                            child: Center(
                              child: Text(
                                'ANNULER',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: adminGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: saving
                              ? null
                              : () async {
                                  setModalState(() => saving = true);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('live')
                                        .doc('current')
                                        .set({
                                          'motmVoteTitle': titleCtrl.text
                                              .trim(),
                                          'motmVoteSponsorName': sponsorCtrl
                                              .text
                                              .trim(),
                                          'motmVoteSponsorLogo': sponsorLogoCtrl
                                              .text
                                              .trim(),
                                          'motmVoteBackgroundImage':
                                              backgroundCtrl.text.trim(),
                                        }, SetOptions(merge: true));
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Visuel joueur du match mis a jour.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => saving = false);
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: adminGold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      'ENREGISTRER',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    titleCtrl.dispose();
    sponsorCtrl.dispose();
    sponsorLogoCtrl.dispose();
    backgroundCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['motmVoteStatus'] as String? ?? '').trim();
    final active = MotmVoteService.isVoteActive(data);
    final teams = MotmVoteService.teamMaps(data);
    final counts = MotmVoteService.candidateCounts(data);
    final teamTotals = MotmVoteService.teamVoteTotals(data);
    final totalVotes = MotmVoteService.totalVotes(data);
    final title = (data['motmVoteTitle'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultTitle
        : (data['motmVoteTitle'] as String).trim();
    final sponsorName =
        (data['motmVoteSponsorName'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultSponsorName
        : (data['motmVoteSponsorName'] as String).trim();
    final sponsorLogo =
        (data['motmVoteSponsorLogo'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultSponsorLogo
        : (data['motmVoteSponsorLogo'] as String).trim();
    final team1Default = (data['team1'] as String? ?? 'Équipe 1').trim();
    final team2Default = (data['team2'] as String? ?? 'Equipe 2').trim();
    final lineupMotm = MotmVoteService.playersFromLineups(data);
    final canQuickLaunchFromLineup =
        teams.isEmpty && lineupMotm.ready && status != 'active';
    final revealWinner = MotmVoteService.shouldRevealWinner(data);
    final winnerName = (data['motmVoteWinnerName'] as String? ?? '').trim();
    final winnerTeamName = (data['motmVoteWinnerTeamName'] as String? ?? '')
        .trim();

    if (status == 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MotmVoteService.ensureVoteState(data);
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: adminGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'HOMME DU MATCH',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminGold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? adminRed.withAlpha(20)
                      : status == 'closed'
                      ? adminGold.withAlpha(20)
                      : adminBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? adminRed.withAlpha(100)
                        : status == 'closed'
                        ? adminGold.withAlpha(100)
                        : adminBorder,
                  ),
                ),
                child: Text(
                  active
                      ? 'VOTE EN COURS'
                      : status == 'closed'
                      ? 'VOTE CLOS'
                      : 'INACTIF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? adminRed
                        : status == 'closed'
                        ? adminGold
                        : adminGrey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showQuickEditSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        size: 12,
                        color: adminGold,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'VISUEL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: adminGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (sponsorLogo.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    sponsorLogo,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        size: 18,
                        color: adminGreyLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                    Text(
                      'Sponsor : $sponsorName',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: adminBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: adminBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MotmVoteMetaColumn(
                    label: 'Votes',
                    value: '$totalVotes',
                  ),
                ),
                Expanded(
                  child: _MotmVoteMetaColumn(
                    label: active ? 'Temps restant' : 'Statut',
                    value: active
                        ? _remainingLabel(data)
                        : (status.isEmpty ? 'Pret' : 'Clos'),
                    accent: active ? adminRed : adminGold,
                  ),
                ),
                Expanded(
                  child: _MotmVoteMetaColumn(
                    label: 'Publication',
                    value: revealWinner ? 'Vainqueur public' : 'Votes prives',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (canQuickLaunchFromLineup) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adminGold.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: adminGold.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Composition enregistree',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: adminGold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lineupMotm.team1Players.length} joueurs • $team1Default\n'
                    '${lineupMotm.team2Players.length} joueurs • $team2Default',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lance le vote en un clic. Utilise « Personnaliser » pour modifier sponsor ou liste.',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (teams.isEmpty)
            Text(
              lineupMotm.team1Players.isNotEmpty ||
                      lineupMotm.team2Players.isNotEmpty
                  ? 'Composition incomplete : ajoute les joueurs manquants ou complete la compo, puis lance le vote.'
                  : 'Prepare les 2 equipes puis lance le vote. Chaque supporter choisira une equipe, puis un seul joueur.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else
            Column(
              children: teams.map((team) {
                final teamId = (team['id'] as String? ?? '').trim();
                final teamName = (team['name'] as String? ?? '').trim();
                final teamCandidates =
                    MotmVoteService.candidatesForTeam(data, teamId)
                      ..sort((a, b) {
                        final aVotes =
                            counts[(a['id'] as String? ?? '').trim()] ?? 0;
                        final bVotes =
                            counts[(b['id'] as String? ?? '').trim()] ?? 0;
                        return bVotes.compareTo(aVotes);
                      });
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                teamName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: adminTextPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${teamTotals[teamId] ?? 0} vote${(teamTotals[teamId] ?? 0) > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...teamCandidates.map((candidate) {
                          final candidateId = (candidate['id'] as String? ?? '')
                              .trim();
                          final candidateName =
                              (candidate['name'] as String? ?? '').trim();
                          final votes = counts[candidateId] ?? 0;
                          final percent = totalVotes == 0
                              ? 0.0
                              : votes / totalVotes;
                          final isWinner = winnerName == candidateName;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isWinner ? adminGold : adminBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          candidateName,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: adminTextPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$votes vote${votes > 1 ? 's' : ''} • ${(percent * 100).round()}%',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: adminGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 7,
                                      backgroundColor: adminBorder,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isWinner
                                            ? adminGold
                                            : adminRed.withAlpha(180),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 2),
          if (winnerName.isNotEmpty && status == 'closed') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adminGold.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: adminGold.withAlpha(100)),
              ),
              child: Text(
                revealWinner
                    ? 'Vainqueur public : $winnerName${winnerTeamName.isEmpty ? '' : ' • $winnerTeamName'}'
                    : 'Vainqueur admin : $winnerName${winnerTeamName.isEmpty ? '' : ' • $winnerTeamName'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: active
                      ? null
                      : () {
                          if (canQuickLaunchFromLineup) {
                            _quickStartVoteFromLineup(
                              context,
                              team1Name: team1Default,
                              team2Name: team2Default,
                              team1Players: lineupMotm.team1Players,
                              team2Players: lineupMotm.team2Players,
                              sponsorName: sponsorName,
                              sponsorLogo: sponsorLogo,
                              revealWinner: revealWinner,
                            );
                            return;
                          }
                          _showStartVoteSheet(
                            context,
                            sponsorName: sponsorName,
                            sponsorLogo: sponsorLogo,
                            team1Name: teams.isNotEmpty
                                ? (teams.first['name'] as String? ?? '').trim()
                                : team1Default,
                            team2Name: teams.length > 1
                                ? (teams[1]['name'] as String? ?? '').trim()
                                : team2Default,
                            team1Players: _motmDefaultPlayers(
                              data: data,
                              teams: teams,
                              teamId: 'team_1',
                              lineupPlayers: lineupMotm.team1Players,
                            ),
                            team2Players: _motmDefaultPlayers(
                              data: data,
                              teams: teams,
                              teamId: 'team_2',
                              lineupPlayers: lineupMotm.team2Players,
                            ),
                            revealWinner: revealWinner,
                            lineupPrefill: lineupMotm.ready,
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: active ? adminBg : adminGold,
                      borderRadius: BorderRadius.circular(10),
                      border: active ? Border.all(color: adminBorder) : null,
                    ),
                    child: Center(
                      child: Text(
                        active
                            ? 'VOTE EN COURS'
                            : canQuickLaunchFromLineup
                            ? 'LANCER LE VOTE'
                            : 'LANCER LE VOTE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active ? adminGrey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (canQuickLaunchFromLineup) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showStartVoteSheet(
                      context,
                      sponsorName: sponsorName,
                      sponsorLogo: sponsorLogo,
                      team1Name: team1Default,
                      team2Name: team2Default,
                      team1Players: lineupMotm.team1Players,
                      team2Players: lineupMotm.team2Players,
                      revealWinner: revealWinner,
                      lineupPrefill: true,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Center(
                        child: Text(
                          'PERSONNALISER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (active) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await MotmVoteService.stopVote(reason: 'manual');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vote homme du match arrete manuellement.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Center(
                        child: Text(
                          'ARRETER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<String> _motmDefaultPlayers({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> teams,
    required String teamId,
    required List<String> lineupPlayers,
  }) {
    if (teams.isNotEmpty) {
      return MotmVoteService.candidatesForTeam(data, teamId)
          .map((c) => (c['name'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return lineupPlayers;
  }

  Future<void> _quickStartVoteFromLineup(
    BuildContext context, {
    required String team1Name,
    required String team2Name,
    required List<String> team1Players,
    required List<String> team2Players,
    required String sponsorName,
    required String sponsorLogo,
    required bool revealWinner,
  }) async {
    try {
      await MotmVoteService.startVote(
        team1Name: team1Name,
        team2Name: team2Name,
        team1Players: team1Players,
        team2Players: team2Players,
        sponsorId: (data['motmVoteSponsorId'] as String? ?? '').trim(),
        sponsorName: sponsorName,
        sponsorLogo: sponsorLogo,
        sponsorColorHex: (data['motmVoteSponsorColorHex'] as String? ?? '')
            .trim(),
        sponsorLinkUrl: (data['motmVoteSponsorLinkUrl'] as String? ?? '')
            .trim(),
        backgroundImageUrl:
            (data['motmVoteBackgroundImage'] as String? ?? '').trim(),
        revealWinner: revealWinner,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vote homme du match lance (joueurs issus de la composition).',
          ),
        ),
      );
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  Future<void> _showStartVoteSheet(
    BuildContext context, {
    required String sponsorName,
    required String sponsorLogo,
    required String team1Name,
    required String team2Name,
    required List<String> team1Players,
    required List<String> team2Players,
    required bool revealWinner,
    bool lineupPrefill = false,
  }) async {
    final team1Ctrl = TextEditingController(text: team1Name);
    final team2Ctrl = TextEditingController(text: team2Name);
    final sponsorCtrl = TextEditingController(
      text: sponsorName.isEmpty
          ? MotmVoteService.defaultSponsorName
          : sponsorName,
    );
    final logoCtrl = TextEditingController(
      text: sponsorLogo.isEmpty
          ? MotmVoteService.defaultSponsorLogo
          : sponsorLogo,
    );
    final sponsorColorCtrl = TextEditingController(
      text: (data['motmVoteSponsorColorHex'] as String? ?? '').trim(),
    );
    final sponsorLinkCtrl = TextEditingController(
      text: (data['motmVoteSponsorLinkUrl'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (data['motmVoteBackgroundImage'] as String? ?? '').trim(),
    );
    final team1Ctrls = _buildPlayerControllers(team1Players);
    final team2Ctrls = _buildPlayerControllers(team2Players);
    var saving = false;
    var revealWinnerValue = revealWinner;
    var selectedSponsorId = (data['motmVoteSponsorId'] as String? ?? '').trim();

    await showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                adminBottomSheetHandle(),
                Text(
                  'LANCER LE VOTE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lineupPrefill
                      ? 'Joueurs pre-remplis depuis la composition. Tu peux encore ajuster la liste ou le sponsor avant de lancer.'
                      : 'Le supporter choisit d\'abord une équipe, puis un seul joueur. Les votes restent invisibles au public.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SponsorService.stream(),
                  builder: (context, sponsorSnap) {
                    final sponsors =
                        sponsorSnap.data ?? const <Map<String, dynamic>>[];
                    final activeSponsors = sponsors
                        .where((item) => item['active'] != false)
                        .toList();
                    if (activeSponsors.isEmpty) return const SizedBox.shrink();
                    final availableIds = activeSponsors
                        .map((item) => (item['id'] as String? ?? '').trim())
                        .where((id) => id.isNotEmpty)
                        .toList();
                    final currentValue =
                        availableIds.contains(selectedSponsorId)
                        ? selectedSponsorId
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: currentValue,
                        dropdownColor: adminCard,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: adminTextPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Sponsor enregistré (optionnel)',
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                          ),
                          filled: true,
                          fillColor: adminBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: adminBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: adminBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: adminGold),
                          ),
                        ),
                        items: activeSponsors.map((sponsor) {
                          final id = (sponsor['id'] as String? ?? '').trim();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              (sponsor['name'] as String? ?? '').trim(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedSponsorId = value ?? '';
                            final selected = activeSponsors.firstWhere(
                              (item) =>
                                  (item['id'] as String? ?? '').trim() ==
                                  selectedSponsorId,
                              orElse: () => const <String, dynamic>{},
                            );
                            sponsorCtrl.text =
                                (selected['name'] as String? ?? '').trim();
                            logoCtrl.text =
                                (selected['logoUrl'] as String? ?? '').trim();
                            sponsorColorCtrl.text =
                                (selected['colorHex'] as String? ?? '').trim();
                            sponsorLinkCtrl.text =
                                (selected['linkUrl'] as String? ?? '').trim();
                          });
                        },
                      ),
                    );
                  },
                ),
                AdminField(ctrl: sponsorCtrl, label: 'Nom du sponsor'),
                const SizedBox(height: 10),
                AdminField(ctrl: logoCtrl, label: 'Logo sponsor (URL)'),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: backgroundCtrl,
                  label: 'Image de fond (URL, optionnel)',
                ),
                if (backgroundCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: Image.network(
                        backgroundCtrl.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: adminBg,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Publier le vainqueur au public',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              revealWinnerValue
                                  ? 'Le gagnant sera affiche a la cloture.'
                                  : 'Le resultat restera visible seulement dans l admin.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: revealWinnerValue,
                        onChanged: (value) =>
                            setModalState(() => revealWinnerValue = value),
                        activeThumbColor: adminGold,
                        inactiveThumbColor: adminGrey,
                        inactiveTrackColor: adminBorder,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _MotmTeamEditorBlock(
                  title: 'EQUIPE 1',
                  teamCtrl: team1Ctrl,
                  playerCtrls: team1Ctrls,
                  onChanged: () => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                _MotmTeamEditorBlock(
                  title: 'EQUIPE 2',
                  teamCtrl: team2Ctrl,
                  playerCtrls: team2Ctrls,
                  onChanged: () => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: saving ? null : () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: adminBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: adminBorder),
                          ),
                          child: Center(
                            child: Text(
                              'ANNULER',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: adminGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: saving
                            ? null
                            : () async {
                                final players1 = _readPlayers(team1Ctrls);
                                final players2 = _readPlayers(team2Ctrls);
                                if (players1.isEmpty || players2.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ajoute au moins un joueur dans chaque equipe.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => saving = true);
                                try {
                                  await MotmVoteService.startVote(
                                    team1Name: team1Ctrl.text.trim(),
                                    team2Name: team2Ctrl.text.trim(),
                                    team1Players: players1,
                                    team2Players: players2,
                                    sponsorId: selectedSponsorId,
                                    sponsorName: sponsorCtrl.text.trim(),
                                    sponsorLogo: logoCtrl.text.trim(),
                                    sponsorColorHex: sponsorColorCtrl.text
                                        .trim(),
                                    sponsorLinkUrl: sponsorLinkCtrl.text.trim(),
                                    backgroundImageUrl: backgroundCtrl.text
                                        .trim(),
                                    revealWinner: revealWinnerValue,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Vote homme du match lance pour 10 minutes.',
                                      ),
                                    ),
                                  );
                                } on StateError catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error.message.toString()),
                                    ),
                                  );
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: adminGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    'LANCER',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    team1Ctrl.dispose();
    team2Ctrl.dispose();
    sponsorCtrl.dispose();
    logoCtrl.dispose();
    sponsorColorCtrl.dispose();
    sponsorLinkCtrl.dispose();
    backgroundCtrl.dispose();
    for (final ctrl in [...team1Ctrls, ...team2Ctrls]) {
      ctrl.dispose();
    }
  }

  List<TextEditingController> _buildPlayerControllers(List<String> players) {
    final values = players.isEmpty ? <String>['', ''] : [...players, ''];
    return values
        .take(20)
        .map((player) => TextEditingController(text: player))
        .toList();
  }

  List<String> _readPlayers(List<TextEditingController> ctrls) {
    return ctrls
        .map((ctrl) => ctrl.text.trim())
        .where((player) => player.isNotEmpty)
        .toSet()
        .toList();
  }

  String _remainingLabel(Map<String, dynamic> data) {
    final endsAt = data['motmVoteEndsAt'];
    if (endsAt is! Timestamp) return '10:00';
    final remaining = endsAt.toDate().difference(DateTime.now());
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

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM EDITOR BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

class _MotmTeamEditorBlock extends StatelessWidget {
  final String title;
  final TextEditingController teamCtrl;
  final List<TextEditingController> playerCtrls;
  final VoidCallback onChanged;

  const _MotmTeamEditorBlock({
    required this.title,
    required this.teamCtrl,
    required this.playerCtrls,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          AdminField(ctrl: teamCtrl, label: 'Nom de l equipe'),
          const SizedBox(height: 10),
          ...playerCtrls.asMap().entries.map((entry) {
            final index = entry.key;
            final ctrl = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AdminField(ctrl: ctrl, label: 'Joueur ${index + 1}'),
                  ),
                  if (playerCtrls.length > 2) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        playerCtrls[index].dispose();
                        playerCtrls.removeAt(index);
                        onChanged();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: adminCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: adminBorder),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: adminGrey,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (playerCtrls.length < 20)
            GestureDetector(
              onTap: () {
                playerCtrls.add(TextEditingController());
                onChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 14, color: adminGold),
                    const SizedBox(width: 6),
                    Text(
                      'AJOUTER UN JOUEUR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: adminGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MotmVoteMetaColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _MotmVoteMetaColumn({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: adminGrey,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accent ?? adminTextPrimary,
          ),
        ),
      ],
    );
  }
}