import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/quiz_raffle.dart';
import '../../../../services/quiz_raffle_service.dart';
import '../../../../widgets/quiz_raffle_live_card.dart';
import '../../../../widgets/quiz_raffle_tombola.dart';
import '../../admin_components.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_navigation.dart';
import '../../admin_palette.dart';

/// Pilotage quiz + tirage (onglet Reward). Indépendant du sondage émission.
class QuizRaffleAdminSection extends StatefulWidget {
  const QuizRaffleAdminSection({super.key});

  @override
  State<QuizRaffleAdminSection> createState() => _QuizRaffleAdminSectionState();
}

class _QuizRaffleAdminSectionState extends State<QuizRaffleAdminSection> {
  final _titleCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _customMinCtrl = TextEditingController();
  final _choiceCtrls = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  int _presetSeconds = 60;
  bool _busy = false;
  String? _closeAttemptedId;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _titleCtrl.dispose();
    _questionCtrl.dispose();
    _customMinCtrl.dispose();
    for (final c in _choiceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  int get _durationSeconds {
    if (_presetSeconds > 0) return _presetSeconds;
    final m = int.tryParse(_customMinCtrl.text.trim()) ?? 1;
    return (m.clamp(1, 60)) * 60;
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await QuizRaffleService.startQuiz(
        title: _titleCtrl.text,
        question: _questionCtrl.text,
        choices: _choiceCtrls.map((c) => c.text).toList(),
        correctIndex: _correctIndex,
        durationSeconds: _durationSeconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz lancé — visible sur DVCR TV.')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _draw(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await QuizRaffleService.drawNow(id);
      if (!mounted) return;
      final name = (result['winnerName'] as String? ?? '').trim();
      final uid = (result['winnerUid'] as String? ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uid.isEmpty
                ? 'Tirage fait — personne n’avait la bonne réponse.'
                : 'Gagnant : ${name.isEmpty ? uid : name}',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tirage impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Annuler ce quiz ?',
          style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Pas de tirage. Le quiz disparaît pour les supporters.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler le quiz'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await QuizRaffleService.cancelQuiz(id);
  }

  Future<void> _maybeCloseExpired(Map<String, dynamic> quiz) async {
    if (_busy) return;
    if (QuizRaffleService.statusOf(quiz) != 'open') return;
    if (QuizRaffleService.isOpen(quiz, _now)) return;
    final id = (quiz['id'] as String? ?? '').trim();
    if (id.isEmpty || _closeAttemptedId == id) return;
    _closeAttemptedId = id;
    try {
      await QuizRaffleService.closeAndDraw(id);
    } catch (_) {
      // Le cron 1 min prendra le relais si la callable n’est pas encore déployée.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _QuizRaffleTombolaTestCue(),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: QuizRaffleService.watchActive(),
          builder: (context, snap) {
            final quiz = QuizRaffleService.pickNewest(snap.data?.docs ?? const []);
            if (quiz != null && QuizRaffleService.statusOf(quiz) == 'open') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _maybeCloseExpired(quiz);
              });
            }
            return Container(
              decoration: BoxDecoration(
                color: adminSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: adminBorder),
              ),
              padding: const EdgeInsets.all(14),
              child: quiz == null ? _buildForm() : _buildLive(quiz),
            );
          },
        ),
        const SizedBox(height: 16),
        const _QuizRaffleHistoryPanel(),
      ],
    );
  }

  Widget _buildForm() {
    const presets = <(String, int)>[
      ('30 s', 30),
      ('1 min', 60),
      ('2 min', 120),
      ('5 min', 300),
      ('10 min', 600),
      ('Autre', 0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUIZ + TIRAGE',
          style: GoogleFonts.barlowCondensed(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AdminModuleColors.live,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Question à choix, une bonne réponse (cachée jusqu’au tirage). '
          'Un gagnant au hasard parmi ceux qui ont bon. Visible sur DVCR TV.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        AdminField(
          ctrl: _titleCtrl,
          label: 'Titre (Live)',
          hint: 'Quiz antenne, Tirage écharpe… vide = Quiz',
          accent: AdminModuleColors.live,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _questionCtrl,
          label: 'Question',
          maxLines: 2,
          accent: AdminModuleColors.live,
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 4; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _correctIndex = i),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8, top: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _correctIndex == i
                          ? AdminModuleColors.live
                          : adminHairline,
                    ),
                    color: _correctIndex == i
                        ? AdminModuleColors.live
                        : Colors.transparent,
                  ),
                ),
              ),
              Expanded(
                child: AdminField(
                  ctrl: _choiceCtrls[i],
                  label: i < 2 ? 'Choix ${i + 1}' : 'Choix ${i + 1} (optionnel)',
                  accent: AdminModuleColors.live,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Bonne réponse = pastille à gauche. Durée :',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in presets)
              ChoiceChip(
                label: Text(p.$1, style: GoogleFonts.inter(fontSize: 12)),
                selected: _presetSeconds == p.$2,
                selectedColor: adminSurface,
                side: BorderSide(
                  color: _presetSeconds == p.$2
                      ? AdminModuleColors.live
                      : adminHairline,
                ),
                onSelected: (_) => setState(() => _presetSeconds = p.$2),
              ),
          ],
        ),
        if (_presetSeconds == 0) ...[
          const SizedBox(height: 8),
          AdminField(
            ctrl: _customMinCtrl,
            label: 'Minutes (1–60)',
            keyboardType: TextInputType.number,
            accent: AdminModuleColors.live,
          ),
        ],
        const SizedBox(height: 14),
        AdminPrimaryButton(
          label: 'Démarrer',
          icon: Icons.play_arrow_rounded,
          loading: _busy,
          color: AdminModuleColors.live,
          onTap: _start,
        ),
      ],
    );
  }

  Widget _buildLive(Map<String, dynamic> quiz) {
    final id = (quiz['id'] as String? ?? '').trim();
    final status = QuizRaffleService.statusOf(quiz);
    final open = QuizRaffleService.isOpen(quiz, _now);
    final drawn = QuizRaffleService.isDrawn(quiz);
    final ends = QuizRaffleService.endsAtOf(quiz);
    final choices = QuizRaffleService.choicesOf(quiz);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.casino_outlined, color: AdminModuleColors.live, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                QuizRaffleService.titleOf(quiz).toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminModuleColors.live,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              drawn
                  ? 'TIRÉ'
                  : open
                      ? 'OUVERT'
                      : status == 'open'
                          ? 'FIN CHRONO'
                          : status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: drawn ? AdminModuleColors.live : adminRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          QuizRaffleService.questionOf(quiz),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: QuizRaffleService.secretRef(id).snapshots(),
          builder: (context, secretSnap) {
            final correct =
                (secretSnap.data?.data()?['correctIndex'] as num?)?.toInt();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: QuizRaffleService.votesCol(id).snapshots(),
              builder: (context, votesSnap) {
                final votes = votesSnap.data?.docs ?? const [];
                final counts = List<int>.filled(choices.length, 0);
                for (final v in votes) {
                  final i = (v.data()['choiceIndex'] as num?)?.toInt();
                  if (i != null && i >= 0 && i < counts.length) {
                    counts[i] += 1;
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < choices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${correct == i ? '● ' : '○ '}${choices[i]}  —  ${counts[i]} vote${counts[i] > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: correct == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: adminTextPrimary,
                          ),
                        ),
                      ),
                    Text(
                      '${votes.length} réponse${votes.length > 1 ? 's' : ''} au total',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                    ),
                  ],
                );
              },
            );
          },
        ),
        if (drawn) ...[
          const SizedBox(height: 12),
          QuizRaffleTombolaReveal(
            key: ValueKey('admin-tombola-$id'),
            winnerUid: QuizRaffleService.winnerUidOf(quiz),
            winnerName: QuizRaffleService.winnerNameOf(quiz),
            eligibleNames: QuizRaffleService.eligibleNamesOf(quiz),
          ),
          const SizedBox(height: 10),
          _QuizWinnerTapLine(
            winnerUid: QuizRaffleService.winnerUidOf(quiz),
            winnerName: QuizRaffleService.winnerNameOf(quiz),
          ),
        ] else if (ends != null) ...[
          const SizedBox(height: 8),
          Text(
            open
                ? 'Fin du chrono : ${_fmt(ends)}'
                : 'Chrono terminé — tirage auto (functions) ou bouton ci-dessous.',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
          ),
        ],
        const SizedBox(height: 12),
        if (!drawn) ...[
          AdminPrimaryButton(
            label: 'Tirer au sort maintenant',
            icon: Icons.casino_rounded,
            loading: _busy,
            color: AdminModuleColors.live,
            onTap: () => _draw(id),
          ),
          const SizedBox(height: 8),
          AdminPrimaryButton(
            label: 'Annuler',
            color: adminCard,
            textColor: adminGrey,
            onTap: _busy ? null : () => _cancel(id),
          ),
        ] else
          AdminPrimaryButton(
            label: 'Masquer pour les supporters',
            color: adminCard,
            textColor: adminGrey,
            onTap: () => QuizRaffleService.hideResult(id),
          ),
      ],
    );
  }

  String _fmt(DateTime ends) {
    var s = ends.difference(_now).inSeconds;
    if (s < 0) s = 0;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}

