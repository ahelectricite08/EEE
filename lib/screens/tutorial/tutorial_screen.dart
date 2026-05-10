import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTutorialDoneKey = 'tutorial_done_v1';
const _kGold = Color(0xFFC8A436);
const _kBg = Color(0xFFF5F2E9);
const _kMuted = Color(0xFF5C6560);
const _kGreen = Color(0xFF0A4438);
const _kDotInactive = Color(0xFFE5E1D6);

Future<bool> isTutorialDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kTutorialDoneKey) ?? false;
}

Future<void> markTutorialDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTutorialDoneKey, true);
}

// ── Nav items (mirrors main.dart tabs) ────────────────────────────────────────
const _kNavItems = [
  (Icons.home_rounded, 'Accueil'),
  (Icons.play_circle_rounded, 'DVCR TV'),
  (Icons.sports_soccer_rounded, 'Matchs'),
  (Icons.newspaper_rounded, 'Actus'),
  (Icons.public_rounded, 'CdM 2026'),
  (Icons.chat_bubble_rounded, 'Chat'),
];

// ── Step data ─────────────────────────────────────────────────────────────────
class _Step {
  final String tag;
  final String title;
  final String body;
  final Color accent;
  final int tabIndex;
  const _Step({
    required this.tag,
    required this.title,
    required this.body,
    required this.accent,
    this.tabIndex = -1,
  });
}

const _kSteps = [
  _Step(
    tag: 'ACCUEIL',
    title: 'Ton fil\nperso',
    body: 'Prochain match, dernières actus, vidéos DVCR TV — tout en un coup d\'œil.',
    accent: _kGold,
    tabIndex: 0,
  ),
  _Step(
    tag: 'MATCHS',
    title: 'Tous les\nmatchs',
    body: 'Calendrier, résultats, compositions et stats détaillées de chaque rencontre.',
    accent: Color(0xFF4CAF50),
    tabIndex: 2,
  ),
  _Step(
    tag: 'CdM 2026',
    title: 'Pronostique la\nCoupe du Monde',
    body: 'Monte au classement et gagne un ballon officiel de la Coupe du Monde 2026.',
    accent: Color(0xFFE53935),
    tabIndex: 4,
  ),
  _Step(
    tag: 'COMMUNAUTÉ',
    title: 'Rejoins\nla tribune',
    body: 'Le chat en direct avec les autres supporters. Réagis et vis les matchs ensemble.',
    accent: Color(0xFF2196F3),
    tabIndex: 5,
  ),
  _Step(
    tag: 'DVCR TV',
    title: 'Revois\ntout',
    body: 'Résumés, jour de match, émissions et podcasts — toute la chaîne DVCR dans l\'appli.',
    accent: Color(0xFFE53935),
    tabIndex: 1,
  ),
];

