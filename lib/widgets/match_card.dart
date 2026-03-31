import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match_model.dart';

const _kRed    = Color(0xFFBA203C);
const _kGreen  = Color(0xFF0A4438);
const _kBg     = Color(0xFF0D0D0D);
const _kCard   = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kText   = Color(0xFFFFFFFF);
const _kSub    = Color(0xFF888888);

// ── Match card style OL Play ──────────────────────────────────────────────────
class MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  final VoidCallback? onReplay;
  final VoidCallback? onAddReplay;
  final bool greenHeader;
  final bool showStats;
  final bool isAdmin;
  final Widget? footerOverride;

  const MatchCard({super.key, required this.match, this.onTap, this.onReplay, this.onAddReplay, this.greenHeader = true, this.showStats = false, this.isAdmin = false, this.footerOverride});

  static bool _isSedanMatch(MatchModel m) {
    final t1 = m.team1.toUpperCase();
    final t2 = m.team2.toUpperCase();
    return t1.contains('SEDAN') || t1.contains('CSSA') ||
           t2.contains('SEDAN') || t2.contains('CSSA');
  }

  static bool _hasFooter(MatchModel m) =>
      _isSedanMatch(m) &&
      (m.status == MatchStatus.finished || m.status == MatchStatus.upcoming);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Column(
          children: [
            // ── Top : compétition + date ──────────────────────────────────
            _CardTop(match: match, green: greenHeader),
            // ── Corps : équipes + score (+ footer intégré si fourni) ─────
            _CardBody(
              match: match,
              showStats: showStats,
              bottomBar: footerOverride,
            ),
            // ── Footer résultat ou détail match (non intégré) ────────────
            if (footerOverride == null && match.status == MatchStatus.finished && _isSedanMatch(match))
              _CardFooter(match: match, onReplay: onReplay, onAddReplay: onAddReplay, isAdmin: isAdmin)
            else if (footerOverride == null && match.status == MatchStatus.upcoming && _isSedanMatch(match))
              _DetailMatchFooter(onTap: onTap),
          ],
        ),
      ),
    );
  }
}

