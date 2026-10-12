import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/room.dart';
import '../game/room_engine.dart';
import '../orders.dart';
import 'discovery.dart';
import 'invite.dart';

/// Who's sitting down: this phone's player.
class Seat {
  const Seat({required this.id, required this.name, required this.order});
  final String id;
  final String name;
  final Order order;
}

/// One phone's view of a table, whether it hosts or joined. Screens only
/// talk to this, so another transport (Nearby, a cloud room) can slot in.
abstract class TableSession extends ChangeNotifier {
  TableSession(this.seat);

  final Seat seat;
  String get meId => seat.id;
  bool get isHost;

  RoomState? _state;
  final _since = Stopwatch();
  String? _error;

  RoomState? get state => _state;
  Player? get me => _state?.player(meId);

  /// Set when the table is gone: the host left, or the Wi-Fi did.
  String? get error => _error;

  /// How to bring more people in: the QR code and the address line.
  TableInvite? get invite;

  /// The round clock right now, filled in between updates from the host.
  int get clockMs {
    final s = _state;
    if (s == null) return 0;
    return s.phase == Phase.live
        ? s.clockMs + _since.elapsedMilliseconds
        : s.clockMs;
  }

  int get countdownMs {
    final s = _state;
    if (s == null || s.phase != Phase.countdown) return 0;
    return math.max(0, s.countdownMs - _since.elapsedMilliseconds);
  }

  @protected
  void apply(RoomState s) {
    _state = s;
    _since
      ..reset()
      ..start();
    notifyListeners();
  }

  @protected
  void fail(String message) {
    if (_error != null) return;
    _error = message;
    notifyListeners();
  }

  void setDown(bool down);

  // Host-only controls. Joined phones ignore them.
  void start() {}
  void cancel() {}
  void callIt() {}
  void setTease(bool on) {}

  Future<void> close();
}

/// This phone runs the table: the rules, a small WebSocket server, and an
/// mDNS broadcast so phones on the same Wi-Fi can find it.
class HostSession extends TableSession {
  HostSession._(
    super.seat,
    this._engine,
    this._server,
    this._invite,
    this._advertiser,
  ) {
    _clock.start();
    _server.listen(_accept);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _publish();
  }

  static Future<HostSession> open(Seat seat, {bool advertise = true}) async {
    final code = RoomEngine.newCode();
    final engine = RoomEngine(
      code: code,
      host: Player(id: seat.id, name: seat.name, order: seat.order, host: true),
    );
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final invite = TableInvite(
      code: code,
      hosts: await TableInvite.localAddresses(),
      port: server.port,
      hostName: seat.name,
    );
    TableAdvertiser? advertiser;
    if (advertise) {
      advertiser = TableAdvertiser();
      unawaited(advertiser.start(invite, seat.order).catchError((_) {}));
    }
    return HostSession._(seat, engine, server, invite, advertiser);
  }

  final RoomEngine _engine;
  final HttpServer _server;
  final TableInvite _invite;
  final TableAdvertiser? _advertiser;
  final _clock = Stopwatch();
  final _clients = <WebSocket, String?>{};
  late final Timer _ticker;
  int _lastSync = 0;

  @override
  bool get isHost => true;

  @override
  TableInvite get invite => _invite;

  int get _now => _clock.elapsedMilliseconds;

  void _tick() {
    final changed = _engine.tick(_now);
    // A heartbeat keeps every phone's clock honest during a round.
    final live = _engine.phase == Phase.live;
    if (changed || (live && _now - _lastSync > 1000)) _publish();
  }

  void _publish() {
    _lastSync = _now;
    final s = _engine.snapshot(_now);
    final msg = jsonEncode({'t': 'state', 's': s.toJson()});
    for (final entry in _clients.entries) {
      if (entry.value != null) entry.key.add(msg);
    }
    apply(s);
  }

  Future<void> _accept(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..write('Phone Down table ${_invite.code}');
      await req.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    ws.pingInterval = const Duration(seconds: 2);
    _clients[ws] = null;
    ws.listen(
      (data) => _onMessage(ws, data),
      onDone: () => _drop(ws),
      onError: (_) => _drop(ws),
      cancelOnError: true,
    );
  }