/// Switch TEST — même carte Live que les fans. Titre libre (plus « tombola » figé).
class _QuizRaffleTombolaTestCue extends StatefulWidget {
  const _QuizRaffleTombolaTestCue();

  @override
  State<_QuizRaffleTombolaTestCue> createState() =>
      _QuizRaffleTombolaTestCueState();
}

class _QuizRaffleTombolaTestCueState extends State<_QuizRaffleTombolaTestCue> {
  final _titleCtrl = TextEditingController();
  bool _seeded = false;
  Timer? _titleDebounce;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_scheduleTitleSave);
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleCtrl.removeListener(_scheduleTitleSave);
    _titleCtrl.dispose();
    super.dispose();
  }

  void _seedTitle(Map<String, dynamic>? data) {
    if (_seeded) return;
    _seeded = true;
    final raw = (data?['title'] as String? ?? '').trim();
    if (raw.isNotEmpty) _titleCtrl.text = raw;
  }

  void _scheduleTitleSave() {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(QuizRaffleService.updateTestTitle(_titleCtrl.text));
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: QuizRaffleService.testRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        _seedTitle(data);
        final on = QuizRaffleService.isForceTest(data);
        final preview = QuizRaffleService.testQuizFromCue(data);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: on ? adminGold.withAlpha(28) : adminCard,
            borderRadius: BorderRadius.circular(adminPaperRadius),
            border: Border.all(
              color: on ? adminGold : adminInk.withAlpha(40),
              width: on ? 2 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEST',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminGrey,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AdminField(
                          ctrl: _titleCtrl,
                          label: 'Titre affiché sur DVCR TV',
                          hint: 'Ce que tu veux — plus « tombola » figé',
                          accent: AdminModuleColors.live,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          on
                              ? 'ON — défilement avec des prénoms inventés. Éteins pour retirer.'
                              : 'OFF — tape le titre, allume pour voir sur TV, sans vrai tirage.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: adminGrey,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Text(
                        on ? 'ON' : 'OFF',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: on ? adminGreen : adminGrey,
                          letterSpacing: 1,
                        ),
                      ),
                      Switch(
                        value: on,
                        onChanged: (v) => _setForce(context, v),
                        activeThumbColor: adminInk,
                        activeTrackColor: adminGold,
                      ),
                    ],
                  ),
                ],
              ),
              if (snap.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'Lecture Firestore en erreur — tu peux quand même basculer le switch.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: adminRed,
                  ),
                ),
              ],
              if (on && preview != null) ...[
                const SizedBox(height: 12),
                QuizRaffleLiveCard(
                  key: ValueKey(
                    'reward-test-${QuizRaffleService.playNonceOf(preview)}',
                  ),
                  quiz: preview,
                ),
                const SizedBox(height: 10),
                AdminPrimaryButton(
                  label: 'Relancer le défilement',
                  icon: Icons.replay_rounded,
                  color: adminCard,
                  textColor: adminInk,
                  onTap: () => _setForce(context, true),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _setForce(BuildContext context, bool on) async {
    try {
      await QuizRaffleService.setForceTest(on, title: _titleCtrl.text);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de changer le TEST : $e',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
  }
}

class _QuizWinnerTapLine extends StatelessWidget {
  final String winnerUid;
  final String winnerName;

  const _QuizWinnerTapLine({
    required this.winnerUid,
    required this.winnerName,
  });

  @override
  Widget build(BuildContext context) {
    final uid = winnerUid.trim();
    final name = winnerName.trim().isEmpty ? 'Membre' : winnerName.trim();
    if (uid.isEmpty || uid == 'test_preview') {
      return Text(
        'Personne n’a trouvé',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: adminGrey,
        ),
      );
    }
    return InkWell(
      onTap: () => AdminNavigation.openUserProfile(
        context,
        uid: uid,
        displayName: name,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Gagnant : $name',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: adminInk,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: adminGrey, size: 22),
          ],
        ),
      ),
    );
  }
}

