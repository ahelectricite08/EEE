import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/dvcr_share_service.dart';
import '../models/match_model.dart';
import '../services/favorites_service.dart';
import '../utils/share_helper.dart';
import 'dvcr_reveal.dart';

Stream<String?> _watchStadiumUrl(String teamName) => FirebaseFirestore.instance
    .collection('teams')
    .where('name', isEqualTo: teamName)
    .limit(1)
    .snapshots()
    .map((s) {
      if (s.docs.isEmpty) return null;
      final url = (s.docs.first.data()['stadiumImageUrl'] as String?)?.trim();
      return (url == null || url.isEmpty) ? null : url;
    });

const _kRed = Color(0xFFBA203C);
const _kGreen = Color(0xFF0A4438);
const _kGreenBright = Color(0xFF1E6B56);
const _kCard = Color(0xFF1C1C1C);
const _kBorder = Color(0xFF333333);

/// Rouge direct plus posé (bordures / accents), sans effet néon.
const _kLiveSoft = Color(0xFFC94156);

const _kHomePaper = Color(0xFFFDFBF7);
const _kHomeInk = Color(0xFF173C31);
const _kHomeMuted = Color(0xFF5C6862);

enum MatchCardSurface {
  /// Fond sombre + photo (listes matchs, détail…).
  stadium,
  /// Carte « papier » sur fond clair (accueil uniquement).
  homeEditorial,
}

Color _statusAccent(MatchStatus status) {
  switch (status) {
    case MatchStatus.live:
      return _kLiveSoft;
    case MatchStatus.finished:
      return const Color(0xFF3A7A52);
    case MatchStatus.upcoming:
      return _kGreenBright;
  }
}

String _statusHeadline(MatchStatus status) {
  switch (status) {
    case MatchStatus.live:
      return 'DIRECT';
    case MatchStatus.finished:
      return 'TERMINE';
    case MatchStatus.upcoming:
      return 'A VENIR';
  }
}

int _fireInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

bool _looselyTeamMatch(String a, String b) {
  final at = a.trim().toUpperCase();
  final bt = b.trim().toUpperCase();
  if (at.isEmpty || bt.isEmpty) return false;
  final aw = at.split(RegExp(r'\s+')).firstWhere((s) => s.isNotEmpty, orElse: () => at);
  final bw = bt.split(RegExp(r'\s+')).firstWhere((s) => s.isNotEmpty, orElse: () => bt);
  return at.contains(bw) || bt.contains(aw);
}

String _liveDocMatchId(Map<String, dynamic> d) {
  final v = d['matchId'];
  if (v == null) return '';
  return v.toString().trim();
}

/// Live courant = même `matchId` **ou** les deux noms d'équipes correspondent
/// (évite 0-0 si `matchId` est faux / ancien type alors que le header lit bien `live/current`).
bool _liveDocIsForMatch(Map<String, dynamic>? d, MatchModel match) {
  if (d == null) return false;
  final id = _liveDocMatchId(d);
  final t1 = (d['team1'] as String? ?? '').toUpperCase();
  final t2 = (d['team2'] as String? ?? '').toUpperCase();
  final m1 = match.team1.toUpperCase();
  final m2 = match.team2.toUpperCase();
  final teamsOrdered =
      _looselyTeamMatch(t1, m1) && _looselyTeamMatch(t2, m2);
  final teamsSwapped =
      _looselyTeamMatch(t1, m2) && _looselyTeamMatch(t2, m1);
  final teamsOk = teamsOrdered || teamsSwapped;
  if (id.isNotEmpty) {
    // Si un matchId est renseigné, seul l’alignement strict évite d’afficher le score
    // live d’un autre match sur la carte « prochain match » (ex. Epernay–Sedan futur).
    return id == match.id;
  }
  return teamsOk;
}

