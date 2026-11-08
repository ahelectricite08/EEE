import 'package:dvcr/utils/opponent_lineup_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a single typed name, including shirt number', () {
    expect(parseOpponentLineupNames('9 Martin'), ['9 Martin']);
  });

  test('splits one name per line', () {
    expect(
      parseOpponentLineupNames('Martin\nDupont\nLopez'),
      ['Martin', 'Dupont', 'Lopez'],
    );
  });

  test('splits a comma list copied from a site', () {
    expect(
      parseOpponentLineupNames('Martin, Dupont, Lopez, Petit'),
      ['Martin', 'Dupont', 'Lopez', 'Petit'],
    );
  });

  test('splits a packed numbered line', () {
    expect(
      parseOpponentLineupNames('1 Martin 4 Dupont 9 Lopez'),
      ['1 Martin', '4 Dupont', '9 Lopez'],
    );
  });

  test('strips list markers but keeps jersey numbers', () {
    expect(
      parseOpponentLineupNames('1. Martin\n2) Dupont\n9 Lopez'),
      ['Martin', 'Dupont', '9 Lopez'],
    );
  });

  test('skips coach / staff labels and duplicates', () {
    expect(
      parseOpponentLineupNames('Martin\nCoach\nMartin\nDupont'),
      ['Martin', 'Dupont'],
    );
  });
}
