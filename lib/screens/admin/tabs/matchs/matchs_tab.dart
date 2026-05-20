import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/match_model.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';
import '../../admin_module_shell.dart';
import 'match_editor.dart';

class MatchsTab extends StatefulWidget {
  const MatchsTab();

  @override
  State<MatchsTab> createState() => _MatchsTabState();
}

class _MatchsTabState extends State<MatchsTab> {
  String _filter = 'upcoming';

  static String _fieldStr(Map<String, dynamic> d, String key) {
    final v = d[key];
    if (v == null) return '';
    final s = v.toString().trim();
    return s;
  }

  static String _statusDisplayLabel(String status) {
    switch (status) {
      case 'finished':
        return 'TERMINÉ';
      case 'live':
        return 'LIVE';
      default:
        return 'À VENIR';
    }
  }

  /// True si la date/heure du match est déjà passée (mais le doc peut encore être `upcoming`).
  static bool _isMatchDateInPast(Map<String, dynamic> d) {
    final raw = d['date'];
    if (raw is! Timestamp) return false;
    return raw.toDate().isBefore(DateTime.now());
  }

  /// Clé de dédup : `fffId` si présent (évite doublons sync / manuel), sinon équipes + date.
  static String _dedupeKey(Map<String, dynamic> d) {
    final fff = _fieldStr(d, 'fffId');
    if (fff.isNotEmpty) return 'fff:$fff';
    final id = _fieldStr(d, 'id');
    if (id.isNotEmpty) return 'id:$id';
    return '${d['team1']}|${d['team2']}|${d['date']}';
  }

