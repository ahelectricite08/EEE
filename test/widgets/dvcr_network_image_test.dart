import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/widgets/dvcr_network_image.dart';

void main() {
  testWidgets('cacheWidth follows logical size × DPR', (tester) async {
    late int stadium;
    late int crest;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800), devicePixelRatio: 2),
        child: Builder(
          builder: (context) {
            stadium = dvcrStadiumCacheWidth(context);
            crest = dvcrCrestCacheWidth(context, 54);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(stadium, 800);
    expect(crest, 108);
  });
}
