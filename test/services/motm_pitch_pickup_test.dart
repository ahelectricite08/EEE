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
}
