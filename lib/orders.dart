import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// What you drink. It's your avatar, and it's what the loser buys you.
enum Order {
  espresso('Espresso', Color(0xFF3B2116), null, 0.46),
  cortado('Cortado', Color(0xFF8A5634), Color(0xFFE9D3B4), 0.52),
  flatWhite('Flat white', Color(0xFFB07A4C), Color(0xFFF1E2CB), 0.62),
  cappuccino('Cappuccino', Color(0xFFA06A40), Color(0xFFF6EBDA), 0.66),
  latte('Latte', Color(0xFFC3936A), Color(0xFFF7EEDF), 0.72),
  mocha('Mocha', Color(0xFF5C3423), Color(0xFFD8B79A), 0.68),
  americano('Americano', Color(0xFF2E1A12), null, 0.7),
  matcha('Matcha', Color(0xFF8DA65A), Color(0xFFE6EDD2), 0.7),
  chai('Chai', Color(0xFFC08B57), Color(0xFFF0DDC2), 0.7),
  tea('Tea', Color(0xFFB4652E), null, 0.7);

  const Order(this.label, this.liquid, this.foam, this.size);

  final String label;
  final Color liquid;

  /// Milk on top, drawn as latte art. Null for black drinks.
  final Color? foam;

  /// Cup diameter relative to the glyph box: an espresso is tiny.
  final double size;

  static Order parse(String? name) => Order.values.firstWhere(
    (o) => o.name == name,
    orElse: () => Order.flatWhite,
  );
}

/// A cup on a saucer, seen from above, like the rest of the table.
class CupGlyph extends StatelessWidget {
  const CupGlyph(this.order, {super.key, this.size = 44, this.dark = false});

  final Order order;
  final double size;

  /// On the dark table the saucer picks up the roast colours.
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: CupPainter(order, dark: dark)),
  );
}

class CupPainter extends CustomPainter {
  CupPainter(this.order, {this.dark = false});

  final Order order;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final saucer = r * 0.98;
    final cup = r * order.size;
    final rim = cup * 0.84;

    // Saucer with its soft shadow and a well for the cup.
    canvas.drawCircle(
      c.translate(0, r * 0.05),
      saucer,
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.35 : 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    canvas.drawCircle(
      c,
      saucer,
      Paint()..color = dark ? Brew.roastUp : Brew.card,
    );
    canvas.drawCircle(
      c,
      saucer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = dark ? Brew.roastLine : Brew.line,
    );
    canvas.drawCircle(
      c,
      cup * 1.12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = (dark ? Brew.roastLine : Brew.line).withValues(alpha: 0.7),
    );

    // Handle, out to the lower right like a cup set down by a right hander.
    final angle = math.pi * 0.22;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final handle = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c + dir * (cup * 1.08),
        width: cup * 0.62,
        height: cup * 0.34,
      ),
      Radius.circular(cup * 0.17),
    );
    canvas.save();
    canvas.translate(handle.center.dx, handle.center.dy);
    canvas.rotate(angle);
    canvas.translate(-handle.center.dx, -handle.center.dy);
    canvas.drawRRect(handle, Paint()..color = const Color(0xFFFFFCF6));
    canvas.drawRRect(
      handle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = Brew.line,
    );
    canvas.restore();

    // The porcelain cup.
    canvas.drawCircle(
      c.translate(0, r * 0.03),
      cup,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );
    canvas.drawCircle(c, cup, Paint()..color = const Color(0xFFFFFCF6));
    canvas.drawCircle(
      c,
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = Brew.line,
    );

    // The drink, a touch darker at the edge.
    final drink = Rect.fromCircle(center: c, radius: rim);
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(order.liquid, Colors.white, 0.08)!,
            Color.lerp(order.liquid, Colors.black, 0.25)!,
          ],
        ).createShader(drink),
    );

    final foam = order.foam;
    if (foam != null) {
      _latteArt(canvas, c, rim, foam);
    } else {
      // Crema or a bit of shine on a black drink.
      canvas.drawCircle(
        c.translate(-rim * 0.28, -rim * 0.3),
        rim * 0.22,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rim * 0.12),
      );
    }
  }

  void _latteArt(Canvas canvas, Offset c, double rim, Color foam) {
    final paint = Paint()..color = foam;
    if (order == Order.cortado || order == Order.matcha) {
      // A simple round dot of milk.
      canvas.drawCircle(c, rim * 0.48, paint);
      return;
    }
    if (order == Order.cappuccino || order == Order.chai) {
      // A full foam top with a dusting of cocoa or spice.
      canvas.drawCircle(c, rim * 0.82, paint);
      final dust = Paint()..color = order.liquid.withValues(alpha: 0.55);
      final rnd = math.Random(order.index);
      for (var i = 0; i < 26; i++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final d = math.sqrt(rnd.nextDouble()) * rim * 0.42;
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * d,
          rim * 0.035,
          dust,
        );
      }
      return;
    }
    // A heart: two lobes and a point, plus the pull-through line.
    final s = rim * 0.5;
    final heart = Path()
      ..moveTo(c.dx, c.dy + s * 0.95)
      ..cubicTo(
        c.dx - s * 1.3,
        c.dy + s * 0.1,
        c.dx - s * 0.75,
        c.dy - s * 0.95,
        c.dx,
        c.dy - s * 0.35,
      )
      ..cubicTo(
        c.dx + s * 0.75,
        c.dy - s * 0.95,
        c.dx + s * 1.3,
        c.dy + s * 0.1,
        c.dx,
        c.dy + s * 0.95,
      )
      ..close();
    canvas.drawPath(heart, paint);
    canvas.drawLine(
      Offset(c.dx, c.dy - s * 0.6),
      Offset(c.dx, c.dy + s * 1.1),
      Paint()
        ..color = order.liquid.withValues(alpha: 0.6)
        ..strokeWidth = rim * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(CupPainter old) => old.order != order || old.dark != dark;
}
