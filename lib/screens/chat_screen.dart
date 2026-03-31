import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';
import 'prono_screen.dart' show PronoBanner;

// ── Constants ─────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0D0D0D);
const _kHeader = Color(0xFF0D0D0D);
const _kInput  = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);
const _kRed    = Color(0xFFBA203C);
const _kGreen  = Color(0xFF0A4438);
const _kGold   = Color(0xFFC8A436);
const _kChatBg = 'https://static.wixstatic.com/media/e91e00_fcf196ad9a89460db9891eff37e50601~mv2.jpg';

// ── Badge data per role ────────────────────────────────────────────────────────
(String label, Color bg, Color text, Color nameColor, Color avatarColor) _roleData(
    UserRole r) {
  switch (r) {
    case UserRole.admin:
      return (
        'ADMIN',
        const Color(0xFF1A0A0D),
        const Color(0xFFBA203C),
        const Color(0xFFCC5566),
        const Color(0xFF8B1828),
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
        'DONATEUR',
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
    case UserRole.supporter:
      return (
        'MEMBRE',
        const Color(0xFF1A1A1E),
        const Color(0xFF888896),
        Colors.white70,
        const Color(0xFF3A3A44),
      );
  }
}

UserRole _parseRole(String? s) {
  switch (s) {
    case 'admin':             return UserRole.admin;
    case 'community_manager':
    case 'communityManager':  return UserRole.communityManager;
    case 'editor':            return UserRole.editor;
    case 'partenaire':        return UserRole.partenaire;
    case 'donateur':          return UserRole.donateur;
    default:                  return UserRole.supporter;
  }
}

// Lit les rôles depuis un message Firestore
Set<UserRole> _rolesFromMsg(Map<String, dynamic> data) {
  final rolesList = data['roles'];
  if (rolesList is List && rolesList.isNotEmpty) {
    final set = rolesList.whereType<String>().map(_parseRole).toSet();
    if (set.isNotEmpty) return set;
  }
  return {_parseRole(data['role'] as String?)};
}

// ── Chat screen ───────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  UserRole? _role;
  Set<UserRole> _roles = {};
  Map<String, dynamic>? _userData;
  bool _loading  = true;
  bool _isBanned = false;
  User? _fireUser;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _loadUser(user);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadUser(User? user) async {
    if (user == null) {
      if (mounted) setState(() { _fireUser = null; _loading = false; });
      return;
    }
    final data = await UserService.getUserDataByUid(user.uid);
    final roles = UserService.parseRolesFromData(data);
    final role  = UserService.primaryRole(roles);
    final bannedUntil = data?['chatBannedUntil'];
    bool banned = false;
    if (bannedUntil is Timestamp) {
      banned = bannedUntil.toDate().isAfter(DateTime.now());
    }
    if (mounted) setState(() {
      _fireUser  = user;
      _userData  = data;
      _roles     = roles;
      _role      = role;
      _isBanned  = banned;
      _loading   = false;
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _fireUser == null) return;
    _ctrl.clear();
    await FirebaseFirestore.instance.collection('chat').add({
      'text':      text,
      'uid':       _fireUser!.uid,
      'firstName': _userData?['firstName'] ?? 'Membre',
      'lastName':  _userData?['lastName']  ?? '',
      'role':      _role?.name ?? 'supporter',
      'roles':     _roles.map((r) => r.name).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
    _scrollToTop();
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

  Future<void> _delete(String id) async {
    if (!UserService.canModerateChat(_role)) return;
    final ref  = FirebaseFirestore.instance.collection('chat').doc(id);
    final snap = await ref.get();
    final data = snap.data();
    await ref.update({'isDeleted': true});
    // Crée un signalement automatique visible dans l'onglet Signalements (admin web)
    if (data != null) {
      await FirebaseFirestore.instance.collection('reports').add({
        'messageId':    id,
        'messageText':  data['text'] ?? '',
        'reportedUid':  data['uid'] ?? '',
        'reportedName': data['firstName'] ?? 'Membre',
        'reporterUid':  _fireUser!.uid,
        'reporterRole': _role?.name ?? 'unknown',
        'createdAt':    FieldValue.serverTimestamp(),
        'status':       'pending',
        'source':       'moderation', // distingue d'un signalement manuel CM
      });
    }
  }

  Future<void> _report(String docId, String text, String uid, String name) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'messageId':    docId,
      'messageText':  text,
      'reportedUid':  uid,
      'reportedName': name,
      'reporterUid':  _fireUser!.uid,
      'createdAt':    FieldValue.serverTimestamp(),
      'status':       'pending',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signalement envoyé à la modération',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: const Color(0xFF0A4438),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kRed, strokeWidth: 2)),
      );
    }
    if (_fireUser == null) return const AuthLockScreen();

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _ChannelHeader(role: _role, roles: _roles),
          const Divider(height: 1, color: _kBorder),
          PronoBanner(uid: _fireUser!.uid),
          Expanded(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(_kChatBg, fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(color: Colors.black.withAlpha(160)),
                  ),
                  _MessageList(
                    scroll:      _scroll,
                    currentUid:  _fireUser!.uid,
                    role:        _role,
                    onDelete:    _delete,
                    onReport:    _report,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (_isBanned)
            _BannedBar()
          else
            _InputBar(ctrl: _ctrl, onSend: _send),
        ],
      ),
    );
  }
}

