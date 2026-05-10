import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/tournament_service.dart';
import '../../utils/share_helper.dart';
import '../tournament_prono_screen.dart';

class WorldCupTab extends StatelessWidget {
  /// [MainNavigation] l’incrémente à chaque focus CdM pour réafficher l’encart partenaire
  /// sans détruire l’arbre (cache visuel / stream partenaire).
  final int partnerEncartResetToken;

  const WorldCupTab({super.key, this.partnerEncartResetToken = 0});

  @override
  Widget build(BuildContext context) {
    Widget embeddedForDoc(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String? ?? 'Tournoi';
      return _WorldCupEmbedded(
        tournamentId: doc.id,
        tournamentName: name,
        partnerEncartResetToken: partnerEncartResetToken,
      );
    }

    /// 1) Tournoi avec `active == true` (rempli par syncWorldCupFixtures, id. worldcup2026).
    /// 2) Sinon un seul doc `tournaments`, ordre d’id déterministe (évite `docs.first` aléatoire).
    return StreamBuilder<QuerySnapshot>(
      stream: TournamentService.activeTournamentsStream(),
      builder: (context, activeSnap) {
        final activeDocs = activeSnap.data?.docs ?? [];
        if (activeDocs.isNotEmpty) {
          return embeddedForDoc(activeDocs.first);
        }
        final waitingActive =
            activeSnap.connectionState == ConnectionState.waiting &&
                !activeSnap.hasData;
        if (waitingActive) {
          return const ColoredBox(
            color: Color(0xFFF5F2E9),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .orderBy(FieldPath.documentId)
              .limit(1)
              .snapshots(),
          builder: (context, legacySnap) {
            final legacyDocs = legacySnap.data?.docs ?? [];
            if (legacyDocs.isEmpty) {
              return const _ComingSoonScreen();
            }
            return embeddedForDoc(legacyDocs.first);
          },
        );
      },
    );
  }
}

// ── Écran principal avec hero + contenu embarqué ──────────────────────────────
class _WorldCupEmbedded extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;
  final int partnerEncartResetToken;

  const _WorldCupEmbedded({
    required this.tournamentId,
    required this.tournamentName,
    required this.partnerEncartResetToken,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2E9),
      body: Column(
        children: [
          _WorldCupHero(
            topPad: topPad,
            tournamentId: tournamentId,
            tournamentName: tournamentName,
          ),
          Expanded(
            child: TournamentPronoScreen(
              tournamentId: tournamentId,
              tournamentName: tournamentName,
              embedded: true,
              partnerEncartResetToken: partnerEncartResetToken,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────
class _WorldCupHero extends StatelessWidget {
  final double topPad;
  /// Si renseignés : icône partage en haut à droite du bandeau (onglet Coupe du monde).
  final String? tournamentId;
  final String? tournamentName;

  const _WorldCupHero({
    required this.topPad,
    this.tournamentId,
    this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF062921),
            Color(0xFF0A4438),
            Color(0xFF0A4438),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: topPad - 10,
            child: Opacity(
              opacity: 0.07,
              child: Icon(Icons.public_rounded, size: 200, color: Colors.white),
            ),
          ),
          if (tournamentId != null &&
              tournamentName != null &&
              tournamentId!.isNotEmpty)
            Positioned(
              top: topPad + 10,
              right: 10,
              child: _WorldCupHeroShareCorner(
                tournamentId: tournamentId!,
                tournamentName: tournamentName!,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              topPad + 20,
              tournamentId != null &&
                      tournamentName != null &&
                      tournamentId!.isNotEmpty
                  ? 52
                  : 20,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8A436),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PRONOS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'USA · MEX · CAN 2026',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'COUPE DU\nMONDE 2026',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 0.9,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pronostique les matchs, grimpe au classement.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sports_soccer_rounded,
                      color: Color(0xFFC8A436),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le 1er du classement remporte un ballon officiel '
                        'de la Coupe du Monde 2026.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icône partage discrète, coin haut droit du bandeau CdM.
class _WorldCupHeroShareCorner extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;

  const _WorldCupHeroShareCorner({
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Tooltip(
        message: 'Partager mon classement',
        child: Material(
          color: Colors.white.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Connecte-toi pour partager ta place au classement.',
                  ),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.ios_share_rounded,
                size: 20,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<int?>(
      stream: TournamentService.myRankStream(tournamentId),
      builder: (context, rankSnap) {
        return StreamBuilder<TournamentEntry?>(
          stream: TournamentService.myLeaderboardEntryStream(tournamentId),
          builder: (context, entrySnap) {
            final rank = rankSnap.data;
            final entry = entrySnap.data;
            return Tooltip(
              message: 'Partager mon classement',
              child: Material(
                color: Colors.white.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    final r = rank ?? entry?.rank;
                    final pts = entry?.points ?? 0;
                    final ex = entry?.exactScores ?? 0;
                    final name = entry?.displayName;
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
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: Color(0xFFC8A436),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Écran si aucun tournoi ─────────────────────────────────────────────────────
class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2E9),
      body: Column(
        children: [
          _WorldCupHero(topPad: topPad),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A4438).withAlpha(30),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0A4438).withAlpha(60),
                        ),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        size: 38,
                        color: Color(0xFF0A4438),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'BIENTÔT DISPONIBLE',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A4438),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le tirage au sort et les matchs\narriveront prochainement.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Color(0xFF5C6560),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
