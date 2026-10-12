import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../main.dart';
import '../net/discovery.dart';
import '../net/invite.dart';
import '../net/session.dart';
import '../orders.dart';
import '../profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'table_screen.dart';

/// Tables on this Wi-Fi, a box for the code, and the QR scanner.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.profile, this.finder});

  final Profile profile;

  /// Injected in tests and screenshots.
  final TableFinder? finder;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TableFinder _finder = widget.finder ?? (TableFinder()..start());
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  String? _joining;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCode);
    _finder.addListener(_onCode);
  }

  @override
  void dispose() {
    _finder.removeListener(_onCode);
    if (widget.finder == null) _finder.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _onCode() {
    setState(() {});
    final code = _code.text;
    if (code.length != 4 || _joining != null) return;
    final found = _finder.byCode(code);
    if (found != null) _join(found.invite);
  }

  Future<void> _join(TableInvite invite) async {
    if (_joining != null) return;
    setState(
      () => _joining = invite.code.isEmpty ? invite.hosts.first : invite.code,
    );
    try {
      final session = await ClientSession.join(widget.profile.seat, invite);
      if (!mounted) {
        await session.close();
        return;
      }
      HapticFeedback.mediumImpact();
      await Navigator.of(context).pushReplacement(
        pageRoute(TableScreen(session: session, profile: widget.profile)),
      );
    } on JoinError catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast("Couldn't reach that table. Make sure you're on the same Wi-Fi.");
    } finally {
      if (mounted) setState(() => _joining = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _scan() async {
    final invite = await Navigator.of(
      context,
    ).push<TableInvite>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (invite != null) _join(invite);
  }

  Future<void> _typeAddress() async {
    final ctl = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brew.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type the address', style: serif(34)),
            const SizedBox(height: 6),
            Text(
              "It's under the QR code on the host's phone.",
              style: manrope(14, color: Brew.inkSoft),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: manrope(22, weight: FontWeight.w700, tabular: true),
              decoration: InputDecoration(
                hintText: '192.168.1.20:40123',
                hintStyle: manrope(22, color: Brew.inkFaint, tabular: true),
                filled: true,
                fillColor: Brew.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Brew.line),
                ),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            const SizedBox(height: 16),
            BrewButton(
              'Join',
              onTap: () => Navigator.of(context).pop(ctl.text),
            ),
          ],
        ),
      ),
    );
    if (text == null) return;
    final invite = TableInvite.parse(text);
    if (invite == null) {
      _toast('That doesn\'t look like an address. Try 192.168.1.20:40123.');
      return;
    }
    _join(invite);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final tables = _finder.tables;
    final code = _code.text;
    return Scaffold(
      body: Paper(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                pad.top + 16,
                24,
                pad.bottom + 24,
              ),
              children: [
                Row(
                  children: [
                    RoundIcon(
                      Icons.arrow_back_rounded,
                      label: 'Back',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Kicker('Join a table')),
                  ],
                ),
                const SizedBox(height: 28),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Find a\n'),
                      TextSpan(
                        text: 'table.',
                        style: serif(64, italic: true, color: Brew.crema),
                      ),
                    ],
                  ),
                  style: serif(64, height: 0.95),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask the host for their four-letter code, or tap their table below.',
                  style: manrope(15, color: Brew.inkSoft, height: 1.45),
                ),
                const SizedBox(height: 24),
                _CodeBoxes(controller: _code, focus: _codeFocus),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  child: code.length == 4 && _finder.byCode(code) == null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const PulseDot(color: Brew.crema),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Looking for $code on this Wi-Fi. It joins as soon as it shows up.',
                                  style: manrope(13, color: Brew.inkSoft),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 32),
                Kicker(
                  'On this Wi-Fi',
                  trailing: tables.isEmpty ? null : '${tables.length} found',
                ),
                const SizedBox(height: 8),
                if (tables.isEmpty)
                  _Searching(failed: _finder.failed)
                else
                  for (final t in tables)
                    _TableRow(table: t, onTap: () => _join(t.invite)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: BrewButton(
                        'Scan QR',
                        icon: Icons.qr_code_scanner_rounded,
                        style: BrewButtonStyle.quiet,
                        height: 52,
                        onTap: _scan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BrewButton(
                        'Address',
                        icon: Icons.keyboard_rounded,
                        style: BrewButtonStyle.quiet,
                        height: 52,
                        onTap: _typeAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _Tip(),
              ],
            ),
            if (_joining != null) _JoiningVeil(label: _joining!),
          ],
        ),
      ),
    );
  }
}