// ── Card complète (top + body fusionnés avec image fond) ─────────────────────
class _CardTop extends StatelessWidget {
  final MatchModel match;
  final bool green;
  const _CardTop({required this.match, this.green = false});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CardBody extends StatelessWidget {
  final MatchModel match;
  final bool showStats;
  final Widget? bottomBar;
  const _CardBody({required this.match, this.showStats = false, this.bottomBar});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = match.status == MatchStatus.upcoming;
    final isLive     = match.status == MatchStatus.live;
    final days   = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
    final months = ['jan','fév','mar','avr','mai','juin','juil','aoû','sep','oct','nov','déc'];
    final d = match.date;
    final dateStr = '${days[d.weekday-1].toUpperCase()} ${d.day} ${months[d.month-1].toUpperCase()}';

    return ClipRRect(
      borderRadius: bottomBar != null
          ? BorderRadius.circular(12)
          : const BorderRadius.vertical(top: Radius.circular(12)),
      child: Stack(
        children: [
          // Fond image terrain JOURDEMATCH
          Positioned.fill(
            child: Image.asset(
              'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A4438), Color(0xFF0D5548)],
                  ),
                ),
              ),
            ),
          ),
          // Overlay légère sur les bords seulement
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(160),
                    Colors.black.withAlpha(60),
                    Colors.black.withAlpha(160),
                  ],
                ),
              ),
            ),
          ),

          // Barre prono intégrée à la photo
          if (bottomBar != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ligne séparatrice avec dégradé
                  Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.white24, Colors.transparent],
                      ),
                    ),
                  ),
                  // Fond frosted glass
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: Colors.black.withAlpha(140),
                        child: bottomBar!,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Contenu
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomBar != null ? 56 : 16),
            child: Column(
              children: [
                // ── Ligne 1 : badge compétition + date ──────────────────
                Row(
                  children: [
                    // Badge pill compétition avec flou
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white38, width: 1),
                          ),
                          child: Text(
                            match.competition,
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (match.status == MatchStatus.live)
                      _LiveChip()
                    else
                      Text(dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Ligne 2 : équipes + score ────────────────────────────
                Row(
                  children: [
                    // Équipe 1
                    Expanded(child: _TeamCol(
                      name: match.team1, logo: match.logo1,
                      rank: showStats ? (match.rank1 ?? '?') : null,
                      form: showStats ? (match.form1 ?? '-----') : null,
                      align: CrossAxisAlignment.start,
                    )),

                    // Centre
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          isUpcoming
                              ? _UpcomingCenter(date: match.date)
                              : _ScoreCenter(
                                  s1: match.score1 ?? 0,
                                  s2: match.score2 ?? 0,
                                  isLive: isLive),
                        ],
                      ),
                    ),

                    // Équipe 2
                    Expanded(child: _TeamCol(
                      name: match.team2, logo: match.logo2,
                      rank: showStats ? (match.rank2 ?? '?') : null,
                      form: showStats ? (match.form2 ?? '-----') : null,
                      align: CrossAxisAlignment.end,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Colonne équipe ────────────────────────────────────────────────────────────
class _TeamCol extends StatelessWidget {
  final String name;
  final String? logo;
  final String? rank;
  final String? form;
  final CrossAxisAlignment align;
  const _TeamCol({
    required this.name, this.logo,
    this.rank, this.form,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = align == CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6)],
          ),
          child: logo != null
              ? Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.network(logo!, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _initials()))
              : _initials(),
        ),
        const SizedBox(height: 8),
        // Rang
        if (rank != null)
          Text(
            _ordinal(rank!),
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        const SizedBox(height: 4),
        // Forme
        if (form != null)
          _FormRow(form: form!, reverse: !isLeft),
        const SizedBox(height: 4),
        // Nom
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 0.2,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
          textAlign: isLeft ? TextAlign.left : TextAlign.right,
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _ordinal(String r) {
    final n = int.tryParse(r);
    if (n == null) return r;
    return n == 1 ? '1ER' : '${n}ÈME';
  }

  Widget _initials() {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, name.length.clamp(0, 2));
    return Center(
      child: Text(initials.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white54)),
    );
  }
}

// ── Forme récente ─────────────────────────────────────────────────────────────
class _FormRow extends StatelessWidget {
  final String form;
  final bool reverse;
  const _FormRow({required this.form, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    var letters = form.toUpperCase().characters.take(5).toList();
    if (reverse) letters = letters.reversed.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: letters.map((l) {
        final color = l == 'W' ? const Color(0xFF4CAF50)
                    : l == 'L' ? _kRed
                    : const Color(0xFFFFB300);
        return Container(
          width: 14, height: 14,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(color: color.withAlpha(200), shape: BoxShape.circle),
          child: Center(
            child: Text(l,
              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        );
      }).toList(),
    );
  }
}

// ── Score centre (OL Play : grands chiffres + point séparateur) ───────────────
class _ScoreCenter extends StatelessWidget {
  final int s1, s2;
  final bool isLive;
  const _ScoreCenter({required this.s1, required this.s2, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    final numStyle = GoogleFonts.inter(
      fontSize: 38, fontWeight: FontWeight.w700,
      color: isLive ? _kRed : Colors.white,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$s1', style: numStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('·',
            style: GoogleFonts.inter(
              fontSize: 28, fontWeight: FontWeight.w700,
              color: isLive ? _kRed.withAlpha(180) : Colors.white24)),
        ),
        Text('$s2', style: numStyle),
      ],
    );
  }
}

// ── Centre à venir ────────────────────────────────────────────────────────────
class _UpcomingCenter extends StatelessWidget {
  final DateTime date;
  const _UpcomingCenter({required this.date});

  @override
  Widget build(BuildContext context) {
    final diff = date.difference(DateTime.now());
    final String countdown;
    if (diff.inMinutes < 60)       countdown = '${diff.inMinutes} min';
    else if (diff.inHours < 24)    countdown = '${diff.inHours}h';
    else if (diff.inDays == 1)     countdown = 'Demain';
    else                           countdown = '${diff.inDays}j';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(180),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC8A436).withAlpha(180), width: 1.5),
          ),
          child: Text(
            '${date.hour.toString().padLeft(2,'0')}h${date.minute.toString().padLeft(2,'0')}',
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: const Color(0xFFC8A436), height: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(countdown,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.white70)),
        ),
      ],
    );
  }
}

