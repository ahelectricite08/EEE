import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../services/xp_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../domain/prono_xp_scale.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';

/// Expose le barème XP réel (`app_settings/xp_config`) aux surfaces qui
/// l'annoncent au joueur, avec [PronoXpScale.defaults] en repli le temps du
/// premier snapshot ou si le document est illisible.
class PronoXpScaleBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, PronoXpScale scale) builder;

  const PronoXpScaleBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: XpService.configDocStream(),
      builder: (context, snap) {
        var scale = PronoXpScale.defaults;
        if (!snap.hasError) {
          try {
            scale = PronoXpScale.fromConfigDoc(snap.data?.data());
          } catch (_) {
            scale = PronoXpScale.defaults;
          }
        }
        return builder(context, scale);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Kit partagé « Journal du Sanglier ».
//
//  Cinq langages de composition, jamais mélangés au hasard :
//   1. MASTHEAD  photo club + titre condensé            (prono_tab_hero_sliver)
//   2. RÉGLURE   filets, gouttière, chiffres            (feeds, annuaires)
//   3. ENCRE     matière vert-noir, une dalle par écran (moments décisifs)
//   4. TABLE     classements                            (prono_leaderboard_style)
//   5. VESTIAIRE panneaux à casquette colorée           (ligues, duels)
// ═══════════════════════════════════════════════════════════════════════════

// ── Langage 2 · RÉGLURE ────────────────────────────────────────────────────

/// Filet + kicker — l’en-tête de section du module (magazine, pas un badge).
class PronoSectionHeader extends StatelessWidget {
  final String title;
  final String? countLabel;
  final PronoPageAccent pageAccent;
  final Widget? action;

  const PronoSectionHeader({
    super.key,
    required this.title,
    this.countLabel,
    required this.pageAccent,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 16, height: 3, color: pageAccent.color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PronoType.kicker.copyWith(color: PronoTokens.text),
            ),
          ),
          if (countLabel != null && countLabel!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(countLabel!, style: PronoType.meta),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Hairline pleine largeur — sépare deux blocs sans dessiner de carte.
class PronoRule extends StatelessWidget {
  final double top;
  final double bottom;
  final Color? color;

  const PronoRule({super.key, this.top = 0, this.bottom = 0, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Container(height: 1, color: color ?? PronoArenaTheme.hairline),
    );
  }
}

/// Ligne d’annuaire — numérotée, filetée. Remplace la carte de navigation.
class PronoNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final PronoPageAccent pageAccent;
  final String? indexLabel;
  final Widget? trailing;

  const PronoNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.pageAccent,
    this.indexLabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: pageAccent.color.withValues(alpha: 0.06),
        highlightColor: pageAccent.color.withValues(alpha: 0.04),
        child: Ink(
          decoration: PronoArenaTheme.fixtureTape(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 30,
                  child: indexLabel != null
                      ? Text(
                          indexLabel!,
                          style: PronoType.numeralGutter.copyWith(
                            fontSize: 20,
                            color: PronoTokens.textSoft,
                          ),
                        )
                      : Icon(icon, size: 21, color: pageAccent.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.title.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.caption,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: PronoTokens.textSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip filtre — segment sportif souligné, jamais une pilule Material.
class PronoFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PronoFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: PronoTokens.animFast,
        curve: PronoTokens.animCurve,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? PronoArenaTheme.ink : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? PronoArenaTheme.ink : PronoArenaTheme.hairline,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: PronoType.kicker.copyWith(
            color: selected ? Colors.white : PronoTokens.textMuted,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

// ── Langage 3 · ENCRE ──────────────────────────────────────────────────────

/// Matière ENCRE — la seule façon autorisée de poser une dalle sombre.
///
/// Règle du module : **une seule dalle d'encre par écran**, et aucune sur un
/// écran coiffé d'une photo hero (la photo y tient déjà le rôle du bloc
/// sombre). À l'échelle d'un contrôle — bouton, puce, tampon — l'encre reste
/// libre partout.
///
/// Ce qu'on empile ici, du fond vers la surface : le dégradé diagonal de
/// [PronoArenaTheme.inkSlab], un écusson en filigrane très discret, un grain
/// de presse, puis un filet or optionnel sur l'arête haute.
///
/// Avec [photoSlot], la dalle devient **pilotable depuis l'admin** : si une
/// photo est renseignée pour cet emplacement, elle passe en fond sous un voile
/// d'encre ; sinon on garde exactement la matière ci-dessus comme repli. Le
/// contraste du texte ne dépend donc jamais de la photo choisie.
class PronoInkSurface extends StatelessWidget {
  final Widget? child;

  /// Alternative à [child] pour les dalles dont le contenu doit s'adapter à la
  /// présence d'une photo (typographie plus sûre, or allégé…).
  final Widget Function(BuildContext context, bool hasPhoto)? builder;

  final Color? tint;
  final double radius;
  final bool crest;
  final bool goldEdge;
  final bool shadow;

  /// Emplacement admin (`app_config/prono_banners`). `null` = encre pure.
  final PronoBannerSlot? photoSlot;
  final Alignment photoAlignment;

  /// Renfort du voile pour les dalles denses — voir [PronoArenaTheme.inkPhotoVeil].
  final double veilBoost;

  const PronoInkSurface({
    super.key,
    this.child,
    this.builder,
    this.tint,
    this.radius = 0,
    this.crest = true,
    this.goldEdge = false,
    this.shadow = false,
    this.photoSlot,
    this.photoAlignment = Alignment.center,
    this.veilBoost = 0,
  }) : assert(
          (child == null) != (builder == null),
          'Fournir soit child, soit builder.',
        );

  @override
  Widget build(BuildContext context) {
    final slot = photoSlot;
    if (slot == null) return _slab(context, null);

    return StreamBuilder<PronoBannersSettings>(
      stream: AppSettingsService.pronoBannersStream(),
      initialData: AppSettingsService.lastKnownPronoBanners,
      builder: (context, snap) {
        final banners = snap.data ?? PronoBannersSettings.defaults;
        final raw = banners.urlForSlot(slot).trim();
        return _slab(
          context,
          raw.isEmpty
              ? null
              : cacheBustedImageUrl(raw, banners.revisionMillis),
        );
      },
    );
  }

  Widget _slab(BuildContext context, String? photoUrl) {
    final hasPhoto = photoUrl != null;
    return DecoratedBox(
      decoration: PronoArenaTheme.inkSlab(
        radius: radius,
        tint: tint,
        shadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (photoUrl != null) ...[
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: PronoArenaTheme.inkPhotoFilter,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    alignment: photoAlignment,
                    // Le cache d'images est indexé sur l'URL : une fois
                    // décodée, la photo revient sans re-téléchargement ni
                    // frame blanche.
                    gaplessPlayback: true,
                    headers: kDvcrImageHttpHeaders,
                    filterQuality: FilterQuality.medium,
                    // Repli silencieux : l'encre dessous tient déjà le fond.
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const SizedBox.shrink(),
                  ),
                ),
              ),
              // Voile d'encre — c'est lui qui garantit la lisibilité quelle que
              // soit la photo déposée, y compris une photo très claire.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: PronoArenaTheme.inkPhotoVeil(
                      tint: tint,
                      veilBoost: veilBoost,
                    ),
                  ),
                ),
              ),
            ],
            if (crest && !hasPhoto)
              Positioned(
                right: -34,
                top: -26,
                bottom: -26,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _InkCrestPainter(),
                    child: const SizedBox(width: 190),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _InkGrainPainter()),
              ),
            ),
            if (goldEdge)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(height: 2, color: PronoArenaTheme.gold),
              ),
            child ?? builder!(context, hasPhoto),
          ],
        ),
      ),
    );
  }
}

