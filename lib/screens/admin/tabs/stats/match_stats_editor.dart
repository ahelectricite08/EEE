import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/match_stats_sheet_service.dart';
import '../../../../services/seed_service.dart';
import '../../admin_palette.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE STATS PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class MatchStatsEditor extends StatefulWidget {
  final Map<String, dynamic> data;
  /// Si renseigné, persiste dans `match_stats/{matchId}` (module Statistiques).
  final String? matchId;
  /// Match officiel (stats publiées) — certaines actions rouvrent la saisie.
  final bool isPublished;
  /// Legacy Direct : écriture `live/current.stats` (désactivé par défaut).
  final bool persistToLive;

  const MatchStatsEditor({
    super.key,
    required this.data,
    this.matchId,
    this.isPublished = false,
    this.persistToLive = false,
  });

  @override
  State<MatchStatsEditor> createState() => _MatchStatsEditorState();
}

class _MatchStatsEditorState extends State<MatchStatsEditor> {
  bool _showStats = false;
  Map<String, dynamic>? _undo;
  final FocusNode _shortcutFocusNode = FocusNode();
  late Map<String, LogicalKeyboardKey> _keyBindings = _defaultBindings();
  String? _remappingAction;
  Timer? _possessionTicker;
  Timer? _saveDebounce;
  bool _statsDirty = false;
  static const Duration _statsSaveDebounce = Duration(seconds: 2);
  static const int _possessionFirestoreIntervalMs = 30000;
  int _possessionMillis1 = 0, _possessionMillis2 = 0;
  int? _activePossessionTeam;
  int _pendingPossessionSaveMs = 0;
  bool _possessionManualMode = false;

  int _shots1 = 0, _shots2 = 0;
  int _onTarget1 = 0, _onTarget2 = 0;
  int _blocked1 = 0, _blocked2 = 0;
  int _poteau1 = 0, _poteau2 = 0;
  double _xg1 = 0, _xg2 = 0;
  int _passAcc1 = 0, _passAcc2 = 0;
  int _passInacc1 = 0, _passInacc2 = 0;
  int _keyPass1 = 0, _keyPass2 = 0;
  int _crossAcc1 = 0, _crossAcc2 = 0;
  int _crossInacc1 = 0, _crossInacc2 = 0;
  int _tackleWon1 = 0, _tackleWon2 = 0;
  int _tackleLost1 = 0, _tackleLost2 = 0;
  int _duelWon1 = 0, _duelWon2 = 0;
  int _aerialWon1 = 0, _aerialWon2 = 0;
  int _corners1 = 0, _corners2 = 0;
  int _offsides1 = 0, _offsides2 = 0;
  int _fouls1 = 0, _fouls2 = 0;
  int _saves1 = 0, _saves2 = 0;

