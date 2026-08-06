import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../navigation/main_shell_insets.dart';
import '../../models/fff_season_config.dart';
import '../../services/season_config_service.dart';
import '../../services/user_preferences_service.dart';
import '../../widgets/cssa_favorite_ranking_share_button.dart';
import 'matches_helpers.dart';
import 'matches_palette.dart';

class MatchesRankingTab extends StatefulWidget {
  const MatchesRankingTab({super.key});

  @override
  State<MatchesRankingTab> createState() => _MatchesRankingTabState();
}

class _MatchesRankingTabState extends State<MatchesRankingTab> {
  String _season = FffSeasonConfig.defaults.seasonLabel;
  String? _favoriteTeam;

  /// Logos absents du doc `ranking` → récupérés sur les derniers matchs (logo1 / logo2).
  final Map<String, String> _matchLogoByTeam = {};
  String _lastHydrateKey = '';

  @override
  void initState() {
    super.initState();
    _favoriteTeam = UserPreferencesService.instance.favoriteTeam;
    UserPreferencesService.instance.addListener(_handleFavoriteTeamChanged);
    unawaited(UserPreferencesService.instance.init());
  }

  @override
  void dispose() {
    UserPreferencesService.instance.removeListener(_handleFavoriteTeamChanged);
    super.dispose();
  }

  void _handleFavoriteTeamChanged() {
    final next = UserPreferencesService.instance.favoriteTeam;
    if (!mounted || _favoriteTeam == next) {
      return;
    }
    setState(() => _favoriteTeam = next);
  }

