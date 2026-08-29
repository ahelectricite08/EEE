import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_role.dart';
import '../../services/xp_service.dart';
import 'profile_palette.dart';

/// Cartes d’appartenance sous le nom (hero Profil).
///
/// Adhérent = oui/non uniquement (`helloAsso.isAdherentActive`).
/// Jamais montant, date d’expiration, reçu HelloAsso.
enum ProfileMembershipKind {
  /// Tout compte inscrit — palier [UserRole.supporter].
  supporter,

  /// Association HelloAsso — badge seulement si le flag est actif.
  adherent,

  /// Rôle club existant [UserRole.teamDvcr] (pas un nouveau flag).
  clubMember,
}

/// Règles d’affichage — pas de chips Material, pas d’invention de flag.
///
/// Membre DVCR (`team_dvcr`) exclusif : pas Adhérent ni Supporter à côté.
/// Sinon Adhérent + Supporter (palier) peuvent cohabiter.
List<ProfileMembershipKind> profileMembershipKinds({
  required Set<UserRole> roles,
  required bool isAdherentActive,
}) {
  if (roles.contains(UserRole.teamDvcr)) {
    return [ProfileMembershipKind.clubMember];
  }
  return [
    ProfileMembershipKind.supporter,
    if (isAdherentActive) ProfileMembershipKind.adherent,
  ];
}

String profileMembershipLabel(
  ProfileMembershipKind kind, {
  String supporterLabel = 'Supporter',
}) {
  switch (kind) {
    case ProfileMembershipKind.supporter:
      return supporterLabel.trim().isEmpty ? 'Supporter' : supporterLabel;
    case ProfileMembershipKind.adherent:
      return 'Adhérent DVCR';
    case ProfileMembershipKind.clubMember:
      return 'Membre DVCR';
  }
}

/// Tampons à poser (appartenance + Admin). [maxStamps] : bulles chat 2–3.
List<(String label, ProfileCarteTone tone)> membershipStampTickets({
  required Set<UserRole> roles,
  required bool isAdherentActive,
  String supporterLabel = 'Supporter',
  String adminLabel = 'Admin',
  int maxStamps = 8,
}) {
  final tickets = <(String, ProfileCarteTone)>[
    for (final kind in profileMembershipKinds(
      roles: roles,
      isAdherentActive: isAdherentActive,
    ))
      (
        profileMembershipLabel(kind, supporterLabel: supporterLabel),
        switch (kind) {
          ProfileMembershipKind.supporter => ProfileCarteTone.quiet,
          ProfileMembershipKind.adherent => ProfileCarteTone.adherent,
          ProfileMembershipKind.clubMember => ProfileCarteTone.club,
        },
      ),
  ];
  if (roles.contains(UserRole.admin)) {
    final label = adminLabel.trim().isEmpty ? 'Admin' : adminLabel.trim();
    tickets.add((label, ProfileCarteTone.staff));
  }
  if (tickets.length <= maxStamps) return tickets;
  return tickets.take(maxStamps).toList();
}

String profileStaffStampLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.communityManager:
      return 'CM';
    case UserRole.editor:
      return 'Éditeur';
    case UserRole.statisticien:
      return 'Stats';
    default:
      return role.displayName;
  }
}

class ProfileMembershipStampRow extends StatelessWidget {
  final Set<UserRole> roles;
  final bool isAdherentActive;
  final int xp;
  final List<Map<String, dynamic>>? xpLevels;
  final bool compact;
  final int maxStamps;
  final WrapAlignment alignment;
  final String adminLabel;

  const ProfileMembershipStampRow({
    super.key,
    required this.roles,
    required this.isAdherentActive,
    this.xp = 0,
    this.xpLevels,
    this.compact = false,
    this.maxStamps = 8,
    this.alignment = WrapAlignment.center,
    this.adminLabel = 'Admin',
  });

