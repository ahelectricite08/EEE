import 'package:flutter/material.dart';

/// Monte un onglet à la première visite, puis le garde hors écran (état conservé).
///
/// Contrairement à [IndexedStack], les onglets jamais ouverts n’exécutent pas
/// `initState` (pas de streams Firestore, pas de décodage d’images).
///
/// Identité = [Widget.key] (ex. `ValueKey` sémantique), pas l’index — les
/// onglets Chat / Pronos peuvent apparaître sans recycler un autre State.
class LazyTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyTabStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyTabStack> createState() => _LazyTabStackState();
}

class _LazyTabStackState extends State<LazyTabStack> {
  final Set<Object> _builtIds = <Object>{};

  int get _safeIndex {
    if (widget.children.isEmpty) return 0;
    return widget.index.clamp(0, widget.children.length - 1);
  }

  Object _idFor(int i) {
    final key = widget.children[i].key;
    if (key is ValueKey) return key.value ?? i;
    return key ?? i;
  }

  void _markCurrentBuilt() {
    if (widget.children.isEmpty) return;
    _builtIds.add(_idFor(_safeIndex));
  }

  @override
  void initState() {
    super.initState();
    _markCurrentBuilt();
  }

  @override
  void didUpdateWidget(LazyTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _markCurrentBuilt();
  }

  @override
  Widget build(BuildContext context) {
    final current = _safeIndex;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_builtIds.contains(_idFor(i)))
            Offstage(
              offstage: i != current,
              child: TickerMode(
                enabled: i == current,
                child: widget.children[i],
              ),
            ),
      ],
    );
  }
}
