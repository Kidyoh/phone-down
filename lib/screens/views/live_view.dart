import 'package:flutter/material.dart';

import '../../game/room.dart';
import '../../net/session.dart';
import '../../orders.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/table_view.dart';

/// The round. Face down, the screen goes black. Picked up, you see the
/// table, the clock, and who's still holding out.
class LiveView extends StatelessWidget {
  const LiveView({
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
    final me = state.player(session.meId);
    final sleeping = me != null && !me.isOut && faceDown;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: sleeping
          ? _Sleep(
              key: const ValueKey('sleep'),
              clockMs: session.clockMs,
              onDebugToggle: onDebugToggle,
            )
          : _Watch(
              key: const ValueKey('watch'),
              session: session,
              state: state,
              onLeave: onLeave,
            ),
    );
  }
}

/// Black, for a screen nobody can see. Saves the battery on OLED.
class _Sleep extends StatelessWidget {
  const _Sleep({super.key, required this.clockMs, this.onDebugToggle});
  final int clockMs;
  final VoidCallback? onDebugToggle;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Shh.',
            style: serif(40, italic: true, color: const Color(0xFF2E2620)),
          ),
          const SizedBox(height: 6),
          ClockText(
            formatClock(clockMs),
            style: manrope(
              14,
              weight: FontWeight.w700,
              color: const Color(0xFF2E2620),
            ),
          ),
          if (onDebugToggle != null)
            TextButton(
              onPressed: onDebugToggle,
              child: Text(
                'Debug: pick phone up',
                style: manrope(12, color: Brew.steamSoft),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Watch extends StatelessWidget {
  const _Watch({
    super.key,
    required this.session,
    required this.state,
    required this.onLeave,
  });

  final TableSession session;
  final RoomState state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final me = state.player(session.meId);
    final standing = state.standing.length;
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top + 16, 24, pad.bottom + 24),
      children: [
        Row(
          children: [
            RoundIcon(
              Icons.close_rounded,
              label: 'Leave table',
              dark: true,
              onTap: onLeave,
            ),
            const SizedBox(width: 12),
            const PulseDot(color: Brew.tomato, size: 7),
            const SizedBox(width: 2),
            Expanded(
              child: Kicker(
                'Live · ${state.code}',
                dark: true,
                trailing: '$standing of ${state.players.length} down',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (me != null && me.isOut)
          _MyResult(me: me, payer: state.payerId == me.id, state: state),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1,
          child: TableView(
            dark: true,
            seats: SeatView.fromRoom(state, session.meId),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ON THE CLOCK',
                  style: kicker(color: Brew.steamSoft, size: 9.5),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: ClockText(
                    formatClock(session.clockMs),
                    style: serif(52, color: Brew.steam, letterSpacing: 0),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Kicker('Standings', dark: true),
        const SizedBox(height: 4),
        Standings(
          state: state,
          meId: session.meId,
          clockMs: session.clockMs,
          dark: true,
        ),
        if (session.isHost && me != null && me.isOut && standing > 0) ...[
          const SizedBox(height: 20),
          BrewButton(
            'Call it',
            style: BrewButtonStyle.light,
            trailing: standing == 1 ? 'they win' : 'they share it',
            onTap: session.callIt,
          ),
        ],
      ],
    );
  }
}

class _MyResult extends StatelessWidget {
  const _MyResult({required this.me, required this.payer, required this.state});
  final Player me;
  final bool payer;
  final RoomState state;

  @override
  Widget build(BuildContext context) {
    final rank = state.leaderboard.indexWhere((p) => p.id == me.id) + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: payer ? Brew.tomato : Brew.roastUp,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: payer ? Brew.tomato : Brew.roastLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payer
                      ? 'You blinked first.'
                      : 'You lasted ${formatSpan(me.outMs ?? 0)}.',
                  style: serif(
                    30,
                    italic: payer,
                    color: payer ? Brew.card : Brew.steam,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payer
                      ? 'The coffee\'s on you. ${state.players.length - 1} to go.'
                      : 'Place #$rank so far. ${state.payer?.name ?? 'Someone'} is buying.',
                  style: manrope(
                    14,
                    color: payer
                        ? Brew.card.withValues(alpha: 0.85)
                        : Brew.steamSoft,
                  ),
                ),
              ],
            ),
          ),
          if (payer) Stamp('PAYS', color: Brew.card, size: 13),
        ],
      ),
    );
  }
}

/// The leaderboard: longest down at the top, still-down players live.
class Standings extends StatelessWidget {
  const Standings({
    super.key,
    required this.state,
    required this.meId,
    required this.clockMs,
    this.dark = false,
  });

  final RoomState state;
  final String meId;
  final int clockMs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Brew.steam : Brew.ink;
    final soft = dark ? Brew.steamSoft : Brew.inkSoft;
    final line = dark ? Brew.roastLine : Brew.line;
    final board = state.leaderboard;
    return Column(
      children: [
        for (var i = 0; i < board.length; i++)
          AnimatedContainer(
            key: ValueKey(board[i].id),
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${i + 1}',
                    style: serif(
                      26,
                      italic: true,
                      color: i == 0 ? Brew.crema : soft,
                    ),
                  ),
                ),
                CupGlyph(board[i].order, size: 36, dark: dark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        board[i].id == meId
                            ? '${board[i].name} (you)'
                            : board[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: serif(
                          22,
                          color: board[i].id == state.payerId
                              ? Brew.tomato
                              : ink,
                        ),
                      ),
                      Text(_status(board[i]), style: manrope(12, color: soft)),
                    ],
                  ),
                ),
                if (board[i].id == state.payerId)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stamp('PAYS', size: 10, color: Brew.tomato),
                  ),
                if (!board[i].isOut && state.phase == Phase.live) ...[
                  const PulseDot(color: Color(0xFF8DAE78), size: 7),
                  const SizedBox(width: 2),
                ],
                ClockText(
                  formatClock(board[i].outMs ?? clockMs),
                  style: manrope(
                    15,
                    weight: FontWeight.w800,
                    color: board[i].isOut ? soft : ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _status(Player p) {
    if (p.dropped) return 'walked away · ${p.order.label.toLowerCase()}';
    if (!p.isOut) {
      return state.phase == Phase.live
          ? 'still down · ${p.order.label.toLowerCase()}'
          : 'never blinked · ${p.order.label.toLowerCase()}';
    }
    return 'picked up · ${p.order.label.toLowerCase()}';
  }
}
