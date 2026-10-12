import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/room.dart';
import '../orders.dart';
import '../theme.dart';

/// How a phone is lying on the table.
enum PhonePose {
  /// Screen up, waiting for the round.
  waiting,

  /// Face down. Good.
  down,

  /// Picked up during the round.
  out,
}

class SeatView {
  const SeatView({
    required this.id,
    required this.name,
    required this.order,
    required this.pose,
    this.me = false,
    this.payer = false,
  });

  final String id;
  final String name;
  final Order order;
  final PhonePose pose;
  final bool me;
  final bool payer;

  static List<SeatView> fromRoom(RoomState s, String meId) => [
    for (final p in s.players)
      SeatView(
        id: p.id,
        name: p.id == meId ? 'You' : p.name,
        order: p.order,
        me: p.id == meId,
        payer: p.id == s.payerId,
        pose: p.isOut
            ? PhonePose.out
            : (p.down ? PhonePose.down : PhonePose.waiting),
      ),
  ];
}

/// The table from above: phones around the edge, whatever you like in the
/// middle. You always sit at the bottom, nearest your own thumb.
class TableView extends StatelessWidget {
  const TableView({
    super.key,
    required this.seats,
    this.center,
    this.dark = false,
    this.showNames = true,
  });

  final List<SeatView> seats;
  final Widget? center;
  final bool dark;
  final bool showNames;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final s = math.min(box.maxWidth, box.maxHeight);
        final labelRoom = showNames ? 40.0 : 6.0;
        final r = s / 2 - labelRoom;
        final c = Offset(box.maxWidth / 2, box.maxHeight / 2);

