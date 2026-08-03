import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_model.dart';
import '../../../../services/live_banner_format.dart';
import '../../../../services/seed_service.dart';
import '../../../../services/emission_poll_service.dart';
import '../../../../services/sponsor_service.dart';
import '../../../../services/live_start_service.dart';
import '../../../../utils/youtube_parser.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_components.dart';
import '../../../../widgets/live_match_quick_panel.dart';
import '../../../../widgets/live_start_match_picker.dart';
import '../../../../widgets/match_commentary_record_sheet.dart';
import '../../../../widgets/match_event_audio_play_button.dart';
import '../../../../widgets/match_event_video_play_button.dart';
import '../../../../widgets/match_highlight_attach_sheet.dart';
import '../../../../widgets/match_media_after_event.dart';
import '../../../../widgets/match_highlight_export_panel.dart';
import '../../../../widgets/match_post_media_admin_panel.dart';
import '../../../../widgets/sedan_squad_player_picker.dart';
import '../../../../models/match_stats_schema.dart';
import '../../../../services/match_media_stats_service.dart';
import '../../admin_navigation.dart';
import '../../admin_controller.dart';
import '../../admin_palette.dart';
import '../../widgets/match_admin_context_banner.dart';
import '../../widgets/motm_vote_admin_panel.dart';
import '../../widgets/match_rating_admin_panel.dart';
import 'direct_live_salon_panel.dart';
import 'direct_sticky_actions.dart';
import '../stats/live_stats_display_control.dart';

// -------------------------------------------------------------------------------
// ONGLET DIRECT
// -------------------------------------------------------------------------------

class _StartLiveFormResult {
  final bool streamBroadcast;
  final MatchModel match;
  const _StartLiveFormResult({
    required this.streamBroadcast,
    required this.match,
  });
}

class DirectTab extends StatefulWidget {
  const DirectTab();

  @override
  State<DirectTab> createState() => _DirectTabState();
}

class _DirectTabState extends State<DirectTab> {
  bool _loadingLive = false;
  bool _loadingEmission = false;
  DirectMatchDayMode _mode = DirectMatchDayMode.pilotage;

