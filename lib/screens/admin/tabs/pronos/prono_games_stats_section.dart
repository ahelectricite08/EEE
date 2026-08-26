import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../models/match_stats_schema.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import '../../admin_stat_widgets.dart';

class _MatchEngagement {
  final String id;
  final String team1;
  final String team2;
  final DateTime? date;
  final String status;
  final int pronoTotal;
  final int homeWin;
  final int draw;
  final int awayWin;
  final int xiCount;
  final bool isSedan;

  const _MatchEngagement({
    required this.id,
    required this.team1,
    required this.team2,
    required this.date,
    required this.status,
    required this.pronoTotal,
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    required this.xiCount,
    required this.isSedan,
  });
}

class _PronoGamesSnapshot {
  final int xiSubmissions;
  final int xiUniqueUsers;
  final int pronoDocs;
  final int matchesWithPronos;
  final List<_MatchEngagement> upcoming;
  final List<_MatchEngagement> live;
  final List<_MatchEngagement> finished;

  const _PronoGamesSnapshot({
    required this.xiSubmissions,
    required this.xiUniqueUsers,
    required this.pronoDocs,
    required this.matchesWithPronos,
    required this.upcoming,
    required this.live,
    required this.finished,
  });
}

/// Stats d’usage Pronos + XI probable (admin Jeux → Championnat).
class PronoGamesStatsSection extends StatefulWidget {
  const PronoGamesStatsSection({super.key});

  @override
  State<PronoGamesStatsSection> createState() => _PronoGamesStatsSectionState();
}