  void _onMessage(WebSocket ws, Object? data) {
    final Map<String, Object?> m;
    try {
      m = (jsonDecode(data as String) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    final id = _clients[ws];
    switch (m['t']) {
      case 'hello' when id == null:
        final pid = m['id'] as String? ?? '';
        if (pid.isEmpty || pid == meId) {
          _clients.remove(ws);
          ws.close();
          return;
        }
        final why = _engine.join(
          Player(
            id: pid,
            name: _clean(m['n'] as String?),
            order: Order.parse(m['o'] as String?),
          ),
        );
        if (why != null) {
          _clients.remove(ws);
          ws.add(jsonEncode({'t': 'no', 'why': why}));
          ws.close();
          return;
        }
        // One socket per player: a reconnect replaces the old one.
        for (final e in _clients.entries.toList()) {
          if (e.value == pid && e.key != ws) {
            _clients.remove(e.key);
            e.key.close();
          }
        }
        _clients[ws] = pid;
        _publish();
      case 'down' when id != null:
        _engine.setDown(id, m['v'] == true, _now);
        _publish();
      case 'bye' when id != null:
        _clients[ws] = null;
        _engine.leave(id, _now);
        _publish();
        ws.close();
    }
  }

  void _drop(WebSocket ws) {
    final id = _clients.remove(ws);
    if (id == null) return;
    // Give a blip of bad Wi-Fi a moment before counting it as leaving.
    Timer(const Duration(seconds: 4), () {
      if (_clients.containsValue(id)) return;
      _engine.leave(id, _now);
      _publish();
    });
  }

  static String _clean(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'Someone';
    return n.length > 18 ? n.substring(0, 18) : n;
  }

  @override
  void setDown(bool down) {
    _engine.setDown(meId, down, _now);
    _publish();
  }

  @override
  void start() {
    _engine.start(_now);
    _publish();
  }

  @override
  void cancel() {
    _engine.cancel();
    _publish();
  }

  @override
  void callIt() {
    _engine.callIt(_now);
    _publish();
  }

  @override
  void setTease(bool on) {
    _engine.tease = on;
    _publish();
  }

  @override
  Future<void> close() async {
    _ticker.cancel();
    for (final ws in _clients.keys.toList()) {
      if (ws.closeCode != null) continue;
      ws.add(jsonEncode({'t': 'no', 'why': 'The host closed the table.'}));
      await ws.close();
    }
    _clients.clear();
    await _advertiser?.stop();
    await _server.close(force: true);
  }
}

/// Thrown when a table won't have us.
class JoinError implements Exception {
  JoinError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A phone that sat down at someone else's table.
class ClientSession extends TableSession {
  ClientSession._(super.seat, this._invite);

  static Future<ClientSession> join(Seat seat, TableInvite invite) async {
    final session = ClientSession._(seat, invite);
    await session._connect(firstTime: true);
    return session;
  }

  TableInvite _invite;
  WebSocket? _ws;
  bool _closing = false;
  bool _down = false;

  @override
  bool get isHost => false;

  @override
  TableInvite get invite => _invite;

  Future<void> _connect({bool firstTime = false}) async {
    Object? lastError;
    for (final host in _invite.hosts) {
      try {
        final uri = Uri(
          scheme: 'ws',
          host: host,
          port: _invite.port,
          path: '/t',
        );
        final ws = await WebSocket.connect(uri.toString())
            .timeout(const Duration(seconds: 4));
        ws.pingInterval = const Duration(seconds: 2);
        final first = Completer<void>();
        ws.listen(
          (data) => _onMessage(data, first),
          onDone: () => _lost(first),
          onError: (_) => _lost(first),
          cancelOnError: true,
        );
        ws.add(
          jsonEncode({
            't': 'hello',
            'id': seat.id,
            'n': seat.name,
            'o': seat.order.name,
          }),
        );
        _ws = ws;
        await first.future.timeout(const Duration(seconds: 5));
        // Put the working address first for any reconnect.
        _invite = TableInvite(
          code: state?.code ?? _invite.code,
          hosts: [host, ..._invite.hosts.where((h) => h != host)],
          port: _invite.port,
          hostName: _invite.hostName,
        );
        if (_down) _send({'t': 'down', 'v': true});
        return;
      } on JoinError {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    throw JoinError(
      firstTime
          ? "Couldn't reach that table. Make sure you're on the same Wi-Fi."
          : 'Lost the table. ${lastError ?? ''}'.trim(),
    );
  }

  void _onMessage(Object? data, Completer<void> first) {
    final Map<String, Object?> m;
    try {
      m = (jsonDecode(data as String) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (m['t']) {
      case 'state':
        apply(RoomState.fromJson((m['s'] as Map).cast<String, Object?>()));
        if (!first.isCompleted) first.complete();
      case 'no':
        final why = m['why'] as String? ?? "That table won't have you.";
        _closing = true;
        if (!first.isCompleted) {
          first.completeError(JoinError(why));
        } else {
          fail(why);
        }
    }
  }

  void _lost(Completer<void> first) {
    if (!first.isCompleted) {
      first.completeError(const SocketException('The table hung up.'));
      return;
    }
    if (_closing) return;
    _ws = null;
    _reconnect();
  }

  Future<void> _reconnect() async {
    for (var attempt = 0; attempt < 5 && !_closing; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      if (_closing) return;
      try {
        await _connect();
        return;
      } on JoinError catch (e) {
        if (e.message.startsWith('Lost')) continue;
        fail(e.message);
        return;
      }
    }
    if (!_closing) fail('Lost the table. The host may have left.');
  }

  void _send(Map<String, Object?> m) => _ws?.add(jsonEncode(m));

  @override
  void setDown(bool down) {
    _down = down;
    _send({'t': 'down', 'v': down});
  }

  @override
  Future<void> close() async {
    _closing = true;
    _send({'t': 'bye'});
    await _ws?.close();
  }
}
