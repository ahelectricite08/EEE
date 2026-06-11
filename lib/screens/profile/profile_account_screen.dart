import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_router.dart';
import '../../navigation/community_chat_rollout.dart';
import '../../navigation/prono_championship_rollout.dart';
import '../../services/account_deletion_service.dart';
import '../../services/auth_service.dart';
import '../../services/feature_flags_service.dart';
import '../../services/live_match_activity_service.dart';
import '../../services/notification_prefs_service.dart';
import '../../services/referral_service.dart';
import '../../services/team_dvcr_members_service.dart';
import '../../services/user_preferences_service.dart';
import '../../widgets/favorite_team_picker_sheet.dart';
import '../tutorial/tutorial_screen.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';

enum _IconBadgeStyle { green, gold }

Widget _accountIconBadge(
  IconData icon,
  _IconBadgeStyle style, {
  Color? iconColor,
}) {
  final useGold = style == _IconBadgeStyle.gold;
  final fill = useGold
      ? profileGold.withValues(alpha: 0.12)
      : profileGreen.withValues(alpha: 0.09);
  final border = useGold
      ? profileGold.withValues(alpha: 0.32)
      : profileGreen.withValues(alpha: 0.18);
  final ic = iconColor ?? (useGold ? profileGold : profileGreen);
  return Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
    ),
    child: Icon(icon, size: 19, color: ic),
  );
}

/// Compte, mot de passe, équipe favorite et notifications (préférences FCM).
class ProfileAccountScreen extends StatefulWidget {
  const ProfileAccountScreen({super.key});

  @override
  State<ProfileAccountScreen> createState() => _ProfileAccountScreenState();
}

