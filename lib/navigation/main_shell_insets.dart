import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared bottom clearance for [MainNavigation]'s floating pill nav, device
/// safe areas (home indicator), and modal bottom sheets.
abstract final class MainShellInsets {
  /// Inner height of the floating main-nav pill (excludes outer margins).
  static double mainNavBarHeight({required int tabCount}) =>
      tabCount >= 6 ? 60.0 : 54.0;

  /// Top + bottom margins around the pill in [MainNavigation._buildBottomNav].
  static const double mainNavOuterVertical = 16.0;

  /// Full vertical space occupied by the floating pill + its outer padding
  /// (excludes device home-indicator — add [safeBottom] when needed).
  static double floatingNavExtent({int tabCount = 6}) =>
      mainNavBarHeight(tabCount: tabCount) + mainNavOuterVertical;

  /// Device home-indicator / gesture inset (use in modals & bottom sheets).
  static double safeBottom(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom;

  /// Keyboard inset when a sheet field is focused.
  static double keyboardBottom(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom;

  /// Bottom tail for scrollables inside [MainNavigation] tab bodies.
  ///
  /// Nested [Scaffold]s often strip the outer `MediaQuery.padding.bottom` that
  /// `extendBody` injects for the floating nav — so we always take the max of
  /// the ambient padding and an explicit floating-nav reserve.
  static double tabScrollTail(BuildContext context, {double extra = 16}) {
    final ambient = MediaQuery.paddingOf(context).bottom;
    final reserve = floatingNavExtent() + safeBottom(context);
    return math.max(ambient, reserve) + extra;
  }

  /// Bottom padding for modal bottom-sheet content (safe area + keyboard).
  /// Prefer [showDvcrModalBottomSheet] (`useRootNavigator: true`) so the sheet
  /// sits above the floating nav; then only safe/keyboard insets are needed.
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

/// App-wide modal bottom sheet: always on the root navigator so it paints
/// **above** [MainNavigation]'s floating bar (and any nested tab navigators).
Future<T?> showDvcrModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  Color? barrierColor,
  double? elevation,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  bool useSafeArea = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    elevation: elevation,
    clipBehavior: clipBehavior,
    constraints: constraints,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    useSafeArea: useSafeArea,
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
    builder: builder,
  );
}
