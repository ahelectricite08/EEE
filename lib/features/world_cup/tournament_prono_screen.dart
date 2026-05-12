import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/app_settings_service.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/tournament_service.dart';
import '../../widgets/powered_by_partner_encart.dart';
import '../../utils/share_helper.dart';
import '../prono/presentation/history/recent_prono_history_page.dart';
import '../prono/presentation/history/recent_prono_row.dart';

DateTime _effectiveOpensAt(TournamentMatch m) {
  final fallback = m.date.subtract(const Duration(days: 7));
  final o = m.predictionOpensAt;
  if (o == null) return fallback;
  if (o.isAfter(m.date)) return fallback;
  return o;
}

bool _matchStarted(TournamentMatch m) =>
    !DateTime.now().isBefore(m.date) || m.status == 'finished';

bool _tooEarlyForProno(TournamentMatch m) {
  if (m.status == 'finished' || _matchStarted(m)) return false;
  return DateTime.now().isBefore(_effectiveOpensAt(m));
}

bool _canEditProno(TournamentMatch m) =>
    !_matchStarted(m) && !_tooEarlyForProno(m);

/// Écran tournoi (pronos phase à phase) — logique basée sur [TournamentService].
class TournamentPronoScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final bool embedded;

  /// Incrémenté par [WorldCupTab] quand l’utilisateur revient sur l’onglet CdM : réaffiche
  /// l’encart partenaire sans recréer l’écran (évite flash sur le visuel partenaire).
  final int partnerEncartResetToken;

  const TournamentPronoScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.embedded = false,
    this.partnerEncartResetToken = 0,
  });

  @override
  State<TournamentPronoScreen> createState() => _TournamentPronoScreenState();
}

