import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../matches/matches_helpers.dart';
import '../theme/calendar_theme.dart';
import '../theme/calendar_type.dart';

/// En-tête de jour — même gouttière que les lignes de match (dialogue Pronos).
class CalendarDateHeader extends StatelessWidget {
  final DateTime date;

  const CalendarDateHeader({super.key, required this.date});

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('EEEE', 'fr_FR').format(date);
    final month = frenchMonthShort(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(CalendarTheme.gutter, 22, 0, 10),
      child: Row(
        children: [
          SizedBox(
            width: CalendarTheme.timeGutter,
            child: Text(
              '${date.day}',
              style: CalendarType.numeralGutter.copyWith(
                color: CalendarTheme.accent,
              ),
            ),
          ),
          Flexible(
            child: Text(
              '${_cap(weekday).toUpperCase()}  ·  ${_cap(month).toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CalendarType.kicker.copyWith(color: CalendarTheme.text),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: CalendarTheme.gutter),
              child: ColoredBox(
                color: CalendarTheme.border,
                child: SizedBox(height: 1, width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
