import 'package:flutter/material.dart';

import '../features/prono/presentation/theme/prono_theme.dart';
import '../features/prono/presentation/theme/prono_type.dart';
import '../models/sedan_squad.dart';
import '../utils/player_name_normalize.dart';
import 'dvcr_network_image.dart';

/// Place un XI dans un 1-4-3-3 (GB / DEF / MIL / ATT).
List<SedanSquadPlayer?> xiFormationSlots(List<SedanSquadPlayer> picked) {
  if (picked.isEmpty) return const [];

  const caps = {'GB': 1, 'DEF': 4, 'MIL': 3, 'ATT': 3};
  final buckets = <String, List<SedanSquadPlayer>>{
    for (final k in SedanSquadPositions.order) k: [],
  };
  final leftover = <SedanSquadPlayer>[];
  for (final p in picked) {
    final key = SedanSquadPositions.normalize(p.position);
    if (buckets.containsKey(key) && buckets[key]!.length < caps[key]!) {
      buckets[key]!.add(p);
    } else {
      leftover.add(p);
    }
  }
  for (final p in leftover) {
    var placed = false;
    for (final k in SedanSquadPositions.order) {
      if (buckets[k]!.length < caps[k]!) {
        buckets[k]!.add(p);
        placed = true;
        break;
      }
    }
    if (!placed) break;
  }

  T? at<T>(List<T> list, int i) => i < list.length ? list[i] : null;
  return [
    ...List<SedanSquadPlayer?>.generate(1, (i) => at(buckets['GB']!, i)),
    ...List<SedanSquadPlayer?>.generate(4, (i) => at(buckets['DEF']!, i)),
    ...List<SedanSquadPlayer?>.generate(3, (i) => at(buckets['MIL']!, i)),
    ...List<SedanSquadPlayer?>.generate(3, (i) => at(buckets['ATT']!, i)),
  ];
}

/// Disque joueur journal : papier ivoire, anneau, photo clipée.
///
/// Pas d’aplat vert (maillot CSSA + disque vert = illisible). Numéro / initiale
/// si l’admin n’a pas mis de `photoUrl`.
class SedanPlayerFace extends StatelessWidget {
  final SedanSquadPlayer? player;
  final double size;
  final Color? background;
  final Color? foreground;
  final Color? border;
  final double? borderWidth;
  final bool occupied;
  final bool selected;
  /// `true` = validé, `false` = pas validé, `null` = pas de verdict.
  final bool? validated;

  const SedanPlayerFace({
    super.key,
    required this.player,
    this.size = 28,
    this.background,
    this.foreground,
    this.border,
    this.borderWidth,
    this.occupied = true,
    this.selected = false,
    this.validated,
  });

  @override
  Widget build(BuildContext context) {
    final label = player?.number != null
        ? '${player!.number}'
        : (player != null && player!.name.trim().isNotEmpty
            ? player!.name.trim().substring(0, 1).toUpperCase()
            : '');
    final url = player?.photoUrl?.trim() ?? '';
    final showPhoto = player != null && player!.hasPhoto && url.isNotEmpty;

    final ringW = borderWidth ?? (selected ? 2.5 : (occupied ? 1.5 : 1.0));
    final fill = background ?? PronoArenaTheme.surface;
    final ring = border ??
        (validated == true
            ? PronoArenaTheme.gold
            : validated == false
                ? PronoArenaTheme.red
                : selected
                    ? PronoArenaTheme.gold
                    : occupied
                        ? PronoArenaTheme.green
                        : PronoArenaTheme.hairline);
    final ink = foreground ??
        (occupied ? PronoArenaTheme.text : PronoArenaTheme.textMuted);

    Widget fallback() => Text(
          label,
          style: PronoType.kicker.copyWith(
            fontSize: size >= 48 ? 16 : (size >= 36 ? 13 : 11),
            letterSpacing: 0,
            color: ink,
          ),
        );

    final inner = (size - ringW * 2).clamp(8.0, size);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: ring, width: ringW),
            ),
            child: Padding(
              padding: EdgeInsets.all(ringW),
              child: ClipOval(
                child: SizedBox(
                  width: inner,
                  height: inner,
                  child: showPhoto
                      ? DvcrNetworkImage(
                          url,
                          fit: BoxFit.cover,
                          width: inner,
                          height: inner,
                          cacheWidth: dvcrImageCacheWidth(context, inner),
                          errorBuilder: (_, __, ___) =>
                              Center(child: fallback()),
                          placeholder: Center(child: fallback()),
                        )
                      : Center(child: fallback()),
                ),
              ),
            ),
          ),
          if (validated != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: _VerdictDot(validated: validated!),
            ),
        ],
      ),
    );
  }
}

