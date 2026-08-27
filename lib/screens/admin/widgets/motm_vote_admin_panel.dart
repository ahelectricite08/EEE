import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      useRootNavigator: true,
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
            padding: adminBottomSheetPadding(ctx),
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
        (data['motmVoteSponsorLogo'] as String? ?? '').trim();
    final team1Default = (data['team1'] as String? ?? 'Équipe 1').trim();
    final team2Default = (data['team2'] as String? ?? 'Equipe 2').trim();
    final lineupMotm = MotmVoteService.playersFromLineups(data);
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
          if (teams.isEmpty)
            Text(
              lineupMotm.team1Players.isNotEmpty ||
                      lineupMotm.team2Players.isNotEmpty
                  ? 'La composition (XI + remplaçants, hors entraîneurs) pré-remplit le formulaire. Tu peux encore ajouter, modifier ou retirer des joueurs.'
                  : 'Prépare les 2 équipes puis lance le vote. Sans composition, saisis les joueurs à la main. Chaque supporter choisira une équipe, puis un seul joueur.',
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
                                color: isWinner
                                    ? adminGold.withAlpha(14)
                                    : adminCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isWinner
                                      ? adminGold.withAlpha(160)
                                      : adminBorder,
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
                                          fontWeight: FontWeight.w600,
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
                                            : adminRed.withAlpha(200),
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
                      : () => _openStartVoteSheet(
                          context,
                          sponsorName: sponsorName,
                          sponsorLogo: sponsorLogo,
                          team1Name: teams.isNotEmpty
                              ? (teams.first['name'] as String? ?? '').trim()
                              : team1Default,
                          team2Name: teams.length > 1
                              ? (teams[1]['name'] as String? ?? '').trim()
                              : team2Default,
                          teams: teams,
                          revealWinner: revealWinner,
                        ),
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

  Future<void> openLaunchSheet(BuildContext context) {
    final teams = MotmVoteService.teamMaps(data);
    final sponsorName =
        (data['motmVoteSponsorName'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultSponsorName
        : (data['motmVoteSponsorName'] as String).trim();
    final sponsorLogo =
        (data['motmVoteSponsorLogo'] as String? ?? '').trim();
    final team1Default = (data['team1'] as String? ?? 'Équipe 1').trim();
    final team2Default = (data['team2'] as String? ?? 'Equipe 2').trim();
    return _openStartVoteSheet(
      context,
      sponsorName: sponsorName,
      sponsorLogo: sponsorLogo,
      team1Name: teams.isNotEmpty
          ? (teams.first['name'] as String? ?? '').trim()
          : team1Default,
      team2Name: teams.length > 1
          ? (teams[1]['name'] as String? ?? '').trim()
          : team2Default,
      teams: teams,
      revealWinner: MotmVoteService.shouldRevealWinner(data),
    );
  }

  static Future<void> openLaunchSheetFor(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return MotmVoteAdminPanel(data: data).openLaunchSheet(context);
  }

  List<String> _motmDefaultPlayers({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> teams,
    required String teamId,
    required List<String> lineupPlayers,
  }) {
    if (lineupPlayers.isNotEmpty) return lineupPlayers;
    if (teams.isEmpty) return const [];
    return MotmVoteService.candidatesForTeam(data, teamId)
        .map((c) => (c['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _openStartVoteSheet(
    BuildContext context, {
    required String sponsorName,
    required String sponsorLogo,
    required String team1Name,
    required String team2Name,
    required List<Map<String, dynamic>> teams,
    required bool revealWinner,
  }) async {
    var lineupMotm = MotmVoteService.playersFromLineups(data);
    if (lineupMotm.team1Players.isEmpty || lineupMotm.team2Players.isEmpty) {
      try {
        lineupMotm = await MotmVoteService.resolvePlayersFromLineups(data);
      } catch (_) {
        // Live data only — le formulaire manuel reste disponible.
      }
    }
    if (!context.mounted) return;
    final team1Players = _motmDefaultPlayers(
      data: data,
      teams: teams,
      teamId: 'team_1',
      lineupPlayers: lineupMotm.team1Players,
    );
    final team2Players = _motmDefaultPlayers(
      data: data,
      teams: teams,
      teamId: 'team_2',
      lineupPlayers: lineupMotm.team2Players,
    );
    await _showStartVoteSheet(
      context,
      sponsorName: sponsorName,
      sponsorLogo: sponsorLogo,
      team1Name: team1Name,
      team2Name: team2Name,
      team1Players: team1Players,
      team2Players: team2Players,
      revealWinner: revealWinner,
      lineupPrefill:
          lineupMotm.team1Players.isNotEmpty ||
          lineupMotm.team2Players.isNotEmpty,
    );
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
  }) {
    return showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => MotmVoteLaunchSheet(
        liveData: data,
        sponsorName: sponsorName,
        sponsorLogo: sponsorLogo,
        team1Name: team1Name,
        team2Name: team2Name,
        team1Players: team1Players,
        team2Players: team2Players,
        revealWinner: revealWinner,
        lineupPrefill: lineupPrefill,
      ),
    );
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

/// Formulaire de lancement MOTM : les [TextEditingController] vivent dans
/// [State] (initState / dispose), pas dans le builder du bottom sheet ni
/// dans le StreamBuilder live/current du profil.
class MotmVoteLaunchSheet extends StatefulWidget {
  final Map<String, dynamic> liveData;
  final String sponsorName;
  final String sponsorLogo;
  final String team1Name;
  final String team2Name;
  final List<String> team1Players;
  final List<String> team2Players;
  final bool revealWinner;
  final bool lineupPrefill;
  final Stream<List<Map<String, dynamic>>>? sponsorStream;

  const MotmVoteLaunchSheet({
    super.key,
    required this.liveData,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.team1Name,
    required this.team2Name,
    required this.team1Players,
    required this.team2Players,
    required this.revealWinner,
    this.lineupPrefill = false,
    this.sponsorStream,
  });

  @override
  State<MotmVoteLaunchSheet> createState() => MotmVoteLaunchSheetState();
}

class MotmVoteLaunchSheetState extends State<MotmVoteLaunchSheet> {
  final List<TextEditingController> _owned = [];
  late final TextEditingController _team1Ctrl;
  late final TextEditingController _team2Ctrl;
  late final TextEditingController _sponsorCtrl;
  late final TextEditingController _logoCtrl;
  late final TextEditingController _sponsorColorCtrl;
  late final TextEditingController _sponsorLinkCtrl;
  late final TextEditingController _backgroundCtrl;
  late final List<TextEditingController> _team1Ctrls;
  late final List<TextEditingController> _team2Ctrls;
  var _saving = false;
  late var _revealWinnerValue = widget.revealWinner;
  late var _selectedSponsorId =
      (widget.liveData['motmVoteSponsorId'] as String? ?? '').trim();
  var _controllerBuildCount = 0;

  @visibleForTesting
  int get controllerBuildCount => _controllerBuildCount;

  @visibleForTesting
  TextEditingController get team1NameController => _team1Ctrl;

  @visibleForTesting
  List<TextEditingController> get team1PlayerControllers =>
      List.unmodifiable(_team1Ctrls);

  TextEditingController _own([String text = '']) {
    _controllerBuildCount++;
    final ctrl = TextEditingController(text: text);
    _owned.add(ctrl);
    return ctrl;
  }

  List<TextEditingController> _playerControllers(List<String> players) {
    final values = players.isEmpty ? <String>['', ''] : [...players, ''];
    return values.take(20).map(_own).toList();
  }

  List<String> _readPlayers(List<TextEditingController> ctrls) {
    return ctrls
        .map((ctrl) => ctrl.text.trim())
        .where((player) => player.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final data = widget.liveData;
    _team1Ctrl = _own(widget.team1Name);
    _team2Ctrl = _own(widget.team2Name);
    _sponsorCtrl = _own(
      widget.sponsorName.isEmpty
          ? MotmVoteService.defaultSponsorName
          : widget.sponsorName,
    );
    _logoCtrl = _own(widget.sponsorLogo);
    _sponsorColorCtrl = _own(
      (data['motmVoteSponsorColorHex'] as String? ?? '').trim(),
    );
    _sponsorLinkCtrl = _own(
      (data['motmVoteSponsorLinkUrl'] as String? ?? '').trim(),
    );
    _backgroundCtrl = _own(
      (data['motmVoteBackgroundImage'] as String? ?? '').trim(),
    );
    _team1Ctrls = _playerControllers(widget.team1Players);
    _team2Ctrls = _playerControllers(widget.team2Players);
  }

  @override
  void dispose() {
    for (final ctrl in _owned) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: adminBottomSheetPadding(context),
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
              widget.lineupPrefill
                  ? 'Joueurs pré-remplis depuis la composition (titulaires et remplaçants, hors entraîneurs). Tu peux modifier, ajouter ou retirer un nom avant de lancer.'
                  : 'Aucune composition détectée : saisis les joueurs à la main. Le supporter choisit d\'abord une équipe, puis un seul joueur.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.sponsorStream ?? SponsorService.stream(),
              builder: (context, sponsorSnap) {
                if (sponsorSnap.hasError) return const SizedBox.shrink();
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
                final currentValue = availableIds.contains(_selectedSponsorId)
                    ? _selectedSponsorId
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
                      setState(() {
                        _selectedSponsorId = value ?? '';
                        final selected = activeSponsors.firstWhere(
                          (item) =>
                              (item['id'] as String? ?? '').trim() ==
                              _selectedSponsorId,
                          orElse: () => const <String, dynamic>{},
                        );
                        _sponsorCtrl.text =
                            (selected['name'] as String? ?? '').trim();
                        _logoCtrl.text =
                            (selected['logoUrl'] as String? ?? '').trim();
                        _sponsorColorCtrl.text =
                            (selected['colorHex'] as String? ?? '').trim();
                        _sponsorLinkCtrl.text =
                            (selected['linkUrl'] as String? ?? '').trim();
                      });
                    },
                  ),
                );
              },
            ),
            AdminField(ctrl: _sponsorCtrl, label: 'Nom du sponsor'),
            const SizedBox(height: 10),
            AdminField(ctrl: _logoCtrl, label: 'Logo sponsor (URL)'),
            const SizedBox(height: 4),
            Text(
              'Vide = logo par défaut (Photos & réseaux → Partenaires match).',
              style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
            ),
            const SizedBox(height: 10),
            AdminField(
              ctrl: _backgroundCtrl,
              label: 'Image de fond (URL, optionnel)',
            ),
            if (_backgroundCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: Image.network(
                    _backgroundCtrl.text.trim(),
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
                          _revealWinnerValue
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
                    value: _revealWinnerValue,
                    onChanged: (value) =>
                        setState(() => _revealWinnerValue = value),
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
              teamCtrl: _team1Ctrl,
              playerCtrls: _team1Ctrls,
              onAdd: () {
                _team1Ctrls.add(_own());
                setState(() {});
              },
              onRemove: (index) {
                _team1Ctrls.removeAt(index);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            _MotmTeamEditorBlock(
              title: 'EQUIPE 2',
              teamCtrl: _team2Ctrl,
              playerCtrls: _team2Ctrls,
              onAdd: () {
                _team2Ctrls.add(_own());
                setState(() {});
              },
              onRemove: (index) {
                _team2Ctrls.removeAt(index);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _saving ? null : () => Navigator.pop(context),
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
                    onTap: _saving ? null : _launch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: adminGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: _saving
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
    );
  }

  Future<void> _launch() async {
    final players1 = _readPlayers(_team1Ctrls);
    final players2 = _readPlayers(_team2Ctrls);
    if (players1.isEmpty || players2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoute au moins un joueur dans chaque equipe.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await MotmVoteService.startVote(
        team1Name: _team1Ctrl.text.trim(),
        team2Name: _team2Ctrl.text.trim(),
        team1Players: players1,
        team2Players: players2,
        sponsorId: _selectedSponsorId,
        sponsorName: _sponsorCtrl.text.trim(),
        sponsorLogo: _logoCtrl.text.trim(),
        sponsorColorHex: _sponsorColorCtrl.text.trim(),
        sponsorLinkUrl: _sponsorLinkCtrl.text.trim(),
        backgroundImageUrl: _backgroundCtrl.text.trim(),
        revealWinner: _revealWinnerValue,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Vote homme du match lance pour 10 minutes.'),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM EDITOR BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

class _MotmTeamEditorBlock extends StatelessWidget {
  final String title;
  final TextEditingController teamCtrl;
  final List<TextEditingController> playerCtrls;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _MotmTeamEditorBlock({
    required this.title,
    required this.teamCtrl,
    required this.playerCtrls,
    required this.onAdd,
    required this.onRemove,
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
              key: ObjectKey(ctrl),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AdminField(ctrl: ctrl, label: 'Joueur ${index + 1}'),
                  ),
                  if (playerCtrls.length > 2) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemove(index),
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
              onTap: onAdd,
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