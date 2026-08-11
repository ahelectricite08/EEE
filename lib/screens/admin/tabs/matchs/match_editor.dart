import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/match_stats_schema.dart';
import '../../../../models/benevole_posts.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../../../services/season_config_service.dart';
import '../../../../utils/match_competition.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_navigation.dart';
import '../../admin_components.dart';
import '../../widgets/match_admin_context_banner.dart';

/// Ligne de stat personnalisée
class _CustStat {
  final TextEditingController label = TextEditingController();
  final TextEditingController v1 = TextEditingController(text: '0');
  final TextEditingController v2 = TextEditingController(text: '0');
  void init(String lbl, String val1, String val2) {
    label.text = lbl;
    v1.text = val1;
    v2.text = val2;
  }
  void dispose() {
    label.dispose();
    v1.dispose();
    v2.dispose();
  }
}

class MatchEditorScreen extends StatefulWidget {
  final DocumentSnapshot? doc;
  const MatchEditorScreen({super.key, this.doc});

  @override
  State<MatchEditorScreen> createState() => _MatchEditorScreenState();
}

class _MatchEditorScreenState extends State<MatchEditorScreen> {
  late final TextEditingController _team1, _team2, _logo1, _logo2;
  late final TextEditingController _score1, _score2, _replay, _stadiumImage;
  late final TextEditingController _ville, _lieu, _adresse;
  late final TextEditingController _rank1, _rank2, _form1, _form2;
  late final TextEditingController _pos1, _pos2, _tirs1, _tirs2;
  late final TextEditingController _tirsCadres1, _tirsCadres2;
  late final TextEditingController _xg1, _xg2, _passes1, _passes2;
  late final TextEditingController _corners1, _corners2;
  late final TextEditingController _horsJeu1, _horsJeu2, _fautes1, _fautes2;
  late final TextEditingController _arretsGardien1, _arretsGardien2;
  late final TextEditingController _motmPlayer, _motmPartner, _motmLogo;
  final List<_CustStat> _extraStats = [];
  final List<Map<String, TextEditingController>> _goals = [];
  final List<Map<String, TextEditingController>> _yellowCards = [];
  final List<Map<String, TextEditingController>> _redCards = [];
  final List<Map<String, TextEditingController>> _subs = [];
  bool _statsExpanded = true;
  bool _importingLive = false;
  /// Après le live : false = lecture seule (rempli auto). true = correction manuelle.
  bool _factsCorrectionMode = false;
  bool _factsTouchedByUser = false;
  bool _applyingRemoteFacts = false;
  String _appliedFactsSignature = '';
  DateTime? _ignoreRemoteFactsUntil;
  StreamSubscription<DocumentSnapshot>? _matchFactsSub;
  StreamSubscription<DocumentSnapshot>? _liveFactsSub;
  final List<void Function()> _factsListenerRemovers = [];
  bool _showMotmOnCard = true;
  final Set<String> _activeStats = {
    'possession', 'tirs', 'tirsCadres', 'xg', 'passes',
    'corners', 'horsJeu', 'fautes', 'arretsGardien',
  };
  late String _competition;
  late String _benevoleType;
  late String _status;
  late DateTime _date;
  bool _saving = false;
  /// Match « À venir » : section stats / cartons repliable.
  bool _prepPostMatchExpanded = false;
  /// Publier scores & stats dans l’app malgré le statut « À venir ».
  bool _earlyPublish = false;

  static const _competitions = MatchCompetition.all;

  List<String> _competitionDropdownItems() {
    if (_competition.isNotEmpty && !_competitions.contains(_competition)) {
      return [..._competitions, _competition];
    }
    return _competitions;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.doc?.data() as Map<String, dynamic>?;
    _team1 = TextEditingController(text: d?['team1'] ?? 'SEDAN ARDENNES CS');
    _team2 = TextEditingController(text: d?['team2'] ?? '');
    _logo1 = TextEditingController(text: d?['logo1'] ?? '');
    _logo2 = TextEditingController(text: d?['logo2'] ?? '');
    _score1 = TextEditingController(text: d?['score1']?.toString() ?? '');
    _score2 = TextEditingController(text: d?['score2']?.toString() ?? '');
    _replay = TextEditingController(text: d?['replayVideoId'] ?? '');
    _stadiumImage = TextEditingController(text: d?['stadiumImageUrl'] ?? '');
    _ville = TextEditingController(
      text: (d?['ville'] ?? d?['city'] ?? '').toString(),
    );
    _lieu = TextEditingController(
      text: (d?['lieu'] ?? d?['stadium'] ?? '').toString(),
    );
    _adresse = TextEditingController(
      text: (d?['adresse'] ?? '').toString(),
    );
    _rank1 = TextEditingController(text: d?['rank1']?.toString() ?? '');
    _rank2 = TextEditingController(text: d?['rank2']?.toString() ?? '');
    _form1 = TextEditingController(text: d?['form1']?.toString() ?? '');
    _form2 = TextEditingController(text: d?['form2']?.toString() ?? '');
    final stats = d?['stats'] as Map<String, dynamic>?;
    _pos1 = TextEditingController(text: stats?['possession1']?.toString() ?? '50');
    _pos2 = TextEditingController(text: stats?['possession2']?.toString() ?? '50');
    _tirs1 = TextEditingController(text: stats?['tirs1']?.toString() ?? '0');
    _tirs2 = TextEditingController(text: stats?['tirs2']?.toString() ?? '0');
    _tirsCadres1 = TextEditingController(text: stats?['tirsCadres1']?.toString() ?? '0');
    _tirsCadres2 = TextEditingController(text: stats?['tirsCadres2']?.toString() ?? '0');
    _xg1 = TextEditingController(text: stats?['xg1']?.toString() ?? '0');
    _xg2 = TextEditingController(text: stats?['xg2']?.toString() ?? '0');
    _passes1 = TextEditingController(text: stats?['passes1']?.toString() ?? '0');
    _passes2 = TextEditingController(text: stats?['passes2']?.toString() ?? '0');
    _corners1 = TextEditingController(text: stats?['corners1']?.toString() ?? '0');
    _corners2 = TextEditingController(text: stats?['corners2']?.toString() ?? '0');
    _horsJeu1 = TextEditingController(text: stats?['horsJeu1']?.toString() ?? '0');
    _horsJeu2 = TextEditingController(text: stats?['horsJeu2']?.toString() ?? '0');
    _fautes1 = TextEditingController(text: stats?['fautes1']?.toString() ?? '0');
    _fautes2 = TextEditingController(text: stats?['fautes2']?.toString() ?? '0');
    _arretsGardien1 = TextEditingController(text: stats?['arretsGardien1']?.toString() ?? '0');
    _arretsGardien2 = TextEditingController(text: stats?['arretsGardien2']?.toString() ?? '0');
    _showMotmOnCard = (d?['showMotm'] as bool?) ?? true;
    _motmPlayer = TextEditingController(text: d?['manOfTheMatchName'] ?? '');
    _motmPartner = TextEditingController(text: d?['manOfTheMatchPartnerName'] ?? '');
    _motmLogo = TextEditingController(text: d?['manOfTheMatchPartnerLogo'] ?? '');
    _loadEventsIntoForm(
      MatchStatsSchema.eventsFromMatchDoc(
        d != null ? Map<String, dynamic>.from(d) : null,
      ),
    );
    if (stats != null) {
      if (!stats.containsKey('tirsCadres1')) _activeStats.remove('tirsCadres');
      if (!stats.containsKey('xg1')) _activeStats.remove('xg');
      if (!stats.containsKey('horsJeu1')) _activeStats.remove('horsJeu');
      if (!stats.containsKey('arretsGardien1')) _activeStats.remove('arretsGardien');
    }
    final customRaw = stats?['customStats'];
    if (customRaw is List) {
      for (final row in customRaw.whereType<Map<String, dynamic>>()) {
        final cs = _CustStat();
        cs.init(
          row['label']?.toString() ?? '',
          row['value1']?.toString() ?? '',
          row['value2']?.toString() ?? '',
        );
        _extraStats.add(cs);
      }
    }
    final rawComp = (d?['competition'] ?? '').toString().trim();
    _competition =
        rawComp.isNotEmpty ? rawComp : _competitions.first;
    final rawBenevoleType = (d?['benevoleType'] ?? '').toString().trim();
    if (rawBenevoleType.isNotEmpty &&
        BenevolePosts.eventTypes.contains(rawBenevoleType)) {
      _benevoleType = rawBenevoleType;
    } else {
      _benevoleType = rawComp.toLowerCase().contains('réserve') ||
              rawComp.toLowerCase().contains('reserve')
          ? BenevolePosts.typeReserve
          : BenevolePosts.typePremiere;
    }
    _status = d?['status'] ?? 'upcoming';
    _earlyPublish = d?['earlyPublish'] == true;
    _prepPostMatchExpanded = widget.doc == null || _status != 'upcoming';
    final ts = d?['date'];
    _date = ts is Timestamp
        ? ts.toDate()
        : DateTime.now().add(const Duration(days: 7));

    if (widget.doc != null && d != null) {
      _appliedFactsSignature = _factsSignature(d);
      _attachFactsListeners();
      _matchFactsSub = widget.doc!.reference.snapshots().listen(
            _onMatchDocChanged,
          );
      _liveFactsSub = FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots()
          .listen(_onLiveDocChanged);
    }
  }

