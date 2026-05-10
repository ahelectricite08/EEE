import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';

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
  late final TextEditingController _rank1, _rank2, _form1, _form2;
  late final TextEditingController _pos1, _pos2, _tirs1, _tirs2;
  late final TextEditingController _tirsCadres1, _tirsCadres2;
  late final TextEditingController _xg1, _xg2, _passes1, _passes2;
  late final TextEditingController _corners1, _corners2;
  late final TextEditingController _horsJeu1, _horsJeu2, _fautes1, _fautes2;
  late final TextEditingController _arretsGardien1, _arretsGardien2;
  late final TextEditingController _motmPlayer, _motmPartner, _motmLogo;
  late final TextEditingController _edYellowHome, _edYellowAway;
  late final TextEditingController _edRedHome, _edRedAway;
  final List<_CustStat> _extraStats = [];
  final List<Map<String, TextEditingController>> _goals = [];
  bool _statsExpanded = true;
  bool _importingLive = false;
  bool _showStatsOnCard = true;
  bool _showMotmOnCard = true;
  final Set<String> _activeStats = {
    'possession', 'tirs', 'tirsCadres', 'xg', 'passes',
    'corners', 'horsJeu', 'fautes', 'arretsGardien',
  };
  late String _competition;
  late String _status;
  late DateTime _date;
  bool _saving = false;
  /// Match « À venir » : section stats / cartons repliable.
  bool _prepPostMatchExpanded = false;
  /// Publier scores & stats dans l’app malgré le statut « À venir ».
  bool _earlyPublish = false;

  static const _competitions = [
    'National 3',
    'Régional 1',
    'Régional 2',
    'Régional 3',
    'Coupe de France',
    'Coupe Grand Est',
    'Coupe des Ardennes',
    'Coupe de la Ligue',
    'Match Amical',
  ];

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
    _showStatsOnCard = (d?['showStats'] as bool?) ?? true;
    _showMotmOnCard = (d?['showMotm'] as bool?) ?? true;
    _motmPlayer = TextEditingController(text: d?['manOfTheMatchName'] ?? '');
    _motmPartner = TextEditingController(text: d?['manOfTheMatchPartnerName'] ?? '');
    _motmLogo = TextEditingController(text: d?['manOfTheMatchPartnerLogo'] ?? '');
    _edYellowHome = TextEditingController(text: '${d?['yellowHome'] ?? 0}');
    _edYellowAway = TextEditingController(text: '${d?['yellowAway'] ?? 0}');
    _edRedHome = TextEditingController(text: '${d?['redHome'] ?? 0}');
    _edRedAway = TextEditingController(text: '${d?['redAway'] ?? 0}');
    final events = d?['events'];
    if (events is List) {
      for (final e in events) {
        if (e is Map && e['type'] == 'goal') {
          _goals.add({
            'player': TextEditingController(text: e['player']?.toString() ?? ''),
            'minute': TextEditingController(text: e['minute']?.toString() ?? ''),
            'team': TextEditingController(text: e['team']?.toString() ?? ''),
          });
        }
      }
    }
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
    _status = d?['status'] ?? 'upcoming';
    _earlyPublish = d?['earlyPublish'] == true;
    _prepPostMatchExpanded = _status != 'upcoming';
    final ts = d?['date'];
    _date = ts is Timestamp
        ? ts.toDate()
        : DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    for (final ctrl in [
      _team1, _team2, _logo1, _logo2, _score1, _score2, _replay, _stadiumImage,
      _rank1, _rank2, _form1, _form2,
      _pos1, _pos2, _tirs1, _tirs2, _tirsCadres1, _tirsCadres2,
      _xg1, _xg2, _passes1, _passes2, _corners1, _corners2,
      _horsJeu1, _horsJeu2, _fautes1, _fautes2, _arretsGardien1, _arretsGardien2,
      _motmPlayer, _motmPartner, _motmLogo,
      _edYellowHome, _edYellowAway, _edRedHome, _edRedAway,
    ]) ctrl.dispose();
    for (final cs in _extraStats) cs.dispose();
    for (final g in _goals) {
      g['player']!.dispose();
      g['minute']!.dispose();
      g['team']!.dispose();
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
      final s = (liveData['stats'] as Map<String, dynamic>?) ?? {};
      setState(() {
        if (s.isNotEmpty) {
          _pos1.text = (s['possession1'] ?? 50).toString();
          _pos2.text = (s['possession2'] ?? 50).toString();
          _tirs1.text = (s['tirs1'] ?? 0).toString();
          _tirs2.text = (s['tirs2'] ?? 0).toString();
          _tirsCadres1.text = (s['tirsCadres1'] ?? 0).toString();
          _tirsCadres2.text = (s['tirsCadres2'] ?? 0).toString();
          _xg1.text = (s['xg1'] ?? 0).toString();
          _xg2.text = (s['xg2'] ?? 0).toString();
          _passes1.text = (s['passes1'] ?? 0).toString();
          _passes2.text = (s['passes2'] ?? 0).toString();
          _corners1.text = (s['corners1'] ?? 0).toString();
          _corners2.text = (s['corners2'] ?? 0).toString();
          _horsJeu1.text = (s['horsJeu1'] ?? 0).toString();
          _horsJeu2.text = (s['horsJeu2'] ?? 0).toString();
          _fautes1.text = (s['fautes1'] ?? 0).toString();
          _fautes2.text = (s['fautes2'] ?? 0).toString();
          _arretsGardien1.text = (s['arretsGardien1'] ?? 0).toString();
          _arretsGardien2.text = (s['arretsGardien2'] ?? 0).toString();
        }
        final motmName = (liveData['manOfTheMatchName'] as String? ?? '').trim();
        if (motmName.isNotEmpty) {
          _motmPlayer.text = motmName;
          _motmPartner.text = liveData['manOfTheMatchPartnerName'] as String? ?? '';
          _motmLogo.text = liveData['manOfTheMatchPartnerLogo'] as String? ?? '';
        }
        _edYellowHome.text = '${liveData['yellowHome'] ?? 0}';
        _edYellowAway.text = '${liveData['yellowAway'] ?? 0}';
        _edRedHome.text = '${liveData['redHome'] ?? 0}';
        _edRedAway.text = '${liveData['redAway'] ?? 0}';
        final events = liveData['events'];
        if (events is List) {
          for (final g in _goals) {
            g['player']!.dispose();
            g['minute']!.dispose();
            g['team']!.dispose();
          }
          _goals.clear();
          for (final e in events) {
            if (e is Map && e['type'] == 'goal') {
              _goals.add({
                'player': TextEditingController(text: e['player']?.toString() ?? ''),
                'minute': TextEditingController(text: e['minute']?.toString() ?? ''),
                'team': TextEditingController(text: e['team']?.toString() ?? ''),
              });
            }
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live importé ✓ (stats, MOTM, cartons, buteurs)'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importingLive = false);
    }
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

  Future<void> _save() async {
    if (_team1.text.trim().isEmpty || _team2.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'team1': _team1.text.trim(),
        'team2': _team2.text.trim(),
        'competition': _competition,
        'status': _status,
        'date': Timestamp.fromDate(_date),
      };
      if (_logo1.text.trim().isNotEmpty) payload['logo1'] = _logo1.text.trim();
      if (_logo2.text.trim().isNotEmpty) payload['logo2'] = _logo2.text.trim();
      payload['stadiumImageUrl'] = _stadiumImage.text.trim().isEmpty
          ? null : _stadiumImage.text.trim();
      final s1 = int.tryParse(_score1.text.trim());
      final s2 = int.tryParse(_score2.text.trim());
      if (s1 != null) payload['score1'] = s1;
      if (s2 != null) payload['score2'] = s2;
      if (_replay.text.trim().isNotEmpty) payload['replayVideoId'] = _replay.text.trim();
      if (_rank1.text.trim().isNotEmpty) payload['rank1'] = int.tryParse(_rank1.text.trim()) ?? _rank1.text.trim();
      if (_rank2.text.trim().isNotEmpty) payload['rank2'] = int.tryParse(_rank2.text.trim()) ?? _rank2.text.trim();
      if (_form1.text.trim().isNotEmpty) payload['form1'] = _form1.text.trim().toUpperCase();
      if (_form2.text.trim().isNotEmpty) payload['form2'] = _form2.text.trim().toUpperCase();
      final customList = _extraStats
          .where((cs) => cs.label.text.trim().isNotEmpty)
          .map((cs) => {
            'label': cs.label.text.trim(),
            'value1': cs.v1.text.trim(),
            'value2': cs.v2.text.trim(),
          }).toList();
      bool _a(String k) => _activeStats.contains(k);
      final statsMap = <String, dynamic>{};
      if (_a('possession')) {
        statsMap['possession1'] = int.tryParse(_pos1.text.trim()) ?? 50;
        statsMap['possession2'] = int.tryParse(_pos2.text.trim()) ?? 50;
      }
      if (_a('tirs')) {
        statsMap['tirs1'] = int.tryParse(_tirs1.text.trim()) ?? 0;
        statsMap['tirs2'] = int.tryParse(_tirs2.text.trim()) ?? 0;
      }
      if (_a('tirsCadres')) {
        statsMap['tirsCadres1'] = int.tryParse(_tirsCadres1.text.trim()) ?? 0;
        statsMap['tirsCadres2'] = int.tryParse(_tirsCadres2.text.trim()) ?? 0;
      }
      if (_a('xg')) {
        statsMap['xg1'] = double.tryParse(_xg1.text.trim()) ?? 0.0;
        statsMap['xg2'] = double.tryParse(_xg2.text.trim()) ?? 0.0;
      }
      if (_a('passes')) {
        statsMap['passes1'] = int.tryParse(_passes1.text.trim()) ?? 0;
        statsMap['passes2'] = int.tryParse(_passes2.text.trim()) ?? 0;
      }
      if (_a('corners')) {
        statsMap['corners1'] = int.tryParse(_corners1.text.trim()) ?? 0;
        statsMap['corners2'] = int.tryParse(_corners2.text.trim()) ?? 0;
      }
      if (_a('horsJeu')) {
        statsMap['horsJeu1'] = int.tryParse(_horsJeu1.text.trim()) ?? 0;
        statsMap['horsJeu2'] = int.tryParse(_horsJeu2.text.trim()) ?? 0;
      }
      if (_a('fautes')) {
        statsMap['fautes1'] = int.tryParse(_fautes1.text.trim()) ?? 0;
        statsMap['fautes2'] = int.tryParse(_fautes2.text.trim()) ?? 0;
      }
      if (_a('arretsGardien')) {
        statsMap['arretsGardien1'] = int.tryParse(_arretsGardien1.text.trim()) ?? 0;
        statsMap['arretsGardien2'] = int.tryParse(_arretsGardien2.text.trim()) ?? 0;
      }
      if (customList.isNotEmpty) statsMap['customStats'] = customList;
      payload['stats'] = statsMap;
      payload['showStats'] = _showStatsOnCard;
      payload['showMotm'] = _showMotmOnCard;
      payload['earlyPublish'] =
          _status == 'upcoming' ? _earlyPublish : false;
      payload['manOfTheMatchName'] = _motmPlayer.text.trim();
      payload['manOfTheMatchPartnerName'] = _motmPartner.text.trim();
      payload['manOfTheMatchPartnerLogo'] = _motmLogo.text.trim();
      payload['yellowHome'] = int.tryParse(_edYellowHome.text) ?? 0;
      payload['yellowAway'] = int.tryParse(_edYellowAway.text) ?? 0;
      payload['redHome'] = int.tryParse(_edRedHome.text) ?? 0;
      payload['redAway'] = int.tryParse(_edRedAway.text) ?? 0;
      payload['events'] = _goals
          .where((g) => g['player']!.text.trim().isNotEmpty)
          .map((g) => {
            'type': 'goal',
            'player': g['player']!.text.trim(),
            'minute': int.tryParse(g['minute']!.text.trim()) ?? 0,
            'team': g['team']!.text.trim(),
          }).toList();
      if (widget.doc == null) {
        payload['manual'] = true;
        await FirebaseFirestore.instance.collection('matches').add(payload);
      } else {
        final existing = widget.doc!.data() as Map<String, dynamic>?;
        if (existing?['manual'] == true) {
          payload['manual'] = true;
        }
        await widget.doc!.reference.update(payload);
      }
      if (mounted) Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        backgroundColor: adminBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: adminTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.doc == null ? 'NOUVEAU MATCH' : 'MODIFIER LE MATCH',
          style: GoogleFonts.barlowCondensed(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: adminTextPrimary, letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: adminGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text('ENREGISTRER', style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: adminBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          _Dropdown(
            value: _competitionDropdownItems().contains(_competition)
                ? _competition
                : _competitionDropdownItems().first,
            items: _competitionDropdownItems(),
            onChanged: (v) => setState(() => _competition = v!),
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
                    activeThumbColor: adminGold,
                    inactiveThumbColor: adminGrey,
                    inactiveTrackColor: adminBorder,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: adminGold),
                  const SizedBox(width: 10),
                  Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary)),
                  const Spacer(),
                  Text('CHANGER', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: adminGold)),
                ],
              ),
            ),
          ),
          if (_status == 'finished' || _status == 'live') ...[
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
                    Icon(Icons.add_chart_rounded, size: 22, color: adminGold.withAlpha(200)),
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
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scores, stats, cartons, buteurs, homme du match — optionnel tant qu’à venir.',
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
          // ── Statistiques ──────────────────────────────────────────────────
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
                GestureDetector(
                  onTap: () => setState(() => _statsExpanded = !_statsExpanded),
                  child: Row(
                    children: [
                      Text('STATISTIQUES MATCH', style: GoogleFonts.barlowCondensed(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: adminGold, letterSpacing: 2)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _importingLive ? null : _importFromLive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: adminGold.withAlpha(20),
                            border: Border.all(color: adminGold.withAlpha(80)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _importingLive
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: adminGold))
                              : Text('⚡ LIVE', style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: adminGold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(_statsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: adminGrey, size: 18),
                    ],
                  ),
                ),
                if (_statsExpanded) ...[
                  const SizedBox(height: 12),
                  _sRow('possession', _pos1, _pos2, 'Possession dom %', 'Possession ext %'),
                  _sRow('tirs', _tirs1, _tirs2, 'Tirs dom', 'Tirs ext'),
                  _sRow('tirsCadres', _tirsCadres1, _tirsCadres2, 'Tirs cadrés dom', 'Tirs cadrés ext'),
                  _sRow('xg', _xg1, _xg2, 'xG dom', 'xG ext'),
                  _sRow('passes', _passes1, _passes2, 'Passes dom', 'Passes ext'),
                  _sRow('corners', _corners1, _corners2, 'Corners dom', 'Corners ext'),
                  _sRow('horsJeu', _horsJeu1, _horsJeu2, 'Hors-jeu dom', 'Hors-jeu ext'),
                  _sRow('fautes', _fautes1, _fautes2, 'Fautes dom', 'Fautes ext'),
                  _sRow('arretsGardien', _arretsGardien1, _arretsGardien2, 'Arrêts dom', 'Arrêts ext'),
                  if (_extraStats.isNotEmpty) ...[
                    const Divider(color: adminBorder, height: 20),
                    ..._extraStats.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: AdminField(ctrl: e.value.label, label: 'Nom de la stat')),
                          const SizedBox(width: 6),
                          Expanded(child: AdminField(ctrl: e.value.v1, label: 'Dom')),
                          const SizedBox(width: 6),
                          Expanded(child: AdminField(ctrl: e.value.v2, label: 'Ext')),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() { _extraStats[e.key].dispose(); _extraStats.removeAt(e.key); }),
                            child: const Icon(Icons.close_rounded, size: 18, color: adminGrey),
                          ),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _extraStats.add(_CustStat())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: adminBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: adminBorder),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add_rounded, size: 14, color: adminGold),
                            const SizedBox(width: 4),
                            Text('AJOUTER STAT', style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700, color: adminGold)),
                          ]),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _deleteAllStats,
                        child: Text('Tout effacer', style: GoogleFonts.inter(
                          fontSize: 10, color: adminGrey,
                          decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Visibilité ────────────────────────────────────────────────────
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
                  label: 'Statistiques visibles sur la carte',
                  value: _showStatsOnCard,
                  onChanged: (v) => setState(() => _showStatsOnCard = v),
                ),
                const Divider(height: 1, color: adminBorder),
                _VisRow(
                  label: 'Homme du match visible sur la carte',
                  value: _showMotmOnCard,
                  onChanged: (v) => setState(() => _showMotmOnCard = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Homme du match ────────────────────────────────────────────────
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
                  Text('HOMME DU MATCH', style: GoogleFonts.barlowCondensed(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: adminGold, letterSpacing: 2)),
                ]),
                const SizedBox(height: 12),
                AdminField(ctrl: _motmPlayer, label: 'Nom du joueur'),
                const SizedBox(height: 8),
                AdminField(ctrl: _motmPartner, label: 'Partenaire (optionnel)'),
                const SizedBox(height: 8),
                AdminField(ctrl: _motmLogo, label: 'Logo partenaire (URL)'),
                if (_motmPlayer.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() { _motmPlayer.clear(); _motmPartner.clear(); _motmLogo.clear(); }),
                    child: Text('Effacer', style: GoogleFonts.inter(
                      fontSize: 10, color: adminGrey,
                      decoration: TextDecoration.underline)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Cartons ───────────────────────────────────────────────────────
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
                  const Icon(Icons.style_rounded, size: 15, color: adminGold),
                  const SizedBox(width: 8),
                  Text('CARTONS', style: GoogleFonts.barlowCondensed(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: adminGold, letterSpacing: 2)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  SizedBox(width: 110, child: Row(children: [
                    Container(width: 10, height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8C82A),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                    Text('JAUNES', style: GoogleFonts.inter(fontSize: 11, color: adminGrey)),
                  ])),
                  Expanded(child: AdminField(ctrl: _edYellowHome, label: 'Dom')),
                  const SizedBox(width: 8),
                  Expanded(child: AdminField(ctrl: _edYellowAway, label: 'Ext')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(width: 110, child: Row(children: [
                    Container(width: 10, height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: adminRed,
                        borderRadius: BorderRadius.circular(2)),
                    ),
                    Text('ROUGES', style: GoogleFonts.inter(fontSize: 11, color: adminGrey)),
                  ])),
                  Expanded(child: AdminField(ctrl: _edRedHome, label: 'Dom')),
                  const SizedBox(width: 8),
                  Expanded(child: AdminField(ctrl: _edRedAway, label: 'Ext')),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Buteurs ───────────────────────────────────────────────────────
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
                  const Icon(Icons.sports_soccer_rounded, size: 15, color: adminGold),
                  const SizedBox(width: 8),
                  Expanded(child: Text('BUTEURS', style: GoogleFonts.barlowCondensed(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: adminGold, letterSpacing: 2))),
                  GestureDetector(
                    onTap: () => setState(() => _goals.add({
                      'player': TextEditingController(),
                      'minute': TextEditingController(text: '0'),
                      'team': TextEditingController(text: _team1.text.trim()),
                    })),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: adminGold.withAlpha(20),
                        border: Border.all(color: adminGold.withAlpha(80)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_rounded, size: 13, color: adminGold),
                        const SizedBox(width: 4),
                        Text('AJOUTER', style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: adminGold)),
                      ]),
                    ),
                  ),
                ]),
                if (_goals.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Aucun buteur', style: GoogleFonts.inter(fontSize: 12, color: adminGrey)),
                ] else ...[
                  const SizedBox(height: 10),
                  ..._goals.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(flex: 3, child: AdminField(ctrl: e.value['player']!, label: 'Joueur')),
                      const SizedBox(width: 6),
                      SizedBox(width: 50, child: AdminField(ctrl: e.value['minute']!, label: 'Min')),
                      const SizedBox(width: 6),
                      _TeamToggle(
                        current: e.value['team']!.text,
                        team1: _team1.text.trim(),
                        team2: _team2.text.trim(),
                        onChanged: (v) => setState(() => e.value['team']!.text = v),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          e.value['player']!.dispose();
                          e.value['minute']!.dispose();
                          e.value['team']!.dispose();
                          _goals.removeAt(e.key);
                        }),
                        child: const Icon(Icons.close_rounded, size: 18, color: adminGrey),
                      ),
                    ]),
                  )),
                ],
              ],
            ),
          ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminGold.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminGold.withAlpha(90)),
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
            color: isTeam1 ? adminGold : adminGrey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('/', style: GoogleFonts.inter(fontSize: 10, color: adminBorder)),
          ),
          Text(t2, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: !isTeam1 ? adminGold : adminGrey)),
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
        activeThumbColor: adminGold,
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
