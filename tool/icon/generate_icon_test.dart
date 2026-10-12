// Draws the launcher icon. Not part of the normal test run; use:
//   flutter test tool/icon --update-goldens && cp tool/icon/icon_*.png assets/icon/
//   dart run flutter_launcher_icons
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_down/orders.dart';
import 'package:phone_down/theme.dart';
import 'package:phone_down/widgets/table_view.dart';

/// A phone face down on the table, a cortado beside it.
class _Icon extends StatelessWidget {
  const _Icon({required this.background});

  /// False for the adaptive foreground layer, which sits on its own colour.
  final bool background;

  @override
  Widget build(BuildContext context) {
    // The adaptive foreground keeps its art inside the middle 66%.
    final s = background ? 1.0 : 0.72;
    return Container(
      color: background ? Brew.paper : Colors.transparent,
      child: Center(
        child: SizedBox.square(
          dimension: 1024 * s,
          child: Stack(
            children: [
              Positioned(
                left: 250 * s,
                top: 130 * s,
                child: Transform.rotate(
                  angle: -math.pi * 0.09,
                  child: PhoneTile(
                    pose: PhonePose.down,
                    order: Order.cortado,
                    width: 340 * s,
                  ),
                ),
              ),
              Positioned(
                left: 560 * s,
                top: 560 * s,
                child: CupGlyph(Order.cortado, size: 330 * s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  for (final (name, bg) in [('icon_full', true), ('icon_foreground', false)]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1024, 1024);
      tester.view.devicePixelRatio = 1;
      debugDisableShadows = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(child: _Icon(background: bg)),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('$name.png'),
      );
      debugDisableShadows = true;
    });
  }
}
