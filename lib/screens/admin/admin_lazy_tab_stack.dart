import 'package:flutter/material.dart';

import 'admin_nav_model.dart';

/// Charge un onglet seulement à la première visite, puis le garde vivant.
class AdminLazyTabStack extends StatefulWidget {
  final int currentIndex;
  final List<AdminTabDef> tabs;

  const AdminLazyTabStack({
    super.key,
    required this.currentIndex,
    required this.tabs,
  });

  @override
  State<AdminLazyTabStack> createState() => _AdminLazyTabStackState();
}

class _AdminLazyTabStackState extends State<AdminLazyTabStack> {
  final Set<int> _built = {};

  @override
  void initState() {
    super.initState();
    _built.add(widget.currentIndex);
  }

  @override
  void didUpdateWidget(AdminLazyTabStack old) {
    super.didUpdateWidget(old);
    if (!_built.contains(widget.currentIndex)) {
      setState(() => _built.add(widget.currentIndex));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.tabs.map((def) {
        final isActive = def.index == widget.currentIndex;
        final wasBuilt = _built.contains(def.index);
        if (!wasBuilt) return const SizedBox.shrink();
        return Offstage(
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: _KeepAliveWrapper(child: def.builder(context)),
          ),
        );
      }).toList(),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
