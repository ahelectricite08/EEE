import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/matches/matches_helpers.dart';
import '../screens/profile/profile_palette.dart';
import '../screens/profile/profile_type.dart';

/// Feuille de sélection d’équipe favorite (clubs du classement CSSA).
class FavoriteTeamPickerSheet extends StatefulWidget {
  const FavoriteTeamPickerSheet({
    super.key,
    this.current,
  });

  final String? current;

  @override
  State<FavoriteTeamPickerSheet> createState() =>
      _FavoriteTeamPickerSheetState();
}

class _FavoriteTeamPickerSheetState extends State<FavoriteTeamPickerSheet> {
  late Future<List<String>> _teamsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _teamsFuture = _loadTeams();
  }

  Future<List<String>> _loadTeams() async {
    final teams = <String>{};
    final current = widget.current?.trim();
    if (current != null && current.isNotEmpty) {
      teams.add(current);
    }

    try {
      final snap =
          await FirebaseFirestore.instance.collection('ranking').get();
      for (final doc in snap.docs) {
        final team = (doc.data()['team'] as String?)?.trim();
        if (team != null && team.isNotEmpty) {
          teams.add(team);
        }
      }
    } catch (_) {
      // Réseau / permissions : garder au moins l’équipe courante si connue.
    }

    if (teams.isEmpty) {
      teams.add('SEDAN ARDENNES CS');
    }

    final sorted = teams.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  List<String> _filter(List<String> teams) {
    final q = normalizeTeamLabel(_query);
    if (q.isEmpty) return teams;
    return teams
        .where((t) => normalizeTeamLabel(t).contains(q))
        .toList(growable: false);
  }

  void _pick(String? team) {
    Navigator.pop(context, team);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choisir mon équipe favorite',
                      style: ProfileType.title,
                    ),
                  ),
                  if (widget.current != null &&
                      widget.current!.trim().isNotEmpty)
                    TextButton(
                      onPressed: () => _pick(''),
                      child: Text(
                        'Effacer',
                        style: GoogleFonts.inter(
                          color: profileRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: profileMutedText,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher un club…',
                  hintStyle: GoogleFonts.inter(color: profileMutedText),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: profileSurface,
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: profileHairline),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: profileGreen),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<String>>(
                future: _teamsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: profileGreen,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  final teams = _filter(snap.data ?? const []);
                  if (teams.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun club trouvé.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: profileMutedText),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      final selected = teamMatchesPreference(
                        team,
                        widget.current,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _pick(team),
                            child: Ink(
                              decoration: profilePaper(
                                edge: selected ? profileGreen : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        team,
                                        style: GoogleFonts.inter(
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: selected
                                              ? profileGreen
                                              : profileText,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_rounded,
                                        color: profileGreen,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
