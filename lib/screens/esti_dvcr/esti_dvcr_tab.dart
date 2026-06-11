import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/world_cup/tournament_prono_screen.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import 'esti_dvcr_leaderboard.dart';
import 'leagues/esti_dvcr_leagues_panel.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kEstiBg = Color(0xFF062921);
const _kEstiTeal = Color(0xFF0A4438);
const _kEstiRed = Color(0xFFBA203C);
const _kEstiGold = Color(0xFFC8A436);
const _kEstiSurface = Color(0xFF0D3D32);
const _kEstiMuted = Color(0xFF7AADA0);

class EstiDvcrTab extends StatelessWidget {
  final int partnerEncartResetToken;
  const EstiDvcrTab({super.key, this.partnerEncartResetToken = 0});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TournamentService.activeTournamentsStream(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isNotEmpty) {
          final doc = docs.first;
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] as String? ?? 'Esti\'DVCR';
          return _EstiDvcrEmbedded(
            tournamentId: doc.id,
            tournamentName: name,
            partnerEncartResetToken: partnerEncartResetToken,
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const ColoredBox(
            color: _kEstiBg,
            child: Center(
              child: CircularProgressIndicator(color: _kEstiGold),
            ),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .orderBy(FieldPath.documentId)
              .limit(1)
              .snapshots(),
          builder: (context, legacySnap) {
            final legacyDocs = legacySnap.data?.docs ?? [];
            if (legacyDocs.isEmpty) {
              return const _ComingSoonScreen();
            }
            final doc = legacyDocs.first;
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? 'Esti\'DVCR';
            return _EstiDvcrEmbedded(
              tournamentId: doc.id,
              tournamentName: name,
              partnerEncartResetToken: partnerEncartResetToken,
            );
          },
        );
      },
    );
  }
}

// ── Shell avec hero + TabBar ──────────────────────────────────────────────────
class _EstiDvcrEmbedded extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final int partnerEncartResetToken;
  const _EstiDvcrEmbedded({
    required this.tournamentId,
    required this.tournamentName,
    this.partnerEncartResetToken = 0,
  });

  @override
  State<_EstiDvcrEmbedded> createState() => _EstiDvcrEmbeddedState();
}

class _EstiDvcrEmbeddedState extends State<_EstiDvcrEmbedded>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final ValueNotifier<bool> _heroHiddenNotifier = ValueNotifier(false);
  double _scrollAccum = 0;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _heroHiddenNotifier.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _kEstiBg,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification) {
            final delta = n.scrollDelta ?? 0;
            if (delta < 0) {
              _scrollAccum = 0;
              if (_heroHiddenNotifier.value) _heroHiddenNotifier.value = false;
            } else {
              _scrollAccum += delta;
              if (_scrollAccum > 50 && !_heroHiddenNotifier.value) {
                _heroHiddenNotifier.value = true;
              }
            }
          }
          return false;
        },
        child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _heroHiddenNotifier,
            builder: (context, hidden, _) {
              // Quand hidden : on garde topPad de hauteur pour que l'image
              // reste visible derrière l'encoche. ClipRect masque le reste.
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: ClipRect(
                  child: SizedBox(
                    height: hidden ? topPad : null,
                    child: _EstiDvcrHero(
                      topPad: topPad,
                      tournamentId: widget.tournamentId,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            color: _kEstiSurface,
            child: TabBar(
              controller: _tc,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _kEstiRed,
                borderRadius: BorderRadius.circular(0),
                border: const Border(bottom: BorderSide(color: _kEstiRed, width: 3)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              unselectedLabelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0),
              labelColor: Colors.white,
              unselectedLabelColor: _kEstiMuted,
              tabs: const [
                Tab(text: 'PRONOS'),
                Tab(text: 'CLASSEMENT'),
                Tab(text: 'LIGUES'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                TournamentPronoScreen(
                  tournamentId: widget.tournamentId,
                  tournamentName: widget.tournamentName,
                  embedded: true,
                  hideLeaderboard: true,
                  showPartnerModal: true,
                  partnerEncartResetToken: widget.partnerEncartResetToken,
                ),
                EstiDvcrLeaderboard(tournamentId: widget.tournamentId),
                EstiDvcrLeaguesPanel(tournamentId: widget.tournamentId),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}


// ── Hero visuel ───────────────────────────────────────────────────────────────
class _EstiDvcrHero extends StatelessWidget {
  final double topPad;
  final String tournamentId;

  const _EstiDvcrHero({
    required this.topPad,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('esti_dvcr')
          .snapshots(),
      builder: (context, snap) {
        final heroBannerUrl = (snap.data?.data() as Map<String, dynamic>?)?['heroBannerUrl'] as String?;
        final hasImage = heroBannerUrl != null && heroBannerUrl.trim().isNotEmpty;

        return SizedBox(
          height: topPad + 160,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Fond : image ou dégradé ─────────────────────────────
              Positioned.fill(
                child: hasImage
                    ? Image.network(
                        heroBannerUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultGradient(),
                      )
                    : _defaultGradient(),
              ),

              // Overlay sombre si image (pour lisibilité du texte)
              if (hasImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(60),
                          Colors.black.withAlpha(140),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Décorations X (uniquement sans image) ───────────────
              if (!hasImage) ...[
                Positioned(
                  top: topPad - 20,
                  right: -30,
                  child: _RedX(size: 140, opacity: 0.18, angle: 0.15),
                ),
                Positioned(
                  bottom: -10,
                  left: -20,
                  child: _RedX(size: 90, opacity: 0.22, angle: -0.1),
                ),
                Positioned(
                  top: topPad + 30,
                  left: 60,
                  child: _RedX(size: 55, opacity: 0.28, angle: 0.35),
                ),
              ],

              // ── Bouton admin : changer l'image (haut gauche) ───────
              Positioned(
                top: topPad + 8,
                left: 12,
                child: _HeroBannerAdminButton(hasImage: hasImage),
              ),

              // ── Bouton partage (haut droit) ────────────────────────
              Positioned(
                top: topPad + 8,
                right: 12,
                child: _ShareEstiButton(tournamentId: tournamentId),
              ),

              // ── Contenu textuel ────────────────────────────────────
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PRONOS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kEstiRed,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "ESTI'DVCR",
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        height: 0.9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ParticipantsBadge(tournamentId: tournamentId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _defaultGradient() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kEstiTeal, _kEstiBg],
      ),
    ),
  );
}

// Badge "N participants"
class _ParticipantsBadge extends StatelessWidget {
  final String tournamentId;
  const _ParticipantsBadge({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .collection('leaderboard')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.size ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kEstiRed.withAlpha(40),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: _kEstiRed.withAlpha(80)),
          ),
          child: Text(
            '$count participant${count > 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(220),
            ),
          ),
        );
      },
    );
  }
}

// ── Croix rouge géométrique ───────────────────────────────────────────────────
class _RedX extends StatelessWidget {
  final double size;
  final double opacity;
  final double angle;

  const _RedX({
    required this.size,
    required this.opacity,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _XPainter(
            color: _kEstiRed.withAlpha((opacity * 255).round()),
            strokeWidth: size * 0.18,
          ),
        ),
      ),
    );
  }
}

class _XPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _XPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_XPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ── Bouton admin : modifier l'image du hero ───────────────────────────────────
class _HeroBannerAdminButton extends StatefulWidget {
  final bool hasImage;
  const _HeroBannerAdminButton({required this.hasImage});

  @override
  State<_HeroBannerAdminButton> createState() => _HeroBannerAdminButtonState();
}

class _HeroBannerAdminButtonState extends State<_HeroBannerAdminButton> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    UserService.isAdmin().then((v) { if (mounted) setState(() => _isAdmin = v); });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) return const SizedBox.shrink();
    return Material(
      color: Colors.black.withAlpha(80),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showBannerDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.hasImage ? Icons.edit_rounded : Icons.add_photo_alternate_rounded,
                color: Colors.white, size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                widget.hasImage ? 'IMAGE' : 'AJOUTER IMAGE',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBannerDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => const _BannerEditDialog(),
    );
  }
}

