import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../admin_palette.dart';

/// Push « rappel match » Sedan/CSSA : choix du match, aperçu et texte modifiable.
class MatchReminderTab extends StatefulWidget {
  const MatchReminderTab({super.key});

  @override
  State<MatchReminderTab> createState() => _MatchReminderTabState();
}

class _MatchReminderTabState extends State<MatchReminderTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  List<_MatchReminderRow> _rows = [];
  _MatchReminderRow? _selected;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'getMatchReminderCandidates',
      );
      final res = await fn.call();
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      final raw = data['matches'];
      final list = raw is List ? raw : <dynamic>[];
      final rows = <_MatchReminderRow>[];
      for (final e in list) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        rows.add(
          _MatchReminderRow(
            matchId: '${m['matchId'] ?? ''}',
            team1: '${m['team1'] ?? ''}',
            team2: '${m['team2'] ?? ''}',
            kickoffMs: (m['kickoffMs'] as num?)?.toInt(),
            suggestedTitle: '${m['suggestedTitle'] ?? ''}',
            suggestedBody: '${m['suggestedBody'] ?? ''}',
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        if (_selected != null) {
          _MatchReminderRow? still;
          for (final r in rows) {
            if (r.matchId == _selected!.matchId) {
              still = r;
              break;
            }
          }
          if (still != null) {
            _selected = still;
          } else {
            _selected = rows.isNotEmpty ? rows.first : null;
            _applySelection();
          }
        } else if (rows.isNotEmpty) {
          _selected = rows.first;
          _applySelection();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _applySelection() {
    final s = _selected;
    if (s == null) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      return;
    }
    _titleCtrl.text = s.suggestedTitle;
    _bodyCtrl.text = s.suggestedBody;
  }

  Future<void> _send() async {
    final s = _selected;
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choisis un match', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'sendMatchReminderManual',
      );
      await fn.call(<String, dynamic>{
        'matchId': s.matchId,
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notification envoyée (topic dvcr_notifications)',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Envoi : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _kickoffLabel(_MatchReminderRow r) {
    final ms = r.kickoffMs;
    if (ms == null) return 'Date inconnue';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat("EEE d MMM · HH:mm", 'fr_FR').format(dt);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 980 : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rappel match (push)',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Matchs Sedan / CSSA à venir. Tu choisis le match, tu vois '
                  'et tu modifies le titre et le texte, puis envoi sur le '
                  'topic général des notifs (comme l’ancien rappel automatique).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: adminGrey,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Actualiser la liste',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(fontSize: 12, color: adminRed),
                  ),
                ],
                const SizedBox(height: 24),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildMatchList()),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: _buildEditor()),
                    ],
                  )
                else ...[
                  _buildMatchList(),
                  const SizedBox(height: 20),
                  _buildEditor(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchList() {
    if (_rows.isEmpty && !_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: adminBorder),
        ),
        child: Text(
          'Aucun match à venir Sedan/CSSA trouvé. Vérifie que les matchs '
          'sont en statut « upcoming » dans Firestore.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              'Prochains matchs',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: adminGold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rows.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: adminBorder),
            itemBuilder: (context, i) {
              final r = _rows[i];
              final sel = _selected?.matchId == r.matchId;
              return ListTile(
                selected: sel,
                selectedTileColor: adminGold.withAlpha(24),
                title: Text(
                  '${r.team1} — ${r.team2}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: adminTextPrimary,
                  ),
                ),
                subtitle: Text(
                  _kickoffLabel(r),
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
                onTap: () {
                  setState(() {
                    _selected = r;
                    _applySelection();
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aperçu & envoi',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selected == null
                ? 'Sélectionne un match à gauche.'
                : 'ID : ${_selected!.matchId}',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            enabled: _selected != null,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: adminTextPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Titre (notification)',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              filled: true,
              fillColor: adminSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: adminBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            enabled: _selected != null,
            minLines: 3,
            maxLines: 6,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: adminTextPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Texte (corps)',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              filled: true,
              fillColor: adminSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: adminBorder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les champs vides au moment de l’envoi utilisent les textes par défaut côté serveur.',
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_sending || _selected == null) ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: adminRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              'Envoyer la push à tout le monde (topic)',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchReminderRow {
  final String matchId;
  final String team1;
  final String team2;
  final int? kickoffMs;
  final String suggestedTitle;
  final String suggestedBody;

  _MatchReminderRow({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.kickoffMs,
    required this.suggestedTitle,
    required this.suggestedBody,
  });
}
