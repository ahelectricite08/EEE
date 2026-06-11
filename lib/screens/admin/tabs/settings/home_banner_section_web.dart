import 'dart:async';
import 'dart:typed_data' show ByteBuffer, Uint8List;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../services/home_banner_service.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Section admin pour changer la photo de la bannière home.
class HomeBannerSection extends StatefulWidget {
  const HomeBannerSection({super.key});

  @override
  State<HomeBannerSection> createState() => _HomeBannerSectionState();
}

class _HomeBannerSectionState extends State<HomeBannerSection> {
  StreamSubscription<String?>? _sub;
  String? _currentUrl;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = HomeBannerService.photoUrlStream().listen((url) {
      if (!mounted) return;
      setState(() => _currentUrl = url);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/jpeg,image/png,image/webp';
    input.click();

    final file = await input.onChange.first.then((_) => input.files?.first);
    if (file == null) return;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    // dart:html FileReader.result est un ByteBuffer natif JS
    // ignore: avoid_dynamic_calls
    final bytes = Uint8List.view(
      (reader.result as dynamic).buffer as ByteBuffer,
    );

    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      setState(() => _error = 'Format non supporté (jpg, png, webp)');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });

    try {
      // Animation progress (Storage n'expose pas de stream direct ici)
      final ticker = Stream.periodic(const Duration(milliseconds: 80), (i) => i);
      final sub = ticker.listen((_) {
        if (!mounted) return;
        setState(() => _progress = (_progress + 0.04).clamp(0, 0.9));
      });

      await HomeBannerService.uploadPhoto(bytes, ext);
      sub.cancel();

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = 0;
        _error = 'Erreur : $e';
      });
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Remettre la photo par défaut ?',
          style: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'La photo personnalisée sera supprimée et l\'image d\'origine du stade sera réaffichée.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remettre', style: GoogleFonts.inter(color: adminRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await HomeBannerService.clearPhoto();
    if (!mounted) return;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = _currentUrl != null && _currentUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 15, color: adminOrange),
              const SizedBox(width: 8),
              Text(
                'PHOTO ACCUEIL',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: hasCustom
                      ? adminGreenAccent.withAlpha(25)
                      : adminGrey.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasCustom
                        ? adminGreenAccent.withAlpha(80)
                        : adminGrey.withAlpha(60),
                  ),
                ),
                child: Text(
                  hasCustom ? 'Personnalisée' : 'Par défaut',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: hasCustom ? adminGreenAccent : adminGrey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Aperçu photo actuelle
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCustom)
                    Image.network(
                      _currentUrl!,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.3),
                      errorBuilder: (context, error, stackTrace) => _AssetPlaceholder(),
                    )
                  else
                    _AssetPlaceholder(),
                  // Overlay gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(120),
                        ],
                      ),
                    ),
                  ),
                  // Label bas
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Text(
                      hasCustom ? 'Photo personnalisée' : 'Photo par défaut (asset local)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withAlpha(200),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Progress overlay
                  if (_uploading)
                    Container(
                      color: Colors.black.withAlpha(160),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.white.withAlpha(40),
                              color: adminOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Envoi en cours…',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 11, color: adminRed),
            ),
          ],

          const SizedBox(height: 12),

          // Boutons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: Text(
                    'Changer la photo',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: adminOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: adminOrange.withAlpha(60),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (hasCustom) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _reset,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text(
                    'Défaut',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adminGrey,
                    side: BorderSide(color: adminBorder),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Formats acceptés : JPG, PNG, WebP. Recommandé : paysage 16:9, min 1200×500 px.',
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AssetPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1A14),
      child: Image.asset(
        'assets/images/IMG_0842.JPG',
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.3),
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF0E1A14),
          child: Icon(
            Icons.image_outlined,
            size: 40,
            color: Colors.white.withAlpha(60),
          ),
        ),
      ),
    );
  }
}
