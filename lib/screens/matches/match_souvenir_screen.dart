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
import '../../services/dvcr_share_service.dart';
import '../../utils/share_helper.dart';
import 'match_detail_palette.dart';

/// Fond officiel du cadre souvenir (portrait, branding DVCR).
const kSouvenirMatchBgAsset = 'assets/images/souvenir_match_bg.png';

/// Résolution de composition (Stories / partage social).
const double kSouvenirCardW = 1080;
const double kSouvenirCardH = 1920;

/// CTA principal — sous le hero score, au-dessus des onglets (toujours visible).
class MatchSouvenirHeroCta extends StatelessWidget {
  final MatchModel match;

  const MatchSouvenirHeroCta({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
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
  }
}

Future<void> openMatchSouvenir(BuildContext context, MatchModel match) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MatchSouvenirScreen(match: match),
    ),
  );
}

/// Menu partage fiche match : texte + souvenir.
Future<void> showMatchShareActions(BuildContext context, MatchModel match) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MatchDetailPalette.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              children: [
                Text(
                  'Choisis une photo (galerie ou appareil), ou continue sans photo. '
                  'Rien n’est envoyé sur internet.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MatchDetailPalette.grey,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: AspectRatio(
                      aspectRatio: kSouvenirCardW / kSouvenirCardH,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: kSouvenirCardW,
                          height: kSouvenirCardH,
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: MatchSouvenirCard(
                              match: m,
                              photoBytes: _photoBytes,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          'Galerie',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MatchDetailPalette.green,
                          side: const BorderSide(
                            color: MatchDetailPalette.border,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          'Appareil photo',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MatchDetailPalette.green,
                          side: const BorderSide(
                            color: MatchDetailPalette.border,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_photoBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _photoBytes = null),
                    child: Text(
                      'Retirer la photo (carte score seule)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: MatchDetailPalette.grey,
                      ),
                    ),
                  ),
                ],
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
                        foregroundColor: MatchDetailPalette.text,
                        side: const BorderSide(
                          color: MatchDetailPalette.border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(
                        'Partager',
                        style:
                            GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MatchDetailPalette.gold,
                        foregroundColor: Colors.black,
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

/// Composition visuelle 1080×1920 — fond DVCR + photo + logos/score.
class MatchSouvenirCard extends StatelessWidget {
  final MatchModel match;
  final Uint8List? photoBytes;

  const MatchSouvenirCard({
    super.key,
    required this.match,
    this.photoBytes,
  });

  @override
  Widget build(BuildContext context) {
    final s1 = match.score1;
    final s2 = match.score2;
    final hasScore = s1 != null && s2 != null;
    final dateLabel =
        DateFormat('d MMM yyyy', 'fr_FR').format(match.date).toUpperCase();
    final comp = match.competition.trim();

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
          // Fenêtre photo centrale (au-dessus du taureau, sous le crest).
          Positioned(
            top: kSouvenirCardH * 0.155,
            left: kSouvenirCardW * 0.09,
            right: kSouvenirCardW * 0.09,
            height: kSouvenirCardH * 0.40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE8D48A),
                  width: 5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(140),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
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
          // Bande score + logos, au-dessus du wordmark DVCR.
          Positioned(
            left: kSouvenirCardW * 0.06,
            right: kSouvenirCardW * 0.06,
            bottom: kSouvenirCardH * 0.155,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(175),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MatchDetailPalette.red.withAlpha(200),
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (comp.isNotEmpty || dateLabel.isNotEmpty)
                    Text(
                      [
                        if (comp.isNotEmpty) comp.toUpperCase(),
                        if (dateLabel.isNotEmpty) dateLabel,
                      ].join('  ·  '),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 1.1,
                      ),
                    ),
                  if (comp.isNotEmpty || dateLabel.isNotEmpty)
                    const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TeamBlock(
                          name: match.team1,
                          logoUrl: match.logo1,
                          alignEnd: false,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: hasScore
                            ? Text(
                                '$s1 – $s2',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              )
                            : Text(
                                'VS',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: MatchDetailPalette.gold,
                                  height: 1,
                                ),
                              ),
                      ),
                      Expanded(
                        child: _TeamBlock(
                          name: match.team2,
                          logoUrl: match.logo2,
                          alignEnd: true,
                        ),
                      ),
                    ],
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
  final bool alignEnd;

  const _TeamBlock({
    required this.name,
    required this.logoUrl,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final logo = (logoUrl ?? '').trim();
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _TeamLogo(url: logo, name: name),
        const SizedBox(height: 10),
        Text(
          name.toUpperCase(),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String url;
  final String name;

  const _TeamLogo({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    final fallback = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.barlowCondensed(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return fallback;
    }
    return ClipOval(
      child: Container(
        width: 88,
        height: 88,
        color: Colors.white.withAlpha(24),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
