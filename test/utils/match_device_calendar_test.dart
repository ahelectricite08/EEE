import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/utils/match_device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({
  required DateTime date,
  String team1 = 'CSSA',
  String team2 = 'AS Test',
  String? lieu,
  String? ville,
  String? adresse,
  String competition = 'Régional 1',
}) {
  return MatchModel(
    id: 'abc123',
    team1: team1,
    team2: team2,
    date: date,
    competition: competition,
    status: MatchStatus.upcoming,
    lieu: lieu,
    ville: ville,
    adresse: adresse,
  );
}

void main() {
  test('heure inconnue (minuit) → bouton masqué', () {
    final m = _match(date: DateTime(2026, 9, 5));
    expect(MatchDeviceCalendar.hasKnownKickoff(m.date), isFalse);
    expect(MatchDeviceCalendar.canAdd(m), isFalse);
  });

  test('coup d’envoi connu → bouton visible', () {
    final m = _match(date: DateTime(2026, 9, 5, 18, 30));
    expect(MatchDeviceCalendar.canAdd(m), isTrue);
  });

  test('titre domicile CSSA – adversaire', () {
    final m = _match(
      date: DateTime(2026, 9, 5, 18),
      team1: 'CS Sedan Ardennes',
      team2: 'Sarreguemines FC',
    );
    expect(MatchDeviceCalendar.eventTitle(m), 'CSSA – Sarreguemines FC');
  });

  test('titre extérieur CSSA – adversaire', () {
    final m = _match(
      date: DateTime(2026, 9, 5, 15),
      team1: 'Valence FC',
      team2: 'CSSA',
    );
    expect(MatchDeviceCalendar.eventTitle(m), 'CSSA – Valence FC');
  });

  test('durée ~2 h + lieu adresse', () {
    final kickoff = DateTime(2026, 9, 5, 20);
    final m = _match(
      date: kickoff,
      adresse: 'Stade Louis Dugauguez, Sedan',
    );
    expect(
      MatchDeviceCalendar.eventEnd(kickoff),
      DateTime(2026, 9, 5, 22),
    );
    expect(
      MatchDeviceCalendar.eventLocation(m),
      'Stade Louis Dugauguez, Sedan',
    );
  });

  test('ics UTC, titre, lieu, DTEND', () {
    final m = _match(
      date: DateTime.utc(2026, 9, 5, 18),
      team1: 'CSSA',
      team2: 'Bogny FC',
      lieu: 'Stade municipal',
      ville: 'Bogny-sur-Meuse',
    );
    final ics = MatchDeviceCalendar.buildIcs(
      m,
      stampedAt: DateTime.utc(2026, 8, 28, 10),
    );
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('SUMMARY:CSSA – Bogny FC'));
    expect(ics, contains('DTSTART:20260905T180000Z'));
    expect(ics, contains('DTEND:20260905T200000Z'));
    expect(ics, contains('LOCATION:Stade municipal\\, Bogny-sur-Meuse'));
    expect(ics, contains('UID:dvcr-match-abc123@dvcr.app'));
  });
}
