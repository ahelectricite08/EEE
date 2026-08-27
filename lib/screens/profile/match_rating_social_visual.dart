import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/match_model.dart';
import '../../models/match_partner_logos.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/match_partner_logos_service.dart';
import '../../services/match_rating_service.dart';
import '../../utils/remote_image_url.dart';
import '../../utils/save_image_to_gallery.dart';
import '../../widgets/match_rating_summary.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';
import 'profile_type.dart';

const double kMatchRatingSocialW = 1080;
const double kMatchRatingSocialH = 1920;

/// Story 9:16 — toile blanche, encre club, pas l’ivoire profil.
const Color _storyWhite = Color(0xFFFFFFFF);
const Color _storyInk = Color(0xFF0A1C18);
const Color _storyGreen = Color(0xFF0B3D2E);
const Color _storyRed = Color(0xFFBA203C);
const Color _storyRule = Color(0xFF0A1C18);

class MatchRatingSocialPayload {
  final String matchId;
  final String team1;
  final String team2;
  final String? logo1;
  final String? logo2;
  final int? score1;
  final int? score2;
  final DateTime date;
  final DateTime liveEndedAt;
  final String competition;
  final MatchRatingSnapshot rating;
  final Map<String, int> counts;

  const MatchRatingSocialPayload({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.date,
    required this.liveEndedAt,
    required this.rating,
    required this.counts,
    this.logo1,
    this.logo2,
    this.score1,
    this.score2,
    this.competition = '',
  });

  String get scoreLabel {
    if (score1 == null || score2 == null) return '—';
    return '$score1 – $score2';
  }

  static MatchRatingSocialPayload? fromDoc(
    String id,
    Map<String, dynamic> data, {
    required DateTime now,
  }) {
    if (!MatchRatingService.hasSocialVisual(data, now)) return null;
    final rating = MatchRatingSnapshot.fromDoc(data);
    final ended = MatchRatingService.liveEndedAtOf(data);
    if (rating == null || ended == null) return null;
    final date = MatchRatingService.parseDateTime(data['date']) ?? ended;
    return MatchRatingSocialPayload(
      matchId: id,
      team1: (data['team1'] as String? ?? 'Équipe 1').trim(),
      team2: (data['team2'] as String? ?? 'Équipe 2').trim(),
      logo1: (data['logo1'] as String?)?.trim(),
      logo2: (data['logo2'] as String?)?.trim(),
      score1: MatchModel.parseScoreField(data['score1'] ?? data['scoreHome']),
      score2: MatchModel.parseScoreField(data['score2'] ?? data['scoreAway']),
      date: date,
      liveEndedAt: ended,
      competition: (data['competition'] as String? ?? '').trim(),
      rating: rating,
      counts: MatchRatingSnapshot.countsFromDoc(data),
    );
  }
}

class MatchRatingSocialVisualScreen extends StatefulWidget {
  final MatchRatingSocialPayload payload;

  const MatchRatingSocialVisualScreen({super.key, required this.payload});

  @override
  State<MatchRatingSocialVisualScreen> createState() =>
      _MatchRatingSocialVisualScreenState();
}

