part of '../home_screen.dart';

mixin _HomeScreenActionsMixin on _HomeScreenController {
  String _formatPodcastRendezVous(DateTime date) {
    return 'Prochain rendez-vous le ${DateFormat("d MMM yyyy · HH'h'mm", 'fr_FR').format(date)}';
  }

  /// Ouvre la fiche match du live courant sur l'onglet Compositions.
  ///
  /// Source de vérité = `live/current.matchId` (même ID que le score hero).
  /// Pas de matching flou par noms tant qu'un vrai matchId est présent :
  /// sinon un autre match Sedan (ex. Cormontreuil) peut être ouvert à la place.
  Future<void> _openCompoCard(BuildContext ctx) async {
    final catalog = ref.read(homeMatchCatalogAdapterProvider);
    final allMatches = [
      ...catalog.upcoming,
      ...catalog.results,
    ];
    final mid = _liveMatchId.trim();
    final isSynthetic = mid.startsWith('live_') &&
        RegExp(r'^live_\d+$').hasMatch(mid);

    MatchModel? match;

    // 1) Exact matchId hub → calendrier local, sinon Firestore
    if (mid.isNotEmpty && !isSynthetic) {
      match = allMatches.where((m) => m.id == mid).firstOrNull;
      if (match == null) {
        try {
          match = await ref
              .read(homeMatchLookupDatasourceProvider)
              .fetchById(mid);
        } catch (_) {}
      }
    } else if (_liveTeam1.isNotEmpty && _liveTeam2.isNotEmpty) {
      // 2) Session sans ID calendrier uniquement : matching équipes (avec swap)
      match = allMatches.where((m) {
        return (_looseTeamName(_liveTeam1, m.team1) &&
                _looseTeamName(_liveTeam2, m.team2)) ||
            (_looseTeamName(_liveTeam1, m.team2) &&
                _looseTeamName(_liveTeam2, m.team1));
      }).firstOrNull;
    }

    if (!ctx.mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Fiche match introuvable.')),
      );
      return;
    }
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(match: match!, initialTab: 1),
      ),
    );
  }

  Future<void> _openPodcastRendezVousEditor(DateTime? initialDate) async {
    final firstDate = DateTime.now().subtract(const Duration(days: 1));
    final lastDate = DateTime.now().add(const Duration(days: 730));
    final sourceDate = initialDate ?? DateTime.now().add(const Duration(days: 7));
    // Clamp pour éviter un initialDate hors plage (ex: date passée ancienne)
    final clampedDate = sourceDate.isBefore(firstDate)
        ? firstDate
        : sourceDate.isAfter(lastDate)
            ? lastDate
            : sourceDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: clampedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Prochain rendez-vous podcast',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC8A436),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(sourceDate),
      helpText: 'Heure du rendez-vous',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC8A436),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || pickedTime == null) return;

    final nextDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await ref.read(setPodcastNextEventProvider).call(nextDate);
    if (!mounted) return;
  }
}
