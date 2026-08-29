import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dvcr/features/prono/domain/prono_season_rank.dart';

import '../../admin_dialogs.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';

/// Liste admin des entrées `prono_leaderboard` (panneau Jeux uniquement).
void showPronoLeaderboardAdminSheet(BuildContext context) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(90),
    builder: (_) => const _PronoLeaderboardAdminSheet(),
  );
}

class _PronoLeaderboardAdminSheet extends StatefulWidget {
  const _PronoLeaderboardAdminSheet();

  @override
  State<_PronoLeaderboardAdminSheet> createState() =>
      _PronoLeaderboardAdminSheetState();
}

class _PronoLeaderboardAdminSheetState
    extends State<_PronoLeaderboardAdminSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AdminModuleColors.jeux;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              adminBottomSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASSEMENT PRONO',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: adminTextPrimary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toutes les personnes présentes dans prono_leaderboard.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: adminGrey,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: adminTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un nom…',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: adminGrey,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: adminGrey,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: adminGrey,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: adminSurface,
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: adminBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: accent, width: 1.4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: adminBorder),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('prono_leaderboard')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Impossible de charger le classement.\n${snap.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: adminRed,
                            ),
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      );
                    }

                    final docs = [...snap.data!.docs]..sort((a, b) {
                        return comparePronoSeasonRank(
                          pointsA:
                              (a.data()['points'] as num?)?.toInt() ?? 0,
                          exactA: (a.data()['exactScores'] as num?)
                                  ?.toInt() ??
                              0,
                          lineupPointsA: (a.data()['lineupPoints'] as num?)
                                  ?.toInt() ??
                              0,
                          firstScorerPointsA:
                              (a.data()['firstScorerPoints'] as num?)
                                      ?.toInt() ??
                                  0,
                          uidA: a.id,
                          pointsB:
                              (b.data()['points'] as num?)?.toInt() ?? 0,
                          exactB: (b.data()['exactScores'] as num?)
                                  ?.toInt() ??
                              0,
                          lineupPointsB: (b.data()['lineupPoints'] as num?)
                                  ?.toInt() ??
                              0,
                          firstScorerPointsB:
                              (b.data()['firstScorerPoints'] as num?)
                                      ?.toInt() ??
                                  0,
                          uidB: b.id,
                        );
                      });
                    final q = _query.toLowerCase();
                    final filtered = q.isEmpty
                        ? docs
                        : docs.where((doc) {
                            final d = doc.data();
                            final name =
                                (d['displayName'] ?? '').toString().toLowerCase();
                            final uid = doc.id.toLowerCase();
                            return name.contains(q) || uid.contains(q);
                          }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Aucune entrée classement.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: adminGrey,
                          ),
                        ),
                      );
                    }
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'Aucun résultat pour « $_query ».',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: adminGrey,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: adminBottomSheetPadding(
                        context,
                        top: 8,
                        extra: 24,
                      ),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, i) => i == 0
                          ? const SizedBox(height: 8)
                          : const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Text(
                            q.isEmpty
                                ? '${docs.length} personne${docs.length > 1 ? 's' : ''}'
                                : '${filtered.length} / ${docs.length}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: adminGrey,
                            ),
                          );
                        }
                        final doc = filtered[i - 1];
                        final rank = docs.indexWhere((d) => d.id == doc.id) + 1;
                        return _LeaderboardRow(doc: doc, rank: rank);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int rank;

  const _LeaderboardRow({required this.doc, required this.rank});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final name = (d['displayName'] ?? 'Membre').toString().trim();
    final points = (d['points'] as num?)?.toInt() ?? 0;
    final exact = (d['exactScores'] as num?)?.toInt() ?? 0;
    final goods = (d['goodResults'] as num?)?.toInt() ?? 0;
    final preds = (d['totalPredictions'] as num?)?.toInt() ?? 0;
    final xi = (d['perfectXiCount'] as num?)?.toInt() ?? 0;
    final xiPts = (d['lineupPoints'] as num?)?.toInt() ?? 0;
    final fsPts = (d['firstScorerPoints'] as num?)?.toInt() ?? 0;

    return Material(
      color: adminSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: doc.id));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('UID copié : ${doc.id}'),
              backgroundColor: adminGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: rank <= 3 ? adminGold : adminGrey,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Membre' : name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$exact exact · $goods bons · $preds prono${preds > 1 ? 's' : ''} · $xiPts pts XI · $fsPts pts buteur · $xi XI 11/11',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$points pts',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
