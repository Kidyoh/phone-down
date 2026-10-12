import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../net/session.dart';
import '../orders.dart';
import '../profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/table_view.dart';
import 'join_screen.dart';
import 'onboarding_screen.dart';
import 'table_screen.dart';

/// The front page: masthead, the table, your record, host or join.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _opening = false;

  Profile get _p => widget.profile;

  Future<void> _host() async {
    setState(() => _opening = true);
    try {
      final session = await HostSession.open(_p.seat);
      if (!mounted) {
        await session.close();
        return;
      }
      await Navigator.of(context)
          .push(pageRoute(TableScreen(session: session, profile: _p)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't open a table. Is Wi-Fi or your hotspot on?",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Paper(
        child: ListenableBuilder(
          listenable: _p,
          builder: (context, _) => ListView(
            padding: EdgeInsets.fromLTRB(24, pad.top + 16, 24, pad.bottom + 24),
            children: [
              _masthead(context),
              const SizedBox(height: 8),
              _hero(),
              const SizedBox(height: 8),
              _stats(),
              const SizedBox(height: 28),
              BrewButton(
                'Host a table',
                icon: Icons.local_cafe_outlined,
                busy: _opening,
                onTap: _host,
              ),
              const SizedBox(height: 12),
              BrewButton(
                'Join a table',
                style: BrewButtonStyle.outline,
                icon: Icons.wifi_tethering_rounded,
                onTap: () =>
                    Navigator.of(context)
                        .push(pageRoute(JoinScreen(profile: _p))),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'No accounts, no internet. Just the same Wi-Fi.',
                  style: manrope(12.5, color: Brew.inkFaint),
                ),
              ),
              if (_p.history.isNotEmpty) ...[
                const SizedBox(height: 36),
                _log(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _masthead(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('NO. ${_p.rounds + 1}', style: kicker()),
            const SizedBox(width: 10),
            Text('·', style: kicker()),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}'
                    .toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kicker(),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              semanticLabel: 'Edit your seat',
              onTap: () => Navigator.of(
                context,
              ).push(pageRoute(OnboardingScreen(profile: _p, editing: true))),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                decoration: BoxDecoration(
                  color: Brew.card,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Brew.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupGlyph(_p.order, size: 28),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        _p.name,
                        overflow: TextOverflow.ellipsis,
                        style: manrope(13, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Rule(double: true),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Phone '),
                TextSpan(
                  text: 'Down.',
                  style: serif(
                    84,
                    italic: true,
                    color: Brew.crema,
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
            style: serif(84, letterSpacing: -2, height: 1),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Rule(),
        const SizedBox(height: 12),
        Text(
          'Everyone at the table puts their phone face down. '
          'First one to pick theirs up buys the coffee.',
          style: manrope(15, color: Brew.inkSoft, height: 1.45),
        ),
      ],
    );
  }

  Widget _hero() {
    final others = [Order.cortado, Order.latte, Order.americano, Order.matcha];
    return AspectRatio(
      aspectRatio: 1.08,
      child: TableView(
        showNames: false,
        seats: [
          SeatView(
            id: 'me',
            name: 'You',
            order: _p.order,
            pose: PhonePose.down,
            me: true,
          ),
          for (var i = 0; i < others.length; i++)
            SeatView(
              id: '$i',
              name: '',
              order: others[i],
              pose: PhonePose.down,
            ),
        ],
        center: SteamingCup(order: _p.order),
      ),
    );
  }

  Widget _stats() {
    Widget cell(String label, String value, {String? unit}) => Expanded(
      child: Column(
        children: [
          Text(label.toUpperCase(), style: kicker(size: 10)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: serif(16, italic: true, color: Brew.inkSoft),
                  ),
              ],
            ),
            style: serif(34, height: 1),
          ),
        ],
      ),
    );
    Widget divider() => Container(width: 1, height: 44, color: Brew.line);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Brew.line)),
      ),
      child: Row(
        children: [
          cell('Longest down', _p.bestMs == 0 ? '—' : formatSpan(_p.bestMs)),
          divider(),
          cell('Coffees won', '${_p.coffeesWon}'),
          divider(),
          cell(
            'Bought',
            '${_p.timesPaid}',
            unit: _p.timesPaid == 1 ? 'round' : 'rounds',
          ),
        ],
      ),
    );
  }

  Widget _log() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('The log'),
        const SizedBox(height: 6),
        for (final r in _p.history.take(6))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Brew.line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    '${r.at.day} ${months[r.at.month - 1]}',
                    style: manrope(
                      12,
                      weight: FontWeight.w700,
                      color: Brew.inkFaint,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: r.iPaid
                          ? [
                              TextSpan(
                                text: 'You bought',
                                style: serif(
                                  20,
                                  italic: true,
                                  color: Brew.tomato,
                                ),
                              ),
                              TextSpan(text: '  · ${r.players} at the table'),
                            ]
                          : [
                              TextSpan(
                                text: r.payer.isEmpty
                                    ? 'Nobody blinked'
                                    : '${r.payer} bought',
                                style: serif(20),
                              ),
                              TextSpan(
                                text: r.place == 1 && r.players > 1
                                    ? '  · you won'
                                    : '  · #${r.place} of ${r.players}',
                              ),
                            ],
                    ),
                    style: manrope(12.5, color: Brew.inkSoft),
                  ),
                ),
                Text(
                  formatClock(r.myMs),
                  style: manrope(14, weight: FontWeight.w700, tabular: true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A cup with steam curling off it.
class SteamingCup extends StatefulWidget {
  const SteamingCup({super.key, required this.order, this.size = 92});

  final Order order;
  final double size;

  @override
  State<SteamingCup> createState() => _SteamingCupState();
}

class _SteamingCupState extends State<SteamingCup>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CupGlyph(widget.order, size: widget.size),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) =>
                    CustomPaint(painter: _SteamPainter(_c.value)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SteamPainter extends CustomPainter {
  _SteamPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var k = 0; k < 3; k++) {
      final phase = (t + k / 3) % 1.0;
      final path = Path();
      final x0 = c.dx + (k - 1) * size.width * 0.09;
      final y0 = c.dy - size.height * 0.02;
      final len = size.height * 0.42;
      for (var i = 0; i <= 24; i++) {
        final f = i / 24;
        final y = y0 - f * len - phase * size.height * 0.06;
        final x =
            x0 +
            math.sin(f * math.pi * 2.2 + phase * math.pi * 2 + k) *
                size.width *
                0.035 *
                (0.4 + f);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final fade = math.sin(phase * math.pi);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = size.width * 0.03
          ..shader =
              LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.55 * fade),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromLTWH(
                  0,
                  y0 - len - size.height * 0.08,
                  size.width,
                  len + size.height * 0.08,
                ),
              )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.012),
      );
    }
  }

  @override
  bool shouldRepaint(_SteamPainter old) => old.t != t;
}
