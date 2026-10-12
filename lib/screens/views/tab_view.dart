import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../game/room.dart';
import '../../net/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// The round's over. Here's the bill, and who's paying it.
class TabView extends StatefulWidget {
  const TabView({
    super.key,
    required this.session,
    required this.state,
    required this.onLeave,
  });

  final TableSession session;
  final RoomState state;
  final VoidCallback onLeave;

  @override
  State<TabView> createState() => _TabViewState();
}

class _TabViewState extends State<TabView> {
  final _receipt = GlobalKey();
  bool _sharing = false;

  RoomState get _s => widget.state;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _receipt.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final payer = _s.payer;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes!.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'phone-down-tab.png',
            ),
          ],
          text: payer == null
              ? 'Nobody blinked. Phone Down ☕'
              : '${payer.name} picked up first and is buying the coffee. Phone Down ☕',
        ),
      );
    } catch (_) {
      // Nothing to share with, or the user backed out.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final session = widget.session;
    final payer = _s.payer;
    final iPaid = payer?.id == session.meId;
    final winner = _s.leaderboard.firstOrNull;
    final hostName = _s.host?.name ?? 'the host';

    return Paper(
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, pad.top + 16, 24, pad.bottom + 24),
        children: [
          Row(
            children: [
              RoundIcon(
                Icons.close_rounded,
                label: 'Leave table',
                onTap: widget.onLeave,
              ),
              const SizedBox(width: 16),
              Expanded(child: Kicker('Round ${_s.round} · The tab')),
            ],
          ),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              children: payer == null
                  ? [
                      const TextSpan(text: 'Nobody\n'),
                      TextSpan(
                        text: 'blinked.',
                        style: serif(
                          76,
                          italic: true,
                          color: Brew.crema,
                          letterSpacing: -2,
                        ),
                      ),
                    ]
                  : iPaid
                  ? [
                      const TextSpan(text: "You're\n"),
                      TextSpan(
                        text: 'buying.',
                        style: serif(
                          76,
                          italic: true,
                          color: Brew.tomato,
                          letterSpacing: -2,
                        ),
                      ),
                    ]
                  : [
                      TextSpan(text: '${payer.name}\n'),
                      TextSpan(
                        text: 'pays.',
                        style: serif(
                          76,
                          italic: true,
                          color: Brew.tomato,
                          letterSpacing: -2,
                        ),
                      ),
                    ],
            ),
            style: serif(76, letterSpacing: -2, height: 0.92),
          ),
          const SizedBox(height: 14),
          Text(
            _summary(payer, winner),
            style: manrope(15, color: Brew.inkSoft, height: 1.45),
          ),
          const SizedBox(height: 24),
          RepaintBoundary(
            key: _receipt,
            child: ColoredBox(
              color: Brew.paper,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 6,
                ),
                child: Receipt(state: _s, meId: session.meId),
              ),
            ),
          ),
          const SizedBox(height: 24),
          BrewButton(
            'Share the tab',
            style: BrewButtonStyle.outline,
            icon: Icons.ios_share_rounded,
            busy: _sharing,
            onTap: _share,
          ),
          const SizedBox(height: 10),
          if (session.isHost) ...[
            BrewButton('Again', trailing: 'same table', onTap: session.start),
            const SizedBox(height: 10),
            BrewButton(
              'Back to the lobby',
              style: BrewButtonStyle.quiet,
              onTap: session.cancel,
            ),
          ] else
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Brew.paperDeep,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PulseDot(color: Brew.crema),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: hostName,
                          style: serif(20, italic: true),
                        ),
                        const TextSpan(text: ' calls the next round'),
                      ],
                    ),
                    style: manrope(15, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _summary(Player? payer, Player? winner) {
    final n = _s.players.length;
    if (payer == null) return 'Everyone held out until the host called it.';
    final coffees = n == 1 ? 'one coffee' : '$n coffees';
    if (winner == null || winner.id == payer.id) {
      return '${payer.name} lasted ${formatSpan(payer.outMs ?? 0)}. That\'s $coffees.';
    }
    final standing = _s.standing.length;
    final best = standing > 1
        ? '$standing of you never picked up'
        : '${winner.name} lasted ${formatSpan(winner.outMs ?? _s.clockMs)}';
    return '${payer.name} cracked after ${formatSpan(payer.outMs ?? 0)}. $best. That\'s $coffees on ${payer.name}.';
  }
}