class _TournamentPronoScreenState extends State<TournamentPronoScreen>
    with SingleTickerProviderStateMixin {
  static const _kBg = Color(0xFFF5F2E9);
  static const _kGreen = Color(0xFF0A4438);
  static const _kGold = Color(0xFFC8A436);
  static const _kText = Color(0xFF173C31);

  final _fmt = DateFormat('EEE d MMM · HH:mm', 'fr_FR');
  final _fmtOpens = DateFormat('d MMM', 'fr_FR');

  late final TabController _tabCtrl;

  /// `null` = tous les groupes.
  String? _filterGroupKey;

  /// Masqué pour cette « visite » de l’onglet CdM ; réinitialisé quand
  /// [TournamentPronoScreen.partnerEncartResetToken] change (navigation barre du bas).
  bool _wcPartnerEncartDismissed = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TournamentPronoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partnerEncartResetToken != widget.partnerEncartResetToken) {
      setState(() => _wcPartnerEncartDismissed = false);
    }
  }

  void _dismissWorldCupPartnerEncart() {
    setState(() => _wcPartnerEncartDismissed = true);
  }

  Widget _worldCupMatchesPartnerFooter() {
    // [maintainState] : ne pas démonter l’encart à la fermeture — sinon au retour sur CdM
    // le [StreamBuilder] repart sur [initialData] (defaults) + cache réseau = flash d’image.
    return Visibility(
      visible: !_wcPartnerEncartDismissed,
      maintainState: true,
      maintainSize: false,
      maintainAnimation: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kBg,
          border: Border(
            top: BorderSide(
              color: _kGold.withValues(alpha: 0.35),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topRight,
          children: [
            const PoweredByPartnerEncart(
              slot: PoweredByEncartSlot.worldCup,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.white.withValues(alpha: 0.96),
                elevation: 3,
                shadowColor: _kGreen.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _kGreen.withValues(alpha: 0.45)),
                ),
                child: InkWell(
                  onTap: _dismissWorldCupPartnerEncart,
                  borderRadius: BorderRadius.circular(12),
                  child: Tooltip(
                    message: 'Masquer ce message partenaire',
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 30,
                        color: _kGreen,
                        semanticLabel: 'Fermer',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _editPrediction(TournamentMatch m) async {
    if (!_canEditProno(m)) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connecte-toi pour pronostiquer.')),
        );
      }
      return;
    }
    final existing = await TournamentService.getPrediction(
      widget.tournamentId,
      m.id,
    );
    if (!mounted) return;
    final result = await showDialog<(int, int)?>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF0A4438).withValues(alpha: 0.52),
      builder: (ctx) => _WorldCupScoreDialog(
        match: m,
        initialHome: existing?.score1 ?? 0,
        initialAway: existing?.score2 ?? 0,
      ),
    );
    if (result == null || !mounted) return;
    await TournamentService.savePrediction(
      widget.tournamentId,
      m.id,
      result.$1,
      result.$2,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prono enregistré')),
      );
    }
    setState(() {});
  }

  List<TournamentMatch> _filtered(List<TournamentMatch> all) {
    if (_filterGroupKey == null) return all;
    return all.where((m) => m.groupKey == _filterGroupKey).toList();
  }

  List<String> _distinctGroupKeys(List<TournamentMatch> all) {
    final s = <String>{};
    for (final m in all) {
      if (m.groupKey.isNotEmpty) s.add(m.groupKey);
    }
    final list = s.toList()..sort();
    return list;
  }

  /// Une seule section : matchs à venir / récents d’abord ; **terminés depuis 24 h+** en bas
  /// pour remonter les prochains pronos disponibles.
  List<({String header, List<TournamentMatch> matches})> _groupSections(
    List<TournamentMatch> filtered,
  ) {
    bool staleFinished(TournamentMatch m) {
      if (m.status != 'finished') return false;
      return DateTime.now().isAfter(m.date.add(const Duration(hours: 24)));
    }

    final sorted = [...filtered]..sort((a, b) {
      final sa = staleFinished(a);
      final sb = staleFinished(b);
      if (sa != sb) return sa ? 1 : -1;
      return a.date.compareTo(b.date);
    });
    return [(header: '', matches: sorted)];
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Material(
          color: _kGreen,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: _kGold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'MATCHS'),
              Tab(text: 'CLASSEMENT'),
            ],
          ),
        ),
        if (_tabCtrl.index == 0)
          StreamBuilder<PoweredByPartnerSettings>(
            stream: AppSettingsService.poweredByPartnerStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox.shrink();
              }
              final s = snap.data!;
              if (!s.worldCupPrizeBannerEnabled) {
                return const SizedBox.shrink();
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.14),
                  border: Border(
                    bottom: BorderSide(color: _kGold.withValues(alpha: 0.35)),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_outlined, color: _kGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.effectiveWorldCupPrizeBanner,
                          maxLines: 4,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kText,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
                StreamBuilder<List<TournamentMatch>>(
                  stream: TournamentService.matchesStream(widget.tournamentId),
                  builder: (context, snap) {
                    final all = snap.data ?? [];
                    final waitingEmpty = snap.connectionState ==
                            ConnectionState.waiting &&
                        all.isEmpty;

                    Widget scrollArea() {
                      if (waitingEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (all.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Aucun match pour ce tournoi.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _kText,
                              ),
                            ),
                          ),
                        );
                      }
                      final filtered = _filtered(all);
                      final sections = _groupSections(filtered);
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Aucun match dans ce groupe.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _kText,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        children: [
                          for (final sec in sections) ...[
                            if (sec.header.isNotEmpty &&
                                sec.matches.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                  left: 4,
                                ),
                                child: Text(
                                  sec.header,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _kGreen,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            for (final m in sec.matches) ...[
                              _TournamentMatchCard(
                                match: m,
                                tournamentId: widget.tournamentId,
                                dateFmt: _fmt,
                                opensFmt: _fmtOpens,
                                onPredict: () => _editPrediction(m),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      );
                    }

                    final groupKeys = all.isEmpty
                        ? const <String>[]
                        : _distinctGroupKeys(all);

                    return ColoredBox(
                      color: _kBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (groupKeys.isNotEmpty)
                            _GroupFilterBar(
                              groupKeys: groupKeys,
                              selected: _filterGroupKey,
                              onSelect: (k) {
                                setState(() => _filterGroupKey = k);
                              },
                            ),
                          Expanded(child: scrollArea()),
                          _worldCupMatchesPartnerFooter(),
                        ],
                      ),
                    );
                  },
                ),
                _TournamentLeaderboardTab(
                  tournamentId: widget.tournamentId,
                  tournamentName: widget.tournamentName,
                ),
              ],
            ),
          ),
        ],
    );

    if (widget.embedded) {
      return ColoredBox(color: _kBg, child: body);
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        title: Text(
          widget.tournamentName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: body,
    );
  }
}

