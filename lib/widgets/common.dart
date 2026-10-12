import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Shrinks a touch under the finger, with a tick of haptics.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onLongPress: widget.onLongPress,
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

enum BrewButtonStyle { solid, outline, quiet, danger, light, darkOutline }

/// The big pill buttons.
class BrewButton extends StatelessWidget {
  const BrewButton(
    this.label, {
    super.key,
    this.onTap,
    this.style = BrewButtonStyle.solid,
    this.icon,
    this.trailing,
    this.height = 60,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final BrewButtonStyle style;
  final IconData? icon;
  final String? trailing;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      BrewButtonStyle.solid => (Brew.ink, Brew.paper, Brew.ink),
      BrewButtonStyle.outline => (Colors.transparent, Brew.ink, Brew.ink),
      BrewButtonStyle.quiet => (Brew.paperDeep, Brew.ink, Brew.paperDeep),
      BrewButtonStyle.danger => (Brew.tomato, Brew.card, Brew.tomato),
      BrewButtonStyle.light => (Brew.steam, Brew.roast, Brew.steam),
      BrewButtonStyle.darkOutline => (
        Colors.transparent,
        Brew.steam,
        Brew.roastLine,
      ),
    };
    final enabled = onTap != null && !busy;
    return Pressable(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: trailing == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        ),
                      )
                    else if (icon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(icon, size: 20, color: fg),
                      ),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: manrope(16, weight: FontWeight.w700, color: fg),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  maxLines: 1,
                  style: serif(
                    22,
                    italic: true,
                    color: fg.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round icon button, like the back button on a menu card.
class RoundIcon extends StatelessWidget {
  const RoundIcon(
    this.icon, {
    super.key,
    required this.onTap,
    this.label,
    this.dark = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: dark ? Brew.roastLine : Brew.line,
          width: 1.2,
        ),
        color: dark ? Brew.roastUp : Brew.card,
      ),
      child: Icon(icon, size: size * 0.45, color: dark ? Brew.steam : Brew.ink),
    ),
  );
}

/// A hairline rule, as between columns of a newspaper.
class Rule extends StatelessWidget {
  const Rule({super.key, this.dark = false, this.double = false});
  final bool dark;
  final bool double;

  @override
  Widget build(BuildContext context) {
    final c = dark ? Brew.roastLine : Brew.ink;
    if (!double) {
      return Container(height: 1, color: dark ? Brew.roastLine : Brew.line);
    }
    return Column(
      children: [
        Container(height: 2, color: c),
        const SizedBox(height: 3),
        Container(height: 0.8, color: c),
      ],
    );
  }
}

/// A dashed line, for the receipt.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = Brew.line});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(color)),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 3.5, size.width), 0),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Cream paper with a faint speckle, so flat screens feel printed.
class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.color = Brew.paper,
    this.dark = false,
  });

  final Widget child;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: CustomPaint(
      isComplex: true,
      willChange: false,
      painter: _GrainPainter(dark),
      child: child,
    ),
  );
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final dots = (size.width * size.height / 260).round();
    final a = Paint()
      ..color = (dark ? Colors.white : Brew.ink).withValues(
        alpha: dark ? 0.025 : 0.035,
      );
    final b = Paint()
      ..color = (dark ? Colors.black : Colors.white).withValues(alpha: 0.12);
    for (var i = 0; i < dots; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      canvas.drawCircle(o, rnd.nextDouble() * 0.9 + 0.3, i.isEven ? a : b);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.dark != dark;
}

/// Digits in fixed-width boxes, so a running clock doesn't wobble.
class ClockText extends StatelessWidget {
  const ClockText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final ch in text.split(''))
          SizedBox(
            width: ch == ':' ? size * 0.26 : size * 0.5,
            child: Text(ch, textAlign: TextAlign.center, style: style),
          ),
      ],
    );
  }
}

/// A little "live" dot that breathes.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = Brew.olive, this.size = 8});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size * 2.4,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _PulsePainter(_c.value, widget.color, widget.size),
      ),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color, this.dot);
  final double t;
  final Color color;
  final double dot;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      dot / 2 + dot * 0.7 * t,
      Paint()..color = color.withValues(alpha: 0.35 * (1 - t)),
    );
    canvas.drawCircle(c, dot / 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// A rubber stamp, slightly crooked, as on a paid bill.
class Stamp extends StatelessWidget {
  const Stamp(
    this.text, {
    super.key,
    this.color = Brew.tomato,
    this.angle = -0.18,
    this.size = 14,
  });

  final String text;
  final Color color;
  final double angle;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.6,
        vertical: size * 0.22,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: color.withValues(alpha: 0.85),
          width: size * 0.14,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        text,
        style: manrope(
          size,
          weight: FontWeight.w800,
          color: color.withValues(alpha: 0.9),
          letterSpacing: size * 0.14,
        ),
      ),
    ),
  );
}

/// Kicker text with an optional rule running out to the right.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.dark = false, this.trailing});
  final String text;
  final bool dark;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = kicker(color: dark ? Brew.steamSoft : Brew.inkSoft);
    return LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          // Long kickers ellipsize; short ones leave the rule room to run.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Rule(dark: dark)),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(trailing!.toUpperCase(), maxLines: 1, style: style),
          ],
        ],
      ),
    );
  }
}
