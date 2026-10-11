import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/favorite_team_calendar_service.dart';
import '../../services/user_preferences_service.dart';
import '../../widgets/favorite_team_picker_sheet.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';

/// Ligne Profil : tous les matchs de l’équipe favorite → calendrier téléphone.
class FavoriteTeamCalendarRow extends StatefulWidget {
  const FavoriteTeamCalendarRow({super.key});

  @override
  State<FavoriteTeamCalendarRow> createState() =>
      _FavoriteTeamCalendarRowState();
}

class _FavoriteTeamCalendarRowState extends State<FavoriteTeamCalendarRow> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<bool> _pickFavoriteTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('Connecte-toi pour choisir ton équipe favorite.');
      return false;
    }
    if (!mounted) return false;

    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: profileSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FavoriteTeamPickerSheet(
        current: UserPreferencesService.instance.favoriteTeam,
      ),
    );
    if (!mounted || picked == null) return false;

    final v = picked.trim();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'favoriteTeam': v.isEmpty ? FieldValue.delete() : v},
      SetOptions(merge: true),
    );
    return v.isNotEmpty;
  }

  Future<void> _onTap() async {
    if (_busy || kIsWeb) return;

    final team = FavoriteTeamCalendarService.normalizedFavoriteTeam(
      UserPreferencesService.instance.favoriteTeam,
    );
    if (team == null) {
      final ok = await _pickFavoriteTeam();
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    FavoriteTeamCalendarOutcome outcome;
    try {
      outcome = await FavoriteTeamCalendarService.exportToDevice(context);
    } catch (_) {
      outcome = const FavoriteTeamCalendarOutcome(
        status: FavoriteTeamCalendarStatus.failed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    switch (outcome.status) {
      case FavoriteTeamCalendarStatus.webUnsupported:
        _snack('Le calendrier du téléphone n’est pas dispo sur le web.');
      case FavoriteTeamCalendarStatus.noFavoriteTeam:
        _snack('Choisis d’abord ton équipe favorite.');
      case FavoriteTeamCalendarStatus.noUpcomingMatches:
        _snack(
          FavoriteTeamCalendarService.emptyMessage(
            outcome.teamName ?? 'ton équipe',
          ),
        );
      case FavoriteTeamCalendarStatus.shared:
        _snack(
          FavoriteTeamCalendarService.successMessage(
            outcome.count,
            warnDuplicates: outcome.mentionsPossibleDuplicates,
          ),
        );
      case FavoriteTeamCalendarStatus.cancelled:
        break;
      case FavoriteTeamCalendarStatus.failed:
        _snack(
          'Impossible d’ajouter au calendrier. Autorise le partage de fichiers, puis ouvre le fichier dans l’app Calendrier (Réglages si l’accès est refusé).',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: UserPreferencesService.instance,
      builder: (context, _) {
        final team = FavoriteTeamCalendarService.normalizedFavoriteTeam(
          UserPreferencesService.instance.favoriteTeam,
        );
        final subtitle = _busy
            ? 'Préparation du calendrier…'
            : team == null
                ? 'Choisis d’abord ton équipe favorite.'
                : team.toUpperCase();
        return ProfileActionRow(
          icon: Icons.event_available_rounded,
          title: 'Tous les matchs au calendrier',
          subtitle: subtitle,
          onTap: _onTap,
        );
      },
    );
  }
}
