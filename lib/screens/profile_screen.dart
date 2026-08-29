import 'dart:async';

import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../navigation/main_shell_insets.dart';
import '../widgets/powered_by_partner_image.dart';
import '../navigation/app_store_safe_mode.dart';
import '../services/app_settings_service.dart';
import '../services/favorites_service.dart';
import '../services/helloasso_adhesion_service.dart';
import '../services/prono_social_service.dart';
import '../services/user_service.dart';
import '../services/xp_service.dart';
import '../widgets/donation_banner.dart';
import '../widgets/dvcr_member_role_badge.dart';
import '../widgets/live_match_quick_panel.dart';
import 'admin_web_screen.dart';
import 'notifications/notifications_center_screen.dart';
import 'profile/profile_account_screen.dart';
import 'profile/profile_favorites_screen.dart';
import 'profile/profile_hero_sliver.dart';
import 'profile/profile_membership_stamps.dart';
import 'profile/profile_palette.dart';
import 'profile/profile_shell_widgets.dart';
import 'profile/profile_type.dart';
import 'home/home_motion.dart';
import '../models/user_role.dart';
import '../services/benevole_space_service.dart';
import 'benevole/benevole_space_screen.dart';
import 'profile/motm_pitch_pickup_plate.dart';
import 'profile/match_rating_social_plate.dart';
import 'profile/match_sheet_share_plate.dart';

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
    case UserRole.donateur:
    case UserRole.supporter:
      return 'Supporter';
    case UserRole.teamDvcr:
      return UserRole.teamDvcr.displayName;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await UserService.getUserData().timeout(
        const Duration(seconds: 15),
      );
      final roles = UserService.parseRolesFromData(data);
      final role = UserService.primaryRole(roles);
      if (!mounted) return;
      setState(() {
        _userData = data;
        _roles = roles;
        _role = role;
        _profileHeroBgIndex =
            UserService.profileHeroBackgroundIndexFromData(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context);
  }

  void _openNotifications() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsCenterScreen(),
      ),
    );
  }

  void _openFavorites() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileFavoritesScreen(
          onSwitchMainTab: widget.onSwitchMainTab,
        ),
      ),
    );
  }

  void _openAccount() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const ProfileAccountScreen(),
      ),
    );
  }

  void _openBenevole() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const BenevoleSpaceScreen(),
      ),
    );
  }

  void _openAdmin() {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AdminWebScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: profileBg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: profileGreen,
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
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: _buildStatsStrip(context, user),
                    ),
                  ),
                ),
                if (UserService.canSeeMatchSheetShare(_roles))
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 34),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: MatchSheetSharePlate(),
                      ),
                    ),
                  ),
                if (UserService.canSeeMatchRatingSocialPlate(_roles))
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 36),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: MatchRatingSocialPlate(),
                      ),
                    ),
                  ),
                if (UserService.canSeeMotmPitchPickup(_roles))
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 42),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: MotmPitchPickupPlate(),
                      ),
                    ),
                  ),
                if (UserService.canPilotLiveFromProfile(_roles) ||
                    UserService.canEditLiveStatsFromApp(_roles))
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 48),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: LiveMatchQuickPanel(
                          canPilot:
                              UserService.canPilotLiveFromProfile(_roles),
                          canEditLiveStats:
                              UserService.canEditLiveStatsFromApp(_roles),
                          canLaunchMotm:
                              UserService.canLaunchMotmVote(_roles),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 52),
                    child: AppStoreMonetizationGate(
                      child: _buildPoweredByFooter(
                        context,
                        PoweredByPartnerSettings.defaults,
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
                if (_role == UserRole.admin)
                  SliverToBoxAdapter(
                    child: HomeReveal(
                      delay: const Duration(milliseconds: 170),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _ReportsSection(),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 185),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(6, 10, 6, 0),
                      child: DonationBanner(
                        slot: SoutenezDvcrBannerSlot.profile,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      children: [
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: profileHairline,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: profileRed.withValues(alpha: 0.88),
                          ),
                          label: Text(
                            'Se déconnecter',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: profileRed.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: MainShellInsets.tabScrollTail(context)),
                ),
              ],
            ),
    );
  }

  Widget _buildPoweredByFooter(
    BuildContext context,
    PoweredByPartnerSettings poweredBy,
  ) {
    final photoW = MediaQuery.sizeOf(context).width - 40;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DecoratedBox(
        decoration: profilePaper(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PARTENAIRE OFFICIEL', style: ProfileType.kicker),
              const SizedBox(height: 6),
              Text('PROPULSÉE PAR', style: ProfileType.title.copyWith(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                poweredBy.tagline,
                textAlign: TextAlign.center,
                style: ProfileType.caption,
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: PoweredByPartnerImage(
                    settings: poweredBy,
                    fit: BoxFit.cover,
                    width: photoW,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeroSliver(BuildContext context, User? user) {
    final firstName = (_userData?['firstName'] ?? '') as String;
    final lastName = (_userData?['lastName'] ?? '') as String;
    final fullName = '$firstName $lastName'.trim();
    final initials = (firstName.isNotEmpty ? firstName[0] : '') +
        (lastName.isNotEmpty ? lastName[0] : '');
    return ProfileHeroSliver.build(
      context,
      initialIndex: _profileHeroBgIndex,
      onPageChanged: (i) {
        if (!mounted || _profileHeroBgIndex == i) return;
        setState(() => _profileHeroBgIndex = i);
        unawaited(UserService.setProfileHeroBackgroundIndex(i));
      },
      onBack: () => Navigator.pop(context),
      onNotifications: _openNotifications,
      lockup: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          DvcrAvatarRoleFrame(
            roles: _roles,
            innerDiameter: 88,
            frameThickness: 7,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: profileSurface,
              ),
              alignment: Alignment.center,
              child: Text(
                initials.isEmpty ? '?' : initials.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: profileGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fullName.isEmpty
                ? (user?.email ?? UserRole.teamDvcr.displayName)
                : fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ProfileType.masthead.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          ProfileMembershipStampRow(
            roles: _roles,
            // Flag HelloAsso only — never amount, expiry, or receipt.
            isAdherentActive:
                HelloAssoAdhesionService.isAdherentActive(_userData),
            xp: XpService.displayXp(_userData),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildStatsStrip(BuildContext context, User? user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _profileStatCell(
            icon: Icons.workspace_premium_rounded,
            title: _roleLabel(_role),
            subtitle: 'Rôle',
            onTap: null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: user == null
              ? _profileStatCell(
                  icon: Icons.stadium_outlined,
                  title: '0 PTS',
                  subtitle: 'Pronos',
                  onTap: null,
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: PronoSocialService.leaderboardEntryStream(user.uid),
                  builder: (context, lbSnap) {
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: PronoSocialService.userDocStream(user.uid),
                      builder: (context, userSnap) {
                        final merged = PronoSocialService
                            .mergeLeaderboardAndPronoProfileForXp(
                          lbSnap.data?.data(),
                          userSnap.data?.data(),
                        );
                        final points = (merged['points'] as num?)?.toInt() ?? 0;
                        return _profileStatCell(
                          icon: Icons.stadium_outlined,
                          title: '$points PTS',
                          subtitle: 'Pronos',
                          onTap: null,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _profileStatCell({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final child = DecoratedBox(
      decoration: profilePaper(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, color: profileGreen, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ProfileType.figure.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ProfileType.caption,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final adminish = UserService.canAccessAdminPanel(_roles);
    final isTeamDvcr = _roles.contains(UserRole.teamDvcr);

    return StreamBuilder(
      stream: BenevoleSpaceService.instance.watchConfig(),
      builder: (context, cfgSnap) {
        final configEnabled = cfgSnap.data?.enabled ?? true;
        final isDvcrAdmin =
            _roles.contains(UserRole.admin) || _role == UserRole.admin;
        final showBenevoleShortcut =
            configEnabled && (isTeamDvcr || isDvcrAdmin);
        final benevoleSubtitle = isDvcrAdmin && !isTeamDvcr
            ? 'PDF et planning — même vue que les bénévoles (aperçu admin).'
            : 'Documents PDF et planning — réservé Team DVCR.';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileSectionHeader(
              showBadge: false,
              title: 'Raccourcis',
              subtitle: 'Tes favoris, tes alertes et les réglages du compte.',
              icon: Icons.flash_on_rounded,
              accent: profileGreenBright,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                children: [
                  ProfileActionRow(
                    icon: Icons.bookmark_added_rounded,
                    title: 'Mes favoris',
                    subtitle:
                        'Articles, matchs et replays enregistrés depuis l’app.',
                    onTap: _openFavorites,
                  ),
                  ProfileActionRow(
                    icon: Icons.notifications_active_rounded,
                    title: 'Mes alertes',
                    subtitle:
                        'Live, actus, scores et mentions — centre de notifications.',
                    onTap: _openNotifications,
                  ),
                  ProfileActionRow(
                    icon: Icons.tune_rounded,
                    title: 'Compte',
                    subtitle:
                        'E-mail, mot de passe, notif. push, équipe favorite, suppression des données.',
                    onTap: _openAccount,
                  ),
                  if (showBenevoleShortcut)
                    ProfileActionRow(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Bénévoles',
                      subtitle: benevoleSubtitle,
                      onTap: _openBenevole,
                    ),
                  if (adminish)
                    ProfileActionRow(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin',
                      subtitle:
                          'Pilotage, signalements et score live (accès équipe DVCR).',
                      onTap: _openAdmin,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReportsSection extends StatelessWidget {
  const _ReportsSection();

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
            const ProfileInlineSectionTitle(
              title: 'Signalements',
              icon: Icons.flag_outlined,
              accent: profileRed,
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: profilePaper(
                    edge: profileRed.withValues(alpha: 0.28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['reportedName'] ?? 'Membre',
                          style: ProfileType.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${d['messageText'] ?? ''}"',
                          style: ProfileType.caption.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                                    DateTime.now()
                                        .add(const Duration(hours: 24)),
                                  ),
                                });
                                await doc.reference.update({'status': 'banned'});
                              },
                              child: Text(
                                'Bannir 24h',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: profileRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () =>
                                  doc.reference.update({'status': 'ignored'}),
                              child: Text(
                                'Ignorer',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: profileMutedText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