/// `team1` / `scoreHome` = domicile dans `live/current` — aligné sur colonnes match.team1 / team2.
(int, int) _liveScoresForMatchColumns(Map<String, dynamic> d, MatchModel match) {
  final sh = _fireInt(d['scoreHome']);
  final sa = _fireInt(d['scoreAway']);
  final l1 = (d['team1'] as String? ?? '').trim().toUpperCase();
  final l2 = (d['team2'] as String? ?? '').trim().toUpperCase();
  final m1 = match.team1.trim().toUpperCase();
  if (_looselyTeamMatch(l1, m1)) return (sh, sa);
  if (_looselyTeamMatch(l2, m1)) return (sa, sh);
  return (sh, sa);
}

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
  final MatchCardSurface surface;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.onReplay,
    this.onAddReplay,
    this.greenHeader = true,
    this.showStats = false,
    this.isAdmin = false,
    this.footerOverride,
    this.surface = MatchCardSurface.stadium,
  });

  static bool _isSedanMatch(MatchModel m) {
    final t1 = m.team1.toUpperCase();
    final t2 = m.team2.toUpperCase();
    return t1.contains('SEDAN') ||
        t1.contains('CSSA') ||
        t2.contains('SEDAN') ||
        t2.contains('CSSA');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusAccent(match.status);
    final homeLight = surface == MatchCardSurface.homeEditorial;

    final BoxDecoration outerDeco = homeLight
        ? BoxDecoration(
            color: _kHomePaper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: match.status == MatchStatus.live
                  ? _kGreen.withAlpha(100)
                  : const Color(0xFFD8D2C4),
              width: match.status == MatchStatus.live ? 1.15 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF1A1A1A), statusColor, 0.06)!,
                _kCard,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: match.status == MatchStatus.live
                  ? statusColor.withAlpha(130)
                  : match.status == MatchStatus.upcoming
                  ? _kGreen.withAlpha(55)
                  : _kBorder,
              width: match.status == MatchStatus.live ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(38),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
              if (match.status == MatchStatus.live)
                BoxShadow(
                  color: statusColor.withAlpha(22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                )
              else if (match.status == MatchStatus.finished)
                BoxShadow(
                  color: statusColor.withAlpha(22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          );

    return DVCRReveal(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: homeLight
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(10, 0, 10, 8),
          decoration: outerDeco,
          child: Column(
            children: [
              // ── Top : compétition + date ──────────────────────────────────
              _CardTop(match: match, green: greenHeader),
              // ── Corps : équipes + score (+ footer intégré si fourni) ─────
              _CardBody(
                match: match,
                showStats: showStats,
                bottomBar: footerOverride,
                surface: surface,
              ),
              // ── Footer résultat ou détail match (non intégré) ────────────
              if (footerOverride == null &&
                  match.status == MatchStatus.finished &&
                  _isSedanMatch(match))
                _CardFooter(
                  match: match,
                  onReplay: onReplay,
                  onAddReplay: onAddReplay,
                  isAdmin: isAdmin,
                )
              else if (footerOverride == null &&
                  match.status == MatchStatus.upcoming &&
                  _isSedanMatch(match))
                _DetailMatchFooter(onTap: onTap),
            ],
          ),
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
  final MatchCardSurface surface;

  const _CardBody({
    required this.match,
    this.showStats = false,
    this.bottomBar,
    this.surface = MatchCardSurface.stadium,
  });

  @override
  Widget build(BuildContext context) {
    final light = surface == MatchCardSurface.homeEditorial;
    final upcomingHideScore =
        match.status == MatchStatus.upcoming && !match.earlyPublish;
    final isLive = match.status == MatchStatus.live;
    final statusColor = _statusAccent(match.status);
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    final d = match.date;
    final dateStr =
        '${days[d.weekday - 1].toUpperCase()} ${d.day} ${months[d.month - 1].toUpperCase()}';

    return ClipRRect(
      borderRadius: bottomBar != null
          ? BorderRadius.circular(20)
          : const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          // Fond image terrain (stade domicile ou image par défaut)
          Positioned.fill(
            child:
                match.stadiumImageUrl != null &&
                    match.stadiumImageUrl!.isNotEmpty
                ? Image.network(
                    match.stadiumImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
                      fit: BoxFit.cover,
                    ),
                  )
                : StreamBuilder<String?>(
                    stream: _watchStadiumUrl(match.team1),
                    builder: (context, snap) {
                      final url = snap.data;
                      if (url != null && url.isNotEmpty) {
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return Image.asset(
                        'assets/images/deee5e84-aacd-4f95-9c55-ed6b9e26841d.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0A4438), Color(0xFF0D5548)],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Overlay lisibilité (plus doux sur variante accueil).
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: light
                      ? [
                          _kHomeInk.withAlpha(55),
                          Colors.transparent,
                          _kHomeInk.withAlpha(95),
                        ]
                      : [
                          Colors.black.withAlpha(130),
                          Colors.black.withAlpha(42),
                          Colors.black.withAlpha(120),
                        ],
                ),
              ),
            ),
          ),
          // Accent haut (couleur statut) — pas sur carte accueil + live : évite halo / point rouge.
          if (!(light && isLive))
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withAlpha(light ? 160 : 200),
                        statusColor.withAlpha(light ? 85 : 100),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Barre prono (accueil) : flou + léger voile, ligne de fusion, bandeau clair par-dessus.
          if (bottomBar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: light
                            ? [
                                Colors.white.withAlpha(0),
                                Colors.white.withAlpha(95),
                                Colors.white.withAlpha(175),
                              ]
                            : [
                                Colors.transparent,
                                Colors.black.withAlpha(55),
                                Colors.black.withAlpha(150),
                              ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                light
                                    ? Colors.black.withAlpha(18)
                                    : Colors.white.withAlpha(35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        bottomBar!,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Contenu
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              12,
              14,
              bottomBar != null ? 72 : 16,
            ),
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: light
                                ? (isLive
                                    ? Colors.white.withAlpha(252)
                                    : Colors.white.withAlpha(248))
                                : (isLive
                                    ? statusColor.withAlpha(55)
                                    : Colors.white.withAlpha(40)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: light
                                  ? _kGreen.withAlpha(85)
                                  : (isLive
                                      ? statusColor.withAlpha(150)
                                      : Colors.white38),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            match.competition,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: light ? _kHomeInk : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            child: child,
                          ),
                        );
                      },
                      child: _MatchMetaChip(
                        key: ValueKey('${match.status.name}_$dateStr'),
                        status: match.status,
                        dateLabel: dateStr,
                        lightSurface: light,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ShareBtn(match: match, lightSurface: light),
                    const SizedBox(width: 6),
                    _FavoriteBtn(match: match, lightSurface: light),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Ligne 2 : équipes + score ────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Équipe 1
                    Expanded(
                      child: _TeamCol(
                        name: match.team1,
                        logo: match.logo1,
                        rank: showStats ? (match.rank1 ?? '?') : null,
                        form: showStats ? match.form1 : null,
                        wdl: showStats ? match.wdl1 : null,
                        status: match.status,
                        align: CrossAxisAlignment.start,
                        lightSurface: light,
                      ),
                    ),

                    // Centre (marges serrées pour laisser de l’air aux noms longs)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          upcomingHideScore
                              ? _UpcomingCenter(
                                  date: match.date,
                                  lightSurface: light,
                                )
                              : (isLive || match.score1 != null)
                                  ? isLive
                                      ? _LiveSyncedScoreCenter(
                                          match: match,
                                          lightSurface: light,
                                        )
                                      : _AnimatedScoreCenter(
                                          s1: match.score1 ?? 0,
                                          s2: match.score2 ?? 0,
                                          isLive: false,
                                          lightSurface: light,
                                        )
                                  : _PendingScoreCenter(lightSurface: light),
                          // Sous le score : ruban d’état (sauf accueil live déjà géré, et accueil
                          // terminé — le chip en haut suffit, évite un second « TERMINE » sur la photo).
                          if (!(light &&
                              (isLive || match.status == MatchStatus.finished))) ...[
                            const SizedBox(height: 10),
                            _StateRibbon(
                              status: match.status,
                              color: statusColor,
                              label: _statusHeadline(match.status),
                              lightSurface: light,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Équipe 2
                    Expanded(
                      child: _TeamCol(
                        name: match.team2,
                        logo: match.logo2,
                        rank: showStats ? (match.rank2 ?? '?') : null,
                        form: showStats ? match.form2 : null,
                        wdl: showStats ? match.wdl2 : null,
                        status: match.status,
                        align: CrossAxisAlignment.end,
                        lightSurface: light,
                      ),
                    ),
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
  final String? wdl;
  final MatchStatus status;
  final CrossAxisAlignment align;
  final bool lightSurface;

  const _TeamCol({
    required this.name,
    this.logo,
    this.rank,
    this.form,
    this.wdl,
    required this.status,
    this.align = CrossAxisAlignment.center,
    this.lightSurface = false,
  });

  static const _captionShadows = [
    Shadow(
      color: Color(0xCC000000),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
    Shadow(
      color: Color(0x99000000),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isLeft = align == CrossAxisAlignment.start;
    final ink = Colors.white;
    final captionShadows = lightSurface ? _captionShadows : null;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: lightSurface && status == MatchStatus.live
                  ? Colors.black.withAlpha(35)
                  : _statusAccent(
                      status,
                    ).withAlpha(status == MatchStatus.upcoming ? 50 : 115),
              width: status == MatchStatus.live ? 2 : 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(lightSurface ? 18 : 35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              if (status != MatchStatus.upcoming && !(lightSurface && status == MatchStatus.live))
                BoxShadow(
                  color: _statusAccent(
                    status,
                  ).withAlpha(
                    status == MatchStatus.live ? 40 : 20,
                  ),
                  blurRadius: status == MatchStatus.live ? 8 : 6,
                ),
            ],
          ),
          child: logo != null
              ? Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.network(
                    logo!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _initials(),
                  ),
                )
              : _initials(),
        ),
        const SizedBox(height: 8),
        // Rang
        SizedBox(
          height: 17,
          child: rank == null
              ? const SizedBox.shrink()
              : Text(
                  _ordinal(rank!),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    shadows: captionShadows,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        // Forme
        SizedBox(
          height: 14,
          child: Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: _FormRow(form: form, wdl: wdl, reverse: !isLeft),
          ),
        ),
        const SizedBox(height: 4),
        // Nom
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: 0.2,
            shadows: lightSurface
                ? _captionShadows
                : const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
          textAlign: isLeft ? TextAlign.left : TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _ordinal(String r) {
    final n = int.tryParse(r);
    if (n == null) return r;
    return n == 1 ? '1ER' : '$nÈME';
  }

  Widget _initials() {
    final letterColor = lightSurface ? Colors.white70 : Colors.white54;
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, name.length.clamp(0, 2));
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: letterColor,
        ),
      ),
    );
  }
}

// ── Forme récente ─────────────────────────────────────────────────────────────
class _FormRow extends StatelessWidget {
  final String? form;
  final String? wdl;
  final bool reverse;
  const _FormRow({this.form, this.wdl, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    var letters = _normalizeForm(form ?? '');
    if (letters.isEmpty) letters = _formFromWdl(wdl ?? '');
    if (letters.isEmpty) letters = const ['N', 'N', 'N'];
    if (reverse) letters = letters.reversed.toList();
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: letters.map((l) {
        final color = l == 'V'
            ? const Color(0xFF4CAF50)
            : l == 'D'
            ? _kRed
            : const Color(0xFFFFB300);
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withAlpha(200),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              l,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<String> _normalizeForm(String raw) {
    final compact = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .characters
        .toList();
    final usesFrenchLetters = compact.any((l) => l == 'V' || l == 'N');
    return compact
        .take(5)
        .map((l) {
          if (usesFrenchLetters) {
            if (l == 'V' || l == 'N' || l == 'D') return l;
          } else {
            if (l == 'W') return 'V';
            if (l == 'D') return 'N';
            if (l == 'L') return 'D';
          }
          return l;
        })
        .where((l) => l == 'V' || l == 'N' || l == 'D')
        .toList();
  }

  List<String> _formFromWdl(String raw) {
    final match = RegExp(
      r'(\d+)\s*V\s+(\d+)\s*N\s+(\d+)\s*D',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return const [];
    final wins = int.tryParse(match.group(1) ?? '') ?? 0;
    final draws = int.tryParse(match.group(2) ?? '') ?? 0;
    final losses = int.tryParse(match.group(3) ?? '') ?? 0;
    final letters = <String>[
      ...List.filled(wins.clamp(0, 5), 'V'),
      ...List.filled(draws.clamp(0, 5), 'N'),
      ...List.filled(losses.clamp(0, 5), 'D'),
    ];
    return letters.take(5).toList();
  }
}

/// Score temps réel depuis `live/current` quand le doc correspond à ce match.
class _LiveSyncedScoreCenter extends StatelessWidget {
  final MatchModel match;
  final bool lightSurface;

  const _LiveSyncedScoreCenter({
    required this.match,
    required this.lightSurface,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        var s1 = match.score1 ?? 0;
        var s2 = match.score2 ?? 0;
        if (snap.hasData && snap.data!.exists) {
          final raw = snap.data!.data();
          final d = raw is Map<String, dynamic> ? raw : null;
          if (d != null && _liveDocIsForMatch(d, match)) {
            final aligned = _liveScoresForMatchColumns(d, match);
            s1 = aligned.$1;
            s2 = aligned.$2;
          }
        }
        return _AnimatedScoreCenter(
          s1: s1,
          s2: s2,
          isLive: true,
          lightSurface: lightSurface,
        );
      },
    );
  }
}

// ── Score centre (OL Play : grands chiffres + point séparateur) ───────────────
class _AnimatedScoreCenter extends StatelessWidget {
  final int s1;
  final int s2;
  final bool isLive;
  final bool lightSurface;

  const _AnimatedScoreCenter({
    required this.s1,
    required this.s2,
    this.isLive = false,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final scoreNumStyle = GoogleFonts.inter(
      fontSize: 38,
      fontWeight: FontWeight.w700,
      color: isLive
          ? (lightSurface ? _kHomeInk : Colors.white)
          : (lightSurface ? _kHomeInk : Colors.white),
      height: 1,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLive
            ? (lightSurface
                ? Colors.white.withAlpha(252)
                : _kLiveSoft.withAlpha(88))
            : (lightSurface
                ? Colors.white.withAlpha(230)
                : Colors.black.withAlpha(80)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive
              ? (lightSurface
                  ? const Color(0xFFD0D5D0)
                  : _kLiveSoft.withAlpha(160))
              : (lightSurface ? _kGreen.withAlpha(50) : Colors.white12),
        ),
        boxShadow: [
          if (isLive && !lightSurface)
            BoxShadow(
              color: _kLiveSoft.withAlpha(32),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          if (lightSurface)
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AnimatedScoreDigit(value: s1, style: scoreNumStyle, scoreKey: 's1'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              lightSurface && !isLive ? '–' : '•',
              style: GoogleFonts.inter(
                fontSize: lightSurface && !isLive ? 22 : 28,
                fontWeight: FontWeight.w700,
                color: lightSurface
                    ? (isLive
                        ? _kHomeMuted
                        : const Color(0xFF9AA6A1))
                    : (isLive
                        ? Colors.white.withAlpha(200)
                        : Colors.white24),
              ),
            ),
          ),
          _AnimatedScoreDigit(value: s2, style: scoreNumStyle, scoreKey: 's2'),
        ],
      ),
    );
  }
}

class _PendingScoreCenter extends StatelessWidget {
  final bool lightSurface;

  const _PendingScoreCenter({this.lightSurface = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: lightSurface
            ? Colors.white.withAlpha(230)
            : Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lightSurface ? _kGreen.withAlpha(40) : Colors.white12,
        ),
      ),
      child: Text(
        'Résultat\nprochainement',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: lightSurface ? _kHomeMuted : Colors.white54,
          height: 1.4,
        ),
      ),
    );
  }
}

class _AnimatedScoreDigit extends StatelessWidget {
  final int value;
  final TextStyle style;
  final String scoreKey;

  const _AnimatedScoreDigit({
    required this.value,
    required this.style,
    required this.scoreKey,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text('$value', key: ValueKey('$scoreKey-$value'), style: style),
    );
  }
}

// ── Centre à venir ────────────────────────────────────────────────────────────
class _UpcomingCenter extends StatelessWidget {
  final DateTime date;
  final bool lightSurface;

  const _UpcomingCenter({
    required this.date,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final diff = date.difference(DateTime.now());
    final String countdown;
    if (diff.inMinutes < 60) {
      countdown = '${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      countdown = '${diff.inHours}h';
    } else if (diff.inDays == 1) {
      countdown = 'Demain';
    } else {
      countdown = '${diff.inDays}j';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: lightSurface
                ? Colors.white.withAlpha(245)
                : Colors.black.withAlpha(165),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _kGreenBright.withAlpha(lightSurface ? 170 : 200),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withAlpha(lightSurface ? 22 : 35),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.barlowCondensed(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: lightSurface ? _kHomeInk : const Color(0xFFE8F5F0),
              height: 1,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (!diff.isNegative) ...[
          const SizedBox(height: 6),
          Text(
            countdown,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: lightSurface ? _kHomeMuted : Colors.white70,
              letterSpacing: 0.2,
            ),
          ),
        ],
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
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
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
                child: Text(
                  'Détail du match',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.15,
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

// ── Footer résultat ───────────────────────────────────────────────────────────
class _CardFooter extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onReplay;
  final VoidCallback? onAddReplay;
  final bool isAdmin;
  const _CardFooter({
    required this.match,
    this.onReplay,
    this.onAddReplay,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final cssaIsT1 =
        match.team1.toUpperCase().contains('CSSA') ||
        match.team1.toUpperCase().contains('SEDAN');
    final hasScore = match.score1 != null;
    final cssaScore = hasScore
        ? (cssaIsT1 ? match.score1! : match.score2!)
        : 0;
    final oppScore = hasScore
        ? (cssaIsT1 ? match.score2! : match.score1!)
        : 0;

    final Color resultColor;
    final String resultLabel;
    final IconData resultIcon;
    if (!hasScore) {
      resultColor = const Color(0xFF9E9E9E);
      resultLabel = 'EN ATTENTE';
      resultIcon = Icons.hourglass_empty_rounded;
    } else if (cssaScore > oppScore) {
      resultColor = const Color(0xFF4CAF50);
      resultLabel = 'VICTOIRE';
      resultIcon = Icons.emoji_events_rounded;
    } else if (cssaScore == oppScore) {
      resultColor = const Color(0xFFB8A88A);
      resultLabel = 'MATCH NUL';
      resultIcon = Icons.remove_rounded;
    } else {
      resultColor = const Color(0xFFE53935);
      resultLabel = 'DÉFAITE';
      resultIcon = Icons.close_rounded;
    }

    final hasVideo = match.replayVideoId != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Stack(
        children: [
          // Texture fond
          Positioned.fill(
            child: Image.asset(
              'assets/images/Copie de JOUR DE MATCH.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withAlpha(160))),
          // Contenu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                // Badge résultat amélioré
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: resultColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: resultColor.withAlpha(180),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(resultIcon, color: resultColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        resultLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: resultColor,
                          letterSpacing: 0.5,
                        ),
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreen.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _kGreenBright.withAlpha(220),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: _kGreenBright.withAlpha(255),
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Voir le match',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE8F5F0),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isAdmin)
                  GestureDetector(
                    onTap: onAddReplay,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'AJOUTER VIDÉO',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                              letterSpacing: 0.5,
                            ),
                          ),
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
class _LiveChip extends StatelessWidget {
  final bool lightSurface;

  const _LiveChip({this.lightSurface = false});

  @override
  Widget build(BuildContext context) {
    if (lightSurface) {
      return Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(210),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _kRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Live',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _kLiveSoft.withAlpha(200),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kLiveSoft.withAlpha(240)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'EN DIRECT',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchMetaChip extends StatelessWidget {
  final MatchStatus status;
  final String dateLabel;
  final bool lightSurface;

  const _MatchMetaChip({
    super.key,
    required this.status,
    required this.dateLabel,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MatchStatus.live:
        return _LiveChip(lightSurface: lightSurface);
      case MatchStatus.finished:
        return _StatusChip(
          icon: Icons.check_circle_rounded,
          label: 'TERMINE',
          color: const Color(0xFF3A7A52),
          lightSurface: lightSurface,
        );
      case MatchStatus.upcoming:
        return _StatusChip(
          icon: Icons.schedule_rounded,
          label: dateLabel,
          color: _kGreenBright,
          subtle: true,
          lightSurface: lightSurface,
        );
    }
  }
}

class _StateRibbon extends StatelessWidget {
  final MatchStatus status;
  final Color color;
  final String label;
  final bool lightSurface;

  const _StateRibbon({
    required this.status,
    required this.color,
    required this.label,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status == MatchStatus.upcoming
            ? (lightSurface
                ? Colors.white.withAlpha(240)
                : Colors.black.withAlpha(110))
            : (lightSurface && status == MatchStatus.live
                ? Colors.white.withAlpha(248)
                : color.withAlpha(lightSurface ? 18 : 28)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: status == MatchStatus.upcoming
              ? (lightSurface ? _kGreen.withAlpha(55) : Colors.white24)
              : (lightSurface && status == MatchStatus.live
                  ? _kLiveSoft.withAlpha(160)
                  : color.withAlpha(lightSurface ? 100 : 120)),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: status == MatchStatus.upcoming
              ? (lightSurface ? _kHomeMuted : Colors.white70)
              : (lightSurface && status == MatchStatus.live
                  ? _kLiveSoft
                  : color),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool subtle;
  final bool lightSurface;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.subtle = false,
    this.lightSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = color;
    final Color textColor = lightSurface
        ? (subtle ? _kHomeInk : color)
        : (subtle ? Colors.white : color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: lightSurface
            ? (subtle
                ? Colors.white.withAlpha(245)
                : color.withAlpha(22))
            : (subtle ? Colors.black.withAlpha(130) : color.withAlpha(30)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: lightSurface
              ? (subtle ? color.withAlpha(100) : color.withAlpha(140))
              : (subtle ? color.withAlpha(140) : color.withAlpha(180)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textColor,
            ),
          ),
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
    final days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;

    final String label;
    if (diff == 0) {
      label = 'AUJOURD\'HUI';
    } else if (diff == 1) {
      label = 'DEMAIN';
    } else if (diff == -1) {
      label = 'HIER';
    } else {
      label = '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}'
          .toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton partage ────────────────────────────────────────────────────────────
class _ShareBtn extends StatelessWidget {
  final MatchModel match;
  final bool lightSurface;

  const _ShareBtn({required this.match, this.lightSurface = false});

  @override
  Widget build(BuildContext context) {
    final iconColor = lightSurface
        ? _kHomeInk.withAlpha(140)
        : Colors.white38;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => DvcrShare.share(ShareHelper.matchText(match)),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.share_rounded, color: iconColor, size: 18),
      ),
    );
  }
}

// ── Vagues vertes/rouges ──────────────────────────────────────────────────────
class _FavoriteBtn extends StatelessWidget {
  final MatchModel match;
  final bool lightSurface;

  const _FavoriteBtn({required this.match, this.lightSurface = false});

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser?.uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: FavoritesService.watchIsFavorite(FavoriteType.match, match.id),
      builder: (context, snap) {
        final isFav = snap.data ?? false;
        final outline = lightSurface ? _kHomeInk.withAlpha(120) : Colors.white38;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await FavoritesService.toggle(
              type: FavoriteType.match,
              itemId: match.id,
              title: '${match.team1} vs ${match.team2}',
              subtitle: match.competition,
              routeHint: 'match',
              extra: {
                'team1': match.team1,
                'team2': match.team2,
                'date': match.date.toIso8601String(),
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFav ? const Color(0xFFC9A227) : outline,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}