class _PronoGamesStatsSectionState extends State<PronoGamesStatsSection> {
  late Future<_PronoGamesSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PronoGamesSnapshot> _load() async {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('predictions').count().get(),
      db.collection('lineup_predictions').get(),
      db.collection('match_prono_stats').get(),
      db
          .collection('matches')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('date')
          .limit(16)
          .get(),
      db.collection('matches').where('status', isEqualTo: 'live').get(),
      db
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .orderBy('date', descending: true)
          .limit(8)
          .get(),
    ]);

    final pronoCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final xiSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final statsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final upcoming = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final live = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final finished = results[5] as QuerySnapshot<Map<String, dynamic>>;

    final xiByMatch = <String, int>{};
    final xiUsers = <String>{};
    for (final doc in xiSnap.docs) {
      final d = doc.data();
      final matchId = (d['matchId'] ?? '').toString().trim();
      final uid = (d['uid'] ?? '').toString().trim();
      if (matchId.isNotEmpty) {
        xiByMatch[matchId] = (xiByMatch[matchId] ?? 0) + 1;
      }
      if (uid.isNotEmpty) xiUsers.add(uid);
    }

    final statsByMatch = <String, Map<String, int>>{};
    for (final doc in statsSnap.docs) {
      final d = doc.data();
      statsByMatch[doc.id] = {
        'total': (d['total'] as num?)?.toInt() ?? 0,
        'homeWin': (d['homeWin'] as num?)?.toInt() ?? 0,
        'draw': (d['draw'] as num?)?.toInt() ?? 0,
        'awayWin': (d['awayWin'] as num?)?.toInt() ?? 0,
      };
    }
    final matchesWithPronos =
        statsByMatch.values.where((s) => (s['total'] ?? 0) > 0).length;

    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    _MatchEngagement fromMatch(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final d = doc.data();
      final team1 = (d['team1'] ?? '').toString();
      final team2 = (d['team2'] ?? '').toString();
      final st = statsByMatch[doc.id];
      return _MatchEngagement(
        id: doc.id,
        team1: team1,
        team2: team2,
        date: parseDate(d['date']),
        status: (d['status'] ?? '').toString(),
        pronoTotal: st?['total'] ?? 0,
        homeWin: st?['homeWin'] ?? 0,
        draw: st?['draw'] ?? 0,
        awayWin: st?['awayWin'] ?? 0,
        xiCount: xiByMatch[doc.id] ?? 0,
        isSedan: MatchStatsSchema.isSedanTeamLabel(team1) ||
            MatchStatsSchema.isSedanTeamLabel(team2),
      );
    }

    int byDateAsc(_MatchEngagement a, _MatchEngagement b) {
      final da = a.date;
      final db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    final upcomingRows = upcoming.docs.map(fromMatch).toList()
      ..sort(byDateAsc);
    final seen = upcomingRows.map((m) => m.id).toSet();

    final liveRows = <_MatchEngagement>[];
    for (final doc in live.docs) {
      if (!seen.add(doc.id)) continue;
      liveRows.add(fromMatch(doc));
    }
    liveRows.sort(byDateAsc);

    final finishedRows = <_MatchEngagement>[];
    for (final doc in finished.docs) {
      if (!seen.add(doc.id)) continue;
      finishedRows.add(fromMatch(doc));
    }

    return _PronoGamesSnapshot(
      xiSubmissions: xiSnap.docs.length,
      xiUniqueUsers: xiUsers.length,
      pronoDocs: pronoCount,
      matchesWithPronos: matchesWithPronos,
      upcoming: upcomingRows,
      live: liveRows,
      finished: finishedRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = AdminModuleColors.jeux;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATISTIQUES',
          style: GoogleFonts.barlowCondensed(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Combien de fans jouent aux pronos.',
          style: GoogleFonts.inter(
            fontSize: 11,
            height: 1.35,
            color: adminGrey,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<_PronoGamesSnapshot>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                'Impossible de charger les stats : ${snap.error}',
                style: GoogleFonts.inter(fontSize: 12, color: adminRed),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                ),
              );
            }
            final data = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminStatRow(
                  stats: [
                    AdminStatCardShell(
                      color: accent,
                      icon: Icons.groups_rounded,
                      label: 'XI FAITS',
                      child: _BigNum('${data.xiSubmissions}'),
                    ),
                    AdminStatCardShell(
                      color: accent,
                      icon: Icons.person_rounded,
                      label: 'PERSONNES XI',
                      child: _BigNum('${data.xiUniqueUsers}'),
                    ),
                    AdminStatCardShell(
                      color: adminGold,
                      icon: Icons.sports_soccer_rounded,
                      label: 'PRONOS SCORE',
                      child: _BigNum('${data.pronoDocs}'),
                    ),
                    AdminStatCardShell(
                      color: adminBlue,
                      icon: Icons.event_rounded,
                      label: 'MATCHS JOUÉS',
                      child: _BigNum('${data.matchesWithPronos}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _kpiLegendLine(
                  title: 'XI faits',
                  body: 'nombre de XI enregistrés (1 par fan et par match).',
                ),
                _kpiLegendLine(
                  title: 'Personnes XI',
                  body: 'nombre de fans différents qui ont composé un XI.',
                ),
                _kpiLegendLine(
                  title: 'Pronos score',
                  body: 'nombre de pronos « score du match » (pas le XI).',
                ),
                _kpiLegendLine(
                  title: 'Matchs joués',
                  body: 'nombre de matchs où au moins un fan a pronostiqué le score.',
                ),
                const SizedBox(height: 16),
                _sectionHeading('DÉTAIL PAR MATCH'),
                const SizedBox(height: 8),
                if (data.upcoming.isEmpty)
                  Text(
                    'Aucun match à venir.',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  )
                else
                  ...data.upcoming.map(_matchCard),
                if (data.live.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionHeading('EN DIRECT'),
                  const SizedBox(height: 8),
                  ...data.live.map(_matchCard),
                ],
                if (data.finished.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionHeading('DERNIERS MATCHS'),
                  const SizedBox(height: 8),
                  ...data.finished.map(_matchCard),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _future = _load());
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Actualiser',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(foregroundColor: accent),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeading(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: adminGrey,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _kpiLegendLine({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$title = ',
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
              ),
            ),
            TextSpan(
              text: body,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.45,
                color: adminGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchCard(_MatchEngagement m) {
    final dateLabel = m.date == null
        ? ''
        : DateFormat('EEEE d MMMM · HH:mm', 'fr_FR').format(m.date!);
    final statusLabel = switch (m.status) {
      'live' => 'LIVE',
      'finished' => 'TERMINÉ',
      _ => 'À VENIR',
    };
    final statusColor = switch (m.status) {
      'live' => adminRed,
      'finished' => adminGrey,
      _ => AdminModuleColors.jeux,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${m.team1}  –  ${m.team2}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: adminTextPrimary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                icon: Icons.sports_soccer_rounded,
                label: m.pronoTotal == 0
                    ? 'Personne n’a pronostiqué'
                    : '${m.pronoTotal} ${m.pronoTotal > 1 ? 'ont' : 'a'} pronostiqué le score',
                color: adminGold,
              ),
              if (m.pronoTotal > 0)
                _chip(
                  icon: Icons.stacked_bar_chart_rounded,
                  label:
                      'Domicile ${m.homeWin}  ·  Nul ${m.draw}  ·  Extérieur ${m.awayWin}',
                  color: adminBlue,
                ),
              if (m.isSedan)
                _chip(
                  icon: Icons.groups_rounded,
                  label: m.xiCount == 0
                      ? 'Personne n’a fait le XI'
                      : '${m.xiCount} ${m.xiCount > 1 ? 'ont' : 'a'} fait le XI',
                  color: AdminModuleColors.jeux,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigNum extends StatelessWidget {
  final String value;
  const _BigNum(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: GoogleFonts.barlowCondensed(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: adminTextPrimary,
        height: 1,
        letterSpacing: -0.3,
      ),
    );
  }
}