  void _scheduleLogoHydration(String seasonKey, List<_RankEntry> entries) {
    if (entries.isEmpty) return;
    final needs = entries.where((e) => (e.logo ?? '').trim().isEmpty).toList();
    if (needs.isEmpty) return;

    final key = '$seasonKey|${entries.map((e) => e.team).join('\u0001')}';
    if (key == _lastHydrateKey) return;
    _lastHydrateKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_hydrateLogosFromMatches(needs.map((e) => e.team).toSet()));
    });
  }

  Future<void> _hydrateLogosFromMatches(Set<String> teamsNeeding) async {
    if (teamsNeeding.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .orderBy('date', descending: true)
          .limit(160)
          .get();

      final byExact = <String, String>{};
      final byNorm = <String, String>{};

      void put(String team, String? logo) {
        final t = team.trim();
        final u = logo?.trim();
        if (t.isEmpty || u == null || u.isEmpty) return;
        byExact.putIfAbsent(t, () => u);
        byNorm.putIfAbsent(normalizeTeamLabel(t), () => u);
      }

      for (final doc in snap.docs) {
        final d = doc.data();
        put((d['team1'] as String?) ?? '', d['logo1'] as String?);
        put((d['team2'] as String?) ?? '', d['logo2'] as String?);
      }

      String? pickLogo(String rankingTeam) {
        final t = rankingTeam.trim();
        if (t.isEmpty) return null;
        final direct = byExact[t] ?? byNorm[normalizeTeamLabel(t)];
        if (direct != null) return direct;
        for (final e in byExact.entries) {
          if (teamMatchesPreference(t, e.key) ||
              teamMatchesPreference(e.key, t)) {
            return e.value;
          }
        }
        return null;
      }

      var changed = false;
      final next = Map<String, String>.from(_matchLogoByTeam);
      for (final team in teamsNeeding) {
        final url = pickLogo(team);
        if (url != null && next[team] != url) {
          next[team] = url;
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {
          _matchLogoByTeam
            ..clear()
            ..addAll(next);
        });
      }
    } catch (_) {
      // Pas d’index / réseau : rester sur initiales + logo ranking si présent
    }
  }

  String? _resolvedLogo(_RankEntry e) {
    final fromRanking = e.logo?.trim();
    if (fromRanking != null && fromRanking.isNotEmpty) return fromRanking;
    final cached = _matchLogoByTeam[e.team.trim()];
    if (cached != null && cached.isNotEmpty) return cached;
    for (final o in _matchLogoByTeam.entries) {
      if (teamMatchesPreference(e.team, o.key) ||
          teamMatchesPreference(o.key, e.team)) {
        return o.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FffSeasonConfig>(
      stream: SeasonConfigService.stream(),
      builder: (context, fffSnap) {
        final cfg = fffSnap.data ?? FffSeasonConfig.defaults;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('ranking_archive').snapshots(),
          builder: (context, archSnap) {
            final archived =
                archSnap.data?.docs.map((d) => d.id).toList() ?? <String>[];
            archived.sort();
            final chips = <String>[
              cfg.seasonLabel,
              ...archived.where((id) => id != cfg.seasonLabel),
            ];
            final displaySeason =
                chips.contains(_season) ? _season : cfg.seasonLabel;
            if (!chips.contains(_season)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _season = cfg.seasonLabel;
                  _lastHydrateKey = '';
                });
              });
            }
            final leagueHdr = displaySeason == cfg.seasonLabel
                ? cfg.competitionDisplayName
                : _leagueLabelFromArchive(archSnap, displaySeason);

            Widget rankingBody() {
              if (displaySeason == cfg.seasonLabel) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('ranking')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final entries = _entriesFromLiveRanking(
                      snapshot,
                      displaySeason,
                      cfg.seasonLabel,
                    );
                    return _buildRankingList(displaySeason, entries);
                  },
                );
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ranking_archive')
                    .doc(displaySeason)
                    .snapshots(),
                builder: (context, docSnap) {
                  final entries = _entriesFromArchiveDoc(docSnap);
                  return _buildRankingList(displaySeason, entries);
                },
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: _RankingClassementHeader(
                    season: displaySeason,
                    seasonChips: chips,
                    leagueLabel: leagueHdr,
                    favoriteTeam: _favoriteTeam,
                    onSeasonSelected: (s) => setState(() {
                      _season = s;
                      _lastHydrateKey = '';
                    }),
                  ),
                ),
                Expanded(child: rankingBody()),
              ],
            );
          },
        );
      },
    );
  }

  String _leagueLabelFromArchive(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> archSnap,
    String displaySeason,
  ) {
    for (final d in archSnap.data?.docs ?? const []) {
      if (d.id != displaySeason) continue;
      final ll = d.data()['leagueLabel'] as String?;
      if (ll != null && ll.trim().isNotEmpty) return ll.trim();
      break;
    }
    return 'Classement archivé · $displaySeason';
  }

  Widget _buildRankingList(String seasonKey, List<_RankEntry> entries) {
    _scheduleLogoHydration(seasonKey, entries);

    final favoriteEntry = _favoriteTeam == null
        ? null
        : entries.cast<_RankEntry?>().firstWhere(
              (entry) =>
                  teamMatchesPreference(entry!.team, _favoriteTeam),
              orElse: () => null,
            );

    if (entries.isEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          14,
          8,
          14,
          MainShellInsets.tabScrollTail(context, extra: 8),
        ),
        children: [
          _RankingEmptyCard(season: seasonKey),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        MainShellInsets.tabScrollTail(context, extra: 8),
      ),
      children: [
        if (favoriteEntry != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FavoriteRankingSpotlight(
              entry: favoriteEntry,
              favoriteTeam: _favoriteTeam!,
              resolvedLogo: _resolvedLogo(favoriteEntry),
            ),
          ),
        const _RankingColumnHeader(),
        const SizedBox(height: 10),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RankingCard(
              entry: entry,
              position: index + 1,
              favoriteTeam: _favoriteTeam,
              resolvedLogo: _resolvedLogo(entry),
            ),
          );
        }),
      ],
    );
  }

  List<_RankEntry> _entriesFromLiveRanking(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    String seasonKey,
    String activeSeasonLabel,
  ) {
    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
      final docs =
          snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final season = data['season'] as String?;
            return season == null || season == seasonKey;
          }).toList()
            ..sort((a, b) {
              final aPos = (a.data()['position'] as int?) ?? 999;
              final bPos = (b.data()['position'] as int?) ?? 999;
              return aPos.compareTo(bPos);
            });

      return docs.map((doc) {
        final data = doc.data();
        return _RankEntry(
          '${data['position'] ?? 0}',
          data['team'] as String? ?? '',
          data['logo'] as String?,
          data['mj'] as int? ?? 0,
          data['v'] as int? ?? 0,
          data['n'] as int? ?? 0,
          data['d'] as int? ?? 0,
          data['bf'] as int? ?? 0,
          data['bc'] as int? ?? 0,
          data['pts'] as int? ?? 0,
        );
      }).toList();
    }

    return [];
  }

  List<_RankEntry> _entriesFromArchiveDoc(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
  ) {
    final d = snap.data?.data();
    if (d == null) return [];
    final raw = d['rows'];
    if (raw is! List) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _RankEntry(
        '${m['position'] ?? 0}',
        m['team'] as String? ?? '',
        m['logo'] as String?,
        (m['mj'] as num?)?.toInt() ?? 0,
        (m['v'] as num?)?.toInt() ?? 0,
        (m['n'] as num?)?.toInt() ?? 0,
        (m['d'] as num?)?.toInt() ?? 0,
        (m['bf'] as num?)?.toInt() ?? 0,
        (m['bc'] as num?)?.toInt() ?? 0,
        (m['pts'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}

/// Saison + titre dans une seule carte (moins « blocs empilés »), puces avec [Material] pour un fond lisible.
class _RankingClassementHeader extends StatelessWidget {
  final String season;
  final List<String> seasonChips;
  final String leagueLabel;
  final String? favoriteTeam;
  final ValueChanged<String> onSeasonSelected;

  const _RankingClassementHeader({
    required this.season,
    required this.seasonChips,
    required this.leagueLabel,
    required this.favoriteTeam,
    required this.onSeasonSelected,
  });

  static const _unselectedChipFill = Color(0xFFE8E4DC);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kMatchesGreenDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMatchesGold.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titre + partage ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: kMatchesGold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLASSEMENT',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: kMatchesGold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        leagueLabel,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                CssaFavoriteRankingShareButton(
                  season: season,
                  favoriteTeam: favoriteTeam,
                  leagueLabel: leagueLabel,
                  style: CssaRankingShareStyle.matchesCard,
                ),
              ],
            ),
          ),

          // ── Chips saisons ───────────────────────────────────────────────
          if (seasonChips.length > 1) ...[
            Container(
              height: 1,
              color: Colors.white.withAlpha(18),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: seasonChips.map((s) {
                    final selected = s == season;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => onSeasonSelected(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? kMatchesGold
                                : Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.black
                                  : Colors.white.withAlpha(180),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RankingColumnHeader extends StatelessWidget {
  const _RankingColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 32), // position
          const SizedBox(width: 36), // logo
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'CLUB',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: kMatchesMuted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          _colLabel('MJ'),
          _colLabel('V'),
          _colLabel('N'),
          _colLabel('D'),
          _colLabel('Diff'),
          _colLabel('PTS', isLast: true, accent: true),
        ],
      ),
    );
  }

  Widget _colLabel(String t, {bool isLast = false, bool accent = false}) {
    return SizedBox(
      width: isLast ? 38 : 28,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accent ? kMatchesGreen : kMatchesMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _RankingEmptyCard extends StatelessWidget {
  final String season;

  const _RankingEmptyCard({required this.season});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      decoration: BoxDecoration(
        color: kMatchesCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kMatchesBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 40,
            color: kMatchesGreen.withAlpha(180),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun classement pour $season',
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kMatchesText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les données seront affichées dès synchronisation Firestore.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: kMatchesMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

Color? _podiumAccent(int position) {
  switch (position) {
    case 1:
      return const Color(0xFFD4AF37);
    case 2:
      return const Color(0xFFB0B8C1);
    case 3:
      return const Color(0xFFC98A4A);
    default:
      return null;
  }
}

class _RankingCard extends StatelessWidget {
  final _RankEntry entry;
  final int position;
  final String? favoriteTeam;
  final String? resolvedLogo;

  const _RankingCard({
    required this.entry,
    required this.position,
    required this.resolvedLogo,
    this.favoriteTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorite = teamMatchesPreference(entry.team, favoriteTeam);
    final isSedan = isSedanTeam(entry.team);
    final isHighlighted = isFavorite || (favoriteTeam == null && isSedan);
    final diff = entry.bf - entry.bc;
    final podium = _podiumAccent(position);

    // Couleurs selon état
    final rowBg = isHighlighted
        ? (isFavorite ? const Color(0xFFFFFBF0) : const Color(0xFFF2FAF6))
        : Colors.white;
    final leftAccent = podium ?? (isHighlighted ? kMatchesGold : Colors.transparent);
    final teamNameColor = isHighlighted ? kMatchesGreenDeep : kMatchesText;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? (isFavorite ? kMatchesGold.withAlpha(120) : kMatchesGreen.withAlpha(80))
              : kMatchesBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Bande couleur gauche (podium ou highlight)
              Container(
                width: 3,
                color: leftAccent,
              ),
              // Position
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '$position',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: podium ?? kMatchesMuted,
                      height: 1,
                    ),
                  ),
                ),
              ),
              // Logo
              _RankingTeamLogo(
                team: entry.team,
                resolvedUrl: resolvedLogo,
                highlighted: isHighlighted,
                size: 34,
                borderRadius: 8,
              ),
              const SizedBox(width: 10),
              // Nom équipe
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    entry.team,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                      color: teamNameColor,
                    ),
                  ),
                ),
              ),
              // Stats : MJ V N D Diff PTS
              _statCell('${entry.mj}'),
              _statCell('${entry.v}', color: entry.v > 0 ? const Color(0xFF2E7D32) : null),
              _statCell('${entry.n}'),
              _statCell('${entry.d}', color: entry.d > 0 ? const Color(0xFFC62828) : null),
              _statCell(
                '${diff > 0 ? '+' : ''}$diff',
                color: _diffColor(diff),
              ),
              // Points
              Container(
                width: 38,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isHighlighted ? kMatchesGreenDeep : kMatchesIvory,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entry.pts}',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isHighlighted ? Colors.white : kMatchesText,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCell(String value, {Color? color}) {
    return SizedBox(
      width: 28,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color ?? kMatchesMuted,
        ),
      ),
    );
  }
}

