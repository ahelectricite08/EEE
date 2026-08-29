import 'match_fan_poll_window.dart';

/// Sondage « Où tu regardes le match, toi ? » — domicile CSSA uniquement.
enum DugauguezPlaceChoice {
  home,
  stadium,
  virage,
  virageExt,
}

extension DugauguezPlaceChoiceX on DugauguezPlaceChoice {
  String get id => switch (this) {
        DugauguezPlaceChoice.home => 'home',
        DugauguezPlaceChoice.stadium => 'stadium',
        DugauguezPlaceChoice.virage => 'virage',
        DugauguezPlaceChoice.virageExt => 'virage_ext',
      };

  String get label => switch (this) {
        DugauguezPlaceChoice.home => 'À la maison',
        DugauguezPlaceChoice.stadium => 'Au stade',
        DugauguezPlaceChoice.virage => 'En virage',
        DugauguezPlaceChoice.virageExt => 'En virage extérieur',
      };

  String get hint => switch (this) {
        DugauguezPlaceChoice.home => 'Canapé, télé, sandwich',
        DugauguezPlaceChoice.stadium => 'Dugauguez, côté sage',
        DugauguezPlaceChoice.virage => 'Debout. Ça chante.',
        DugauguezPlaceChoice.virageExt => 'En face, on vous entend',
      };
}

abstract final class DugauguezPlaceChoiceCodec {
  static DugauguezPlaceChoice? fromId(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'home':
        return DugauguezPlaceChoice.home;
      case 'stadium':
        return DugauguezPlaceChoice.stadium;
      case 'virage':
        return DugauguezPlaceChoice.virage;
      case 'virage_ext':
        return DugauguezPlaceChoice.virageExt;
      default:
        return null;
    }
  }

  static const ids = ['home', 'stadium', 'virage', 'virage_ext'];
}

/// H-30 inclus → KO+20 exclus. Pas besoin du live.
abstract final class DugauguezPlaceWindow {
  static DateTime opensAt(DateTime kickoff) =>
      MatchFanPollWindow.opensAt(kickoff);

  static DateTime closesAt(DateTime kickoff) =>
      MatchFanPollWindow.closesAt(kickoff);

  static bool isOpen({
    required DateTime? kickoff,
    required DateTime now,
  }) =>
      MatchFanPollWindow.isPlaceOpen(kickoff: kickoff, now: now);
}

/// Domicile CSSA = Sedan / CSSA en `team1`. Pas l’extérieur.
abstract final class DugauguezPlaceGate {
  static bool isSedanHome(String team1) {
    final u = team1.toUpperCase();
    return u.contains('SEDAN') || u.contains('CSSA');
  }

  static bool shouldShow({
    required String team1,
    required DateTime? kickoff,
    required DateTime now,
    bool force = false,
  }) {
    if (force) return true;
    if (!isSedanHome(team1)) return false;
    return DugauguezPlaceWindow.isOpen(kickoff: kickoff, now: now);
  }
}

class DugauguezPlaceCounts {
  final Map<DugauguezPlaceChoice, int> byChoice;

  const DugauguezPlaceCounts(this.byChoice);

  factory DugauguezPlaceCounts.empty() => DugauguezPlaceCounts({
        for (final c in DugauguezPlaceChoice.values) c: 0,
      });

  factory DugauguezPlaceCounts.fromMap(Map<String, dynamic>? raw) {
    final out = DugauguezPlaceCounts.empty().byChoice;
    if (raw != null) {
      for (final c in DugauguezPlaceChoice.values) {
        final v = raw[c.id];
        out[c] = v is num ? v.toInt().clamp(0, 999999) : 0;
      }
    }
    return DugauguezPlaceCounts(out);
  }

  int of(DugauguezPlaceChoice choice) => byChoice[choice] ?? 0;

  int get total =>
      DugauguezPlaceChoice.values.fold(0, (sum, c) => sum + of(c));

  int percentOf(DugauguezPlaceChoice choice) {
    final t = total;
    if (t <= 0) return 0;
    return ((of(choice) * 100) / t).round();
  }

  Map<String, int> toMap() => {
        for (final c in DugauguezPlaceChoice.values) c.id: of(c),
      };
}
