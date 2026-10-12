import 'package:flutter_test/flutter_test.dart';
import 'package:phone_down/game/room.dart';
import 'package:phone_down/net/invite.dart';
import 'package:phone_down/net/session.dart';
import 'package:phone_down/orders.dart';

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ok(), isTrue);
}

void main() {
  test('a phone joins over the network and plays a round', () async {
    final host = await HostSession.open(
      const Seat(id: 'host', name: 'Mia', order: Order.cortado),
      advertise: false,
    );
    final local = TableInvite(
      code: host.invite.code,
      hosts: ['127.0.0.1'],
      port: host.invite.port,
    );
    final guest = await ClientSession.join(
      const Seat(id: 'g1', name: 'Sam', order: Order.mocha),
      local,
    );
    addTearDown(() async {
      await guest.close();
      await host.close();
    });

    await _until(() => host.state!.players.length == 2);
    expect(guest.state!.player('host')!.name, 'Mia');
    expect(guest.state!.code, host.invite.code);

    host.start();
    host.setDown(true);
    guest.setDown(true);
    await _until(() => guest.state!.phase == Phase.countdown);
    await _until(() => guest.state!.phase == Phase.live);

    guest.setDown(false);
    await _until(() => host.state!.payerId == 'g1');
    host.setDown(false);
    await _until(() => guest.state!.phase == Phase.done);
    expect(guest.state!.payer!.name, 'Sam');
    expect(guest.state!.leaderboard.first.id, 'host');
  });

  test('a late arrival is turned away mid-round', () async {
    final host = await HostSession.open(
      const Seat(id: 'host', name: 'Mia', order: Order.latte),
      advertise: false,
    );
    addTearDown(host.close);
    host.start();
    host.setDown(true);
    await _until(() => host.state!.phase == Phase.live);
    final invite = TableInvite(
      code: '',
      hosts: ['127.0.0.1'],
      port: host.invite.port,
    );
    await expectLater(
      ClientSession.join(
        const Seat(id: 'x', name: 'Late', order: Order.tea),
        invite,
      ),
      throwsA(isA<JoinError>()),
    );
  });

  test('invite links round-trip through the QR code', () {
    const invite = TableInvite(
      code: 'KQMV',
      hosts: ['192.168.1.20', '10.0.0.4'],
      port: 40123,
      hostName: 'Mia',
    );
    final back = TableInvite.parse(invite.toUri().toString())!;
    expect(back.code, 'KQMV');
    expect(back.hosts, ['192.168.1.20', '10.0.0.4']);
    expect(back.port, 40123);
    expect(back.hostName, 'Mia');
    expect(TableInvite.parse('192.168.1.20:40123')!.port, 40123);
    expect(TableInvite.parse('hello'), isNull);
  });
}
