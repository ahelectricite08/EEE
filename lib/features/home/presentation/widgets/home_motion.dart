import 'package:flutter/material.dart';

/// Entrée douce (fade + léger slide) pour le contenu home — une seule fois au montage.
class HomeReveal extends StatefulWidget {
  const HomeReveal({
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.slideBegin = const Offset(0, 0.055),
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  /// Fraction du parent (ex. dy 0.05 = 5 % vers le bas au départ).
  final Offset slideBegin;
  final Widget child;

  @override
  State<HomeReveal> createState() => _HomeRevealState();
}

class _HomeRevealState extends State<HomeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: widget.slideBegin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    // Sans ceci, le 1er frame est à opacité 0 : écran « vide » jusqu’au microtask
    // (très visible sur Profil où delay = Duration.zero sur le héro).
    if (widget.delay == Duration.zero) {
      _controller.value = 1;
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Léger scale au press (le child gère le tap / navigation).
class HomeScaleOnPress extends StatefulWidget {
  const HomeScaleOnPress({
    super.key,
    required this.child,
    this.minScale = 0.988,
  });

  final Widget child;
  final double minScale;

  @override
  State<HomeScaleOnPress> createState() => _HomeScaleOnPressState();
}

class _HomeScaleOnPressState extends State<HomeScaleOnPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.minScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
