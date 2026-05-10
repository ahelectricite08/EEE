import 'package:flutter/material.dart';

/// Transition douce pour les routes Material : léger slide vertical + fondu.
/// Donne un rendu plus « produit fini » que le fade Android par défaut.
class DvcrForwardPageTransitionsBuilder extends PageTransitionsBuilder {
  const DvcrForwardPageTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.028),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
