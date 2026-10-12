import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import '../orders.dart';
import 'invite.dart';

const _type = '_phonedown._tcp';

/// Announces this phone's table on the local network.
class TableAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start(TableInvite invite, Order order) async {
    final b = BonsoirBroadcast(
      service: BonsoirService(
        name: "${invite.hostName}'s table ${invite.code}",
        type: _type,
        port: invite.port,
        attributes: {'c': invite.code, 'n': invite.hostName, 'o': order.name},
      ),
    );
    _broadcast = b;
    await b.initialize();
    await b.start();
  }

  Future<void> stop() async {
    await _broadcast?.stop();
    _broadcast = null;
  }
}

/// A table someone nearby is hosting.
class FoundTable {
  const FoundTable(this.invite, this.order);
  final TableInvite invite;
  final Order order;
}

/// Watches the Wi-Fi for tables. Lists only the ones it can connect to.
class TableFinder extends ChangeNotifier {
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;
  final _tables = <String, FoundTable>{};
  bool _searching = false;
  bool _failed = false;

  List<FoundTable> get tables => _tables.values.toList(growable: false);
  bool get searching => _searching;

  /// Discovery couldn't start (no Wi-Fi, or local network access denied).
  bool get failed => _failed;

  FoundTable? byCode(String code) {
    for (final t in _tables.values) {
      if (t.invite.code == code) return t;
    }
    return null;
  }

  Future<void> start() async {
    if (_discovery != null) return;
    try {
      final d = BonsoirDiscovery(type: _type);
      _discovery = d;
      await d.initialize();
      _sub = d.eventStream?.listen((event) {
        switch (event) {
          case BonsoirDiscoveryServiceFoundEvent():
            d.serviceResolver.resolveService(event.service);
          case BonsoirDiscoveryServiceResolvedEvent():
          case BonsoirDiscoveryServiceUpdatedEvent():
            _add(event.service!);
          case BonsoirDiscoveryServiceLostEvent():
            if (_tables.remove(event.service.name) != null) notifyListeners();
          default:
            break;
        }
      });
      await d.start();
      _searching = true;
    } catch (_) {
      _failed = true;
    }
    notifyListeners();
  }

  void _add(BonsoirService s) {
    final hosts = s.hostAddresses.where((a) => !a.contains(':')).toList();
    if (hosts.isEmpty || s.port <= 0) return;
    final a = s.attributes;
    _tables[s.name] = FoundTable(
      TableInvite(
        code: a['c'] ?? '',
        hosts: hosts,
        port: s.port,
        hostName: a['n'] ?? s.name,
      ),
      Order.parse(a['o']),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _discovery?.stop();
    super.dispose();
  }
}
