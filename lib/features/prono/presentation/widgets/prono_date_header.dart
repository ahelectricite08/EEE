import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';

/// En-tête de jour — masthead calendrier (jour géant + filet).
class PronoDateHeader extends StatelessWidget {
  final DateTime date;

  const PronoDateHeader({super.key, required this.date});

  static String labelFor(DateTime date, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Aujourd’hui';
    if (diff == 1) return 'Demain';
    if (diff == -1) return 'Hier';
    final raw = DateFormat('EEEE d MMMM', 'fr_FR').format(date);
    if (raw.isEmpty) return raw;
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('EEEE', 'fr_FR').format(date);
    final month = DateFormat('MMM', 'fr_FR').format(date);

    // Gouttière : le chiffre du jour aligné sur la même colonne que l’heure
    // des lignes de match — l’axe vertical du calendrier.
    return Padding(
      padding: const EdgeInsets.fromLTRB(PronoArenaTheme.gutter, 24, 0, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${date.day}',
              style: PronoType.numeralGutter.copyWith(
                color: PronoPageAccent.matchs.color,
              ),
            ),
          ),
          Text(
            '${_cap(weekday).toUpperCase()}  ·  ${_cap(month).toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.kicker.copyWith(color: PronoTokens.text),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: PronoArenaTheme.gutter),
              child: ColoredBox(
                color: PronoTokens.border,
                child: SizedBox(height: 1, width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
