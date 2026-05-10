import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/world_cup_tab_rollout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_settings_service.dart';
import '../utils/remote_image_url.dart';
import '../services/feature_flags_service.dart';
import '../widgets/powered_by_partner_image.dart';
import '../services/favorites_service.dart';
import '../services/user_service.dart';
import '../widgets/donation_banner.dart';
import '../widgets/dvcr_member_role_badge.dart';
import '../widgets/live_match_quick_panel.dart';
import 'admin_web_screen.dart';
import 'notifications/notifications_center_screen.dart';
import 'profile/profile_account_screen.dart';
import 'profile/profile_favorites_screen.dart';
import 'home/home_palette.dart';
import 'home/home_shell_widgets.dart';
import 'home/home_motion.dart';
import 'world_cup_tab.dart';

// Helpers rôle
String _roleLabel(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.communityManager:
      return 'CM';
    case UserRole.editor:
      return 'Éditeur';
    case UserRole.statisticien:
      return 'Stats';
    case UserRole.partenaire:
      return 'Partenaire';
    case UserRole.donateur:
      return 'Donateur';
    case UserRole.teamDvcr:
      return 'Membre DVCR';
    case UserRole.supporter:
      return 'Supporter';
  }
}

class ProfileScreen extends StatefulWidget {
  /// Même signature que l’accueil : bascule un onglet du `MainNavigation`.
  final void Function(int tabIndex, {int? matchesSubTab})? onSwitchMainTab;

