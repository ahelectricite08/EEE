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
import '../../utils/save_image_to_gallery.dart';
import '../../utils/share_helper.dart';
import '../../widgets/square_partner_logo.dart';
import 'match_detail_theme.dart';
import 'match_detail_type.dart';
import 'match_detail_ui.dart';

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
              child: Ink(
                decoration: BoxDecoration(
                  color: MatchDetailTheme.surface,
                  border: Border.all(
                    color: MatchDetailTheme.hairline,
                    width: 1,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3,
                        color: MatchDetailTheme.green,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: MatchDetailTheme.hairline,
                              width: 1,
                            ),
                          ),
                          child: Image.asset(
                            kSouvenirMatchBgAsset,
                            width: 40,
                            height: 54,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'CRÉER MON SOUVENIR',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: MatchDetailTheme.ink,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cadre tribune · score · partage',
                                style: MatchDetailType.meta,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: MatchDetailTheme.surfaceMuted,
                              border: Border.all(
                                color: MatchDetailTheme.hairline,
                                width: 1,
                              ),
                            ),
                            child: const SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.photo_camera_outlined,
                                color: MatchDetailTheme.green,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
    useRootNavigator: true,
    context: context,
    backgroundColor: MatchDetailTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
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
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      color: MatchDetailTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PARTAGER',
                      style: MatchDetailType.nameplate.copyWith(
                        color: MatchDetailTheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 3,
                  color: MatchDetailTheme.green,
                ),
                const SizedBox(height: 14),
                _ShareSheetRow(
                  icon: Icons.ios_share_outlined,
                  title: 'Partager le match',
                  subtitle: 'Texte pour les réseaux',
                  onTap: () {
                    Navigator.pop(ctx);
                    DvcrShare.share(
                      ShareHelper.matchText(match),
                      context: context,
                    );
                  },
                ),
                if (branding.featureEnabled) ...[
                  const SizedBox(height: 8),
                  _ShareSheetRow(
                    icon: Icons.photo_camera_outlined,
                    title: 'Créer mon souvenir',
                    subtitle: 'Cadre tribune avec le score',
                    onTap: () {
                      Navigator.pop(ctx);
                      openMatchSouvenir(context, match);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ShareSheetRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareSheetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: MatchDetailTheme.surface,
            border: Border.all(color: MatchDetailTheme.hairline, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Icon(icon, color: MatchDetailTheme.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: MatchDetailType.label),
                      const SizedBox(height: 2),
                      Text(subtitle, style: MatchDetailType.meta),
                    ],
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

/// Tampon partenaire sur la fiche match — même logo / toggle que le souvenir
/// (`app_config/souvenir_branding.enabled`). Rien si switch OFF ou URL vide.
class MatchFicheSouvenirPartnerStrip extends StatelessWidget {
  const MatchFicheSouvenirPartnerStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SouvenirBranding>(
      stream: MatchSouvenirBrandingService.instance.watch(),
      builder: (context, snap) {
        final branding = snap.data ?? SouvenirBranding.defaults;
        if (!branding.showOnFiche) return const SizedBox.shrink();
        final url = branding.logoUrl.trim();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MatchDetailTheme.surface,
              border: Border.all(
                color: MatchDetailTheme.hairline,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    color: const Color(0xFFC8A436),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARTENAIRE',
                          style: MatchDetailType.kicker.copyWith(
                            color: MatchDetailTheme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SquarePartnerLogo(
                    url: url,
                    revisionMillis: branding.revisionMillis,
                    size: 44,
                    background: MatchDetailTheme.surface,
                    borderColor: MatchDetailTheme.hairline,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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

      // Web : téléchargement fichier (pas de galerie native).
      if (kIsWeb) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le souvenir',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: const ['png'],
          bytes: bytes,
        );
        if (!mounted) return;
        if (path == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Souvenir enregistré.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
        return;
      }

      // iOS / Android : photothèque / galerie.
      final result = await saveImageToGallery(bytes, name: _fileBase);
      if (!mounted) return;
      switch (result) {
        case SaveImageToGalleryResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Enregistré dans la galerie',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
        case SaveImageToGalleryResult.denied:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Autorise l’accès à la galerie pour enregistrer.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
        case SaveImageToGalleryResult.unsupported:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Échec de l’enregistrement. Réessaie.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec de l’enregistrement. Réessaie.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showLocalInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: MatchDetailTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: MatchDetailTheme.hairline, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    color: MatchDetailTheme.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PHOTO LOCALE',
                    style: MatchDetailType.nameplate.copyWith(
                      color: MatchDetailTheme.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 3, color: const Color(0xFFC8A436)),
              const SizedBox(height: 14),
              Text(
                'Ta photo reste sur ton téléphone. Rien n’est envoyé sur internet. '
                'Tu peux aussi continuer sans photo.',
                style: MatchDetailType.body,
              ),
              const SizedBox(height: 16),
              MatchDetailPaperButton(
                label: 'OK',
                ink: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Scaffold(
      backgroundColor: MatchDetailTheme.scaffold,
      body: Column(
        children: [
          ColoredBox(
            color: MatchDetailTheme.scaffold,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Retour',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: MatchDetailTheme.ink,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 16,
                          color: const Color(0xFFC8A436),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SOUVENIR',
                            style: MatchDetailType.nameplate.copyWith(
                              color: MatchDetailTheme.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Infos',
                          onPressed: _showLocalInfo,
                          icon: const Icon(
                            Icons.info_outline,
                            color: MatchDetailTheme.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 3,
                    width: double.infinity,
                    color: MatchDetailTheme.green,
                  ),
                ],
              ),
            ),
          ),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: MatchDetailTheme.surface,
                        border: Border.all(
                          color: MatchDetailTheme.hairline,
                          width: 1,
                        ),
                      ),
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
                    ),
                  );
                },
              ),
            ),
          ),
          // Actions photo — pied fixe, visibles sans scroll.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MatchDetailPaperButton(
                        label: 'Galerie',
                        icon: Icons.photo_library_outlined,
                        ink: true,
                        onTap:
                            _busy ? null : () => _pick(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MatchDetailPaperButton(
                        label: 'Appareil photo',
                        icon: Icons.photo_camera_outlined,
                        onTap:
                            _busy ? null : () => _pick(ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                if (_photoBytes != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _photoBytes = null),
                    child: Text(
                      'Retirer la photo',
                      style: MatchDetailType.meta,
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
                    child: MatchDetailPaperButton(
                      label: 'Enregistrer',
                      icon: Icons.download_outlined,
                      onTap: _busy ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MatchDetailPaperButton(
                      label: 'Partager',
                      icon: Icons.ios_share_outlined,
                      ink: true,
                      onTap: _busy ? null : _share,
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

/// Libellé court sous le logo (ex. « PAU », « CSSA »).
String _souvenirShortTeam(String name) {
  final t = name.trim().toUpperCase();
  if (t.isEmpty) return '?';
  if (t.length <= 10) return t;
  final first = t.split(RegExp(r'\s+')).first;
  if (first.length >= 3 && first.length <= 10) return first;
  return t.substring(0, 10);
}

/// Composition visuelle 1080×1920 — fond DVCR + photo + plaque tribune.
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
    const partnerSize = 156.0;
    // Logo sur la photo, pas sur le passe-partout ivoire.
    const partnerInset = _SouvenirPhotoCadre.goldW +
        _SouvenirPhotoCadre.greenW +
        _SouvenirPhotoCadre.matTop +
        _SouvenirPhotoCadre.hairlineW +
        _SouvenirPhotoCadre.hairlineW +
        12;

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
          Positioned(
            top: frameTop,
            left: kSouvenirCardW * 0.08,
            right: frameRight,
            height: kSouvenirCardH * 0.48,
            child: _SouvenirPhotoCadre(
              child: photoBytes != null
                  ? Image.memory(
                      photoBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.high,
                    )
                  : _ScoreOnlyPlaceholder(match: match),
            ),
          ),
          if (showPartner)
            Positioned(
              top: frameTop + partnerInset,
              right: frameRight + partnerInset,
              child: SquarePartnerLogo(
                url: partnerUrl,
                revisionMillis: partnerLogoRevisionMillis,
                size: partnerSize,
                background: const Color(0xFFFFFDF8),
                borderColor: const Color(0xFFE6E0D1),
              ),
            ),
          // Pied tribune — même ADN que le cadre photo (ivoire / or / vert).
          // Dans le RepaintBoundary : aperçu et export partagent cette plaque.
          Positioned(
            left: kSouvenirCardW * 0.08,
            right: kSouvenirCardW * 0.08,
            bottom: kSouvenirCardH * 0.055,
            child: _SouvenirTribunePlate(
              dateLabel: dateLabel,
              competition: match.competition,
              team1: match.team1,
              logo1: match.logo1,
              team2: match.team2,
              logo2: match.logo2,
              scoreLabel: hasScore ? '$s1–$s2' : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cadre tribune autour de la photo fan — même ADN que le nameplate page
/// (ivoire, filet or 3 px, bande verte 3 px, filet 1 px, coins carrés).
/// Inclus dans le [RepaintBoundary] : aperçu et export partagent ce widget.
class _SouvenirPhotoCadre extends StatelessWidget {
  static const Color gold = Color(0xFFC8A436);
  static const Color ivory = Color(0xFFF4F0E6);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color green = Color(0xFF0A4438);

  static const double goldW = 3;
  static const double greenW = 3;
  static const double hairlineW = 1;
  static const double mat = 22;
  static const double matTop = 16;

  final Widget child;

  const _SouvenirPhotoCadre({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ivory,
        border: Border.all(color: gold, width: goldW),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(
            color: green,
            child: SizedBox(height: greenW, width: double.infinity),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(mat, matTop, mat, mat),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: hairline, width: hairlineW),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(hairlineW),
                  child: ClipRect(
                    child: SizedBox.expand(child: child),
                  ),
                ),
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
    return ColoredBox(
      color: const Color(0x88062921),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 3,
                color: const Color(0xFFC8A436),
              ),
              const SizedBox(height: 18),
              Text(
                'SOUVENIR',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${match.team1}\nvs\n${match.team2}',
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Ajoute ta photo\npour personnaliser',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  height: 1.3,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plaque tribune sous la photo — date nameplate + blasons carrés + VS / score.
/// Inclus dans le [RepaintBoundary] avec le cadre.
class _SouvenirTribunePlate extends StatelessWidget {
  static const Color gold = Color(0xFFC8A436);
  static const Color ivory = Color(0xFFF4F0E6);
  static const Color hairline = Color(0xFFE6E0D1);
  static const Color green = Color(0xFF0A4438);
  static const Color ink = Color(0xFF0A1C18);
  static const Color paper = Color(0xFFFFFDF8);

  final String dateLabel;
  final String competition;
  final String team1;
  final String? logo1;
  final String team2;
  final String? logo2;
  final String? scoreLabel;

  const _SouvenirTribunePlate({
    required this.dateLabel,
    required this.competition,
    required this.team1,
    required this.logo1,
    required this.team2,
    required this.logo2,
    required this.scoreLabel,
  });

  @override
  Widget build(BuildContext context) {
    final comp = competition.trim().toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ivory,
        border: Border.all(color: gold, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(
            color: green,
            child: SizedBox(height: 3, width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              children: [
                if (comp.isNotEmpty) ...[
                  Text(
                    comp,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      height: 1,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const ColoredBox(
                      color: gold,
                      child: SizedBox(width: 3, height: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dateLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                          height: 1,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const ColoredBox(
                      color: gold,
                      child: SizedBox(width: 3, height: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const ColoredBox(
            color: hairline,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _TeamBlock(
                    name: team1,
                    logoUrl: logo1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _VsMark(scoreLabel: scoreLabel),
                ),
                Expanded(
                  child: _TeamBlock(
                    name: team2,
                    logoUrl: logo2,
                  ),
                ),
              ],
            ),
          ),
          const ColoredBox(
            color: green,
            child: SizedBox(height: 3, width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _VsMark extends StatelessWidget {
  final String? scoreLabel;

  const _VsMark({required this.scoreLabel});

  @override
  Widget build(BuildContext context) {
    final score = scoreLabel;
    final isScore = score != null && score.isNotEmpty;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _SouvenirTribunePlate.green,
        border: Border.fromBorderSide(
          BorderSide(color: _SouvenirTribunePlate.gold, width: 3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isScore ? 18 : 16,
          vertical: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ColoredBox(
              color: _SouvenirTribunePlate.gold,
              child: SizedBox(width: 36, height: 3),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isScore ? score : 'VS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: isScore ? 72 : 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: isScore ? 0.4 : 4,
                    height: 1,
                    color: _SouvenirTribunePlate.ivory,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const ColoredBox(
              color: _SouvenirTribunePlate.gold,
              child: SizedBox(width: 36, height: 3),
            ),
          ],
        ),
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
        _TeamLogo(url: logo, name: name, size: 196),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            height: 1,
            color: _SouvenirTribunePlate.ink,
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
    this.size = 196,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    final inset = size * 0.12;

    Widget square({required Widget child}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _SouvenirTribunePlate.paper,
          border: Border.all(color: _SouvenirTribunePlate.gold, width: 3),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: child,
          ),
        ),
      );
    }

    final fallback = square(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          initial,
          style: GoogleFonts.barlowCondensed(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            color: _SouvenirTribunePlate.green,
          ),
        ),
      ),
    );

    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return fallback;
    }

    return square(
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
              fontSize: size * 0.5,
              fontWeight: FontWeight.w900,
              color: _SouvenirTribunePlate.green,
            ),
          ),
        ),
      ),
    );
  }
}
