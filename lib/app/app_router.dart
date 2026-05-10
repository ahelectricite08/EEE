import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../screens/admin_web_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/live_screen.dart';
import '../screens/login_screen.dart';
import '../screens/match_detail_screen.dart';
import '../screens/matches_screen.dart';
import '../screens/notifications_center_screen.dart';
import '../screens/world_cup_tab.dart';
import '../features/prono/prono_public.dart';
import '../navigation/prono_championship_rollout.dart';
import '../navigation/world_cup_tab_rollout.dart';
import '../screens/register_screen.dart';
import '../services/article_service.dart';
import '../services/match_service.dart';

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
      unawaited(pushScreenForNotificationData(decoded));
    } else if (decoded is Map) {
      unawaited(
        pushScreenForNotificationData(
          decoded.map((key, value) => MapEntry('$key', value)),
        ),
      );
    }
  } catch (_) {}
}

/// Ouvre l’écran le plus pertinent selon le `type` et les ids fournis par FCM
/// ou par les notifs locales (payload JSON).
Future<void> pushScreenForNotificationData(Map<String, dynamic> data) async {
  final navigator = dvcrNavigatorKey.currentState;
  if (navigator == null) return;

  final type = (data['type'] ?? '').toString();
  final articleId = (data['articleId'] ?? '').toString();
  final matchId = (data['matchId'] ?? '').toString();

  switch (type) {
    case 'article':
      if (articleId.isNotEmpty) {
        final article = await ArticleService.byId(articleId);
        if (article != null && navigator.mounted) {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
          return;
        }
      }
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const ArticlesScreen()),
        );
      }
      return;

    case 'match_reminder':
    case 'match_recap':
    case 'fulltime':
    case 'halftime':
      if (matchId.isNotEmpty) {
        final match = await MatchService.byId(matchId);
        if (match != null && navigator.mounted) {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(match: match),
            ),
          );
          return;
        }
      }
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const MatchesScreen()),
        );
      }
      return;

    case 'duel':
    case 'duel_result':
    case 'friend_request':
    case 'ranking_motivation':
      if (!PronoChampionshipRollout.isHubVisible) {
        final ctx = navigator.context;
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Les pronos championnat ne sont pas encore disponibles.',
              ),
            ),
          );
        }
        return;
      }
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const PronoRootShell(),
          ),
        );
      }
      return;

    case 'wc_prono_points':
      if (!WorldCupTabRollout.isTabVisible) {
        final ctx = navigator.context;
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'La Coupe du monde dans l’app n’est pas disponible pour le moment.',
              ),
            ),
          );
        }
        return;
      }
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const WorldCupTab()),
        );
      }
      return;

    case 'chat_mention':
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
      return;

    case 'emission':
    case 'kickoff':
    case 'goal':
    case 'offside':
    case 'yellow_card':
    case 'red_card':
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const LiveScreen()),
        );
      }
      return;

    default:
      if (navigator.mounted) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const NotificationsCenterScreen(),
          ),
        );
      }
  }
}
