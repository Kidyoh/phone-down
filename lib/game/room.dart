import '../orders.dart';

/// Where a table is in a round.
enum Phase {
  /// Gathering players.
  lobby,

  /// The host hit start; waiting for every phone to go face down.
  arming,

  /// Everyone is down, counting in. Lifting a phone now just cancels.
  countdown,

  /// The clock is running. First phone up pays.
  live,

  /// Everyone's up (or the host called it). The tab is in.
  done,
}

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.order,
    this.host = false,
    this.down = false,
    this.outMs,
    this.dropped = false,
  });

  final String id;
  final String name;
  final Order order;
  final bool host;

  /// Phone is face down on the table right now.
  final bool down;

  /// When this player picked up, in ms since the round started.
  final int? outMs;

  /// Out because their connection went, not because they picked up.
  final bool dropped;

  bool get isOut => outMs != null;

  Player copyWith({
    bool? down,
    int? outMs,
    bool? dropped,
    bool clearOut = false,
  }) => Player(
    id: id,
    name: name,
    order: order,
    host: host,
    down: down ?? this.down,
    outMs: clearOut ? null : (outMs ?? this.outMs),
    dropped: clearOut ? false : (dropped ?? this.dropped),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'n': name,
    'o': order.name,
    if (host) 'h': true,
    if (down) 'd': true,
    if (outMs != null) 'x': outMs,
    if (dropped) 'dr': true,
  };

  factory Player.fromJson(Map<String, Object?> j) => Player(
    id: j['id'] as String,
    name: j['n'] as String,
    order: Order.parse(j['o'] as String?),
    host: j['h'] == true,
    down: j['d'] == true,
    outMs: (j['x'] as num?)?.toInt(),
    dropped: j['dr'] == true,
  );
}

/// Everything a phone needs to draw the table. The host owns it and sends
/// a fresh copy on every change.
class RoomState {
  const RoomState({
    required this.code,
    required this.phase,
    required this.players,
    this.round = 1,
    this.clockMs = 0,
    this.countdownMs = 0,
    this.tease = true,
    this.payerId,
  });

  /// Four letters, said out loud across the table.
  final String code;
  final Phase phase;
  final List<Player> players;

  /// Bumps on every rematch, so a phone records each result once.
  final int round;

  /// Time on the clock when this state was made (live and done).
  final int clockMs;

  /// Left on the countdown when this state was made.
  final int countdownMs;

  /// Buzz everyone's phone when someone picks up. Pure temptation.
  final bool tease;

  /// First one to pick up.
  final String? payerId;

  Player? player(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Player? get host => players.where((p) => p.host).firstOrNull;
  Player? get payer => payerId == null ? null : player(payerId!);
  Iterable<Player> get standing => players.where((p) => !p.isOut);

  /// Longest survivor first; anyone still down sits at the top.
  List<Player> get leaderboard {
    final list = [...players];
    list.sort((a, b) {
      final ax = a.outMs ?? 1 << 40;
      final bx = b.outMs ?? 1 << 40;
      if (ax != bx) return bx.compareTo(ax);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Map<String, Object?> toJson() => {
    'c': code,
    'p': phase.name,
    'r': round,
    'ck': clockMs,
    'cd': countdownMs,
    't': tease,
    if (payerId != null) 'pay': payerId,
    'pl': [for (final p in players) p.toJson()],
  };

  factory RoomState.fromJson(Map<String, Object?> j) => RoomState(
    code: j['c'] as String,
    phase: Phase.values.byName(j['p'] as String),
    round: (j['r'] as num?)?.toInt() ?? 1,
    clockMs: (j['ck'] as num?)?.toInt() ?? 0,
    countdownMs: (j['cd'] as num?)?.toInt() ?? 0,
    tease: j['t'] != false,
    payerId: j['pay'] as String?,
    players: [
      for (final p in (j['pl'] as List? ?? const []))
        Player.fromJson((p as Map).cast<String, Object?>()),
    ],
  );
}