/// Four big letter boxes over a hidden text field.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    return GestureDetector(
      onTap: focus.requestFocus,
      child: Stack(
        children: [
          // The real field, invisible, catching the keyboard.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 84,
              child: TextField(
                controller: controller,
                focusNode: focus,
                maxLength: 4,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  TextInputFormatter.withFunction(
                    (_, v) => v.copyWith(text: v.text.toUpperCase()),
                  ),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: focus,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 84,
                      decoration: BoxDecoration(
                        color: Brew.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: focus.hasFocus && i == text.length.clamp(0, 3)
                              ? Brew.ink
                              : Brew.line,
                          width: focus.hasFocus && i == text.length.clamp(0, 3)
                              ? 1.8
                              : 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Text(
                          i < text.length ? text[i] : '',
                          key: ValueKey('$i${i < text.length ? text[i] : ''}'),
                          style: serif(52),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.table, required this.onTap});
  final FoundTable table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = table.invite;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Pressable(
        onTap: onTap,
        semanticLabel: "Join ${i.hostName}'s table",
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
          decoration: BoxDecoration(
            color: Brew.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Brew.line),
          ),
          child: Row(
            children: [
              CupGlyph(table.order, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${i.hostName}'s table",
                      overflow: TextOverflow.ellipsis,
                      style: serif(26),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'hosting · ${table.order.label.toLowerCase()} drinker',
                      style: manrope(12.5, color: Brew.inkSoft),
                    ),
                  ],
                ),
              ),
              Text(
                i.code.split('').join(' '),
                style: manrope(15, weight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rings rippling out from a cup while we listen for tables.
class _Searching extends StatefulWidget {
  const _Searching({required this.failed});
  final bool failed;

  @override
  State<_Searching> createState() => _SearchingState();
}

class _SearchingState extends State<_Searching>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Brew.line),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 56,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                painter: _RipplePainter(widget.failed ? 0 : _c.value),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.failed
                      ? 'Can\'t look around here'
                      : 'Listening for tables…',
                  style: serif(22),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.failed
                      ? 'Allow local network access, or scan the host\'s QR.'
                      : 'Once someone taps Host, it shows up here.',
                  style: manrope(13, color: Brew.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1;
      canvas.drawCircle(
        c,
        r * (0.25 + 0.75 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Brew.crema.withValues(alpha: (1 - p) * 0.8),
      );
    }
    canvas.drawCircle(c, r * 0.2, Paint()..color = Brew.ink);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

class _Tip extends StatelessWidget {
  const _Tip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Brew.paperDeep,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¶', style: serif(30, color: Brew.crema, height: 0.9)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Café Wi-Fi being difficult? ',
                  style: manrope(13.5, weight: FontWeight.w800),
                ),
                const TextSpan(
                  text:
                      'Some networks keep phones from seeing each other. '
                      'Have the host turn on their hotspot and everyone join that. No data is used.',
                ),
              ],
            ),
            style: manrope(13.5, color: Brew.inkSoft, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _JoiningVeil extends StatelessWidget {
  const _JoiningVeil({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Brew.paper.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: Brew.ink),
            ),
            const SizedBox(height: 18),
            Text('Pulling up a chair', style: serif(30, italic: true)),
            const SizedBox(height: 4),
            Text(label, style: kicker()),
          ],
        ),
      ),
    ),
  );
}

/// Full-screen camera with a viewfinder. Pops with the table it read.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final invite = TableInvite.parse(b.rawValue ?? '');
      if (invite != null) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(invite);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Brew.roast,
      body: Stack(
        children: [
          Positioned.fill(child: MobileScanner(onDetect: _onDetect)),
          Positioned.fill(child: CustomPaint(painter: _FinderPainter())),
          Positioned(
            top: pad.top + 16,
            left: 24,
            right: 24,
            child: Row(
              children: [
                RoundIcon(
                  Icons.close_rounded,
                  label: 'Close',
                  dark: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Kicker('Scan the host\'s code', dark: true),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: pad.bottom + 40,
            left: 24,
            right: 24,
            child: Text(
              'Point at the QR code on the host\'s phone.',
              textAlign: TextAlign.center,
              style: serif(24, italic: true, color: Brew.steam),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width * 0.7, 300.0);
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: s, height: s),
      const Radius.circular(28),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Brew.roast.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Brew.cremaLight,
    );
  }

  @override
  bool shouldRepaint(_FinderPainter old) => false;
}
