import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dvcr/core/core.dart';
import 'package:dvcr/features/home/data/mappers/home_sections_mapper.dart';
import 'package:dvcr/features/home/domain/entities/home_layout_hints.dart';
import 'package:dvcr/features/home/domain/entities/home_sections_config.dart';
import 'package:dvcr/features/home/domain/repositories/home_repository.dart';
import 'package:dvcr/features/home/domain/usecases/clear_podcast_next_event.dart';
import 'package:dvcr/features/home/domain/usecases/set_podcast_next_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home_sections_mapper', () {
    test('homeLayoutHintsFromMap reads bool flags', () {
      final hints = homeLayoutHintsFromMap({
        'hideDonationBannerWhenAnyLive': true,
        'hidePodcastBlockWhenAnyLive': true,
        'hideDvcrTvBlockWhenAnyLive': false,
      });
      expect(hints.hideDonationBannerWhenAnyLive, isTrue);
      expect(hints.hidePodcastBlockWhenAnyLive, isTrue);
      expect(hints.hideDvcrTvBlockWhenAnyLive, isFalse);
    });

    test('homeLayoutHintsFromMap null/empty → defaults', () {
      expect(homeLayoutHintsFromMap(null), HomeLayoutHints.defaults);
      expect(homeLayoutHintsFromMap({}), HomeLayoutHints.defaults);
    });

    test('homeSectionsConfigFromMap reads Timestamp podcast', () {
      final at = DateTime(2026, 8, 1, 18, 30);
      final config = homeSectionsConfigFromMap({
        'podcastNextEventAt': Timestamp.fromDate(at),
        'hidePodcastBlockWhenAnyLive': true,
      });
      expect(config.podcastNextEventAt, at);
      expect(config.layoutHints.hidePodcastBlockWhenAnyLive, isTrue);
    });

    test('homeSectionsConfigFromMap empty → defaults', () {
      expect(homeSectionsConfigFromMap(null), HomeSectionsConfig.defaults);
    });
  });

  group('use cases with FakeHomeRepository', () {
    late FakeHomeRepository fake;
    late SetPodcastNextEvent setPodcast;
    late ClearPodcastNextEvent clearPodcast;

    setUp(() {
      fake = FakeHomeRepository();
      setPodcast = SetPodcastNextEvent(fake);
      clearPodcast = ClearPodcastNextEvent(fake);
    });

    test('SetPodcastNextEvent delegates to repository', () async {
      final at = DateTime(2026, 9, 1, 20);
      final result = await setPodcast(at);
      expect(result.isSuccess, isTrue);
      expect(fake.lastPodcastAt, at);
    });

    test('ClearPodcastNextEvent clears podcast', () async {
      fake.lastPodcastAt = DateTime(2026, 1, 1);
      final result = await clearPodcast();
      expect(result.isSuccess, isTrue);
      expect(fake.lastPodcastAt, isNull);
      expect(fake.clearedPodcast, isTrue);
    });

    test('SetPodcastNextEvent surfaces Failure', () async {
      fake.failWrites = true;
      final result = await setPodcast(DateTime.now());
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}

class FakeHomeRepository implements HomeRepository {
  DateTime? lastPodcastAt;
  bool clearedPodcast = false;
  bool failWrites = false;

  @override
  Stream<HomeLayoutHints> watchLayoutHints() =>
      Stream.value(HomeLayoutHints.defaults);

  @override
  Stream<HomeSectionsConfig> watchSectionsConfig() =>
      Stream.value(HomeSectionsConfig.defaults);

  @override
  Stream<String?> watchBannerPhotoUrl() => Stream.value(null);

  @override
  Future<Result<void>> setPodcastNextEvent(DateTime dateTime) async {
    if (failWrites) {
      return const Failure(UnexpectedFailure(message: 'boom'));
    }
    lastPodcastAt = dateTime;
    return const Success(null);
  }

  @override
  Future<Result<void>> clearPodcastNextEvent() async {
    if (failWrites) {
      return const Failure(UnexpectedFailure(message: 'boom'));
    }
    lastPodcastAt = null;
    clearedPodcast = true;
    return const Success(null);
  }

  @override
  Future<Result<String>> uploadBannerPhoto({
    required Uint8List bytes,
    required String extension,
  }) async {
    return const Success('https://example.test/banner.jpg');
  }

  @override
  Future<Result<void>> clearBannerPhoto() async => const Success(null);
}
