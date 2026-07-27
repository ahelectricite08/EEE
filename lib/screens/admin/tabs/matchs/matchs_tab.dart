import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_components.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import 'match_editor.dart';
import 'matchs_list_tile.dart';

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
    return v.toString().trim();
  }

  static bool _isMatchDateInPast(Map<String, dynamic> d) {
    final raw = d['date'];
    if (raw is! Timestamp) return false;
    return raw.toDate().isBefore(DateTime.now());
  }

  static String _dedupeKey(Map<String, dynamic> d) {
    final fff = _fieldStr(d, 'fffId');
    if (fff.isNotEmpty) return 'fff:$fff';
    final id = _fieldStr(d, 'id');
    if (id.isNotEmpty) return 'id:$id';
    return '${d['team1']}|${d['team2']}|${d['date']}';
  }

  void _openNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MatchEditorScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  List<Widget> _topSlivers(Color accent) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdminModuleHeader(
              title: 'Matchs',
              subtitle:
                  'Fiche calendrier & faits de jeu — pas le direct ni les stats chiffrées.',
              icon: Icons.sports_soccer_rounded,
              accent: accent,
              trailing: AdminPrimaryButton(
                label: 'Nouveau',
                icon: Icons.add_rounded,
                height: 36,
                onTap: _openNew,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdminSegmentedControl(
              selected: _filter,
              accent: accent,
              onChanged: (v) => setState(() => _filter = v),
              options: const [
                AdminSegmentOption(value: 'upcoming', label: 'À venir'),
                AdminSegmentOption(value: 'finished', label: 'Résultats'),
                AdminSegmentOption(value: 'all', label: 'Tous'),
              ],
            ),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final accent = AdminModuleColors.preparation;
    final Query<Map<String, dynamic>> query;
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
        final top = _topSlivers(accent);
        if (snap.hasError) {
          return CustomScrollView(
            slivers: [
              ...top,
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
              ...top,
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AdminModuleColors.preparation,
                  ),
                ),
              ),
            ],
          );
        }

        final seen = <String>{};
        var docs = snap.data!.docs.where((d) {
          return seen.add(_dedupeKey(d.data() as Map<String, dynamic>));
        }).toList();

        if (_filter == 'upcoming') {
          docs = docs
              .where(
                (d) => !_isMatchDateInPast(d.data() as Map<String, dynamic>),
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
              ...top,
              SliverFillRemaining(
                hasScrollBody: false,
                child: AdminEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Aucun match dans cette vue',
                  subtitle:
                      'Change de filtre ou crée un match avec le bouton « Nouveau ».',
                  actionLabel: 'Nouveau match',
                  onAction: _openNew,
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            ...top,
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '${docs.length} match${docs.length > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: adminGrey,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final docSnap = docs[i];
                    final dm = docSnap.data() as Map<String, dynamic>;
                    final statusStr = (dm['status'] ?? 'upcoming').toString();
                    final stale = _filter != 'upcoming' &&
                        statusStr == 'upcoming' &&
                        _isMatchDateInPast(dm);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < docs.length - 1 ? 8.0 : 0,
                      ),
                      child: MatchAdminListTile(
                        docSnap: docSnap,
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
}
