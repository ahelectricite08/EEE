/// Répartition live entre 1, 2 ou 3 statisticiens.
enum StatBlock { shots, passes, crosses, duels, events }

class StatsBench {
  final int size;
  final int seat;

  const StatsBench({this.size = 1, this.seat = 1});

  factory StatsBench.clamp({required int size, required int seat}) {
    final s = size.clamp(1, 3);
    return StatsBench(size: s, seat: seat.clamp(1, s));
  }

  /// Chrono possession : solo, poste 1 en duo, poste 1 en trio.
  bool get showPossession => size == 1 || seat == 1;

  /// Toujours les deux équipes — on ne split jamais Sedan / adverse.
  List<int> get teams => const [1, 2];

  /// Passes réussie / ratée : uniquement à 3 (poste 2).
  bool get showPasses => size == 3 && seat == 2;

  Set<StatBlock> get blocks {
    if (size == 1) {
      return const {
        StatBlock.shots,
        StatBlock.crosses,
        StatBlock.duels,
        StatBlock.events,
      };
    }
    if (size == 2) {
      return seat == 1
          ? const {StatBlock.shots}
          : const {
              StatBlock.crosses,
              StatBlock.duels,
              StatBlock.events,
            };
    }
    switch (seat) {
      case 1:
        return const {StatBlock.shots};
      case 2:
        return const {
          StatBlock.passes,
          StatBlock.crosses,
          StatBlock.duels,
        };
      default:
        return const {StatBlock.events};
    }
  }

  String caption(String team1, String team2) {
    if (size == 1) return 'Seul — les deux équipes, sans passes';
    if (size == 2) {
      return seat == 1
          ? 'Poste 1 — possession + tirs (les deux équipes)'
          : 'Poste 2 — centres, duels, faits (les deux équipes)';
    }
    switch (seat) {
      case 1:
        return 'Poste 1 — possession + tirs';
      case 2:
        return 'Poste 2 — passes, centres, duels';
      default:
        return 'Poste 3 — corners, fautes, arrêts';
    }
  }

  String seatLabel(int n, String team1, String team2) {
    if (size == 2) return n == 1 ? 'TIRS' : 'FAITS';
    switch (n) {
      case 1:
        return 'TIRS';
      case 2:
        return 'PASSES';
      default:
        return 'FAITS';
    }
  }
}
