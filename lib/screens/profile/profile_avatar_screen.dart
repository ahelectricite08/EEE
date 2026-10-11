import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/profile_avatars_service.dart';
import '../../widgets/profile_catalog_avatar.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';
import 'profile_type.dart';

/// Choix d’un avatar du catalogue admin — pas d’import photo perso.
class ProfileAvatarScreen extends StatefulWidget {
  const ProfileAvatarScreen({super.key});

  @override
  State<ProfileAvatarScreen> createState() => _ProfileAvatarScreenState();
}

class _ProfileAvatarScreenState extends State<ProfileAvatarScreen> {
  String? _busyId;
  bool _clearing = false;

  Future<void> _pick(ProfileAvatar avatar) async {
    if (_busyId != null || _clearing) return;
    setState(() => _busyId = avatar.id);
    try {
      await ProfileAvatarsService.instance.selectForCurrentUser(avatar);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar enregistré.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer l’avatar.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _clear() async {
    if (_busyId != null || _clearing) return;
    setState(() => _clearing = true);
    try {
      await ProfileAvatarsService.instance.clearForCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar retiré — initiales affichées.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de retirer l’avatar.')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(
        context,
        'Choisir mon avatar',
        accentColor: profileGreen,
      ),
      body: StreamBuilder<ProfileAvatarCatalog>(
        stream: ProfileAvatarsService.instance.watchCatalog(),
        builder: (context, catSnap) {
          final catalog = catSnap.data ?? ProfileAvatarCatalog.empty;
          return StreamBuilder<String?>(
            stream: ProfileAvatarsService.instance.watchMyAvatarUrl(),
            builder: (context, mineSnap) {
              final selectedUrl = (mineSnap.data ?? '').trim();
              return ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottom),
                children: [
                  Text(
                    'Choisis un visage du catalogue DVCR. '
                    'Pas de photo personnelle — le club prépare les visuels.',
                    style: ProfileType.caption,
                  ),
                  const SizedBox(height: 18),
                  if (catSnap.connectionState == ConnectionState.waiting &&
                      catalog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: profileGreen,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (catalog.isEmpty)
                    DecoratedBox(
                      decoration: profilePaper(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                        child: Text(
                          'Les avatars arrivent bientôt.',
                          textAlign: TextAlign.center,
                          style: ProfileType.label.copyWith(
                            color: profileMutedText,
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: catalog.avatars.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, i) {
                        final a = catalog.avatars[i];
                        final selected = selectedUrl.isNotEmpty &&
                            a.url.trim() == selectedUrl;
                        final busy = _busyId == a.id;
                        return GestureDetector(
                          onTap: busy ? null : () => _pick(a),
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final s = c.maxWidth.clamp(
                                ProfileAvatar.displayLogicalMin,
                                ProfileAvatar.displayLogicalMax,
                              );
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  ProfileCatalogAvatar(
                                    url: a.url,
                                    size: s,
                                    selected: selected,
                                  ),
                                  if (busy)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: profileGold,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  if (selectedUrl.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: _clearing ? null : _clear,
                      child: Text(
                        _clearing ? 'Retrait…' : 'Retirer l’avatar',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: profileMutedText,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
