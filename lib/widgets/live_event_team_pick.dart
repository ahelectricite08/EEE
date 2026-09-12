import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/admin/admin_palette.dart';
import '../screens/home/home_palette.dart';
import '../utils/remote_image_url.dart';

/// Deux gros choix d’équipe : écusson + nom, sélection = filet papier (pas un fond vert).
class LiveEventTeamPick extends StatelessWidget {
  final String team1;
  final String team2;
  final String? logo1;
  final String? logo2;
  final String? selectedTeam;
  final ValueChanged<String> onSelect;
  final bool adminStyle;

  const LiveEventTeamPick({
    super.key,
    required this.team1,
    required this.team2,
    this.logo1,
    this.logo2,
    required this.selectedTeam,
    required this.onSelect,
    this.adminStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final muted = adminStyle ? adminGrey : homeMutedText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ÉQUIPE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TeamChoice(
                name: team1,
                logoUrl: logo1,
                selected: selectedTeam == team1,
                onTap: () => onSelect(team1),
                adminStyle: adminStyle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TeamChoice(
                name: team2,
                logoUrl: logo2,
                selected: selectedTeam == team2,
                onTap: () => onSelect(team2),
                adminStyle: adminStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamChoice extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool selected;
  final VoidCallback onTap;
  final bool adminStyle;

  const _TeamChoice({
    required this.name,
    required this.logoUrl,
    required this.selected,
    required this.onTap,
    required this.adminStyle,
  });

  @override
  Widget build(BuildContext context) {
    final surface = adminStyle ? adminCard : homeSurface;
    final text = adminStyle ? adminTextPrimary : homeText;
    final hairline = adminStyle ? adminBorder : homeHairline;
    final filet = adminStyle ? adminGreenAccent : homeGreen;
    return Material(
      color: surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? filet : hairline,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              _MiniCrest(url: logoUrl, size: 36, adminStyle: adminStyle),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: text,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCrest extends StatelessWidget {
  final String? url;
  final double size;
  final bool adminStyle;

  const _MiniCrest({
    required this.url,
    required this.size,
    required this.adminStyle,
  });

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    final hairline = adminStyle ? adminBorder : homeHairline;
    final filet = adminStyle ? adminGreenAccent : homeGreen;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: hairline, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: u.isNotEmpty && !shouldSkipNetworkImageUrl(u)
              ? Image.network(
                  u,
                  fit: BoxFit.contain,
                  headers: kDvcrImageHttpHeaders,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.shield_outlined,
                    size: size * 0.42,
                    color: filet,
                  ),
                )
              : Icon(
                  Icons.shield_outlined,
                  size: size * 0.42,
                  color: filet,
                ),
        ),
      ),
    );
  }
}