class _QuizRaffleHistoryPanel extends StatelessWidget {
  const _QuizRaffleHistoryPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: QuizRaffleService.watchDrawnHistory(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Historique indisponible.',
            style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          );
        }
        final items = QuizRaffleService.historyFromDocs(
          snap.data?.docs ?? const [],
        );
        return Container(
          decoration: BoxDecoration(
            color: adminSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: adminBorder),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'HISTORIQUE',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminModuleColors.live,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tirages déjà faits, du plus récent. Touche le gagnant pour ouvrir son profil.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (!snap.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (items.isEmpty)
                Text(
                  'Aucun tirage pour l’instant.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                )
              else
                for (final item in items) _QuizHistoryRow(item: item),
            ],
          ),
        );
      },
    );
  }
}

class _QuizHistoryRow extends StatelessWidget {
  final QuizRaffleHistoryItem item;

  const _QuizHistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final when = QuizRaffleLogic.formatDrawnAtParis(item.drawnAt);
    final title = QuizRaffleLogic.displayTitle(item.title);
    final question = QuizRaffleLogic.shortQuestion(item.question);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(adminPaperRadius),
          border: Border.all(color: adminHairline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (when.isNotEmpty)
                Text(
                  when,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: adminGrey,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: adminInk,
                ),
              ),
              if (question.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
              ],
              const SizedBox(height: 6),
              if (item.hasWinner)
                InkWell(
                  onTap: () => AdminNavigation.openUserProfile(
                    context,
                    uid: item.winnerUid,
                    displayName: item.winnerName,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.winnerName.trim().isEmpty
                              ? 'Membre'
                              : item.winnerName.trim(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AdminModuleColors.live,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: adminGrey,
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Personne n’a trouvé',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: adminGrey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
