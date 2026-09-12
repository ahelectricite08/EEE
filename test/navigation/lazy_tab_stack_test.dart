import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/navigation/lazy_tab_stack.dart';

class _BuildProbe extends StatefulWidget {
  final String label;
  final void Function() onInit;

  const _BuildProbe({required Key key, required this.label, required this.onInit})
      : super(key: key);

  @override
  State<_BuildProbe> createState() => _BuildProbeState();
}

class _BuildProbeState extends State<_BuildProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  testWidgets('builds only the current tab until another is visited', (
    tester,
  ) async {
    final inits = <String>[];
    var index = 0;

    Widget stack() {
      return MaterialApp(
        home: LazyTabStack(
          index: index,
          children: [
            _BuildProbe(
              key: const ValueKey('home'),
              label: 'HOME',
              onInit: () => inits.add('home'),
            ),
            _BuildProbe(
              key: const ValueKey('live'),
              label: 'LIVE',
              onInit: () => inits.add('live'),
            ),
            _BuildProbe(
              key: const ValueKey('actus'),
              label: 'ACTUS',
              onInit: () => inits.add('actus'),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(stack());
    expect(inits, ['home']);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    index = 1;
    await tester.pumpWidget(stack());
    await tester.pump();
    expect(inits, ['home', 'live']);
    expect(find.text('LIVE'), findsOneWidget);

    index = 0;
    await tester.pumpWidget(stack());
    await tester.pump();
    expect(inits, ['home', 'live']);
  });
}
