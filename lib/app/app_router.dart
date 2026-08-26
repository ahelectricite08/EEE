import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../screens/admin_web_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/match_detail_screen.dart';
import '../navigation/app_shell_navigation.dart';
import '../navigation/community_chat_rollout.dart';
import '../navigation/prono_championship_rollout.dart';
import '../services/article_service.dart';
import '../services/match_service.dart';
import '../services/live_match_activity_service.dart';

/// Global navigator for FCM / local notification taps and [MaterialApp].
final GlobalKey<NavigatorState> dvcrNavigatorKey = GlobalKey<NavigatorState>();

Map<String, WidgetBuilder> buildDvcrAppRoutes() {
  return {
    '/register': (ctx) => RegisterScreen(
      onBrowseArticlesAsGuest: () {
        Navigator.of(ctx).pushNamedAndRemoveUntil('/', (route) => false);
      },
      onBackToGuest: () {
        Navigator.of(ctx).pushNamedAndRemoveUntil('/', (route) => false);
      },
    ),
    '/login': (_) => const LoginScreen(),
    '/calendar': (_) => const CalendarScreen(),
    '/admin': (_) => const AdminWebScreen(),
  };
}

void handleDvcrNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;

  if (payload == 'live_score_sticky') {
    AppShellNavigation.goToTab(AppShellTab.home);
    return;
  }

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
  } catch (_) {
    AppShellNavigation.goToTab(AppShellTab.home);
  }
}

Future<void> _pushRouteOnRoot(Widget Function(BuildContext) builder) async {
  final navigator = dvcrNavigatorKey.currentState;
  if (navigator == null || !navigator.mounted) return;
  await navigator.push(MaterialPageRoute(builder: builder));
}

void _snack(String message) {
  final ctx = dvcrNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// Ouvre l’écran le plus pertinent : onglet du shell + page cible si connue, sinon accueil.
Future<void> pushScreenForNotificationData(Map<String, dynamic> data) async {
  if (dvcrNavigatorKey.currentState == null) return;

  final type = (data['type'] ?? '').toString().trim();
  final articleId = (data['articleId'] ?? '').toString().trim();
  final matchId = (data['matchId'] ?? '').toString().trim();

  switch (type) {
    case 'article':
      if (articleId.isNotEmpty) {
        AppShellNavigation.goToTab(
          AppShellTab.articles,
          afterSelected: () async {
            final article = await ArticleService.byId(articleId);
            if (article == null) return;
            await _pushRouteOnRoot(
              (_) => ArticleDetailScreen(article: article),
            );
          },
        );
      } else {
        AppShellNavigation.goToTab(AppShellTab.articles);
      }
      return;

    case 'match_reminder':
    case 'match_recap':
      if (matchId.isNotEmpty) {
        AppShellNavigation.goToTab(
          AppShellTab.matches,
          afterSelected: () async {
            final match = await MatchService.byId(matchId);
            if (match == null) return;
            await _pushRouteOnRoot(
              (_) => MatchDetailScreen(match: match),
            );
          },
        );
      } else {
        AppShellNavigation.goToTab(AppShellTab.matches);
      }
      return;

    case 'duel':
    case 'duel_result':
    case 'friend_request':
    case 'ranking_motivation':
    case 'prono_rankings_reset':
    case 'prono_day_recap':
      if (!PronoChampionshipRollout.isHubVisible) {
        AppShellNavigation.goToTab(AppShellTab.home);
        _snack('Les pronos championnat ne sont pas encore disponibles.');
        return;
      }
      final openMatches = type == 'prono_day_recap' ||
          (data['pronoTab'] ?? '').toString().trim() == 'matches';
      AppShellNavigation.goToTab(
        AppShellTab.prono,
        pronoSubTab: openMatches ? 1 : null,
      );
      return;

    case 'wc_prono_points':
      AppShellNavigation.goToTab(AppShellTab.home);
      return;

    case 'chat_mention':
      if (!CommunityChatRollout.isVisible) {
        AppShellNavigation.goToTab(AppShellTab.home);
        _snack('Le chat communauté n’est pas encore disponible.');
        return;
      }
      AppShellNavigation.goToTab(AppShellTab.chat);
      return;

    case 'emission':
    case 'live_start':
    case 'kickoff':
    case 'goal':
    case 'offside':
    case 'goal_cancelled':
    case 'goal_disallowed':
    case 'yellow_card':
    case 'red_card':
    case 'substitution':
    case 'halftime':
    case 'fulltime':
    case 'extra_time':
    case 'extra_halftime':
    case 'extra_fulltime':
      unawaited(LiveMatchActivityService.markStartAfterUserOpenedApp());
      AppShellNavigation.goToTab(AppShellTab.home);
      return;

    case 'benevole_pdf':
    case 'reminder_admin_manual':
    case 'badge':
      AppShellNavigation.goToTab(AppShellTab.home);
      return;

    default:
      AppShellNavigation.goToTab(AppShellTab.home);
  }
}

