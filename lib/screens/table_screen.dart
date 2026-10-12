import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../game/face_down.dart';
import '../game/room.dart';
import '../net/session.dart';
import '../profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'views/arming_view.dart';
import 'views/live_view.dart';
import 'views/lobby_view.dart';
import 'views/tab_view.dart';

/// One table, start to finish. Watches the accelerometer, keeps the screen
/// awake, buzzes at the right moments, and shows whichever page the round
/// is on.
class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.session,
    required this.profile,
    this.faceDown,
    this.useWakelock = true,
  });

  final TableSession session;
  final Profile profile;

  /// Face-down changes. The real accelerometer unless a test passes one.
  final Stream<bool>? faceDown;
  final bool useWakelock;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> with WidgetsBindingObserver {
  StreamSubscription<bool>? _sensor;
  RoomState? _prev;
  bool _faceDown = false;
  bool _leaving = false;
  Timer? _ticker;

  TableSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.useWakelock) WakelockPlus.enable().catchError((_) {});
    _sensor = (widget.faceDown ?? faceDownStream()).listen(_onFaceDown);
    _s.addListener(_onState);
    _prev = _s.state;
    // Redraws the clock between updates from the host.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final p = _s.state?.phase;
      if (mounted && (p == Phase.live || p == Phase.countdown)) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _sensor?.cancel();
    _s.removeListener(_onState);
    if (widget.useWakelock) WakelockPlus.disable().catchError((_) {});
    _s.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-round means you picked the phone up.
    if (state == AppLifecycleState.paused && _s.state?.phase == Phase.live) {
      _s.setDown(false);
    }
  }

  void _onFaceDown(bool down) {
    _faceDown = down;
    _s.setDown(down);
    if (mounted) setState(() {});
  }

  void _onState() {
    if (_s.error != null) {
      _lost(_s.error!);
      return;
    }
    final s = _s.state;
    if (s == null) return;
    final prev = _prev;
    _prev = s;
    if (s.phase == Phase.done) widget.profile.record(s, s.code);
    if (prev != null) _buzz(prev, s);
    if (mounted) setState(() {});
  }

  /// The screen is face down for most of a round, so haptics carry it.
  void _buzz(RoomState a, RoomState b) {
    if (a.phase != Phase.countdown && b.phase == Phase.countdown) {
      HapticFeedback.lightImpact();
    }
    if (a.phase == Phase.countdown && b.phase == Phase.live) {
      _pattern([
        HapticFeedback.heavyImpact,
        HapticFeedback.heavyImpact,
        HapticFeedback.heavyImpact,
      ]);
    }
    if (b.phase == Phase.live || b.phase == Phase.done) {
      final newlyOut = b.players.where(
        (p) => p.isOut && a.player(p.id)?.isOut == false,
      );
      for (final p in newlyOut) {
        if (p.id == _s.meId) {
          _pattern([HapticFeedback.heavyImpact, HapticFeedback.mediumImpact]);
        } else if (b.tease && b.player(_s.meId)?.isOut == false) {
          // Somebody cracked. Feel that? Don't look.
          _pattern([HapticFeedback.mediumImpact, HapticFeedback.mediumImpact]);
        }
      }
    }
    if (a.phase != Phase.done && b.phase == Phase.done) {
      HapticFeedback.mediumImpact();
    }
  }

  void _pattern(List<Future<void> Function()> beats) {
    for (var i = 0; i < beats.length; i++) {
      Future<void>.delayed(Duration(milliseconds: 160 * i), beats[i]);
    }
  }

  Future<void> _lost(String why) async {
    if (_leaving || !mounted) return;
    _leaving = true;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _Notice(title: 'Table closed', body: why, action: 'Back home'),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _leave() async {
    final s = _s.state;
    final risky = s != null && (s.phase == Phase.live || _s.isHost);
    if (risky) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => _Notice(
          title: _s.isHost ? 'Close the table?' : 'Walk away?',
          body: _s.isHost ? 'Everyone else gets sent home too.' : 'Leaving mid-round counts as picking up. If you\'re first, you\'re buying.',
          action: _s.isHost ? 'Close it' : 'Leave anyway',
          cancel: 'Stay',
          danger: true,
        ),
      );
      if (ok != true) return;
    }
    _leaving = true;
    if (mounted) Navigator.of(context).pop();
  }

  /// Lets an emulator with no motion sensor play along.
  bool get _debug => kDebugMode && widget.faceDown == null;

  bool get _dark {
    final p = _s.state?.phase;
    return p == Phase.arming || p == Phase.countdown || p == Phase.live;
  }

  @override
  Widget build(BuildContext context) {
    final s = _s.state;
    final dark = _dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          color: dark ? Brew.roast : Brew.paper,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: s == null
                ? const Center(
                    child: CircularProgressIndicator(color: Brew.ink),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.97, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_page(s.phase)),
                      child: _view(s),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _page(Phase p) => switch (p) {
    Phase.lobby => 'lobby',
    Phase.arming || Phase.countdown => 'arming',
    Phase.live => 'live',
    Phase.done => 'done',
  };

  Widget _view(RoomState s) => switch (s.phase) {
    Phase.lobby => LobbyView(session: _s, state: s, onLeave: _leave),
    Phase.arming || Phase.countdown => ArmingView(
      session: _s,
      state: s,
      faceDown: _faceDown,
      onLeave: _leave,
      onDebugToggle: _debug ? () => _onFaceDown(!_faceDown) : null,
    ),
    Phase.live => LiveView(
      session: _s,
      state: s,
      faceDown: _faceDown,
      onLeave: _leave,
      onDebugToggle: _debug ? () => _onFaceDown(!_faceDown) : null,
    ),
    Phase.done => TabView(session: _s, state: s, onLeave: _leave),
  };
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.body,
    required this.action,
    this.cancel,
    this.danger = false,
  });

  final String title;
  final String body;
  final String action;
  final String? cancel;
  final bool danger;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Brew.paper,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: serif(34)),
          const SizedBox(height: 8),
          Text(body, style: manrope(15, color: Brew.inkSoft, height: 1.45)),
          const SizedBox(height: 22),
          BrewButton(
            action,
            height: 52,
            style: danger ? BrewButtonStyle.danger : BrewButtonStyle.solid,
            onTap: () => Navigator.of(context).pop(true),
          ),
          if (cancel != null) ...[
            const SizedBox(height: 8),
            BrewButton(
              cancel!,
              height: 52,
              style: BrewButtonStyle.quiet,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ],
      ),
    ),
  );
}
