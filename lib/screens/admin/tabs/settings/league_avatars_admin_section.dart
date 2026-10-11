import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/league_avatars_service.dart';
import '../../../../utils/pick_image_bytes.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

/// Admin — catalogue d’emblèmes de ligue (`app_config/league_avatars`).
class LeagueAvatarsAdminSection extends StatefulWidget {
  const LeagueAvatarsAdminSection({super.key});

  @override
  State<LeagueAvatarsAdminSection> createState() =>
      _LeagueAvatarsAdminSectionState();
}

class _LeagueAvatarsAdminSectionState extends State<LeagueAvatarsAdminSection> {
  StreamSubscription<LeagueAvatarCatalog>? _sub;
  LeagueAvatarCatalog _catalog = LeagueAvatarCatalog.empty;
  bool _loading = true;
  bool _uploading = false;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = LeagueAvatarsService.instance.watchCatalog().listen((c) {
      if (!mounted) return;
      setState(() {
        _catalog = c;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _errorLabel(Object e) {
    if (e is StateError) {
      return switch (e.message) {
        'avatar_too_large' => 'Fichier trop lourd (500 Ko max).',
        'avatar_format' => 'Format refusé — PNG ou WebP uniquement.',
        'avatar_empty' => 'Fichier vide — réessaie.',
        'not_authenticated' => 'Connecte-toi pour uploader.',
        _ => 'Erreur : $e',
      };
    }
    return 'Erreur : $e';
  }

  Future<void> _upload() async {
    if (_uploading) return;
    late final PickedImageBytes picked;
    try {
      final result = await pickImageBytes(
        allowedExtensions: const ['png', 'webp'],
      );
      if (result == null) return;
      picked = result;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorLabel(e));
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await LeagueAvatarsService.instance.uploadCatalogAvatar(
        bytes: picked.bytes,
        extension: picked.extension,
        originalName: picked.name,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorLabel(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(LeagueCatalogAvatar avatar) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Supprimer cet emblème ?',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'Il disparaît du catalogue. Les ligues déjà créées avec cet emblème '
          'le conservent jusqu’à ce que le créateur en choisisse un autre.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = avatar.id);
    try {
      await LeagueAvatarsService.instance.deleteCatalogAvatar(avatar);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorLabel(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'AVATARS LIGUES',
      icon: Icons.shield_rounded,
      color: adminGold,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LeagueCatalogAvatar.specCopy,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fond transparent OK. Affichage dans l’app ~64 px ; '
                    'on stocke 512 pour rester net. Distinct des avatars profil '
                    '(onglet AVATARS). Catalogue vide = aucun choix dans '
                    'Créer ma ligue — les mascottes restent dans AVATARS profil.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Storage · ${LeagueCatalogAvatar.storageFolder}/  ·  '
                    'Firestore · app_config/${LeagueCatalogAvatar.firestoreDocId}',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: adminGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                        _uploading ? 'IMPORT…' : 'IMPORTER UN EMBLÈME',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 12, color: adminRed),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_catalog.isEmpty)
                    Text(
                      'Aucun emblème pour l’instant — importe le premier. '
                      'Sans import, Créer ma ligue n’affiche pas les mascottes '
                      'profil (sanglier, supporter, etc.).',
                      style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in _catalog.avatars)
                          _AdminLeagueThumb(
                            avatar: a,
                            busy: _busyId == a.id,
                            onDelete: () => _delete(a),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _AdminLeagueThumb extends StatelessWidget {
  final LeagueCatalogAvatar avatar;
  final bool busy;
  final VoidCallback onDelete;

  const _AdminLeagueThumb({
    required this.avatar,
    required this.busy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ColoredBox(
                    color: adminSurface,
                    child: DvcrNetworkImage(
                      avatar.url,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      cacheWidth: dvcrImageCacheWidth(context, 64),
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 22,
                        color: adminGrey,
                      ),
                    ),
                  ),
                ),
              ),
              if (busy)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: adminGold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          TextButton(
            onPressed: busy ? null : onDelete,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              'Suppr.',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: adminRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