/// Classement : top 5 toujours ; puis **6–20** seulement si tu es dans le top 20 ;
/// sinon **fenêtre** autour de ton rang (> 20) via `rank` Firestore.
class _TournamentLeaderboardTab extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;

  const _TournamentLeaderboardTab({
    required this.tournamentId,
    required this.tournamentName,
  });

  static const _kBg = Color(0xFFF5F2E9);
  static const _kGreen = Color(0xFF0A4438);
  static const _kMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<TournamentEntry>>(
      stream: TournamentService.leaderboardTopStream(tournamentId, limit: 20),
      builder: (context, topSnap) {
        return StreamBuilder<List<TournamentEntry>>(
          stream: TournamentService.leaderboardNeighborWindowStream(
            tournamentId,
            maxTop: 20,
            window: 3,
          ),
          builder: (context, neighSnap) {
            return StreamBuilder<int?>(
              stream: TournamentService.myRankStream(tournamentId),
              builder: (context, rankSnap) {
                final top = topSnap.data ?? const <TournamentEntry>[];
                final waitingTop =
                    topSnap.connectionState == ConnectionState.waiting &&
                    top.isEmpty;
                if (waitingTop) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (top.isEmpty) {
                  return _LeaderboardEmptyPreview(
                    tournamentId: tournamentId,
                    tournamentName: tournamentName,
                    uid: uid,
                  );
                }

                final neigh = neighSnap.data ?? const <TournamentEntry>[];
                final myRank = rankSnap.data;
                TournamentEntry? myRow;
                if (uid != null) {
                  for (final e in top) {
                    if (e.uid == uid) {
                      myRow = e;
                      break;
                    }
                  }
                  myRow ??= () {
                    for (final e in neigh) {
                      if (e.uid == uid) return e;
                    }
                    return null;
                  }();
                }
                final inTop20 =
                    uid != null && myRank != null && myRank >= 1 && myRank <= 20;
                final showPeloton620 = inTop20 && top.length > 5;
                final showNeighbor = uid != null &&
                    myRank != null &&
                    myRank > 20 &&
                    neigh.isNotEmpty;
                final secondBlock = showPeloton620 || showNeighbor;

                return ColoredBox(
                  color: _kBg,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    children: [
                      const _LeaderboardTableHeader(),
                      if (uid != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kGreen,
                                side: BorderSide(
                                  color: _kGreen.withValues(alpha: 0.45),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                              ),
                              icon: const Icon(Icons.ios_share_rounded, size: 20),
                              label: Text(
                                'Partager ma place (réseaux)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () {
                                final r = myRank ?? myRow?.rank;
                                final pts = myRow?.points ?? 0;
                                final ex = myRow?.exactScores ?? 0;
                                final name = myRow?.displayName;
                                DvcrShare.share(
                                  ShareHelper.tournamentRankingShareText(
                                    tournamentLabel: tournamentName,
                                    rank: r,
                                    points: pts,
                                    exactScores: ex,
                                    displayName: name,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Raccourci identique sur le bandeau vert « Coupe du monde » en haut.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _kMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      for (var i = 0; i < math.min(5, top.length); i++)
                        _LeaderboardDataRow(
                          entry: top[i],
                          displayRank: top[i].rank ?? i + 1,
                          highlight: i < 3,
                          isMe: uid != null && top[i].uid == uid,
                        ),
                      if (secondBlock) ...[
                        _LeaderboardZoneDivider(
                          label: showNeighbor
                              ? 'Rang $myRank · autour de toi'
                              : '6e – 20e place',
                        ),
                        if (showNeighbor) ...[
                          for (final e in neigh)
                            _LeaderboardDataRow(
                              entry: e,
                              displayRank: e.rank ?? 0,
                              highlight: false,
                              isMe: e.uid == uid,
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Podium fixe + ta tranche autour du rang $myRank : '
                              'pas de défilement sur des milliers de lignes.',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _kMuted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ] else if (showPeloton620) ...[
                          for (var i = 5; i < top.length && i < 20; i++)
                            _LeaderboardDataRow(
                              entry: top[i],
                              displayRank: top[i].rank ?? i + 1,
                              highlight: false,
                              isMe: top[i].uid == uid,
                            ),
                        ],
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            uid == null
                                ? 'Connecte-toi : on te montrera le podium (top 5) '
                                    'puis ta zone dans le classement.'
                                : myRank == null
                                    ? 'Tu n’as pas encore de ligne au classement — '
                                        'un prono sur Matchs te fait apparaître ici.'
                                    : myRank > 20
                                        ? 'Tu es ${myRank}e : on n’affiche que le '
                                            'podium ici ; la fenêtre autour de ton '
                                            'rang apparaîtra dès synchronisation '
                                            'Firestore.'
                                        : 'Tu es dans le top 20, mais moins de six '
                                            'joueurs au classement pour l’instant — '
                                            'le bloc 6–20 s’étendra tout seul.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _kMuted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      if (uid != null) ...[
                        const SizedBox(height: 20),
                        _TournamentRecentPronosBlock(
                          tournamentId: tournamentId,
                          tournamentLabel: tournamentName.toUpperCase(),
                          uid: uid,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Bloc sous le classement : 10 derniers pronos CDM scorés.
class _TournamentRecentPronosBlock extends StatelessWidget {
  final String tournamentId;
  final String tournamentLabel;
  final String uid;

  const _TournamentRecentPronosBlock({
    required this.tournamentId,
    required this.tournamentLabel,
    required this.uid,
  });

  static const _kGreen = Color(0xFF0A4438);
  static const _kMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tes 10 derniers pronos',
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _kGreen,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Exact +3 (+20 XP), bon résultat +1 (+8 XP), raté +0.',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<RecentPronoRow>>(
          key: ValueKey<String>('$tournamentId|$uid'),
          future: TournamentService.recentResolvedTournamentPredictions(
            tournamentId,
            uid,
            limit: 10,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _kGreen,
                    ),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Text(
                'Historique indisponible.',
                style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
              );
            }
            final rows = snap.data ?? const <RecentPronoRow>[];
            if (rows.isEmpty) {
              return Text(
                'Aucun prono terminé pour ce tournoi pour l’instant.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: _kMuted,
                ),
              );
            }
            return Column(
              children: [
                for (final r in rows) ...[
                  RecentPronoHistoryCard(
                    row: r,
                    competitionLabel: tournamentLabel,
                    onTap: null,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LeaderboardTableHeader extends StatelessWidget {
  const _LeaderboardTableHeader();

  static const _muted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'SUPPORTER',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              'PTS',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 56,
            child: Text(
              'EXACTS',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardDataRow extends StatelessWidget {
  final TournamentEntry entry;
  final int displayRank;
  final bool highlight;
  final bool isMe;

  const _LeaderboardDataRow({
    required this.entry,
    required this.displayRank,
    required this.highlight,
    required this.isMe,
  });

  static const _kGreen = Color(0xFF0A4438);
  static const _kGold = Color(0xFFC8A436);
  static const _kText = Color(0xFF173C31);
  static const _kMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: highlight ? _kGold.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? _kGreen.withValues(alpha: 0.55)
              : _kMuted.withValues(alpha: 0.18),
          width: isMe ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$displayRank',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kGreen,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${entry.points}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 56,
            child: Text(
              '${entry.exactScores}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardZoneDivider extends StatelessWidget {
  final String label;

  const _LeaderboardZoneDivider({required this.label});

  static const _kGreen = Color(0xFF0A4438);
  static const _kMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: _kGreen.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _kMuted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: _kGreen.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête colonnes (aperçu classement vide).
class _PreviewLeaderboardHeaderRow extends StatelessWidget {
  const _PreviewLeaderboardHeaderRow();

  static const _green = Color(0xFF0A4438);
  static const _muted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: _green.withValues(alpha: 0.06),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'SUPPORTER',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              'PTS',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 56,
            child: Text(
              'EXACTS',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aperçu du classement avant les premières entrées (noms masqués + démo lointaine).
class _LeaderboardEmptyPreview extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;
  final String? uid;

  const _LeaderboardEmptyPreview({
    required this.tournamentId,
    required this.tournamentName,
    required this.uid,
  });

  static const _bg = Color(0xFFF5F2E9);
  static const _green = Color(0xFF0A4438);
  static const _text = Color(0xFF173C31);
  static const _muted = Color(0xFF5C6560);
  static const _amber = Color(0xFFC4963A);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Text(
            'CLASSEMENT PRONOS',
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _green,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Section dédiée au tournoi : chaque prono compte, ta place '
            'évolue au fil des résultats.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _text.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _amber.withValues(alpha: 0.45)),
              ),
              child: Text(
                'APERÇU FACTICE — tout disparaît au 1er vrai prono',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _green,
                  letterSpacing: 0.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                children: [
                  const _PreviewLeaderboardHeaderRow(),
                  for (var rank = 1; rank <= 5; rank++)
                    _PreviewRankRow(rank: rank, podium: rank <= 3),
                  const _LeaderboardZoneDivider(label: '6e – 20e place'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Text(
                      'Ce bloc (places 6 à 20) ne s’affiche que si ton rang est '
                      'dans le top 20. Sinon tu ne vois que le podium ci-dessus, '
                      'puis ta fenêtre personnelle (exemple ci-dessous).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Au-delà du 20e rang : pas de liste interminable — une petite '
            'fenêtre autour de ta vraie place.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _text.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _green.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Text(
                      'Exemple si tu es vers la 1 000e place (fictif)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const _PreviewLeaderboardHeaderRow(),
                  const _LeaderboardZoneDivider(label: 'Rang 1247 · autour de toi'),
                  for (final rank in [1244, 1245, 1246, 1247, 1248, 1249, 1250])
                    _PreviewRankRow(
                      rank: rank,
                      podium: false,
                      isDemoMe: rank == 1247,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun classement pour l’instant — dès qu’un prono est enregistré, '
            'ces grisages laissent place aux vrais pseudos et points.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: _muted,
              height: 1.35,
            ),
          ),
          if (uid != null && uid!.isNotEmpty) ...[
            const SizedBox(height: 28),
            _TournamentRecentPronosBlock(
              tournamentId: tournamentId,
              tournamentLabel: tournamentName.toUpperCase(),
              uid: uid!,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewRankRow extends StatelessWidget {
  final int rank;
  final bool podium;
  final bool isDemoMe;

  const _PreviewRankRow({
    required this.rank,
    required this.podium,
    this.isDemoMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = podium
        ? const Color(0xFFC8A436).withValues(alpha: 0.14)
        : (rank.isEven ? Colors.white : _LeaderboardEmptyPreview._bg);
    final inner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _LeaderboardEmptyPreview._green,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: _LeaderboardEmptyPreview._muted.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isDemoMe ? '···· ··· (ex. toi)' : '············',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: isDemoMe ? 0.4 : 1.2,
                      color: isDemoMe
                          ? _LeaderboardEmptyPreview._green.withValues(alpha: 0.75)
                          : _LeaderboardEmptyPreview._muted.withValues(
                              alpha: 0.35,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '—',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _LeaderboardEmptyPreview._muted.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 56,
            child: Text(
              '—',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _LeaderboardEmptyPreview._muted.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
    if (!isDemoMe) return inner;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _LeaderboardEmptyPreview._green.withValues(alpha: 0.52),
            width: 1.5,
          ),
        ),
        child: inner,
      ),
    );
  }
}

class _GroupFilterBar extends StatelessWidget {
  final List<String> groupKeys;
  final String? selected;
  final void Function(String?) onSelect;

  const _GroupFilterBar({
    required this.groupKeys,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          _Chip(
            label: 'TOUS',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          ...groupKeys.map(
            (g) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: 'Gr. $g',
                selected: selected == g,
                onTap: () => onSelect(g),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _kGreen = Color(0xFF0A4438);
  static const _kGold = Color(0xFFC8A436);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _kGold : _kGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _kGold : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.black : Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentMatchCard extends StatelessWidget {
  final TournamentMatch match;
  final String tournamentId;
  final DateFormat dateFmt;
  final DateFormat opensFmt;
  final VoidCallback onPredict;

  const _TournamentMatchCard({
    required this.match,
    required this.tournamentId,
    required this.dateFmt,
    required this.opensFmt,
    required this.onPredict,
  });

  static const _kGreen = Color(0xFF0A4438);
  static const _kCard = Color(0xFFFFFFFF);
  static const _kBorder = Color(0xFFD8D2C4);
  static const _kMuted = Color(0xFF5C6560);

  void _onCardTap(BuildContext context) {
    if (_tooEarlyForProno(match)) {
      final o = _effectiveOpensAt(match);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Les pronos ouvrent le ${opensFmt.format(o)}.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return;
    }
    if (_matchStarted(match)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            match.status == 'finished'
                ? 'Match terminé.'
                : 'Le coup d\'envoi est passé, prono fermé.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return;
    }
    onPredict();
  }

  @override
  Widget build(BuildContext context) {
    final opens = _effectiveOpensAt(match);
    final tooEarly = _tooEarlyForProno(match);
    final started = _matchStarted(match);
    final finished = match.status == 'finished';

    return Material(
      color: _kCard,
      elevation: 0,
      shadowColor: _kGreen.withAlpha(40),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _onCardTap(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withAlpha(14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateFmt.format(match.date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                      ),
                    ),
                  ),
                  if (match.phase.isNotEmpty)
                    Flexible(
                      child: Text(
                        match.phase.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kGreen.withAlpha(160),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _TeamRow(
                      flag: match.flag1,
                      name: match.team1,
                      alignEnd: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: StreamBuilder<TournamentPrediction?>(
                      stream: TournamentService.predictionStream(
                        tournamentId,
                        match.id,
                      ),
                      builder: (context, predSnap) {
                        final pred = predSnap.data;
                        if (finished &&
                            match.result1 != null &&
                            match.result2 != null) {
                          return _ScorePill(
                            text: '${match.result1} – ${match.result2}',
                            highlight: true,
                          );
                        }
                        if (started && !finished) {
                          return _ScorePill(
                            text: match.result1 != null &&
                                    match.result2 != null
                                ? '${match.result1} – ${match.result2}'
                                : '—',
                            highlight: false,
                          );
                        }
                        if (tooEarly) {
                          return _LockPill(
                            label:
                                'Dispo le ${opensFmt.format(opens)}',
                          );
                        }
                        if (pred != null) {
                          return _ScorePill(
                            text: '${pred.score1} – ${pred.score2}',
                            highlight: true,
                          );
                        }
                        return const _VsPill();
                      },
                    ),
                  ),
                  Expanded(
                    child: _TeamRow(
                      flag: match.flag2,
                      name: match.team2,
                      alignEnd: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String flag;
  final String name;
  final bool alignEnd;

  const _TeamRow({
    required this.flag,
    required this.name,
    required this.alignEnd,
  });

  static const _kText = Color(0xFF173C31);

  @override
  Widget build(BuildContext context) {
    final label = Text(
      name.toUpperCase(),
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: _kText,
        height: 1.2,
      ),
    );
    if (alignEnd) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(child: label),
          const SizedBox(width: 8),
          _FlagAvatar(flag: flag, teamName: name),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _FlagAvatar(flag: flag, teamName: name),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
  }
}

class _FlagAvatar extends StatelessWidget {
  final String flag;
  final String teamName;

  const _FlagAvatar({required this.flag, required this.teamName});

  static const _kBorder = Color(0xFFD8D2C4);

  @override
  Widget build(BuildContext context) {
    final t = flag.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          t,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _letterFallback(),
        ),
      );
    }
    if (t.isNotEmpty) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder),
          color: const Color(0xFFF8F6F0),
        ),
        child: Text(
          t,
          style: const TextStyle(fontSize: 20),
        ),
      );
    }
    return _letterFallback();
  }

  Widget _letterFallback() {
    final letter = teamName.isNotEmpty
        ? teamName.characters.first.toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF0A4438).withAlpha(26),
      child: Text(
        letter,
        style: GoogleFonts.barlowCondensed(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0A4438),
        ),
      ),
    );
  }
}

class _VsPill extends StatelessWidget {
  const _VsPill();

  static const _kMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        'VS',
        style: GoogleFonts.barlowCondensed(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: _kMuted,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String text;
  final bool highlight;

  const _ScorePill({required this.text, required this.highlight});

  static const _kGreen = Color(0xFF0A4438);
  static const _kGold = Color(0xFFC8A436);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? _kGold.withAlpha(28) : const Color(0xFFF0EDE4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? _kGold.withAlpha(120) : _kGreen.withAlpha(40),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.barlowCondensed(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: highlight ? _kGold : _kGreen,
        ),
      ),
    );
  }
}

class _LockPill extends StatelessWidget {
  final String label;

  const _LockPill({required this.label});

  static const _kMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFECEAE4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: _kMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modale prono CdM : drapeaux + noms d’équipes, scores en grand, ± (plus de « Score 1 / 2 »).
class _WorldCupScoreDialog extends StatefulWidget {
  final TournamentMatch match;
  final int initialHome;
  final int initialAway;

  const _WorldCupScoreDialog({
    required this.match,
    required this.initialHome,
    required this.initialAway,
  });

  @override
  State<_WorldCupScoreDialog> createState() => _WorldCupScoreDialogState();
}

class _WorldCupScoreDialogState extends State<_WorldCupScoreDialog> {
  static const _kGreen = Color(0xFF0A4438);
  static const _kGold = Color(0xFFC8A436);
  static const _kBg = Color(0xFFF5F2E9);
  static const _kMuted = Color(0xFF5C6560);

  late final TextEditingController _homeCtrl;
  late final TextEditingController _awayCtrl;

  @override
  void initState() {
    super.initState();
    _homeCtrl = TextEditingController(text: '${widget.initialHome}');
    _awayCtrl = TextEditingController(text: '${widget.initialAway}');
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  int _parse(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    if (v == null) return 0;
    return v.clamp(0, 20);
  }

  void _nudge(TextEditingController c, int delta) {
    final next = (_parse(c) + delta).clamp(0, 20);
    c.text = '$next';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _kGold.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'TON PRONO',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: _kGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (m.phase.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      m.phase.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _kMuted,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _WcScoreColumn(
                        flag: m.flag1,
                        teamName: m.team1,
                        controller: _homeCtrl,
                        alignEnd: true,
                        onMinus: () => _nudge(_homeCtrl, -1),
                        onPlus: () => _nudge(_homeCtrl, 1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 40, 4, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EDE4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _kGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'VS',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _kMuted,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _WcScoreColumn(
                        flag: m.flag2,
                        teamName: m.team2,
                        controller: _awayCtrl,
                        alignEnd: false,
                        onMinus: () => _nudge(_awayCtrl, -1),
                        onPlus: () => _nudge(_awayCtrl, 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '0 à 20 buts · tape ou utilise + / −',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop<(int, int)?>(context, null),
                        style: TextButton.styleFrom(
                          foregroundColor: _kMuted,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop<(int, int)?>(
                            context,
                            (_parse(_homeCtrl), _parse(_awayCtrl)),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Enregistrer',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WcScoreColumn extends StatelessWidget {
  final String flag;
  final String teamName;
  final TextEditingController controller;
  final bool alignEnd;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _WcScoreColumn({
    required this.flag,
    required this.teamName,
    required this.controller,
    required this.alignEnd,
    required this.onMinus,
    required this.onPlus,
  });

  static const _kText = Color(0xFF173C31);

  @override
  Widget build(BuildContext context) {
    final nameBlock = Text(
      teamName.toUpperCase(),
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: _kText,
        height: 1.2,
        letterSpacing: 0.2,
      ),
    );
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignEnd) ...[
              _FlagAvatar(flag: flag, teamName: teamName),
              const SizedBox(width: 8),
              Flexible(child: nameBlock),
            ] else ...[
              Flexible(child: nameBlock),
              const SizedBox(width: 8),
              _FlagAvatar(flag: flag, teamName: teamName),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WcRoundIconBtn(icon: Icons.remove_rounded, onTap: onMinus),
                const SizedBox(width: 4),
                _WcScoreDigitField(controller: controller),
                const SizedBox(width: 4),
                _WcRoundIconBtn(icon: Icons.add_rounded, onTap: onPlus),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WcRoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WcRoundIconBtn({required this.icon, required this.onTap});

  static const _kGreen = Color(0xFF0A4438);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 20, color: _kGreen),
        ),
      ),
    );
  }
}

class _WcScoreDigitField extends StatelessWidget {
  final TextEditingController controller;

  const _WcScoreDigitField({required this.controller});

  static const _kGreen = Color(0xFF0A4438);
  static const _kGold = Color(0xFFC8A436);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kGold.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.barlowCondensed(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: _kGreen,
            height: 1.0,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            counterText: '',
          ),
        ),
      ),
    );
  }
}
