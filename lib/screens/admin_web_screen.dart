import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article_model.dart';
import '../services/article_service.dart';
import '../services/user_service.dart';
import 'article_editor_screen.dart';

const _kRed    = Color(0xFFBA203C);
const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF141414);
const _kBorder = Color(0xFF242424);

class AdminWebScreen extends StatefulWidget {
  const AdminWebScreen({super.key});
  @override
  State<AdminWebScreen> createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  bool _checking = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _checking = false; _authorized = false; });
      return;
    }
    final ok = await UserService.canModerate();
    setState(() { _checking = false; _authorized = ok; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(
      backgroundColor: _kBg,
      body: Center(child: CircularProgressIndicator(color: _kRed)));

    if (!_authorized) return _LoginGate(onLogin: () { setState(() { _checking = true; }); _check(); });

    return _AdminPanel();
  }
}

// ── Gate login ────────────────────────────────────────────────────────────────
class _LoginGate extends StatefulWidget {
  final VoidCallback onLogin;
  const _LoginGate({required this.onLogin});
  @override
  State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(), password: _pass.text.trim());
      widget.onLogin();
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DVCR', style: GoogleFonts.oswald(
                fontSize: 28, fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic, color: _kRed)),
              Text('Administration', style: GoogleFonts.barlow(
                fontSize: 14, color: Colors.white54)),
              const SizedBox(height: 32),
              _WebField(controller: _email, label: 'Email', obscure: false),
              const SizedBox(height: 16),
              _WebField(controller: _pass, label: 'Mot de passe', obscure: true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: GoogleFonts.barlow(fontSize: 12, color: _kRed)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Connexion', style: GoogleFonts.oswald(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Panel principal ───────────────────────────────────────────────────────────
class _AdminPanel extends StatefulWidget {
  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text('DVCR', style: GoogleFonts.oswald(
                fontSize: 22, fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic, color: _kRed)),
              const SizedBox(width: 8),
              Text('Admin', style: GoogleFonts.barlow(fontSize: 13, color: Colors.white38)),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 16, color: Colors.white38),
            label: Text('Déconnexion', style: GoogleFonts.barlow(
              fontSize: 13, color: Colors.white38)),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kRed,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.barlow(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Articles'),
            Tab(text: 'Live & Émission'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ArticlesAdmin(),
          const _LiveAdmin(),
        ],
      ),
    );
  }
}

