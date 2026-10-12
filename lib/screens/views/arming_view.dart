import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/room.dart';
import '../../net/session.dart';
import '../../orders.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/table_view.dart';

/// "Phones down." Waits for every phone to flip, then counts in.
class ArmingView extends StatelessWidget {
  const ArmingView({
    super.key,
    required this.session,
    required this.state,
    required this.faceDown,
    required this.onLeave,
    this.onDebugToggle,
  });

  final TableSession session;
  final RoomState state;
  final bool faceDown;
  final VoidCallback onLeave;
  final VoidCallback? onDebugToggle;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final counting = state.phase == Phase.countdown;
    final waiting = state.players.where((p) => !p.down).toList();
    final me = state.player(session.meId);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, pad.top + 16, 24, pad.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RoundIcon(
                Icons.close_rounded,
                label: 'Leave table',
                dark: true,
                onTap: onLeave,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Kicker(
                  'Table ${state.code} · Round ${state.round}',
                  dark: true,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 260,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: counting
                  ? _Countdown(
                      key: const ValueKey('count'),
                      ms: session.countdownMs,
                    )
                  : _Headline(
                      key: const ValueKey('head'),
                      order: me?.order ?? Order.flatWhite,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            counting
                ? 'Everyone\'s down. Hands off.'
                : waiting.isEmpty
                ? 'Everyone\'s down.'
                : me != null && !me.down
                ? 'Turn yours over. The clock starts when every phone is down.'
                : 'Waiting on ${_names(waiting.map((p) => p.name).toList())}.',
            style: manrope(16, color: Brew.steamSoft, height: 1.45),
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in state.players)
                _ReadyChip(
                  name: p.id == session.meId ? 'You' : p.name,
                  order: p.order,
                  ready: p.down,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (session.isHost)
            BrewButton(
              'Not yet, back to the lobby',
              style: BrewButtonStyle.darkOutline,
              height: 52,
              onTap: session.cancel,
            ),
          if (onDebugToggle != null)
            Center(
              child: TextButton(
                onPressed: onDebugToggle,
                child: Text(
                  faceDown ? 'Debug: pick phone up' : 'Debug: put phone down',
                  style: manrope(12, color: Brew.steamSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _names(List<String> names) {
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.take(2).join(', ')} and ${names.length - 2} more';
  }
}

class _Headline extends StatefulWidget {
  const _Headline({super.key, required this.order});
  final Order order;

  @override
  State<_Headline> createState() => _HeadlineState();
}

class _HeadlineState extends State<_Headline> {
  late final Timer _flip;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _flip = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) setState(() => _down = !_down);
    });
  }

  @override
  void dispose() {
    _flip.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Phones\n'),
                TextSpan(
                  text: 'down.',
                  style: serif(
                    92,
                    italic: true,
                    color: Brew.crema,
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
            style: serif(92, color: Brew.steam, letterSpacing: -2, height: 0.9),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18, right: 8),
          child: PhoneTile(
            pose: _down ? PhonePose.down : PhonePose.waiting,
            order: widget.order,
            width: 58,
            dark: true,
          ),
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({super.key, required this.ms});
  final int ms;

  @override
  Widget build(BuildContext context) {
    final n = (ms / 1000).ceil().clamp(1, 9);
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 1.4, end: 1.0).animate(a),
            child: c,
          ),
        ),
        child: Text(
          '$n',
          key: ValueKey(n),
          style: serif(240, italic: true, color: Brew.crema, height: 1),
        ),
      ),
    );
  }
}

class _ReadyChip extends StatelessWidget {
  const _ReadyChip({
    required this.name,
    required this.order,
    required this.ready,
  });
  final String name;
  final Order order;
  final bool ready;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
    decoration: BoxDecoration(
      color: ready ? Brew.roastUp : Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(
        color: ready ? Brew.olive : Brew.roastLine,
        width: 1.2,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupGlyph(order, size: 28, dark: true),
        const SizedBox(width: 6),
        Text(
          name,
          style: manrope(
            13,
            weight: FontWeight.w700,
            color: ready ? Brew.steam : Brew.steamSoft,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: ready
              ? const Icon(
                  Icons.check_rounded,
                  key: ValueKey(1),
                  size: 16,
                  color: Color(0xFF9DB98B),
                )
              : const Icon(
                  Icons.more_horiz_rounded,
                  key: ValueKey(0),
                  size: 16,
                  color: Brew.steamSoft,
                ),
        ),
      ],
    ),
  );
}
