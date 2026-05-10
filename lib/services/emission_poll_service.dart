import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'vote_history_service.dart';

class EmissionPollService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DocumentReference<Map<String, dynamic>> _emissionRef = _db
      .collection('live')
      .doc('emission');

  static const Duration defaultDuration = Duration(minutes: 10);

  static Future<void> startPoll({
    required String title,
    required List<String> options,
    String subtitle = '',
    String backgroundImageUrl = '',
    String sponsorId = '',
    String sponsorName = '',
    String sponsorLogo = '',
    String sponsorColorHex = '',
    String sponsorLinkUrl = '',
    int durationMinutes = 10,
    bool revealResults = true,
  }) async {
    final cleanTitle = title.trim();
    final cleanSubtitle = subtitle.trim();
    final cleanOptions = _cleanOptions(options);
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final duration = durationMinutes.clamp(1, 30);

    if (cleanTitle.isEmpty) {
      throw StateError('Renseigne un titre avant de lancer le sondage.');
    }
    if (cleanOptions.length < 2) {
      throw StateError('Ajoute au moins 2 choix pour le sondage.');
    }

    final optionMaps = <Map<String, dynamic>>[];
    final counts = <String, int>{};
    for (var i = 0; i < cleanOptions.length; i++) {
      final optionId = 'option_${i + 1}';
      optionMaps.add({'id': optionId, 'label': cleanOptions[i]});
      counts[optionId] = 0;
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_emissionRef);
      if (!snap.exists) {
        throw StateError('Demarre l emission avant de lancer un sondage.');
      }
      tx.set(_emissionRef, {
        'pollEnabled': true,
        'pollStatus': 'active',
        'pollSessionId': sessionId,
        'pollTitle': cleanTitle,
        'pollSubtitle': cleanSubtitle,
        'pollBackgroundImage': backgroundImageUrl.trim(),
        'pollSponsorId': sponsorId.trim(),
        'pollSponsorName': sponsorName.trim(),
        'pollSponsorLogo': sponsorLogo.trim(),
        'pollSponsorColorHex': sponsorColorHex.trim(),
        'pollSponsorLinkUrl': sponsorLinkUrl.trim(),
        'pollOptions': optionMaps,
        'pollCounts': counts,
        'pollTotal': 0,
        'pollRevealResults': revealResults,
        'pollStartedAt': FieldValue.serverTimestamp(),
        'pollEndsAt': Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: duration)),
        ),
        'pollClosedAt': null,
        'pollWinnerId': '',
        'pollWinnerLabel': '',
        'pollEndedReason': '',
      }, SetOptions(merge: true));
    });
  }

  static Future<void> castVote({required String optionId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Tu dois être connecté pour voter.');
    }

    final voteRef = _emissionRef.collection('pollVotes').doc(user.uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_emissionRef);
      if (!snap.exists) {
        throw StateError('Aucun sondage emission disponible.');
      }
      final data = snap.data() ?? <String, dynamic>{};
      if (_isExpired(data)) {
        tx.set(
          _emissionRef,
          _buildClosePayload(data, reason: 'timeout'),
          SetOptions(merge: true),
        );
        throw StateError('Le sondage est maintenant clos.');
      }
      if ((data['pollStatus'] as String? ?? '').trim() != 'active') {
        throw StateError('Le sondage est clos.');
      }
      final option = optionById(data, optionId);
      if (option == null) {
        throw StateError('Ce choix n\'est plus disponible.');
      }

      final sessionId = (data['pollSessionId'] as String? ?? '').trim();
      final previousSnap = await tx.get(voteRef);
      final previousData = previousSnap.data() ?? <String, dynamic>{};
      final previousSessionId = (previousData['sessionId'] as String? ?? '')
          .trim();
      final previousOptionId = previousSessionId == sessionId
          ? (previousData['optionId'] as String? ?? '').trim()
          : '';

      if (previousOptionId == optionId) return;

      final counts = optionCounts(data);
      var total = totalVotes(data);

      if (previousOptionId.isNotEmpty) {
        counts[previousOptionId] = ((counts[previousOptionId] ?? 0) - 1).clamp(
          0,
          999999,
        );
      } else {
        total += 1;
      }
      counts[optionId] = (counts[optionId] ?? 0) + 1;

      tx.set(_emissionRef, {
        'pollCounts': counts,
        'pollTotal': total,
        'pollUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(voteRef, {
        'uid': user.uid,
        'sessionId': sessionId,
        'optionId': optionId,
        'optionLabel': (option['label'] as String? ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!previousSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> stopPoll({String reason = 'manual'}) async {
    Map<String, dynamic> originalData = <String, dynamic>{};
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_emissionRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      originalData = data;
      final status = (data['pollStatus'] as String? ?? '').trim();
      if (status.isEmpty || status == 'closed') return;
      tx.set(
        _emissionRef,
        _buildClosePayload(data, reason: reason),
        SetOptions(merge: true),
      );
    });
    if (originalData.isNotEmpty) {
      await VoteHistoryService.archiveEmissionPoll({
        ...originalData,
        ..._buildClosePayload(originalData, reason: reason),
      });
    }
  }

  static Future<void> ensurePollState(Map<String, dynamic> data) async {
    if (_isExpired(data)) {
      await stopPoll(reason: 'timeout');
    }
  }

  static bool hasVisiblePoll(Map<String, dynamic> data) {
    final status = (data['pollStatus'] as String? ?? '').trim();
    return (status == 'active' || status == 'closed') &&
        optionMaps(data).isNotEmpty;
  }

  static bool isPollActive(Map<String, dynamic> data) {
    if (_isExpired(data)) return false;
    return (data['pollStatus'] as String? ?? '').trim() == 'active';
  }

  static bool shouldRevealResults(Map<String, dynamic> data) {
    return data['pollRevealResults'] != false;
  }

  static List<Map<String, dynamic>> optionMaps(Map<String, dynamic> data) {
    final raw = data['pollOptions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic>? optionById(
    Map<String, dynamic> data,
    String optionId,
  ) {
    for (final option in optionMaps(data)) {
      if ((option['id'] as String? ?? '').trim() == optionId.trim()) {
        return option;
      }
    }
    return null;
  }

  static Map<String, int> optionCounts(Map<String, dynamic> data) {
    final raw = data['pollCounts'];
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  static int totalVotes(Map<String, dynamic> data) {
    return (data['pollTotal'] as num?)?.toInt() ?? 0;
  }

  static Map<String, dynamic> _buildClosePayload(
    Map<String, dynamic> data, {
    required String reason,
  }) {
    final counts = optionCounts(data);
    final options = optionMaps(data);
    String winnerId = '';
    String winnerLabel = '';
    var winnerVotes = -1;
    for (final option in options) {
      final optionId = (option['id'] as String? ?? '').trim();
      final votes = counts[optionId] ?? 0;
      if (votes > winnerVotes) {
        winnerVotes = votes;
        winnerId = optionId;
        winnerLabel = (option['label'] as String? ?? '').trim();
      }
    }
    return {
      'pollEnabled': true,
      'pollStatus': 'closed',
      'pollClosedAt': FieldValue.serverTimestamp(),
      'pollWinnerId': winnerId,
      'pollWinnerLabel': winnerLabel,
      'pollEndedReason': reason,
      'pollCounts': counts,
      'pollTotal': totalVotes(data),
    };
  }

  static List<String> _cleanOptions(List<String> options) {
    return options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet()
        .toList();
  }

  static bool _isExpired(Map<String, dynamic> data) {
    final endsAt = data['pollEndsAt'];
    if (endsAt is! Timestamp) return false;
    return endsAt.toDate().isBefore(DateTime.now());
  }
}
