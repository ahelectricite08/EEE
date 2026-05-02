import 'dart:convert';

import 'package:flutter/material.dart';

import '../screens/admin_web_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/live_screen.dart';
import '../screens/login_screen.dart';
import '../screens/matches_screen.dart';
import '../screens/notifications_center_screen.dart';
import '../screens/register_screen.dart';

/// Global navigator for FCM / local notification taps and [MaterialApp].
final GlobalKey<NavigatorState> dvcrNavigatorKey = GlobalKey<NavigatorState>();

Map<String, WidgetBuilder> buildDvcrAppRoutes() {
  return {
    '/register': (_) => const RegisterScreen(),
    '/login': (_) => const LoginScreen(),
    '/calendar': (_) => const CalendarScreen(),
    '/admin': (_) => const AdminWebScreen(),
  };
}

void handleDvcrNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      pushScreenForNotificationData(decoded);
    } else if (decoded is Map) {
      pushScreenForNotificationData(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
    }
  } catch (_) {}
}

void pushScreenForNotificationData(Map<String, dynamic> data) {
  final navigator = dvcrNavigatorKey.currentState;
  if (navigator == null) return;

  final type = (data['type'] ?? '').toString();
  final Widget screen;
  switch (type) {
    case 'article':
      screen = const ArticlesScreen();
      break;
    case 'chat_mention':
      screen = const ChatScreen();
      break;
    case 'emission':
    case 'kickoff':
    case 'goal':
    case 'yellow_card':
    case 'red_card':
      screen = const LiveScreen();
      break;
    case 'match_reminder':
    case 'match_recap':
    case 'fulltime':
    case 'halftime':
      screen = const MatchesScreen();
      break;
    default:
      screen = const NotificationsCenterScreen();
      break;
  }

  navigator.push(MaterialPageRoute(builder: (_) => screen));
}
