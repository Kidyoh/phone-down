import 'dart:io';

/// How to reach a table: what goes in the QR code, and what discovery finds.
class TableInvite {
  const TableInvite({
    required this.code,
    required this.hosts,
    required this.port,
    this.hostName = '',
  });

  final String code;

  /// Every address the host phone might be reachable on, best first.
  final List<String> hosts;
  final int port;
  final String hostName;

  static const scheme = 'phonedown';

  Uri toUri() => Uri(
    scheme: scheme,
    host: 'table',
    queryParameters: {
      'c': code,
      'h': hosts.join(','),
      'p': '$port',
      if (hostName.isNotEmpty) 'n': hostName,
    },
  );

  /// Reads a scanned QR code, or a typed "192.168.1.20:40123".
  static TableInvite? parse(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    if (uri != null && uri.scheme == scheme) {
      final q = uri.queryParameters;
      final port = int.tryParse(q['p'] ?? '');
      final hosts = (q['h'] ?? '').split(',').where((h) => h.isNotEmpty);
      if (port == null || hosts.isEmpty) return null;
      return TableInvite(
        code: q['c'] ?? '',
        hosts: hosts.toList(),
        port: port,
        hostName: q['n'] ?? '',
      );
    }
    final m = RegExp(r'^([0-9a-fA-F:.]+?):(\d{2,5})$').firstMatch(text);
    if (m != null && InternetAddress.tryParse(m[1]!) != null) {
      return TableInvite(code: '', hosts: [m[1]!], port: int.parse(m[2]!));
    }
    return null;
  }

  /// This phone's LAN addresses. Wi-Fi and hotspot interfaces come first.
  static Future<List<String>> localAddresses() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      int rank(NetworkInterface i) {
        final n = i.name.toLowerCase();
        if (n.startsWith('wlan') || n.startsWith('en0')) return 0;
        if (n.startsWith('ap') ||
            n.startsWith('swlan') ||
            n.contains('bridge')) {
          return 1;
        }
        if (n.startsWith('en') || n.startsWith('eth')) return 2;
        if (n.startsWith('rmnet') ||
            n.startsWith('pdp') ||
            n.startsWith('ccmni')) {
          return 9; // Mobile data: never reachable from the next phone over.
        }
        return 5;
      }

      ifaces.sort((a, b) => rank(a).compareTo(rank(b)));
      return [
        for (final i in ifaces)
          if (rank(i) < 9)
            for (final a in i.addresses)
              if (!a.isLinkLocal) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }
}
