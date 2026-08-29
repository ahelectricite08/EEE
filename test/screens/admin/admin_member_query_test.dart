import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/screens/admin/admin_member_query.dart';

void main() {
  test('matches first+last together even without email', () {
    expect(
      adminMemberMatchesQuery(
        {'firstName': 'Jean', 'lastName': 'Dupont'},
        'jean dupont',
      ),
      isTrue,
    );
    expect(
      adminMemberMatchesQuery(
        {'firstName': 'Jean', 'lastName': 'Dupont'},
        'dupont',
      ),
      isTrue,
    );
  });

  test('matches email and emailLower', () {
    expect(
      adminMemberMatchesQuery(
        {'email': '', 'emailLower': 'b@club.fr', 'firstName': 'A'},
        'b@club',
      ),
      isTrue,
    );
  });

  test('empty email still matches name', () {
    expect(
      adminMemberMatchesQuery(
        {'email': '', 'firstName': 'Camille', 'lastName': 'Martin'},
        'camille',
      ),
      isTrue,
    );
  });
}
