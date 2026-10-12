import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_down/game/room.dart';
import 'package:phone_down/main.dart';
import 'package:phone_down/net/invite.dart';
import 'package:phone_down/net/session.dart';
import 'package:phone_down/orders.dart';
import 'package:phone_down/profile.dart';
import 'package:phone_down/screens/table_screen.dart';
import 'package:phone_down/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session extends TableSession {
  _Session(super.seat, RoomState s) {
    apply(s);
  }
  final downs = <bool>[];
  void push(RoomState s) => apply(s);
  @override
  bool get isHost => false;
  @override
  TableInvite? get invite => null;
  @override
  void setDown(bool down) => downs.add(down);
  @override
  Future<void> close() async {}
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('first launch: name and order, then the front page', (
    tester,
  ) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final profile = (await tester.runAsync(Profile.load))!;
    await tester.pumpWidget(PhoneDownApp(profile: profile));
    await _settle(tester);
    expect(find.text('Take a seat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sam');
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    await tester.ensureVisible(find.text('Mocha'));
    await _settle(tester);
    await tester.tap(find.text('Mocha'));
    await _settle(tester);
    await tester.tap(find.text('Take a seat'));
    await _settle(tester);

    expect(find.text('Host a table'), findsOneWidget);
    expect(profile.name, 'Sam');
    expect(profile.order, Order.mocha);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the table follows the round and records the result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'id': 'me',
      'name': 'Sam',
      'order': 'mocha',
    });
    final profile = (await tester.runAsync(Profile.load))!;
    final players = [
      const Player(id: 'h', name: 'Mia', order: Order.cortado, host: true),
      const Player(id: 'me', name: 'Sam', order: Order.mocha),
    ];
    final session = _Session(
      profile.seat,
      RoomState(code: 'KQMV', phase: Phase.lobby, players: players),
    );
    final sensor = StreamController<bool>();
    await tester.pumpWidget(
      MaterialApp(
        theme: brewTheme(),
        home: TableScreen(
          session: session,
          profile: profile,
          faceDown: sensor.stream,
          useWakelock: false,
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('KQMV'), findsOneWidget);
    expect(find.textContaining('Waiting for'), findsOneWidget);

    sensor.add(true);
    await _settle(tester);
    expect(session.downs, [true]);

    session.push(
      RoomState(code: 'KQMV', phase: Phase.arming, players: players),
    );
    await _settle(tester);
    expect(find.textContaining('Phones', findRichText: true), findsOneWidget);

    session.push(
      RoomState(
        code: 'KQMV',
        phase: Phase.done,
        clockMs: 90000,
        payerId: 'me',
        players: [
          players[0].copyWith(outMs: 90000),
          players[1].copyWith(outMs: 30000),
        ],
      ),
    );
    await _settle(tester);
    expect(find.textContaining('buying.', findRichText: true), findsOneWidget);
    expect(profile.timesPaid, 1);
    expect(profile.history.single.place, 2);

    await tester.pumpWidget(const SizedBox());
    unawaited(sensor.close());
  });
}
