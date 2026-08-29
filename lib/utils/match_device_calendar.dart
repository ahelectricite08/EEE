import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/match_model.dart';
import '../screens/matches/matches_helpers.dart';
import '../services/dvcr_share_service.dart';
import 'stadium_maps_launcher.dart';

/// Ajout d’un match au calendrier téléphone — un flux (.ics), pas 4 boutons.
abstract final class MatchDeviceCalendar {
  MatchDeviceCalendar._();

  static const eventDuration = Duration(hours: 2);

  /// FFF / admin : minuit = heure inconnue (pas un vrai coup d’envoi).
  static bool hasKnownKickoff(DateTime date) =>
      date.hour != 0 || date.minute != 0;

  static bool canAdd(MatchModel match) => hasKnownKickoff(match.date);

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
    final bits = <String>['CSSA', 'Coup d’envoi'];
    if (comp.isNotEmpty) bits.add(comp);
    return bits.join(' · ');
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
    final start = match.date;
    final end = eventEnd(start);
    final stamp = stampedAt ?? DateTime.now();
    final title = _escapeText(eventTitle(match));
    final desc = _escapeText(eventDescription(match));
    final loc = eventLocation(match);
    final uid = 'dvcr-match-${match.id}@dvcr.app';
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//DVCR//CSSA//FR',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:${icsUtcStamp(stamp)}',
      'DTSTART:${icsUtcStamp(start)}',
      'DTEND:${icsUtcStamp(end)}',
      'SUMMARY:$title',
      'DESCRIPTION:$desc',
      if (loc != null) 'LOCATION:${_escapeText(loc)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return '${lines.join('\r\n')}\r\n';
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

      final ics = buildIcs(match);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/cssa_${match.id}.ics';
      final file = File(path);
      await file.writeAsString(ics, flush: true);
      if (!context.mounted) return;

      await DvcrShare.shareLocalFiles(
        [
          XFile(
            path,
            mimeType: 'text/calendar',
            name: 'cssa_match.ics',
          ),
        ],
        subject: eventTitle(match),
        context: context,
      );
    } catch (_) {
      if (context.mounted) _snack(context, fail: true);
    }
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