class _MatchRatingSocialVisualScreenState
    extends State<MatchRatingSocialVisualScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  String get _fileBase {
    String slug(String s) {
      final t = s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return t.length <= 12 ? t : t.substring(0, 12);
    }

    return 'dvcr_note_${slug(widget.payload.team1)}_${slug(widget.payload.team2)}';
  }

  Future<Uint8List?> _capturePng() async {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null || bytes.isEmpty) throw StateError('capture');
      final name = '$_fileBase.png';
      final caption =
          'Note du match ${widget.payload.team1} ${widget.payload.scoreLabel} ${widget.payload.team2} : ${widget.payload.rating.averageLabel}/10';
      if (!mounted) return;
      if (kIsWeb) {
        await DvcrShare.shareLocalFiles(
          [
            XFile.fromData(bytes, mimeType: 'image/png', name: name),
          ],
          text: caption,
          subject: 'Note du match DVCR',
          context: context,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/dvcr_note_${DateTime.now().millisecondsSinceEpoch}.png';
        final tmp = File(path);
        await tmp.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        await DvcrShare.shareLocalFiles(
          [XFile(tmp.path, mimeType: 'image/png', name: name)],
          text: caption,
          subject: 'Note du match DVCR',
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
      if (bytes == null || bytes.isEmpty) throw StateError('capture');
      final name = '$_fileBase.png';
      if (kIsWeb) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le visuel',
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
              'Visuel enregistré.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
        return;
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(context, 'Note du match'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Visuel portrait 9:16 — à publier sur tes réseaux.',
              style: ProfileType.caption,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const aspect = kMatchRatingSocialW / kMatchRatingSocialH;
                  final maxW = constraints.maxWidth.clamp(0.0, 360.0);
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
                        color: _storyWhite,
                        border: Border.all(color: _storyInk, width: 1),
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: StreamBuilder<MatchPartnerLogos>(
                          stream: MatchPartnerLogosService.instance.watch(),
                          builder: (context, logoSnap) {
                            final logos =
                                logoSnap.data ?? MatchPartnerLogos.defaults;
                            return FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: kMatchRatingSocialW,
                                height: kMatchRatingSocialH,
                                child: RepaintBoundary(
                                  key: _boundaryKey,
                                  child: MatchRatingSocialCard(
                                    payload: widget.payload,
                                    partnerLogoUrl: logos.matchRatingLogoUrl,
                                    partnerLogoRevisionMillis:
                                        logos.revisionMillis,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _PaperAction(
                      label: 'Enregistrer',
                      icon: Icons.download_outlined,
                      onTap: _busy ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaperAction(
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

class _PaperAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool ink;

  const _PaperAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.ink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ink ? profileGreen : profileSurface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: ink ? profileGreen : profileHairline,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: ink ? Colors.white : profileGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ink ? Colors.white : profileGreen,
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

/// Composition 1080×1920 full-bleed — story blanche, tribune, pas une plaque ivoire.
class MatchRatingSocialCard extends StatelessWidget {
  final MatchRatingSocialPayload payload;
  final String partnerLogoUrl;
  final int partnerLogoRevisionMillis;

  const MatchRatingSocialCard({
    super.key,
    required this.payload,
    this.partnerLogoUrl = '',
    this.partnerLogoRevisionMillis = 0,
  });

  Color _noteColor(MatchRatingSnapshot rating) {
    if (rating.average >= 7) return _storyGreen;
    if (rating.average >= 5) return _storyInk;
    return _storyRed;
  }

  @override
  Widget build(BuildContext context) {
    final rating = payload.rating;
    final noteColor = _noteColor(rating);
    final dateLabel =
        DateFormat('d MMMM yyyy', 'fr_FR').format(payload.date).toUpperCase();
    final partner = partnerLogoUrl.trim();
    final showPartner = partner.startsWith('http://') ||
        partner.startsWith('https://');
    final meta = [
      if (payload.competition.isNotEmpty) payload.competition,
      dateLabel,
    ].join('  ·  ').toUpperCase();

    return ColoredBox(
      color: _storyWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(color: _storyGreen, child: SizedBox(height: 14)),
          ColoredBox(
            color: _storyGreen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 8, 44, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DVCR',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: _storyWhite,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'NOTE DU MATCH',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 92,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: _storyWhite,
                      height: 0.88,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ColoredBox(color: _storyInk, child: SizedBox(height: 3)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 36, 44, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _teamCol(payload.team1, payload.logo1, true),
                      ),
                      Expanded(
                        flex: 4,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              payload.scoreLabel,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 168,
                                fontWeight: FontWeight.w900,
                                color: _storyInk,
                                height: 0.9,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _teamCol(payload.team2, payload.logo2, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    meta,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _storyInk,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const ColoredBox(
                    color: _storyRule,
                    child: SizedBox(height: 1),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rating.averageLabel,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 420,
                              fontWeight: FontWeight.w900,
                              color: noteColor,
                              height: 0.78,
                            ),
                          ),
                        ),
                        Text(
                          '/10',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            color: _storyInk,
                            height: 0.9,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rating.verdictLabel.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: noteColor,
                            letterSpacing: 0.6,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'COMMUNAUTÉ DVCR',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: _storyInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ColoredBox(
                    color: _storyGreen,
                    child: SizedBox(height: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'PARTAGE TOI AUSSI\nLA NOTE DU MATCH !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 58,
                      fontWeight: FontWeight.w900,
                      color: _storyGreen,
                      height: 0.92,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (showPartner)
                    Center(
                      child: ColoredBox(
                        color: _storyWhite,
                        child: Image.network(
                          cacheBustedImageUrl(
                            partner,
                            partnerLogoRevisionMillis,
                          ),
                          height: 168,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                          headers: kDvcrImageHttpHeaders,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    )
                  else
                    Text(
                      'CSSA  ·  SEDAN ARDENNES',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.8,
                        color: _storyGreen,
                      ),
                    ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          const ColoredBox(color: _storyGreen, child: SizedBox(height: 14)),
        ],
      ),
    );
  }

  Widget _teamCol(String name, String? logoUrl, bool alignStart) {
    final url = (logoUrl ?? '').trim();
    final align =
        alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    return Column(
      crossAxisAlignment: align,
      children: [
        if (url.isNotEmpty && !shouldSkipNetworkImageUrl(url))
          SizedBox(
            width: 176,
            height: 176,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          )
        else
          const SizedBox(height: 176),
        const SizedBox(height: 12),
        Text(
          name.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignStart ? TextAlign.left : TextAlign.right,
          style: GoogleFonts.barlowCondensed(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: _storyInk,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
