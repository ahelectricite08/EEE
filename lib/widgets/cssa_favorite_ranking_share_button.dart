import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/matches/matches_helpers.dart';
import '../services/dvcr_share_service.dart';
import '../screens/matches/matches_palette.dart';
import '../utils/share_helper.dart';

/// Icône partage : classement Firestore de l’équipe favorite (calendrier + onglet classement matchs).
enum CssaRankingShareStyle {
  /// Bandeau vert calendrier (fond translucide, icône or).
  calendarGreen,

  /// Carte crème onglet Classement.
  matchesCard,
}

class CssaFavoriteRankingShareButton extends StatelessWidget {
  final String season;
  final String? favoriteTeam;
  final String leagueLabel;
  final CssaRankingShareStyle style;

  const CssaFavoriteRankingShareButton({
    super.key,
    required this.season,
    required this.favoriteTeam,
    required this.leagueLabel,
    this.style = CssaRankingShareStyle.matchesCard,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    if (season == '2025-2026') {
      return FirebaseFirestore.instance.collection('ranking').snapshots();
    }
    return FirebaseFirestore.instance
        .collection('ranking')
        .where('season', isEqualTo: season)
        .snapshots();
  }

  Map<String, Object>? _rowForFavorite(QuerySnapshot<Map<String, dynamic>> snap) {
    final ft = favoriteTeam?.trim();
    if (ft == null || ft.isEmpty) return null;
    final docs = snap.docs.where((doc) {
      final data = doc.data();
      final s = data['season'] as String?;
      return s == null || s == season;
    }).toList()
      ..sort((a, b) {
        final ap = (a.data()['position'] as num?)?.toInt() ?? 999;
        final bp = (b.data()['position'] as num?)?.toInt() ?? 999;
        return ap.compareTo(bp);
      });
    for (var i = 0; i < docs.length; i++) {
      final data = docs[i].data();
      final team = (data['team'] as String?) ?? '';
      if (teamMatchesPreference(team, ft)) {
        return {
          'team': team,
          'rank': i + 1,
          'mj': (data['mj'] as num?)?.toInt() ?? 0,
          'v': (data['v'] as num?)?.toInt() ?? 0,
          'n': (data['n'] as num?)?.toInt() ?? 0,
          'd': (data['d'] as num?)?.toInt() ?? 0,
          'bf': (data['bf'] as num?)?.toInt() ?? 0,
          'bc': (data['bc'] as num?)?.toInt() ?? 0,
          'pts': (data['pts'] as num?)?.toInt() ?? 0,
        };
      }
    }
    return null;
  }

  Widget _shell({required VoidCallback onTap, required Widget child}) {
    final green = style == CssaRankingShareStyle.calendarGreen;
    return Material(
      color: green
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: green ? Colors.white24 : kMatchesBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = style == CssaRankingShareStyle.calendarGreen;
    final iconGold = const Color(0xFFC8A436);
    final iconMuted =
        green ? Colors.white.withValues(alpha: 0.85) : kMatchesMuted;

    void noFavoriteSnack() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisis ton équipe favorite dans ton profil pour partager son classement.',
          ),
        ),
      );
    }

    void notInTableSnack() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ton club n’apparaît pas dans ce classement pour l’instant.',
          ),
        ),
      );
    }

    final ft = favoriteTeam;
    if (ft == null || ft.trim().isEmpty) {
      return Tooltip(
        message: 'Partager le classement de mon club',
        child: _shell(
          onTap: noFavoriteSnack,
          child: Icon(Icons.ios_share_rounded, size: 20, color: iconMuted),
        ),
      );
    }

    return Tooltip(
      message: 'Partager le classement de mon club',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return IgnorePointer(
              child: Opacity(
                opacity: 0.45,
                child: _shell(
                  onTap: () {},
                  child: Icon(Icons.ios_share_rounded, size: 20, color: iconMuted),
                ),
              ),
            );
          }
          final row = _rowForFavorite(snap.data!);
          if (row == null) {
            return _shell(
              onTap: notInTableSnack,
              child: Icon(Icons.ios_share_rounded, size: 20, color: iconMuted),
            );
          }
          return _shell(
            onTap: () {
              DvcrShare.share(
                ShareHelper.cssaFavoriteRankingShareText(
                  clubName: row['team']! as String,
                  rank: row['rank']! as int,
                  pts: row['pts']! as int,
                  mj: row['mj']! as int,
                  v: row['v']! as int,
                  n: row['n']! as int,
                  d: row['d']! as int,
                  bf: row['bf']! as int,
                  bc: row['bc']! as int,
                  season: season,
                  leagueLabel: leagueLabel,
                ),
              );
            },
            child: Icon(
              Icons.ios_share_rounded,
              size: 20,
              color: green ? iconGold : kMatchesGreenDeep,
            ),
          );
        },
      ),
    );
  }
}