        // Me at the bottom, everyone else clockwise from there.
        final ordered = [...seats];
        final mine = ordered.indexWhere((x) => x.me);
        if (mine > 0) {
          ordered.insertAll(0, ordered.sublist(mine));
          ordered.removeRange(ordered.length - mine, ordered.length);
        }
        final n = math.max(ordered.length, 1);
        final ringR = r * 0.72;
        final pw = math
            .min(r * 0.2, 2 * math.pi * ringR / n / 1.65)
            .clamp(14.0, 48.0);
        final ph = pw * 1.95;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _TablePainter(r, dark)),
            ),
            if (center != null)
              Positioned(
                left: c.dx - r * 0.5,
                top: c.dy - r * 0.5,
                width: r,
                height: r,
                child: Center(child: center),
              ),
            for (var i = 0; i < ordered.length; i++)
              ..._seat(ordered[i], i, n, c, r, ringR, pw, ph),
          ],
        );
      },
    );
  }

  List<Widget> _seat(
    SeatView seat,
    int i,
    int n,
    Offset c,
    double r,
    double ringR,
    double pw,
    double ph,
  ) {
    final a = math.pi / 2 + 2 * math.pi * i / n;
    final dir = Offset(math.cos(a), math.sin(a));
    final phoneAt = c + dir * ringR;
    final labelAt = c + dir * (r + 20);
    const dur = Duration(milliseconds: 650);
    const curve = Curves.easeOutBack;
    return [
      AnimatedPositioned(
        key: ValueKey('phone-${seat.id}'),
        duration: dur,
        curve: curve,
        left: phoneAt.dx - ph / 2,
        top: phoneAt.dy - ph / 2,
        width: ph,
        height: ph,
        child: _Arrive(
          child: Center(
            child: Transform.rotate(
              angle: a - math.pi / 2,
              child: PhoneTile(
                pose: seat.pose,
                order: seat.order,
                payer: seat.payer,
                width: pw,
                dark: dark,
              ),
            ),
          ),
        ),
      ),
      if (showNames)
        AnimatedPositioned(
          key: ValueKey('name-${seat.id}'),
          duration: dur,
          curve: curve,
          left: labelAt.dx - 50,
          top: labelAt.dy - 11,
          width: 100,
          height: 22,
          child: _Arrive(
            child: Center(
              child: Text(
                seat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: manrope(
                  12,
                  weight: seat.me ? FontWeight.w800 : FontWeight.w600,
                  color: seat.payer
                      ? Brew.tomato
                      : (dark ? Brew.steam : Brew.ink).withValues(
                          alpha: seat.pose == PhonePose.out && !seat.payer
                              ? 0.55
                              : 1,
                        ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// Pops a seat in the first time it appears.
class _Arrive extends StatelessWidget {
  const _Arrive({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 520),
    curve: Curves.easeOutBack,
    builder: (_, t, c) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: 0.6 + 0.4 * t, child: c),
    ),
    child: child,
  );
}

class _TablePainter extends CustomPainter {
  _TablePainter(this.r, this.dark);
  final double r;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c.translate(0, r * 0.05),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.55 : 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.1,
          colors: dark
              ? const [Color(0xFF34251B), Color(0xFF221710)]
              : const [Color(0xFFE6D5BA), Color(0xFFD3BC9A)],
        ).createShader(rect),
    );

    // Growth rings, a little off centre, like a slice of wood.
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = (dark ? Colors.white : const Color(0xFF7A5634)).withValues(
        alpha: dark ? 0.035 : 0.07,
      );
    final rnd = math.Random(3);
    for (var i = 1; i < 14; i++) {
      final rr = r * (i / 14) + rnd.nextDouble() * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(r * 0.04, -r * 0.03),
          width: rr * 2 * 1.03,
          height: rr * 2,
        ),
        grain,
      );
    }

    // Edge band and a fine inner bead.
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dark ? const Color(0xFF46342A) : const Color(0xFFC3A882),
    );
    canvas.drawCircle(
      c,
      r * 0.93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = (dark ? Colors.white : Colors.white).withValues(
          alpha: dark ? 0.04 : 0.35,
        ),
    );
    // Window light across the top left.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.05 : 0.22),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.55],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) => old.r != r || old.dark != dark;
}

/// One phone. Flips over when it goes down, lifts and lights when picked up.
class PhoneTile extends StatelessWidget {
  const PhoneTile({
    super.key,
    required this.pose,
    required this.order,
    this.payer = false,
    this.width = 40,
    this.dark = false,
  });

  final PhonePose pose;
  final Order order;
  final bool payer;
  final double width;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.95;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: pose == PhonePose.down ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
      builder: (context, flip, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: pose == PhonePose.out ? 1 : 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, lift, _) {
          final showBack = flip > 0.5;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..scaleByDouble(1 + 0.16 * lift, 1 + 0.16 * lift, 1.0, 1.0)
            ..rotateY(flip * math.pi);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: Container(
              width: width,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28 + 0.2 * lift),
                    blurRadius: width * (0.12 + 0.45 * lift),
                    offset: Offset(0, width * (0.06 + 0.3 * lift)),
                  ),
                  if (lift > 0 && !showBack)
                    BoxShadow(
                      color: (payer ? Brew.tomato : Brew.cremaLight).withValues(
                        alpha: 0.55 * lift,
                      ),
                      blurRadius: width * 0.9 * lift,
                      spreadRadius: width * 0.05,
                    ),
                ],
              ),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _Back(width: width),
                    )
                  : _Front(
                      width: width,
                      order: order,
                      lit: pose == PhonePose.out,
                      payer: payer,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * 1.95), painter: _BackPainter());
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2D25), Color(0xFF1E1612)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      body.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    // Camera bump, top left.
    final bump = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, w * 0.1, w * 0.42, w * 0.42),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(bump, Paint()..color = const Color(0xFF47382E));
    final lens = Paint()..color = const Color(0xFF120D0A);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..color = Colors.white.withValues(alpha: 0.18);
    for (final o in [
      Offset(w * 0.21, w * 0.21),
      Offset(w * 0.41, w * 0.21),
      Offset(w * 0.21, w * 0.41),
    ]) {
      canvas.drawCircle(o, w * 0.075, lens);
      canvas.drawCircle(o, w * 0.075, ring);
    }
    canvas.drawCircle(
      Offset(w * 0.41, w * 0.41),
      w * 0.035,
      Paint()..color = const Color(0xFFE9D9B8).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_BackPainter old) => false;
}

class _Front extends StatelessWidget {
  const _Front({
    required this.width,
    required this.order,
    required this.lit,
    required this.payer,
  });
  final double width;
  final Order order;
  final bool lit;
  final bool payer;

  @override
  Widget build(BuildContext context) {
    final screen = payer
        ? Brew.tomato
        : lit
        ? Brew.steam
        : const Color(0xFF3B2E26);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15100D),
        borderRadius: BorderRadius.circular(width * 0.2),
      ),
      padding: EdgeInsets.all(width * 0.06),
      child: Container(
        decoration: BoxDecoration(
          color: screen,
          borderRadius: BorderRadius.circular(width * 0.15),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: width * 0.07,
              child: Container(
                width: width * 0.28,
                height: width * 0.09,
                decoration: BoxDecoration(
                  color: const Color(0xFF15100D),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
            Opacity(
              opacity: lit || payer ? 1 : 0.85,
              child: CupGlyph(order, size: width * 0.62, dark: !lit && !payer),
            ),
          ],
        ),
      ),
    );
  }
}