// ── Dialog modification image bannière ───────────────────────────────────────
class _BannerEditDialog extends StatefulWidget {
  const _BannerEditDialog();

  @override
  State<_BannerEditDialog> createState() => _BannerEditDialogState();
}

class _BannerEditDialogState extends State<_BannerEditDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  static final _ref = FirebaseFirestore.instance
      .collection('app_config')
      .doc('esti_dvcr');

  @override
  void initState() {
    super.initState();
    _ref.get().then((snap) {
      final url = (snap.data()?['heroBannerUrl'] as String?) ?? '';
      if (mounted) { _ctrl.text = url; setState(() => _loaded = true); }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _ref.set({'heroBannerUrl': _ctrl.text.trim()}, SetOptions(merge: true));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image mise à jour ✓')),
      );
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    await _ref.set({'heroBannerUrl': ''}, SetOptions(merge: true));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image supprimée — fond par défaut restauré')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D3D32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMAGE BANNIÈRE',
              style: GoogleFonts.barlowCondensed(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(
              'Colle l\'URL directe de ton image (Wix, Imgur, etc.)',
              style: GoogleFonts.inter(fontSize: 11, color: _kEstiMuted),
            ),
            const SizedBox(height: 16),

            // Aperçu si URL renseignée
            if (_loaded && _ctrl.text.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _ctrl.text,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _kEstiRed.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('Image non accessible',
                        style: GoogleFonts.inter(fontSize: 12, color: _kEstiRed)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Champ URL
            TextField(
              controller: _ctrl,
              autofocus: !_loaded || _ctrl.text.isEmpty,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: GoogleFonts.inter(color: _kEstiMuted),
                filled: true,
                fillColor: const Color(0xFF062921),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _kEstiMuted.withAlpha(80)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _kEstiMuted.withAlpha(80)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kEstiGold),
                ),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: _kEstiMuted, size: 16),
                        onPressed: () => setState(() => _ctrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Boutons
            Row(children: [
              if (_ctrl.text.isNotEmpty) ...[
                TextButton(
                  onPressed: _saving ? null : _remove,
                  child: Text('SUPPRIMER',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _kEstiRed)),
                ),
                const Spacer(),
              ] else
                const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ANNULER',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kEstiMuted)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEstiGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text('ENREGISTRER',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Bouton partage ESTI'DVCR ─────────────────────────────────────────────────
class _ShareEstiButton extends StatelessWidget {
  final String tournamentId;
  const _ShareEstiButton({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(80),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => DvcrShare.share(
          "Rejoins-moi sur ESTI'DVCR, le jeu de pronos de Drapeau Vert ! 🟢\nFais tes pronos et grimpe au classement !",
          context: context,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ios_share_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text(
                'PARTAGER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coming soon ───────────────────────────────────────────────────────────────
class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _kEstiBg,
      body: Padding(
        padding: EdgeInsets.only(top: topPad),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RedX(size: 80, opacity: 0.6, angle: 0),
              const SizedBox(height: 24),
              Text(
                "ESTI'DVCR",
                style: GoogleFonts.barlowCondensed(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bientôt disponible',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _kEstiMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