class _VerdictDot extends StatelessWidget {
  final bool validated;

  const _VerdictDot({required this.validated});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: validated ? PronoArenaTheme.gold : PronoArenaTheme.red,
        border: Border.all(color: PronoArenaTheme.surface, width: 1),
      ),
      child: Icon(
        validated ? Icons.check_rounded : Icons.close_rounded,
        size: 8,
        color: PronoArenaTheme.onInk,
      ),
    );
  }
}

/// Petit onze 1-4-3-3 — portraits si l’admin a mis les photos.
class XiMiniPitch extends StatelessWidget {
  static const pitchAsset = 'assets/images/terrain.jpg';

  final List<SedanSquadPlayer?> players;
  final double faceSize;
  final String? caption;
  final Set<String>? validatedPlayerIds;
  final Set<String>? validatedNames;
  final bool showVerdict;
  /// Officiel : tout le onze est la référence — or, jamais rouge.
  final bool verdictAllCorrect;

  const XiMiniPitch({
    super.key,
    required this.players,
    this.faceSize = 52,
    this.caption,
    this.validatedPlayerIds,
    this.validatedNames,
    this.showVerdict = false,
    this.verdictAllCorrect = false,
  });

  @override
  Widget build(BuildContext context) {
    final slots = List<SedanSquadPlayer?>.from(players);
    while (slots.length < 11) {
      slots.add(null);
    }

    bool? verdictFor(SedanSquadPlayer? p) {
      if (!showVerdict || p == null) return null;
      if (verdictAllCorrect) return true;
      if (p.id.isNotEmpty && (validatedPlayerIds?.contains(p.id) ?? false)) {
        return true;
      }
      final n = normalizePlayerName(p.name);
      if (n.isNotEmpty && (validatedNames?.contains(n) ?? false)) return true;
      return false;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 6.0;
        const gap = 6.0;
        final innerW = constraints.maxWidth.isFinite
            ? constraints.maxWidth - hPad * 2
            : 320.0;
        final maxFour = ((innerW - gap * 3) / 4).floorToDouble();
        final size = faceSize < maxFour ? faceSize : maxFour.clamp(36.0, faceSize);

        Widget row(int start, int count) {
          return Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(
                  child: Center(
                    child: SedanPlayerFace(
                      player: slots[start + i],
                      size: size,
                      occupied: slots[start + i] != null,
                      validated: verdictFor(slots[start + i]),
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              const Positioned.fill(child: _XiPitchBackdrop()),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                decoration: BoxDecoration(
                  border: Border.all(color: PronoArenaTheme.hairline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    if (caption != null && caption!.isNotEmpty) ...[
                      Text(
                        caption!.toUpperCase(),
                        style: PronoType.kicker.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    row(0, 1),
                    const SizedBox(height: 12),
                    row(1, 4),
                    const SizedBox(height: 12),
                    row(5, 3),
                    const SizedBox(height: 12),
                    row(8, 3),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pelouse + filets — `terrain.jpg` si dispo, sinon bandes peintes.
class _XiPitchBackdrop extends StatelessWidget {
  const _XiPitchBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _PitchLinesPainter()),
        Image.asset(
          XiMiniPitch.pitchAsset,
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.55),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
      ],
    );
  }
}

class _PitchLinesPainter extends CustomPainter {
  const _PitchLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()..style = PaintingStyle.fill;
    const a = Color(0xFF2A5A32);
    const b = Color(0xFF234D2B);
    const bands = 6;
    for (var i = 0; i < bands; i++) {
      stripe.color = i.isEven ? a : b;
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * i / bands, size.width, size.height / bands),
        stripe,
      );
    }
    final line = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), line);
    canvas.drawLine(
      Offset(4, size.height / 2),
      Offset(size.width - 4, size.height / 2),
      line,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14, line);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.22, 4, size.width * 0.56, size.height * 0.18),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.82,
        size.width * 0.56,
        size.height * 0.18 - 4,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