  @override
  void initState() {
    super.initState();
    _loadFromData(widget.data['stats']);
    _loadBindings();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _possessionTicker?.cancel();
    if (_statsDirty) {
      _save();
    }
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _statsDirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_statsSaveDebounce, () {
      if (!mounted) return;
      _flushSave();
    });
  }

  Future<void> _flushSave() async {
    if (!_statsDirty) return;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _statsDirty = false;
    await _save();
  }

  @override
  void didUpdateWidget(MatchStatsEditor old) {
    super.didUpdateWidget(old);
    // Ne pas écraser une saisie / chrono en cours quand Firestore renvoie un snapshot.
    if (_activePossessionTeam != null || _statsDirty || _possessionManualMode) {
      return;
    }
    final oldJson = jsonEncode(old.data['stats'] ?? {});
    final newJson = jsonEncode(widget.data['stats'] ?? {});
    if (oldJson != newJson) {
      _loadFromData(widget.data['stats']);
    }
  }

  void _loadFromData(dynamic raw) {
    if (raw is! Map<String, dynamic>) return;
    final s = raw;
    setState(() {
      _shots1 = _gi(s['tirs1'] ?? s['shots1']);
      _shots2 = _gi(s['tirs2'] ?? s['shots2']);
      _onTarget1 = _gi(s['tirsCadres1'] ?? s['onTarget1']);
      _onTarget2 = _gi(s['tirsCadres2'] ?? s['onTarget2']);
      _blocked1 = _gi(s['blocked1']);
      _blocked2 = _gi(s['blocked2']);
      _poteau1 = _gi(s['poteau1']);
      _poteau2 = _gi(s['poteau2']);
      _xg1 = (s['xg1'] is num) ? (s['xg1'] as num).toDouble() : 0;
      _xg2 = (s['xg2'] is num) ? (s['xg2'] as num).toDouble() : 0;
      _passAcc1 = _gi(s['passes1'] ?? s['passAcc1']);
      _passAcc2 = _gi(s['passes2'] ?? s['passAcc2']);
      _passInacc1 = _gi(s['passInacc1']);
      _passInacc2 = _gi(s['passInacc2']);
      _keyPass1 = _gi(s['keyPass1']);
      _keyPass2 = _gi(s['keyPass2']);
      _crossAcc1 = _gi(s['crossAcc1']);
      _crossAcc2 = _gi(s['crossAcc2']);
      _crossInacc1 = _gi(s['crossInacc1']);
      _crossInacc2 = _gi(s['crossInacc2']);
      _tackleWon1 = _gi(s['tackleWon1']);
      _tackleWon2 = _gi(s['tackleWon2']);
      _tackleLost1 = _gi(s['tackleLost1']);
      _tackleLost2 = _gi(s['tackleLost2']);
      _duelWon1 = _gi(s['duelWon1']);
      _duelWon2 = _gi(s['duelWon2']);
      _aerialWon1 = _gi(s['aerialWon1']);
      _aerialWon2 = _gi(s['aerialWon2']);
      _corners1 = _gi(s['corners1']);
      _corners2 = _gi(s['corners2']);
      _offsides1 = _gi(s['horsJeu1'] ?? s['offsides1']);
      _offsides2 = _gi(s['horsJeu2'] ?? s['offsides2']);
      _fouls1 = _gi(s['fautes1'] ?? s['fouls1']);
      _fouls2 = _gi(s['fautes2'] ?? s['fouls2']);
      _saves1 = _gi(s['arretsGardien1'] ?? s['saves1']);
      _saves2 = _gi(s['arretsGardien2'] ?? s['saves2']);
      _possessionMillis1 = _gi(s['possessionMs1'] ?? s['possessionMillis1']);
      _possessionMillis2 = _gi(s['possessionMs2'] ?? s['possessionMillis2']);
      if (_possessionMillis1 + _possessionMillis2 == 0) {
        final p1 = _gi(s['possession1']);
        final p2 = _gi(s['possession2']);
        if (p1 + p2 == 100) {
          _possessionMillis1 = p1 * 600;
          _possessionMillis2 = p2 * 600;
          _possessionManualMode = p1 > 0 || p2 > 0;
        }
      } else {
        _possessionManualMode = false;
      }
      // Ne jamais relancer le chrono automatiquement à l'ouverture.
      _activePossessionTeam = null;
    });
    _possessionTicker?.cancel();
    _possessionTicker = null;
  }

  int _gi(dynamic v) => (v is num) ? v.toInt() : 0;

  String get _t1 => (widget.data['team1'] as String? ?? 'DOM').trim();
  String get _t2 => (widget.data['team2'] as String? ?? 'EXT').trim();

  int get _poss1 {
    final total = _possessionMillis1 + _possessionMillis2;
    if (total == 0) return 50;
    return ((_possessionMillis1 / total) * 100).round().clamp(0, 100);
  }

  int get _poss2 => (100 - _poss1).clamp(0, 100);

  Map<String, dynamic> _captureSnapshot() => {
    'shots1': _shots1,
    'shots2': _shots2,
    'onTarget1': _onTarget1,
    'onTarget2': _onTarget2,
    'blocked1': _blocked1,
    'blocked2': _blocked2,
    'poteau1': _poteau1,
    'poteau2': _poteau2,
    'xg1': _xg1,
    'xg2': _xg2,
    'passAcc1': _passAcc1,
    'passAcc2': _passAcc2,
    'passInacc1': _passInacc1,
    'passInacc2': _passInacc2,
    'keyPass1': _keyPass1,
    'keyPass2': _keyPass2,
    'crossAcc1': _crossAcc1,
    'crossAcc2': _crossAcc2,
    'crossInacc1': _crossInacc1,
    'crossInacc2': _crossInacc2,
    'tackleWon1': _tackleWon1,
    'tackleWon2': _tackleWon2,
    'tackleLost1': _tackleLost1,
    'tackleLost2': _tackleLost2,
    'duelWon1': _duelWon1,
    'duelWon2': _duelWon2,
    'aerialWon1': _aerialWon1,
    'aerialWon2': _aerialWon2,
    'corners1': _corners1,
    'corners2': _corners2,
    'offsides1': _offsides1,
    'offsides2': _offsides2,
    'fouls1': _fouls1,
    'fouls2': _fouls2,
    'saves1': _saves1,
    'saves2': _saves2,
    'possessionMillis1': _possessionMillis1,
    'possessionMillis2': _possessionMillis2,
    'activePossessionTeam': _activePossessionTeam,
  };

  Map<String, dynamic> _buildStatsPayload() => {
    'tirs1': _shots1,
    'tirs2': _shots2,
    'tirsCadres1': _onTarget1,
    'tirsCadres2': _onTarget2,
    'blocked1': _blocked1,
    'blocked2': _blocked2,
    'poteau1': _poteau1,
    'poteau2': _poteau2,
    'passes1': _passAcc1,
    'passes2': _passAcc2,
    'corners1': _corners1,
    'corners2': _corners2,
    'horsJeu1': _offsides1,
    'horsJeu2': _offsides2,
    'fautes1': _fouls1,
    'fautes2': _fouls2,
    'arretsGardien1': _saves1,
    'arretsGardien2': _saves2,
    'possession1': _poss1,
    'possession2': _poss2,
    'passInacc1': _passInacc1,
    'passInacc2': _passInacc2,
    'keyPass1': _keyPass1,
    'keyPass2': _keyPass2,
    'crossAcc1': _crossAcc1,
    'crossAcc2': _crossAcc2,
    'crossInacc1': _crossInacc1,
    'crossInacc2': _crossInacc2,
    'duelWon1': _duelWon1,
    'duelWon2': _duelWon2,
    'possessionMs1': _possessionMillis1,
    'possessionMs2': _possessionMillis2,
    // Ne pas persister l'équipe active — évite reprise auto du chrono.
    'possessionActiveTeam': null,
  };

  Future<void> _save() async {
    final payload = _buildStatsPayload();
    final matchId = widget.matchId?.trim();
    if (matchId != null && matchId.isNotEmpty) {
      await MatchStatsSheetService.instance.saveDraft(
        matchId: matchId,
        stats: payload,
      );
      return;
    }
    if (widget.persistToLive) {
      await SeedService.setLiveStats(payload);
    }
  }

  void _restoreSnapshot(Map<String, dynamic> s) {
    _shots1 = _gi(s['shots1']);
    _shots2 = _gi(s['shots2']);
    _onTarget1 = _gi(s['onTarget1']);
    _onTarget2 = _gi(s['onTarget2']);
    _blocked1 = _gi(s['blocked1']);
    _blocked2 = _gi(s['blocked2']);
    _poteau1 = _gi(s['poteau1']);
    _poteau2 = _gi(s['poteau2']);
    _xg1 = (s['xg1'] is num) ? (s['xg1'] as num).toDouble() : 0;
    _xg2 = (s['xg2'] is num) ? (s['xg2'] as num).toDouble() : 0;
    _passAcc1 = _gi(s['passAcc1']);
    _passAcc2 = _gi(s['passAcc2']);
    _passInacc1 = _gi(s['passInacc1']);
    _passInacc2 = _gi(s['passInacc2']);
    _keyPass1 = _gi(s['keyPass1']);
    _keyPass2 = _gi(s['keyPass2']);
    _crossAcc1 = _gi(s['crossAcc1']);
    _crossAcc2 = _gi(s['crossAcc2']);
    _crossInacc1 = _gi(s['crossInacc1']);
    _crossInacc2 = _gi(s['crossInacc2']);
    _tackleWon1 = _gi(s['tackleWon1']);
    _tackleWon2 = _gi(s['tackleWon2']);
    _tackleLost1 = _gi(s['tackleLost1']);
    _tackleLost2 = _gi(s['tackleLost2']);
    _duelWon1 = _gi(s['duelWon1']);
    _duelWon2 = _gi(s['duelWon2']);
    _aerialWon1 = _gi(s['aerialWon1']);
    _aerialWon2 = _gi(s['aerialWon2']);
    _corners1 = _gi(s['corners1']);
    _corners2 = _gi(s['corners2']);
    _offsides1 = _gi(s['offsides1']);
    _offsides2 = _gi(s['offsides2']);
    _fouls1 = _gi(s['fouls1']);
    _fouls2 = _gi(s['fouls2']);
    _saves1 = _gi(s['saves1']);
    _saves2 = _gi(s['saves2']);

    _possessionMillis1 = _gi(s['possessionMillis1']);
    _possessionMillis2 = _gi(s['possessionMillis2']);
    _activePossessionTeam = null;
    _syncPossessionTicker();
  }

  void _shot(int team, String outcome) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        _shots1++;
        if (outcome == 'cadre') {
          _onTarget1++;
        } else if (outcome == 'blocked') {
          _blocked1++;
        } else if (outcome == 'poteau') {
          _poteau1++;
        }
      } else {
        _shots2++;
        if (outcome == 'cadre') {
          _onTarget2++;
        } else if (outcome == 'blocked') {
          _blocked2++;
        } else if (outcome == 'poteau') {
          _poteau2++;
        }
      }
    });
    _scheduleSave();
  }

  void _decShot(int team, String outcome) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        final missed = (_shots1 - _onTarget1 - _blocked1 - _poteau1).clamp(0, 999);
        if (outcome == 'cadre' && _onTarget1 > 0) {
          _onTarget1--;
          _shots1 = (_shots1 - 1).clamp(0, 999);
        } else if (outcome == 'blocked' && _blocked1 > 0) {
          _blocked1--;
          _shots1 = (_shots1 - 1).clamp(0, 999);
        } else if (outcome == 'poteau' && _poteau1 > 0) {
          _poteau1--;
          _shots1 = (_shots1 - 1).clamp(0, 999);
        } else if (outcome == 'manque' && missed > 0) {
          _shots1 = (_shots1 - 1).clamp(0, 999);
        }
      } else {
        final missed = (_shots2 - _onTarget2 - _blocked2 - _poteau2).clamp(0, 999);
        if (outcome == 'cadre' && _onTarget2 > 0) {
          _onTarget2--;
          _shots2 = (_shots2 - 1).clamp(0, 999);
        } else if (outcome == 'blocked' && _blocked2 > 0) {
          _blocked2--;
          _shots2 = (_shots2 - 1).clamp(0, 999);
        } else if (outcome == 'poteau' && _poteau2 > 0) {
          _poteau2--;
          _shots2 = (_shots2 - 1).clamp(0, 999);
        } else if (outcome == 'manque' && missed > 0) {
          _shots2 = (_shots2 - 1).clamp(0, 999);
        }
      }
    });
    _scheduleSave();
  }

  void _duel(int team) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        _duelWon1++;
      } else {
        _duelWon2++;
      }
    });
    _scheduleSave();
  }

  void _decDuel(int team) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        _duelWon1 = (_duelWon1 - 1).clamp(0, 999);
      } else {
        _duelWon2 = (_duelWon2 - 1).clamp(0, 999);
      }
    });
    _scheduleSave();
  }

  void _pass(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate)
          _passAcc1++;
        else
          _passInacc1++;
      } else {
        if (accurate)
          _passAcc2++;
        else
          _passInacc2++;
      }
    });
    _scheduleSave();
  }

  void _decPass(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate) {
          _passAcc1 = (_passAcc1 - 1).clamp(0, 999);
        } else {
          _passInacc1 = (_passInacc1 - 1).clamp(0, 999);
        }
      } else {
        if (accurate) {
          _passAcc2 = (_passAcc2 - 1).clamp(0, 999);
        } else {
          _passInacc2 = (_passInacc2 - 1).clamp(0, 999);
        }
      }
    });
    _scheduleSave();
  }

  void _cross(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate) {
          _crossAcc1++;
        } else {
          _crossInacc1++;
        }
      } else {
        if (accurate) {
          _crossAcc2++;
        } else {
          _crossInacc2++;
        }
      }
    });
    _scheduleSave();
  }

  void _decCross(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate) {
          _crossAcc1 = (_crossAcc1 - 1).clamp(0, 999);
        } else {
          _crossInacc1 = (_crossInacc1 - 1).clamp(0, 999);
        }
      } else {
        if (accurate) {
          _crossAcc2 = (_crossAcc2 - 1).clamp(0, 999);
        } else {
          _crossInacc2 = (_crossInacc2 - 1).clamp(0, 999);
        }
      }
    });
    _scheduleSave();
  }

  void _inc(int team, String stat) {
    _undo = _captureSnapshot();
    setState(() {
      switch (stat) {
        case 'corners':
          if (team == 1)
            _corners1++;
          else
            _corners2++;
          break;
        case 'offsides':
          if (team == 1)
            _offsides1++;
          else
            _offsides2++;
          break;
        case 'fouls':
          if (team == 1)
            _fouls1++;
          else
            _fouls2++;
          break;
        case 'saves':
          if (team == 1)
            _saves1++;
          else
            _saves2++;
          break;
      }
    });
    _scheduleSave();
  }

  void _dec(int team, String stat) {
    _undo = _captureSnapshot();
    setState(() {
      switch (stat) {
        case 'corners':
          if (team == 1)
            _corners1 = (_corners1 - 1).clamp(0, 999);
          else
            _corners2 = (_corners2 - 1).clamp(0, 999);
          break;
        case 'offsides':
          if (team == 1)
            _offsides1 = (_offsides1 - 1).clamp(0, 999);
          else
            _offsides2 = (_offsides2 - 1).clamp(0, 999);
          break;
        case 'fouls':
          if (team == 1)
            _fouls1 = (_fouls1 - 1).clamp(0, 999);
          else
            _fouls2 = (_fouls2 - 1).clamp(0, 999);
          break;
        case 'saves':
          if (team == 1)
            _saves1 = (_saves1 - 1).clamp(0, 999);
          else
            _saves2 = (_saves2 - 1).clamp(0, 999);
          break;
      }
    });
    _scheduleSave();
  }

  void _syncPossessionTicker() {
    if (_activePossessionTeam == null) {
      _possessionTicker?.cancel();
      _possessionTicker = null;
      return;
    }
    if (_possessionTicker != null) return;
    _possessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _activePossessionTeam == null) return;
      setState(() {
        if (_activePossessionTeam == 1) {
          _possessionMillis1 += 1000;
        } else {
          _possessionMillis2 += 1000;
        }
        _pendingPossessionSaveMs += 1000;
      });
      if (_pendingPossessionSaveMs >= _possessionFirestoreIntervalMs) {
        _pendingPossessionSaveMs = 0;
        _scheduleSave();
      }
    });
  }

  void _startPossession(int team) {
    _undo = _captureSnapshot();
    setState(() {
      _possessionManualMode = false;
      _activePossessionTeam = team;
      _pendingPossessionSaveMs = 0;
      if (_possessionMillis1 + _possessionMillis2 == 0) {
        _possessionMillis1 = 0;
        _possessionMillis2 = 0;
      }
    });
    _syncPossessionTicker();
    _scheduleSave();
  }

  Future<void> _editPossessionManual() async {
    if (_activePossessionTeam != null) {
      await _stopPossession();
    }
    if (!mounted) return;

    if (widget.isPublished && widget.matchId != null) {
      final reopen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: adminCard,
          title: Text(
            'Modifier la possession',
            style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
          ),
          content: Text(
            'Ce match est officiel. On rouvre la saisie pour corriger la possession '
            '(sans renvoyer de notif). Pense à « Terminer » quand c’est bon.',
            style: GoogleFonts.inter(color: adminGrey, fontSize: 12, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('ROUVRIR', style: GoogleFonts.inter(color: adminGold)),
            ),
          ],
        ),
      );
      if (reopen != true || !mounted) return;
      try {
        await MatchStatsSheetService.instance.reopen(widget.matchId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e', style: GoogleFonts.inter())),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final ctrl = TextEditingController(text: '$_poss1');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final p1 = int.tryParse(ctrl.text.trim())?.clamp(0, 100) ?? _poss1;
          final p2 = 100 - p1;
          return AlertDialog(
            backgroundColor: adminCard,
            title: Text(
              'Possession',
              style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_t1 (domicile)',
                  style: GoogleFonts.inter(
                    color: adminTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) => setDlg(() {}),
                  decoration: InputDecoration(
                    hintText: '0–100',
                    suffixText: '%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_t1 $p1% · $_t2 $p2%',
                  style: GoogleFonts.inter(color: adminGold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'L’autre équipe est calculée automatiquement (total 100 %).',
                  style: GoogleFonts.inter(color: adminGrey, fontSize: 10),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
              ),
              TextButton(
                onPressed: () {
                  final v = int.tryParse(ctrl.text.trim());
                  Navigator.pop(ctx, v);
                },
                child: Text('ENREGISTRER', style: GoogleFonts.inter(color: adminGold)),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final p1 = result.clamp(0, 100);
    final p2 = 100 - p1;
    setState(() {
      _possessionManualMode = true;
      _possessionMillis1 = p1 * 600;
      _possessionMillis2 = p2 * 600;
      _activePossessionTeam = null;
    });
    _syncPossessionTicker();
    _scheduleSave();
  }

  Future<void> _stopPossession() async {
    _undo = _captureSnapshot();
    setState(() {
      _activePossessionTeam = null;
      _pendingPossessionSaveMs = 0;
    });
    _syncPossessionTicker();
    await _flushSave();
  }

  String _formatPossessionTimer(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const _kBindingsKey = 'liveStats_keyBindings_v2';

  static Map<String, LogicalKeyboardKey> _defaultBindings() => {
    't1_on':       LogicalKeyboardKey.keyA,
    't1_off':      LogicalKeyboardKey.keyZ,
    't1_poteau':   LogicalKeyboardKey.keyS,
    't1_block':    LogicalKeyboardKey.keyE,
    't1_pass_ok':  LogicalKeyboardKey.keyR,
    't1_pass_bad': LogicalKeyboardKey.keyT,
    't1_cross_ok': LogicalKeyboardKey.keyY,
    't1_cross_bad':LogicalKeyboardKey.keyU,
    't1_duel':     LogicalKeyboardKey.keyQ,
    't2_on':       LogicalKeyboardKey.keyJ,
    't2_off':      LogicalKeyboardKey.keyK,
    't2_poteau':   LogicalKeyboardKey.keyH,
    't2_block':    LogicalKeyboardKey.keyL,
    't2_pass_ok':  LogicalKeyboardKey.keyI,
    't2_pass_bad': LogicalKeyboardKey.keyO,
    't2_cross_ok': LogicalKeyboardKey.keyP,
    't2_cross_bad':LogicalKeyboardKey.keyM,
    't2_duel':     LogicalKeyboardKey.keyN,
    'poss1':       LogicalKeyboardKey.digit1,
    'poss2':       LogicalKeyboardKey.digit2,
    'poss_stop':   LogicalKeyboardKey.digit0,
  };

  static const _actionLabels = <String, String>{
    't1_on':       'CADRE — équipe 1',
    't1_off':      'NON CADRE — équipe 1',
    't1_poteau':   'POTEAU — équipe 1',
    't1_block':    'CONTREE — équipe 1',
    't1_pass_ok':  'PASSE RÉUSSIE — équipe 1',
    't1_pass_bad': 'PASSE RATÉE — équipe 1',
    't1_cross_ok': 'CENTRE RÉUSSI — équipe 1',
    't1_cross_bad':'CENTRE RATÉ — équipe 1',
    't1_duel':     'DUEL GAGNÉ — équipe 1',
    't2_on':       'CADRE — équipe 2',
    't2_off':      'NON CADRE — équipe 2',
    't2_poteau':   'POTEAU — équipe 2',
    't2_block':    'CONTREE — équipe 2',
    't2_pass_ok':  'PASSE RÉUSSIE — équipe 2',
    't2_pass_bad': 'PASSE RATÉE — équipe 2',
    't2_cross_ok': 'CENTRE RÉUSSI — équipe 2',
    't2_cross_bad':'CENTRE RATÉ — équipe 2',
    't2_duel':     'DUEL GAGNÉ — équipe 2',
    'poss1':       'POSSESSION — équipe 1',
    'poss2':       'POSSESSION — équipe 2',
    'poss_stop':   'PAUSE possession',
  };

  Future<void> _loadBindings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kBindingsKey);
    final defaults = _defaultBindings();
    if (saved != null) {
      try {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        final loaded = <String, LogicalKeyboardKey>{};
        for (final e in map.entries) {
          loaded[e.key] = LogicalKeyboardKey(e.value as int);
        }
        // fill missing with defaults
        for (final e in defaults.entries) {
          loaded.putIfAbsent(e.key, () => e.value);
        }
        if (mounted) setState(() => _keyBindings = loaded);
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _keyBindings = defaults);
  }

  Future<void> _saveBindings() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (final e in _keyBindings.entries) e.key: e.value.keyId};
    await prefs.setString(_kBindingsKey, jsonEncode(map));
  }

  String _keyLabel(String action) {
    final key = _keyBindings[action];
    if (key == null) return '?';
    final label = key.keyLabel;
    if (label.length == 1) return label.toUpperCase();
    if (key == LogicalKeyboardKey.digit0) return '0';
    if (key == LogicalKeyboardKey.digit1) return '1';
    if (key == LogicalKeyboardKey.digit2) return '2';
    return label.toUpperCase();
  }

  Widget _buildRemapOverlay() {
    final action = _remappingAction ?? '';
    final label = _actionLabels[action] ?? action;
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black.withAlpha(220),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_rounded, color: adminGold, size: 36),
              const SizedBox(height: 12),
              Text(
                'Appuyez sur une touche',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800, color: adminTextPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: adminGold),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() => _remappingAction = null),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGreyLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runShortcut(String action) {
    switch (action) {
      case 't1_on':
        _shot(1, 'cadre');
        break;
      case 't1_off':
        _shot(1, 'manque');
        break;
      case 't1_block':
        _shot(1, 'blocked');
        break;
      case 't1_poteau':
        _shot(1, 'poteau');
        break;
      case 't1_pass_ok':
        _pass(1, true);
        break;
      case 't1_pass_bad':
        _pass(1, false);
        break;
      case 't1_cross_ok':
        _cross(1, true);
        break;
      case 't1_cross_bad':
        _cross(1, false);
        break;
      case 't1_duel':
        _duel(1);
        break;
      case 't2_on':
        _shot(2, 'cadre');
        break;
      case 't2_off':
        _shot(2, 'manque');
        break;
      case 't2_block':
        _shot(2, 'blocked');
        break;
      case 't2_poteau':
        _shot(2, 'poteau');
        break;
      case 't2_pass_ok':
        _pass(2, true);
        break;
      case 't2_pass_bad':
        _pass(2, false);
        break;
      case 't2_cross_ok':
        _cross(2, true);
        break;
      case 't2_cross_bad':
        _cross(2, false);
        break;
      case 't2_duel':
        _duel(2);
        break;
      case 'poss1':
        _startPossession(1);
        break;
      case 'poss2':
        _startPossession(2);
        break;
      case 'poss_stop':
        _stopPossession();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _shortcutFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // Mode remap : capture la prochaine touche
        if (_remappingAction != null) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _remappingAction = null);
            return KeyEventResult.handled;
          }
          setState(() {
            _keyBindings[_remappingAction!] = event.logicalKey;
            _remappingAction = null;
          });
          _saveBindings();
          return KeyEventResult.handled;
        }
        // Mode normal : déclenche le raccourci associé
        for (final e in _keyBindings.entries) {
          if (e.value == event.logicalKey) {
            _runShortcut(e.key);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            decoration: BoxDecoration(
              color: adminCard,
              border: Border.all(color: adminBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1, color: adminBorder),
                _showStats ? _buildStatsDisplayV2() : _buildActionsZone(),
                _buildResetBar(),
              ],
            ),
          ),
          if (_remappingAction != null) _buildRemapOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, size: 16, color: adminGold),
          const SizedBox(width: 8),
          Text(
            'STATS LIVE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showStats = !_showStats),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _showStats ? adminGold.withAlpha(30) : adminBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _showStats ? adminGold : adminBorder),
              ),
              child: Text(
                _showStats ? '⚡ ACTIONS' : '📊 STATS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _showStats ? adminGold : adminGrey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          _buildPossessionPanel(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTeamColV2(1)),
              const SizedBox(width: 8),
              Expanded(child: _buildTeamColV2(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPossessionPanel() {
    final active = _activePossessionTeam;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, size: 15, color: adminGold),
              const SizedBox(width: 6),
              Text(
                'POSSESSION',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800, color: adminGold, letterSpacing: 0.5),
              ),
              const Spacer(),
              if (active == null)
                GestureDetector(
                  onTap: _editPossessionManual,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: adminGold.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: adminGold.withAlpha(80)),
                    ),
                    child: Text(
                      'MODIFIER %',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: adminGold,
                      ),
                    ),
                  ),
                ),
              if (active == null) const SizedBox(width: 6),
              // Long press → remap poss_stop
              GestureDetector(
                onLongPress: () => setState(() => _remappingAction = 'poss_stop'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: adminBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _keyLabel('poss_stop'),
                    style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: adminGrey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              children: [
                // Équipe 1
                Expanded(
                  child: GestureDetector(
                    onTap: () => _startPossession(1),
                    onLongPress: () => setState(() => _remappingAction = 'poss1'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: active == 1 ? adminGold.withAlpha(30) : adminCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active == 1 ? adminGold : adminBorder,
                          width: active == 1 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (active == 1)
                            const Icon(Icons.circle, size: 8, color: adminGold),
                          Text(
                            _t1.length > 10 ? '${_t1.substring(0, 10)}.' : _t1,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: active == 1 ? adminGold : adminGreyLight),
                          ),
                          Text(
                            _formatPossessionTimer(_possessionMillis1),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: active == 1 ? adminGold : adminGrey),
                          ),
                          Text(
                            '$_poss1%',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18, fontWeight: FontWeight.w900,
                              color: active == 1 ? adminGold : adminGrey),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: adminBorder, borderRadius: BorderRadius.circular(3)),
                            child: Text(
                              _keyLabel('poss1'),
                              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800, color: adminGrey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bouton PAUSE au centre
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _stopPossession,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active == null ? adminGold.withAlpha(22) : adminCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active == null ? adminGold.withAlpha(100) : adminBorder,
                        width: active == null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pause_rounded,
                          size: 18,
                          color: active == null ? adminTextPrimary : adminGreyLight,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PAUSE',
                          style: GoogleFonts.inter(
                            fontSize: 6, fontWeight: FontWeight.w800,
                            color: active == null ? adminTextPrimary : adminGreyLight),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Équipe 2
                Expanded(
                  child: GestureDetector(
                    onTap: () => _startPossession(2),
                    onLongPress: () => setState(() => _remappingAction = 'poss2'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: active == 2 ? adminGold.withAlpha(30) : adminCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active == 2 ? adminGold : adminBorder,
                          width: active == 2 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (active == 2)
                            const Icon(Icons.circle, size: 8, color: adminGold),
                          Text(
                            _t2.length > 10 ? '${_t2.substring(0, 10)}.' : _t2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: active == 2 ? adminGold : adminGreyLight),
                          ),
                          Text(
                            _formatPossessionTimer(_possessionMillis2),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: active == 2 ? adminGold : adminGrey),
                          ),
                          Text(
                            '$_poss2%',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18, fontWeight: FontWeight.w900,
                              color: active == 2 ? adminGold : adminGrey),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: adminBorder, borderRadius: BorderRadius.circular(3)),
                            child: Text(
                              _keyLabel('poss2'),
                              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800, color: adminGrey),
                            ),
                          ),
                        ],
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

  Widget _buildTeamColV2(int team) {
    final name = team == 1 ? _t1 : _t2;
    final shots = team == 1 ? _shots1 : _shots2;
    final target = team == 1 ? _onTarget1 : _onTarget2;
    final blocked = team == 1 ? _blocked1 : _blocked2;
    final passAcc = team == 1 ? _passAcc1 : _passAcc2;
    final passInacc = team == 1 ? _passInacc1 : _passInacc2;
    final crossAcc = team == 1 ? _crossAcc1 : _crossAcc2;
    final crossInacc = team == 1 ? _crossInacc1 : _crossInacc2;
    // ignore: unused_local_variable
    final crossTot = crossAcc + crossInacc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name.length > 10 ? '${name.substring(0, 10)}.' : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _SectionLabel('TIRS', color: const Color(0xFF4CAF50), icon: Icons.sports_soccer_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'CADRE',
          val: target,
          color: const Color(0xFF4CAF50),
          onInc: () => _shot(team, 'cadre'),
          onDec: () => _decShot(team, 'cadre'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_on' : 't2_on'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_on' : 't2_on'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'NON CADRE',
          val: (shots - target - blocked - (team == 1 ? _poteau1 : _poteau2)).clamp(0, 999),
          color: Colors.orange,
          onInc: () => _shot(team, 'manque'),
          onDec: () => _decShot(team, 'manque'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_off' : 't2_off'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_off' : 't2_off'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'POTEAU',
          val: team == 1 ? _poteau1 : _poteau2,
          color: const Color(0xFFD4A017),
          onInc: () => _shot(team, 'poteau'),
          onDec: () => _decShot(team, 'poteau'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_poteau' : 't2_poteau'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_poteau' : 't2_poteau'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'CONTREE',
          val: blocked,
          color: adminGreyLight,
          onInc: () => _shot(team, 'blocked'),
          onDec: () => _decShot(team, 'blocked'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_block' : 't2_block'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_block' : 't2_block'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('PASSES', color: const Color(0xFF42A5F5), icon: Icons.swap_horiz_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'REUSSIE',
          val: passAcc,
          color: const Color(0xFF42A5F5),
          onInc: () => _pass(team, true),
          onDec: () => _decPass(team, true),
          shortcutLabel: _keyLabel(team == 1 ? 't1_pass_ok' : 't2_pass_ok'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_pass_ok' : 't2_pass_ok'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'RATEE',
          val: passInacc,
          color: const Color(0xFFEF5350),
          onInc: () => _pass(team, false),
          onDec: () => _decPass(team, false),
          shortcutLabel: _keyLabel(team == 1 ? 't1_pass_bad' : 't2_pass_bad'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_pass_bad' : 't2_pass_bad'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('CENTRES', color: Colors.orange, icon: Icons.open_with_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'REUSSI',
          val: crossAcc,
          color: Colors.orange,
          onInc: () => _cross(team, true),
          onDec: () => _decCross(team, true),
          shortcutLabel: _keyLabel(team == 1 ? 't1_cross_ok' : 't2_cross_ok'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_cross_ok' : 't2_cross_ok'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'RATE',
          val: crossInacc,
          color: const Color(0xFFEF5350),
          onInc: () => _cross(team, false),
          onDec: () => _decCross(team, false),
          shortcutLabel: _keyLabel(team == 1 ? 't1_cross_bad' : 't2_cross_bad'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_cross_bad' : 't2_cross_bad'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('DUELS', color: const Color(0xFF7B68EE), icon: Icons.sports_mma_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'DUEL GAGNE',
          val: team == 1 ? _duelWon1 : _duelWon2,
          color: const Color(0xFF7B68EE),
          onInc: () => _duel(team),
          onDec: () => _decDuel(team),
          shortcutLabel: _keyLabel(team == 1 ? 't1_duel' : 't2_duel'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_duel' : 't2_duel'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('ÉVÉNEMENTS', color: const Color(0xFFEF5350), icon: Icons.flag_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'CORNERS',
          val: team == 1 ? _corners1 : _corners2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'corners'),
          onDec: () => _dec(team, 'corners'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'HORS-JEU',
          val: team == 1 ? _offsides1 : _offsides2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'offsides'),
          onDec: () => _dec(team, 'offsides'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'FAUTES',
          val: team == 1 ? _fouls1 : _fouls2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'fouls'),
          onDec: () => _dec(team, 'fouls'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'ARRETS',
          val: team == 1 ? _saves1 : _saves2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'saves'),
          onDec: () => _dec(team, 'saves'),
        ),
      ],
    );
  }

  Widget _buildStatsDisplayV2() {
    final tot1 = _passAcc1 + _passInacc1;
    final tot2 = _passAcc2 + _passInacc2;
    final pct1 = tot1 == 0 ? 0.0 : _passAcc1 / tot1;
    final pct2 = tot2 == 0 ? 0.0 : _passAcc2 / tot2;
    final crossTot1 = _crossAcc1 + _crossInacc1;
    final crossTot2 = _crossAcc2 + _crossInacc2;
    final logo1 = (widget.data['logo1'] as String? ?? '').trim();
    final logo2 = (widget.data['logo2'] as String? ?? '').trim();

    Widget sectionHead(String label, Color color, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: color, letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: color.withAlpha(50))),
        ],
      ),
    );

    Widget teamLogo(String url, String name, {bool right = false}) {
      final hasLogo = url.isNotEmpty;
      return Column(
        children: [
          if (hasLogo)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(url, width: 32, height: 32, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, size: 28, color: adminGreyLight)),
            )
          else
            const Icon(Icons.shield_rounded, size: 28, color: adminGreyLight),
          const SizedBox(height: 4),
          Text(
            name.length > 10 ? '${name.substring(0, 10)}.' : name,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.barlowCondensed(
              fontSize: 11, fontWeight: FontWeight.w800, color: adminGrey),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── HEADER ÉQUIPES ───────────────────────────────
          Row(
            children: [
              Expanded(child: teamLogo(logo1, _t1)),
              const SizedBox(width: 8),
              Expanded(child: teamLogo(logo2, _t2, right: true)),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: adminBorder),

          // ── POSSESSION ──────────────────────────────────
          sectionHead('POSSESSION', adminGold, Icons.timer_rounded),
          _SBarRow('POSSESSION', _poss1, _poss2, sfx: '%', color: adminGold),
          _SBarRow2(
            'CHRONO',
            _formatPossessionTimer(_possessionMillis1),
            _formatPossessionTimer(_possessionMillis2),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _editPossessionManual,
              icon: const Icon(Icons.edit_rounded, size: 14, color: adminGold),
              label: Text(
                'Modifier la possession',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: adminGold,
                ),
              ),
            ),
          ),

          // ── TIRS ─────────────────────────────────────────
          sectionHead('TIRS', const Color(0xFF4CAF50), Icons.sports_soccer_rounded),
          _SBarRow('TOTAL', _shots1, _shots2, color: const Color(0xFF4CAF50)),
          _SBarRow('CADRES', _onTarget1, _onTarget2, color: const Color(0xFF4CAF50)),
          _SBarRow('POTEAUX', _poteau1, _poteau2, color: const Color(0xFFD4A017)),
          _SBarRow('CONTREES', _blocked1, _blocked2, color: adminGreyLight),

          // ── PASSES ───────────────────────────────────────
          sectionHead('PASSES', const Color(0xFF42A5F5), Icons.swap_horiz_rounded),
          _SBarRow('REUSSIES', _passAcc1, _passAcc2, color: const Color(0xFF42A5F5)),
          _SBarRow2(
            'PRECISION',
            '${(pct1 * 100).round()}%',
            '${(pct2 * 100).round()}%',
          ),
          _SBarRow('CLES', _keyPass1, _keyPass2, color: const Color(0xFF42A5F5)),

          // ── CENTRES ──────────────────────────────────────
          sectionHead('CENTRES', Colors.orange, Icons.open_with_rounded),
          _SBarRow2(
            'REUSSIS / TOTAL',
            '$_crossAcc1/$crossTot1',
            '$_crossAcc2/$crossTot2',
          ),

          // ── DUELS ────────────────────────────────────────
          sectionHead('DUELS', const Color(0xFF7B68EE), Icons.sports_mma_rounded),
          _SBarRow('GAGNES', _duelWon1, _duelWon2, color: const Color(0xFF7B68EE)),

          // ── EVENEMENTS ───────────────────────────────────
          sectionHead('ÉVÉNEMENTS', const Color(0xFFEF5350), Icons.flag_rounded),
          _SBarRow('CORNERS', _corners1, _corners2, color: const Color(0xFFEF5350)),
          _SBarRow('HORS-JEU', _offsides1, _offsides2, color: const Color(0xFFEF5350)),
          _SBarRow('FAUTES', _fouls1, _fouls2, color: const Color(0xFFEF5350)),
          _SBarRow('ARRÊTS', _saves1, _saves2, color: const Color(0xFFEF5350)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Legacy panel kept temporarily while the new stat cockpit settles.
  // ignore: unused_element
  Widget _buildTeamCol(int team) {
    final name = team == 1 ? _t1 : _t2;
    final shots = team == 1 ? _shots1 : _shots2;
    final target = team == 1 ? _onTarget1 : _onTarget2;
    final blocked = team == 1 ? _blocked1 : _blocked2;
    final passAcc = team == 1 ? _passAcc1 : _passAcc2;
    final passInacc = team == 1 ? _passInacc1 : _passInacc2;
    final passTot = passAcc + passInacc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name.length > 10 ? '${name.substring(0, 10)}.' : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QStat('TIRS', '$shots'),
              _QStat('CADRÉ', '$target'),
              _QStat('CONTRÉ', '$blocked'),
              _QStat('PASSES', passTot == 0 ? '0' : '$passAcc/$passTot'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _SectionLabel('⚽ TIRS'),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: _MiniBtn(
                'CADRÉ',
                const Color(0xFF4CAF50),
                () => _shot(team, 'cadre'),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _MiniBtn(
                'NON CADRÉ',
                Colors.orange,
                () => _shot(team, 'manque'),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _MiniBtn(
                'CONTRÉE',
                adminGreyLight,
                () => _shot(team, 'blocked'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _SectionLabel('🎯 PASSES'),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: _MiniBtn(
                'RÉUSSIE',
                const Color(0xFF4CAF50),
                () => _pass(team, true),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _MiniBtn('RATÉE', adminRed, () => _pass(team, false)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _SectionLabel('💪 DUELS'),
        const SizedBox(height: 3),
        _MiniBtn('DUEL GAGNÉ', const Color(0xFF7B68EE), () => _duel(team)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${team == 1 ? _duelWon1 : _duelWon2}',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                ),
              ),
              Text(
                ' gagnés  /  ${team == 1 ? _duelWon2 : _duelWon1} perdus',
                style: GoogleFonts.inter(fontSize: 8, color: adminGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _CounterRow(
          label: 'CORNERS',
          val: team == 1 ? _corners1 : _corners2,
          onInc: () => _inc(team, 'corners'),
          onDec: () => _dec(team, 'corners'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'HORS-JEU',
          val: team == 1 ? _offsides1 : _offsides2,
          onInc: () => _inc(team, 'offsides'),
          onDec: () => _dec(team, 'offsides'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'FAUTES',
          val: team == 1 ? _fouls1 : _fouls2,
          onInc: () => _inc(team, 'fouls'),
          onDec: () => _dec(team, 'fouls'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'ARRÊTS',
          val: team == 1 ? _saves1 : _saves2,
          onInc: () => _inc(team, 'saves'),
          onDec: () => _dec(team, 'saves'),
        ),
      ],
    );
  }

  // Legacy panel kept temporarily while the new stat cockpit settles.
  // ignore: unused_element
  Widget _buildStatsDisplay() {
    final tot1 = _passAcc1 + _passInacc1;
    final tot2 = _passAcc2 + _passInacc2;
    final pct1 = tot1 == 0 ? 0.0 : _passAcc1 / tot1;
    final pct2 = tot2 == 0 ? 0.0 : _passAcc2 / tot2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          _SBarRow('POSSESSION', _poss1, _poss2, sfx: '%'),
          _SBarRow('TIRS', _shots1, _shots2),
          _SBarRow('TIRS CADRÉS', _onTarget1, _onTarget2),
          _SBarRow('TIRS BLOQUÉS', _blocked1, _blocked2),
          _SBarRow2('xG', _xg1.toStringAsFixed(2), _xg2.toStringAsFixed(2)),
          _SBarRow('PASSES RÉUSSIES', _passAcc1, _passAcc2),
          _SBarRow2(
            'PRÉCISION PASSES',
            '${(pct1 * 100).round()}%',
            '${(pct2 * 100).round()}%',
          ),
          _SBarRow('PASSES CLÉS', _keyPass1, _keyPass2),
          _SBarRow('CENTRES RÉUSSIS', _crossAcc1, _crossAcc2),
          _SBarRow('DUELS GAGNÉS', _duelWon1, _duelWon2),
          _SBarRow('CORNERS', _corners1, _corners2),
          _SBarRow('HORS-JEU', _offsides1, _offsides2),
          _SBarRow('FAUTES', _fouls1, _fouls2),
          _SBarRow('ARRÊTS', _saves1, _saves2),
        ],
      ),
    );
  }

  Widget _buildResetBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (_undo != null) ...[
            GestureDetector(
              onTap: () async {
                final snap = _undo;
                if (snap == null) return;
                setState(() {
                  _restoreSnapshot(snap);
                  _undo = null;
                });
                await _flushSave();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.undo_rounded,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ANNULER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: adminCard,
                    title: Text(
                      'Réinitialiser les stats ?',
                      style: GoogleFonts.inter(
                        color: adminTextPrimary,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text(
                          'RESET',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok != true || !mounted) return;
                setState(() {
                  _shots1 = _shots2 = _onTarget1 = _onTarget2 = _blocked1 =
                      _blocked2 = 0;
                  _xg1 = _xg2 = 0;
                  _passAcc1 = _passAcc2 = _passInacc1 = _passInacc2 = 0;
                  _keyPass1 = _keyPass2 = _crossAcc1 = _crossAcc2 =
                      _crossInacc1 = _crossInacc2 = 0;
                  _tackleWon1 = _tackleWon2 = _tackleLost1 = _tackleLost2 = 0;
                  _duelWon1 = _duelWon2 = _aerialWon1 = _aerialWon2 = 0;
                  _corners1 = _corners2 = _offsides1 = _offsides2 = _fouls1 =
                      _fouls2 = 0;
                  _saves1 = _saves2 = 0;
                  _possessionMillis1 = _possessionMillis2 = 0;
                  _activePossessionTeam = null;
                  _possessionManualMode = false;
                  _pendingPossessionSaveMs = 0;
                });
                _syncPossessionTicker();
                await _flushSave();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: adminBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder),
                ),
                child: Center(
                  child: Text(
                    'RÉINITIALISER STATS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: adminGrey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VOTE META COLUMN
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _SectionLabel(this.label, {this.color = adminGrey, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 1, color: color.withAlpha(50))),
        ],
      ),
    );
  }
}

class _QStat extends StatelessWidget {
  final String label, value;
  const _QStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 7,
            fontWeight: FontWeight.w700,
            color: adminGrey,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int val;
  final VoidCallback onInc, onDec;
  final String? shortcutLabel; // ex: 'A', '1'
  final VoidCallback? onRemap; // long press → remap
  final Color color;

  const _CounterRow({
    required this.label,
    required this.val,
    required this.onInc,
    required this.onDec,
    this.shortcutLabel,
    this.onRemap,
    this.color = adminGold,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: adminBg,
          border: Border.all(color: adminBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Bouton —
              GestureDetector(
                onTap: onDec,
                child: Container(
                  width: 44,
                  color: adminBorder.withAlpha(55),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_rounded, size: 18, color: adminGrey),
                ),
              ),
              // Valeur + label (long press → remap)
              Expanded(
                child: GestureDetector(
                  onLongPress: onRemap,
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$val',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: val > 0 ? color : adminTextPrimary,
                              ),
                            ),
                            if (shortcutLabel != null) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: adminBorder,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  shortcutLabel!,
                                  style: GoogleFonts.inter(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    color: adminGrey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: adminGrey,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
              // Bouton +
              GestureDetector(
                onTap: onInc,
                child: Container(
                  width: 44,
                  color: color.withAlpha(20),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, size: 18, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SBarRow extends StatelessWidget {
  final String label;
  final int v1, v2;
  final String sfx;
  final Color color;
  const _SBarRow(this.label, this.v1, this.v2,
      {this.sfx = '', this.color = adminGold});

  @override
  Widget build(BuildContext context) {
    final total = v1 + v2;
    final frac1 = total == 0 ? 0.5 : v1 / total;
    final bar1 = (frac1 * 100).round().clamp(1, 99);
    final isLeading = v1 >= v2;
    final isTrailing = v2 > v1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '$v1$sfx',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isLeading && total > 0 ? color : adminTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: adminGrey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$v2$sfx',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isTrailing && total > 0 ? color : adminTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: bar1,
                    child: Container(color: color.withAlpha(180)),
                  ),
                  Expanded(
                    flex: 100 - bar1,
                    child: Container(color: color.withAlpha(40)),
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

class _MiniBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SBarRow2 extends StatelessWidget {
  final String label, v1, v2;
  const _SBarRow2(this.label, this.v1, this.v2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              v1,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: adminGrey,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              v2,
              textAlign: TextAlign.right,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

