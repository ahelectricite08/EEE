import 'package:dvcr/models/user_role.dart';
import 'package:dvcr/services/motm_vote_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canSeeBenevoleProfileTools', () {
    test('team_dvcr bénévoles see the profile plates', () {
      expect(canSeeBenevoleProfileTools({UserRole.teamDvcr}), isTrue);
    });

    test('admin, CM and statisticien keep access', () {
      expect(canSeeBenevoleProfileTools({UserRole.admin}), isTrue);
      expect(canSeeBenevoleProfileTools({UserRole.communityManager}), isTrue);
      expect(canSeeBenevoleProfileTools({UserRole.statisticien}), isTrue);
    });

    test('regular members do not see pitch-side or social download', () {
      expect(canSeeBenevoleProfileTools({UserRole.supporter}), isFalse);
      expect(canSeeBenevoleProfileTools({UserRole.editor}), isFalse);
      expect(canSeeBenevoleProfileTools({}), isFalse);
    });
  });

  group('canSeeMatchSheetShare', () {
    test('admin et CM voient les stories réseaux', () {
      expect(canSeeMatchSheetShare({UserRole.admin}), isTrue);
      expect(canSeeMatchSheetShare({UserRole.communityManager}), isTrue);
      expect(
        canSeeMatchSheetShare({UserRole.admin, UserRole.communityManager}),
        isTrue,
      );
    });

    test('bénévoles et supporters non', () {
      expect(canSeeMatchSheetShare({UserRole.teamDvcr}), isFalse);
      expect(canSeeMatchSheetShare({UserRole.supporter}), isFalse);
      expect(canSeeMatchSheetShare({UserRole.statisticien}), isFalse);
      expect(canSeeMatchSheetShare({}), isFalse);
    });
  });

  group('canSeeMatchRatingSocialPlate', () {
    test('bénévoles team_dvcr see the note plate', () {
      expect(canSeeMatchRatingSocialPlate({UserRole.teamDvcr}), isTrue);
    });

    test('admin sees it as preview; supporters never', () {
      expect(canSeeMatchRatingSocialPlate({UserRole.admin}), isTrue);
      expect(canSeeMatchRatingSocialPlate({UserRole.admin, UserRole.teamDvcr}),
          isTrue);
      expect(canSeeMatchRatingSocialPlate({UserRole.supporter}), isFalse);
      expect(canSeeMatchRatingSocialPlate({UserRole.communityManager}), isFalse);
      expect(canSeeMatchRatingSocialPlate({UserRole.statisticien}), isFalse);
    });

    test('benevole aliases map to team_dvcr', () {
      expect(parseUserRoleFromFirestore('benevole'), UserRole.teamDvcr);
      expect(parseUserRoleFromFirestore('bénévole'), UserRole.teamDvcr);
      expect(parseUserRoleFromFirestore('team_dvcr'), UserRole.teamDvcr);
    });
  });

  group('canLaunchMotmVote', () {
    test('admin and CM can launch; statisticien and bénévoles cannot', () {
      expect(canLaunchMotmVote({UserRole.admin}), isTrue);
      expect(canLaunchMotmVote({UserRole.communityManager}), isTrue);
      expect(canLaunchMotmVote({UserRole.statisticien}), isFalse);
      expect(canLaunchMotmVote({UserRole.teamDvcr}), isFalse);
    });
  });

  group('profile live gates', () {
    test('pilotage is admin and CM only', () {
      expect(canPilotLiveFromProfile({UserRole.admin}), isTrue);
      expect(canPilotLiveFromProfile({UserRole.communityManager}), isTrue);
      expect(canPilotLiveFromProfile({UserRole.statisticien}), isFalse);
      expect(canPilotLiveFromProfile({UserRole.teamDvcr}), isFalse);
    });

    test('stats editor is statisticien or full admin, not bénévoles or CM', () {
      expect(canEditLiveStatsFromApp({UserRole.admin}), isTrue);
      expect(canEditLiveStatsFromApp({UserRole.statisticien}), isTrue);
      expect(canEditLiveStatsFromApp({UserRole.communityManager}), isFalse);
      expect(canEditLiveStatsFromApp({UserRole.teamDvcr}), isFalse);
      expect(canEditLiveStatsFromApp({UserRole.supporter}), isFalse);
    });

    test('profile back-office is admin, CM, editor — not live-only postes', () {
      expect(canOpenAdminFromProfile({UserRole.admin}), isTrue);
      expect(canOpenAdminFromProfile({UserRole.communityManager}), isTrue);
      expect(canOpenAdminFromProfile({UserRole.editor}), isTrue);
      expect(canOpenAdminFromProfile({UserRole.commentateur}), isFalse);
      expect(canOpenAdminFromProfile({UserRole.statisticien}), isFalse);
      expect(canOpenAdminFromProfile({UserRole.teamDvcr}), isFalse);
      expect(canOpenAdminFromProfile({UserRole.supporter}), isFalse);
    });

    test('radio from profile is commentateur or admin, not CM', () {
      expect(canUseRadioFromProfile({UserRole.commentateur}), isTrue);
      expect(canUseRadioFromProfile({UserRole.admin}), isTrue);
      expect(canUseRadioFromProfile({UserRole.communityManager}), isFalse);
      expect(canUseRadioFromProfile({UserRole.statisticien}), isFalse);
    });

    test('live panel on profile includes commentateur radio', () {
      expect(canSeeLiveQuickPanelFromProfile({UserRole.commentateur}), isTrue);
      expect(canSeeLiveQuickPanelFromProfile({UserRole.statisticien}), isTrue);
      expect(canSeeLiveQuickPanelFromProfile({UserRole.communityManager}),
          isTrue);
      expect(canSeeLiveQuickPanelFromProfile({UserRole.teamDvcr}), isFalse);
    });
  });

  group('MotmPitchPickupView', () {
    final now = DateTime(2026, 8, 27, 18, 0);

    test('idle when there is no live vote', () {
      final view = MotmVoteService.pitchPickupView(const {}, now: now);
      expect(view.phase, MotmPitchPickupPhase.idle);
      expect(view.hasPlayer, isFalse);
      expect(view.liveActive, isTrue);
    });

    test('hides when live document is gone (Arrêter le live)', () {
      final view = MotmVoteService.pitchPickupView(null, now: now);
      expect(view.liveActive, isFalse);
      expect(view.phase, MotmPitchPickupPhase.idle);
    });

    test('voting shows remaining time, not a fake player', () {
      final view = MotmVoteService.pitchPickupView({
        'motmVoteStatus': 'active',
        'motmVoteEndsAt': now.add(const Duration(minutes: 4, seconds: 32)),
      }, now: now);
      expect(view.phase, MotmPitchPickupPhase.voting);
      expect(view.hasPlayer, isFalse);
      expect(view.remainingLabel, '04:32');
    });

    test('expired active vote is pending until a winner exists', () {
      final view = MotmVoteService.pitchPickupView({
        'motmVoteStatus': 'active',
        'motmVoteEndsAt': now.subtract(const Duration(seconds: 1)),
      }, now: now);
      expect(view.phase, MotmPitchPickupPhase.pending);
      expect(view.hasPlayer, isFalse);
    });

    test('closed vote with winner is ready for pitch-side pickup', () {
      final view = MotmVoteService.pitchPickupView({
        'motmVoteStatus': 'closed',
        'motmVoteWinnerName': '9 Koffi',
        'motmVoteWinnerTeamName': 'CSSA',
        'motmVoteWinnerVotes': 80,
        'motmVoteTotal': 100,
      }, now: now);
      expect(view.phase, MotmPitchPickupPhase.ready);
      expect(view.playerName, '9 Koffi');
      expect(view.teamName, 'CSSA');
      expect(view.winnerPercent, 80);
      expect(view.winnerShareLabel, '80 % des votes');
    });

    test('FIN de match (fulltime) does not idle the plate while live exists', () {
      final view = MotmVoteService.pitchPickupView({
        'lastEvent': 'fulltime',
        'motmVoteStatus': 'closed',
        'motmVoteWinnerName': '9 Koffi',
        'motmVoteWinnerVotes': 4,
        'motmVoteTotal': 5,
      }, now: now);
      expect(view.phase, MotmPitchPickupPhase.ready);
      expect(view.winnerPercent, 80);
    });

    test('closed vote without a name stays pending', () {
      final view = MotmVoteService.pitchPickupView({
        'motmVoteStatus': 'closed',
      }, now: now);
      expect(view.phase, MotmPitchPickupPhase.pending);
    });

    test('splitPlayerLabel extracts shirt number when present', () {
      expect(
        MotmVoteService.splitPlayerLabel('9 Koffi'),
        (number: '9', name: 'Koffi'),
      );
      expect(
        MotmVoteService.splitPlayerLabel('Martin'),
        (number: '', name: 'Martin'),
      );
    });
  });

  group('MOTM persist on fiche', () {
    test('percent is round(winner / total * 100)', () {
      expect(
        MotmVoteService.winnerVotePercent({
          'motmVoteWinnerVotes': 8,
          'motmVoteTotal': 10,
        }),
        80,
      );
      expect(
        MotmVoteService.winnerVotePercentLabel({
          'motmVoteWinnerVotes': 8,
          'motmVoteTotal': 10,
        }),
        '80 % des votes',
      );
    });

    test('active vote is closed into match fields on Arrêter le live', () {
      final fields = MotmVoteService.persistFieldsForMatch({
        'motmVoteStatus': 'active',
        'motmVoteRevealWinner': true,
        'motmVoteCandidates': [
          {'id': 'a', 'name': '9 Koffi', 'teamId': 'team_1', 'teamName': 'CSSA'},
          {'id': 'b', 'name': '10 Martin', 'teamId': 'team_2', 'teamName': 'Pau'},
        ],
        'motmVoteCounts': {'a': 8, 'b': 2},
        'motmVoteTotal': 10,
        'motmVoteSponsorName': 'MANEO',
      });
      expect(fields['manOfTheMatchName'], '9 Koffi');
      expect(fields['showMotm'], isTrue);
      expect(fields['motmVoteWinnerVotes'], 8);
      expect(fields['motmVoteTotal'], 10);
      expect(fields['motmVoteStatus'], 'closed');
    });
  });

  group('MOTM public winner encart', () {
    test('closed + reveal + name → public winner, not while voting', () {
      expect(
        MotmVoteService.showsPublicWinner({
          'motmVoteStatus': 'active',
          'motmVoteRevealWinner': true,
          'motmVoteWinnerName': '9 Koffi',
          'motmVoteEndsAt': null,
        }),
        isFalse,
      );
      expect(
        MotmVoteService.showsPublicWinner({
          'motmVoteStatus': 'closed',
          'motmVoteRevealWinner': true,
          'motmVoteWinnerName': '9 Koffi',
        }),
        isTrue,
      );
      expect(
        MotmVoteService.showsPublicWinner({
          'motmVoteStatus': 'closed',
          'motmVoteRevealWinner': false,
          'motmVoteWinnerName': '9 Koffi',
        }),
        isFalse,
      );
    });

    test('Sedan MOTM side includes CSSA without the word Sedan', () {
      expect(MotmVoteService.isSedanTeamName('CSSA'), isTrue);
      expect(MotmVoteService.isSedanTeamName('CS Sedan Ardennes'), isTrue);
      expect(MotmVoteService.isSedanTeamName('Pau'), isFalse);
      expect(
        MotmVoteService.isSedanMotmTeam(
          {'team1': 'CSSA', 'team2': 'Pau'},
          {'id': 'team_1', 'name': 'CSSA'},
        ),
        isTrue,
      );
      expect(
        MotmVoteService.isSedanMotmTeam(
          {'team1': 'CSSA', 'team2': 'Pau'},
          {'id': 'team_2', 'name': 'Pau'},
        ),
        isFalse,
      );
      expect(
        MotmVoteService.winnerIsSedan({
          'motmVoteWinnerTeamName': 'CSSA',
          'motmVoteWinnerTeamId': 'team_1',
          'team1': 'CSSA',
        }),
        isTrue,
      );
      expect(
        MotmVoteService.winnerIsSedan({
          'motmVoteWinnerTeamName': 'Pau',
          'motmVoteWinnerTeamId': 'team_2',
          'team2': 'Pau',
        }),
        isFalse,
      );
    });

    test('crest follows the winner team (team_2 → logo2)', () {
      expect(
        MotmVoteService.winnerCrestUrl({
          'motmVoteWinnerTeamId': 'team_2',
          'motmVoteWinnerTeamName': 'Pau',
          'logo1': 'https://a.test/sedan.png',
          'logo2': 'https://a.test/pau.png',
          'team1': 'CSSA',
          'team2': 'Pau',
        }),
        'https://a.test/pau.png',
      );
      expect(
        MotmVoteService.winnerCrestUrl({
          'motmVoteWinnerTeamId': 'team_1',
          'motmVoteWinnerLogo': 'https://stored.test/cssa.png',
          'logo1': 'https://a.test/sedan.png',
        }),
        'https://stored.test/cssa.png',
      );
    });

    test('team picker crest uses stored logo then live logo1/logo2', () {
      expect(
        MotmVoteService.teamCrestUrl(
          {'logo1': 'https://a.test/sedan.png', 'logo2': 'https://a.test/pau.png'},
          {'id': 'team_2', 'name': 'Pau'},
          index: 1,
        ),
        'https://a.test/pau.png',
      );
      expect(
        MotmVoteService.teamCrestUrl(
          {'logo1': 'https://a.test/sedan.png'},
          {'id': 'team_1', 'name': 'CSSA', 'logo': 'https://stored.test/cssa.png'},
        ),
        'https://stored.test/cssa.png',
      );
    });
  });
}
