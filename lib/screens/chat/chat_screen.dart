import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/user_role.dart';
import '../../utils/chat_reactions.dart';
import '../../services/app_settings_service.dart';
import '../../services/role_permissions_service.dart';
import '../../services/user_service.dart';
import '../../services/xp_service.dart';
import '../../widgets/chat_sticker_image.dart';
import '../../widgets/dvcr_member_role_badge.dart';
import '../../widgets/hub_hero_photo.dart';
import '../../widgets/member_badge_info.dart';
import 'chat_design.dart';
import 'chat_role_list_utils.dart';
part 'chat_ui_parts.dart';

// ── Constants (hex club, alignés sur ChatDesign) ──────────────────────────────
const _kSheet = ChatDesign.ivory;
const _kInput = ChatDesign.paper;
const _kBorder = ChatDesign.border;
const _kText = ChatDesign.text;
const _kMuted = ChatDesign.muted;
const _kGreen = ChatDesign.green;
const _kGreenDeep = ChatDesign.greenDeep;
const _kRed = ChatDesign.red;
const _kGold = ChatDesign.gold;

/// L'or du club tombe à ~2:1 en texte sur papier : illisible en petit corps.
/// Les filets, fonds et icônes gardent [_kGold], le texte passe par celui-ci.
const _kGoldDeep = ChatDesign.goldDeep;

/// Photo de fond par défaut du salon. L'admin peut la remplacer via
/// Admin → Réglages → Photos hero → Onglets / Communauté (`app_config/hub_heroes`).
const _kChatHeroBg =
    'https://static.wixstatic.com/media/e91e00_67784108c7c9490d8fbf1e3790267a32~mv2.jpg';

/// Au-delà, le fil arrête de s'étirer : une ligne de 1200 px est illisible.
const double _kChatMaxContentWidth = 760;

DateTime _chatDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _chatSameDay(DateTime a, DateTime b) =>
    _chatDateOnly(a) == _chatDateOnly(b);

String _chatDaySeparatorLabel(DateTime d) {
  final today = _chatDateOnly(DateTime.now());
  final day = _chatDateOnly(d);
  if (day == today) return "Aujourd'hui";
  if (day == today.subtract(const Duration(days: 1))) return 'Hier';
  return DateFormat('EEEE d MMMM', 'fr_FR').format(d);
}

String _chatMessageTimeLabel(DateTime d) {
  final time = DateFormat('HH:mm', 'fr_FR').format(d);
  final today = _chatDateOnly(DateTime.now());
  final day = _chatDateOnly(d);
  if (day == today) return time;
  if (day == today.subtract(const Duration(days: 1))) return 'Hier · $time';
  return '${DateFormat('EEE d MMM', 'fr_FR').format(d)} · $time';
}

/// Heure nue, pour la gouttière des messages groupés.
String _chatClockLabel(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);

/// La liste est inversée et triée du plus récent au plus ancien : le message
/// affiché juste au-dessus de `docs[index]` est `docs[index + 1]`. Le
/// séparateur coiffe donc le premier message de la journée, pas le dernier.
bool _chatShowDateSeparator(int index, List<QueryDocumentSnapshot> docs) {
  if (index < 0 || index >= docs.length) return false;
  final curTs = (docs[index].data() as Map)['createdAt'];
  if (curTs is! Timestamp) return false;
  if (index == docs.length - 1) return true;
  final olderTs = (docs[index + 1].data() as Map)['createdAt'];
  if (olderTs is! Timestamp) return false;
  return !_chatSameDay(curTs.toDate(), olderTs.toDate());
}

Map<String, dynamic> _defaultChatConfig() {
  return {
    'autoModeration': {
      'enabled': false,
      'blockedWords': <String>[],
      'notice':
          'Hey {user}, petit rappel avec le sourire : merci de rester cool et respectueux·se avec tout le monde ici.',
    },
    'customEmojis': <Map<String, dynamic>>[],
  };
}

List<Map<String, dynamic>> _customChatEmojis(Map<String, dynamic>? config) {
  final raw = (config?['customEmojis'] as List?) ?? const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => (item['enabled'] ?? true) == true)
      .toList();
}

Map<String, Map<String, dynamic>> _emojiValueMap(Map<String, dynamic>? config) {
  final map = <String, Map<String, dynamic>>{};
  for (final emoji in _customChatEmojis(config)) {
    final value = (emoji['value'] ?? '').toString().trim();
    if (value.isNotEmpty) {
      map[value] = emoji;
    }
  }
  return map;
}