// ── Lock screen (public pour réutilisation) ───────────────────────────────────
class AuthLockScreen extends StatelessWidget {
  const AuthLockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Hero ────────────────────────────────────────────────────────
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(80),
                        Colors.black.withAlpha(200),
                        _kBg,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24, left: 24, right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'ESPACE MEMBRES',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 28, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: _kGold, width: 1.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('DVCR',
                              style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: _kGold, letterSpacing: 1,
                              )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connecte-toi pour rejoindre la communauté.',
                        style: GoogleFonts.barlow(
                            fontSize: 13, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Corps ───────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Text(
                    'Le chat est réservé aux membres inscrits.\nCrée ton compte gratuitement pour rejoindre la communauté CSSA !',
                    style: GoogleFonts.barlow(
                        fontSize: 14, color: Colors.white38, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      UserRole.supporter, UserRole.donateur,
                      UserRole.partenaire, UserRole.communityManager, UserRole.admin,
                    ].map((r) => _RoleBadge(role: r)).toList(),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'CRÉER UN COMPTE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.barlow(
                            fontSize: 13, color: Colors.white54),
                        children: [
                          const TextSpan(text: 'Déjà inscrit ? '),
                          TextSpan(
                            text: 'Se connecter',
                            style: const TextStyle(
                              color: _kGold,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: _kGold,
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

// ── Channel header ────────────────────────────────────────────────────────────
class _ChannelHeader extends StatelessWidget {
  final UserRole? role;
  final Set<UserRole> roles;
  const _ChannelHeader({this.role, this.roles = const {}});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(140), Colors.black.withAlpha(200)],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: const Icon(Icons.tag_rounded, color: Colors.white70, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'COMMUNAUTÉ DVCR',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 2,
                          shadows: [const Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50), shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Membres connectés',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (roles.isNotEmpty)
                    _RoleBadges(roles: roles)
                  else if (role != null)
                    _RoleBadge(role: role!),
                ],
              ),
            ),
          ),
          // Séparateur bas or
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(height: 1, color: _kGold.withAlpha(60)),
          ),
        ],
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────
class _MessageList extends StatelessWidget {
  final ScrollController scroll;
  final String currentUid;
  final UserRole? role;
  final void Function(String) onDelete;
  final void Function(String docId, String text, String uid, String name) onReport;

