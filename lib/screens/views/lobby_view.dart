import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/room.dart';
import '../../net/session.dart';
import '../../orders.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/table_view.dart';

/// Gathering round: the code to say out loud, the QR, who's sat down.
class LobbyView extends StatelessWidget {
  const LobbyView({
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
    final host = state.host;
    final n = state.players.length;
    return Paper(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, pad.top + 16, 24, 24),
              children: [
                Row(
                  children: [
                    RoundIcon(
                      Icons.close_rounded,
                      label: 'Leave table',
                      onTap: onLeave,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Kicker(
                        session.isHost
                            ? 'Your table'
                            : "${host?.name ?? 'The'}'s table",
                        trailing: state.round > 1
                            ? 'Round ${state.round}'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CodeCard(session: session, code: state.code),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1.15,
                  child: TableView(
                    seats: SeatView.fromRoom(state, session.meId),
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Text('$n', key: ValueKey(n), style: serif(64)),
                        ),
                        Text('AT THE TABLE', style: kicker(size: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Kicker("Who's in"),
                for (final p in state.players)
                  _PlayerRow(player: p, me: p.id == session.meId),
                if (session.isHost) ...[
                  const SizedBox(height: 28),
                  const Kicker('House rules'),
                  const SizedBox(height: 4),
                  _TeaseRow(on: state.tease, onChanged: session.setTease),
                ],
                const SizedBox(height: 24),
                const _Rules(),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, pad.bottom + 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Brew.line)),
            ),
            child: session.isHost
                ? BrewButton(
                    n == 1 ? 'Start solo' : 'Start the round',
                    trailing: 'phones down',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      session.start();
                    },
                  )
                : _Waiting(hostName: host?.name ?? 'the host'),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.session, required this.code});
  final TableSession session;
  final String code;

  void _bigQr(BuildContext context, String data, String address) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Brew.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          32,
          28,
          32,
          MediaQuery.paddingOf(context).bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Scan to sit down', style: serif(34)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Brew.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _Qr(data: data, size: 240),
            ),
            const SizedBox(height: 16),
            Text(
              address,
              style: manrope(
                14,
                weight: FontWeight.w700,
                color: Brew.inkSoft,
                tabular: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = session.invite;
    final hasQr = invite != null && invite.hosts.isNotEmpty;
    final address = hasQr ? '${invite.hosts.first}:${invite.port}' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
      decoration: BoxDecoration(
        color: Brew.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Brew.line),
        boxShadow: [
          BoxShadow(
            color: Brew.ink.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TABLE CODE', style: kicker()),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(code, style: serif(72, letterSpacing: 8)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Say it out loud.',
                  style: serif(18, italic: true, color: Brew.inkSoft),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    address,
                    style: manrope(
                      11.5,
                      weight: FontWeight.w700,
                      color: Brew.inkFaint,
                      tabular: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasQr)
            Pressable(
              semanticLabel: 'Show QR code',
              onTap: () => _bigQr(context, invite.toUri().toString(), address),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Brew.paper,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _Qr(data: invite.toUri().toString(), size: 104),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TAP TO ENLARGE',
                    style: kicker(size: 8.5, color: Brew.inkFaint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Qr extends StatelessWidget {
  const _Qr({required this.data, required this.size});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => QrImageView(
    data: data,
    size: size,
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Brew.ink),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.circle,
      color: Brew.ink,
    ),
  );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.me});
  final Player player;
  final bool me;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    builder: (_, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Brew.line)),
      ),
      child: Row(
        children: [
          CupGlyph(player.order, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: serif(24),
                ),
                Text(
                  player.order.label,
                  style: manrope(12.5, color: Brew.inkSoft),
                ),
              ],
            ),
          ),
          if (player.host) const _Tag('Host'),
          if (me) ...[
            const SizedBox(width: 6),
            const _Tag('You', filled: true),
          ],
        ],
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.filled = false});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: filled ? Brew.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Brew.ink),
    ),
    child: Text(
      text.toUpperCase(),
      style: kicker(size: 9.5, color: filled ? Brew.paper : Brew.ink),
    ),
  );
}

class _TeaseRow extends StatelessWidget {
  const _TeaseRow({required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Temptation buzz', style: serif(24)),
              const SizedBox(height: 2),
              Text(
                'When someone picks up, every phone still down buzzes. Don\'t look.',
                style: manrope(13, color: Brew.inkSoft, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: on,
          onChanged: onChanged,
          activeThumbColor: Brew.paper,
          activeTrackColor: Brew.ink,
          inactiveThumbColor: Brew.inkFaint,
          inactiveTrackColor: Brew.paperDeep,
          trackOutlineColor: const WidgetStatePropertyAll(Brew.line),
        ),
      ],
    ),
  );
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    const rules = [
      ('Phones face down', 'on the table, screens hidden.'),
      ('The clock starts', 'once every last phone is down.'),
      ('First one up pays.', 'Everyone else keeps going for the record.'),
    ];
    return Column(
      children: [
        for (var i = 0; i < rules.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${i + 1}.',
                    style: serif(26, italic: true, color: Brew.crema),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${rules[i].$1} ',
                            style: manrope(14.5, weight: FontWeight.w800),
                          ),
                          TextSpan(text: rules[i].$2),
                        ],
                      ),
                      style: manrope(14.5, color: Brew.inkSoft, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.hostName});
  final String hostName;

  @override
  Widget build(BuildContext context) => Container(
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
              const TextSpan(text: 'Waiting for '),
              TextSpan(text: hostName, style: serif(20, italic: true)),
              const TextSpan(text: ' to start'),
            ],
          ),
          style: manrope(15, weight: FontWeight.w600),
        ),
      ],
    ),
  );
}
