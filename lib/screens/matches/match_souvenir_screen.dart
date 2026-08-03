import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/match_model.dart';
import '../../models/souvenir_branding.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/match_souvenir_branding_service.dart';
import '../../utils/remote_image_url.dart';
import '../../utils/share_helper.dart';
import 'match_detail_palette.dart';

/// Fond officiel du cadre souvenir (portrait, branding DVCR).
const kSouvenirMatchBgAsset = 'assets/images/souvenir_match_bg.png';

/// Résolution de composition (Stories / partage social).
const double kSouvenirCardW = 1080;
const double kSouvenirCardH = 1920;

/// CTA principal — sous le hero score, au-dessus des onglets (si feature ON).
class MatchSouvenirHeroCta extends StatelessWidget {
  final MatchModel match;

  const MatchSouvenirHeroCta({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SouvenirBranding>(
      stream: MatchSouvenirBrandingService.instance.watch(),
      builder: (context, snap) {
        final branding = snap.data ?? SouvenirBranding.defaults;
        if (!branding.featureEnabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => openMatchSouvenir(context, match),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                decoration: BoxDecoration(
                  color: MatchDetailPalette.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MatchDetailPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        kSouvenirMatchBgAsset,
                        width: 44,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Créer mon souvenir',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: MatchDetailPalette.text,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Photo souvenir — partager',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: MatchDetailPalette.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MatchDetailPalette.gold.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: MatchDetailPalette.greenDeep,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> openMatchSouvenir(BuildContext context, MatchModel match) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MatchSouvenirScreen(match: match),
    ),
  );
}

/// Menu partage fiche match : texte + souvenir (si feature ON).
Future<void> showMatchShareActions(BuildContext context, MatchModel match) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MatchDetailPalette.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: StreamBuilder<SouvenirBranding>(
        stream: MatchSouvenirBrandingService.instance.watch(),
        builder: (context, snap) {
          final branding = snap.data ?? SouvenirBranding.defaults;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PARTAGER',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: MatchDetailPalette.gold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.ios_share_rounded,
                    color: MatchDetailPalette.green,
                  ),
                  title: Text(
                    'Partager le match',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: MatchDetailPalette.text,
                    ),
                  ),
                  subtitle: Text(
                    'Texte pour les réseaux',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MatchDetailPalette.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    DvcrShare.share(
                      ShareHelper.matchText(match),
                      context: context,
                    );
                  },
                ),
                if (branding.featureEnabled)
                  ListTile(
                    leading: const Icon(
                      Icons.photo_camera_back_rounded,
                      color: MatchDetailPalette.red,
                    ),
                    title: Text(
                      'Créer un souvenir',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: MatchDetailPalette.text,
                      ),
                    ),
                    subtitle: Text(
                      'Cadre photo DVCR avec score',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      openMatchSouvenir(context, match);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class MatchSouvenirScreen extends StatefulWidget {
  final MatchModel match;

  const MatchSouvenirScreen({super.key, required this.match});

  @override
  State<MatchSouvenirScreen> createState() => _MatchSouvenirScreenState();
}

class _MatchSouvenirScreenState extends State<MatchSouvenirScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Impossible d’ouvrir l’appareil photo.'
                : 'Impossible d’ouvrir la galerie.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Future<Uint8List?> _capturePng() async {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // Déjà rendu à 1080×1920 — ratio 1 suffit.
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  String get _fileBase {
    String slug(String s) {
      final t = s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return t.length <= 12 ? t : t.substring(0, 12);
    }

    return 'dvcr_souvenir_${slug(widget.match.team1)}_${slug(widget.match.team2)}';
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('capture');
      }
      final caption = ShareHelper.matchText(widget.match);
      final name = '$_fileBase.png';
      if (!mounted) return;

      if (kIsWeb) {
        await DvcrShare.shareLocalFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: name,
            ),
          ],
          text: caption,
          subject: 'Souvenir DVCR',
          context: context,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/dvcr_souvenir_${DateTime.now().millisecondsSinceEpoch}.png';
        final tmp = File(path);
        await tmp.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        await DvcrShare.shareLocalFiles(
          [XFile(tmp.path, mimeType: 'image/png', name: name)],
          text: caption,
          subject: 'Souvenir DVCR',
          context: context,
        );
        try {
          await tmp.delete();
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec du partage. Réessaie.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('capture');
      }
      final name = '$_fileBase.png';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le souvenir',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (path == null) {
        // Annulé — sur mobile sans dialogue, fallback partage.
        if (!kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Utilise Partager → Enregistrer dans Photos.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Souvenir enregistré.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // Fallback : feuille de partage (Enregistrer dans Photos).
      setState(() => _busy = false);
      await _share();
      return;
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  void _showLocalInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Photo 100 % locale',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Ta photo reste sur ton téléphone. Rien n’est envoyé sur internet. '
          'Tu peux aussi continuer sans photo.',
          style: GoogleFonts.inter(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Scaffold(
      backgroundColor: MatchDetailPalette.bg,
      appBar: AppBar(
        backgroundColor: MatchDetailPalette.greenDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Souvenir match',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Infos',
            onPressed: _showLocalInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Aperçu : s’adapte à l’espace restant (boutons photo toujours visibles).
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final aspect = kSouvenirCardW / kSouvenirCardH;
                  final maxW = constraints.maxWidth.clamp(0.0, 340.0);
                  final maxH = constraints.maxHeight;
                  var w = maxW;
                  var h = w / aspect;
                  if (h > maxH && maxH > 0) {
                    h = maxH;
                    w = h * aspect;
                  }
                  return Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: StreamBuilder<SouvenirBranding>(
                        stream: MatchSouvenirBrandingService.instance.watch(),
                        builder: (context, brandSnap) {
                          final branding =
                              brandSnap.data ?? SouvenirBranding.defaults;
                          return FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: kSouvenirCardW,
                              height: kSouvenirCardH,
                              child: RepaintBoundary(
                                key: _boundaryKey,
                                child: MatchSouvenirCard(
                                  match: m,
                                  photoBytes: _photoBytes,
                                  partnerLogoUrl: branding.showOnFrame
                                      ? branding.logoUrl
                                      : null,
                                  partnerLogoRevisionMillis:
                                      branding.revisionMillis,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Actions photo — pied fixe, visibles sans scroll.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PrimaryPhotoButton(
                  label: 'Galerie',
                  icon: Icons.photo_library_rounded,
                  background: MatchDetailPalette.green,
                  onPressed:
                      _busy ? null : () => _pick(ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _PrimaryPhotoButton(
                  label: 'Prendre une photo',
                  icon: Icons.photo_camera_rounded,
                  background: MatchDetailPalette.red,
                  onPressed:
                      _busy ? null : () => _pick(ImageSource.camera),
                ),
                if (_photoBytes != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _photoBytes = null),
                    child: Text(
                      'Retirer la photo',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        'Enregistrer',
                        style:
                            GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MatchDetailPalette.green,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: MatchDetailPalette.border,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(
                        'Partager',
                        style:
                            GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MatchDetailPalette.green,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: MatchDetailPalette.border,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

class _PrimaryPhotoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback? onPressed;

  const _PrimaryPhotoButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          disabledBackgroundColor: background.withAlpha(120),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// Libellé court sous le logo (ex. « PAU », « CSSA »).
String _souvenirShortTeam(String name) {
  final t = name.trim().toUpperCase();
  if (t.isEmpty) return '?';
  if (t.length <= 10) return t;
  final first = t.split(RegExp(r'\s+')).first;
  if (first.length >= 3 && first.length <= 10) return first;
  return t.substring(0, 10);
}

/// Composition visuelle 1080×1920 — fond DVCR + photo + logos/score flottants.
class MatchSouvenirCard extends StatelessWidget {
  final MatchModel match;
  final Uint8List? photoBytes;

  /// Logo partenaire (sponsor) — coin haut droit du cadre, inclus à l’export.
  final String? partnerLogoUrl;
  final int partnerLogoRevisionMillis;

  const MatchSouvenirCard({
    super.key,
    required this.match,
    this.photoBytes,
    this.partnerLogoUrl,
    this.partnerLogoRevisionMillis = 0,
  });

  @override
  Widget build(BuildContext context) {
    final s1 = match.score1;
    final s2 = match.score2;
    final hasScore = s1 != null && s2 != null;
    final dateLabel =
        DateFormat('d MMMM yyyy', 'fr_FR').format(match.date).toUpperCase();
    final partnerUrl = (partnerLogoUrl ?? '').trim();
    final showPartner = partnerUrl.startsWith('http://') ||
        partnerUrl.startsWith('https://');

    // Fenêtre photo (pour ancrer le logo partenaire en haut à droite).
    const frameTop = kSouvenirCardH * 0.12;
    const frameRight = kSouvenirCardW * 0.08;
    const partnerSize = 168.0;

    return SizedBox(
      width: kSouvenirCardW,
      height: kSouvenirCardH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            kSouvenirMatchBgAsset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          // Grande fenêtre photo (bordure or), sans carte.
          Positioned(
            top: frameTop,
            left: kSouvenirCardW * 0.08,
            right: frameRight,
            height: kSouvenirCardH * 0.48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFE8D48A),
                  width: 6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(120),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: photoBytes != null
                    ? Image.memory(
                        photoBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        gaplessPlayback: true,
                      )
                    : _ScoreOnlyPlaceholder(match: match),
              ),
            ),
          ),
          // Logo partenaire — haut droit du cadre (dans la composition exportée).
          if (showPartner)
            Positioned(
              top: frameTop - 18,
              right: frameRight - 18,
              width: partnerSize,
              height: partnerSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.network(
                  cacheBustedImageUrl(partnerUrl, partnerLogoRevisionMillis),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  headers: kDvcrImageHttpHeaders,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          // Date + logos XXL + score / VS — flottants sur le fond (wordmark DVCR visible).
          Positioned(
            left: kSouvenirCardW * 0.04,
            right: kSouvenirCardW * 0.04,
            bottom: kSouvenirCardH * 0.085,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE8D48A),
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _TeamBlock(
                        name: match.team1,
                        logoUrl: match.logo1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: hasScore
                          ? Text(
                              '$s1 - $s2',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 96,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              'VS',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                color: MatchDetailPalette.gold,
                                height: 1,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Expanded(
                      child: _TeamBlock(
                        name: match.team2,
                        logoUrl: match.logo2,
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

class _ScoreOnlyPlaceholder extends StatelessWidget {
  final MatchModel match;
  const _ScoreOnlyPlaceholder({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF062921),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.22,
            child: Image.asset(
              kSouvenirMatchBgAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SOUVENIR',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: MatchDetailPalette.gold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${match.team1}\nvs\n${match.team2}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ajoute ta photo\npour personnaliser',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      color: Colors.white60,
                      height: 1.3,
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

class _TeamBlock extends StatelessWidget {
  final String name;
  final String? logoUrl;

  const _TeamBlock({
    required this.name,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final logo = (logoUrl ?? '').trim();
    final label = _souvenirShortTeam(name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TeamLogo(url: logo, name: name, size: 220),
        const SizedBox(height: 14),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
            shadows: const [
              Shadow(
                color: Color(0x99000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String url;
  final String name;
  final double size;

  const _TeamLogo({
    required this.url,
    required this.name,
    this.size = 220,
  });

  static const _shadow = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    // Marge intérieure ~14 % pour que le logo « contain » tienne correctement
    // dans le disque blanc (ni croppé, ni trop petit).
    final inset = size * 0.14;

    Widget circle({required Widget child}) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: _shadow,
        ),
        padding: EdgeInsets.all(inset),
        alignment: Alignment.center,
        child: child,
      );
    }

    final fallback = circle(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          initial,
          style: GoogleFonts.barlowCondensed(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: MatchDetailPalette.greenDeep,
          ),
        ),
      ),
    );

    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return fallback;
    }

    return circle(
      child: Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => FittedBox(
          fit: BoxFit.contain,
          child: Text(
            initial,
            style: GoogleFonts.barlowCondensed(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              color: MatchDetailPalette.greenDeep,
            ),
          ),
        ),
      ),
    );
  }
}