String _normalizeChatText(String input) {
  final lowered = input.toLowerCase();
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'ç': 'c',
  };
  var result = lowered;
  accents.forEach((key, value) {
    result = result.replaceAll(key, value);
  });
  return result;
}

String _displayNameFromData(Map<String, dynamic>? data) {
  final firstName = (data?['firstName'] ?? '').toString().trim();
  final lastName = (data?['lastName'] ?? '').toString().trim();
  final displayName = (data?['displayName'] ?? '').toString().trim();
  if (firstName.isNotEmpty) {
    return '$firstName${lastName.isNotEmpty ? ' ${lastName[0]}.' : ''}';
  }
  if (displayName.isNotEmpty) return displayName;
  final email = (data?['email'] ?? '').toString().trim();
  if (email.isNotEmpty) return email.split('@').first;
  return 'Membre';
}

String _userHandleFromData(Map<String, dynamic>? data) {
  final base = _displayNameFromData(data)
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
  return base.isEmpty ? 'membre' : base;
}

List<String> _extractMentions(String text) {
  return RegExp(
    r'@([a-zA-Z0-9_.-]+)',
  ).allMatches(text).map((match) => match.group(1)!).toSet().toList();
}

// ── XP / Niveaux : voir XpService + Cloud Function awardXp ───────────────────

// ── Badge data per role ────────────────────────────────────────────────────────
(String label, Color bg, Color text, Color nameColor, Color avatarColor)
    _roleData(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return (
        'ADMIN',
        const Color(0xFFFFF2F2),
        const Color(0xFFB54D5C),
        const Color(0xFF2D4A42),
        const Color(0xFFE8A8B0),
      );
    case UserRole.communityManager:
      return (
        'CM',
        const Color(0xFF0D1520),
        const Color(0xFF64B5F6),
        const Color(0xFF6699BB),
        const Color(0xFF2A4A6A),
      );
    case UserRole.partenaire:
      return (
        'PARTENAIRE',
        const Color(0xFF1A1200),
        const Color(0xFFFFB74D),
        const Color(0xFFBB9944),
        const Color(0xFF7A5522),
      );
    case UserRole.donateur:
      return (
        'MEMBRE',
        const Color(0xFF0A1A0D),
        const Color(0xFF81C784),
        const Color(0xFF5A9A6A),
        const Color(0xFF2A5A3A),
      );
    case UserRole.editor:
      return (
        'ÉDITEUR',
        const Color(0xFF0A1A1A),
        const Color(0xFF00BCD4),
        const Color(0xFF3A9AAA),
        const Color(0xFF1A5A66),
      );
    case UserRole.teamDvcr:
      return (
        'TEAM DVCR',
        const Color(0xFFFFF9EC),
        const Color(0xFF8A7228),
        const Color(0xFF2D4A42),
        const Color(0xFFE8D4A8),
      );
    case UserRole.statisticien:
      return (
        'STATISTICIEN',
        const Color(0xFF150A1A),
        const Color(0xFF9C27B0),
        const Color(0xFF885599),
        const Color(0xFF4A1A5A),
      );
    case UserRole.supporter:
      return (
        'MEMBRE',
        const Color(0xFF1A1A1E),
        const Color(0xFF888896),
        const Color(0xFF3A3A44),
        const Color(0xFF3A3A44),
      );
  }
}

/// Nom lisible sur plaque ivoire (évite blanc sur blanc).
///
/// Les couleurs de rôle sont pensées pour un fond sombre : sur le papier du
/// salon, cyan, or et vert clair tombent sous 3:1. On les assombrit jusqu'à
/// atteindre le ratio, plutôt que de les remplacer par du noir.
Color _readableChatNameColor(Color roleNameColor) {
  const minContrast = 4.0;
  var candidate = roleNameColor;
  for (var i = 0; i < 12; i++) {
    if (_chatContrastOnPlate(candidate) >= minContrast) return candidate;
    final hsl = HSLColor.fromColor(candidate);
    candidate =
        hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
  }
  return _chatContrastOnPlate(candidate) >=
          _chatContrastOnPlate(roleNameColor)
      ? candidate
      : _kText;
}