// ── Gestion articles ──────────────────────────────────────────────────────────
class _ArticlesAdmin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ArticleModel>>(
      stream: ArticleService.all(limit: 100),
      builder: (context, snap) {
        final articles = snap.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text('Articles', style: GoogleFonts.oswald(
                    fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text('Nouvel article', style: GoogleFonts.barlow(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ArticleEditorScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Table
              Expanded(
                child: articles.isEmpty
                    ? Center(child: Text('Aucun article',
                        style: GoogleFonts.barlow(color: Colors.white38)))
                    : SingleChildScrollView(
                        child: Column(
                          children: articles.map((a) => _ArticleRow(
                            article: a,
                            onEdit: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ArticleEditorScreen(article: a))),
                            onDelete: () => _confirmDelete(context, a),
                            onFeatured: () => a.featured
                                ? ArticleService.removeFeatured(a.id)
                                : ArticleService.setFeatured(a.id),
                          )).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ArticleModel a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Supprimer ?', style: GoogleFonts.oswald(
          color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(a.title, style: GoogleFonts.barlow(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () { Navigator.pop(context); ArticleService.delete(a.id); },
            child: Text('Supprimer', style: TextStyle(color: _kRed))),
        ],
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onEdit, onDelete, onFeatured;
  const _ArticleRow({required this.article, required this.onEdit,
      required this.onDelete, required this.onFeatured});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: article.featured
            ? Colors.amber.withAlpha(80) : _kBorder, width: 1),
      ),
      child: Row(
        children: [
          // Badge catégorie
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF333333))),
            child: Text(article.category,
              style: GoogleFonts.barlow(fontSize: 10, color: Colors.white54),
              overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),

          // Titre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title,
                  style: GoogleFonts.barlow(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(article.authorName ?? '',
                  style: GoogleFonts.barlow(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),

          // À la une
          IconButton(
            tooltip: article.featured ? 'Retirer de la une' : 'Mettre à la une',
            icon: Icon(article.featured ? Icons.star : Icons.star_border,
              color: article.featured ? Colors.amber : Colors.white24, size: 20),
            onPressed: onFeatured,
          ),

          // Éditer
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 20),
            onPressed: onEdit,
          ),

          // Supprimer
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline, color: Color(0xFFAA3A3A), size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Gestion Live & Émission ───────────────────────────────────────────────────
class _LiveAdmin extends StatefulWidget {
  const _LiveAdmin();
  @override
  State<_LiveAdmin> createState() => _LiveAdminState();
}

class _LiveAdminState extends State<_LiveAdmin> {
  // Match live
  final _matchUrlCtrl   = TextEditingController();
  final _matchTeam1Ctrl = TextEditingController();
  final _matchTeam2Ctrl = TextEditingController();
  bool _matchLive = false;
  bool _matchLoading = false;

  // Émission live
  final _emUrlCtrl   = TextEditingController();
  final _emTitleCtrl = TextEditingController();
  bool _emLive = false;
  bool _emLoading = false;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final matchDoc = await _db.collection('live').doc('current').get();
    final emDoc    = await _db.collection('live').doc('emission').get();
    if (!mounted) return;
    setState(() {
      _matchLive = matchDoc.exists;
      if (matchDoc.exists) {
        final d = matchDoc.data()!;
        _matchUrlCtrl.text   = d['url'] ?? '';
        _matchTeam1Ctrl.text = d['team1'] ?? '';
        _matchTeam2Ctrl.text = d['team2'] ?? '';
      }
      _emLive = emDoc.exists;
      if (emDoc.exists) {
        final d = emDoc.data()!;
        _emUrlCtrl.text   = d['url'] ?? '';
        _emTitleCtrl.text = d['title'] ?? '';
      }
    });
  }

  Future<void> _toggleMatch() async {
    setState(() => _matchLoading = true);
    final ref = _db.collection('live').doc('current');
    if (_matchLive) {
      await ref.delete();
    } else {
      await ref.set({
        'url':          _matchUrlCtrl.text.trim(),
        'team1':        _matchTeam1Ctrl.text.trim(),
        'team2':        _matchTeam2Ctrl.text.trim(),
        'scoreHome':    0,
        'scoreAway':    0,
        'live_viewers': 0,
        'startedAt':    FieldValue.serverTimestamp(),
      });
    }
    await _loadCurrent();
    setState(() => _matchLoading = false);
  }

  Future<void> _toggleEmission() async {
    setState(() => _emLoading = true);
    final ref = _db.collection('live').doc('emission');
    if (_emLive) {
      await ref.delete();
    } else {
      await ref.set({
        'url':       _emUrlCtrl.text.trim(),
        'title':     _emTitleCtrl.text.trim().isEmpty
            ? 'ÉMISSION DVCR'
            : _emTitleCtrl.text.trim(),
        'viewers':   0,
        'startedAt': FieldValue.serverTimestamp(),
      });
    }
    await _loadCurrent();
    setState(() => _emLoading = false);
  }

  @override
  void dispose() {
    _matchUrlCtrl.dispose();
    _matchTeam1Ctrl.dispose();
    _matchTeam2Ctrl.dispose();
    _emUrlCtrl.dispose();
    _emTitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Match live ─────────────────────────────────────
          _SectionCard(
            title: 'Match en direct',
            isLive: _matchLive,
            liveLabel: 'MATCH EN COURS',
            child: Column(
              children: [
                _WebField(controller: _matchUrlCtrl, label: 'URL du stream', obscure: false),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _WebField(controller: _matchTeam1Ctrl, label: 'Équipe domicile', obscure: false)),
                    const SizedBox(width: 12),
                    Expanded(child: _WebField(controller: _matchTeam2Ctrl, label: 'Équipe visiteur', obscure: false)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _matchLive ? Colors.white12 : _kRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _matchLoading ? null : _toggleMatch,
                    child: _matchLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _matchLive ? '⏹ TERMINER LE MATCH' : '▶ DÉMARRER LE MATCH EN DIRECT',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 15, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section Émission live ──────────────────────────────────
          _SectionCard(
            title: 'Émission DVCR',
            isLive: _emLive,
            liveLabel: 'ÉMISSION EN COURS',
            child: Column(
              children: [
                _WebField(controller: _emTitleCtrl, label: 'Titre de l\'émission', obscure: false),
                const SizedBox(height: 12),
                _WebField(controller: _emUrlCtrl, label: 'URL du stream (YouTube, Twitch…)', obscure: false),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emLive ? Colors.white12 : _kRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _emLoading ? null : _toggleEmission,
                    child: _emLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _emLive ? '⏹ TERMINER L\'ÉMISSION' : '▶ DÉMARRER L\'ÉMISSION EN DIRECT',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 15, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final bool isLive;
  final String liveLabel;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.isLive,
    required this.liveLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? _kRed.withAlpha(180) : _kBorder,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: GoogleFonts.oswald(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(liveLabel, style: GoogleFonts.barlowCondensed(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 1,
                      )),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Champ texte web ───────────────────────────────────────────────────────────
class _WebField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  const _WebField({required this.controller, required this.label, required this.obscure});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.barlow(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.barlow(fontSize: 13, color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kRed)),
      ),
    );
  }
}
