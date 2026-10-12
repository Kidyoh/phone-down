import 'package:flutter_test/flutter_test.dart';
import 'package:phone_down/game/room.dart';
import 'package:phone_down/game/room_engine.dart';
import 'package:phone_down/orders.dart';

Player _p(String id, {bool host = false}) =>
    Player(id: id, name: id.toUpperCase(), order: Order.latte, host: host);

RoomEngine _table() {
  final e = RoomEngine(code: 'ABCD', host: _p('h', host: true));
  e.join(_p('a'));
  e.join(_p('b'));
  return e;
}

void main() {
  test('starts only once every phone is down, after the countdown', () {
    final e = _table();
    e.start(0);
    expect(e.phase, Phase.arming);
    e.setDown('h', true, 10);
    e.setDown('a', true, 20);
    expect(e.phase, Phase.arming);
    e.setDown('b', true, 30);
    expect(e.phase, Phase.countdown);
    expect(e.snapshot(1030).countdownMs, 2000);
    expect(e.tick(2000), isFalse);
    expect(e.tick(3030), isTrue);
    expect(e.phase, Phase.live);
  });

  test('lifting during the countdown just cancels it', () {
    final e = _table();
    e.start(0);
    for (final id in ['h', 'a', 'b']) {
      e.setDown(id, true, 0);
    }
    e.setDown('a', false, 1000);
    expect(e.phase, Phase.arming);
    expect(e.snapshot(1000).payerId, isNull);
  });

  test('first up pays, the round ends when everyone is up', () {
    final e = _table();
    e.start(0);
    for (final id in ['h', 'a', 'b']) {
      e.setDown(id, true, 0);
    }
    e.tick(3000);
    e.setDown('b', false, 63000);
    var s = e.snapshot(63000);
    expect(s.payerId, 'b');
    expect(s.player('b')!.outMs, 60000);
    expect(s.phase, Phase.live);

    e.setDown('h', false, 93000);
    e.setDown('a', false, 123000);
    s = e.snapshot(200000);
    expect(s.phase, Phase.done);
    expect(s.clockMs, 120000);
    expect(s.leaderboard.map((p) => p.id), ['a', 'h', 'b']);
  });

  test('putting it back down does not undo a pickup', () {
    final e = _table();
    e.start(0);
    for (final id in ['h', 'a', 'b']) {
      e.setDown(id, true, 0);
    }
    e.tick(3000);
    e.setDown('a', false, 5000);
    e.setDown('a', true, 6000);
    e.setDown('a', false, 9000);
    expect(e.snapshot(9000).player('a')!.outMs, 2000);
  });

  test('leaving mid-round counts as picking up', () {
    final e = _table();
    e.start(0);
    for (final id in ['h', 'a', 'b']) {
      e.setDown(id, true, 0);
    }
    e.tick(3000);
    e.leave('a', 13000);
    final s = e.snapshot(13000);
    expect(s.payerId, 'a');
    expect(s.player('a')!.dropped, isTrue);
  });

  test('no one sits down mid-round, but a reconnect keeps its seat', () {
    final e = _table();
    e.start(0);
    expect(e.join(_p('late')), isNotNull);
    expect(e.join(_p('a')), isNull);
    expect(e.snapshot(0).players, hasLength(3));
  });

  test('host can call it, and a rematch clears the tab', () {
    final e = _table();
    e.start(0);
    for (final id in ['h', 'a', 'b']) {
      e.setDown(id, true, 0);
    }
    e.tick(3000);
    e.setDown('h', false, 4000);
    e.callIt(10000);
    var s = e.snapshot(99999);
    expect(s.phase, Phase.done);
    expect(s.standing.map((p) => p.id), ['a', 'b']);

    e.start(100000);
    s = e.snapshot(100000);
    expect(s.round, 2);
    expect(s.payerId, isNull);
    expect(s.players.every((p) => !p.isOut), isTrue);
    // a and b never lifted, h is back up: still waiting on h.
    expect(s.phase, Phase.arming);
  });

  test('state survives the wire', () {
    final e = _table();
    e.start(0);
    e.setDown('a', true, 0);
    final s = e.snapshot(0);
    final back = RoomState.fromJson(s.toJson());
    expect(back.code, 'ABCD');
    expect(back.phase, Phase.arming);
    expect(back.player('a')!.down, isTrue);
    expect(back.host!.id, 'h');
  });

  test('codes avoid letters that read alike', () {
    for (var i = 0; i < 200; i++) {
      expect(
        RoomEngine.newCode(),
        matches(RegExp(r'^[ACDEFHJKMNPQRTUVWXY]{4}$')),
      );
    }
  });
}
