import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/match_model.dart';
import '../screens/matches/matches_helpers.dart';
import 'stadium_maps_launcher.dart';

/// Ajout d’un match au calendrier téléphone — un flux (.ics), pas 4 boutons.
abstract final class MatchDeviceCalendar {
  MatchDeviceCalendar._();

  static const eventDuration = Duration(hours: 2);

  /// FFF / admin : minuit = heure inconnue (pas un vrai coup d’envoi).
  static bool hasKnownKickoff(DateTime date) =>
      date.hour != 0 || date.minute != 0;

  static bool canAdd(MatchModel match) => hasKnownKickoff(match.date);

  /// Identifiant iCalendar stable — réimport possible sans 40 doublons
  /// si l’app Calendrier honore l’UID (Google / Apple ne le font pas toujours).
  static String eventUid(MatchModel match) =>
      'dvcr-match-${match.id}@dvcr.app';

  /// Titre club : `CSSA – [adversaire]`, sinon `équipe – équipe`.
  static String eventTitle(MatchModel match) {
    final t1 = match.team1.trim();
    final t2 = match.team2.trim();
    final sedanHome = isSedanTeam(t1);
    final sedanAway = isSedanTeam(t2);
    if (sedanHome && !sedanAway) return 'CSSA – $t2';
    if (sedanAway && !sedanHome) return 'CSSA – $t1';
    return '$t1 – $t2';
  }

  static String? eventLocation(MatchModel match) {
    final q = StadiumMapsLauncher.resolveQuery(match);
    if (q == null || q.trim().isEmpty) return null;
    return q.trim();
  }

  static DateTime eventEnd(DateTime kickoff) =>
      kickoff.add(eventDuration);

  static String eventDescription(MatchModel match) {
    final comp = match.competition.trim();
    final sedan = isSedanTeam(match.team1) || isSedanTeam(match.team2);
    final bits = <String>[
      if (sedan) 'CSSA' else 'DVCR',
      if (hasKnownKickoff(match.date)) 'Coup d’envoi' else 'Heure à confirmer',
    ];
    if (comp.isNotEmpty) bits.add(comp);
    return bits.join(' · ');
  }

  static String icsDateStamp(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${p(dt.month)}${p(dt.day)}';
  }

  static String icsUtcStamp(DateTime dt) {
    final u = dt.toUtc();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${p(u.month)}${p(u.day)}T${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
  }

  static String _escapeText(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n');
  }

  /// Fichier iCalendar (RFC 5545) — iOS / Android ouvrent l’app Calendrier.
  static String buildIcs(MatchModel match, {DateTime? stampedAt}) {
    return buildIcsCalendar([match], stampedAt: stampedAt);
  }

  /// Calendrier multi-matchs (un VEVENT par fiche, même UID que [buildIcs]).
  static String buildIcsCalendar(
    List<MatchModel> matches, {
    DateTime? stampedAt,
  }) {
    final stamp = stampedAt ?? DateTime.now();
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//DVCR//CSSA//FR',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      for (final match in matches) ..._veventLines(match, stamp),
      'END:VCALENDAR',
    ];
    return '${lines.join('\r\n')}\r\n';
  }

  static List<String> _veventLines(MatchModel match, DateTime stamp) {
    final title = _escapeText(eventTitle(match));
    final desc = _escapeText(eventDescription(match));
    final loc = eventLocation(match);
    final timed = hasKnownKickoff(match.date);
    return [
      'BEGIN:VEVENT',
      'UID:${eventUid(match)}',
      'DTSTAMP:${icsUtcStamp(stamp)}',
      if (timed) 'DTSTART:${icsUtcStamp(match.date)}',
      if (timed) 'DTEND:${icsUtcStamp(eventEnd(match.date))}',
      if (!timed)
        'DTSTART;VALUE=DATE:${icsDateStamp(DateTime(match.date.year, match.date.month, match.date.day))}',
      if (!timed)
        'DTEND;VALUE=DATE:${icsDateStamp(DateTime(match.date.year, match.date.month, match.date.day + 1))}',
      'SUMMARY:$title',
      'DESCRIPTION:$desc',
      if (loc != null) 'LOCATION:${_escapeText(loc)}',
      'END:VEVENT',
    ];
  }

  static Uri googleCalendarUrl(MatchModel match) {
    final start = icsUtcStamp(match.date);
    final end = icsUtcStamp(eventEnd(match.date));
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': eventTitle(match),
      'dates': '$start/$end',
      'details': eventDescription(match),
      if (eventLocation(match) != null) 'location': eventLocation(match)!,
    });
  }

  static Future<void> addToDevice(BuildContext context, MatchModel match) async {
    if (!canAdd(match)) return;

    try {
      if (kIsWeb) {
        final ok = await launchUrl(
          googleCalendarUrl(match),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && context.mounted) _snack(context, fail: true);
        return;
      }

      final result = await shareIcsFile(
        context,
        ics: buildIcs(match),
        fileName: 'cssa_${match.id}.ics',
        subject: eventTitle(match),
      );
      if (result == MatchCalendarShareResult.failed && context.mounted) {
        _snack(context, fail: true);
      }
    } catch (_) {
      if (context.mounted) _snack(context, fail: true);
    }
  }

  /// Partage un .ics (un ou plusieurs matchs). Pas d’API Calendrier native :
  /// pas de permission EventKit / WRITE_CALENDAR — l’app Calendrier importe.
  static Future<MatchCalendarShareResult> shareIcsFile(
    BuildContext context, {
    required String ics,
    required String fileName,
    String? subject,
  }) async {
    if (kIsWeb) return MatchCalendarShareResult.unsupported;
    try {
      final dir = await getTemporaryDirectory();
      final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final path = '${dir.path}/$safe';
      await File(path).writeAsString(ics, flush: true);
      if (!context.mounted) return MatchCalendarShareResult.cancelled;

      Rect? originRect;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        originRect = box.localToGlobal(Offset.zero) & box.size;
      }

      final result = await Share.shareXFiles(
        [
          XFile(
            path,
            mimeType: 'text/calendar',
            name: safe.endsWith('.ics') ? safe : '$safe.ics',
          ),
        ],
        subject: subject,
        sharePositionOrigin: originRect,
      );
      switch (result.status) {
        case ShareResultStatus.success:
          return MatchCalendarShareResult.shared;
        case ShareResultStatus.dismissed:
          return MatchCalendarShareResult.cancelled;
        case ShareResultStatus.unavailable:
          return MatchCalendarShareResult.failed;
      }
    } catch (_) {
      return MatchCalendarShareResult.failed;
    }
  }

  static Future<MatchCalendarShareResult> addManyToDevice(
    BuildContext context,
    List<MatchModel> matches, {
    String fileName = 'dvcr_matchs.ics',
    String? subject,
  }) async {
    if (kIsWeb) return MatchCalendarShareResult.unsupported;
    if (matches.isEmpty) return MatchCalendarShareResult.failed;
    return shareIcsFile(
      context,
      ics: buildIcsCalendar(matches),
      fileName: fileName,
      subject: subject,
    );
  }

  static void _snack(BuildContext context, {required bool fail}) {
    if (!fail) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impossible d’ajouter au calendrier.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum MatchCalendarShareResult {
  shared,
  cancelled,
  failed,
  unsupported,
}
