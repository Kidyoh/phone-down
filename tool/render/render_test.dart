// Renders app screens to PNG for the README. Not part of the normal test
// run; use: flutter test tool/render --update-goldens
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_down/game/room.dart';
import 'package:phone_down/main.dart';
import 'package:phone_down/net/discovery.dart';
import 'package:phone_down/net/invite.dart';
import 'package:phone_down/net/session.dart';
import 'package:phone_down/orders.dart';
import 'package:phone_down/profile.dart';
import 'package:phone_down/screens/join_screen.dart';
import 'package:phone_down/screens/table_screen.dart';
import 'package:phone_down/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
    );
  }
  await loader.load();
}

Future<void> _fonts() async {
  await _font('Manrope', ['assets/fonts/Manrope.ttf']);
  await _font('InstrumentSerif', [
    'assets/fonts/InstrumentSerif-Regular.ttf',
    'assets/fonts/InstrumentSerif-Italic.ttf',
  ]);
  final flutterRoot = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .parent
      .path;
  await _font('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

class FakeSession extends TableSession {
  FakeSession(super.seat, RoomState s, {this.host = true, this.clock = 0}) {
    apply(s);
  }
  final bool host;
  final int clock;
  @override
  bool get isHost => host;
  @override
  int get clockMs => clock;
  @override
  int get countdownMs => 2400;
  @override
  TableInvite get invite => TableInvite(
    code: state!.code,
    hosts: ['192.168.1.20'],
    port: 40123,
    hostName: 'Mia',
  );
  @override
  void setDown(bool down) {}
  @override
  Future<void> close() async {}
}

class FakeFinder extends TableFinder {
  FakeFinder(this._list);
  final List<FoundTable> _list;
  @override
  List<FoundTable> get tables => _list;
  @override
  Future<void> start() async {}
}

const _me = Seat(id: 'me', name: 'Mia', order: Order.cortado);

List<Player> _players({
  Map<String, bool> down = const {},
  Map<String, int> out = const {},
}) => [
  for (final (id, name, order, host) in [
    ('me', 'Mia', Order.cortado, true),
    ('sam', 'Sam', Order.mocha, false),
    ('jo', 'Jo', Order.latte, false),
    ('ade', 'Adeola', Order.americano, false),
    ('kai', 'Kai', Order.matcha, false),
  ])
    Player(
      id: id,
      name: name,
      order: order,
      host: host,
      down: down[id] ?? false,
      outMs: out[id],
    ),
];

Future<Profile> _profile({bool history = true, String name = 'Mia'}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'id': 'me',
    if (name.isNotEmpty) 'name': name,
    'order': 'cortado',
    if (history)
      'history':
          '[{"at":$now,"n":5,"ms":1450000,"pay":"Sam","ip":false,"pl":1},'
          '{"at":${now - 86400000 * 2},"n":4,"ms":312000,"pay":"Mia","ip":true,"pl":4},'
          '{"at":${now - 86400000 * 5},"n":3,"ms":905000,"pay":"Jo","ip":false,"pl":2}]',
  });
  return Profile.load();
}

Future<void> _setUp(WidgetTester tester) async {
  // Real shadows instead of the test outline, so the receipt looks printed.
  debugDisableShadows = false;
  await tester.runAsync(_fonts);
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  debugDisableShadows = true;
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _snap(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('out/$name.png'),
);

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brewTheme(),
  home: home,
);

Future<void> _table(
  WidgetTester tester,
  String name,
  RoomState s, {
  bool host = true,
  int clock = 0,
  bool down = false,
  double scroll = 0,
}) async {
  await _setUp(tester);
  final profile = (await tester.runAsync(() => _profile()))!;
  final faceDown = StreamController<bool>();
  await tester.pumpWidget(
    _app(
      TableScreen(
        session: FakeSession(_me, s, host: host, clock: clock),
        profile: profile,
        faceDown: faceDown.stream,
        useWakelock: false,
      ),
    ),
  );
  faceDown.add(down);
  await _frames(tester, 90);
  if (scroll != 0) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
    await _frames(tester, 40);
  }
  await _snap(tester, name);
  await _done(tester);
  unawaited(faceDown.close());
}

