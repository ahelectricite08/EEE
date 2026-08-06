import 'package:flutter/material.dart';

/// Shared bottom clearance for [MainNavigation]'s floating pill nav, device
/// safe areas (home indicator), and modal bottom sheets.
abstract final class MainShellInsets {
  /// Inner height of the floating main-nav pill (excludes outer margins).
  static double mainNavBarHeight({required int tabCount}) =>
      tabCount >= 6 ? 60.0 : 54.0;

  /// Top + bottom margins around the pill in [MainNavigation._buildBottomNav].
  static const double mainNavOuterVertical = 16.0;

  /// Device home-indicator / gesture inset (use in modals & bottom sheets).
  static double safeBottom(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom;

  /// Keyboard inset when a sheet field is focused.
  static double keyboardBottom(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom;

  /// Bottom tail for scrollables inside [MainNavigation] tab bodies.
  /// With `extendBody: true`, [MediaQuery.padding.bottom] already includes the
  /// floating nav height injected by the scaffold body builder.
  static double tabScrollTail(BuildContext context, {double extra = 16}) =>
      MediaQuery.paddingOf(context).bottom + extra;

  /// Bottom padding for modal bottom-sheet content (safe area + keyboard).
  static double sheetBottom(BuildContext context, {double extra = 16}) =>
      safeBottom(context) + keyboardBottom(context) + extra;

  static EdgeInsets sheetContentPadding(
    BuildContext context, {
    double left = 20,
    double top = 16,
    double right = 20,
    double extra = 16,
  }) =>
      EdgeInsets.fromLTRB(
        left,
        top,
        right,
        sheetBottom(context, extra: extra),
      );

  static EdgeInsets listBottom(BuildContext context, {double extra = 16}) =>
      EdgeInsets.only(bottom: tabScrollTail(context, extra: extra));
}
