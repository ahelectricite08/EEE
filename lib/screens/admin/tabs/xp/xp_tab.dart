import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/prono_social_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';

/// Valeur Firestore : `int` (ancien) ou `{ "xp": int, "enabled": bool }`.
({int xp, bool enabled}) _parseXpEvent(dynamic raw, int fallbackXp) {
  if (raw == null) return (xp: fallbackXp, enabled: true);
  if (raw is num) return (xp: raw.toInt(), enabled: true);
  if (raw is Map) {
    final m = Map<String, dynamic>.from(raw);
    return (
      xp: (m['xp'] as num?)?.toInt() ?? fallbackXp,
      enabled: m['enabled'] != false,
    );
  }
  return (xp: fallbackXp, enabled: true);
}

// ── XpTab ──────────────────────────────────────────────────────────────────────
class XpTab extends StatefulWidget {
  const XpTab();

  @override
  State<XpTab> createState() => _XpTabState();
}

class _XpTabState extends State<XpTab> with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3, height: 20,
                decoration: BoxDecoration(color: adminGold, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(
                'GESTION XP',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20, fontWeight: FontWeight.w900, color: adminTextPrimary, letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('app_config')
                .doc('prono_social')
                .snapshots(),
            builder: (context, snap) {
              final cfg = snap.data?.data();
              final lvls =
                  PronoSocialService.levelsListFromFirestore(cfg?['levels']);
              final tierOne = lvls.isNotEmpty
                  ? (lvls.first['name'] as String? ?? '—')
                  : 'Recrue (paliers par défaut si liste vide)';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: adminGold.withAlpha(16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: adminGold.withAlpha(50)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: adminGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Même document que l’onglet Prono et les profils : '
                        'app_config/prono_social. Niveau 1 actuellement affiché '
                        'dans l’app : « $tierOne ».',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: adminGrey,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ── Tabs ────────────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: TabBar(
            controller: _tc,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: adminGold.withAlpha(30),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: adminGold.withAlpha(80)),
            ),
            labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
            labelColor: adminGold,
            unselectedLabelColor: adminGrey,
            tabs: const [
              Tab(text: 'ÉVÉNEMENTS'),
              Tab(text: 'NIVEAUX'),
              Tab(text: 'CLASSEMENT'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _XpEventsPanel(),
              _XpLevelsPanel(),
              _XpLeaderboardPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── XP Events ─────────────────────────────────────────────────────────────────
class _XpEventsPanel extends StatelessWidget {
  const _XpEventsPanel();

  static const _defaultEvents = [
    {'key': 'vote_prono', 'label': 'Vote pronostic', 'xp': 5},
    {'key': 'prono_correct', 'label': 'Pronostic correct', 'xp': 20},
    {'key': 'article_read', 'label': 'Article lu', 'xp': 2},
    {'key': 'chat_message', 'label': 'Message chat', 'xp': 1},
    {'key': 'match_comment', 'label': 'Commentaire match', 'xp': 3},
    {'key': 'share_app', 'label': 'Partage appli', 'xp': 10},
    {'key': 'daily_login', 'label': 'Connexion quotidienne', 'xp': 5},
    {'key': 'badge_earned', 'label': 'Badge obtenu', 'xp': 15},
    {'key': 'referral_sent', 'label': 'Parrainage envoyé (parrain)', 'xp': 50},
    {'key': 'referral_used', 'label': 'Code parrainage utilisé (filleul)', 'xp': 25},
    {'key': 'emission_poll_vote', 'label': 'Vote sondage émission', 'xp': 3},
    {'key': 'motm_vote', 'label': 'Vote homme du match', 'xp': 3},
    {'key': 'replay_watched', 'label': 'Replay regardé', 'xp': 2},
    {'key': 'profile_complete', 'label': 'Profil complété', 'xp': 10},
    {'key': 'favorite_team_set', 'label': 'Équipe favorite enregistrée', 'xp': 5},
  ];

  static final _builtInKeys = _defaultEvents.map((e) => e['key'] as String).toSet();

  static Future<Map<String, dynamic>> _loadXpConfigMap() async {
    final snap = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('xp_config')
        .get();
    return Map<String, dynamic>.from(snap.data() ?? const {});
  }

  static Future<void> _writeEventsMerge(Map<String, dynamic> patch) async {
    await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('xp_config')
        .set(patch, SetOptions(merge: true));
  }

  static Future<void> _persistEvent(
    String key,
    int xp,
    bool enabled, {
    Map<String, dynamic>? fullEventsOverride,
  }) async {
    final data = fullEventsOverride ?? await _loadXpConfigMap();
    final events = Map<String, dynamic>.from(
      (data['events'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    events[key] = {'xp': xp, 'enabled': enabled};
    await _writeEventsMerge({'events': events});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('xp_config')
          .snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final events = (data['events'] as Map<String, dynamic>?) ?? {};
        final labels = (data['eventLabels'] as Map<String, dynamic>?) ?? {};

        final extraKeys = events.keys
            .where((k) => !_builtInKeys.contains(k))
            .toList()
          ..sort();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: adminBlue.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBlue.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: adminBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Interrupteur : désactivé = aucun XP (callable awardXp, pronos, parrainage). '
                      'Tu peux ajouter des clés personnalisées pour brancher l’app plus tard.',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            ..._defaultEvents.map((e) {
              final key = e['key'] as String;
              final label = e['label'] as String;
              final defaultXp = e['xp'] as int;
              final cfg = _parseXpEvent(events[key], defaultXp);
              return _XpEventRow(
                label: label,
                eventKey: key,
                value: cfg.xp,
                enabled: cfg.enabled,
                builtIn: true,
                onToggle: (en) => _persistEvent(key, cfg.xp, en),
                onSave: (v) => _persistEvent(key, v, cfg.enabled),
              );
            }),
            if (extraKeys.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'ÉVÉNEMENTS PERSONNALISÉS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                ),
              ),
              const SizedBox(height: 8),
              ...extraKeys.map((key) {
                final cfg = _parseXpEvent(events[key], 0);
                final label = (labels[key] ?? key).toString();
                return _XpEventRow(
                  label: label,
                  eventKey: key,
                  value: cfg.xp,
                  enabled: cfg.enabled,
                  builtIn: false,
                  onToggle: (en) => _persistEvent(key, cfg.xp, en),
                  onSave: (v) => _persistEvent(key, v, cfg.enabled),
                  onDelete: () async {
                    final ok = await adminConfirm(
                      context,
                      'Supprimer l’événement « $key » de la config ?',
                    );
                    if (!ok) return;
                    final fresh = await _loadXpConfigMap();
                    final ev = Map<String, dynamic>.from(
                      (fresh['events'] as Map?)?.cast<String, dynamic>() ?? const {},
                    );
                    final lb = Map<String, dynamic>.from(
                      (fresh['eventLabels'] as Map?)?.cast<String, dynamic>() ?? const {},
                    );
                    ev.remove(key);
                    lb.remove(key);
                    await _writeEventsMerge({'events': ev, 'eventLabels': lb});
                  },
                );
              }),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _XpEventsPanel._showAddCustomEvent(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: adminGold.withAlpha(70)),
                  borderRadius: BorderRadius.circular(10),
                  color: adminGold.withAlpha(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: adminGold),
                    const SizedBox(width: 6),
                    Text(
                      'AJOUTER UN ÉVÉNEMENT (CLÉ TECHNIQUE)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: adminGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final ok = await adminConfirm(
                  context,
                  'Remettre les événements intégrés aux valeurs par défaut (XP + activés) ? '
                  'Les événements personnalisés ne sont pas supprimés.',
                );
                if (!ok) return;
                final fresh = await _loadXpConfigMap();
                final ev = Map<String, dynamic>.from(
                  (fresh['events'] as Map?)?.cast<String, dynamic>() ?? const {},
                );
                for (final e in _defaultEvents) {
                  final k = e['key'] as String;
                  ev[k] = {'xp': e['xp'] as int, 'enabled': true};
                }
                await _writeEventsMerge({'events': ev});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: adminBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'RÉINITIALISER LES ÉVÉNEMENTS INTÉGRÉS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: adminGrey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showAddCustomEvent(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final xpCtrl = TextEditingController(text: '5');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Nouvel événement XP',
          style: GoogleFonts.barlowCondensed(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Étape 1 — Tu enregistres ici une clé (snake_case) et le nombre d’XP : '
                'elles partent dans Firestore `app_settings/xp_config` → `events`.\n\n'
                'Étape 2 — Pour que ça donne vraiment des points, il faut appeler la Cloud Function '
                '`awardXp` au bon moment dans le code, avec le même `eventType` que la clé.\n\n'
                'Exemple côté app : `httpsCallable(\'awardXp\').call({\'eventType\': \'live_reaction\'});`\n\n'
                'Sans l’étape 2, la ligne n’apparaît que dans l’admin : aucun utilisateur ne reçoit d’XP.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminGrey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyCtrl,
                style: GoogleFonts.inter(color: adminTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Clé technique',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: labelCtrl,
                style: GoogleFonts.inter(color: adminTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'Libellé admin',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: xpCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: adminTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'XP',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () async {
              final rawKey = keyCtrl.text.trim().toLowerCase();
              if (!RegExp(r'^[a-z][a-z0-9_]{1,38}$').hasMatch(rawKey)) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Clé invalide : minuscules, chiffres, underscore, 2–40 caractères, commence par une lettre.',
                    ),
                  ),
                );
                return;
              }
              if (_builtInKeys.contains(rawKey)) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cette clé est déjà un événement intégré.')),
                );
                return;
              }
              final xp = int.tryParse(xpCtrl.text.trim()) ?? 0;
              final fresh = await _loadXpConfigMap();
              final ev = Map<String, dynamic>.from(
                (fresh['events'] as Map?)?.cast<String, dynamic>() ?? const {},
              );
              final lb = Map<String, dynamic>.from(
                (fresh['eventLabels'] as Map?)?.cast<String, dynamic>() ?? const {},
              );
              if (ev.containsKey(rawKey)) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cette clé existe déjà.')),
                );
                return;
              }
              ev[rawKey] = {'xp': xp, 'enabled': true};
              final lbl = labelCtrl.text.trim();
              if (lbl.isNotEmpty) {
                lb[rawKey] = lbl;
              }
              await _writeEventsMerge({'events': ev, 'eventLabels': lb});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Créer', style: GoogleFonts.inter(color: adminGold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _XpEventRow extends StatefulWidget {
  final String label;
  final String eventKey;
  final int value;
  final bool enabled;
  final bool builtIn;
  final Future<void> Function(bool enabled) onToggle;
  final Future<void> Function(int xp) onSave;
  final Future<void> Function()? onDelete;

  const _XpEventRow({
    required this.label,
    required this.eventKey,
    required this.value,
    required this.enabled,
    required this.builtIn,
    required this.onToggle,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_XpEventRow> createState() => _XpEventRowState();
}

class _XpEventRowState extends State<_XpEventRow> {
  late final TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_XpEventRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_editing) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactive = !widget.enabled;
    return Opacity(
      opacity: inactive ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _editing ? adminGold.withAlpha(80) : adminBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                      if (!widget.builtIn)
                        Text(
                          widget.eventKey,
                          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                        ),
                    ],
                  ),
                ),
                Text(
                  'Actif',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: adminGrey),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 28,
                  child: _toggling
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: adminGold),
                          ),
                        )
                      : Switch(
                          value: widget.enabled,
                          onChanged: (v) async {
                            setState(() => _toggling = true);
                            try {
                              await widget.onToggle(v);
                            } finally {
                              if (mounted) setState(() => _toggling = false);
                            }
                          },
                          activeThumbColor: adminGold,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_editing) ...[
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13, color: adminGold),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: adminGold),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: adminGold),
                        ),
                        suffix: Text('XP', style: GoogleFonts.inter(fontSize: 10, color: adminGrey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _saving
                        ? null
                        : () async {
                            final v = int.tryParse(_ctrl.text);
                            if (v == null) return;
                            setState(() => _saving = true);
                            await widget.onSave(v);
                            if (mounted) {
                              setState(() {
                                _saving = false;
                                _editing = false;
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: adminGold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              'OK',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _editing = false;
                      _ctrl.text = widget.value.toString();
                    }),
                    child: const Icon(Icons.close_rounded, size: 16, color: adminGrey),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inactive ? adminGrey.withAlpha(24) : adminGold.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: inactive ? adminBorder : adminGold.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      inactive ? '+${widget.value} XP (off)' : '+${widget.value} XP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: inactive ? adminGrey : adminGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _editing = true),
                    child: const Icon(Icons.edit_rounded, size: 15, color: adminGrey),
                  ),
                  if (widget.onDelete != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => widget.onDelete!(),
                      child: const Icon(Icons.delete_outline_rounded, size: 18, color: adminRed),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── XP Levels ─────────────────────────────────────────────────────────────────
// Les niveaux sont stockés dans app_config/prono_social → levels (liste dynamique)
// Chaque entrée : {level, name, xpRequired, imageUrl}
class _XpLevelsPanel extends StatelessWidget {
  const _XpLevelsPanel();

  static final _ref = FirebaseFirestore.instance.collection('app_config').doc('prono_social');

  static const _defaultLevels = [
    {'level': 1, 'name': 'Recrue',       'xpRequired': 0,    'imageUrl': ''},
    {'level': 2, 'name': 'Fan',          'xpRequired': 150,  'imageUrl': ''},
    {'level': 3, 'name': 'Supporter',    'xpRequired': 400,  'imageUrl': ''},
    {'level': 4, 'name': 'Ultra',        'xpRequired': 900,  'imageUrl': ''},
    {'level': 5, 'name': 'Capitaine',    'xpRequired': 1800, 'imageUrl': ''},
    {'level': 6, 'name': 'Legende',      'xpRequired': 3500, 'imageUrl': ''},
  ];

  Future<void> _save(List<Map<String, dynamic>> levels) async {
    await _ref.set({'levels': levels}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final raw = data['levels'] as List?;
        final levels = raw != null && raw.isNotEmpty
            ? PronoSocialService.levelsListFromFirestore(raw)
            : _defaultLevels.map((e) => Map<String, dynamic>.from(e)).toList();
        levels.sort((a, b) => ((a['xpRequired'] as num?) ?? 0).compareTo((b['xpRequired'] as num?) ?? 0));
        for (int i = 0; i < levels.length; i++) levels[i]['level'] = i + 1;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: adminBlue.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBlue.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: adminBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un seul « badge » visuel : celui du palier atteint. Pour chaque niveau, '
                      'renseigne une URL HTTPS vers ta photo (PNG/JPG, lien public). '
                      'Colle l’adresse depuis le presse-papiers dans l’édition du palier.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...levels.asMap().entries.map((e) {
              final lvl = e.value;
              final idx = e.key;
              return _LevelRow(
                level: lvl,
                canDelete: levels.length > 1 && idx > 0,
                onEdit: (updated) async {
                  final copy = List<Map<String, dynamic>>.from(levels);
                  copy[idx] = updated;
                  copy.sort((a, b) => ((a['xpRequired'] as num?) ?? 0).compareTo((b['xpRequired'] as num?) ?? 0));
                  for (int i = 0; i < copy.length; i++) copy[i]['level'] = i + 1;
                  await _save(copy);
                },
                onDelete: () async {
                  final copy = List<Map<String, dynamic>>.from(levels)..removeAt(idx);
                  for (int i = 0; i < copy.length; i++) copy[i]['level'] = i + 1;
                  await _save(copy);
                },
              );
            }),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showAddSheet(context, levels),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: adminGold.withAlpha(60)),
                  borderRadius: BorderRadius.circular(10),
                  color: adminGold.withAlpha(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: adminGold),
                    const SizedBox(width: 6),
                    Text('AJOUTER UN PALIER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: adminGold)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddSheet(BuildContext context, List<Map<String, dynamic>> levels) {
    final nameCtrl = TextEditingController();
    final xpCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          bool saving = false;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOUVEAU PALIER', style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w900, color: adminGold, letterSpacing: 2)),
                const SizedBox(height: 16),
                AdminField(ctrl: nameCtrl, label: 'Nom du palier'),
                const SizedBox(height: 10),
                AdminField(ctrl: xpCtrl, label: 'XP requis pour ce palier', keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                AdminField(ctrl: urlCtrl, label: 'URL image (optionnel)'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      if (saving) return;
                      if (nameCtrl.text.trim().isEmpty) return;
                      setSt(() => saving = true);
                      final copy = List<Map<String, dynamic>>.from(levels);
                      copy.add({
                        'level': copy.length + 1,
                        'name': nameCtrl.text.trim(),
                        'xpRequired': int.tryParse(xpCtrl.text) ?? 0,
                        'imageUrl': urlCtrl.text.trim(),
                      });
                      copy.sort((a, b) => ((a['xpRequired'] as num?) ?? 0).compareTo((b['xpRequired'] as num?) ?? 0));
                      for (int i = 0; i < copy.length; i++) {
                        copy[i]['level'] = i + 1;
                      }
                      await _save(copy);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE1C15A), adminGold]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: _SheetPrimaryButtonLabel(saving: saving, label: 'CRÉER'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SheetPrimaryButtonLabel extends StatelessWidget {
  final bool saving;
  final String label;

  const _SheetPrimaryButtonLabel({required this.saving, required this.label});

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
      );
    }
    return Text(
      label,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final Map<String, dynamic> level;
  final bool canDelete;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function() onDelete;

  const _LevelRow({required this.level, required this.canDelete, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = level['name'] as String? ?? '';
    final xpRequired = (level['xpRequired'] as num?)?.toInt() ?? 0;
    final imageUrl = level['imageUrl'] as String? ?? '';
    final lvlNum = (level['level'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: adminGold.withAlpha(18),
              shape: BoxShape.circle,
              border: Border.all(color: adminGold.withAlpha(70)),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text('L$lvlNum', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w900, color: adminGold)),
                    ))
                : Center(
                    child: Text('L$lvlNum', style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w900, color: adminGold)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: adminTextPrimary)),
                const SizedBox(height: 2),
                Text('Seuil : $xpRequired XP', style: GoogleFonts.inter(fontSize: 11, color: adminGrey)),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(imageUrl, style: GoogleFonts.inter(fontSize: 9, color: adminGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditSheet(context),
            child: const Icon(Icons.edit_rounded, size: 16, color: adminGrey),
          ),
          if (canDelete) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final ok = await adminConfirm(context, 'Supprimer le palier "$name" ?');
                if (ok) await onDelete();
              },
              child: const Icon(Icons.delete_outline_rounded, size: 16, color: adminRed),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: level['name'] as String? ?? '');
    final xpCtrl = TextEditingController(text: ((level['xpRequired'] as num?)?.toInt() ?? 0).toString());
    final urlCtrl = TextEditingController(text: level['imageUrl'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          bool saving = false;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PALIER ${level['level']}', style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w900, color: adminGold, letterSpacing: 2)),
                const SizedBox(height: 16),
                AdminField(ctrl: nameCtrl, label: 'Nom du palier'),
                const SizedBox(height: 10),
                AdminField(ctrl: xpCtrl, label: 'XP requis', keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AdminField(
                        ctrl: urlCtrl,
                        label: 'URL de la photo du palier (HTTPS)',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: IconButton.filledTonal(
                        onPressed: () async {
                          final clip = await Clipboard.getData('text/plain');
                          final t = clip?.text?.trim();
                          if (t != null && t.isNotEmpty) {
                            urlCtrl.text = t;
                            setSt(() {});
                          }
                        },
                        icon: const Icon(Icons.content_paste_rounded, size: 20),
                        tooltip: 'Coller depuis le presse-papiers',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Photo affichée pour ce palier dans l’app (cercle de niveau). Lien HTTPS public.',
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      if (saving) return;
                      setSt(() => saving = true);
                      await onEdit({
                        ...level,
                        'name': nameCtrl.text.trim(),
                        'xpRequired': int.tryParse(xpCtrl.text) ?? 0,
                        'imageUrl': urlCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE1C15A), adminGold]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: _SheetPrimaryButtonLabel(saving: saving, label: 'ENREGISTRER'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── XP Leaderboard ─────────────────────────────────────────────────────────────
class _XpLeaderboardPanel extends StatelessWidget {
  const _XpLeaderboardPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('xp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: adminGold));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('Aucun utilisateur avec XP', style: GoogleFonts.inter(color: adminGrey)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final name = d['displayName'] ?? d['email'] ?? 'Utilisateur';
            final xp = (d['xp'] as num?)?.toInt() ?? 0;
            final level = (d['level'] as num?)?.toInt() ?? 1;
            final isTop3 = i < 3;
            final medalEmoji = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '';
            final rankColor = i == 0 ? adminGold : i == 1 ? adminGreyLight : i == 2 ? const Color(0xFFCD7F32) : adminGrey;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isTop3 ? rankColor.withAlpha(12) : adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isTop3 ? rankColor.withAlpha(60) : adminBorder),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      isTop3 ? medalEmoji : '#${i + 1}',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: isTop3 ? 18 : 13, fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: adminTextPrimary)),
                        Text('Niveau $level', style: GoogleFonts.inter(fontSize: 10, color: adminGrey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: adminGold.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: adminGold.withAlpha(60)),
                    ),
                    child: Text(
                      '$xp XP',
                      style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w900, color: adminGold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