Color _diffColor(int diff) {
  if (diff > 0) return const Color(0xFF2E7D32);
  if (diff < 0) return const Color(0xFFC62828);
  return kMatchesMuted;
}

class _FavoriteRankingSpotlight extends StatelessWidget {
  final _RankEntry entry;
  final String favoriteTeam;
  final String? resolvedLogo;

  const _FavoriteRankingSpotlight({
    required this.entry,
    required this.favoriteTeam,
    required this.resolvedLogo,
  });

  @override
  Widget build(BuildContext context) {
    final diff = entry.bf - entry.bc;
    final pos = int.tryParse(entry.pos) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D34), kMatchesGreenDeep],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMatchesGold.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: kMatchesGreen.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _RankingTeamLogo(
                  team: entry.team,
                  resolvedUrl: resolvedLogo,
                  highlighted: true,
                  size: 42,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MON ÉQUIPE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: kMatchesGold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        favoriteTeam,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Position badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: pos <= 3 ? kMatchesGold : Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        pos > 0 ? '${entry.pos}e' : '—',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: pos <= 3 ? Colors.black : Colors.white,
                          height: 1,
                        ),
                      ),
                      Text(
                        '${entry.pts} pts',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: pos <= 3
                              ? Colors.black.withAlpha(180)
                              : Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Ligne stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(40),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _spotStat('${entry.mj}', 'matchs'),
                _vDivider(),
                _spotStat('${entry.v}', 'victoires'),
                _vDivider(),
                _spotStat('${entry.n}', 'nuls'),
                _vDivider(),
                _spotStat('${entry.d}', 'défaites'),
                _vDivider(),
                _spotStat(
                  '${diff > 0 ? '+' : ''}$diff',
                  'diff.',
                  color: _diffColor(diff),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _spotStat(String value, String label, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color ?? Colors.white,
            height: 1,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: Colors.white.withAlpha(160),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withAlpha(30),
      );

}

class _RankEntry {
  final String pos;
  final String team;
  final String? logo;
  final int mj;
  final int v;
  final int n;
  final int d;
  final int bf;
  final int bc;
  final int pts;

  const _RankEntry(
    this.pos,
    this.team,
    this.logo,
    this.mj,
    this.v,
    this.n,
    this.d,
    this.bf,
    this.bc,
    this.pts,
  );
}

class _RankingTeamLogo extends StatelessWidget {
  final String team;
  final String? resolvedUrl;
  final bool highlighted;
  final double size;
  final double borderRadius;

  const _RankingTeamLogo({
    required this.team,
    required this.resolvedUrl,
    required this.highlighted,
    this.size = 42,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolvedUrl?.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : kMatchesIvory,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: highlighted
              ? Colors.white.withAlpha(140)
              : kMatchesBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kMatchesGreen.withAlpha(160),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) =>
                    _RankingLogoFallback(team: team, highlighted: highlighted),
              ),
            )
          : _RankingLogoFallback(team: team, highlighted: highlighted),
    );
  }
}

class _RankingLogoFallback extends StatelessWidget {
  final String team;
  final bool highlighted;

  const _RankingLogoFallback({required this.team, required this.highlighted});

  static Color _tintForTeam(String name) {
    final h = name.hashCode.abs();
    const colors = [
      Color(0xFF0A4438),
      Color(0xFF1E6B56),
      Color(0xFF2A4E7C),
      Color(0xFF5C3D6E),
      Color(0xFF6D4C41),
    ];
    return colors[h % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? kMatchesGreen.withAlpha(40)
        : _tintForTeam(team).withAlpha(36);
    return ColoredBox(
      color: bg,
      child: Center(
        child: Text(
          teamInitials(team),
          style: GoogleFonts.inter(
            fontSize: (team.length > 18) ? 10 : 12,
            fontWeight: FontWeight.w900,
            color: highlighted ? kMatchesGreenDeep : Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
