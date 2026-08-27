import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/match_partner_logos.dart';
import 'package:dvcr/services/motm_vote_service.dart';

void main() {
  test('MatchPartnerLogos doc id is stable', () {
    expect(MatchPartnerLogos.firestoreDocId, 'match_partner_logos');
    expect(MatchPartnerLogos.storageFolder, 'match_partner_logos');
    expect(MatchPartnerLogos.defaults.hasMatchRatingLogo, isFalse);
    expect(MatchPartnerLogos.defaults.hasMotmLogo, isFalse);
    expect(
      MatchPartnerLogos.fromMap({
        'matchRatingLogoUrl': ' https://x.test/n.png ',
        'motmLogoUrl': 'https://x.test/m.png',
      }).hasMatchRatingLogo,
      isTrue,
    );
  });

  test('MOTM resolves vote override then settings default', () {
    expect(
      MotmVoteService.resolveSponsorLogo(
        voteLogo: 'https://vote.test/l.png',
        settingsLogo: 'https://settings.test/l.png',
      ),
      'https://vote.test/l.png',
    );
    expect(
      MotmVoteService.resolveSponsorLogo(
        voteLogo: '  ',
        settingsLogo: 'https://settings.test/l.png',
      ),
      'https://settings.test/l.png',
    );
    expect(
      MotmVoteService.resolveSponsorLogo(voteLogo: '', settingsLogo: ''),
      '',
    );
    expect(MotmVoteService.defaultSponsorLogo, isEmpty);
  });
}
