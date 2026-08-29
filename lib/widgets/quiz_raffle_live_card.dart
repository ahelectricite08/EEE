import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/chat_screen.dart' show AuthLockScreen;
import '../screens/live/theme/tv_theme.dart';
import '../screens/live/theme/tv_type.dart';
import '../services/quiz_raffle_service.dart';
import 'quiz_raffle_tombola.dart';

/// Quiz-sondage + tirage — visible sur DVCR TV / Live uniquement (pas l’accueil).
class QuizRaffleLiveSlot extends StatelessWidget {
  const QuizRaffleLiveSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: QuizRaffleService.testRef.snapshots(),
      builder: (context, testSnap) {
        final testQuiz = QuizRaffleService.testQuizFromCue(testSnap.data?.data());
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: QuizRaffleService.watchActive(),
          builder: (context, snap) {
            final data = QuizRaffleService.pickNewest(snap.data?.docs ?? const []);
            final status = data == null ? '' : QuizRaffleService.statusOf(data);
            final showReal = data != null && (status == 'open' || status == 'drawn');
            if (testQuiz == null && !showReal) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (testQuiz != null) ...[
                    QuizRaffleLiveCard(
                      key: ValueKey(
                        'live-test-${QuizRaffleService.playNonceOf(testQuiz)}',
                      ),
                      quiz: testQuiz,
                    ),
                    if (showReal) const SizedBox(height: 18),
                  ],
                  if (showReal) QuizRaffleLiveCard(quiz: data),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class QuizRaffleLiveCard extends StatefulWidget {
  final Map<String, dynamic> quiz;

  const QuizRaffleLiveCard({super.key, required this.quiz});

  @override
  State<QuizRaffleLiveCard> createState() => _QuizRaffleLiveCardState();
}

class _QuizRaffleLiveCardState extends State<QuizRaffleLiveCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _sending = false;

  String get _id => (widget.quiz['id'] as String? ?? '').trim();

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant QuizRaffleLiveCard oldWidget) {
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
    if (!QuizRaffleService.isOpen(widget.quiz, DateTime.now()) &&
        QuizRaffleService.statusOf(widget.quiz) != 'open') {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _vote(int index) async {
    if (_sending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AuthLockScreen()),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await QuizRaffleService.castVote(
        quizId: _id,
        choiceIndex: index,
        quiz: widget.quiz,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponse enregistrée. On attend le tirage.')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'permission-denied'
          ? 'Vote refusé — le chrono est peut-être terminé.'
          : 'Erreur : ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _clock(DateTime? ends) {
    if (ends == null) return '--:--';
    var s = ends.difference(_now).inSeconds;
    if (s < 0) s = 0;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final question = QuizRaffleService.questionOf(widget.quiz);
    final choices = QuizRaffleService.choicesOf(widget.quiz);
    final open = QuizRaffleService.isOpen(widget.quiz, _now);
    final drawn = QuizRaffleService.isDrawn(widget.quiz);
    final ends = QuizRaffleService.endsAtOf(widget.quiz);
    final waitingDraw =
        QuizRaffleService.statusOf(widget.quiz) == 'open' && !open;

    return DecoratedBox(
      decoration: TvTheme.paper(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  QuizRaffleService.titleOf(widget.quiz).toUpperCase(),
                  style: TvType.kicker,
                ),
                const Spacer(),
                if (open || waitingDraw)
                  Text(
                    waitingDraw ? 'TIRAGE' : _clock(ends),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: TvTheme.green,
                    ),
                  ),
              ],
            ),
            if (question.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(question, style: TvType.title),
            ],
            const SizedBox(height: 14),
            if (drawn)
              _DrawnBody(quiz: widget.quiz, quizId: _id)
            else ...[
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseAuth.instance.currentUser == null
                    ? null
                    : QuizRaffleService.votesCol(_id)
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots(),
                builder: (context, voteSnap) {
                  final myIndex = (voteSnap.data?.data()?['choiceIndex'] as num?)
                      ?.toInt();
                  final voted = myIndex != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < choices.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _ChoiceTile(
                          label: choices[i],
                          selected: myIndex == i,
                          enabled: open && !_sending && !voted,
                          onTap: () => _vote(i),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        waitingDraw
                            ? 'Chrono terminé — tirage en cours…'
                            : voted
                                ? 'Ton choix est enregistré. On attend la fin du chrono.'
                                : open
                                    ? 'Un vote, un tirage parmi ceux qui ont la bonne réponse.'
                                    : 'Le quiz n’accepte plus de réponses.',
                        style: TvType.caption,
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawnBody extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final String quizId;

  const _DrawnBody({required this.quiz, required this.quizId});

  @override
  Widget build(BuildContext context) {
    final correct = QuizRaffleService.correctLabelOf(quiz);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          correct.isEmpty ? 'Bonne réponse révélée.' : 'Bonne réponse : $correct',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: TvTheme.ink,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        QuizRaffleTombolaReveal(
          key: ValueKey(
            'fan-tombola-$quizId-${QuizRaffleService.playNonceOf(quiz)}',
          ),
          winnerUid: QuizRaffleService.winnerUidOf(quiz),
          winnerName: QuizRaffleService.winnerNameOf(quiz),
          eligibleNames: QuizRaffleService.eligibleNamesOf(quiz),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TvTheme.surfaceMuted : TvTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TvTheme.paperRadius),
        side: BorderSide(
          color: selected ? TvTheme.green : TvTheme.hairline,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(TvTheme.paperRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: enabled || selected ? TvTheme.text : TvTheme.textSoft,
            ),
          ),
        ),
      ),
    );
  }
}
