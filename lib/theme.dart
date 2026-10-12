import 'package:flutter/material.dart';

/// Warm coffee editorial: cream paper and espresso ink for the room,
/// a dark roast for the table once phones go down.
abstract final class Brew {
  static const paper = Color(0xFFF3EADB);
  static const paperDeep = Color(0xFFE8DAC3);
  static const card = Color(0xFFFBF6EE);
  static const line = Color(0xFFD8C6AC);

  static const ink = Color(0xFF241812);
  static const inkSoft = Color(0xFF6F5A4A);
  static const inkFaint = Color(0xFFA48D78);

  static const crema = Color(0xFFC8894A);
  static const cremaLight = Color(0xFFE7C397);
  static const tomato = Color(0xFFD4462A);
  static const olive = Color(0xFF5E7A4F);

  static const roast = Color(0xFF1A110C);
  static const roastUp = Color(0xFF261A13);
  static const roastLine = Color(0xFF3A2A20);
  static const steam = Color(0xFFEFE3D0);
  static const steamSoft = Color(0xFFA8927E);
}

/// Instrument Serif: headlines, the big numbers, the room code.
TextStyle serif(
  double size, {
  Color color = Brew.ink,
  bool italic = false,
  double letterSpacing = -0.5,
  double? height = 1.0,
}) => TextStyle(
  fontFamily: 'InstrumentSerif',
  fontSize: size,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  fontWeight: FontWeight.w400,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// Manrope ships as a variable font, so the weight is set on the `wght` axis.
TextStyle manrope(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = Brew.ink,
  double letterSpacing = 0,
  double? height,
  bool tabular = false,
}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation.weight(weight.value.toDouble())],
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// The small spaced capitals above a headline, like a newspaper kicker.
TextStyle kicker({Color color = Brew.inkSoft, double size = 11}) =>
    manrope(size, weight: FontWeight.w700, color: color, letterSpacing: 1.8);

ThemeData brewTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brew.crema,
    surface: Brew.paper,
    primary: Brew.ink,
    onPrimary: Brew.paper,
    secondary: Brew.crema,
    error: Brew.tomato,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brew.paper,
    fontFamily: 'Manrope',
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Brew.crema,
      selectionColor: Brew.cremaLight,
      selectionHandleColor: Brew.crema,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brew.ink,
      contentTextStyle: manrope(14, color: Brew.paper),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// 754_000 ms -> "12:34", 4_003_000 -> "1:06:43".
String formatClock(int ms) {
  final s = (ms ~/ 1000).clamp(0, 359999);
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// Short spoken form for summaries: "12m 34s", "1h 06m", "48s".
String formatSpan(int ms) {
  final s = ms ~/ 1000;
  if (s < 60) return '${s}s';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m ${(s % 60).toString().padLeft(2, '0')}s';
}