  @override
  Widget build(BuildContext context) {
    final readOnly =
        AdminController.maybeOf(context)?.isDirectReadOnly ?? false;

    final body = StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        final isLive = snap.hasData && snap.data!.exists;
        final data =
            isLive ? snap.data!.data() as Map<String, dynamic> : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (readOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                color: adminBlue.withAlpha(18),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded,
                        color: adminBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lecture seule — suivi live sans pilotage.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            DirectStickyActionsBar(
              isLive: isLive,
              data: data,
              loading: _loadingLive,
              readOnly: readOnly,
              onToggleLive: () => _handleLiveMatch(isLive, data),
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
            ),
            Expanded(
              child: _mode == DirectMatchDayMode.pilotage
                  ? _buildPilotageScroll(isLive, data)
                  : _buildStudioScroll(),
            ),
          ],
        );
      },
    );

    if (readOnly) {
      return AbsorbPointer(absorbing: true, child: body);
    }
    return body;
  }

  Widget _buildPilotageScroll(bool isLive, Map<String, dynamic>? data) {
    final matchId = (data?['matchId'] as String? ?? '').trim();
    const accent = AdminModuleColors.live;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AdminModuleHeader(
          title: 'Direct',
          subtitle: isLive
              ? 'Cockpit match — score, chronos, liens fiche & stats.'
              : 'Aucun live — démarrer depuis le bandeau sticky.',
          icon: Icons.sensors_rounded,
          accent: accent,
        ),
        const SizedBox(height: 14),
        if (!isLive) ...[
          _LiveCard(
            title: 'MATCH EN DIRECT',
            subtitle: 'Aucun match en cours — démarrer depuis le bandeau.',
            icon: Icons.sports_soccer_rounded,
            isActive: false,
            loading: _loadingLive,
            onToggle: () => _handleLiveMatch(false, null),
          ),
          const SizedBox(height: 18),
          AdminModuleSection(
            eyebrow: 'Après match',
            title: 'Médias & export résumé',
            subtitle: 'Audio, clips vMix, parole du coach, export résumé.',
            accent: AdminModuleColors.apresMatch,
            wrapInCard: false,
            child: const MatchPostMediaAdminPanel(),
          ),
        ],
        if (isLive && data != null) ...[
          AdminModuleSection(
            eyebrow: 'Pilotage',
            title: 'Match en cours',
            subtitle: 'Flux, score live et actions rapides.',
            accent: accent,
            wrapInCard: false,
            child: Container(
              decoration: BoxDecoration(
                color: adminSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withAlpha(80)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LiveViewersChip(
                    viewers: (data['viewers'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(height: 10),
                  _EditStreamUrlButton(
                    currentUrl: (data['url'] as String? ?? '').trim(),
                    docPath: 'live/current',
                  ),
                  const SizedBox(height: 12),
                  LiveMatchQuickPilotageBody(
                    data: data,
                    showHeader: false,
                    hideStatsBandeauToggle: true,
                    useAdminStyle: true,
                  ),
                ],
              ),
            ),
          ),
          if (matchId.isNotEmpty) ...[
            const SizedBox(height: 18),
            AdminModuleSection(
              eyebrow: 'Liens',
              title: 'Calendrier & stats',
              subtitle: 'Même match — fiche, stats, affichage bandeau.',
              accent: AdminModuleColors.apresMatch,
              wrapInCard: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MatchAdminContextBanner(
                      matchId: matchId,
                      team1: data['team1'] as String? ?? '',
                      team2: data['team2'] as String? ?? '',
                      compact: true,
                    ),
                    const SizedBox(height: 10),
                    LiveStatsDisplayControl(
                      matchId: matchId,
                      compact: true,
                    ),
                    const SizedBox(height: 10),
                    MatchHighlightExportPanel(matchId: matchId, compact: true),
                    const SizedBox(height: 10),
                    AdminPrimaryButton(
                      label: 'Saisir les statistiques',
                      icon: Icons.bar_chart_rounded,
                      height: 42,
                      color: AdminModuleColors.apresMatch,
                      textColor: Colors.white,
                      onTap: () =>
                          AdminNavigation.openLiveStatsWorkbench(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _DirectVotesSection(data: data),
        ],
      ],
    );
  }

  Widget _buildStudioScroll() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const AdminModuleHeader(
          title: 'Studio',
          subtitle: 'Salon chat, émission et sondages — hors cockpit score.',
          icon: Icons.podcasts_rounded,
          accent: AdminModuleColors.live,
        ),
        const SizedBox(height: 14),
        AdminModuleSection(
          eyebrow: 'Chat app',
          title: 'Salon live',
          subtitle: 'Salons marqués live et archivage.',
          accent: AdminModuleColors.communaute,
          wrapInCard: false,
          child: const DirectLiveSalonPanel(),
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Studio',
          title: 'Émission & sondage',
          subtitle: 'Antenne DVCR et sondage lié à l’émission.',
          accent: AdminModuleColors.live,
          wrapInCard: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('live')
                    .doc('emission')
                    .snapshots(),
                builder: (context, snap) {
                  final isLive = snap.hasData && snap.data!.exists;
                  final data = isLive
                      ? snap.data!.data() as Map<String, dynamic>
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LiveCard(
                        title: 'ÉMISSION DVCR',
                        subtitle: isLive
                            ? (data?['title'] ?? 'En antenne')
                            : 'Studio prêt',
                        icon: Icons.mic_rounded,
                        isActive: isLive,
                        loading: _loadingEmission,
                        onToggle: () => _handleEmission(isLive),
                      ),
                      if (isLive) ...[
                        const SizedBox(height: 8),
                        _EditStreamUrlButton(
                          currentUrl: (data?['url'] as String? ?? '').trim(),
                          docPath: 'live/emission',
                        ),
                      ],
                    ],
                  );
                },
              ),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('live')
                    .doc('emission')
                    .snapshots(),
                builder: (context, snap) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: adminSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminBorder),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: _EmissionPollPanel(
                      emissionLive: snap.data?.exists == true,
                      data: snap.data?.data(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleLiveMatch(bool isLive, Map<String, dynamic>? data) async {
    if (isLive) {
      final ok = await adminConfirm(context, 'Terminer le match en direct ?');
      if (!ok) return;
      setState(() => _loadingLive = true);
      try {
        await SeedService.endLiveSession();
        if (context.mounted) {
          final mid = (data?['matchId'] as String? ?? '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                mid.isEmpty
                    ? 'Direct terminé.'
                    : 'Direct terminé — stats archivées. '
                        'Poursuivre dans Statistiques match.',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              action: mid.isEmpty
                  ? null
                  : SnackBarAction(
                      label: 'STATS',
                      textColor: AdminModuleColors.live,
                      onPressed: () {
                        AdminNavigation.goToStats(context);
                        AdminNavigation.openStatsWorkbench(
                          context,
                          matchId: mid,
                          team1: data?['team1'] as String? ?? '',
                          team2: data?['team2'] as String? ?? '',
                        );
                      },
                    ),
              backgroundColor: adminCard,
            ),
          );
        }
      } finally {
        setState(() => _loadingLive = false);
      }
      return;
    }

    setState(() => _loadingLive = true);
    try {
      final pickable = await LiveStartService.loadPickableMatches();
      if (!context.mounted) return;
      final suggested = LiveStartService.pickSuggestedFrom(pickable);
      var selected = suggested.match;
      if (selected != null && !pickable.any((m) => m.id == selected!.id)) {
        selected = pickable.isNotEmpty ? pickable.first : null;
      }

      final urlCtrl = TextEditingController();
      final team1Ctrl = TextEditingController(text: selected?.team1 ?? '');
      final team2Ctrl = TextEditingController(text: selected?.team2 ?? '');

      if (mounted) setState(() => _loadingLive = false);

      final form = await _promptStartLiveMatchDialog(
        context: context,
        pickableMatches: pickable,
        initialMatch: selected,
        suggestedMessage: suggested.message,
        urlCtrl: urlCtrl,
        team1Ctrl: team1Ctrl,
        team2Ctrl: team2Ctrl,
      );

      if (form == null) return;
      final match = form.match;
      if (match.id.trim().isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Choisis un match du calendrier (onglet Match) avant de lancer le live.',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            backgroundColor: adminOrange,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _loadingLive = true);
      await SeedService.beginLiveSession(
        url: form.streamBroadcast
            ? YoutubeParser.sanitizeShareUrl(
                urlCtrl.text.trim().isEmpty
                    ? 'https://www.youtube.com/@drapeauvertcartonrouge/streams'
                    : urlCtrl.text.trim(),
              )
            : '',
        team1: team1Ctrl.text.trim().isEmpty ? match.team1 : team1Ctrl.text.trim(),
        team2: team2Ctrl.text.trim().isEmpty ? match.team2 : team2Ctrl.text.trim(),
        matchId: match.id,
        logo1: match.logo1,
        logo2: match.logo2,
        streamBroadcast: form.streamBroadcast,
      );
    } finally {
      if (mounted) setState(() => _loadingLive = false);
    }
  }

  Future<_StartLiveFormResult?> _promptStartLiveMatchDialog({
    required BuildContext context,
    required List<MatchModel> pickableMatches,
    required MatchModel? initialMatch,
    required String? suggestedMessage,
    required TextEditingController urlCtrl,
    required TextEditingController team1Ctrl,
    required TextEditingController team2Ctrl,
  }) async {
    var streamBroadcast = true;
    MatchModel? selectedMatch = initialMatch;

    return showDialog<_StartLiveFormResult>(
      context: context,
      barrierColor: Colors.black.withAlpha(120),
      builder: (dialogContext) {
        final maxH = (MediaQuery.sizeOf(dialogContext).height * 0.86)
            .clamp(280.0, 620.0);
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            void onMatchPicked(MatchModel? m) {
              if (m == null) return;
              setLocal(() {
                selectedMatch = m;
                team1Ctrl.text = m.team1;
                team2Ctrl.text = m.team2;
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, maxHeight: maxH),
                child: Container(
                  decoration: adminCardDecoration(radius: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DÉMARRER UN MATCH',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: adminTextPrimary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choisis le match du calendrier, puis si la retransmission vidéo est active.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: adminBorder),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (suggestedMessage != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: adminBlue.withAlpha(16),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: adminBlue.withAlpha(70),
                                    ),
                                  ),
                                  child: Text(
                                    suggestedMessage,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: adminTextPrimary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              LiveStartMatchPicker(
                                matches: pickableMatches,
                                value: selectedMatch,
                                onChanged: onMatchPicked,
                                useAdminStyle: true,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: AdminField(
                                      ctrl: team1Ctrl,
                                      label: 'Domicile',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AdminField(
                                      ctrl: team2Ctrl,
                                      label: 'Extérieur',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: adminCardHigh,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: adminBorder),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: !streamBroadcast,
                                  activeThumbColor: AdminModuleColors.live,
                                  onChanged: (notBroadcast) => setLocal(
                                    () => streamBroadcast = !notBroadcast,
                                  ),
                                  title: Text(
                                    'Match non retransmis',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: adminTextPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    notBroadcastSubtitle(!streamBroadcast),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: adminGrey,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                              if (streamBroadcast) ...[
                                const SizedBox(height: 10),
                                AdminField(
                                  ctrl: urlCtrl,
                                  label: 'URL YouTube du stream',
                                  hint:
                                      'URL directe (barre d’adresse), pas via « Partager » YouTube',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: adminBorder),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, null),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: adminTextPrimary,
                                  side: const BorderSide(color: adminBorder),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  'Annuler',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: selectedMatch == null
                                    ? null
                                    : () => Navigator.pop(
                                          dialogContext,
                                          _StartLiveFormResult(
                                            streamBroadcast: streamBroadcast,
                                            match: selectedMatch!,
                                          ),
                                        ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AdminModuleColors.live,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  'Lancer',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String notBroadcastSubtitle(bool notBroadcast) => notBroadcast
      ? 'Pas de caméras sur place — score, stats et notifs sans bouton vidéo.'
      : 'Ajoute l’URL YouTube — bouton « Regarder en direct » sur l’accueil.';

  Future<void> _createLiveSalon(String matchId, String name) async {
    final db = FirebaseFirestore.instance;
    // Archive tout salon live actif ou récemment terminé (liveEndedAt présent)
    final existing = await db
        .collection('chat_salons')
        .where('archived', isEqualTo: false)
        .get();
    for (final doc in existing.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final isLive = data['isLive'] == true;
      final hasEnded = data['liveEndedAt'] != null;
      if (isLive || hasEnded) {
        await doc.reference.update({
          'archived': true,
          'isLive': false,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    // Create the new live salon
    await db.collection('chat_salons').doc('live_$matchId').set({
      'name': name,
      'isLive': true,
      'archived': false,
      'matchId': matchId,
      'order': -1,
      'createdAt': FieldValue.serverTimestamp(),
      'archivedAt': null,
      'liveEndedAt': null,
    });
  }

  Future<void> _archiveLiveSalon() async {
    final db = FirebaseFirestore.instance;
    final existing = await db
        .collection('chat_salons')
        .where('isLive', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .get();
    for (final doc in existing.docs) {
      // On ne supprime pas : on note juste la fin du live.
      // Le salon reste visible 2h puis disparaît côté client.
      await doc.reference.update({
        'isLive': false,
        'liveEndedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _handleEmission(bool isLive) async {
    if (isLive) {
      final ok = await adminConfirm(context, 'Terminer l\'émission ?');
      if (!ok) return;
      setState(() => _loadingEmission = true);
      try {
        await FirebaseFirestore.instance
            .collection('live')
            .doc('emission')
            .delete();
      } finally {
        setState(() => _loadingEmission = false);
      }
      return;
    }

    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'ÉMISSION DVCR');

    final ok = await adminShowFormDialog(context, 'DÉMARRER UNE ÉMISSION', [
      AdminField(ctrl: titleCtrl, label: 'Titre'),
      const SizedBox(height: 10),
      AdminField(ctrl: urlCtrl, label: 'URL Stream'),
    ]);

    if (!ok) return;
    setState(() => _loadingEmission = true);
    try {
      await FirebaseFirestore.instance.collection('live').doc('emission').set({
        'url': YoutubeParser.sanitizeShareUrl(urlCtrl.text),
        'title': titleCtrl.text,
        'viewers': 0,
        'startedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      setState(() => _loadingEmission = false);
    }
  }
}

// -------------------------------------------------------------------------------
// SCORE PANEL
// -------------------------------------------------------------------------------

class _ScorePanel extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ScorePanel({required this.data});

  @override
  State<_ScorePanel> createState() => _ScorePanelState();
}

class _ScorePanelState extends State<_ScorePanel> {
  Timer? _chronoTimer;
  int _elapsedSeconds = 0;
  bool _running = false;
  int _lastSavedMinute = -1;

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = ((widget.data['minute'] ?? 0) as int) * 60;
    _lastSavedMinute = _elapsedSeconds ~/ 60;
  }

  @override
  void didUpdateWidget(_ScorePanel old) {
    super.didUpdateWidget(old);
    // Si le doc Firestore change la minute depuis l'extérieur et qu'on ne tourne pas, sync
    final firestoreMinute = ((widget.data['minute'] ?? 0) as int);
    if (!_running && firestoreMinute != _lastSavedMinute) {
      setState(() {
        _elapsedSeconds = firestoreMinute * 60;
        _lastSavedMinute = firestoreMinute;
      });
    }
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
    super.dispose();
  }

  void _startChrono() {
    if (_running) return;
    setState(() => _running = true);
    // Efface l'état halftime/fulltime au redémarrage du chrono
    final lastEvent = widget.data['lastEvent'] ?? '';
    if (lastEvent == 'fulltime' || lastEvent == 'halftime') {
      FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .update({'lastEvent': ''});
    }
    SeedService.startChrono(_elapsedSeconds);
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
      final minute = _elapsedSeconds ~/ 60;
      if (minute != _lastSavedMinute) {
        _lastSavedMinute = minute;
        SeedService.updateMinute(minute);
      }
    });
  }

  void _pauseChrono() {
    _chronoTimer?.cancel();
    _chronoTimer = null;
    setState(() => _running = false);
    SeedService.pauseChrono(_elapsedSeconds);
    SeedService.updateMinute(_elapsedSeconds ~/ 60);
  }

  void _resetAndStart(int startMinute) {
    _chronoTimer?.cancel();
    _elapsedSeconds = startMinute * 60;
    _lastSavedMinute = startMinute;
    _running = false;
    SeedService.updateMinute(startMinute);
    // Efface aussi le statut MI-TEMPS / FIN DE MATCH
    FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .update({'lastEvent': ''});
    _startChrono();
  }

  void _editManually() async {
    final controller = TextEditingController(text: '${_elapsedSeconds ~/ 60}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text('Modifier la minute',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: adminTextPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: adminTextPrimary, fontSize: 20),
          decoration: InputDecoration(
            suffixText: "'",
            suffixStyle: const TextStyle(color: adminGreyLight),
            filled: true,
            fillColor: adminBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: adminBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: adminBorder)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGreyLight))),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null) Navigator.pop(ctx, v);
            },
            child: Text('OK', style: GoogleFonts.inter(color: AdminModuleColors.live, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    // Différer le dispose — le dialog anime encore sa sortie et rebuild le TextField
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      setState(() {
        _elapsedSeconds = result * 60;
        _lastSavedMinute = result;
      });
      SeedService.updateMinute(result);
    }
  }

  String get _display {
    final m = _elapsedSeconds ~/ 60;
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final home = (widget.data['scoreHome'] ?? 0) as int;
    final away = (widget.data['scoreAway'] ?? 0) as int;
    final lastEvent = widget.data['lastEvent'] ?? '';
    final isHalftime = lastEvent == 'halftime';
    final isFulltime = lastEvent == 'fulltime';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          Text(
            'SCORE EN DIRECT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AdminModuleColors.live, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreCtrl(
                team: widget.data['team1'] ?? 'DOM',
                score: home,
                onMinus: home > 0 ? () => SeedService.updateLiveScore(home - 1, away) : null,
                onPlus: () => SeedService.updateLiveScore(home + 1, away),
              ),
              Column(
                children: [
                  Text('VS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22, color: adminGreyLight, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  // Statut MI-TEMPS / FIN
                  if (isFulltime)
                    _StatusChip('FIN', Colors.red)
                  else if (isHalftime)
                    _StatusChip('MI-TEMPS', Colors.orange)
                  else
                    const SizedBox(height: 24),
                ],
              ),
              _ScoreCtrl(
                team: widget.data['team2'] ?? 'EXT',
                score: away,
                onMinus: away > 0 ? () => SeedService.updateLiveScore(home, away - 1) : null,
                onPlus: () => SeedService.updateLiveScore(home, away + 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: adminBorder),
          const SizedBox(height: 14),

          // -- CHRONO ---------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play / Pause
              GestureDetector(
                onTap: _running ? _pauseChrono : _startChrono,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _running ? AdminModuleColors.live.withAlpha(30) : AdminModuleColors.live,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24,
                    color: _running ? AdminModuleColors.live : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Affichage chrono (tap = édition manuelle)
              GestureDetector(
                onTap: _editManually,
                child: Column(
                  children: [
                    Text(
                      _display,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 32, fontWeight: FontWeight.w900,
                        color: _running ? adminTextPrimary : adminGreyLight),
                    ),
                    Text(
                      'appuyer pour éditer',
                      style: GoogleFonts.inter(fontSize: 7, color: adminGreyLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // -- RACCOURCIS -----------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SmallBtn(label: '0', onTap: () => _resetAndStart(0)),
              const SizedBox(width: 6),
              _SmallBtn(label: '45', onTap: () => _resetAndStart(45)),
              const SizedBox(width: 12),
              // MI-TEMPS
              GestureDetector(
                onTap: () async {
                  _pauseChrono();
                  if (isHalftime) {
                    await FirebaseFirestore.instance
                        .collection('live').doc('current')
                        .update({'lastEvent': ''});
                  } else {
                    await SeedService.notifyHalftime();
                    setState(() => _elapsedSeconds = 45 * 60);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHalftime ? Colors.orange.withAlpha(30) : Colors.transparent,
                    border: Border.all(color: Colors.orange.withAlpha(isHalftime ? 200 : 100)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('MI-TEMPS',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.orange, letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 6),
              // FIN DE MATCH
              GestureDetector(
                onTap: () async {
                  _pauseChrono();
                  await SeedService.notifyFulltime(_elapsedSeconds ~/ 60);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFulltime ? Colors.red.withAlpha(30) : Colors.transparent,
                    border: Border.all(color: Colors.red.withAlpha(isFulltime ? 200 : 100)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('FIN',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.red, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Text(label, style: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _ScoreCtrl extends StatelessWidget {
  final String team;
  final int score;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  const _ScoreCtrl({
    required this.team,
    required this.score,
    this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          team.length > 8 ? '${team.substring(0, 8)}…' : team,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: adminGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            GestureDetector(
              onTap: onMinus,
              child: Icon(
                Icons.remove_circle_rounded,
                color: onMinus != null ? adminGreyLight : adminBorder,
                size: 28,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$score',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  height: 1,
                ),
              ),
            ),
            GestureDetector(
              onTap: onPlus,
              child: const Icon(
                Icons.add_circle_rounded,
                color: AdminModuleColors.live,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chip équipe (bottom sheet buts / cartons) — largeur bornée + ellipse.
class _AdminTeamPickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdminTeamPickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AdminModuleColors.live.withAlpha(30) : Colors.transparent,
          border: Border.all(color: selected ? AdminModuleColors.live : adminBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AdminModuleColors.live : adminGrey,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------------
// GOAL FEED
// -------------------------------------------------------------------------------

class _GoalFeed extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GoalFeed({required this.data});

  @override
  Widget build(BuildContext context) {
    final rawEvents = data['events'];
    final events = rawEvents is List
        ? rawEvents
              .whereType<Map<String, dynamic>>()
              .where(
                (e) => const {
                  'goal',
                  'yellow',
                  'red',
                  'substitution',
                  'offside',
                  'goal_cancelled',
                  'goal_disallowed',
                }.contains(e['type']),
              )
              .toList()
        : <Map<String, dynamic>>[];

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
              const Icon(Icons.flag_rounded, color: AdminModuleColors.live, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FAITS DE JEU',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminModuleColors.live,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if ((data['matchId'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            StreamBuilder<MatchMediaStats>(
              stream: MatchMediaStatsService.instance
                  .watch((data['matchId'] ?? '').toString()),
              builder: (context, snap) {
                final s = snap.data ?? const MatchMediaStats();
                if (!s.hasAny) return const SizedBox.shrink();
                return Text(
                  '🎙 ${s.audioClips} audio (${s.audioDurationSec}s · ${s.audioPlays} écoutes)  ·  '
                  '🎬 ${s.videoClips} clips (${s.videoDurationSec}s · ${s.videoPlays} vues)',
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () => _showAddEvent(context, 'goal'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: AdminModuleColors.live,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ BUT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddEvent(context, 'yellow'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ JAUNE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddEvent(context, 'red'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ ROUGE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminTextPrimary,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showSubstitution(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'REMPLACEMENT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => SeedService.clearLiveFacts(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminBg,
                    border: Border.all(color: adminBorder),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'VIDER',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (events.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Aucun fait de jeu',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ...events.reversed
                .map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _eventColor(
                              (g['type'] ?? '').toString(),
                            ).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              "${g['minute'] ?? '?'}'",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: _eventColor(
                                  (g['type'] ?? '').toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            _eventIcon((g['type'] ?? '').toString()),
                            size: 15,
                            color: _eventColor((g['type'] ?? '').toString()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                MatchStatsSchema.eventPlayerLine(g),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: adminTextPrimary,
                                ),
                              ),
                              Text(
                                '${g['team'] ?? ''} • ${_eventLabel((g['type'] ?? '').toString())}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MatchEventAudioRecordButton(
                          matchId: (data['matchId'] ?? '').toString(),
                          event: g,
                          accent: AdminModuleColors.live,
                          onRecord: () async {
                            final mid =
                                (data['matchId'] ?? '').toString().trim();
                            final eid = (g['id'] ?? '').toString().trim();
                            if (mid.isEmpty || eid.isEmpty) return;
                            final ok = await showMatchCommentaryRecordSheet(
                              context,
                              matchId: mid,
                              eventId: eid,
                              type: (g['type'] ?? '').toString(),
                              minute: (g['minute'] as num?)?.toInt() ?? 0,
                              player: MatchStatsSchema.eventPlayerLine(g),
                              team: (g['team'] ?? '').toString(),
                            );
                            if (ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Commentaire audio publié',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: adminGreen,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        MatchEventVideoAttachButton(
                          accent: AdminModuleColors.live,
                          onAttach: () async {
                            final mid =
                                (data['matchId'] ?? '').toString().trim();
                            final eid = (g['id'] ?? '').toString().trim();
                            if (mid.isEmpty || eid.isEmpty) return;
                            final ok = await showMatchHighlightAttachSheet(
                              context,
                              matchId: mid,
                              eventId: eid,
                              type: (g['type'] ?? '').toString(),
                              minute: (g['minute'] as num?)?.toInt() ?? 0,
                              player: MatchStatsSchema.eventPlayerLine(g),
                              team: (g['team'] ?? '').toString(),
                            );
                            if (ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Clip vMix publié',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: adminGreen,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            await SeedService.removeMatchEvent(g);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: adminRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: adminRed,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  int _currentChronoMinute() =>
      LiveBannerFormat.elapsedSecondsFromMap(data) ~/ 60;

  void _showSubstitution(BuildContext context) {
    final outCtrl = TextEditingController();
    final inCtrl = TextEditingController();
    final currentMin = _currentChronoMinute();
    final minuteCtrl = TextEditingController(
      text: currentMin > 0 ? '$currentMin' : '',
    );
    String team = data['team1'] ?? 'DOM';

    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final sedanSide = MatchStatsSchema.isSedanTeamLabel(team);
          Widget playerField({
            required TextEditingController ctrl,
            required String label,
            required String pickerTitle,
          }) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AdminField(
                    ctrl: ctrl,
                    label: label,
                    hint: sedanSide ? 'Effectif ou saisie manuelle' : null,
                  ),
                ),
                if (sedanSide) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Effectif Sedan',
                    onPressed: () async {
                      final p = await showSedanSquadSinglePicker(
                        ctx,
                        title: pickerTitle,
                        accent: const Color(0xFF4A90D9),
                      );
                      if (p != null) {
                        ctrl.text = p.lineupName;
                        setSt(() {});
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9).withAlpha(40),
                      foregroundColor: const Color(0xFF4A90D9),
                    ),
                    icon: const Icon(Icons.groups_rounded),
                  ),
                ],
              ],
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                adminBottomSheetHandle(),
                Text(
                  'REMPLACEMENT',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4A90D9),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sortant puis entrant — un joueur peut revenir (R1). '
                  'La compo d’origine n’est pas modifiée.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AdminTeamPickChip(
                        label: '${data['team1'] ?? 'DOM'}',
                        selected: team == (data['team1'] ?? 'DOM'),
                        onTap: () =>
                            setSt(() => team = data['team1'] ?? 'DOM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AdminTeamPickChip(
                        label: '${data['team2'] ?? 'EXT'}',
                        selected: team == (data['team2'] ?? 'EXT'),
                        onTap: () =>
                            setSt(() => team = data['team2'] ?? 'EXT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                playerField(
                  ctrl: outCtrl,
                  label: 'Sortant *',
                  pickerTitle: 'Joueur sortant',
                ),
                const SizedBox(height: 10),
                playerField(
                  ctrl: inCtrl,
                  label: 'Entrant *',
                  pickerTitle: 'Joueur entrant',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 120,
                  child: AdminField(
                    ctrl: minuteCtrl,
                    label: "Min' (chrono)",
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final min = int.tryParse(minuteCtrl.text) ?? 0;
                    final out = outCtrl.text.trim();
                    final inn = inCtrl.text.trim();
                    if (out.isEmpty || inn.isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Indique le sortant et l’entrant.',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                      }
                      return;
                    }
                    Map<String, dynamic>? event;
                    try {
                      event = await SeedService.addMatchEvent(
                        type: 'substitution',
                        team: team,
                        player: out,
                        playerIn: inn,
                        minute: min,
                      );
                    } on StateError catch (e) {
                      if (e.message == 'substitution_players_required' &&
                          ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Indique le sortant et l’entrant.',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                      }
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (event != null && context.mounted) {
                      await offerMatchMediaAfterEvent(
                        context,
                        event: event,
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'VALIDER',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
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
  }

  void _showAddEvent(BuildContext context, String type) {
    final playerCtrl = TextEditingController();
    final currentMin = _currentChronoMinute();
    final minuteCtrl = TextEditingController(
      text: currentMin > 0 ? '$currentMin' : '',
    );
    String team = data['team1'] ?? 'DOM';
    final title = switch (type) {
      'yellow' => 'AJOUTER UN CARTON JAUNE',
      'red' => 'AJOUTER UN CARTON ROUGE',
      _ => 'AJOUTER UN BUT',
    };
    final playerLabel = type == 'goal' ? 'Buteur' : 'Joueur';

    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              adminBottomSheetHandle(),
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AdminModuleColors.live,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AdminTeamPickChip(
                      label: '${data['team1'] ?? 'DOM'}',
                      selected: team == (data['team1'] ?? 'DOM'),
                      onTap: () =>
                          setSt(() => team = data['team1'] ?? 'DOM'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminTeamPickChip(
                      label: '${data['team2'] ?? 'EXT'}',
                      selected: team == (data['team2'] ?? 'EXT'),
                      onTap: () =>
                          setSt(() => team = data['team2'] ?? 'EXT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final sedanSide =
                      MatchStatsSchema.isSedanTeamLabel(team);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AdminField(
                          ctrl: playerCtrl,
                          label: playerLabel,
                          hint: sedanSide
                              ? 'Effectif ou saisie manuelle'
                              : null,
                        ),
                      ),
                      if (sedanSide) ...[
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Effectif Sedan',
                          onPressed: () async {
                            final p = await showSedanSquadSinglePicker(
                              ctx,
                              title: playerLabel,
                              accent: AdminModuleColors.live,
                            );
                            if (p != null) {
                              playerCtrl.text = p.lineupName;
                              setSt(() {});
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AdminModuleColors.live.withAlpha(40),
                            foregroundColor: AdminModuleColors.live,
                          ),
                          icon: const Icon(Icons.groups_rounded),
                        ),
                      ],
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: AdminField(
                          ctrl: minuteCtrl,
                          label: "Min' (chrono)",
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final min = int.tryParse(minuteCtrl.text) ?? 0;
                  final event = await SeedService.addMatchEvent(
                    type: type,
                    team: team,
                    player: playerCtrl.text.trim().isEmpty
                        ? 'Inconnu'
                        : playerCtrl.text.trim(),
                    minute: min,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    await offerMatchMediaAfterEvent(
                      context,
                      event: event,
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AdminModuleColors.live,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'VALIDER',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'substitution':
        return Icons.swap_horiz_rounded;
      case 'yellow':
      case 'red':
        return Icons.crop_portrait_rounded;
      case 'offside':
        return Icons.flag_rounded;
      case 'goal_cancelled':
      case 'goal_disallowed':
        return Icons.block_rounded;
      default:
        return Icons.sports_soccer_rounded;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'substitution':
        return const Color(0xFF4A90D9);
      case 'yellow':
        return Colors.amber;
      case 'red':
        return adminRed;
      case 'offside':
        return const Color(0xFF5C6BC0);
      case 'goal_cancelled':
        return Colors.orange;
      case 'goal_disallowed':
        return Colors.deepPurple;
      default:
        return AdminModuleColors.live;
    }
  }

  String _eventLabel(String type) {
    switch (type) {
      case 'substitution':
        return 'Remplacement';
      case 'yellow':
        return 'Carton jaune';
      case 'red':
        return 'Carton rouge';
      case 'offside':
        return 'Hors-jeu';
      case 'goal_cancelled':
        return 'But annulé';
      case 'goal_disallowed':
        return 'But refusé';
      default:
        return 'But';
    }
  }
}

// -------------------------------------------------------------------------------
// EMISSION POLL PANEL
// -------------------------------------------------------------------------------

class _EmissionPollPanel extends StatelessWidget {
  final bool emissionLive;
  final Map<String, dynamic>? data;

  const _EmissionPollPanel({required this.emissionLive, required this.data});

  Future<void> _showQuickEditSheet(BuildContext context) async {
    final pollData = data ?? const <String, dynamic>{};
    final titleCtrl = TextEditingController(
      text: (pollData['pollTitle'] as String? ?? '').trim(),
    );
    final subtitleCtrl = TextEditingController(
      text: (pollData['pollSubtitle'] as String? ?? '').trim(),
    );
    final sponsorCtrl = TextEditingController(
      text: (pollData['pollSponsorName'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (pollData['pollBackgroundImage'] as String? ?? '').trim(),
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
                    'VISUEL DU SONDAGE',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AdminModuleColors.live,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu peux changer le titre, le sous-titre et l\'image sans relancer le sondage.',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  ),
                  const SizedBox(height: 14),
                  AdminField(ctrl: titleCtrl, label: 'Titre du sondage'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: subtitleCtrl, label: 'Sous-titre'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: sponsorCtrl, label: 'Nom du sponsor'),
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
                                        .doc('emission')
                                        .set({
                                          'pollTitle': titleCtrl.text.trim(),
                                          'pollSubtitle': subtitleCtrl.text
                                              .trim(),
                                          'pollSponsorName': sponsorCtrl.text
                                              .trim(),
                                          'pollBackgroundImage': backgroundCtrl
                                              .text
                                              .trim(),
                                        }, SetOptions(merge: true));
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Visuel du sondage mis à jour.',
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
                              color: AdminModuleColors.live,
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
    subtitleCtrl.dispose();
    sponsorCtrl.dispose();
    backgroundCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pollData = data ?? const <String, dynamic>{};
    final status = (pollData['pollStatus'] as String? ?? '').trim();
    final active = EmissionPollService.isPollActive(pollData);
    final options = EmissionPollService.optionMaps(pollData);
    final counts = EmissionPollService.optionCounts(pollData);
    final totalVotes = EmissionPollService.totalVotes(pollData);
    final title = (pollData['pollTitle'] as String? ?? '').trim();
    final subtitle = (pollData['pollSubtitle'] as String? ?? '').trim();
    final winnerLabel = (pollData['pollWinnerLabel'] as String? ?? '').trim();
    final sponsorName = (pollData['pollSponsorName'] as String? ?? '').trim();

    if (active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        EmissionPollService.ensurePollState(pollData);
      });
    }

    final rankedOptions = [...options]
      ..sort((a, b) {
        final aVotes = counts[(a['id'] as String? ?? '').trim()] ?? 0;
        final bVotes = counts[(b['id'] as String? ?? '').trim()] ?? 0;
        return bVotes.compareTo(aVotes);
      });

    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.poll_rounded, color: AdminModuleColors.live, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SONDAGE ÉMISSION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminModuleColors.live,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? adminRed.withAlpha(20)
                      : status == 'closed'
                      ? AdminModuleColors.live.withAlpha(20)
                      : adminBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? adminRed.withAlpha(90)
                        : status == 'closed'
                        ? AdminModuleColors.live.withAlpha(90)
                        : adminBorder,
                  ),
                ),
                child: Text(
                  active
                      ? 'ACTIF'
                      : status == 'closed'
                      ? 'CLOS'
                      : 'INACTIF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? adminRed
                        : status == 'closed'
                        ? AdminModuleColors.live
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
                        color: AdminModuleColors.live,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'VISUEL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AdminModuleColors.live,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!emissionLive)
            Text(
              'Démarre d\'abord l\'émission avant de lancer un sondage.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else if (options.isEmpty)
            Text(
              'Prépare ton titre, tes choix et la durée. Le public votera sans voir les résultats pendant le direct.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else ...[
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
            ],
            if (sponsorName.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MiniInfoPill(icon: Icons.campaign_rounded, label: sponsorName),
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
                    child: _VoteMetaColumnV2(
                      label: 'CHOIX',
                      value: '${options.length}',
                    ),
                  ),
                  Expanded(
                    child: _VoteMetaColumnV2(
                      label: 'VOTES',
                      value: '$totalVotes',
                    ),
                  ),
                  Expanded(
                    child: _VoteMetaColumnV2(
                      label: active ? 'TEMPS RESTANT' : 'STATUT',
                      value: active ? _remainingLabel(pollData) : 'Clos',
                      accent: active ? adminRed : AdminModuleColors.live,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rankedOptions.map((option) {
              final optionId = (option['id'] as String? ?? '').trim();
              final label = (option['label'] as String? ?? '').trim();
              final votes = counts[optionId] ?? 0;
              final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
              final isWinner = winnerLabel.isNotEmpty && winnerLabel == label;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWinner ? AdminModuleColors.live : adminBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$votes vote${votes > 1 ? 's' : ''} · ${(percent * 100).round()}%',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          backgroundColor: adminBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isWinner ? AdminModuleColors.live : adminRed.withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: !emissionLive || active
                      ? null
                      : () => _showCreatePollSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: !emissionLive || active ? adminBg : AdminModuleColors.live,
                      borderRadius: BorderRadius.circular(10),
                      border: !emissionLive || active
                          ? Border.all(color: adminBorder)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        active ? 'SONDAGE EN COURS' : 'LANCER LE SONDAGE',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: !emissionLive || active
                              ? adminGrey
                              : Colors.black,
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
                      await EmissionPollService.stopPoll(reason: 'manual');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sondage émission arrêté manuellement.',
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
                          'ARRÊTER',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  Future<void> _showCreatePollSheet(BuildContext context) async {
    final titleCtrl = TextEditingController(
      text: (data?['pollTitle'] as String? ?? '').trim(),
    );
    final subtitleCtrl = TextEditingController(
      text: (data?['pollSubtitle'] as String? ?? '').trim(),
    );
    final durationCtrl = TextEditingController(text: '10');
    final sponsorCtrl = TextEditingController(
      text: (data?['pollSponsorName'] as String? ?? '').trim(),
    );
    final sponsorLogoCtrl = TextEditingController(
      text: (data?['pollSponsorLogo'] as String? ?? '').trim(),
    );
    final sponsorColorCtrl = TextEditingController(
      text: (data?['pollSponsorColorHex'] as String? ?? '').trim(),
    );
    final sponsorLinkCtrl = TextEditingController(
      text: (data?['pollSponsorLinkUrl'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (data?['pollBackgroundImage'] as String? ?? '').trim(),
    );
    final optionCtrls = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    var revealResults = data?['pollRevealResults'] != false;
    var selectedSponsorId = (data?['pollSponsorId'] as String? ?? '').trim();
    var saving = false;

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
                  'CRÉER UN SONDAGE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AdminModuleColors.live,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tu remplis librement le titre, le sous-titre et les choix du direct.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
                const SizedBox(height: 14),
                AdminField(ctrl: titleCtrl, label: 'Titre du sondage'),
                const SizedBox(height: 10),
                AdminField(ctrl: subtitleCtrl, label: 'Sous-titre (optionnel)'),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: durationCtrl,
                  label: 'Durée en minutes (1 à 30)',
                ),
                const SizedBox(height: 10),
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
                    return DropdownButtonFormField<String>(
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
                          borderSide: const BorderSide(color: AdminModuleColors.live),
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
                          sponsorCtrl.text = (selected['name'] as String? ?? '')
                              .trim();
                          sponsorLogoCtrl.text =
                              (selected['logoUrl'] as String? ?? '').trim();
                          sponsorColorCtrl.text =
                              (selected['colorHex'] as String? ?? '').trim();
                          sponsorLinkCtrl.text =
                              (selected['linkUrl'] as String? ?? '').trim();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: sponsorCtrl,
                  label: 'Nom du sponsor (optionnel)',
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
                              'Afficher le résultat final au public',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              revealResults
                                  ? 'Le gagnant sera visible après clôture.'
                                  : 'Le résultat restera visible seulement dans l admin.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: revealResults,
                        onChanged: (value) =>
                            setModalState(() => revealResults = value),
                        activeThumbColor: AdminModuleColors.live,
                        inactiveThumbColor: adminGrey,
                        inactiveTrackColor: adminBorder,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'CHOIX DU SONDAGE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AdminModuleColors.live,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                ...optionCtrls.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: AdminField(
                            ctrl: ctrl,
                            label: 'Choix ${index + 1}',
                          ),
                        ),
                        if (optionCtrls.length > 2) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                optionCtrls[index].dispose();
                                optionCtrls.removeAt(index);
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: adminBg,
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
                if (optionCtrls.length < 6)
                  GestureDetector(
                    onTap: () => setModalState(() {
                      optionCtrls.add(TextEditingController());
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: AdminModuleColors.live,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AJOUTER UN CHOIX',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AdminModuleColors.live,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                final options = optionCtrls
                                    .map((ctrl) => ctrl.text.trim())
                                    .where((option) => option.isNotEmpty)
                                    .toList();
                                setModalState(() => saving = true);
                                try {
                                  await EmissionPollService.startPoll(
                                    title: titleCtrl.text.trim(),
                                    subtitle: subtitleCtrl.text.trim(),
                                    sponsorId: selectedSponsorId,
                                    sponsorName: sponsorCtrl.text.trim(),
                                    sponsorLogo: sponsorLogoCtrl.text.trim(),
                                    sponsorColorHex: sponsorColorCtrl.text
                                        .trim(),
                                    sponsorLinkUrl: sponsorLinkCtrl.text.trim(),
                                    backgroundImageUrl: backgroundCtrl.text
                                        .trim(),
                                    options: options,
                                    durationMinutes:
                                        int.tryParse(
                                          durationCtrl.text.trim(),
                                        ) ??
                                        10,
                                    revealResults: revealResults,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sondage émission lancé.'),
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
                            color: AdminModuleColors.live,
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

    titleCtrl.dispose();
    subtitleCtrl.dispose();
    durationCtrl.dispose();
    sponsorCtrl.dispose();
    sponsorLogoCtrl.dispose();
    sponsorColorCtrl.dispose();
    sponsorLinkCtrl.dispose();
    backgroundCtrl.dispose();
    for (final ctrl in optionCtrls) {
      ctrl.dispose();
    }
  }

  String _remainingLabel(Map<String, dynamic> data) {
    final endsAt = data['pollEndsAt'];
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

class _VoteMetaColumnV2 extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _VoteMetaColumnV2({
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

// -------------------------------------------------------------------------------
// SMALL HELPERS
// -------------------------------------------------------------------------------

class _DirectVotesSection extends StatefulWidget {
  final Map<String, dynamic> data;

  const _DirectVotesSection({required this.data});

  @override
  State<_DirectVotesSection> createState() => _DirectVotesSectionState();
}

class _DirectVotesSectionState extends State<_DirectVotesSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.how_to_vote_rounded,
                      size: 18,
                      color: AdminModuleColors.live,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VOTES & NOTES',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: adminTextPrimary,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'Homme du match et note du public',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: adminGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: adminGrey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: adminBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                children: [
                  MotmVoteAdminPanel(data: widget.data),
                  const SizedBox(height: 12),
                  MatchRatingAdminPanel(data: widget.data),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool isActive, loading;
  final VoidCallback onToggle;
  const _LiveCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? AdminModuleColors.live : AdminModuleColors.preparation;
    return Container(
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AdminModuleColors.live.withAlpha(120) : adminBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 22),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: adminRed,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              )
            else
              AdminPrimaryButton(
                label: isActive ? 'Arrêter' : 'Démarrer',
                icon: isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                height: 36,
                color: accent,
                textColor: Colors.white,
                onTap: onToggle,
              ),
          ],
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: adminBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: adminGrey,
        ),
      ),
    ),
  );
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: adminBorder.withAlpha(45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: adminBorder.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AdminModuleColors.live),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: adminGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _SectionLabel(this.label, {this.color = adminGrey, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 1, color: color.withAlpha(50))),
        ],
      ),
    );
  }
}

class _QStat extends StatelessWidget {
  final String label, value;
  const _QStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 7,
            fontWeight: FontWeight.w700,
            color: adminGrey,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int val;
  final VoidCallback onInc, onDec;
  final String? shortcutLabel; // ex: 'A', '1'
  final VoidCallback? onRemap; // long press ? remap
  final Color color;

  const _CounterRow({
    required this.label,
    required this.val,
    required this.onInc,
    required this.onDec,
    this.shortcutLabel,
    this.onRemap,
    this.color = AdminModuleColors.live,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: adminBg,
          border: Border.all(color: adminBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Bouton —
              GestureDetector(
                onTap: onDec,
                child: Container(
                  width: 44,
                  color: adminBorder.withAlpha(55),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_rounded, size: 18, color: adminGrey),
                ),
              ),
              // Valeur + label (long press ? remap)
              Expanded(
                child: GestureDetector(
                  onLongPress: onRemap,
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$val',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: val > 0 ? color : adminTextPrimary,
                              ),
                            ),
                            if (shortcutLabel != null) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: adminBorder,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  shortcutLabel!,
                                  style: GoogleFonts.inter(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    color: adminGrey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: adminGrey,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
              // Bouton +
              GestureDetector(
                onTap: onInc,
                child: Container(
                  width: 44,
                  color: color.withAlpha(20),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, size: 18, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SBarRow extends StatelessWidget {
  final String label;
  final int v1, v2;
  final String sfx;
  final Color color;
  const _SBarRow(this.label, this.v1, this.v2,
      {this.sfx = '', this.color = AdminModuleColors.live});

  @override
  Widget build(BuildContext context) {
    final total = v1 + v2;
    final frac1 = total == 0 ? 0.5 : v1 / total;
    final bar1 = (frac1 * 100).round().clamp(1, 99);
    final isLeading = v1 >= v2;
    final isTrailing = v2 > v1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '$v1$sfx',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isLeading && total > 0 ? color : adminTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: adminGrey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$v2$sfx',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isTrailing && total > 0 ? color : adminTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: bar1,
                    child: Container(color: color.withAlpha(180)),
                  ),
                  Expanded(
                    flex: 100 - bar1,
                    child: Container(color: color.withAlpha(40)),
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

// -----------------------------------------------------------------------------
// Spectateurs score (mobile + TV) — live/current.viewers
// -----------------------------------------------------------------------------

class _LiveViewersChip extends StatelessWidget {
  final int viewers;
  const _LiveViewersChip({required this.viewers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminModuleColors.live.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminModuleColors.live.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_rounded,
              size: 16, color: AdminModuleColors.live),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              viewers <= 0
                  ? 'Personne ne regarde le score pour l’instant'
                  : '$viewers personne${viewers > 1 ? 's' : ''} '
                      'regardent le score (app / TV)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bouton inline « Modifier l'URL stream » — utilisable en cours de live
// -----------------------------------------------------------------------------

class _EditStreamUrlButton extends StatelessWidget {
  final String currentUrl;
  /// Chemin Firestore du document à mettre à jour (ex: 'live/current').
  final String docPath;

  const _EditStreamUrlButton({
    required this.currentUrl,
    required this.docPath,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.link_rounded, size: 16),
        label: Text(
          currentUrl.isEmpty ? 'Ajouter URL stream' : 'Modifier l\'URL stream',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminModuleColors.live,
          side: BorderSide(color: AdminModuleColors.live.withAlpha(80)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: currentUrl);
    final ok = await adminShowFormDialog(context, 'URL DU STREAM LIVE', [
      AdminField(ctrl: ctrl, label: 'URL YouTube / Stream'),
    ]);
    if (!ok) return;
    final url = YoutubeParser.sanitizeShareUrl(ctrl.text.trim());
    final parts = docPath.split('/');
    if (parts.length != 2) return;
    try {
      await FirebaseFirestore.instance
          .collection(parts[0])
          .doc(parts[1])
          .update({'url': url});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL stream mise à jour.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}

class _SBarRow2 extends StatelessWidget {
  final String label, v1, v2;
  const _SBarRow2(this.label, this.v1, this.v2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              v1,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: adminGrey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              v2,
              textAlign: TextAlign.right,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
