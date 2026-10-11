import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/profile_avatars_service.dart';
import '../../../../utils/pick_image_bytes.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

/// Admin — catalogue d’avatars profil (`app_config/profile_avatars`).
class ProfileAvatarsAdminSection extends StatefulWidget {
  const ProfileAvatarsAdminSection({super.key});

  @override
  State<ProfileAvatarsAdminSection> createState() =>
      _ProfileAvatarsAdminSectionState();
}

class _ProfileAvatarsAdminSectionState
    extends State<ProfileAvatarsAdminSection> {
  StreamSubscription<ProfileAvatarCatalog>? _sub;
  ProfileAvatarCatalog _catalog = ProfileAvatarCatalog.empty;
  bool _loading = true;
  bool _uploading = false;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = ProfileAvatarsService.instance.watchCatalog().listen((c) {
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
      await ProfileAvatarsService.instance.uploadCatalogAvatar(
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

  Future<void> _delete(ProfileAvatar avatar) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Supprimer cet avatar ?',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'Il disparaît du catalogue. Les membres qui l’avaient choisi '
          'retomberont sur leurs initiales.',
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
      await ProfileAvatarsService.instance.deleteCatalogAvatar(avatar);
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
      title: 'AVATARS PROFIL',
      icon: Icons.face_retouching_natural_rounded,
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
                    ProfileAvatar.specCopy,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fond transparent OK. Affichage dans l’app 64–96 px ; '
                    'on stocke 512 pour rester net. Les membres choisissent '
                    'dans Profil → Choisir mon avatar — pas d’import photo perso.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Storage · ${ProfileAvatar.storageFolder}/  ·  '
                    'Firestore · app_config/${ProfileAvatar.firestoreDocId}',
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
                        _uploading ? 'IMPORT…' : 'IMPORTER UN AVATAR',
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
                      'Aucun avatar pour l’instant — importe le premier '
                      '(${ProfileAvatar.specCopy}).',
                      style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in _catalog.avatars)
                          _AdminAvatarThumb(
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

class _AdminAvatarThumb extends StatelessWidget {
  final ProfileAvatar avatar;
  final bool busy;
  final VoidCallback onDelete;

  const _AdminAvatarThumb({
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