  const _MessageList({
    required this.scroll,
    required this.currentUid,
    required this.role,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kRed, strokeWidth: 2),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 52, color: Color(0xFF222228)),
                const SizedBox(height: 14),
                Text('Aucun message pour l\'instant',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white24)),
                const SizedBox(height: 4),
                Text('Sois le premier à écrire !',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white12)),
              ],
            ),
          );
        }

        final docs = snap.data!.docs
            .where((d) => (d.data() as Map)['isDeleted'] != true)
            .toList();

        return ListView.builder(
          controller: scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;

            // Group check: same uid, within 5 min of previous (older) message
            final nextData = i < docs.length - 1
                ? docs[i + 1].data() as Map<String, dynamic>
                : null;
            final isGrouped = nextData != null &&
                nextData['uid'] == data['uid'] &&
                _diffMin(nextData['createdAt'], data['createdAt']) < 5;

            final msgUid  = data['uid'] as String? ?? '';
            final msgName = data['firstName'] as String? ?? 'Membre';
            final msgText = data['text'] as String? ?? '';
            return _MessageTile(
              data:      data,
              docId:     doc.id,
              isMine:    msgUid == currentUid,
              isGrouped: isGrouped,
              role:      role,
              onDelete:  () => onDelete(doc.id),
              onReport:  () => onReport(doc.id, msgText, msgUid, msgName),
            );
          },
        );
      },
    );
  }

  int _diffMin(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return 999;
    return a.toDate().difference(b.toDate()).inMinutes.abs();
  }
}