/// Ratio WCAG du pseudo sur la plaque la plus claire (#FFFDF8).
double _chatContrastOnPlate(Color color) {
  const plateLuminance = 0.9884; // Color(0xFFFFFDF8).computeLuminance()
  final l = color.computeLuminance();
  return (plateLuminance + 0.05) / (l + 0.05);
}

// ── Avis flottants ────────────────────────────────────────────────────────────
enum _ChatNoticeTone { success, warning, danger }

/// Un seul avis pour tout le salon : envoi refusé, modération, erreur réseau.
/// Flottant et arrondi, posé juste au-dessus de la barre de saisie.
void _showChatNotice(
  BuildContext context,
  String message, {
  _ChatNoticeTone tone = _ChatNoticeTone.success,
  Duration duration = const Duration(seconds: 2),
}) {
  final (Color accent, IconData icon) = switch (tone) {
    _ChatNoticeTone.success => (ChatDesign.accent, Icons.check_circle_rounded),
    _ChatNoticeTone.warning => (ChatDesign.goldDeep, Icons.shield_rounded),
    _ChatNoticeTone.danger => (ChatDesign.red, Icons.error_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ChatDesign.paper,
        elevation: 0,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ChatDesign.radius),
          side: const BorderSide(color: ChatDesign.hairline),
        ),
        content: Row(
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: ChatDesign.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

UserRole _parseRole(String? s) {
  switch (s) {
    case 'admin':
      return UserRole.admin;
    case 'community_manager':
    case 'communityManager':
      return UserRole.communityManager;
    case 'editor':
      return UserRole.editor;
    case 'statisticien':
      return UserRole.statisticien;
    case 'team_dvcr':
    case 'teamDvcr':
      return UserRole.teamDvcr;
    case 'partenaire':
    case 'donateur':
      return UserRole.supporter;
    default:
      return UserRole.supporter;
  }
}

Set<UserRole> _rolesFromMsg(Map<String, dynamic> data) {
  final rolesList = data['roles'];
  if (rolesList is List && rolesList.isNotEmpty) {
    final set = rolesList.whereType<String>().map(_parseRole).toSet();
    if (set.isNotEmpty) return set;
  }
  return {_parseRole(data['role'] as String?)};
}

Set<UserRole> _publicChatRoles(Set<UserRole> roles) =>
    publicDisplayBadgeRoles(roles);

Set<UserRole> _chatHeaderBadgeRoles(Set<UserRole> roles) =>
    publicDisplayBadgeRoles(roles);

String _badgeLabelFor(UserRole role, Map<String, String> labels) {
  final key = roleBadgeConfigKey(role);
  final custom = labels[key]?.trim();
  if (role == UserRole.teamDvcr) {
    return RoleBadgeSettings.normalizeTeamDvcrLabel(
      custom,
      fallback: role.displayName,
    );
  }
  if (custom != null && custom.isNotEmpty) return custom;
  return role.displayName;
}

UserRole _chatHeaderPrimaryBadgeRole(UserRole role, Set<UserRole> roles) {
  final raw = roles.isNotEmpty ? roles : {role};
  final list = _chatHeaderBadgeRoles(raw).toList();
  sortRolesByPriority(list);
  return list.first;
}

// ── Chat screen ───────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  UserRole? _role;
  Set<UserRole> _roles = {};
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _isBanned = false;
  User? _fireUser;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<RoleBadgeSettings>? _badgesSub;
  Map<String, String> _roleBadges = {};
  Map<String, String> _roleBadgeLabels = {};

  // Salon courant
  String _salonId = 'general';

  /// Brouillon par salon. Purement local et volatile : rien n'est écrit côté
  /// serveur, on évite juste de perdre un message commencé en changeant d'onglet.
  final Map<String, String> _drafts = {};
  bool _restoringDraft = false;

  // Reply
  Map<String, dynamic>? _replyTo;

  /// Envoi en cours : la barre passe en attente au lieu de rester inerte.
  bool _sending = false;

  /// Le fil est inversé : « en bas » = offset ~0. Sert au bouton de retour.
  final _atBottomNotifier = ValueNotifier<bool>(true);

  // Anti-spam
  final List<DateTime> _spamTs = [];

  // Typing
  Timer? _typingTimer;
  bool _isTyping = false;
  Timer? _mentionDebounce;

  Map<String, dynamic> _chatConfig = _defaultChatConfig();
  StreamSubscription<ChatSettings>? _chatConfigSub;
  StreamSubscription<Map<String, List<String>>>? _permissionsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mentionUsersSub;
  List<Map<String, dynamic>> _mentionUsers = [];
  List<Map<String, dynamic>> _mentionSuggestions = [];
  final Map<String, String> _pendingMentionUids = {}; // handle → uid
  Map<String, List<String>> _permissionsConfig =
      RolePermissionsService.defaultPermissions;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ctrl.addListener(_onTypingChanged);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_loadUser);
    _ensureDefaultSalon();
    _listenChatConfig();
    _listenPermissions();
    _listenMentionUsers();
    _listenRoleBadges();
  }

  @override
  void dispose() {
    // Marquer hors-ligne au départ du chat
    final uid = _fireUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp()
      }).catchError((_) {});
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _authSub?.cancel();
    _userDocSub?.cancel();
    _badgesSub?.cancel();
    _typingTimer?.cancel();
    _mentionDebounce?.cancel();
    _clearTyping();
    _chatConfigSub?.cancel();
    _permissionsSub?.cancel();
    _mentionUsersSub?.cancel();
    _ctrl.removeListener(_onTypingChanged);
    _atBottomNotifier.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _listenChatConfig() {
    _chatConfigSub = AppSettingsService.chatStream().listen((settings) {
      if (!mounted) return;
      setState(() {
        _chatConfig = {..._defaultChatConfig(), ...settings.toMap()};
      });
    });
  }

  void _listenPermissions() {
    RolePermissionsService.ensureDefaults();
    _permissionsSub = RolePermissionsService.stream().listen((config) {
      if (!mounted) return;
      setState(() => _permissionsConfig = config);
    });
  }

  void _listenRoleBadges() {
    _badgesSub = AppSettingsService.roleBadgesStream().listen((settings) {
      if (!mounted) return;
      setState(() {
        _roleBadges = settings.badges;
        _roleBadgeLabels = settings.labels;
      });
    });
  }

  void _listenMentionUsers() {
    _mentionUsersSub = FirebaseFirestore.instance
        .collection('users')
        .limit(100)
        .snapshots()
        .listen((snap) {
      final users =
          snap.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
      if (!mounted) return;
      setState(() {
        _mentionUsers = users;
      });
      _refreshMentionSuggestions();
    });
  }

  Future<void> _ensureDefaultSalon() async {
    final ref =
        FirebaseFirestore.instance.collection('chat_salons').doc('general');
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': 'Général',
        'order': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _loadUser(User? user) async {
    if (user == null) {
      _userDocSub?.cancel();
      _userDocSub = null;
      if (mounted) {
        setState(() {
          _fireUser = null;
          _loading = false;
        });
      }
      return;
    }
    // Listen to Firestore user doc in real-time so role changes propagate instantly
    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      final roles = UserService.parseRolesFromData(data);
      final role = UserService.primaryRole(roles);
      final bannedUntil = data?['chatBannedUntil'];
      bool banned = false;
      if (bannedUntil is Timestamp) {
        banned = bannedUntil.toDate().isAfter(DateTime.now());
      }
      setState(() {
        _fireUser = user;
        _userData = data;
        _roles = roles;
        _role = role;
        _isBanned = banned;
        _loading = false;
      });
    });
    // Marquer l'utilisateur en ligne
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp()
    }).catchError((_) {});
  }

  // ── Salon ─────────────────────────────────────────────────────────────────
  void _switchSalon(String id, String name) {
    if (_salonId == id) return;
    HapticFeedback.selectionClick();
    _clearTyping();
    final pending = _ctrl.text;
    if (pending.trim().isEmpty) {
      _drafts.remove(_salonId);
    } else {
      _drafts[_salonId] = pending;
    }
    setState(() {
      _salonId = id;
      _replyTo = null;
      _mentionSuggestions = [];
    });
    _restoreDraft(id);
  }

  /// Repose le brouillon du salon sans réveiller l'indicateur « écrit… » :
  /// restaurer du texte n'est pas frapper au clavier.
  void _restoreDraft(String salonId) {
    final draft = _drafts[salonId] ?? '';
    _restoringDraft = true;
    _ctrl.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    _restoringDraft = false;
  }

  Future<void> _createSalon(String name) async {
    if (_role != UserRole.admin) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('chat_salons')
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder = snap.docs.isEmpty
        ? 1
        : ((snap.docs.first.data()['order'] as int?) ?? 0) + 1;
    final ref = await FirebaseFirestore.instance.collection('chat_salons').add({
      'name': trimmed,
      'order': nextOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) _switchSalon(ref.id, trimmed);
  }

  // ── Typing indicator ──────────────────────────────────────────────────────
  void _onTypingChanged() {
    if (_restoringDraft) return;
    _refreshMentionSuggestions();
    if (_ctrl.text.trim().isEmpty) {
      _clearTyping();
      return;
    }
    if (!_isTyping) _sendTyping();
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
  }

  void _refreshMentionSuggestions() {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final match = RegExp(
        r'(?:^|\s)@([a-zA-Z0-9_.-]{0,24})$',
      ).firstMatch(_ctrl.text);
      final query = (match?.group(1) ?? '').trim().toLowerCase();
      if (query.isEmpty) {
        if (_mentionSuggestions.isNotEmpty) {
          setState(() => _mentionSuggestions = []);
        }
        return;
      }

      final suggestions = _mentionUsers
          .where((user) {
            final handle = _userHandleFromData(user).toLowerCase();
            final display = _displayNameFromData(user).toLowerCase();
            return handle.startsWith(query) || display.contains(query);
          })
          .take(6)
          .toList();

      if (_listMentionsSame(_mentionSuggestions, suggestions)) return;
      setState(() => _mentionSuggestions = suggestions);
    });
  }

  bool _listMentionsSame(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['uid'] != b[i]['uid']) return false;
    }
    return true;
  }

  void _insertMention(Map<String, dynamic> user) {
    final handle = _userHandleFromData(user);
    final uid = user['uid'] as String? ?? '';
    if (uid.isNotEmpty) _pendingMentionUids[handle] = uid;
    final currentText = _ctrl.text;
    final replaced = currentText.replaceFirst(
      RegExp(r'(?:^|\s)@[a-zA-Z0-9_.-]{0,24}$'),
      '${currentText.endsWith(' ') || currentText.isEmpty ? '' : ' '}@$handle ',
    );
    _ctrl.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: replaced.length),
    );
    if (mounted) {
      setState(() => _mentionSuggestions = []);
    }
  }

  Future<bool> _handleAutoModeration(String text) async {
    final autoMod =
        (_chatConfig['autoModeration'] as Map<String, dynamic>?) ?? const {};
    if (autoMod['enabled'] != true || _fireUser == null) return false;

    final blockedWords = ((autoMod['blockedWords'] as List?) ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (blockedWords.isEmpty) return false;

    final normalized = _normalizeChatText(text);
    final matched = blockedWords.firstWhere(
      (word) => normalized.contains(_normalizeChatText(word)),
      orElse: () => '',
    );
    if (matched.isEmpty) return false;

    final rawNotice = (autoMod['notice'] ?? '').toString().trim();
    final notice = (rawNotice.isNotEmpty
            ? rawNotice
            : 'Hey {user}, petit rappel avec le sourire : merci de rester cool et respectueux·se avec tout le monde ici.')
        .replaceAll(
      '{user}',
      _userData?['firstName']?.toString() ?? 'membre',
    );

    final db = FirebaseFirestore.instance;
    await db.collection('users').doc(_fireUser!.uid).update({
      'chatWarnings': FieldValue.increment(1),
    });
    await db.collection('chat_salons').doc(_salonId).collection('messages').add(
      {
        'text': notice,
        'uid': _fireUser!.uid,
        'firstName': 'Modération auto',
        'lastName': '',
        'role': (_role ?? UserRole.communityManager).name,
        'roles': [(_role ?? UserRole.communityManager).name],
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'reactions': <String, dynamic>{},
        'isModerationNotice': true,
        'targetUid': _fireUser!.uid,
      },
    );
    if (mounted) {
      _showChatNotice(
        context,
        'Message filtré automatiquement par la modération.',
        tone: _ChatNoticeTone.warning,
      );
    }
    return true;
  }

  Future<void> _sendTyping() async {
    if (_fireUser == null) return;
    _isTyping = true;
    await FirebaseFirestore.instance
        .collection('chat_typing')
        .doc(_fireUser!.uid)
        .set({
      'name': _userData?['firstName'] ?? 'Membre',
      'typingAt': FieldValue.serverTimestamp(),
      'salonId': _salonId,
    });
  }

  Future<void> _clearTyping() async {
    if (_fireUser == null || !_isTyping) return;
    _isTyping = false;
    _typingTimer?.cancel();
    FirebaseFirestore.instance
        .collection('chat_typing')
        .doc(_fireUser!.uid)
        .delete()
        .catchError((_) {});
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _fireUser == null || _sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (await _handleAutoModeration(text)) {
      _ctrl.clear();
      _clearTyping();
      if (mounted) setState(() => _mentionSuggestions = []);
      return;
    }

    // Anti-spam : max 3 messages par 5 secondes
    final now = DateTime.now();
    _spamTs.removeWhere((t) => now.difference(t).inSeconds > 5);
    if (_spamTs.length >= 3) {
      if (mounted) {
        _showChatNotice(
          context,
          'Doucement champion·ne ! Laisse respirer le salon quelques secondes.',
          tone: _ChatNoticeTone.danger,
        );
      }
      return;
    }
    _spamTs.add(now);

    _ctrl.clear();
    _drafts.remove(_salonId);
    _clearTyping();

    final replyData = _replyTo;
    if (mounted) {
      setState(() {
        _replyTo = null;
        _sending = true;
      });
    }

    final db = FirebaseFirestore.instance;
    final msgData = <String, dynamic>{
      'text': text,
      'uid': _fireUser!.uid,
      'firstName': _userData?['firstName'] ?? 'Membre',
      'lastName': _userData?['lastName'] ?? '',
      if ((_userData?['displayName'] ?? '').toString().trim().isNotEmpty)
        'displayName': (_userData?['displayName'] ?? '').toString().trim(),
      'role': _role?.name ?? 'supporter',
      'roles': _roles.map((r) => r.name).toList(),
      'mentions': _extractMentions(text),
      'mentionUids': _extractMentions(text)
          .map((h) => _pendingMentionUids[h])
          .whereType<String>()
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'reactions': <String, dynamic>{},
    };
    _pendingMentionUids.clear();
    if (replyData != null) msgData['replyTo'] = replyData;

    try {
      await db
          .collection('chat_salons')
          .doc(_salonId)
          .collection('messages')
          .add(msgData);
    } catch (e) {
      // Le message est rendu à la barre de saisie : le perdre serait pire que
      // l'échec lui-même.
      if (mounted) {
        _ctrl.text = text;
        setState(() {
          _replyTo = replyData;
          _sending = false;
        });
        _showChatNotice(
          context,
          'Message non envoyé. Vérifie ta connexion et réessaie.',
          tone: _ChatNoticeTone.danger,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }
    if (mounted) setState(() => _sending = false);
    HapticFeedback.lightImpact();

    unawaited(_awardChatMessageXp());

    _scrollToTop();
  }

  Future<void> _awardChatMessageXp() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('awardXp')
          .call({'eventType': 'chat_message'});
    } catch (_) {}
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Modération ────────────────────────────────────────────────────────────
  void _chatSnack(String message, {bool error = false}) {
    if (!mounted) return;
    _showChatNotice(
      context,
      message,
      tone: error ? _ChatNoticeTone.danger : _ChatNoticeTone.success,
    );
  }

  Future<void> _delete(String id) async {
    if (_fireUser == null) return;
    final ref = FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(_salonId)
        .collection('messages')
        .doc(id);
    try {
      final snap = await ref.get();
      final data = snap.data();
      final isMine = data != null && data['uid'] == _fireUser!.uid;
      final canMod = UserService.canReportMessageFromRoles(_roles);
      if (!isMine && !canMod) return;
      await ref.update({'isDeleted': true});
      _chatSnack(isMine ? 'Message supprimé' : 'Message masqué du salon');
    } catch (e) {
      _chatSnack('Impossible de masquer le message : $e', error: true);
    }
  }

  Future<void> _report(
    String docId,
    String text,
    String uid,
    String name,
  ) async {
    if (_fireUser == null) return;
    if (!UserService.canReportMessageFromRoles(_roles)) return;
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'messageId': docId,
        'messageText': text,
        'reportedUid': uid,
        'reportedName': name,
        'reporterUid': _fireUser!.uid,
        'reporterRole': _role?.name ?? 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'source': 'chat',
        'salonId': _salonId,
      });
      _chatSnack('Signalement envoyé à la modération');
    } catch (e) {
      _chatSnack('Échec du signalement : $e', error: true);
    }
  }

  Future<void> _ban(String uid, String name) async {
    if (_role != UserRole.admin && _role != UserRole.communityManager) return;
    final until = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 24)),
    );
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'chatBannedUntil': until,
      });
    } catch (e) {
      if (mounted) {
        _showChatNotice(
          context,
          'Suspension impossible (droits ou réseau). Détail : $e',
          tone: _ChatNoticeTone.danger,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }
    if (mounted) {
      _showChatNotice(
        context,
        '$name suspendu du chat 24h',
        tone: _ChatNoticeTone.danger,
      );
    }
  }

  Future<void> _warn(String uid, String name) async {
    if (_role != UserRole.admin && _role != UserRole.communityManager) return;
    final db = FirebaseFirestore.instance;
    final modUid = _fireUser?.uid;
    if (modUid == null) return;
    try {
      await db.collection('users').doc(uid).update({
        'chatWarnings': FieldValue.increment(1),
      });
    } catch (e) {
      if (mounted) {
        _showChatNotice(
          context,
          'Avertissement impossible (droits ou réseau). Détail : $e',
          tone: _ChatNoticeTone.warning,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }
    try {
      await db
          .collection('chat_salons')
          .doc(_salonId)
          .collection('messages')
          .add({
        'text':
            'Attention $name, merci de respecter les règles du chat et de rester calme. En cas de nouvel écart, une suspension temporaire pourra être appliquée.',
        'uid': modUid,
        'firstName': 'Modération',
        'lastName': '',
        'role': (_role ?? UserRole.communityManager).name,
        'roles': [(_role ?? UserRole.communityManager).name],
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'reactions': <String, dynamic>{},
        'isModerationNotice': true,
        'targetUid': uid,
      });
    } catch (e) {
      if (mounted) {
        _showChatNotice(
          context,
          'Compteur mis à jour mais message salon non posté : $e',
          tone: _ChatNoticeTone.warning,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }
    if (mounted) {
      _showChatNotice(
        context,
        'Avertissement envoyé à $name',
        tone: _ChatNoticeTone.warning,
      );
    }
  }

  Future<void> _pin(String docId, String text, String firstName) async {
    if (_role != UserRole.admin && _role != UserRole.communityManager) return;
    await FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(_salonId)
        .update({
      'pinned': {
        'messageId': docId,
        'text': text,
        'firstName': firstName,
        'pinnedAt': FieldValue.serverTimestamp(),
        'pinnedBy': _userData?['firstName'] ?? 'Admin',
      },
    });
  }

  Future<void> _unpin() async {
    await FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(_salonId)
        .update({'pinned': FieldValue.delete()});
  }

  Future<void> _react(String docId, String rawEmoji) async {
    if (_fireUser == null) return;
    // Même clé canonique qu'à la lecture : sans ça, ❤ et ❤️ créent deux pastilles.
    final emoji = normalizeChatReactionEmoji(rawEmoji);
    if (emoji.isEmpty) return;
    HapticFeedback.selectionClick();
    final ref = FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(_salonId)
        .collection('messages')
        .doc(docId);
    try {
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final raw = reactions[emoji];
      final uids =
          raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
      if (uids.contains(_fireUser!.uid)) {
        uids.remove(_fireUser!.uid);
      } else {
        uids.add(_fireUser!.uid);
      }
      if (uids.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = uids;
      }
      await ref.update({'reactions': reactions});
    } catch (e) {
      _chatSnack('Réaction impossible : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: ChatDesign.heroUnder,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _ChatBackdrop(),
            Center(
              child: CircularProgressIndicator(
                color: ChatDesign.accent,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      );
    }
    if (_fireUser == null) return const AuthLockScreen();
    final hasChatAccess = RolePermissionsService.hasPermission(
      _roles,
      RolePermissionsService.chatAccess,
      _permissionsConfig,
    );
    if (!hasChatAccess) {
      return const _ChatAccessLockedScreen();
    }

    final isAdmin = _role == UserRole.admin;
    final isCM = _role == UserRole.communityManager;
    final canMod = isAdmin || isCM;

    return Scaffold(
      backgroundColor: ChatDesign.heroUnder,
      body: Builder(
        builder: (context) {
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          final topPad = MediaQuery.of(context).padding.top;
          final bottomPad = MediaQuery.of(context).padding.bottom;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _ChatBackdrop(),
              Column(
                children: [
                  _ChatMasthead(
                    role: _role,
                    roles: _roles,
                    roleBadges: _roleBadges,
                    roleBadgeLabels: _roleBadgeLabels,
                    topPad: topPad,
                    compact: isLandscape,
                    currentSalonId: _salonId,
                    canCreateSalon: isAdmin,
                    onSwitchSalon: _switchSalon,
                    onAddSalon: () => _showCreateSalonDialog(context),
                  ),
                  if (!isLandscape)
                    _PinnedBar(
                      salonId: _salonId,
                      canUnpin: canMod,
                      onUnpin: _unpin,
                    ),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notif) {
                        if (notif.metrics.axis == Axis.vertical) {
                          final atBottom = notif.metrics.pixels <= 80;
                          if (_atBottomNotifier.value != atBottom) {
                            _atBottomNotifier.value = atBottom;
                          }
                        }
                        return false;
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _MessageList(
                            scroll: _scroll,
                            salonId: _salonId,
                            currentUid: _fireUser!.uid,
                            currentUserHandle: _userHandleFromData(_userData),
                            role: _role,
                            currentUserRoles: _roles,
                            emojiConfig: _chatConfig,
                            roleBadges: _roleBadges,
                            roleBadgeLabels: _roleBadgeLabels,
                            onDelete: _delete,
                            onReport: _report,
                            onReply: (data) => setState(() => _replyTo = data),
                            onPin: _pin,
                            onBan: _ban,
                            onWarn: _warn,
                            onReact: _react,
                          ),
                          Positioned(
                            right: 0,
                            left: 0,
                            bottom: 10,
                            child: _JumpToLatestButton(
                              hidden: _atBottomNotifier,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _scrollToTop();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TypingIndicator(
                        currentUid: _fireUser!.uid,
                        salonId: _salonId,
                      ),
                      if (_isBanned)
                        _BannedBar()
                      else
                        _InputBar(
                          ctrl: _ctrl,
                          onSend: _send,
                          sending: _sending,
                          replyTo: _replyTo,
                          customEmojis: _customChatEmojis(_chatConfig),
                          mentionSuggestions: _mentionSuggestions,
                          onMentionSelected: _insertMention,
                          onClearReply: () => setState(() => _replyTo = null),
                          bottomPad: bottomPad,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateSalonDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kInput,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ChatDesign.radiusMd),
        ),
        title: Text(
          'Créer un salon',
          style: GoogleFonts.barlowCondensed(
            color: _kText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 14, color: _kText),
          decoration: InputDecoration(
            hintText: 'Nom du salon...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: _kMuted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.inter(color: _kMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createSalon(ctrl.text);
            },
            child: Text(
              'Créer',
              style: GoogleFonts.inter(
                color: _kGoldDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lock screen ───────────────────────────────────────────────────────────────
class AuthLockScreen extends StatelessWidget {
  const AuthLockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSheet,
      body: Column(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(22)),
            child: SizedBox(
              height: 248,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const HubHeroPhoto(
                    slot: HubHeroSlot.auth,
                    alignment: Alignment(0, -0.2),
                    fallbackAsset:
                        'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
                    fallback: ColoredBox(color: _kGreenDeep),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(95),
                          Colors.black.withAlpha(55),
                          _kGreen.withAlpha(200),
                          _kGreenDeep,
                        ],
                        stops: const [0.0, 0.35, 0.72, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 22,
                    left: 22,
                    right: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _kGold.withAlpha(38),
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: Colors.white.withAlpha(85)),
                          ),
                          child: Text(
                            'COMMUNAUTÉ DVCR',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.55,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ESPACE MEMBRES',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connecte-toi pour rejoindre le chat et la communauté.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withAlpha(230),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Text(
                    'Le chat est réservé aux membres inscrits.\nCrée ton compte gratuitement pour rejoindre la communauté CSSA !',
                    style: GoogleFonts.barlow(
                      fontSize: 14,
                      color: _kMuted,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: _kGold,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _kGold.withAlpha(70),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        'CRÉER UN COMPTE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.barlow(fontSize: 13, color: _kMuted),
                        children: [
                          const TextSpan(text: 'Déjà inscrit ? '),
                          TextSpan(
                            text: 'Se connecter',
                            style: const TextStyle(
                              color: _kGoldDeep,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: _kGoldDeep,
                            ),
                          ),
                        ],
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