// ── Footer "DETAIL MATCH" pour matchs à venir ────────────────────────────────
class _DetailMatchFooter extends StatelessWidget {
  final VoidCallback? onTap;
  const _DetailMatchFooter({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/Copie de JOUR DE MATCH.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withAlpha(100)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text('DETAIL MATCH',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer résultat ───────────────────────────────────────────────────────────
class _CardFooter extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onReplay;
  final VoidCallback? onAddReplay;
  final bool isAdmin;
  const _CardFooter({required this.match, this.onReplay, this.onAddReplay, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final cssaIsT1  = match.team1.toUpperCase().contains('CSSA') ||
                      match.team1.toUpperCase().contains('SEDAN');
    final cssaScore = cssaIsT1 ? (match.score1 ?? 0) : (match.score2 ?? 0);
    final oppScore  = cssaIsT1 ? (match.score2 ?? 0) : (match.score1 ?? 0);

    final Color resultColor;
    final String resultLabel;
    final IconData resultIcon;
    if (cssaScore > oppScore) {
      resultColor = const Color(0xFF4CAF50);
      resultLabel = 'VICTOIRE';
      resultIcon  = Icons.emoji_events_rounded;
    } else if (cssaScore == oppScore) {
      resultColor = const Color(0xFFC8A436);
      resultLabel = 'MATCH NUL';
      resultIcon  = Icons.remove_rounded;
    } else {
      resultColor = const Color(0xFFE53935);
      resultLabel = 'DÉFAITE';
      resultIcon  = Icons.close_rounded;
    }

    final hasVideo = match.replayVideoId != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Stack(
        children: [
          // Texture fond
          Positioned.fill(
            child: Image.asset(
              'assets/images/Copie de JOUR DE MATCH.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withAlpha(160)),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                // Badge résultat amélioré
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: resultColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: resultColor.withAlpha(180), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(resultIcon, color: resultColor, size: 13),
                      const SizedBox(width: 5),
                      Text(resultLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: resultColor, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const Spacer(),
                // Bouton vidéo
                if (hasVideo)
                  GestureDetector(
                    onTap: onReplay,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8A436).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFC8A436), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                            color: Color(0xFFC8A436), size: 16),
                          const SizedBox(width: 5),
                          Text('VOIR LE MATCH',
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFFC8A436), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  )
                else if (isAdmin)
                  GestureDetector(
                    onTap: onAddReplay,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white54, size: 14),
                          const SizedBox(width: 5),
                          Text('AJOUTER VIDÉO',
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: Colors.white54, letterSpacing: 0.5)),
                        ],
                      ),
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

// ── Competition badge ─────────────────────────────────────────────────────────
class _CompBadge extends StatelessWidget {
  final String name;
  const _CompBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase();
    final Color dot;
    final String label;
    if (lower.contains('coupe')) {
      dot = _kRed; label = 'Coupe';
    } else if (lower.contains('ligue') || lower.contains('national')) {
      dot = const Color(0xFF7986CB); label = 'National';
    } else {
      dot = const Color(0xFF4CAF50); label = 'Régional 1';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: _kSub)),
    );
  }
}

// ── Live chip ─────────────────────────────────────────────────────────────────
class _LiveChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kRed, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5,
            decoration: const BoxDecoration(
              color: _kText, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('EN DIRECT',
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1.5, color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Date group header ─────────────────────────────────────────────────────────
class MatchDateHeader extends StatelessWidget {
  final DateTime date;
  const MatchDateHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final days   = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    final months = ['jan','fév','mar','avr','mai','juin','juil','aoû','sep','oct','nov','déc'];
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final day    = DateTime(date.year, date.month, date.day);
    final diff   = day.difference(today).inDays;

    final String label;
    if (diff == 0)       label = 'AUJOURD\'HUI';
    else if (diff == 1)  label = 'DEMAIN';
    else if (diff == -1) label = 'HIER';
    else label = '${days[date.weekday-1]} ${date.day} ${months[date.month-1]}'.toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Row(
        children: [
          Container(width: 3, height: 14,
            decoration: BoxDecoration(
              color: _kGreen, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

// ── Vagues vertes/rouges ──────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Vague blanche transparente en bas
    final paint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.55);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.25,
      size.width, size.height * 0.55,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Deuxième vague décalée
    final paint2 = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.quadraticBezierTo(
      size.width * 0.5, size.height * 0.45,
      size.width, size.height * 0.7,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_WavePainter old) => false;
}