class _ProfileAccountScreenState extends State<ProfileAccountScreen> {
  bool _notifLive = true;
  bool _notifLiveStickyScore = true;
  bool _notifAlerts = true;
  bool _notifActus = true;
  bool _notifLiveEvents = true;
  bool _notifChatMention = true;
  bool _notifFriendRequest = true;
  bool _notifDuelInvite = true;
  bool _notifDuelResult = true;
  bool _notifPronoPointsRecap = true;
  String _myReferralCode = '';
  int _referralCount = 0;
  int _referralXpEarned = 0;
  bool _hasUsedReferralCode = false;
  bool _referralLoading = true;
  String? _favoriteTeam;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(UserPreferencesService.instance.init());
    UserPreferencesService.instance.addListener(_onPrefsSvc);
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    _loadPrefs();
    _loadReferralData();
  }

  @override
  void dispose() {
    UserPreferencesService.instance.removeListener(_onPrefsSvc);
    super.dispose();
  }

  void _onPrefsSvc() {
    if (!mounted) return;
    final next = UserPreferencesService.instance.favoriteTeam;
    if (_favoriteTeam == next) return;
    setState(() => _favoriteTeam = next);
  }

  bool _hasFavoriteTeam() =>
      _favoriteTeam != null && _favoriteTeam!.trim().isNotEmpty;

  String _favoriteTeamLabel() =>
      _hasFavoriteTeam() ? _favoriteTeam!.toUpperCase() : 'Non définie';

  static bool _userSkipsChatMentionPushToggle(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    final role = data['role']?.toString().trim().toLowerCase() ?? '';
    if (role == 'admin') return true;
    final rolesRaw = data['roles'];
    if (rolesRaw is List) {
      for (final r in rolesRaw) {
        if (r.toString().trim().toLowerCase() == 'admin') return true;
      }
    }
    return TeamDvcrMembersService.isTeamDvcrMember(data);
  }

  void _applyPrefsFromSharedPreferences(SharedPreferences prefs) {
    bool g(String k) => prefs.getBool(k) ?? true;
    final pronoRecap = g('notif_prono_points_recap');
    _notifLive = g('notif_live');
    _notifLiveStickyScore = g('notif_live_sticky_score');
    _notifAlerts = g('notif_alerts');
    _notifActus = g('notif_actus');
    _notifLiveEvents = g('notif_live_events');
    _notifChatMention = g('notif_chat_mention');
    _notifFriendRequest = g('notif_friend_request');
    _notifDuelInvite = g('notif_duel_invite');
    _notifDuelResult = g('notif_duel_result');
    _notifPronoPointsRecap = pronoRecap;
    _prefsLoaded = true;
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _applyPrefsFromSharedPreferences(prefs));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      unawaited(_syncPrefsFromRemote(uid));
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  /// Firestore + topic FCM : ne bloque pas l’affichage de la page.
  Future<void> _syncPrefsFromRemote(String uid) async {
    try {
      await NotificationPrefsService.pullFromFirestoreAndCacheLocal(uid).timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {}

    try {
      await FirebaseMessaging.instance
          .subscribeToTopic('dvcr_notifications')
          .timeout(const Duration(seconds: 8));
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final pronoRecap = prefs.getBool('notif_prono_points_recap') ?? true;
      final rankingMotivation =
          prefs.getBool('notif_ranking_motivation') ?? true;
      if (pronoRecap != rankingMotivation) {
        await NotificationPrefsService.updateFirestoreAndLocal(
          uid: uid,
          firestoreKey: 'rankingMotivation',
          value: pronoRecap,
        ).timeout(const Duration(seconds: 12));
      }
      if (!mounted) return;
      setState(() => _applyPrefsFromSharedPreferences(prefs));
    } catch (_) {}
  }

  Future<void> _persistTopic(String fsKey, String topic, bool v, void Function(bool) apply) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationPrefsService.updateFirestoreAndLocal(
        uid: uid,
        firestoreKey: fsKey,
        value: v,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final sp = NotificationPrefsService.keys[fsKey];
      if (sp != null) await prefs.setBool(sp, v);
    }
    final f = FirebaseMessaging.instance;
    if (v) {
      await f.subscribeToTopic(topic);
    } else {
      await f.unsubscribeFromTopic(topic);
    }
    if (mounted) setState(() => apply(v));
  }

  Future<void> _persistFlag(String fsKey, bool v, void Function(bool) apply) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationPrefsService.updateFirestoreAndLocal(
        uid: uid,
        firestoreKey: fsKey,
        value: v,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final sp = NotificationPrefsService.keys[fsKey];
      if (sp != null) await prefs.setBool(sp, v);
    }
    if (mounted) setState(() => apply(v));
  }

  Future<void> _toggleLive(bool v) async =>
      _persistTopic('live', 'dvcr_live', v, (x) => _notifLive = x);

  Future<void> _toggleLiveStickyScore(bool v) async {
    await _persistFlag('liveStickyScore', v, (x) => _notifLiveStickyScore = x);
    await LiveMatchActivityService.setEnabled(v);
  }

  Future<void> _toggleAlerts(bool v) async =>
      _persistTopic('alerts', 'dvcr_alerts', v, (x) => _notifAlerts = x);

  Future<void> _toggleActus(bool v) async =>
      _persistTopic('articles', 'dvcr_articles', v, (x) => _notifActus = x);

  Future<void> _toggleLiveEvents(bool v) async =>
      _persistTopic('liveEvents', 'dvcr_live_events', v, (x) => _notifLiveEvents = x);

  Future<void> _toggleChatMention(bool v) async =>
      _persistFlag('chatMention', v, (x) => _notifChatMention = x);

  Future<void> _toggleFriendRequest(bool v) async =>
      _persistFlag('friendRequest', v, (x) => _notifFriendRequest = x);

  Future<void> _toggleDuelInvite(bool v) async =>
      _persistFlag('duelInvite', v, (x) => _notifDuelInvite = x);

  Future<void> _toggleDuelResult(bool v) async =>
      _persistFlag('duelResult', v, (x) => _notifDuelResult = x);

  Future<void> _togglePronoPointsRecap(bool v) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationPrefsService.updateFirestoreAndLocal(
        uid: uid,
        firestoreKey: 'pronoPointsRecap',
        value: v,
      );
      await NotificationPrefsService.updateFirestoreAndLocal(
        uid: uid,
        firestoreKey: 'rankingMotivation',
        value: v,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_prono_points_recap', v);
      await prefs.setBool('notif_ranking_motivation', v);
    }
    if (mounted) setState(() => _notifPronoPointsRecap = v);
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de réinitialisation envoyé.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.errorMessage(e))),
      );
    }
  }

  Future<void> _replayTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_done_v1', false);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TutorialScreen(
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _editFavoriteTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: profileSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FavoriteTeamPickerSheet(current: _favoriteTeam),
    );
    if (!mounted || picked == null) return;

    final v = picked.trim();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'favoriteTeam': v.isEmpty ? FieldValue.delete() : v},
      SetOptions(merge: true),
    );
  }

  Future<void> _loadReferralData() async {
    try {
      final code = await ReferralService.ensureCode();
      Map<String, dynamic>? stats;
      try {
        stats = await ReferralService.getStats();
      } catch (_) {
        stats = null;
      }
      final hasUsed = await ReferralService.hasBeenReferred();
      if (!mounted) return;
      setState(() {
        _myReferralCode = code.trim();
        _referralCount = (stats?['referralCount'] as num?)?.toInt() ?? 0;
        _referralXpEarned = (stats?['xpEarned'] as num?)?.toInt() ?? 0;
        _hasUsedReferralCode = hasUsed;
        _referralLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _referralLoading = false);
    }
  }

  Future<void> _copyReferralCode() async {
    final code = _myReferralCode.isNotEmpty
        ? _myReferralCode
        : await ReferralService.ensureCode();
    if (code.isEmpty || !mounted) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code parrainage copié.')),
    );
    setState(() => _myReferralCode = code);
  }

  Future<void> _promptUseReferralCode() async {
    if (_hasUsedReferralCode) return;
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: profileSurface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Utiliser un code parrain',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            color: profileGreen,
          ),
        ),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Ex. DVCRAB12CD',
            hintStyle: GoogleFonts.inter(color: profileMutedText),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.inter(color: profileMutedText)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: profileGreen),
            child: Text('Valider', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final trimmed = (code ?? '').trim();
    if (trimmed.isEmpty) return;
    try {
      await ReferralService.useCode(trimmed);
      await _loadReferralData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code parrainage appliqué.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code invalide: $e')),
      );
    }
  }

  String _lastSignInLabel(User u) {
    final d = u.metadata.lastSignInTime;
    if (d == null) return '—';
    const months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    final t =
        '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$t • $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(context, 'Compte', accentColor: profileGold),
      body: !_prefsLoaded
          ? const Center(
              child: CircularProgressIndicator(
                color: profileGold,
                strokeWidth: 2,
              ),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8F5ED),
                    profileBg,
                    Color(0xFFEDE8DC),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 28 + bottom),
                children: [
                  const _AccountHeroCard(),
                  const SizedBox(height: 22),
                  _card(
                    children: [
                      _infoRow(
                        icon: Icons.alternate_email_rounded,
                        title: 'E-mail',
                        subtitle: user?.email ?? '—',
                      ),
                      _divider(),
                      _infoRow(
                        icon: Icons.schedule_rounded,
                        title: 'Dernière connexion',
                        subtitle: user != null ? _lastSignInLabel(user) : '—',
                      ),
                      _divider(),
                      _linkRow(
                        icon: Icons.lock_outline_rounded,
                        title: 'Changer mon mot de passe',
                        subtitle: 'Recevoir un lien sécurisé par e-mail.',
                        onTap: _sendPasswordReset,
                      ),
                      _divider(),
                      _linkRow(
                        icon: Icons.school_outlined,
                        title: 'Revoir le tuto',
                        subtitle: 'Relancer la présentation de l’appli.',
                        onTap: _replayTutorial,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _card(
                    children: [
                      _linkRow(
                        icon: Icons.star_rounded,
                        iconBadge: _IconBadgeStyle.gold,
                        iconColor: profileGold,
                        title: 'Mon équipe favorite',
                        subtitle: _favoriteTeamLabel(),
                        titleColor: _hasFavoriteTeam()
                            ? profileGold
                            : profileMutedText,
                        subtitleStyle: _hasFavoriteTeam()
                            ? GoogleFonts.barlowCondensed(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: profileGold,
                                letterSpacing: 0.35,
                                height: 1.15,
                              )
                            : null,
                        onTap: _editFavoriteTeam,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _card(
                    children: [
                      _linkRow(
                        icon: Icons.redeem_rounded,
                        iconBadge: _IconBadgeStyle.gold,
                        iconColor: profileGold,
                        title: 'Mon code parrainage',
                        subtitle: _referralLoading
                            ? 'Chargement...'
                            : (_myReferralCode.isEmpty
                                ? 'Code indisponible'
                                : _myReferralCode),
                        titleColor: profileGold,
                        subtitleStyle: _myReferralCode.isEmpty
                            ? null
                            : GoogleFonts.barlowCondensed(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: profileText,
                                letterSpacing: 1.0,
                              ),
                        onTap: _copyReferralCode,
                      ),
                      _divider(),
                      _hasUsedReferralCode
                          ? _infoRow(
                              icon: Icons.verified_rounded,
                              title: 'Code parrain déjà utilisé',
                              subtitle:
                                  'Ton compte a déjà été rattaché à un parrain.',
                            )
                          : _linkRow(
                              icon: Icons.qr_code_2_rounded,
                              title: 'Saisir un code parrain',
                              subtitle: 'Associer ton compte à un parrain.',
                              onTap: _promptUseReferralCode,
                            ),
                      _divider(),
                      _infoRow(
                        icon: Icons.groups_rounded,
                        title: 'Parrainages validés',
                        subtitle:
                            '$_referralCount filleul(s) · +$_referralXpEarned XP',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const ProfileInlineSectionTitle(
                    title: 'Matchs',
                    icon: Icons.sports_soccer_rounded,
                    accent: profileGold,
                  ),
                  const SizedBox(height: 12),
                  _card(
                    children: [
                      _switchRow(
                        icon: Icons.notifications_active_outlined,
                        label: 'Début de match ou émission',
                        value: _notifLive,
                        onChanged: _toggleLive,
                      ),
                      _divider(),
                      _switchRow(
                        icon: Icons.scoreboard_rounded,
                        label: 'Score sur écran de verrouillage',
                        subtitle:
                            'Pendant le direct : bannière live (iPhone) ou score fixe sur le verrouillage Android.',
                        value: _notifLiveStickyScore,
                        onChanged: _toggleLiveStickyScore,
                      ),
                      _divider(),
                      _switchRow(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Buts et cartons jaunes/rouges',
                        value: _notifLiveEvents,
                        onChanged: _toggleLiveEvents,
                      ),
                      _divider(),
                      _switchRow(
                        icon: Icons.flag_outlined,
                        label: 'Mi-temps et fin de match',
                        value: _notifAlerts,
                        onChanged: _toggleAlerts,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<Map<String, dynamic>>(
                    valueListenable: FeatureFlagsService.notifier,
                    builder: (context, _, __) {
                      final chatOn = CommunityChatRollout.isVisible;
                      final pronoOn = PronoChampionshipRollout.isHubVisible;
                      if (!chatOn && !pronoOn) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (chatOn) ...[
                            const ProfileInlineSectionTitle(
                              title: 'Communauté',
                              icon: Icons.people_outline,
                              accent: profileGold,
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: user == null
                                  ? null
                                  : FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .snapshots(),
                              builder: (context, userSnap) {
                                final udata = userSnap.data?.data();
                                final hideMentionToggle =
                                    _userSkipsChatMentionPushToggle(udata);
                                return _card(
                                  children: [
                                    if (!hideMentionToggle) ...[
                                      _switchRow(
                                        icon: Icons.alternate_email_rounded,
                                        label: 'Mentions dans le chat',
                                        subtitle:
                                            'Quand quelqu’un te cite avec @ dans un message.',
                                        value: _notifChatMention,
                                        onChanged: _toggleChatMention,
                                      ),
                                      _divider(),
                                    ],
                                    _switchRow(
                                      icon: Icons.person_add_alt_1_outlined,
                                      label: 'Demandes d’amis',
                                      value: _notifFriendRequest,
                                      onChanged: _toggleFriendRequest,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (pronoOn) ...[
                            const ProfileInlineSectionTitle(
                              title: 'Pronos',
                              icon: Icons.stadium_outlined,
                              accent: profileGold,
                            ),
                            const SizedBox(height: 12),
                            _card(
                              children: [
                                _switchRow(
                                  icon: Icons.sports_kabaddi_rounded,
                                  label: 'Invitation à un duel prono',
                                  value: _notifDuelInvite,
                                  onChanged: _toggleDuelInvite,
                                ),
                                _divider(),
                                _switchRow(
                                  icon: Icons.emoji_events_outlined,
                                  label: 'Résultat de tes duels',
                                  value: _notifDuelResult,
                                  onChanged: _toggleDuelResult,
                                ),
                                _divider(),
                                _switchRow(
                                  icon: Icons.stacked_line_chart_rounded,
                                  label: 'Points prono (championnat)',
                                  subtitle:
                                      'Récap après les matchs · parfois un clin d’œil discret à ta place au classement si tu es actif (très peu fréquent).',
                                  value: _notifPronoPointsRecap,
                                  onChanged: _togglePronoPointsRecap,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      );
                    },
                  ),
                  const ProfileInlineSectionTitle(
                    title: 'Contenu',
                    icon: Icons.article_outlined,
                    accent: profileGold,
                  ),
                  const SizedBox(height: 12),
                  _card(
                    children: [
                      _switchRow(
                        icon: Icons.article_outlined,
                        label: 'Nouvelles actus et contenus DVCR',
                        value: _notifActus,
                        onChanged: _toggleActus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _deleteAccountSection(context),
                ],
              ),
            ),
    );
  }

  static const _pushTopics = [
    'dvcr_live',
    'dvcr_alerts',
    'dvcr_articles',
    'dvcr_live_events',
    'dvcr_notifications',
  ];

  Future<void> _unsubscribeAllPushTopics() async {
    final f = FirebaseMessaging.instance;
    for (final t in _pushTopics) {
      try {
        await f.unsubscribeFromTopic(t);
      } catch (_) {}
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (!AccountDeletionService.currentUserHasPasswordProvider) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: profileSurface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Supprimer le compte',
            style: GoogleFonts.barlowCondensed(
              fontWeight: FontWeight.w900,
              color: profileGreen,
            ),
          ),
          content: Text(
            'Tu es connecté avec Google ou Apple : la suppression automatique '
            'depuis l’app n’est pas disponible pour cette méthode. '
            'Écris-nous via le site officiel DVCR pour exercer ton droit à '
            'l’effacement (RGPD) — nous traiterons la demande et supprimerons tes données.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: profileMutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: GoogleFonts.inter(color: profileGreen)),
            ),
          ],
        ),
      );
      return;
    }

    var agreed = false;
    final pwdCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            backgroundColor: profileSurface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Supprimer définitivement ?',
              style: GoogleFonts.barlowCondensed(
                fontWeight: FontWeight.w900,
                color: profileRed,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conformément au RGPD, tu peux demander l’effacement de ton compte. '
                    'Tes favoris, ton profil et les traces liées à ton compte seront supprimés '
                    'côté application (dans la limite des données encore nécessaires au service). '
                    'Tu seras déconnecté immédiatement.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: profileMutedText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: agreed,
                    onChanged: (v) => setS(() => agreed = v ?? false),
                    title: Text(
                      'Je comprends que cette action est irréversible.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: profileText,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pwdCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe actuel',
                      labelStyle: GoogleFonts.inter(color: profileMutedText, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annuler', style: GoogleFonts.inter(color: profileMutedText)),
              ),
              TextButton(
                onPressed: agreed && pwdCtrl.text.isNotEmpty
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: Text(
                  'Supprimer',
                  style: GoogleFonts.inter(
                    color: profileRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true || !mounted) {
      pwdCtrl.dispose();
      return;
    }
    final pwd = pwdCtrl.text.trim();
    pwdCtrl.dispose();
    if (pwd.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => Center(
        child: Card(
          color: profileSurface,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: profileGreen, strokeWidth: 2),
                const SizedBox(height: 14),
                Text(
                  'Suppression en cours…',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: profileText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _unsubscribeAllPushTopics();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notifications_center_read_keys');
      await AccountDeletionService.deleteAllFavorites(uid);
      try {
        await AccountDeletionService.deleteUserDocument(uid);
      } catch (_) {}
      await AccountDeletionService.deleteFirebaseAuthAccount(
        emailPassword: pwd,
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        dvcrNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.errorMessage(e),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de supprimer le compte. Réessaie plus tard.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Widget _deleteAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileInlineSectionTitle(
          title: 'Effacement du compte',
          icon: Icons.gpp_maybe_rounded,
          accent: profileRed,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: profileSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: profileRed.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: profileRed.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supprimer mon compte',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: profileText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Droit à l’effacement (RGPD) : tu peux effacer ton compte et tes traces '
                'liées à l’app. Déconnexion automatique après validation.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: profileMutedText,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _confirmDeleteAccount(),
                icon: const Icon(Icons.delete_forever_rounded, color: profileRed),
                label: Text(
                  'Supprimer définitivement mon compte',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: profileRed,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: profileRed, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return ProfileElevatedCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: children),
    );
  }

  Widget _divider() => Container(
        height: 1,
        color: profileBorder,
        margin: const EdgeInsets.only(left: 66),
      );

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _accountIconBadge(icon, _IconBadgeStyle.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: profileText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: profileMutedText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow({
    required IconData icon,
    required String title,
    required String subtitle,
    _IconBadgeStyle iconBadge = _IconBadgeStyle.green,
    Color? iconColor,
    Color? titleColor,
    TextStyle? subtitleStyle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              _accountIconBadge(
                icon,
                iconBadge,
                iconColor: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: titleColor ?? profileText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: subtitleStyle ??
                          GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: profileMutedText,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: profileMutedText.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _accountIconBadge(icon, _IconBadgeStyle.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: profileText,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: profileMutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: profileGold.withAlpha(90),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return profileGold;
                return profileMutedText;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return profileGold.withAlpha(70);
                }
                return profileBorder;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHeroCard extends StatelessWidget {
  const _AccountHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            profileGold.withValues(alpha: 0.8),
            profileGold.withValues(alpha: 0.3),
            profileGreen.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: profileGold.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: profileSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [profileGold, profileGold.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: profileGold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MON COMPTE',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: profileText,
                      letterSpacing: 0.3,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Identité · Notifications · Équipe favorite',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: profileMutedText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
