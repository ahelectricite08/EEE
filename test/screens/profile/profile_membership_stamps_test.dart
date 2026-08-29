import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/user_role.dart';
import 'package:dvcr/screens/profile/profile_membership_stamps.dart';
import 'package:dvcr/services/xp_service.dart';

void main() {
  group('profileMembershipKinds', () {
    test('everyone gets Supporter', () {
      expect(
        profileMembershipKinds(roles: {UserRole.supporter}, isAdherentActive: false),
        [ProfileMembershipKind.supporter],
      );
    });

    test('HelloAsso active adds Adhérent DVCR beside Supporter', () {
      expect(
        profileMembershipKinds(roles: {UserRole.supporter}, isAdherentActive: true),
        [
          ProfileMembershipKind.supporter,
          ProfileMembershipKind.adherent,
        ],
      );
    });

    test('team_dvcr is Membre DVCR only — hides Adhérent and Supporter', () {
      expect(
        profileMembershipKinds(
          roles: {UserRole.supporter, UserRole.teamDvcr},
          isAdherentActive: true,
        ),
        [ProfileMembershipKind.clubMember],
      );
    });

    test('admin is still a supporter; staff is not a membership stamp', () {
      expect(
        profileMembershipKinds(
          roles: {UserRole.admin, UserRole.supporter},
          isAdherentActive: true,
        ),
        [
          ProfileMembershipKind.supporter,
          ProfileMembershipKind.adherent,
        ],
      );
    });
  });

  group('membershipStampTickets', () {
    test('membre + admin is two tickets', () {
      final tickets = membershipStampTickets(
        roles: {UserRole.teamDvcr, UserRole.admin},
        isAdherentActive: true,
        supporterLabel: 'Ultra',
      );
      expect(tickets.map((t) => t.$1).toList(), ['Membre DVCR', 'Admin']);
    });

    test('adhérent + palier + admin capped at 3', () {
      final tickets = membershipStampTickets(
        roles: {UserRole.supporter, UserRole.admin},
        isAdherentActive: true,
        supporterLabel: 'Capitaine',
        maxStamps: 3,
      );
      expect(tickets.map((t) => t.$1).toList(), [
        'Capitaine',
        'Adhérent DVCR',
        'Admin',
      ]);
    });
  });

  test('copy is names only — no money, expiry or receipt', () {
    const labels = [
      'Supporter',
      'Adhérent DVCR',
      'Membre DVCR',
    ];
    expect(profileMembershipLabel(ProfileMembershipKind.supporter), labels[0]);
    expect(
      profileMembershipLabel(
        ProfileMembershipKind.supporter,
        supporterLabel: 'Ultra',
      ),
      'Ultra',
    );
    expect(profileMembershipLabel(ProfileMembershipKind.adherent), labels[1]);
    expect(profileMembershipLabel(ProfileMembershipKind.clubMember), labels[2]);
    for (final label in labels) {
      expect(label.contains('€'), isFalse);
      expect(RegExp(r'\d').hasMatch(label), isFalse);
    }
  });

  group('XpService.supporterStampLabel', () {
    final levels = XpService.defaultLevels
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    test('no XP yet is Supporter, not Recrue', () {
      expect(XpService.supporterStampLabel(0, levels: levels), 'Supporter');
    });

    test('climbs through default prono paliers', () {
      expect(XpService.supporterStampLabel(1, levels: levels), 'Recrue');
      expect(XpService.supporterStampLabel(150, levels: levels), 'Fan');
      expect(XpService.supporterStampLabel(400, levels: levels), 'Supporter');
      expect(XpService.supporterStampLabel(900, levels: levels), 'Ultra');
      expect(XpService.supporterStampLabel(1800, levels: levels), 'Capitaine');
      expect(XpService.supporterStampLabel(3500, levels: levels), 'Legende');
    });
  });
}