// ── Widget principal ──────────────────────────────────────────────────────────
class TutorialScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const TutorialScreen({super.key, this.onDone});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  int _step = 0;

  late final AnimationController _textAnim;
  late final AnimationController _phoneAnim;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _phoneScale;
  late Animation<double> _phoneFade;

  @override
  void initState() {
    super.initState();
    _textAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _phoneAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _buildAnims();
    _textAnim.forward();
    _phoneAnim.forward();
  }

  void _buildAnims() {
    _textFade = CurvedAnimation(parent: _textAnim, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textAnim, curve: Curves.easeOut));
    _phoneScale = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _phoneAnim, curve: Curves.easeOutBack));
    _phoneFade = CurvedAnimation(parent: _phoneAnim, curve: Curves.easeOut);
  }

  Future<void> _next() async {
    if (_step < _kSteps.length - 1) {
      await Future.wait([_textAnim.reverse(), _phoneAnim.reverse()]);
      setState(() => _step++);
      _textAnim.forward();
      _phoneAnim.forward();
    } else {
      await markTutorialDone();
      _finishTutorial();
    }
  }

  Future<void> _skip() async {
    await markTutorialDone();
    _finishTutorial();
  }

  void _finishTutorial() {
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _textAnim.dispose();
    _phoneAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _kSteps[_step];
    final isLast = _step == _kSteps.length - 1;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kGold.withAlpha(80)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('TUTO',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _kGold,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(width: 10),
                  Text('${_step + 1} / ${_kSteps.length}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _kMuted,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text('Passer',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _kMuted,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),

            // ── Dots ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(_kSteps.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _step ? 24 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _step ? s.accent : _kDotInactive,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // ── Phone mockup (animé) ─────────────────────────────────────────
            Expanded(
              child: Center(
                child: ScaleTransition(
                  scale: _phoneScale,
                  child: FadeTransition(
                    opacity: _phoneFade,
                    child: _PhoneMockup(step: _step, accent: s.accent),
                  ),
                ),
              ),
            ),

            // ── Texte (animé) ────────────────────────────────────────────────
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: s.accent.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: s.accent.withAlpha(60)),
                        ),
                        child: Text(s.tag,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: s.accent,
                                letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 8),
                      Text(s.title,
                          style: GoogleFonts.barlowCondensed(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: _kGreen,
                              height: 0.95)),
                      const SizedBox(height: 8),
                      Text(s.body,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _kMuted,
                              height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Bouton ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: GestureDetector(
                onTap: _next,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: isLast ? _kGold : s.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isLast ? 'C\'est parti !' : 'Suivant',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phone frame ───────────────────────────────────────────────────────────────
class _PhoneMockup extends StatelessWidget {
  final int step;
  final Color accent;
  const _PhoneMockup({required this.step, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      height: 355,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withAlpha(130), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withAlpha(50), blurRadius: 24, spreadRadius: 1),
          BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Column(
          children: [
            // Status bar
            Container(
              height: 20,
              color: const Color(0xFF080808),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Text('11:10',
                      style: GoogleFonts.inter(
                          fontSize: 7.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.signal_cellular_alt,
                      size: 8, color: Colors.white60),
                  const SizedBox(width: 2),
                  Icon(Icons.wifi, size: 8, color: Colors.white60),
                  const SizedBox(width: 2),
                  Icon(Icons.battery_full, size: 8, color: Colors.white60),
                ],
              ),
            ),
            // Screen content
            Expanded(child: _content()),
            // Nav bar
            _MockNavBar(activeIndex: _kSteps[step].tabIndex, accent: accent),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    switch (step) {
      case 0:
        return const _MockAccueil();
      case 1:
        return const _MockMatchs();
      case 2:
        return _MockCdm(accent: accent);
      case 3:
        return const _MockChat();
      case 4:
        return const _MockDvcrTv();
      default:
        return const SizedBox();
    }
  }
}

// ── Mock nav bar ──────────────────────────────────────────────────────────────
class _MockNavBar extends StatelessWidget {
  final int activeIndex;
  final Color accent;
  const _MockNavBar({required this.activeIndex, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF141414),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_kNavItems.length, (i) {
          final active = i == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: active ? accent.withAlpha(25) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_kNavItems[i].$1,
                    size: 15, color: active ? accent : Colors.white24),
                const SizedBox(height: 2),
                Text(_kNavItems[i].$2,
                    style: GoogleFonts.inter(
                        fontSize: 5.5,
                        color: active ? accent : Colors.white24,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Mock Accueil ──────────────────────────────────────────────────────────────
class _MockAccueil extends StatelessWidget {
  const _MockAccueil();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('DVCR',
                style: GoogleFonts.barlowCondensed(
                    fontSize: 12,
                    color: _kGold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const Spacer(),
            Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_rounded,
                    size: 10, color: Colors.white54)),
          ]),
          const SizedBox(height: 8),
          // Match card
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2A1A), Color(0xFF111111)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: [
              Text('PROCHAIN MATCH',
                  style: GoogleFonts.inter(
                      fontSize: 5.5,
                      color: _kGold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const SizedBox(height: 7),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _teamCol('CSSA', const Color(0xFFBA203C)),
                Column(children: [
                  Text('VS',
                      style: GoogleFonts.barlowCondensed(
                          fontSize: 14,
                          color: Colors.white38,
                          fontWeight: FontWeight.w900)),
                  Text('Sam. 26 avr',
                      style: GoogleFonts.inter(
                          fontSize: 5, color: Colors.white38)),
                ]),
                _teamCol('TFC', Colors.blueAccent),
              ]),
            ]),
          ),
          const SizedBox(height: 7),
          Text('ACTUS',
              style: GoogleFonts.inter(
                  fontSize: 6,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          _newsRow('Victoire 2-1 face à Metz !'),
          const SizedBox(height: 4),
          _newsRow('Billetterie : réservez vos places'),
          const SizedBox(height: 7),
          Text('DVCR TV',
              style: GoogleFonts.inter(
                  fontSize: 6,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          Row(children: [
            _videoThumb(const Color(0xFF2D0A0A)),
            const SizedBox(width: 5),
            _videoThumb(const Color(0xFF0A1A2D)),
          ]),
        ],
      ),
    );
  }

  Widget _teamCol(String name, Color color) {
    return Column(children: [
      Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withAlpha(80))),
          child: Center(
              child: Text(name[0],
                  style: GoogleFonts.barlowCondensed(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w900)))),
      const SizedBox(height: 3),
      Text(name,
          style: GoogleFonts.inter(
              fontSize: 6.5, color: Colors.white, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _newsRow(String title) {
    return Row(children: [
      Container(
          width: 2.5,
          height: 22,
          decoration: BoxDecoration(
              color: _kGold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Expanded(
          child: Text(title,
              style: GoogleFonts.inter(
                  fontSize: 6.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _videoThumb(Color bg) {
    return Expanded(
        child: Container(
      height: 38,
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white10)),
      child: const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white54, size: 16)),
    ));
  }
}

// ── Mock Matchs ───────────────────────────────────────────────────────────────
class _MockMatchs extends StatelessWidget {
  const _MockMatchs();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MATCHS',
              style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
          const SizedBox(height: 7),
          Row(children: [
            _chip('Résultats', true),
            const SizedBox(width: 5),
            _chip('À venir', false),
          ]),
          const SizedBox(height: 8),
          _matchRow('CSSA', '2', '1', 'Metz', true),
          const SizedBox(height: 4),
          _matchRow('Lens', '1', '1', 'CSSA', true),
          const SizedBox(height: 4),
          _matchRow('CSSA', '3', '0', 'Troyes', true),
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 1,
              color: Colors.white10,
              margin: const EdgeInsets.only(bottom: 8)),
          Text('À VENIR',
              style: GoogleFonts.inter(
                  fontSize: 5.5,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          _matchRow('CSSA', '', '', 'TFC', false),
          const SizedBox(height: 4),
          _matchRow('Sedan', '', '', 'Nancy', false),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF4CAF50).withAlpha(30)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active
                ? const Color(0xFF4CAF50).withAlpha(80)
                : Colors.white24),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 6.5,
              color: active ? const Color(0xFF4CAF50) : Colors.white38,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _matchRow(
      String t1, String s1, String s2, String t2, bool isResult) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
              child: Text(t1,
                  style: GoogleFonts.inter(
                      fontSize: 7,
                      color: Colors.white,
                      fontWeight: FontWeight.w700))),
          if (isResult)
            Row(children: [
              _scoreBox(s1, const Color(0xFF4CAF50)),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text('-',
                      style: GoogleFonts.inter(
                          fontSize: 7, color: Colors.white38))),
              _scoreBox(s2, Colors.white24),
            ])
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(3)),
              child: Text('VS',
                  style: GoogleFonts.barlowCondensed(
                      fontSize: 7,
                      color: Colors.white54,
                      fontWeight: FontWeight.w700)),
            ),
          Expanded(
              child: Text(t2,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 7,
                      color: Colors.white,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _scoreBox(String score, Color color) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
          color: color.withAlpha(50), borderRadius: BorderRadius.circular(3)),
      alignment: Alignment.center,
      child: Text(score,
          style: GoogleFonts.barlowCondensed(
              fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

// ── Mock CdM 2026 ─────────────────────────────────────────────────────────────
class _MockCdm extends StatelessWidget {
  final Color accent;
  const _MockCdm({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Banner CdM
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B5E20), Color(0xFF0A3010)]),
          ),
          child: Column(children: [
            Text('⚽  COUPE DU MONDE',
                style: GoogleFonts.barlowCondensed(
                    fontSize: 9,
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            Text('2026',
                style: GoogleFonts.barlowCondensed(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.0)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: accent.withAlpha(40),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: accent.withAlpha(100))),
              child: Text('PRONOSTIQUER',
                  style: GoogleFonts.inter(
                      fontSize: 7,
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          ]),
        ),
        // Matches
        Expanded(
          child: Container(
            color: const Color(0xFF0D0D0D),
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PHASE DE GROUPES',
                    style: GoogleFonts.inter(
                        fontSize: 6,
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                _cdmRow('🇫🇷', 'France', '🇧🇷', 'Brésil'),
                const SizedBox(height: 4),
                _cdmRow('🇦🇷', 'Argentine', '🇩🇪', 'Allemagne'),
                const SizedBox(height: 4),
                _cdmRow('🇪🇸', 'Espagne', '🇵🇹', 'Portugal'),
                const SizedBox(height: 6),
                // Classement mini
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: accent.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withAlpha(50))),
                  child: Row(children: [
                    Icon(Icons.emoji_events_rounded,
                        color: accent, size: 12),
                    const SizedBox(width: 5),
                    Text('🥇 Ballon officiel CdM 2026 à gagner',
                        style: GoogleFonts.inter(
                            fontSize: 6,
                            color: accent,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cdmRow(String f1, String t1, String f2, String t2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Text('$f1 $t1',
              style: GoogleFonts.inter(
                  fontSize: 6.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFE53935).withAlpha(30),
                borderRadius: BorderRadius.circular(3)),
            child: Text('PRONO',
                style: GoogleFonts.inter(
                    fontSize: 5.5,
                    color: const Color(0xFFE53935),
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('$t2 $f2',
              style: GoogleFonts.inter(
                  fontSize: 6.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Mock Chat ─────────────────────────────────────────────────────────────────
class _MockChat extends StatelessWidget {
  const _MockChat();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.all(9),
      child: Column(
        children: [
          Row(children: [
            Text('TRIBUNE',
                style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withAlpha(30),
                  borderRadius: BorderRadius.circular(5),
                  border:
                      Border.all(color: const Color(0xFF2196F3).withAlpha(80))),
              child: Row(children: [
                const Icon(Icons.circle, size: 5, color: Color(0xFF4CAF50)),
                const SizedBox(width: 3),
                Text('247 en ligne',
                    style: GoogleFonts.inter(
                        fontSize: 5.5,
                        color: const Color(0xFF2196F3),
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          _bubble('🔥 Incroyable ce but de Mateo !!', false,
              const Color(0xFF2196F3)),
          const SizedBox(height: 4),
          _bubble('ALLEZ SEDAN ON VA LES AVOIR 💪⚽', false,
              const Color(0xFF2196F3)),
          const SizedBox(height: 4),
          _bubble('On est les meilleurs ! 🔴⚫', true,
              const Color(0xFF2196F3)),
          const SizedBox(height: 4),
          _bubble('2-0 et c\'est plié les gars 🎉🎉', false,
              const Color(0xFF2196F3)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10)),
            child: Row(children: [
              Expanded(
                  child: Text('Ton message...',
                      style: GoogleFonts.inter(
                          fontSize: 7, color: Colors.white24))),
              const Icon(Icons.send_rounded,
                  size: 11, color: Color(0xFF2196F3)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isMine, Color accent) {
    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 130),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isMine
              ? accent.withAlpha(45)
              : const Color(0xFF222222),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(isMine ? 10 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 10),
          ),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 6.5, color: Colors.white, height: 1.3)),
      ),
    );
  }
}

// ── Mock DVCR TV ──────────────────────────────────────────────────────────────
class _MockDvcrTv extends StatelessWidget {
  const _MockDvcrTv();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('DVCR',
                style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w900)),
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(3)),
              child: Text('TV',
                  style: GoogleFonts.barlowCondensed(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('À LA UNE',
              style: GoogleFonts.inter(
                  fontSize: 6,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          // Featured
          Container(
            width: double.infinity,
            height: 78,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3D0B0B), Color(0xFF1A0505)]),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: const Color(0xFFBA203C).withAlpha(60)),
            ),
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Opacity(
                  opacity: 0.4,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xFF1A0505)]),
                    ),
                  ),
                ),
              ),
              const Center(
                  child: Icon(Icons.play_circle_rounded,
                      color: Colors.white70, size: 30)),
              Positioned(
                bottom: 7,
                left: 8,
                right: 8,
                child: Text('Résumé : CSSA 2-1 FC Metz — J32',
                    style: GoogleFonts.inter(
                        fontSize: 7,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('VIDÉOS',
              style: GoogleFonts.inter(
                  fontSize: 6,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          _videoRow('Jour de match : la prépa du groupe', '12:34',
              const Color(0xFF1A1A2E)),
          const SizedBox(height: 4),
          _videoRow('Émission du dimanche soir', '28:12',
              const Color(0xFF1E1A10)),
          const SizedBox(height: 4),
          _videoRow('Interview : Mateo après le match', '4:20',
              const Color(0xFF1A1A1A)),
        ],
      ),
    );
  }

  Widget _videoRow(String title, String dur, Color thumbColor) {
    return Row(children: [
      Container(
        width: 50,
        height: 32,
        decoration: BoxDecoration(
            color: thumbColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white10)),
        child: const Center(
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white54, size: 15)),
      ),
      const SizedBox(width: 7),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 6.5,
                color: Colors.white,
                fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        Text(dur,
            style: GoogleFonts.inter(
                fontSize: 5.5, color: Colors.white38)),
      ])),
    ]);
  }
}