/// Écusson en filigrane — tracé, pas d'asset : le logo DVCR est sur fond
/// blanc opaque et deviendrait un rectangle en `srcIn`.
class _InkCrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shoulder = h * 0.52;

    final shield = Path()
      ..moveTo(w * 0.08, h * 0.06)
      ..lineTo(w * 0.92, h * 0.06)
      ..lineTo(w * 0.92, shoulder)
      ..quadraticBezierTo(w * 0.92, h * 0.9, w * 0.5, h * 0.97)
      ..quadraticBezierTo(w * 0.08, h * 0.9, w * 0.08, shoulder)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.045),
    );
    canvas.drawPath(
      shield,
      Paint()..color = Colors.white.withValues(alpha: 0.014),
    );

    // Refend central — le partage vert / rouge de l'écusson du club.
    canvas.drawLine(
      Offset(w * 0.5, h * 0.06),
      Offset(w * 0.5, h * 0.95),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.03),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Grain de presse — filets horizontaux à peine perceptibles. C'est ce qui
/// empêche l'encre de lire comme un aplat plastique.
class _InkGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.016);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CTA principal — bloc d’encre avec vrai retour tactile Material.
class PronoInkCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final Color? color;
  final IconData? icon;

  const PronoInkCta({
    super.key,
    required this.label,
    this.onTap,
    this.busy = false,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = busy || onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        splashColor: Colors.white.withValues(alpha: 0.10),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
        child: Ink(
          decoration: disabled && !busy
              ? BoxDecoration(
                  color: PronoArenaTheme.surfaceMuted,
                  borderRadius:
                      BorderRadius.circular(PronoArenaTheme.inkRadius),
                )
              : PronoArenaTheme.inkSlab(tint: color),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 19,
                          color: disabled
                              ? PronoTokens.textSoft
                              : Colors.white,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: PronoType.cta.copyWith(
                            color: disabled
                                ? PronoTokens.textSoft
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// CTA secondaire — papier + filet, même géométrie que l’encre.
class PronoPaperCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? accent;

  const PronoPaperCta({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? PronoTokens.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: PronoArenaTheme.surface,
            border: Border.all(color: PronoArenaTheme.border),
            borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PronoType.cta.copyWith(fontSize: 15, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau « ta place » — chiffre de rang en scène.
///
/// [paper] quand l'écran a déjà dépensé sa dalle d'encre ailleurs (détail de
/// ligue) : même composition, registre papier, chiffre en or sur ivoire.
class PronoStandingBand extends StatelessWidget {
  final String kicker;
  final String rankLabel;
  final String detail;
  final Widget? action;
  final Color? tint;
  final bool paper;

  const PronoStandingBand({
    super.key,
    this.kicker = 'TA PLACE',
    required this.rankLabel,
    required this.detail,
    this.action,
    this.tint,
    this.paper = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: paper
                ? PronoType.kicker.copyWith(color: PronoArenaTheme.textMuted)
                : PronoType.kickerOnInk,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rankLabel,
                style: PronoType.display.copyWith(
                  color: paper ? PronoArenaTheme.text : Colors.white,
                  fontSize: 46,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    detail,
                    style: PronoType.caption.copyWith(
                      color: paper
                          ? PronoArenaTheme.textMuted
                          : PronoArenaTheme.onInkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );

    if (paper) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: PronoArenaTheme.surface,
          border: Border(
            left: BorderSide(color: PronoArenaTheme.gold, width: 3),
            top: BorderSide(color: PronoArenaTheme.hairline),
            bottom: BorderSide(color: PronoArenaTheme.hairline),
          ),
        ),
        child: body,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: PronoInkSurface(
        tint: tint,
        goldEdge: true,
        photoSlot: PronoBannerSlot.standingSlab,
        child: body,
      ),
    );
  }
}

/// Rétro-compat : ancien nom du bandeau de place.
class PronoPlaceCard extends StatelessWidget {
  final String rankLabel;
  final String detail;
  final Widget? action;

  const PronoPlaceCard({
    super.key,
    required this.rankLabel,
    required this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return PronoStandingBand(
      rankLabel: rankLabel,
      detail: detail,
      action: action,
    );
  }
}

/// Grille de statistiques — chiffres alignés sur une réglure, pas des cartes.
class PronoStatLedger extends StatelessWidget {
  final List<({String label, String value})> cells;
  final Color? valueColor;

  const PronoStatLedger({super.key, required this.cells, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: PronoArenaTheme.border),
          bottom: BorderSide(color: PronoArenaTheme.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 42,
                color: PronoArenaTheme.hairline,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    cells[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PronoType.stat.copyWith(
                      fontSize: 30,
                      color: valueColor ?? PronoTokens.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    cells[i].label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PronoType.kicker.copyWith(
                      fontSize: 9,
                      color: PronoTokens.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Langage 5 · VESTIAIRE ──────────────────────────────────────────────────

/// Panneau de salon — papier + casquette colorée, ou encre pour les moments.
class PronoRoomPanel extends StatelessWidget {
  final String eyebrow;
  final Widget child;
  final bool ink;
  final PronoPageAccent accent;
  final Widget? trailing;

  const PronoRoomPanel({
    super.key,
    required this.eyebrow,
    required this.child,
    this.ink = false,
    this.accent = PronoPageAccent.social,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (ink) {
      return SizedBox(
        width: double.infinity,
        child: PronoInkSurface(
          tint: accent.deep,
          radius: PronoArenaTheme.inkRadius,
          goldEdge: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        eyebrow.toUpperCase(),
                        style: PronoType.kickerOnInk,
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: child,
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      decoration: PronoArenaTheme.clubhousePanel(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: accent.color),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        eyebrow.toUpperCase(),
                        style: PronoType.kicker.copyWith(color: accent.color),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de membre — le code de salon, lisible à voix haute, copiable.
class PronoInviteStub extends StatelessWidget {
  final String code;
  final String memberLabel;
  final Color? tint;

  const PronoInviteStub({
    super.key,
    required this.code,
    required this.memberLabel,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final clean = code.trim();
    // Souche PAPIER : elle se pose le plus souvent sur l'en-tête d'encre du
    // salon. Un talon ivoire y lit comme un vrai ticket sur un comptoir —
    // deux encres empilées ne feraient qu'un gros bloc sombre de plus.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PronoArenaTheme.surface,
        borderRadius: BorderRadius.circular(PronoArenaTheme.ticketRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'CODE DU SALON',
                    style: PronoType.kicker.copyWith(
                      color: PronoArenaTheme.textMuted,
                    ),
                  ),
                ),
                Text(
                  memberLabel.toUpperCase(),
                  style: PronoType.kicker.copyWith(
                    color: tint ?? PronoArenaTheme.red,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 15),
            child: Text(
              clean.isEmpty ? '—' : clean.toUpperCase(),
              style: PronoType.codeStamp.copyWith(
                color: PronoArenaTheme.text,
              ),
            ),
          ),
          const _StubPerforation(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: clean.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: clean));
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text('Code $clean copié.'),
                          backgroundColor: PronoArenaTheme.ink,
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: PronoArenaTheme.textMuted,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'COPIER LE CODE',
                      style: PronoType.kicker.copyWith(
                        color: PronoArenaTheme.textMuted,
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

class _StubPerforation extends StatelessWidget {
  const _StubPerforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _PerforationPainter()),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PronoArenaTheme.edgeHighlight
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── États : vide · chargement · erreur ─────────────────────────────────────

/// État vide éditorial — glyphe discret, titre condensé, filet d’accent.
class PronoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final PronoPageAccent? pageAccent;
  final Widget? action;

  const PronoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.pageAccent,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pageAccent ?? PronoPageAccent.accueil;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: PronoArenaTheme.edgeHighlight),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PronoType.headline.copyWith(fontSize: 27),
          ),
          const SizedBox(height: 12),
          Container(width: 34, height: 3, color: accent.color),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: PronoType.caption,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 22),
            action!,
          ],
        ],
      ),
    );
  }
}

class PronoErrorState extends StatelessWidget {
  final String title;
  final String body;
  final PronoPageAccent? pageAccent;
  final Widget? action;

  const PronoErrorState({
    super.key,
    required this.title,
    required this.body,
    this.pageAccent,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return PronoEmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      body: body,
      pageAccent: pageAccent,
      action: action,
    );
  }
}

/// Squelette en langage réglure — des filets qui se remplissent, pas des cartes.
class PronoLoadingTape extends StatelessWidget {
  final int rows;
  final double horizontalPadding;

  const PronoLoadingTape({
    super.key,
    this.rows = 5,
    this.horizontalPadding = PronoArenaTheme.gutter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (i) {
        final fade = 1.0 - (i * 0.14).clamp(0.0, 0.6);
        return Opacity(
          opacity: fade,
          child: Container(
            height: 76,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: PronoArenaTheme.fixtureTape(),
            child: Row(
              children: [
                _bar(34, 12),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(150, 11),
                      const SizedBox(height: 9),
                      _bar(104, 11),
                    ],
                  ),
                ),
                _bar(48, 22),
              ],
            ),
          ),
        );
      }),
    );
  }

  static Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        color: PronoArenaTheme.surfaceMuted,
      );
}

/// Squelette « bloc » — pour les pages salon / progression.
class PronoLoadingBlock extends StatelessWidget {
  const PronoLoadingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 96, color: PronoArenaTheme.surfaceMuted),
        const SizedBox(height: 18),
        PronoLoadingTape._bar(140, 12),
        const SizedBox(height: 16),
        const PronoLoadingTape(rows: 3, horizontalPadding: 0),
      ],
    );
  }
}

// ── Détails ────────────────────────────────────────────────────────────────

/// Pastille XI — méta discrète au classement, jamais un trophée.
class PronoXiChip extends StatelessWidget {
  final int count;
  final bool onInk;

  const PronoXiChip({super.key, required this.count, this.onInk = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onInk
                ? PronoArenaTheme.goldSoft
                : PronoArenaTheme.gold.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$count XI 11/11',
          style: PronoType.meta.copyWith(
            fontSize: 10,
            letterSpacing: 0.3,
            color: onInk
                ? PronoArenaTheme.onInkMuted
                : PronoTokens.textSoft,
          ),
        ),
      ],
    );
  }
}

class PronoIconBadge extends StatelessWidget {
  final IconData icon;
  final PronoPageAccent pageAccent;
  final double size;

  const PronoIconBadge({
    super.key,
    required this.icon,
    required this.pageAccent,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(icon, size: size * 0.48, color: pageAccent.color),
    );
  }
}

/// Note de bas de page éditoriale — filet or + corps discret.
class PronoFootnote extends StatelessWidget {
  final String text;
  final String? heading;

  const PronoFootnote({super.key, required this.text, this.heading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 26, height: 2, color: PronoArenaTheme.gold),
          const SizedBox(height: 10),
          if (heading != null) ...[
            Text(
              heading!.toUpperCase(),
              style: PronoType.kicker.copyWith(color: PronoTokens.text),
            ),
            const SizedBox(height: 7),
          ],
          Text(text, style: PronoType.caption),
        ],
      ),
    );
  }
}
