import 'package:flutter/material.dart';

/// Onglets du [MainNavigation] (barre du bas).
enum AppShellTab { home, live, matches, articles, chat, prono }

class AppShellNavigationRequest {
  final AppShellTab tab;
  final int? matchesSubTab;
  final int? pronoSubTab;
  final bool popRootOverlays;
  final Future<void> Function()? afterSelected;

  const AppShellNavigationRequest({
    required this.tab,
    this.matchesSubTab,
    this.pronoSubTab,
    this.popRootOverlays = true,
    this.afterSelected,
  });
}

/// Pont entre FCM / notifs locales et le shell à onglets.
abstract final class AppShellNavigation {
  static void Function(AppShellNavigationRequest request)? _onRequest;
  static GlobalKey<NavigatorState>? homeTabNavigatorKey;

  static void register({
    required void Function(AppShellNavigationRequest request) onRequest,
    required GlobalKey<NavigatorState> homeNavigatorKey,
  }) {
    _onRequest = onRequest;
    homeTabNavigatorKey = homeNavigatorKey;
  }

  static void unregister() {
    _onRequest = null;
    homeTabNavigatorKey = null;
  }

  static void dispatch(AppShellNavigationRequest request) {
    _onRequest?.call(request);
  }

  static void goToTab(
    AppShellTab tab, {
    int? matchesSubTab,
    int? pronoSubTab,
    bool popRootOverlays = true,
    Future<void> Function()? afterSelected,
  }) {
    dispatch(
      AppShellNavigationRequest(
        tab: tab,
        matchesSubTab: matchesSubTab,
        pronoSubTab: pronoSubTab,
        popRootOverlays: popRootOverlays,
        afterSelected: afterSelected,
      ),
    );
  }
}
