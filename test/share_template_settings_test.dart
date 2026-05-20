import 'package:flutter_test/flutter_test.dart';
import 'package:dvcr/utils/share_template_settings.dart';

void main() {
  group('ShareTemplateSettings.interpolate', () {
    test('remplace les placeholders', () {
      const tpl = '{{a}} et {{b}}';
      final out = ShareTemplateSettings.interpolate(tpl, {
        'a': 'X',
        'b': 'Y',
      });
      expect(out, 'X et Y');
    });

    test('laisse les clés inconnues telles quelles', () {
      const tpl = '{{connu}} {{inconnu}}';
      final out = ShareTemplateSettings.interpolate(tpl, {'connu': 'OK'});
      expect(out, 'OK {{inconnu}}');
    });
  });

  group('ShareTemplateSettings.resolveSignOff', () {
    test('signOffBody vide utilise la signature intégrée', () {
      const s = ShareTemplateSettings.defaults;
      expect(s.signOffBody, isEmpty);
      final off = s.resolveSignOff();
      expect(off, contains('DVCR'));
      expect(off, contains('https://www.dvcr.fr'));
    });

    test('signOffBody personnalisé prime (trim des bords)', () {
      const s = ShareTemplateSettings(
        signOffBody: '\n\n— Custom —\n',
        siteUrl: '',
        articleDefault: '',
        articleByCategory: {},
        videoDefault: '',
        videoByCategory: {},
        matchFinishedScored: '',
        matchFinishedNoScore: '',
        matchLive: '',
        matchUpcoming: '',
        replayStrip: '',
        tournamentEmpty: '',
        tournamentRanked: '',
        cssaFavoriteRanking: '',
        prediction: '',
      );
      expect(s.resolveSignOff(), '— Custom —');
    });
  });
}