  void _onLiveDocChanged(DocumentSnapshot snap) {
    if (!snap.exists ||
        _factsTouchedByUser ||
        _factsCorrectionMode ||
        widget.doc == null ||
        !mounted) {
      return;
    }
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;
    final liveMid = (data['matchId'] as String? ?? '').trim();
    if (liveMid != widget.doc!.id) return;
    final sig = _factsSignature(data);
    if (sig == _appliedFactsSignature) return;
    _appliedFactsSignature = sig;
    setState(() {
      _applyFactsFromMap(data);
      final motm = (data['manOfTheMatchName'] as String? ?? '').trim();
      if (motm.isNotEmpty) {
        _motmPlayer.text = motm;
        _motmPartner.text =
            data['manOfTheMatchPartnerName'] as String? ?? '';
        _motmLogo.text = data['manOfTheMatchPartnerLogo'] as String? ?? '';
      }
    });
  }

  void _attachFactsListeners() {
    for (final c in [_score1, _score2]) {
      void listener() => _onLocalFactsEdit();
      c.addListener(listener);
      _factsListenerRemovers.add(() => c.removeListener(listener));
    }
  }

  void _onLocalFactsEdit() {
    if (_applyingRemoteFacts) return;
    if (!_factsTouchedByUser && mounted) {
      setState(() => _factsTouchedByUser = true);
    }
  }

  void _onMatchDocChanged(DocumentSnapshot snap) {
    if (!snap.exists || _factsTouchedByUser || !mounted) return;
    final d = snap.data() as Map<String, dynamic>?;
    if (d == null) return;
    final sig = _factsSignature(d);
    if (sig == _appliedFactsSignature) return;
    _appliedFactsSignature = sig;
    setState(() => _applyFactsFromMap(d));
  }

  String _factsSignature(Map<String, dynamic> d) {
    final events = MatchStatsSchema.eventsFromMatchDoc(d);
    return Object.hashAll([
      events.length,
      d['yellowHome'],
      d['yellowAway'],
      d['redHome'],
      d['redAway'],
      d['score1'],
      d['score2'],
      ...events.map(
        (e) => Object.hash(
          e['type'],
          e['minute'],
          e['player'],
          e['playerIn'],
          e['playerOut'],
          e['team'],
        ),
      ),
    ]).toString();
  }

  void _disposeCardRow(Map<String, TextEditingController> row) {
    for (final c in row.values) {
      c.dispose();
    }
  }

  void _clearGoalsAndSubs() {
    for (final g in _goals) {
      _disposeCardRow(g);
    }
    _goals.clear();
    for (final c in _yellowCards) {
      _disposeCardRow(c);
    }
    _yellowCards.clear();
    for (final c in _redCards) {
      _disposeCardRow(c);
    }
    _redCards.clear();
    for (final s in _subs) {
      s['playerOut']!.dispose();
      s['playerIn']!.dispose();
      s['minute']!.dispose();
      s['team']!.dispose();
    }
    _subs.clear();
  }

  void _loadEventsIntoForm(List<Map<String, dynamic>> parsedEvents) {
    _clearGoalsAndSubs();
    for (final e in parsedEvents) {
      final type = (e['type'] as String? ?? '').trim().toLowerCase();
      if (type == 'goal') {
        _goals.add({
          'player': TextEditingController(text: e['player']?.toString() ?? ''),
          'minute': TextEditingController(text: e['minute']?.toString() ?? ''),
          'team': TextEditingController(text: e['team']?.toString() ?? ''),
        });
      } else if (type == 'yellow') {
        _yellowCards.add({
          'player': TextEditingController(text: e['player']?.toString() ?? ''),
          'minute': TextEditingController(text: e['minute']?.toString() ?? ''),
          'team': TextEditingController(text: e['team']?.toString() ?? ''),
        });
      } else if (type == 'red') {
        _redCards.add({
          'player': TextEditingController(text: e['player']?.toString() ?? ''),
          'minute': TextEditingController(text: e['minute']?.toString() ?? ''),
          'team': TextEditingController(text: e['team']?.toString() ?? ''),
        });
      } else if (type == 'substitution') {
        _subs.add({
          'playerOut': TextEditingController(
            text: (e['playerOut'] ?? e['player'])?.toString() ?? '',
          ),
          'playerIn': TextEditingController(
            text: e['playerIn']?.toString() ?? '',
          ),
          'minute': TextEditingController(text: e['minute']?.toString() ?? ''),
          'team': TextEditingController(text: e['team']?.toString() ?? ''),
        });
      }
    }
  }

