import 'dart:math' as math;

import 'room.dart';

/// The rules of the table, run on the host's phone. Pure: every call takes
/// the current time in ms, so tests can drive it without a real clock.
class RoomEngine {
  RoomEngine({
    required this.code,
    required Player host,
    this.countdownMs = 3000,
    this.maxPlayers = 12,
  }) {
    _players[host.id] = host.copyWith();
  }

  final String code;
  final int countdownMs;
  final int maxPlayers;

  final _players = <String, Player>{};
  Phase _phase = Phase.lobby;
  int _round = 1;
  int _countdownStart = 0;
  int _start = 0;
  int _end = 0;
  String? _payer;
  bool tease = true;

  Phase get phase => _phase;

  /// Letters people won't misread across a table.
  static String newCode([math.Random? rnd]) {
    const letters = 'ACDEFHJKMNPQRTUVWXY';
    final r = rnd ?? math.Random.secure();
    return List.generate(4, (_) => letters[r.nextInt(letters.length)]).join();
  }

  RoomState snapshot(int now) => RoomState(
    code: code,
    phase: _phase,
    round: _round,
    players: _players.values.toList(growable: false),
    clockMs: switch (_phase) {
      Phase.live => now - _start,
      Phase.done => _end - _start,
      _ => 0,
    },
    countdownMs: _phase == Phase.countdown
        ? math.max(0, countdownMs - (now - _countdownStart))
        : 0,
    tease: tease,
    payerId: _payer,
  );

  /// Returns why the player can't sit down, or null once they have.
  String? join(Player p) {
    final existing = _players[p.id];
    if (existing != null) {
      // Same phone reconnecting: keep where they are in the round.
      _players[p.id] = Player(
        id: p.id,
        name: p.name,
        order: p.order,
        host: existing.host,
        down: existing.down,
        outMs: existing.outMs,
        dropped: existing.dropped,
      );
      return null;
    }
    if (_phase != Phase.lobby && _phase != Phase.done) {
      return "That table's mid-round. Catch the next one.";
    }
    if (_players.length >= maxPlayers) return "That table's full.";
    _players[p.id] = Player(id: p.id, name: p.name, order: p.order);
    return null;
  }

  void leave(String id, int now) {
    final p = _players[id];
    if (p == null || p.host) return;
    if (_phase == Phase.live) {
      // Walking away mid-round is picking up.
      if (!p.isOut) {
        _players[id] = p.copyWith(down: false, dropped: true);
        _out(id, now);
      }
      return;
    }
    _players.remove(id);
    if (_phase == Phase.arming) _maybeArm(now);
    if (_phase == Phase.countdown) _maybeArm(now);
  }

  void start(int now) {
    if (_phase == Phase.done) {
      _round++;
      _payer = null;
      _players.updateAll((_, p) => p.copyWith(clearOut: true));
    } else if (_phase != Phase.lobby) {
      return;
    }
    _phase = Phase.arming;
    _maybeArm(now);
  }

  /// Back to the lobby without playing, from anywhere but a live round.
  void cancel() {
    if (_phase == Phase.live) return;
    if (_phase == Phase.done) {
      _round++;
      _payer = null;
      _players.updateAll((_, p) => p.copyWith(clearOut: true));
    }
    _phase = Phase.lobby;
  }

  void setDown(String id, bool down, int now) {
    final p = _players[id];
    if (p == null || p.down == down) return;
    _players[id] = p.copyWith(down: down);
    switch (_phase) {
      case Phase.arming:
        _maybeArm(now);
      case Phase.countdown:
        if (!down) _phase = Phase.arming;
      case Phase.live:
        if (!down && !p.isOut) _out(id, now);
      case Phase.lobby:
      case Phase.done:
        break;
    }
  }

  /// Ends the round with whoever is still down sharing the win.
  void callIt(int now) {
    if (_phase != Phase.live) return;
    _phase = Phase.done;
    _end = now;
  }

  /// Moves the countdown along. Returns true when the phase changed.
  bool tick(int now) {
    if (_phase == Phase.countdown && now - _countdownStart >= countdownMs) {
      _phase = Phase.live;
      _start = now;
      return true;
    }
    return false;
  }

  void _maybeArm(int now) {
    if (_players.isEmpty) return;
    if (_players.values.every((p) => p.down)) {
      if (_phase != Phase.countdown) {
        _phase = Phase.countdown;
        _countdownStart = now;
      }
    } else {
      _phase = Phase.arming;
    }
  }

  void _out(String id, int now) {
    final p = _players[id]!;
    _players[id] = p.copyWith(outMs: now - _start);
    _payer ??= id;
    if (_players.values.every((p) => p.isOut)) {
      _phase = Phase.done;
      _end = now;
    }
  }
}
