import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_palette.dart';

// ── Section title ─────────────────────────────────────────────────────────────
/// Titre de section avec barre colorée à gauche — identique au design system app.
class AdminSectionTitle extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const AdminSectionTitle({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? adminGold;
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          margin: const EdgeInsets.only(right: 10),
        ),
        if (icon != null) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c.withAlpha(20),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: c),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.barlowCondensed(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: c,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

// ── Stat row ──────────────────────────────────────────────────────────────────
/// Distribue ses enfants en colonnes égales.
class AdminStatRow extends StatelessWidget {
  final List<Widget> stats;
  const AdminStatRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (int i = 0; i < stats.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
            child: stats[i],
          ),
        ),
    ],
  );
}

// ── AdminStatFuture ───────────────────────────────────────────────────────────
/// Carte stat chargée via Future — gradient bg, icon box, accent bar.
class AdminStatFuture extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<String> future;

  const AdminStatFuture({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.future,
  });

  @override
  Widget build(BuildContext context) => AdminStatCardShell(
    color: color,
    icon: icon,
    label: label,
    child: FutureBuilder<String>(
      future: future,
      builder: (_, snap) {
        if (snap.hasError) {
          return Tooltip(
            message: '${snap.error}',
            child: Icon(Icons.warning_amber_rounded, color: adminRed, size: 26),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: color,
            ),
          );
        }
        return Text(
          snap.data ?? '–',
          style: GoogleFonts.barlowCondensed(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
            height: 1,
            letterSpacing: -0.3,
          ),
        );
      },
    ),
  );
}

// ── AdminStatStream ────────────────────────────────────────────────────────────
/// Carte stat chargée via Stream — gradient bg, icon box, accent bar.
class AdminStatStream extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<String> stream;
  final Color Function(String) activeColor;

  const AdminStatStream({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<String>(
    stream: stream,
    builder: (_, snap) {
      if (snap.hasError) {
        return AdminStatCardShell(
          color: adminRed,
          icon: icon,
          label: label,
          child: Tooltip(
            message: '${snap.error}',
            child: Icon(Icons.warning_amber_rounded, color: adminRed, size: 26),
          ),
        );
      }
      final loading =
          snap.connectionState == ConnectionState.waiting && snap.data == null;
      final val = snap.data ?? '–';
      final accent = loading ? color : activeColor(val);
      return AdminStatCardShell(
        color: accent,
        icon: icon,
        label: label,
        child: loading
            ? SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                ),
              )
            : Text(
                val,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  height: 1,
                  letterSpacing: -0.3,
                ),
              ),
      );
    },
  );
}

// ── Shared card shell ─────────────────────────────────────────────────────────
class AdminStatCardShell extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Widget child;

  const AdminStatCardShell({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const r = 16.0;
    // Flutter n’autorise pas borderRadius + Border avec des couleurs de côtés
    // différentes (assert en debug / erreur de peinture) : bordure uniforme +
    // bandeau d’accent séparé.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: adminCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: adminBorder),
        ),
        // ListView → hauteur max infinie : sans IntrinsicHeight, un Row en
        // stretch impose h=∞ aux enfants → "BoxConstraints forces an infinite height".
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: color.withAlpha(200),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withAlpha(14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(height: 12),
                      child,
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: adminGrey,
                          letterSpacing: 0.4,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AdminMiniInfoCard ─────────────────────────────────────────────────────────
class AdminMiniInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const AdminMiniInfoCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(22), adminCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(45)),
        boxShadow: adminCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: adminGrey,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AdminStatBarRow ────────────────────────────────────────────────────────────
class AdminStatBarRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const AdminStatBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: adminGrey)),
              ),
              Text(
                '$value',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: adminBorder,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