  Widget _buildFilterStrip() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _filterSeg(
              'À venir',
              'upcoming',
              Icons.schedule_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _filterSeg(
              'Résultats',
              'finished',
              Icons.emoji_events_outlined,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _filterSeg(
              'Tous',
              'all',
              Icons.grid_view_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterSeg(String label, String filterKey, IconData icon) {
    final sel = _filter == filterKey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = filterKey),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            color: sel ? adminCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? adminGold.withAlpha(170) : Colors.transparent,
              width: sel ? 1.5 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: adminGold.withAlpha(38),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: sel ? adminGold : adminGrey),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: sel ? adminTextPrimary : adminGrey,
                  letterSpacing: 0.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query;
    if (_filter == 'upcoming') {
      query = FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('date')
          .limit(80);
    } else if (_filter == 'finished') {
      query = FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .orderBy('date', descending: true)
          .limit(30);
    } else {
      query = FirebaseFirestore.instance
          .collection('matches')
          .orderBy('date', descending: true)
          .limit(50);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final topSlivers = <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AdminModuleHeader(
                title: 'Matchs',
                subtitle:
                    'Calendrier, résultats, replays : créer et éditer les fiches match.',
                icon: Icons.sports_soccer_rounded,
                accent: adminRed,
                trailing: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MatchEditorScreen(),
                        fullscreenDialog: true,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE1C15A), adminGold],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: adminGold.withAlpha(55),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NOUVEAU',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildFilterStrip(),
            ),
          ),
        ];

        if (snap.hasError) {
          return CustomScrollView(
            slivers: [
              ...topSlivers,
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur chargement matchs :\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: adminRed,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return CustomScrollView(
            slivers: [
              ...topSlivers,
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: adminGold),
                ),
              ),
            ],
          );
        }
        final seen = <String>{};
        var docs = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return seen.add(_dedupeKey(data));
        }).toList();

        // « À venir » = statut upcoming **et** date future (aligné sur la logique sync API).
        // Les fiches restées `upcoming` après la date apparaissent dans « Tous » / « Résultats ».
        if (_filter == 'upcoming') {
          docs = docs
              .where(
                (d) =>
                    !_isMatchDateInPast(d.data() as Map<String, dynamic>),
              )
              .toList();
          docs.sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            final ta = da['date'] is Timestamp
                ? (da['date'] as Timestamp).millisecondsSinceEpoch
                : 0;
            final tb = db['date'] is Timestamp
                ? (db['date'] as Timestamp).millisecondsSinceEpoch
                : 0;
            return ta.compareTo(tb);
          });
        }
        if (docs.isEmpty) {
          return CustomScrollView(
            slivers: [
              ...topSlivers,
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 44,
                          color: adminGrey.withAlpha(160),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Aucun match dans cette vue',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Change de filtre ou crée un match avec « Nouveau ».',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: adminGrey,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return CustomScrollView(
          slivers: [
            ...topSlivers,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final gapBottom = i < docs.length - 1 ? 10.0 : 0.0;
                    final docSnap = docs[i];
                    final dm = docSnap.data() as Map<String, dynamic>;
                    final statusStr = (dm['status'] ?? 'upcoming').toString();
                    final stale = _filter != 'upcoming' &&
                        statusStr == 'upcoming' &&
                        _isMatchDateInPast(dm);
                    return Padding(
                      padding: EdgeInsets.only(bottom: gapBottom),
                      child: _buildMatchCard(
                        context,
                        docSnap,
                        staleUpcomingDate: stale,
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    DocumentSnapshot docSnap, {
    bool staleUpcomingDate = false,
  }) {
    final d = docSnap.data() as Map<String, dynamic>;
    var t1 = _fieldStr(d, 'team1');
    var t2 = _fieldStr(d, 'team2');
    if (t1.isEmpty) t1 = 'Équipe 1';
    if (t2.isEmpty) t2 = 'Équipe 2';
    final s1 = MatchModel.parseScoreField(
      d['score1'] ?? d['homeScore'],
    );
    final s2 = MatchModel.parseScoreField(
      d['score2'] ?? d['awayScore'],
    );
    final status = (d['status'] ?? 'upcoming').toString();
    final comp = _fieldStr(d, 'competition');
    final compLabel = comp.isEmpty ? 'Compétition' : comp;
    final hasReplay = d['replayVideoId'] != null;
    final statusColor = status == 'finished'
        ? const Color(0xFF4CAF50)
        : status == 'live'
        ? adminRed
        : Colors.orange;
    final statusLabel = _statusDisplayLabel(status);
    final rawDate = d['date'];
    final dateStr = rawDate is Timestamp
        ? '${rawDate.toDate().day.toString().padLeft(2, '0')}/'
            '${rawDate.toDate().month.toString().padLeft(2, '0')}/'
            '${rawDate.toDate().year}'
        : '';
    final teamStyle = GoogleFonts.barlowCondensed(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: adminTextPrimary,
      height: 1.2,
    );
    final metaStyle = GoogleFonts.inter(
      fontSize: 11,
      color: adminGrey,
      height: 1.25,
    );
    return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: adminCardShadow,
                    ),
                    child: Material(
                      color: adminCard,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: adminBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchEditorScreen(doc: docSnap),
                            fullscreenDialog: true,
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: statusColor,
                                width: 4,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 40),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t1,
                                            style: teamStyle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Text(
                                            'VS',
                                            style: GoogleFonts.barlowCondensed(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: adminGold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            t2,
                                            style: teamStyle,
                                            textAlign: TextAlign.end,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (s1 != null && s2 != null) ...[
                                      const SizedBox(height: 10),
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: adminSurface,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: adminBorder,
                                            ),
                                          ),
                                          child: Text(
                                            '$s1  —  $s2',
                                            style:
                                                GoogleFonts.barlowCondensed(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: adminTextPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        if (dateStr.isNotEmpty) ...[
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 14,
                                            color: adminGrey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(dateStr, style: metaStyle),
                                        ],
                                        const Spacer(),
                                        AdminStatusChip(
                                          label: statusLabel,
                                          color: statusColor,
                                        ),
                                        if (staleUpcomingDate) ...[
                                          const SizedBox(width: 6),
                                          const AdminStatusChip(
                                            label: 'DATE PASSÉE',
                                            color: adminOrange,
                                          ),
                                        ],
                                        if (hasReplay) ...[
                                          const SizedBox(width: 6),
                                          const AdminStatusChip(
                                            label: 'REPLAY',
                                            color: adminGold,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: adminGold.withAlpha(12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: adminGold.withAlpha(45),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.emoji_events_outlined,
                                            size: 15,
                                            color: adminGold,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              compLabel,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: adminTextPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (staleUpcomingDate) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: adminOrange.withAlpha(22),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: adminOrange.withAlpha(90),
                                          ),
                                        ),
                                        child: Text(
                                          'Passe le statut en Terminé (ou Live) : la date du match est déjà passée.',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: adminTextPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Actions',
                                  color: adminCard,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: adminBorder),
                                  ),
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MatchEditorScreen(doc: docSnap),
                                          fullscreenDialog: true,
                                        ),
                                      );
                                    } else if (v == 'replay') {
                                      _editReplay(context, docSnap);
                                    } else if (v == 'delete') {
                                      final ok = await adminConfirm(
                                        context,
                                        'Supprimer ce match ?',
                                      );
                                      if (ok) await docSnap.reference.delete();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    _mItem(
                                      'edit',
                                      Icons.edit_rounded,
                                      'Modifier',
                                    ),
                                    _mItem(
                                      'replay',
                                      Icons.video_call_rounded,
                                      hasReplay
                                          ? 'Éditer replay'
                                          : 'Ajouter replay',
                                    ),
                                    _mItem(
                                      'delete',
                                      Icons.delete_rounded,
                                      'Supprimer',
                                      color: adminRed,
                                    ),
                                  ],
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: adminGrey,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
  }

  PopupMenuItem<String> _mItem(
    String v,
    IconData icon,
    String label, {
    Color? color,
  }) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? adminTextPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? adminTextPrimary,
              ),
            ),
          ],
        ),
      );

  void _editReplay(BuildContext context, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ctrl = TextEditingController(text: d['replayVideoId'] ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID VIDÉO YOUTUBE',
              style: GoogleFonts.barlowCondensed(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: adminGold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${d['team1']} vs ${d['team2']}',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            ),
            const SizedBox(height: 16),
            AdminField(
              ctrl: ctrl,
              label: 'YouTube Video ID (ex: dQw4w9WgXcQ)',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if ((d['replayVideoId'] ?? '').isNotEmpty) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await doc.reference.update({
                          'replayVideoId': FieldValue.delete(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: adminRed.withAlpha(120)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'SUPPRIMER',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: adminRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (ctrl.text.trim().isEmpty) return;
                      await doc.reference.update({
                        'replayVideoId': ctrl.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: adminGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'ENREGISTRER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