/// The bill, with torn edges and a crooked PAID stamp.
class Receipt extends StatelessWidget {
  const Receipt({super.key, required this.state, required this.meId});

  final RoomState state;
  final String meId;

  @override
  Widget build(BuildContext context) {
    final board = state.leaderboard;
    final payer = state.payer;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final when =
        '${now.day}.${two(now.month)}.${now.year} · ${two(now.hour)}:${two(now.minute)}';
    final mono = manrope(
      12.5,
      weight: FontWeight.w600,
      color: Brew.inkSoft,
      tabular: true,
    );

    return PhysicalShape(
      clipper: const _TornEdges(),
      color: Brew.card,
      elevation: 6,
      shadowColor: Brew.ink.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
        child: Column(
          children: [
            Text('Phone Down', style: serif(34)),
            Text(
              'café of the face-down phone',
              style: serif(15, italic: true, color: Brew.inkSoft),
            ),
            const SizedBox(height: 10),
            Text(
              'TABLE ${state.code}  ·  ROUND ${state.round}',
              style: kicker(size: 10),
            ),
            const SizedBox(height: 2),
            Text(when, style: mono),
            const SizedBox(height: 14),
            const DashedRule(),
            const SizedBox(height: 8),
            for (final p in board)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1 × ${p.order.label}',
                            style: manrope(
                              14.5,
                              weight: FontWeight.w800,
                              color: Brew.ink,
                            ),
                          ),
                          Text(
                            '${p.id == meId ? '${p.name} (you)' : p.name}'
                            '${p.id == state.payerId
                                ? ' · picked up first'
                                : p.isOut
                                ? ''
                                : ' · never blinked'}',
                            style: mono.copyWith(
                              color: p.id == state.payerId
                                  ? Brew.tomato
                                  : Brew.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatClock(p.outMs ?? state.clockMs),
                      style: manrope(
                        14.5,
                        weight: FontWeight.w800,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const DashedRule(),
            const SizedBox(height: 12),
            _line('ITEMS', '${board.length}', mono),
            const SizedBox(height: 4),
            _line('ROUND LENGTH', formatClock(state.clockMs), mono),
            const SizedBox(height: 12),
            const DashedRule(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PAID BY', style: kicker(size: 11, color: Brew.ink)),
                      Text(
                        payer?.name ?? 'nobody',
                        overflow: TextOverflow.ellipsis,
                        style: serif(
                          38,
                          italic: true,
                          color: payer == null ? Brew.inkSoft : Brew.tomato,
                        ),
                      ),
                    ],
                  ),
                ),
                if (payer != null)
                  const Opacity(
                    opacity: 0.85,
                    child: Stamp('PAID', size: 22, angle: -0.22),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarcodePainter('${state.code}${state.round}'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Thank you for putting your phone down.',
              style: serif(15, italic: true, color: Brew.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b, TextStyle style) => Row(
    children: [
      Text(a, style: style.copyWith(letterSpacing: 1.2)),
      const Spacer(),
      Text(
        b,
        style: style.copyWith(color: Brew.ink, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

/// Zigzag top and bottom, like it came off the till.
class _TornEdges extends CustomClipper<Path> {
  const _TornEdges();

  @override
  Path getClip(Size size) {
    const tooth = 9.0;
    const depth = 6.0;
    final n = (size.width / tooth).floor();
    final w = size.width / n;
    final path = Path()..moveTo(0, depth);
    for (var i = 0; i < n; i++) {
      path
        ..lineTo(w * i + w / 2, 0)
        ..lineTo(w * (i + 1), depth);
    }
    path.lineTo(size.width, size.height - depth);
    for (var i = n; i > 0; i--) {
      path
        ..lineTo(w * i - w / 2, size.height)
        ..lineTo(w * (i - 1), size.height - depth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_TornEdges old) => false;
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.seed);
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed.hashCode);
    final p = Paint()..color = Brew.ink;
    var x = size.width * 0.12;
    final end = size.width * 0.88;
    while (x < end) {
      final w = (rnd.nextInt(3) + 1) * 1.3;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + (rnd.nextInt(3) + 1) * 1.6;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.seed != seed;
}