  Widget _wrap(List<Map<String, dynamic>> levels) {
    final tickets = membershipStampTickets(
      roles: roles,
      isAdherentActive: isAdherentActive,
      supporterLabel: XpService.supporterStampLabel(xp, levels: levels),
      adminLabel: adminLabel,
      maxStamps: maxStamps,
    );
    return Semantics(
      label: isAdherentActive ? 'Adhérent DVCR' : 'Pas adhérent DVCR',
      child: Wrap(
        alignment: alignment,
        spacing: compact ? 4 : 6,
        runSpacing: compact ? 4 : 6,
        children: [
          for (final t in tickets)
            ProfileCarteStamp(
              label: t.$1,
              tone: t.$2,
              compact: compact,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (xpLevels != null) return _wrap(xpLevels!);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: XpService.levelsDocStream(),
      builder: (context, snap) {
        return _wrap(XpService.parseLevels(snap.data?.data()));
      },
    );
  }
}

enum ProfileCarteTone { quiet, adherent, club, staff }

/// Petit tampon papier / ticket — ivoire, filet 1 px, pas de pastille SaaS.
class ProfileCarteStamp extends StatelessWidget {
  final String label;
  final ProfileCarteTone tone;
  final bool compact;

  const ProfileCarteStamp({
    super.key,
    required this.label,
    required this.tone,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _CarteSpec.of(tone, compact: compact);
    return Semantics(
      label: label,
      child: CustomPaint(
        painter: _CarteTicketPainter(
          fill: spec.fill,
          stroke: spec.stroke,
          rail: spec.rail,
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(7, 3, 8, 3)
              : const EdgeInsets.fromLTRB(11, 5, 12, 5),
          child: ConstrainedBox(
            constraints: compact
                ? const BoxConstraints(maxWidth: 92)
                : const BoxConstraints(),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.barlowCondensed(
                fontSize: spec.fontSize,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: compact ? 0.2 : 0.35,
                color: spec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteSpec {
  final Color fill;
  final Color stroke;
  final Color ink;
  final Color? rail;
  final double fontSize;

  const _CarteSpec({
    required this.fill,
    required this.stroke,
    required this.ink,
    required this.fontSize,
    this.rail,
  });

  static _CarteSpec of(ProfileCarteTone tone, {bool compact = false}) {
    const ivory = Color(0xFFF4F0E6);
    const paper = Color(0xFFFFFDF8);
    final bump = compact ? -2.5 : 0.0;
    switch (tone) {
      case ProfileCarteTone.quiet:
        return _CarteSpec(
          fill: ivory,
          stroke: profileBorder,
          ink: profileMutedText,
          fontSize: 12 + bump,
        );
      case ProfileCarteTone.adherent:
        return _CarteSpec(
          fill: paper,
          stroke: profileGreen,
          ink: profileGreenDeep,
          rail: profileGreen,
          fontSize: 13 + bump,
        );
      case ProfileCarteTone.club:
        return _CarteSpec(
          fill: ivory,
          stroke: Color(0xFFC8A436),
          ink: profileInk,
          rail: profileGold,
          fontSize: 12 + bump,
        );
      case ProfileCarteTone.staff:
        return _CarteSpec(
          fill: ivory,
          stroke: const Color(0xFFC5BDAE),
          ink: profileMutedText,
          fontSize: 11 + bump,
        );
    }
  }
}

class _CarteTicketPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final Color? rail;

  const _CarteTicketPainter({
    required this.fill,
    required this.stroke,
    this.rail,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const notchR = 3.4;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      const Radius.circular(2),
    );
    final base = Path()..addRRect(outer);
    final holes = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(0, size.height / 2),
          radius: notchR,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height / 2),
          radius: notchR,
        ),
      );
    final ticket = Path.combine(PathOperation.difference, base, holes);

    canvas.drawShadow(ticket, Colors.black.withValues(alpha: 0.35), 2.4, false);
    canvas.drawPath(ticket, Paint()..color = fill);
    canvas.drawPath(
      ticket,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final inset = RRect.fromRectAndRadius(
      Rect.fromLTWH(3.2, 2.4, size.width - 6.4, size.height - 4.8),
      const Radius.circular(1),
    );
    canvas.drawRRect(
      inset,
      Paint()
        ..color = stroke.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final accent = rail;
    if (accent != null) {
      canvas.drawRect(
        Rect.fromLTWH(6.5, 4.5, 2, size.height - 9),
        Paint()..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CarteTicketPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.rail != rail;
  }
}
