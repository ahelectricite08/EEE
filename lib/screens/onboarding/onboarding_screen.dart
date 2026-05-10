import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kGold = Color(0xFFC8A436);
const _kBg = Color(0xFF0D0D0D);
const _kRed = Color(0xFFBA203C);

// Clé SharedPreferences pour savoir si l'onboarding a déjà été vu
const _kOnboardingDoneKey = 'onboarding_done_v1';

Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDoneKey) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.sports_soccer_rounded,
      tag: 'BIENVENUE',
      title: 'L\'app\nDVCR',
      body:
          'Toute l\'actualité du CS Sedan Ardennes, les matchs, le live, les pronos et la communauté — en un seul endroit.',
      accent: _kGold,
    ),
    _Slide(
      icon: Icons.live_tv_rounded,
      tag: 'DIRECT & ACTUS',
      title: 'Le club\nen direct',
      body:
          'Suis le match en direct avec les stats live, regarde les replays DVCR TV et lis les articles de la rédaction.',
      accent: _kRed,
    ),
    _Slide(
      icon: Icons.people_rounded,
      tag: 'COMMUNAUTÉ',
      title: 'Rejoins la\ncommunauté DVCR',
      body:
          'Discute dans le chat, ajoute des amis, suis le club au quotidien et fais partie de la communauté DVCR.',
      accent: Color(0xFF2196F3),
    ),
  ];

  void _next() {
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await markOnboardingDone();
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Background subtile
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // Pages
          PageView.builder(
            controller: _ctrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
          ),

          // Bas : dots + bouton
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _page == i ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _page == i
                                ? _slides[_page].accent
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bouton principal
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isLast ? _kGold : _slides[_page].accent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            isLast ? 'COMMENCER' : 'SUIVANT',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Skip
                    if (!isLast)
                      GestureDetector(
                        onTap: _finish,
                        child: Text(
                          'Passer',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String tag;
  final String title;
  final String body;
  final Color accent;

  const _Slide({
    required this.icon,
    required this.tag,
    required this.title,
    required this.body,
    required this.accent,
  });
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône dans un cercle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: slide.accent.withAlpha(22),
                shape: BoxShape.circle,
                border: Border.all(color: slide.accent.withAlpha(80), width: 1.5),
              ),
              child: Icon(slide.icon, size: 32, color: slide.accent),
            ),
            const SizedBox(height: 28),
            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: slide.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: slide.accent.withAlpha(70)),
              ),
              child: Text(
                slide.tag,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: slide.accent,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Titre
            Text(
              slide.title,
              style: GoogleFonts.barlowCondensed(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 0.95,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            // Corps
            Text(
              slide.body,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white60,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille de fond subtile
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(6)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