// ── Message tile ──────────────────────────────────────────────────────────────
class _MessageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isMine;
  final bool isGrouped;
  final UserRole? role;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _MessageTile({
    required this.data,
    required this.docId,
    required this.isMine,
    required this.isGrouped,
    required this.role,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    final isCM    = role == UserRole.communityManager;

    return GestureDetector(
      onLongPress: isMine ? null : () => _showActions(context, isAdmin, isCM),
      child: _buildTile(context, isAdmin, isCM),
    );
  }

  void _showActions(BuildContext context, bool isAdmin, bool isCM) {
    if (!isAdmin && !isCM) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Supprimer — admin + CM
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350)),
              title: Text('Supprimer le message',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
            // Signaler — CM uniquement (admin gère via le panel web)
            if (isCM && !isAdmin)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xFFFFB74D)),
                title: Text('Signaler à l\'admin',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                onTap: () { Navigator.pop(context); onReport(); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, bool isAdmin, bool isCM) {
    final firstName   = (data['firstName'] ?? 'Membre') as String;
    final lastName    = (data['lastName']  ?? '')       as String;
    final text        = (data['text']      ?? '')       as String;
    final ts          = data['createdAt']  as Timestamp?;
    final msgRoles    = _rolesFromMsg(data);
    final msgRole     = UserService.primaryRole(msgRoles);
    final rd          = _roleData(msgRole);
    final nameColor   = rd.$4;
    final avatarColor = rd.$5;
    final initials    = '${firstName.isNotEmpty ? firstName[0] : "?"}${lastName.isNotEmpty ? lastName[0] : ""}'.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(
        left: 12, right: 12,
        top: isGrouped ? 2 : 10,
        bottom: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          SizedBox(
            width: 36,
            child: isGrouped
                ? null
                : GestureDetector(
                    onTap: (isAdmin || isCM) && !isMine
                        ? () => _showUserProfile(context, data)
                        : null,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: avatarColor.withAlpha(80),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Bulle
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft:     Radius.circular(isGrouped ? 10 : 2),
                topRight:    const Radius.circular(10),
                bottomLeft:  const Radius.circular(10),
                bottomRight: const Radius.circular(10),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(isMine ? 140 : 100),
                    borderRadius: BorderRadius.only(
                      topLeft:     Radius.circular(isGrouped ? 10 : 2),
                      topRight:    const Radius.circular(10),
                      bottomLeft:  const Radius.circular(10),
                      bottomRight: const Radius.circular(10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isGrouped)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                isMine ? 'Vous' : firstName,
                                style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: isMine ? Colors.white54 : nameColor, letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _RoleBadges(roles: msgRoles, small: true),
                              const Spacer(),
                              if (ts != null)
                                Text(
                                  _fmtTs(ts!),
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                                ),
                            ],
                          ),
                        ),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 14, height: 1.4,
                          color: Colors.white.withAlpha(215),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserProfile(BuildContext context, Map<String, dynamic> msgData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserProfileSheet(msgData: msgData),
    );
  }

  String _fmtTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
// ── Barre restriction ban 24h ──────────────────────────────────────────────────
class _BannedBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: Color(0xFFBA203C), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Suite à votre message vous avez été restreint au chat pendant 24h',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;

  const _InputBar({required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: EdgeInsets.only(
        left: 14, right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Envoyer un message...',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white38),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Panel profil membre style Discord ────────────────────────────────────────
class _UserProfileSheet extends StatefulWidget {
  final Map<String, dynamic> msgData;
  const _UserProfileSheet({required this.msgData});
  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.msgData['uid'] as String?;
    if (uid != null) {
      final data = await UserService.getUserDataByUid(uid);
      if (mounted) setState(() { _userData = data; _loading = false; });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.msgData['firstName'] ?? 'Membre') as String;
    final lastName  = (widget.msgData['lastName']  ?? '')       as String;
    final roles     = _rolesFromMsg(widget.msgData);
    final primary   = UserService.primaryRole(roles);
    final rd        = _roleData(primary);
    final avatarColor = rd.$5;
    final initials  = '${firstName.isNotEmpty ? firstName[0] : "?"}${lastName.isNotEmpty ? lastName[0] : ""}'.toUpperCase();

    String memberSince = '';
    bool isBanned = false;
    if (_userData != null) {
      final ts = _userData!['createdAt'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        const months = ['jan','fév','mar','avr','mai','juin',
            'juil','aoû','sep','oct','nov','déc'];
        memberSince = '${d.day} ${months[d.month - 1]} ${d.year}';
      }
      final bannedUntil = _userData!['chatBannedUntil'];
      if (bannedUntil is Timestamp) {
        isBanned = bannedUntil.toDate().isAfter(DateTime.now());
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Bannière couleur + avatar
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: avatarColor.withAlpha(40),
                ),
              ),
              Positioned(
                left: 20, bottom: -28,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarColor.withAlpha(40),
                    border: Border.all(color: const Color(0xFF0F0F12), width: 4),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: avatarColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Infos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + badge ban
                Row(
                  children: [
                    Text(
                      '$firstName $lastName'.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.3,
                      ),
                    ),
                    if (isBanned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA203C).withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBA203C).withAlpha(80)),
                        ),
                        child: Text('SUSPENDU',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: const Color(0xFFBA203C), letterSpacing: 1,
                          )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Badges rôles
                Wrap(
                  spacing: 5,
                  children: roles
                      .where((r) => r != UserRole.supporter || roles.length == 1)
                      .map((r) => _RoleBadge(role: r))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFF1A1A1E)),
                const SizedBox(height: 14),

                // Infos compte
                _loading
                    ? const SizedBox(
                        height: 20,
                        child: Center(child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: _kRed, strokeWidth: 1.5))),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (memberSince.isNotEmpty)
                            _ProfileInfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Membre depuis',
                              value: memberSince,
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white30),
          const SizedBox(width: 8),
          Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
          const Spacer(),
          Text(value,
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white60)),
        ],
      ),
    );
  }
}

// ── Multi-role badges (affiche max 2 badges côte à côte) ─────────────────────
class _RoleBadges extends StatelessWidget {
  final Set<UserRole> roles;
  final bool small;
  const _RoleBadges({required this.roles, this.small = false});

  @override
  Widget build(BuildContext context) {
    // Badges à afficher : tous sauf supporter si d'autres rôles existent
    final visible = roles.length > 1
        ? roles.where((r) => r != UserRole.supporter).toList()
        : roles.toList();
    // Ordre : rôle fonctionnel d'abord, puis statuts (donateur, partenaire)
    visible.sort((a, b) => UserService.rolePriority.indexOf(a)
        .compareTo(UserService.rolePriority.indexOf(b)));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: visible.take(2).map((r) => Padding(
        padding: const EdgeInsets.only(right: 3),
        child: _RoleBadge(role: r, small: small),
      )).toList(),
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool small;
  const _RoleBadge({required this.role, this.small = false});

  @override
  Widget build(BuildContext context) {
    final rd = _roleData(role);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: rd.$2,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        rd.$1,
        style: GoogleFonts.inter(
          fontSize: small ? 9.0 : 10.0,
          fontWeight: FontWeight.w700,
          color: rd.$3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
