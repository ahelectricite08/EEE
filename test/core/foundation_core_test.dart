import 'package:dvcr/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFailure', () {
    test('NetworkFailure exposes default French message', () {
      const f = NetworkFailure();
      expect(f.messageFr, contains('Connexion'));
    });

    test('AuthFailure keeps explicit message', () {
      const f = AuthFailure(message: 'Identifiants incorrects.');
      expect(f.messageFr, 'Identifiants incorrects.');
    });

    test('UnexpectedFailure wraps cause', () {
      final cause = StateError('boom');
      final f = UnexpectedFailure(cause: cause);
      expect(f.cause, same(cause));
      expect(f.messageFr, isNotEmpty);
    });
  });

  group('Result', () {
    test('Success exposes value', () {
      const Result<int> r = Success(42);
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, 42);
      expect(r.failureOrNull, isNull);
      expect(r.when(success: (v) => v, failure: (_) => -1), 42);
    });

    test('Failure exposes AppFailure', () {
      const Result<int> r = Failure(NetworkFailure());
      expect(r.isFailure, isTrue);
      expect(r.valueOrNull, isNull);
      expect(r.failureOrNull, isA<NetworkFailure>());
      expect(
        r.when(success: (_) => 'ok', failure: (e) => e.messageFr),
        contains('Connexion'),
      );
    });

    test('map transforms success only', () {
      const Result<int> ok = Success(2);
      const Result<int> bad = Failure(DomainFailure(message: 'nope'));
      expect(ok.map((v) => v * 3).valueOrNull, 6);
      expect(bad.map((v) => v * 3).failureOrNull, isA<DomainFailure>());
    });
  });

  group('AppConfig', () {
    test('appName is DVCR', () {
      expect(AppConfig.appName, 'DVCR');
      expect(AppConfig.packageName, 'dvcr');
    });
  });

  group('Riverpod foundation', () {
    test('foundationReadyProvider is true by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(foundationReadyProvider), isTrue);
    });

    test('foundationReadyProvider can be overridden', () {
      final container = ProviderContainer(
        overrides: [
          foundationReadyProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(foundationReadyProvider), isFalse);
    });
  });
}
