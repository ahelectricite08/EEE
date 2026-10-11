import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/crowd_xi.dart';

void main() {
  test('fromMatchDoc ignore un agrégat incomplet', () {
    expect(
      CrowdXi.fromMatchDoc({
        'crowdXi': {
          'ballots': 2,
          'players': [
            {'name': 'Dupont', 'votes': 2},
          ],
        },
      }),
      isNull,
    );
  });

  test('fromMatchDoc lit le top 11 et le vs officiel', () {
    final players = List.generate(
      11,
      (i) => {
        'name': 'J$i',
        'votes': 10 - (i % 3),
        'inOfficial': i < 8,
      },
    );
    final crowd = CrowdXi.fromMatchDoc({
      'crowdXi': {
        'ballots': 40,
        'officialHits': 8,
        'officialComputed': true,
        'players': players,
      },
    });
    expect(crowd, isNotNull);
    expect(crowd!.isReady, isTrue);
    expect(crowd.ballots, 40);
    expect(crowd.officialHits, 8);
    expect(crowd.officialComputed, isTrue);
    expect(crowd.players.length, 11);
    expect(crowd.players.first.name, 'J0');
    expect(crowd.players.first.inOfficial, isTrue);
    expect(crowd.players[8].inOfficial, isFalse);
  });
}