  const ProfileScreen({super.key, this.onSwitchMainTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  UserRole _role = UserRole.supporter;
  Set<UserRole> _roles = {UserRole.supporter};
  bool _loading = true;
  int _profileHeroBgIndex = 0;
  Map<String, String> _roleBadges = {};
  StreamSubscription<RoleBadgeSettings>? _roleBadgesSub;

  @override
  void initState() {
    super.initState();
    _roleBadgesSub = AppSettingsService.roleBadgesStream().listen((s) {
      if (!mounted) return;
      setState(() => _roleBadges = s.badges);
    });
    _load();
  }

  @override
  void dispose() {
    _roleBadgesSub?.cancel();
    super.dispose();
  }

  /// Onglet CdM (6) en gardant la barre du bas : ferme le profil puis bascule.
  void _openWorldCupMainTab() {
    final fn = widget.onSwitchMainTab;
    if (fn != null) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fn(WorldCupTabRollout.targetMainTabIndexOrHome());
      });
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const WorldCupTab(),
      ),
    );
  }

  Future<void> _load() async {
    final data  = await UserService.getUserData();
    final roles = UserService.parseRolesFromData(data);
    final role  = UserService.primaryRole(roles);
    if (mounted) {
      setState(() {
        _userData = data;
        _roles = roles;
        _role = role;
        _profileHeroBgIndex = UserService.profileHeroBackgroundIndexFromData(data);
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: homeBg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: homeGreen,
                strokeWidth: 2,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildProfileHeroSliver(context, user),
                SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 30),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: _buildStatsStrip(context, user),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 45),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: DonationBanner(
                        donationUrl: 'https://www.helloasso.com',
                        photoAsset:
                            'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                        title: 'SOUTENEZ DVCR',
                        subtitle: 'Chaque don nous aide à grandir',
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 60),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildDashboard(context),
                    ),
                  ),
                ),

                if (_role == UserRole.admin || _role == UserRole.communityManager)
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: const LiveMatchQuickPanel(),
                      ),
                    ),
                  ),

                if (_role == UserRole.admin)
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 170),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: _ReportsSection(),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 185),
                    // Encart fixe : toujours l’asset Cartevisiteaxel08 + tagline par défaut.
                    // La config admin `powered_by_partner` alimente prono & Coupe du monde ; ici reste fixe.
                    child: _buildPoweredByFooter(
                      context,
                      PoweredByPartnerSettings.defaults,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
                    child: Column(
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: homeBorder.withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: homeRed.withValues(alpha: 0.88),
                          ),
                          label: Text(
                            'Se déconnecter',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: homeRed.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }

  Widget _buildPoweredByFooter(
    BuildContext context,
    PoweredByPartnerSettings poweredBy,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        homeGold.withValues(alpha: 0.35),
                        homeGold,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.electric_bolt_rounded,
                      color: homeGold,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.bolt_rounded,
                      color: homeGold.withValues(alpha: 0.75),
                      size: 18,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        homeGold,
                        homeGold.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  homeGreen,
                  homeGreenDeep,
                  const Color(0xFF041A15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: homeGold.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: homeGreenDeep.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
            child: Container(
              decoration: BoxDecoration(
                color: homeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: homeGold.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: homeGold.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      'PARTENAIRE OFFICIEL',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: homeGreenDeep,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PROPULSÉE PAR',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: homeGreen,
                      letterSpacing: 1.2,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poweredBy.tagline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: homeMutedText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: homeGreenDeep.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: homeGold.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 3 / 2,
                              child: PoweredByPartnerImage(
                                settings: poweredBy,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ),
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

  /// Héros pleine largeur + coins bas arrondis, réduction au scroll (comme accueil / actus).
  Widget _buildProfileHeroSliver(BuildContext context, User? user) {
    final topPad = MediaQuery.paddingOf(context).top;
    const toolbarH = 52.0;
    final expandedH = topPad + toolbarH + 248;

    final firstName = (_userData?['firstName'] ?? '') as String;
    final lastName = (_userData?['lastName'] ?? '') as String;
    final fullName = '$firstName $lastName'.trim();
    final initials = (firstName.isNotEmpty ? firstName[0] : '') +
        (lastName.isNotEmpty ? lastName[0] : '');
    final visible = (_roles.length > 1
            ? _roles.where((r) => r != UserRole.supporter).toList()
            : _roles.toList())
          ..sort(
            (a, b) => UserService.rolePriority
                .indexOf(a)
                .compareTo(UserService.rolePriority.indexOf(b)),
          );

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedH,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      // Transparent comme l’accueil / actus : la photo reste visible sous la barre au scroll.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      forceMaterialTransparency: true,
      toolbarHeight: toolbarH,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leadingWidth: 52,
      leading: Center(
        child: HomeToolbarButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: HomeToolbarButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsCenterScreen(),
                ),
              );
            },
          ),
        ),
      ],
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: FlexibleSpaceBar(
          // Pin = la photo reste lisible en tête comme DVCR TV / actus (pas seulement un fond qui file).
          collapseMode: CollapseMode.pin,
          stretchModes: const [
            StretchMode.zoomBackground,
          ],
          background: StreamBuilder<ProfileHeroBackgroundSettings>(
            stream: AppSettingsService.profileHeroBackgroundsStream(),
            builder: (context, cfgSnap) {
              final cfg =
                  cfgSnap.data ?? ProfileHeroBackgroundSettings.defaults;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _ProfileHeroBackgroundLayers(
                    urls: cfg.urls,
                    revisionMillis: cfg.revisionMillis,
                    initialIndex: _profileHeroBgIndex,
                    onPageChanged: (i) {
                      if (!mounted || _profileHeroBgIndex == i) return;
                      setState(() => _profileHeroBgIndex = i);
                      unawaited(UserService.setProfileHeroBackgroundIndex(i));
                    },
                  ),
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(18, topPad + toolbarH + 4, 18, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DvcrAvatarRoleFrame(
                          roles: _roles,
                          innerDiameter: 88,
                          frameThickness: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: homeSurface,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                                width: 2.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isEmpty ? '?' : initials.toUpperCase(),
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: homeGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fullName.isEmpty
                              ? (user?.email ?? 'Membre DVCR')
                              : fullName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            height: 1.05,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: visible.map((r) {
                            if (dvcrRoleUsesTierBadge(r)) {
                              return DvcrChatRoleCapsule(
                                role: r,
                                small: false,
                                badgeImageUrl:
                                    _roleBadges[roleBadgeConfigKey(r)]?.trim(),
                              );
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                _roleLabel(r).toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.55,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatsStrip(BuildContext context, User? user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: homeSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: homeBorder),
        boxShadow: [
          BoxShadow(
            color: homeGreenDeep.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: FeatureFlagsService.notifier,
        builder: (context, _) {
          final wcOn = WorldCupTabRollout.isTabVisible;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _profileStatCell(
                    icon: Icons.workspace_premium_rounded,
                    accent: homeGold,
                    title: _roleLabel(_role),
                    subtitle: 'Rôle',
                    onTap: null,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: homeBorder.withValues(alpha: 0.8),
                ),
                Expanded(
                  child: user == null
                      ? _profileStatCell(
                          icon: Icons.bookmark_border_rounded,
                          accent: homeGreen,
                          title: '0',
                          subtitle: 'Favoris',
                          onTap: null,
                        )
                      : StreamBuilder<List<FavoriteEntry>>(
                          stream: FavoritesService.watchAll(),
                          builder: (context, snap) {
                            final n = snap.data?.length ?? 0;
                            return _profileStatCell(
                              icon: Icons.bookmark_added_rounded,
                              accent: homeGreen,
                              title: '$n',
                              subtitle: 'Favoris',
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProfileFavoritesScreen(
                                      onSwitchMainTab:
                                          widget.onSwitchMainTab,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                if (wcOn) ...[
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    color: homeBorder.withValues(alpha: 0.8),
                  ),
                  Expanded(
                    child: _profileStatCell(
                      icon: Icons.public_rounded,
                      accent: homeRed,
                      title: 'CdM',
                      subtitle: '2026',
                      onTap: user == null ? null : _openWorldCupMainTab,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profileStatCell({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: homeText,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: homeMutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final adminish = _role == UserRole.admin ||
        _role == UserRole.communityManager ||
        _role == UserRole.editor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          showBadge: false,
          title: 'RACCOURCIS',
          subtitle: 'Tes favoris, tes alertes et les réglages du compte.',
          icon: Icons.flash_on_rounded,
          accent: homeGold,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          // Hauteur bornée : sinon la Row (dans une Column de scroll) a maxHeight = ∞
          // et les cartes reçoivent une hauteur infinie → Expanded interne invalide.
          child: SizedBox(
            height: HomeWideActionCard.layoutHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Expanded(
                child: HomeWideActionCard(
                  icon: Icons.bookmark_added_rounded,
                  title: 'Mes favoris',
                  subtitle:
                      'Articles, matchs et replays enregistrés depuis l’app.',
                  accent: homeGreen,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileFavoritesScreen(
                          onSwitchMainTab: widget.onSwitchMainTab,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HomeWideActionCard(
                  icon: Icons.notifications_active_rounded,
                  title: 'Mes alertes',
                  subtitle:
                      'Live, actus, scores et mentions — centre de notifications.',
                  accent: homeRed,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsCenterScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: SizedBox(
            height: 196,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Expanded(
                child: HomeWideActionCard(
                  icon: Icons.tune_rounded,
                  title: 'Compte',
                  subtitle:
                      'E-mail, mot de passe, notif. push, équipe favorite, suppression des données.',
                  accent: homeGold,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileAccountScreen(),
                      ),
                    );
                  },
                ),
              ),
              if (adminish) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: HomeWideActionCard(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Admin',
                    subtitle:
                        'Pilotage, signalements et score live (accès équipe DVCR).',
                    accent: homeRed,
                    onTap: () {
                      // Navigateur racine : l’admin ne doit pas rester sous le
                      // Navigator de l’onglet Accueil (sinon double barre du bas).
                      Navigator.of(context, rootNavigator: true).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminWebScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
      ],
    );
  }

}

/// PageView (3 fonds) + dégradés + pastilles — sous la colonne avatar du sliver.
class _ProfileHeroBackgroundLayers extends StatefulWidget {
  const _ProfileHeroBackgroundLayers({
    required this.urls,
    required this.revisionMillis,
    required this.initialIndex,
    required this.onPageChanged,
  });

  final List<String> urls;
  final int revisionMillis;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;

  @override
  State<_ProfileHeroBackgroundLayers> createState() =>
      _ProfileHeroBackgroundLayersState();
}

class _ProfileHeroBackgroundLayersState
    extends State<_ProfileHeroBackgroundLayers> {
  late PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, 2);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(covariant _ProfileHeroBackgroundLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final next = widget.initialIndex.clamp(0, 2);
      if (_page != next && _pageController.hasClients) {
        _pageController.jumpToPage(next);
        setState(() => _page = next);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _pageImage(String url) {
    const align = Alignment(0, -0.28);
    const asset = ProfileHeroBackgroundSettings.defaultAssetPath;
    final trimmed = url.trim();
    Widget fallback() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [homeGreen, homeGreenDeep],
            ),
          ),
        );
    if (trimmed.isEmpty) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: align,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }
    final busted = cacheBustedImageUrl(trimmed, widget.revisionMillis);
    return Image.network(
      busted,
      fit: BoxFit.cover,
      alignment: align,
      headers: kDvcrImageHttpHeaders,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: align,
        errorBuilder: (c, e, s) => fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.urls.length >= 3
        ? widget.urls
        : [
            ...widget.urls,
            ...List.filled(3 - widget.urls.length, ''),
          ];

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (i) {
            setState(() => _page = i);
            widget.onPageChanged(i);
          },
          children: [
            _pageImage(u[0]),
            _pageImage(u[1]),
            _pageImage(u[2]),
          ],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                homeGreen.withValues(alpha: 0.45),
                homeGreenDeep.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.85, -0.55),
              radius: 1.15,
              colors: [
                homeGold.withValues(alpha: 0.28),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = _page == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.38),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// --- Signalements (admin) ---
class _ReportsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: homeRed, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text('SIGNALEMENTS',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: homeMutedText, letterSpacing: 1.5,
                  )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: homeRed.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: homeRed.withAlpha(80)),
                  ),
                  child: Text('${docs.length}',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: homeRed,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: homeSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: homeBorder),
                  boxShadow: [
                    BoxShadow(
                      color: homeRed.withAlpha(12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['reportedName'] ?? 'Membre',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: homeText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('"${d['messageText'] ?? ''}"',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: homeMutedText,
                            fontStyle: FontStyle.italic),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(d['reportedUid'] as String)
                                .update({
                                  'chatBannedUntil': Timestamp.fromDate(
                                      DateTime.now().add(const Duration(hours: 24))),
                                });
                            await doc.reference.update({'status': 'banned'});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: homeRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: homeRed.withAlpha(80)),
                            ),
                            child: Text('Bannir 24h',
                              style: GoogleFonts.inter(
                                fontSize: 12, color: homeRed,
                                fontWeight: FontWeight.w600,
                              )),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => doc.reference.update({'status': 'ignored'}),
                          child: Text('Ignorer',
                            style: GoogleFonts.inter(fontSize: 12, color: homeMutedText)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