void main() {
  testWidgets('home', (tester) async {
    await _setUp(tester);
    final profile = (await tester.runAsync(() => _profile()))!;
    await tester.pumpWidget(PhoneDownApp(profile: profile));
    await _frames(tester, 90);
    await _snap(tester, 'home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await _frames(tester, 40);
    await _snap(tester, 'home_log');
    await _done(tester);
  });

  testWidgets('onboarding', (tester) async {
    await _setUp(tester);
    final profile = (await tester.runAsync(
      () => _profile(history: false, name: ''),
    ))!;
    await tester.pumpWidget(PhoneDownApp(profile: profile));
    await _frames(tester, 20);
    await tester.enterText(find.byType(TextField), 'Mia');
    await tester.tap(find.text('Cortado'));
    await _frames(tester, 40);
    FocusManager.instance.primaryFocus?.unfocus();
    await _frames(tester, 40);
    await _snap(tester, 'onboarding');
    await _done(tester);
  });

  testWidgets('join', (tester) async {
    await _setUp(tester);
    final profile = (await tester.runAsync(() => _profile()))!;
    final finder = FakeFinder([
      const FoundTable(
        TableInvite(
          code: 'KQMV',
          hosts: ['192.168.1.20'],
          port: 1,
          hostName: 'Mia',
        ),
        Order.cortado,
      ),
      const FoundTable(
        TableInvite(
          code: 'RTDA',
          hosts: ['192.168.1.31'],
          port: 1,
          hostName: 'Desta',
        ),
        Order.flatWhite,
      ),
    ]);
    await tester.pumpWidget(_app(JoinScreen(profile: profile, finder: finder)));
    await _frames(tester, 60);
    await _snap(tester, 'join');
    await _done(tester);
  });

  testWidgets('lobby', (tester) async {
    await _table(
      tester,
      'lobby',
      RoomState(code: 'KQMV', phase: Phase.lobby, players: _players()),
    );
  });

  testWidgets('lobby_guest', (tester) async {
    await _table(
      tester,
      'lobby_guest',
      RoomState(code: 'KQMV', phase: Phase.lobby, players: _players()),
      host: false,
      scroll: 900,
    );
  });

  testWidgets('arming', (tester) async {
    await _table(
      tester,
      'arming',
      RoomState(
        code: 'KQMV',
        phase: Phase.arming,
        players: _players(down: {'sam': true, 'jo': true, 'kai': true}),
      ),
    );
  });

  testWidgets('countdown', (tester) async {
    await _table(
      tester,
      'countdown',
      RoomState(
        code: 'KQMV',
        phase: Phase.countdown,
        countdownMs: 2400,
        players: _players(
          down: {
            for (final id in ['me', 'sam', 'jo', 'ade', 'kai']) id: true,
          },
        ),
      ),
    );
  });

  testWidgets('live', (tester) async {
    await _table(
      tester,
      'live',
      RoomState(
        code: 'KQMV',
        phase: Phase.live,
        clockMs: 1104000,
        payerId: 'sam',
        players: _players(
          down: {'jo': true, 'ade': true, 'kai': true},
          out: {'sam': 402000, 'me': 1061000},
        ),
      ),
      clock: 1104000,
    );
  });

  testWidgets('live_payer', (tester) async {
    await _table(
      tester,
      'live_payer',
      RoomState(
        code: 'KQMV',
        phase: Phase.live,
        clockMs: 254000,
        payerId: 'me',
        players: _players(
          down: {'sam': true, 'jo': true, 'ade': true, 'kai': true},
          out: {'me': 252000},
        ),
      ),
      clock: 254000,
      host: false,
    );
  });

  testWidgets('tab', (tester) async {
    await _table(
      tester,
      'tab',
      RoomState(
        code: 'KQMV',
        phase: Phase.done,
        round: 3,
        clockMs: 1450000,
        payerId: 'sam',
        players: _players(
          out: {
            'sam': 402000,
            'me': 1061000,
            'jo': 1450000,
            'ade': 1302000,
            'kai': 734000,
          },
        ),
      ),
    );
  });

  testWidgets('tab_receipt', (tester) async {
    await _table(
      tester,
      'tab_receipt',
      RoomState(
        code: 'KQMV',
        phase: Phase.done,
        round: 3,
        clockMs: 1450000,
        payerId: 'sam',
        players: _players(
          out: {
            'sam': 402000,
            'me': 1061000,
            'jo': 1450000,
            'ade': 1302000,
            'kai': 734000,
          },
        ),
      ),
      scroll: 520,
    );
  });
}
