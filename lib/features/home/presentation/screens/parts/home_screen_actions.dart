part of '../home_screen.dart';

mixin _HomeScreenActionsMixin on _HomeScreenController {
  String _formatPodcastRendezVous(DateTime date) {
    return 'Prochain rendez-vous le ${DateFormat("d MMM yyyy · HH'h'mm", 'fr_FR').format(date)}';
  }

  /// Ouvre la fiche match du live courant sur l'onglet Compositions.
  /// Cherche d'abord par ID, puis par noms d'équipes, puis Firestore si nécessaire.
  Future<void> _openCompoCard(BuildContext ctx) async {
    final catalog = ref.read(homeMatchCatalogAdapterProvider);
    final allMatches = [
      ...catalog.upcoming,
      ...catalog.results,
    ];

    MatchModel? match = allMatches
        .where((m) => m.id == _liveMatchId)
        .firstOrNull;

    if (match == null && _liveTeam1.isNotEmpty && _liveTeam2.isNotEmpty) {
      match = allMatches.where((m) {
        final t1 = m.team1.trim().toUpperCase();
        final t2 = m.team2.trim().toUpperCase();
        final l1 = _liveTeam1.trim().toUpperCase();
        final l2 = _liveTeam2.trim().toUpperCase();
        return (t1.contains(l1.split(' ').first) ||
                l1.contains(t1.split(' ').first)) &&
            (t2.contains(l2.split(' ').first) ||
                l2.contains(t2.split(' ').first));
      }).firstOrNull;
    }

    // Dernier recours : fetch Firestore par matchId si c'est un vrai ID
    if (match == null &&
        _liveMatchId.isNotEmpty &&
        !(_liveMatchId.startsWith('live_') &&
            RegExp(r'^live_\d+$').hasMatch(_liveMatchId))) {
      try {
        match = await ref
            .read(homeMatchLookupDatasourceProvider)
            .fetchById(_liveMatchId);
      } catch (_) {}
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