  String _cardTotalsLabel() {
    final t1 = _team1.text.trim();
    final t2 = _team2.text.trim();
    if (t1.isEmpty && t2.isEmpty) return '';
    var yH = 0, yA = 0, rH = 0, rA = 0;
    for (final c in _yellowCards) {
      final e = {'team': c['team']!.text.trim()};
      if (MatchStatsSchema.isHomeTeamEvent(e, t1, t2)) {
        yH++;
      } else {
        yA++;
      }
    }
    for (final c in _redCards) {
      final e = {'team': c['team']!.text.trim()};
      if (MatchStatsSchema.isHomeTeamEvent(e, t1, t2)) {
        rH++;
      } else {
        rA++;
      }
    }
    return 'Jaunes $yH-$yA · Rouges $rH-$rA';
  }

  void _applyFactsFromMap(Map<String, dynamic> d) {
    _applyingRemoteFacts = true;
    try {
      final resolved = MatchStatsSchema.resolveMatchScores(
        d,
        events: MatchStatsSchema.eventsFromMatchDoc(d),
      );
      _score1.text = '${resolved.home}';
      _score2.text = '${resolved.away}';
      _loadEventsIntoForm(MatchStatsSchema.eventsFromMatchDoc(d));
    } finally {
      _applyingRemoteFacts = false;
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      _team1, _team2, _logo1, _logo2, _score1, _score2, _replay, _stadiumImage,
      _ville, _lieu, _adresse,
      _rank1, _rank2, _form1, _form2,
      _pos1, _pos2, _tirs1, _tirs2, _tirsCadres1, _tirsCadres2,
      _xg1, _xg2, _passes1, _passes2, _corners1, _corners2,
      _horsJeu1, _horsJeu2, _fautes1, _fautes2, _arretsGardien1, _arretsGardien2,
      _motmPlayer, _motmPartner, _motmLogo,
    ]) ctrl.dispose();
    for (final cs in _extraStats) cs.dispose();
    for (final g in _goals) {
      g['player']!.dispose();
      g['minute']!.dispose();
      g['team']!.dispose();
    }
    for (final s in _subs) {
      s['playerOut']!.dispose();
      s['playerIn']!.dispose();
      s['minute']!.dispose();
      s['team']!.dispose();
    }
    _matchFactsSub?.cancel();
    _liveFactsSub?.cancel();
    for (final remove in _factsListenerRemovers) {
      remove();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: adminGold,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final picked2 = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: adminGold,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() => _date = DateTime(
      picked.year, picked.month, picked.day,
      picked2?.hour ?? _date.hour,
      picked2?.minute ?? _date.minute,
    ));
  }

  Future<void> _importFromLive() async {
    setState(() => _importingLive = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun live en cours')),
        );
        return;
      }
      final liveData = snap.data() ?? {};
      setState(() {
        final motmName = (liveData['manOfTheMatchName'] as String? ?? '').trim();
        if (motmName.isNotEmpty) {
          _motmPlayer.text = motmName;
          _motmPartner.text = liveData['manOfTheMatchPartnerName'] as String? ?? '';
          _motmLogo.text = liveData['manOfTheMatchPartnerLogo'] as String? ?? '';
        }
        _applyFactsFromMap(Map<String, dynamic>.from(liveData));
      });
      if (mounted) {
        setState(() => _factsTouchedByUser = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live importé ✓ (MOTM, cartons, buteurs)'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importingLive = false);
    }
  }

  Widget _buildPlayerCardSection({
    required String title,
    required Color accent,
    required List<Map<String, TextEditingController>> list,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: adminGrey,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  border: Border.all(color: accent.withAlpha(100)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'AJOUTER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (list.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Aucun carton — ajoute une ligne ou importe depuis le live',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
          ),
        ] else ...[
          const SizedBox(height: 8),
          ...list.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AdminField(
                      ctrl: e.value['player']!,
                      label: 'Joueur',
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 50,
                    child: AdminField(
                      ctrl: e.value['minute']!,
                      label: 'Min',
                    ),
                  ),
                  const SizedBox(width: 6),
                  _TeamToggle(
                    current: e.value['team']!.text,
                    team1: _team1.text.trim(),
                    team2: _team2.text.trim(),
                    onChanged: (v) => setState(() {
                      _factsTouchedByUser = true;
                      e.value['team']!.text = v;
                    }),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _factsTouchedByUser = true;
                      _disposeCardRow(e.value);
                      list.removeAt(e.key);
                    }),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: adminGrey,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFactsSyncBar() {
    if (widget.doc == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, liveSnap) {
        final live = liveSnap.data?.data() ?? {};
        final liveMid = (live['matchId'] ?? '').toString().trim();
        final isLiveForMatch = liveMid == widget.doc!.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLiveForMatch
                ? const Color(0xFF4A90D9).withAlpha(18)
                : adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLiveForMatch
                  ? const Color(0xFF4A90D9).withAlpha(100)
                  : adminBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isLiveForMatch
                        ? Icons.sync_rounded
                        : Icons.cloud_sync_outlined,
                    size: 16,
                    color: isLiveForMatch
                        ? const Color(0xFF4A90D9)
                        : adminGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLiveForMatch
                          ? 'Live connecté sur ce match'
                          : 'Import ou saisie manuelle',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: adminTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isLiveForMatch
                    ? 'Les buts, cartons et remplacements du direct remplissent '
                        'cette fiche automatiquement. Tu peux corriger à la main puis enregistrer.'
                    : 'Saisie manuelle possible. Si un live est lancé sur ce match, '
                        'utilise le bouton ci-dessous pour récupérer les faits.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              if (_factsTouchedByUser) ...[
                const SizedBox(height: 6),
                Text(
                  'Modifications locales non enregistrées — ENREGISTRER pour '
                  'mettre à jour la fiche match.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: adminGold,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _importingLive ? null : _importFromLive,
                icon: _importingLive
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  isLiveForMatch
                      ? 'Rafraîchir depuis le live'
                      : 'Importer depuis le live',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A90D9),
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteAllStats() {
    setState(() {
      _pos1.text = '50';
      _pos2.text = '50';
      for (final c in [
        _tirs1, _tirs2, _tirsCadres1, _tirsCadres2, _xg1, _xg2,
        _passes1, _passes2, _corners1, _corners2, _horsJeu1, _horsJeu2,
        _fautes1, _fautes2, _arretsGardien1, _arretsGardien2,
      ]) c.text = '0';
      for (final cs in _extraStats) cs.dispose();
      _extraStats.clear();
    });
  }

  Widget _sRow(String key, TextEditingController c1, TextEditingController c2, String l1, String l2) {
    final active = _activeStats.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (active) _activeStats.remove(key); else _activeStats.add(key);
            }),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: active ? adminGold.withAlpha(30) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: active ? adminGold : adminBorder),
              ),
              child: active
                  ? const Icon(Icons.check_rounded, size: 13, color: adminGold)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: active ? 1.0 : 0.35,
              child: Row(
                children: [
                  Expanded(child: AdminField(ctrl: c1, label: l1)),
                  const SizedBox(width: 8),
                  Expanded(child: AdminField(ctrl: c2, label: l2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildStatsPayload() {
    final out = <String, dynamic>{};
    void pair(String key, TextEditingController c1, TextEditingController c2) {
      if (!_activeStats.contains(key)) return;
      final v1 = int.tryParse(c1.text.trim()) ?? 0;
      final v2 = int.tryParse(c2.text.trim()) ?? 0;
      out['${key}1'] = v1;
      out['${key}2'] = v2;
    }

    pair('possession', _pos1, _pos2);
    if (_activeStats.contains('tirs')) {
      out['tirs1'] = int.tryParse(_tirs1.text.trim()) ?? 0;
      out['tirs2'] = int.tryParse(_tirs2.text.trim()) ?? 0;
    }
    if (_activeStats.contains('tirsCadres')) {
      out['tirsCadres1'] = int.tryParse(_tirsCadres1.text.trim()) ?? 0;
      out['tirsCadres2'] = int.tryParse(_tirsCadres2.text.trim()) ?? 0;
    }
    if (_activeStats.contains('xg')) {
      out['xg1'] = double.tryParse(_xg1.text.trim().replaceAll(',', '.')) ?? 0;
      out['xg2'] = double.tryParse(_xg2.text.trim().replaceAll(',', '.')) ?? 0;
    }
    pair('passes', _passes1, _passes2);
    pair('corners', _corners1, _corners2);
    pair('horsJeu', _horsJeu1, _horsJeu2);
    pair('fautes', _fautes1, _fautes2);
    pair('arretsGardien', _arretsGardien1, _arretsGardien2);

    if (_extraStats.isNotEmpty) {
      out['customStats'] = _extraStats
          .where((s) => s.label.text.trim().isNotEmpty)
          .map((s) => {
            'label': s.label.text.trim(),
            'value1': s.v1.text.trim(),
            'value2': s.v2.text.trim(),
          })
          .toList();
    }
    return MatchStatsSchema.normalizeMap(out);
  }

  void _bumpStat(TextEditingController c, int delta) {
    final v = (int.tryParse(c.text.trim()) ?? 0) + delta;
    c.text = v.clamp(0, 999).toString();
  }

  Future<void> _save() async {
    if (_team1.text.trim().isEmpty || _team2.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final seasonLabel = (await SeasonConfigService.getCurrent()).seasonLabel;
      final payload = <String, dynamic>{
        'team1': _team1.text.trim(),
        'team2': _team2.text.trim(),
        'competition': _competition,
        'benevoleType': _benevoleType,
        'status': _status,
        'date': Timestamp.fromDate(_date),
        'fffSeason': seasonLabel,
      };
      if (_logo1.text.trim().isNotEmpty) payload['logo1'] = _logo1.text.trim();
      if (_logo2.text.trim().isNotEmpty) payload['logo2'] = _logo2.text.trim();
      if (_stadiumImage.text.trim().isNotEmpty) {
        payload['stadiumImageUrl'] = _stadiumImage.text.trim();
      } else if (widget.doc != null) {
        payload['stadiumImageUrl'] = FieldValue.delete();
      }
      final ville = _ville.text.trim();
      if (ville.isNotEmpty) {
        payload['ville'] = ville;
        payload['city'] = ville;
      } else if (widget.doc != null) {
        payload['ville'] = FieldValue.delete();
        payload['city'] = FieldValue.delete();
      }
      final lieu = _lieu.text.trim();
      if (lieu.isNotEmpty) {
        payload['lieu'] = lieu;
        payload['stadium'] = lieu;
      } else if (widget.doc != null) {
        payload['lieu'] = FieldValue.delete();
        payload['stadium'] = FieldValue.delete();
      }
      final adresse = _adresse.text.trim();
      if (adresse.isNotEmpty) {
        payload['adresse'] = adresse;
      } else if (widget.doc != null) {
        payload['adresse'] = FieldValue.delete();
      }
      final s1 = int.tryParse(_score1.text.trim());
      final s2 = int.tryParse(_score2.text.trim());
      if (s1 != null) payload['score1'] = s1;
      if (s2 != null) payload['score2'] = s2;
      if (_replay.text.trim().isNotEmpty) payload['replayVideoId'] = _replay.text.trim();
      if (_rank1.text.trim().isNotEmpty) payload['rank1'] = int.tryParse(_rank1.text.trim()) ?? _rank1.text.trim();
      if (_rank2.text.trim().isNotEmpty) payload['rank2'] = int.tryParse(_rank2.text.trim()) ?? _rank2.text.trim();
      if (_form1.text.trim().isNotEmpty) payload['form1'] = _form1.text.trim().toUpperCase();
      if (_form2.text.trim().isNotEmpty) payload['form2'] = _form2.text.trim().toUpperCase();
      // Stats : module Statistiques match (match_stats) — pas d’écriture directe ici.
      payload['showMotm'] = _showMotmOnCard;
      payload['earlyPublish'] =
          _status == 'upcoming' ? _earlyPublish : false;
      payload['manOfTheMatchName'] = _motmPlayer.text.trim();
      payload['manOfTheMatchPartnerName'] = _motmPartner.text.trim();
      payload['manOfTheMatchPartnerLogo'] = _motmLogo.text.trim();
      // Préserver les `id` déjà liés aux clips audio / vMix (sinon le micro disparaît).
      final preferIdByKey = <String, String>{};
      if (widget.doc != null) {
        final existing = widget.doc!.data() as Map<String, dynamic>?;
        for (final e in MatchStatsSchema.eventsFromMatchDoc(existing)) {
          final id = (e['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          preferIdByKey.putIfAbsent(
            MatchStatsSchema.gameEventDedupeKey(e),
            () => id,
          );
        }
      }
      final goalEvents = _goals
          .where((g) => g['player']!.text.trim().isNotEmpty)
          .map((g) => {
            'type': 'goal',
            'player': g['player']!.text.trim(),
            'minute': int.tryParse(g['minute']!.text.trim()) ?? 0,
            'team': g['team']!.text.trim(),
          })
          .toList();
      final subEvents = _subs
          .where((s) =>
              s['playerOut']!.text.trim().isNotEmpty ||
              s['playerIn']!.text.trim().isNotEmpty)
          .map((s) {
            final out = s['playerOut']!.text.trim();
            final inn = s['playerIn']!.text.trim();
            return {
              'type': 'substitution',
              'playerOut': out,
              'playerIn': inn,
              'player': out,
              'minute': int.tryParse(s['minute']!.text.trim()) ?? 0,
              'team': s['team']!.text.trim(),
            };
          })
          .toList();
      List<Map<String, dynamic>> cardEvents(String type, List<Map<String, TextEditingController>> rows) =>
          rows
              .where((c) => c['player']!.text.trim().isNotEmpty)
              .map((c) => {
                    'type': type,
                    'player': c['player']!.text.trim(),
                    'minute': int.tryParse(c['minute']!.text.trim()) ?? 0,
                    'team': c['team']!.text.trim(),
                  })
              .toList();
      final events = MatchStatsSchema.withEnsuredEventIds(
        [
          ...goalEvents,
          ...cardEvents('yellow', _yellowCards),
          ...cardEvents('red', _redCards),
          ...subEvents,
        ],
        preferIdByKey: preferIdByKey,
      );
      final eventCounts = MatchStatsSchema.countFromEvents(
        events.cast<Map<String, dynamic>>(),
        _team1.text.trim(),
        _team2.text.trim(),
      );
      final yH = eventCounts.yellowHome;
      final yA = eventCounts.yellowAway;
      final rH = eventCounts.redHome;
      final rA = eventCounts.redAway;
      final hasPostMatchContent = events.isNotEmpty ||
          yH > 0 ||
          yA > 0 ||
          rH > 0 ||
          rA > 0 ||
          (s1 != null && s1 > 0) ||
          (s2 != null && s2 > 0);

      payload['events'] = events;
      payload['yellowHome'] = yH;
      payload['yellowAway'] = yA;
      payload['redHome'] = rH;
      payload['redAway'] = rA;

      late final String matchId;
      if (widget.doc == null) {
        payload['manual'] = true;
        final ref =
            await FirebaseFirestore.instance.collection('matches').add(payload);
        matchId = ref.id;
      } else {
        final existing = widget.doc!.data() as Map<String, dynamic>?;
        if (existing?['manual'] == true || hasPostMatchContent) {
          payload['manual'] = true;
        }
        await widget.doc!.reference.update(payload);
        matchId = widget.doc!.id;
      }

      var statsSyncWarning;
      if (hasPostMatchContent) {
        try {
          await MatchStatsSheetService.instance.syncFromMatchEditor(
            matchId: matchId,
            events: events.cast<Map<String, dynamic>>(),
            yellowHome: yH,
            yellowAway: yA,
            redHome: rH,
            redAway: rA,
            scoreHome: s1,
            scoreAway: s2,
            factsOnly: true,
          );
        } catch (e) {
          statsSyncWarning = e;
        }
      }

      if (mounted) {
        _factsTouchedByUser = false;
        _ignoreRemoteFactsUntil =
            DateTime.now().add(const Duration(seconds: 4));
        _appliedFactsSignature = _factsSignature({
          'events': events,
          'yellowHome': yH,
          'yellowAway': yA,
          'redHome': rH,
          'redAway': rA,
          'score1': s1 ?? 0,
          'score2': s2 ?? 0,
        });
        if (statsSyncWarning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Fiche match enregistrée (logos, date…). Stats non sync : $statsSyncWarning',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: adminGold.withAlpha(230),
              duration: const Duration(seconds: 8),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasPostMatchContent
                    ? 'Match enregistré (buteurs & cartons)'
                    : 'Match enregistré',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Échec enregistrement : $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminRed,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manualSaved = widget.doc != null &&
        ((widget.doc!.data() as Map<String, dynamic>?)?['manual'] ==
            true);
    final months = ['jan','fév','mar','avr','mai','juin','juil','aoû','sep','oct','nov','déc'];
    final days = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
    final dateStr = '${days[_date.weekday - 1]} ${_date.day} ${months[_date.month - 1]} · '
        '${_date.hour.toString().padLeft(2, '0')}h${_date.minute.toString().padLeft(2, '0')}';

    const accent = AdminModuleColors.preparation;
    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        backgroundColor: adminBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: adminTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.doc == null ? 'NOUVEAU MATCH' : 'MODIFIER LE MATCH',
              style: GoogleFonts.barlowCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 0.6,
                height: 1.05,
              ),
            ),
            Text(
              'Préparation · calendrier & faits de jeu',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: AdminPrimaryButton(
              label: 'Enregistrer',
              height: 36,
              loading: _saving,
              color: accent,
              textColor: Colors.white,
              onTap: _save,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: accent),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (widget.doc != null) ...[
            MatchAdminContextBanner(
              matchId: widget.doc!.id,
              team1: _team1.text,
              team2: _team2.text,
            ),
            const SizedBox(height: 10),
            _LiveEditHint(matchId: widget.doc!.id),
            const SizedBox(height: 18),
          ],
          _EditorSection(
            title: 'Équipes & affichage',
            eyebrow: 'Identité',
            icon: Icons.groups_rounded,
            children: [
              Row(children: [
                Expanded(child: AdminField(ctrl: _team1, label: 'Équipe domicile')),
                const SizedBox(width: 8),
                Expanded(child: AdminField(ctrl: _team2, label: 'Équipe extérieur')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AdminField(ctrl: _logo1, label: 'Logo domicile (URL)')),
                const SizedBox(width: 8),
                Expanded(child: AdminField(ctrl: _logo2, label: 'Logo extérieur (URL)')),
              ]),
              const SizedBox(height: 12),
              AdminField(ctrl: _stadiumImage, label: 'Photo du stade domicile (URL)'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AdminField(ctrl: _ville, label: 'Ville')),
                const SizedBox(width: 8),
                Expanded(child: AdminField(ctrl: _lieu, label: 'Lieu / stade')),
              ]),
              const SizedBox(height: 12),
              AdminField(
                ctrl: _adresse,
                label: 'Adresse (GPS / Y aller)',
                hint: 'Ex. 5 Rue Louis Dugauguez, 08000 Sedan',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _EditorSection(
            title: 'Calendrier & statut',
            eyebrow: 'Planning',
            icon: Icons.event_rounded,
            children: [
              _Dropdown(
                value: _competitionDropdownItems().contains(_competition)
                    ? _competition
                    : _competitionDropdownItems().first,
                items: _competitionDropdownItems(),
                onChanged: (v) => setState(() => _competition = v!),
              ),
              const SizedBox(height: 12),
              Text(
                'Type événement bénévoles (Make)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: adminGrey,
                ),
              ),
              const SizedBox(height: 6),
              _Dropdown(
                value: BenevolePosts.eventTypes.contains(_benevoleType)
                    ? _benevoleType
                    : BenevolePosts.typePremiere,
                items: BenevolePosts.eventTypes,
                onChanged: (v) => setState(() => _benevoleType = v!),
              ),
              const SizedBox(height: 12),
              _DropdownEnum(
                value: _status,
                items: [
                  DropdownMenuItem(
                    value: 'upcoming',
                    child: Text(
                      'À venir',
                      style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'finished',
                    child: Text(
                      'Terminé',
                      style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'live',
                    child: Text(
                      'En direct',
                      style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _status = v!;
                  if (_status == 'upcoming') {
                    _prepPostMatchExpanded = false;
                  } else {
                    _prepPostMatchExpanded = true;
                  }
                }),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: adminSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AdminModuleColors.preparation),
                      const SizedBox(width: 10),
                      Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary)),
                      const Spacer(),
                      Text('CHANGER', style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminModuleColors.preparation,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (widget.doc == null || manualSaved) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              text: widget.doc == null
                  ? 'Les matchs créés ici sont enregistrés en « manuel » : ils ne sont pas effacés par la synchro FFF. '
                      'L’API FFF ne met à jour que les fiches dont l’identifiant commence par fff_ (calendrier officiel).'
                  : 'Fiche manuelle : elle est conservée à chaque synchro FFF (non écrasée par l’API).',
            ),
          ],
          if (_status == 'upcoming') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Afficher scores & stats avant le coup d’envoi',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Si désactivé : dans l’app, « vs » sans score ni stats tant que le statut reste « À venir ».',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            height: 1.35,
                            color: adminGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _earlyPublish,
                    onChanged: (v) => setState(() => _earlyPublish = v),
                    activeThumbColor: AdminModuleColors.preparation,
                    inactiveThumbColor: adminGrey,
                    inactiveTrackColor: adminBorder,
                  ),
                ],
              ),
            ),
          ],
          if (_factsCorrectionMode &&
              (_status == 'finished' || _status == 'live')) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AdminField(ctrl: _score1, label: 'Score domicile')),
              const SizedBox(width: 8),
              Expanded(child: AdminField(ctrl: _score2, label: 'Score extérieur')),
            ]),
          ],
          if (_status == 'finished') ...[
            const SizedBox(height: 12),
            AdminField(ctrl: _replay, label: 'ID YouTube replay (optionnel)'),
          ],
          if (_status == 'upcoming' && !_prepPostMatchExpanded) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _prepPostMatchExpanded = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: adminBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_chart_rounded,
                        size: 22, color: AdminModuleColors.preparation),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRÉPARATION POST-MATCH',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: adminTextPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rempli automatiquement après le live — correction manuelle si besoin.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.3,
                              color: adminGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: adminGrey),
                  ],
                ),
              ),
            ),
          ],
          if (_status != 'upcoming' || _prepPostMatchExpanded) ...[
          const SizedBox(height: 12),
          _EditorSection(
            title: 'Faits de jeu & post-match',
            eyebrow: 'Après-match',
            accent: AdminModuleColors.apresMatch,
            icon: Icons.sports_soccer_rounded,
            children: _buildPostMatchFactsSection(),
          ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _exitFactsCorrection() async {
    setState(() {
      _factsCorrectionMode = false;
      _factsTouchedByUser = false;
    });
    if (widget.doc == null) return;
    final snap = await widget.doc!.reference.get();
    if (!mounted || !snap.exists) return;
    final d = snap.data() as Map<String, dynamic>?;
    if (d == null) return;
    _appliedFactsSignature = _factsSignature(d);
    setState(() => _applyFactsFromMap(d));
  }

  List<Widget> _buildPostMatchFactsSection() {
    if (widget.doc == null) {
      return [
        Text(
          'Après enregistrement : faits de jeu et stats se rempliront '
          'automatiquement depuis Live et Statistiques match.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
        ),
      ];
    }

    return [
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('live')
            .doc('current')
            .snapshots(),
        builder: (context, liveSnap) {
          final live = liveSnap.data?.data();
          final isLiveHere = liveSnap.hasData &&
              liveSnap.data!.exists &&
              (live?['matchId'] ?? '').toString().trim() == widget.doc!.id;
          final autoView =
              isLiveHere || (_status == 'finished' && !_factsCorrectionMode);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAutoFillBanner(isLiveHere),
              if (autoView) ...[
                _buildFactsReadOnlySummary(),
                const SizedBox(height: 12),
                _buildStatsChiffreesLink(autoMode: true),
                if (!isLiveHere && _status == 'finished') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _factsCorrectionMode = true),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(
                      'Corriger buteurs, cartons, score…',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(color: adminGold.withAlpha(120)),
                    ),
                  ),
                ],
              ] else ...[
                if (_factsCorrectionMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Correction manuelle — puis ENREGISTRER',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: adminGold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _exitFactsCorrection,
                          child: Text(
                            'ANNULER',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: adminGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._buildFactsManualEditors(),
                const SizedBox(height: 12),
                _buildStatsChiffreesLink(autoMode: false),
              ],
            ],
          );
        },
      ),
    ];
  }

  Widget _buildAutoFillBanner(bool isLiveHere) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLiveHere
            ? adminRed.withAlpha(18)
            : adminGreenAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLiveHere
              ? adminRed.withAlpha(90)
              : adminGreenAccent.withAlpha(90),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLiveHere ? Icons.sync_rounded : Icons.check_circle_outline_rounded,
            size: 20,
            color: isLiveHere ? adminRed : adminGreenAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLiveHere
                  ? 'Match en direct — ne remplis rien ici. '
                      'Tout part de l’onglet Live (buts, cartons) et '
                      'Statistiques match (chiffres). Cette fiche se met à jour toute seule.'
                  : 'Rempli automatiquement après le live. '
                      'Utilise les boutons ci-dessous seulement pour corriger une erreur.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: adminTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactsReadOnlySummary() {
    final score = '${_score1.text.trim()} - ${_score2.text.trim()}';
    final goalLines = _goals
        .map((g) {
          final p = g['player']!.text.trim();
          final m = g['minute']!.text.trim();
          return p.isEmpty ? null : '$p $m′';
        })
        .whereType<String>()
        .toList();
    final subLines = _subs.length;
    final cards = _cardTotalsLabel();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAITS DE JEU (auto)',
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Score : $score',
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AdminModuleColors.apresMatch,
            ),
          ),
          if (goalLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Buteurs : ${goalLines.join(' · ')}',
              style: GoogleFonts.inter(fontSize: 11, color: adminTextPrimary),
            ),
          ],
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Cartons : $cards',
              style: GoogleFonts.inter(fontSize: 11, color: adminTextPrimary),
            ),
          ],
          if (subLines > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$subLines remplacement(s)',
              style: GoogleFonts.inter(fontSize: 11, color: adminTextPrimary),
            ),
          ],
          if (_motmPlayer.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'HDM : ${_motmPlayer.text.trim()}',
              style: GoogleFonts.inter(fontSize: 11, color: adminTextPrimary),
            ),
          ],
          if (goalLines.isEmpty && cards.isEmpty && subLines == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Aucun fait pour l’instant — saisis dans Live pendant le match.',
                style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFactsManualEditors() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Column(
          children: [
            _VisRow(
              label: 'Homme du match visible sur la carte',
              value: _showMotmOnCard,
              onChanged: (v) => setState(() => _showMotmOnCard = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.emoji_events_rounded, size: 15, color: adminGold),
              const SizedBox(width: 8),
              Text(
                'HOMME DU MATCH',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: adminGold,
                  letterSpacing: 2,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            AdminField(ctrl: _motmPlayer, label: 'Nom du joueur'),
            const SizedBox(height: 8),
            AdminField(ctrl: _motmPartner, label: 'Partenaire (optionnel)'),
            const SizedBox(height: 8),
            AdminField(ctrl: _motmLogo, label: 'Logo partenaire (URL)'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CARTONS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminGold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            _buildPlayerCardSection(
              title: 'JAUNES',
              accent: const Color(0xFFE8C82A),
              list: _yellowCards,
              onAdd: () => setState(() {
                _factsTouchedByUser = true;
                _yellowCards.add({
                  'player': TextEditingController(),
                  'minute': TextEditingController(text: '0'),
                  'team': TextEditingController(text: _team1.text.trim()),
                });
              }),
            ),
            const SizedBox(height: 14),
            _buildPlayerCardSection(
              title: 'ROUGES',
              accent: adminRed,
              list: _redCards,
              onAdd: () => setState(() {
                _factsTouchedByUser = true;
                _redCards.add({
                  'player': TextEditingController(),
                  'minute': TextEditingController(text: '0'),
                  'team': TextEditingController(text: _team1.text.trim()),
                });
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_soccer_rounded, size: 15, color: adminGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'BUTEURS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: adminGold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _factsTouchedByUser = true;
                    _goals.add({
                      'player': TextEditingController(),
                      'minute': TextEditingController(text: '0'),
                      'team': TextEditingController(text: _team1.text.trim()),
                    });
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: adminGold.withAlpha(20),
                      border: Border.all(color: adminGold.withAlpha(80)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 13, color: adminGold),
                        const SizedBox(width: 4),
                        Text(
                          'AJOUTER',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: adminGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_goals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Aucun buteur',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
              )
            else
              ..._goals.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AdminField(ctrl: e.value['player']!, label: 'Joueur'),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 50,
                        child: AdminField(ctrl: e.value['minute']!, label: 'Min'),
                      ),
                      const SizedBox(width: 6),
                      _TeamToggle(
                        current: e.value['team']!.text,
                        team1: _team1.text.trim(),
                        team2: _team2.text.trim(),
                        onChanged: (v) =>
                            setState(() => e.value['team']!.text = v),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          _factsTouchedByUser = true;
                          e.value['player']!.dispose();
                          e.value['minute']!.dispose();
                          e.value['team']!.dispose();
                          _goals.removeAt(e.key);
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: adminGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF4A90D9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'REMPLACEMENTS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A90D9),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _factsTouchedByUser = true;
                    _subs.add({
                      'playerOut': TextEditingController(),
                      'playerIn': TextEditingController(),
                      'minute': TextEditingController(text: '0'),
                      'team': TextEditingController(text: _team1.text.trim()),
                    });
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9).withAlpha(20),
                      border: Border.all(color: const Color(0xFF4A90D9).withAlpha(80)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 13, color: Color(0xFF4A90D9)),
                        const SizedBox(width: 4),
                        Text(
                          'AJOUTER',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A90D9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_subs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Aucun remplacement',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
              )
            else
              ..._subs.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AdminField(ctrl: e.value['playerOut']!, label: 'Sortant'),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: AdminField(ctrl: e.value['playerIn']!, label: 'Entrant'),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 50,
                        child: AdminField(ctrl: e.value['minute']!, label: 'Min'),
                      ),
                      const SizedBox(width: 6),
                      _TeamToggle(
                        current: e.value['team']!.text,
                        team1: _team1.text.trim(),
                        team2: _team2.text.trim(),
                        onChanged: (v) =>
                            setState(() => e.value['team']!.text = v),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          _factsTouchedByUser = true;
                          e.value['playerOut']!.dispose();
                          e.value['playerIn']!.dispose();
                          e.value['minute']!.dispose();
                          e.value['team']!.dispose();
                          _subs.removeAt(e.key);
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: adminGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// Aide visuelle : faits de jeu ≠ stats chiffrées.
  Widget _buildMatchDataTypesHelp() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DEUX TYPES DE DONNÉES',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AdminModuleColors.apresMatch,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _dataTypeHelpCell(
                    icon: Icons.sports_soccer_rounded,
                    color: AdminModuleColors.preparation,
                    title: 'Faits de jeu',
                    where: 'Ici + onglet Live',
                    examples: 'Score, buteurs, cartons, remplacements',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dataTypeHelpCell(
                    icon: Icons.bar_chart_rounded,
                    color: AdminModuleColors.apresMatch,
                    title: 'Stats chiffrées',
                    where: 'Onglet Statistiques match',
                    examples: 'Possession, tirs, passes, arrêts…',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataTypeHelpCell({
    required IconData icon,
    required Color color,
    required String title,
    required String where,
    required String examples,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            where,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            examples,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: adminGrey,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Stats chiffrées : workbench uniquement (rempli depuis Statistiques match).
  Widget _buildStatsChiffreesLink({bool autoMode = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminGold.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATS CHIFFRÉES (auto)',
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            autoMode
                ? 'Possession, tirs, passes… : saisis dans Statistiques match '
                    'pendant le match — cette fiche les reprend toute seule.'
                : 'Correction des chiffres détaillés dans le workbench.',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.doc == null
                  ? null
                  : () {
                      final d = widget.doc!.data() as Map<String, dynamic>?;
                      AdminNavigation.openStatsWorkbench(
                        context,
                        matchId: widget.doc!.id,
                        team1:
                            d?['team1']?.toString() ?? _team1.text.trim(),
                        team2:
                            d?['team2']?.toString() ?? _team2.text.trim(),
                      );
                    },
              icon: const Icon(Icons.bar_chart_rounded, size: 18, color: adminGold),
              label: Text(
                widget.doc == null
                    ? 'Enregistrez le match d’abord'
                    : autoMode
                        ? 'Corriger les stats chiffrées (si besoin)'
                        : 'Ouvrir Statistiques match',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: adminTextPrimary,
                side: BorderSide(color: adminGold.withAlpha(120)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  final String title;
  final String eyebrow;
  final IconData icon;
  final List<Widget> children;
  final Color accent;

  const _EditorSection({
    required this.title,
    required this.icon,
    required this.children,
    this.eyebrow = 'Fiche',
    this.accent = AdminModuleColors.preparation,
  });

  @override
  Widget build(BuildContext context) {
    // Langage hubs : barre d’accent + titres, pas de carte crème empilée.
    // [icon] conservé pour cohérence d’appel / accessibilité future.
    assert(icon != Icons.broken_image_outlined);
    return AdminModuleSection(
      eyebrow: eyebrow,
      title: title,
      accent: accent,
      wrapInCard: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Compteur +/- pour stats rapides (passes, etc.).
class _QuickStatStepper extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuickStatStepper({
    required this.label,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminGrey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBtn(icon: Icons.remove_rounded, onTap: onMinus),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  controller.text.trim().isEmpty ? '0' : controller.text.trim(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AdminModuleColors.apresMatch,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StepBtn(icon: Icons.add_rounded, onTap: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminModuleColors.apresMatch.withAlpha(22),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: AdminModuleColors.apresMatch, size: 22),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    const ac = AdminModuleColors.preparation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.withAlpha(14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ac.withAlpha(70)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          height: 1.4,
          color: adminTextPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Team toggle ───────────────────────────────────────────────────────────────
class _TeamToggle extends StatelessWidget {
  final String current, team1, team2;
  final ValueChanged<String> onChanged;
  const _TeamToggle({
    required this.current,
    required this.team1,
    required this.team2,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t1 = team1.split(' ').first.toUpperCase();
    final t2 = team2.split(' ').first.toUpperCase();
    final isTeam1 = current.trim().toUpperCase() == team1.trim().toUpperCase() ||
        current.trim().isEmpty;
    return GestureDetector(
      onTap: () => onChanged(isTeam1 ? team2 : team1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: adminBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: adminBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t1, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: isTeam1 ? AdminModuleColors.preparation : adminGrey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('/', style: GoogleFonts.inter(fontSize: 10, color: adminBorder)),
          ),
          Text(t2, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: !isTeam1 ? AdminModuleColors.preparation : adminGrey)),
        ]),
      ),
    );
  }
}

// ── Vis row ───────────────────────────────────────────────────────────────────
class _VisRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _VisRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: adminGrey))),
      Switch(
        value: value, onChanged: onChanged,
        activeThumbColor: AdminModuleColors.preparation,
        inactiveThumbColor: adminGrey,
        inactiveTrackColor: adminBorder,
      ),
    ],
  );
}

// ── Select helpers (showMenu — fond explicite ; DropdownButton en overlay M3
//    pouvait rester sombre malgré dropdownColor sur certains appareils). ───────
RelativeRect _adminSelectMenuPosition(BuildContext context) {
  final RenderBox button = context.findRenderObject()! as RenderBox;
  final RenderBox overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = button.localToGlobal(
    button.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  return RelativeRect.fromRect(
    Rect.fromPoints(topLeft, bottomRight),
    Offset.zero & overlay.size,
  );
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  Future<void> _open(BuildContext context) async {
    final pos = _adminSelectMenuPosition(context);
    final box = context.findRenderObject()! as RenderBox;
    final chosen = await showMenu<String>(
      context: context,
      position: pos,
      color: adminCard,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: adminBorder),
      ),
      constraints: BoxConstraints(minWidth: box.size.width),
      items: [
        for (final c in items)
          PopupMenuItem<String>(
            value: c,
            child: Text(
              c,
              style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
            ),
          ),
      ],
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(fontSize: 13, color: adminTextPrimary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: style, overflow: TextOverflow.ellipsis)),
              Icon(Icons.arrow_drop_down_rounded, color: adminTextPrimary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avertit si ce match est le live en cours.
class _LiveEditHint extends StatelessWidget {
  final String matchId;
  const _LiveEditHint({required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final live = snap.data!.data() as Map<String, dynamic>?;
        final liveMid = (live?['matchId'] as String? ?? '').trim();
        if (liveMid != matchId.trim()) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: adminRed.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminRed.withAlpha(90)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sensors_rounded, size: 18, color: adminRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ce match est EN DIRECT. Score et buteurs : préfère l’onglet Live '
                  '(ou enregistre ici — sync avec le hub live). '
                  'Chiffres détaillés : Statistiques match.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: adminTextPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DropdownEnum extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _DropdownEnum({required this.value, required this.items, required this.onChanged});

  Future<void> _open(BuildContext context) async {
    final pos = _adminSelectMenuPosition(context);
    final box = context.findRenderObject()! as RenderBox;
    final chosen = await showMenu<String>(
      context: context,
      position: pos,
      color: adminCard,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: adminBorder),
      ),
      constraints: BoxConstraints(minWidth: box.size.width),
      items: [
        for (final d in items)
          PopupMenuItem<String>(
            value: d.value,
            enabled: d.enabled,
            onTap: d.onTap,
            child: d.child,
          ),
      ],
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    Widget? label;
    for (final d in items) {
      if (d.value == value) {
        label = d.child;
        break;
      }
    }
    final style = GoogleFonts.inter(fontSize: 13, color: adminTextPrimary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: style,
                  child: label ?? Text(value, style: style, overflow: TextOverflow.ellipsis),
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, color: adminTextPrimary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
