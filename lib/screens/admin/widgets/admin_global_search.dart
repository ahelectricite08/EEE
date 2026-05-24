import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_controller.dart';
import '../admin_nav_model.dart';
import '../admin_navigation.dart';
import '../admin_palette.dart';

/// Recherche globale : matchs, membres, articles.
class AdminGlobalSearchDelegate extends SearchDelegate<void> {
  AdminGlobalSearchDelegate();

  @override
  String get searchFieldLabel => 'Match, membre, article…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: adminBg,
        foregroundColor: adminTextPrimary,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: adminGrey),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _Results(query: query);

  @override
  Widget buildSuggestions(BuildContext context) => _Results(query: query);
}

class _Results extends StatelessWidget {
  final String query;
  const _Results({required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      return Center(
        child: Text(
          'Tape au moins 2 caractères',
          style: GoogleFonts.inter(color: adminGrey, fontSize: 13),
        ),
      );
    }

    return FutureBuilder<List<_Hit>>(
      future: _search(q),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: adminGold),
          );
        }
        final hits = snap.data!;
        if (hits.isEmpty) {
          return Center(
            child: Text(
              'Aucun résultat',
              style: GoogleFonts.inter(color: adminGrey),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: hits.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: adminBorder),
          itemBuilder: (context, i) {
            final h = hits[i];
            return ListTile(
              leading: Icon(h.icon, color: h.color, size: 22),
              title: Text(
                h.title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                h.subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              onTap: () {
                Navigator.of(context).pop();
                h.onTap(context);
              },
            );
          },
        );
      },
    );
  }

  Future<List<_Hit>> _search(String q) async {
    final db = FirebaseFirestore.instance;
    final hits = <_Hit>[];

    final matches = await db
        .collection('matches')
        .orderBy('date', descending: true)
        .limit(80)
        .get();
    for (final doc in matches.docs) {
      final d = doc.data();
      final t1 = (d['team1'] ?? '').toString();
      final t2 = (d['team2'] ?? '').toString();
      final blob = '$t1 $t2 ${d['competition']}'.toLowerCase();
      if (!blob.contains(q)) continue;
      hits.add(
        _Hit(
          icon: Icons.sports_soccer_rounded,
          color: adminBlue,
          title: '$t1 vs $t2',
          subtitle: 'Match · ${d['status'] ?? ''}',
          onTap: (ctx) => AdminNavigation.openStatsWorkbench(
            ctx,
            matchId: doc.id,
            team1: t1,
            team2: t2,
          ),
        ),
      );
      if (hits.length >= 8) break;
    }

    if (hits.length < 12) {
      final users = await db.collection('users').limit(120).get();
      for (final doc in users.docs) {
        final d = doc.data();
        final name = (d['displayName'] ?? d['firstName'] ?? d['email'] ?? '')
            .toString()
            .toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !email.contains(q)) continue;
        hits.add(
          _Hit(
            icon: Icons.person_rounded,
            color: adminGold,
            title: (d['displayName'] ?? d['firstName'] ?? 'Membre').toString(),
            subtitle: (d['email'] ?? '').toString(),
            onTap: (ctx) => AdminNavigation.goToTab(ctx, AdminTabIndex.users),
          ),
        );
        if (hits.length >= 12) break;
      }
    }

    if (hits.length < 15) {
      final articles = await db
          .collection('articles')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .get();
      for (final doc in articles.docs) {
        final d = doc.data();
        final title = (d['title'] ?? '').toString();
        if (!title.toLowerCase().contains(q)) continue;
        hits.add(
          _Hit(
            icon: Icons.newspaper_rounded,
            color: adminPurple,
            title: title,
            subtitle: 'Article · ${d['status'] ?? ''}',
            onTap: (ctx) => AdminNavigation.goToTab(ctx, AdminTabIndex.articles),
          ),
        );
        if (hits.length >= 15) break;
      }
    }

    return hits;
  }
}

class _Hit {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;
  const _Hit({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

void showAdminGlobalSearch(BuildContext context) {
  showSearch<void>(
    context: context,
    delegate: AdminGlobalSearchDelegate(),
  );
}
