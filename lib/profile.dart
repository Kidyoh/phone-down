import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/room.dart';
import 'net/session.dart';
import 'orders.dart';

/// One finished round, as this phone saw it.
class RoundRecord {
  const RoundRecord({
    required this.at,
    required this.players,
    required this.myMs,
    required this.payer,
    required this.iPaid,
    required this.place,
  });

  final DateTime at;
  final int players;
  final int myMs;
  final String payer;
  final bool iPaid;

  /// 1 is the last one down.
  final int place;

  Map<String, Object> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'n': players,
    'ms': myMs,
    'pay': payer,
    'ip': iPaid,
    'pl': place,
  };

  factory RoundRecord.fromJson(Map<String, Object?> j) => RoundRecord(
    at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
    players: (j['n'] as num).toInt(),
    myMs: (j['ms'] as num).toInt(),
    payer: j['pay'] as String,
    iPaid: j['ip'] == true,
    place: (j['pl'] as num).toInt(),
  );
}

/// Your name, your usual, and your record. Lives on the phone.
class Profile extends ChangeNotifier {
  Profile(this._prefs) {
    final saved = _prefs.getString('id');
    id = saved ?? _newId();
    if (saved == null) _prefs.setString('id', id);
    _name = _prefs.getString('name') ?? '';
    _order = Order.parse(_prefs.getString('order'));
    final raw = _prefs.getString('history');
    if (raw != null) {
      try {
        _history = [
          for (final r in jsonDecode(raw) as List)
            RoundRecord.fromJson((r as Map).cast<String, Object?>()),
        ];
      } catch (_) {}
    }
  }

  static Future<Profile> load() async =>
      Profile(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  late final String id;
  String _name = '';
  Order _order = Order.flatWhite;
  List<RoundRecord> _history = [];
  String? _lastRound;

  String get name => _name;
  Order get order => _order;
  bool get isSetUp => _name.isNotEmpty;
  List<RoundRecord> get history => List.unmodifiable(_history);

  Seat get seat => Seat(id: id, name: _name, order: _order);

  int get rounds => _history.length;
  int get timesPaid => _history.where((r) => r.iPaid).length;
  int get wins => _history.where((r) => r.place == 1 && r.players > 1).length;
  int get bestMs => _history.fold(0, (m, r) => math.max(m, r.myMs));

  /// Coffees other people bought you.
  int get coffeesWon => _history.where((r) => !r.iPaid && r.players > 1).length;

  void save({required String name, required Order order}) {
    _name = name.trim();
    _order = order;
    _prefs.setString('name', _name);
    _prefs.setString('order', _order.name);
    notifyListeners();
  }

  /// Saves a finished round once, however many times the screen rebuilds.
  void record(RoomState s, String code) {
    if (s.phase != Phase.done) return;
    final key = '$code/${s.round}';
    if (_lastRound == key) return;
    _lastRound = key;
    final me = s.player(id);
    if (me == null) return;
    final board = s.leaderboard;
    _history = [
      RoundRecord(
        at: DateTime.now(),
        players: s.players.length,
        myMs: me.outMs ?? s.clockMs,
        payer: s.payer?.name ?? '',
        iPaid: s.payerId == id,
        place: board.indexWhere((p) => p.id == id) + 1,
      ),
      ..._history,
    ].take(50).toList();
    _prefs.setString(
      'history',
      jsonEncode([for (final r in _history) r.toJson()]),
    );
    notifyListeners();
  }

  static String _newId() {
    final r = math.Random.secure();
    return List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
