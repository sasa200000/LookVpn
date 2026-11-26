import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/theme_color.dart';

/// The persisted light-dance preferences, as one immutable value.
class LightDanceConfig {
  const LightDanceConfig({
    this.enabled = true,
    this.style = 'orbit',
    this.palette = 'spectrum',
    this.colorStepSeconds = 1.0,
    this.speedSeconds = 1.6,
    this.colorCycle = true,
    this.colors = const [],
  });

  final bool enabled;
  final String style;
  final String palette;
  final double colorStepSeconds;
  final double speedSeconds;
  final bool colorCycle;
  final List<Color> colors;

  LightDanceStyle get styleValue =>
      LightDanceStyle.values.firstWhere(
        (s) => s.name == style,
        orElse: () => LightDanceStyle.orbit,
      );

  LightDancePalette get paletteValue =>
      LightDancePalette.values.firstWhere(
        (p) => p.name == palette,
        orElse: () => LightDancePalette.spectrum,
      );

  LightDanceConfig copyWith({
    bool? enabled,
    String? style,
    String? palette,
    double? colorStepSeconds,
    double? speedSeconds,
    bool? colorCycle,
    List<Color>? colors,
  }) => LightDanceConfig(
    enabled: enabled ?? this.enabled,
    style: style ?? this.style,
    palette: palette ?? this.palette,
    colorStepSeconds: colorStepSeconds ?? this.colorStepSeconds,
    speedSeconds: speedSeconds ?? this.speedSeconds,
    colorCycle: colorCycle ?? this.colorCycle,
    colors: colors ?? this.colors,
  );

  @override
  bool operator ==(Object other) =>
      other is LightDanceConfig &&
      other.enabled == enabled &&
      other.style == style &&
      other.palette == palette &&
      other.colorStepSeconds == colorStepSeconds &&
      other.speedSeconds == speedSeconds &&
      other.colorCycle == colorCycle &&
      listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hash(
    enabled,
    style,
    palette,
    colorStepSeconds,
    speedSeconds,
    colorCycle,
    Object.hashAll(colors),
  );
}

/// `#RRGGBB` -> [Color]; null for anything malformed.
Color? parseHexColor(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length != 6) return null;
  final rgb = int.tryParse(hex, radix: 16);
  if (rgb == null) return null;
  return Color(0xFF000000 | rgb);
}

/// [Color] -> `#RRGGBB`, the shape stored in settings.
String hexFromColor(Color color) {
  final rgb =
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// How the light dance renders.
///
/// Every style animates forever while [LookLightDance.active] is true, so the widget
/// tree only rebuilds the painter through a [Listenable] tick instead of setState on
/// the whole card.
enum LightDanceStyle {
  /// A rotating conic gradient around the border — the default.
  orbit('Orbit', 'مدار'),

  /// A comet that runs around the ring with a trailing fade.
  comet('Comet', 'دنباله‌دار'),

  /// Three offset arcs chasing each other.
  chase('Chase', 'تعقیب'),

  /// A pulsing double ring that breathes in and out.
  pulse('Pulse', 'تپش'),

  /// A dashed ring whose segments light up in sequence.
  marquee('Marquee', 'مارکی'),

  /// Two counter-rotating arcs crossing each other.
  cross('Cross', 'صلیبی'),

  /// A wave of brightness travelling around the ring, like a ripple.
  ripple('Ripple', 'موج');

  const LightDanceStyle(this.label, this.labelFa);

  final String label;
  final String labelFa;
}

/// The colour journey of the dance.
///
/// [Spectrum] cycles the whole hue wheel, [Brand] stays inside the app's palette,
/// [Canary] is the pre-connection yellow, and [Custom] uses a user-chosen set.
enum LightDancePalette {
  spectrum('Spectrum', 'طیف کامل'),
  brand('Brand', 'رنگ برنامه'),
  canary('Canary', 'زرد قناری'),
  custom('Custom', 'سفارشی');

  const LightDancePalette(this.label, this.labelFa);

  final String label;
  final String labelFa;
}

/// Shared, app-wide light-dance state.
///
/// One [Ticker] drives every dancing ring on screen, so a dashboard with a dancing
/// connect button, download/upload metres, protocol chip and the live chart all stay
/// perfectly in sync and cost a single frame callback.
class LookLightDance extends ChangeNotifier {
  LookLightDance._();

  static final LookLightDance instance = LookLightDance._();

  Ticker? _ticker;
  Duration _elapsed = Duration.zero;

  /// Beam position in turns, 0..1, wrapping every [tickSeconds].
  double get phase => (_elapsed.inMicroseconds / 1e6 / tickSeconds) % 1.0;

  /// Seconds for one full trip around a ring.
  double tickSeconds = 1.6;

  /// Whether the whole dance is on. Mirrors the "Light dance" switch.
  bool get active => _active;
  bool _active = true;

  /// Seconds between colour steps; the colour jumps once per second when this is 1.
  double colorStepSeconds = 1.0;

  /// Style used by widgets that don't pick their own.
  LightDanceStyle style = LightDanceStyle.orbit;
  LightDancePalette palette = LightDancePalette.spectrum;

  /// Custom colours, used when [palette] is [LightDancePalette.custom].
  List<Color> customColors = const [Color(0xFFFFD400), Color(0xFF00E5FF)];

  /// Off = one calm static colour instead of the cycling one (battery saver).
  bool colorCycle = true;

  /// The app's own palette, so "Brand" follows the user's theme.
  List<Color> brandColors = const [Color(0xFF34D399), Color(0xFF5B9BFF)];

  /// Rotation phase used by the pre-connection state: a slow, calm sweep.
  double get slowPhase => (_elapsed.inMicroseconds / 1e6 / 4.0) % 1.0;

  /// Applies a persisted config. Called whenever the device settings reload.
  void apply(LightDanceConfig config) {
    _active = config.enabled;
    style = config.styleValue;
    palette = config.paletteValue;
    colorStepSeconds = config.colorStepSeconds;
    tickSeconds = config.speedSeconds;
    colorCycle = config.colorCycle;
    customColors = config.colors.isEmpty
        ? const [Color(0xFFFFE100), Color(0xFF00E5FF)]
        : config.colors;
    if (_ticker != null) {
      if (_active && !_ticker!.isActive) {
        _ticker!.start();
      } else if (!_active && _ticker!.isActive) {
        _ticker!.stop();
      }
    }
    notifyListeners();
  }

  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    if (_active) notifyListeners();
  }

  void setActive(bool value) {
    if (_active == value) return;
    _active = value;
    notifyListeners();
  }

  void setStyle(LightDanceStyle value) {
    if (style == value) return;
    style = value;
    notifyListeners();
  }

  void setPalette(LightDancePalette value) {
    if (palette == value) return;
    palette = value;
    notifyListeners();
  }

  void setColorCycle(bool value) {
    if (colorCycle == value) return;
    colorCycle = value;
    notifyListeners();
  }

  void setTickSeconds(double value) {
    if (tickSeconds == value) return;
    tickSeconds = value;
    notifyListeners();
  }

  void setCustomColors(List<Color> value) {
    if (value.isEmpty || listEquals(customColors, value)) return;
    customColors = List<Color>.unmodifiable(value);
    notifyListeners();
  }

  void setBrandColors(List<Color> value) {
    if (value.isEmpty || listEquals(brandColors, value)) return;
    brandColors = List<Color>.unmodifiable(value);
    notifyListeners();
  }

  /// The colours the active palette cycles through.
  List<Color> get activeColors => switch (palette) {
    LightDancePalette.spectrum => _spectrum,
    LightDancePalette.brand => brandColors,
    LightDancePalette.canary => _canary,
    LightDancePalette.custom => customColors,
  };

  /// The colour of the dance right now.
  ///
  /// Steps once per [colorStepSeconds] so the ring changes colour every second
  /// rather than blending continuously — that discrete jump is what reads as
  /// "dancing" instead of a slow fade.
  Color currentColor() {
    final colors = activeColors;
    if (!colorCycle) return colors.first;
    final step = colorStepSeconds <= 0
        ? 0
        : (_elapsed.inMicroseconds / 1e6 / colorStepSeconds).floor();
    return colors[step % colors.length];
  }

  /// [currentColor] with a fractional offset, for a ring that needs two hues at once.
  Color colorAt(double offset) {
    final colors = activeColors;
    if (!colorCycle) return colors.first;
    final step = colorStepSeconds <= 0
        ? 0
        : (_elapsed.inMicroseconds / 1e6 / colorStepSeconds).floor();
    final index = (step + (offset * colors.length).floor()) % colors.length;
    return colors[index];
  }

  /// Samples the palette continuously (no stepping) for gradients that should flow.
  List<Color> flowingColors(int count) {
    final colors = activeColors;
    if (!colorCycle) return List<Color>.filled(count, colors.first);
    final base = phase * colors.length;
    return [
      for (var i = 0; i < count; i++)
        colors[((base + i * colors.length / count).floor()) % colors.length],
    ];
  }

  /// The idle ring colour: canary yellow, before the tunnel is up.
  static const canary = _canary;

  static const _canary = [
    Color(0xFFFFE100),
    Color(0xFFFFC400),
    Color(0xFFFFF176),
    Color(0xFFFFAB00),
  ];

  /// A full, evenly spaced hue wheel.
  static final List<Color> _spectrum = [
    for (var i = 0; i < 12; i++)
      HSVColor.fromAHSV(1, (i * 360 / 12) % 360, 0.85, 1).toColor(),
  ];

  /// Seeds the dance from the user's palette so "Brand" never looks generic.
  void syncFromTheme(ThemeColor color) {
    setBrandColors([color.seed, color.accent]);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// A ring of light that travels around its child.
///
/// The ring is painted *outside* the child's bounds so it can hug any shape (a round
/// power button, a rounded bento card, a speed metre) without changing layout. It is
/// deliberately cheap: one [CustomPainter] and an optional blurred copy for the glow.
class LightDanceRing extends StatelessWidget {
  const LightDanceRing({
    super.key,
    required this.child,
    this.style,
    this.active = true,
    this.strokeWidth = 2.6,
    this.radius,
    this.glow = true,
    this.padding = 3,
    this.colors,
    this.turns,
    this.enabled = true,
  });

  final Widget child;

  /// Defaults to the app-wide style.
  final LightDanceStyle? style;

  /// When false the ring is hidden entirely (no static placeholder).
  final bool active;

  /// Ring thickness in logical pixels.
  final double strokeWidth;

  /// Corner radius of the ring; null means fully round (a circle).
  final double? radius;

  /// Draws a soft blurred copy behind the crisp ring.
  final bool glow;

  /// Gap between the child and the ring.
  final double padding;

  /// Explicit colours (the connect button's stopped state uses canary yellow).
  final List<Color>? colors;

  /// Overrides the global rotation speed.
  final double? turns;

  /// Cheap escape hatch when the parent already knows nothing should paint.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!active || !enabled) return child;
    final dance = LookLightDance.instance;
    return AnimatedBuilder(
      animation: dance,
      builder: (context, _) => CustomPaint(
        painter: _RingPainter(
          style: style ?? dance.style,
          phase: dance.phase,
          slowPhase: dance.slowPhase,
          palette: colors ?? dance.activeColors,
          colorCycle: dance.colorCycle,
          step: dance.currentColor(),
          strokeWidth: strokeWidth,
          radius: radius,
          glow: glow,
          padding: padding,
        ),
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.style,
    required this.phase,
    required this.slowPhase,
    required this.palette,
    required this.colorCycle,
    required this.step,
    required this.strokeWidth,
    required this.radius,
    required this.glow,
    required this.padding,
  });

  final LightDanceStyle style;
  final double phase;
  final double slowPhase;
  final List<Color> palette;
  final bool colorCycle;
  final Color step;
  final double strokeWidth;
  final double? radius;
  final bool glow;
  final double padding;

  Color _hue(double t) {
    if (!colorCycle || palette.isEmpty) return step;
    final i = (t.abs() * palette.length).floor() % palette.length;
    return palette[i];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius == null
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : RRect.fromRectAndRadius(rect, Radius.circular(radius!));
    final center = rect.center;
    final circleRadius = size.shortestSide / 2 - strokeWidth / 2;

    for (var pass = 0; pass < (glow ? 2 : 1); pass++) {
      final blur = pass == 0 ? 10.0 : 0.0;
      final scale = pass == 0 ? 1.9 : 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = blur == 0 ? null : MaskFilter.blur(BlurStyle.normal, blur);

      switch (style) {
        case LightDanceStyle.orbit:
          _sweep(canvas, rrect, size, paint, blur);
        case LightDanceStyle.comet:
          _comet(paint, center, circleRadius, blur, pass);
        case LightDanceStyle.chase:
          _chase(paint, center, circleRadius, blur, pass);
        case LightDanceStyle.pulse:
          _pulse(paint, center, circleRadius, blur, pass);
        case LightDanceStyle.marquee:
          _marquee(paint, rrect, size, blur, pass);
        case LightDanceStyle.cross:
          _cross(paint, center, circleRadius, blur, pass);
        case LightDanceStyle.ripple:
          _ripple(paint, rrect, size, blur, pass);
      }
    }
  }

  /// A full ring whose colour sweeps around it, rotating.
  void _sweep(Canvas canvas, RRect rrect, Size size, Paint paint, double blur) {
    paint.maskFilter = blur == 0 ? null : MaskFilter.blur(BlurStyle.normal, blur);
    if (colorCycle) {
      paint.shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(phase * math.pi * 2),
        colors: [
          _hue(phase),
          _hue(phase + 0.25),
          _hue(phase + 0.5),
          _hue(phase + 0.75),
          _hue(phase),
        ],
      ).createShader(Offset.zero & size);
    } else {
      paint
        ..shader = null
        ..color = step;
    }
    _drawRing(canvas, rrect.deflate(strokeWidth / 2), paint);
  }

  /// A short arc with a fading tail running around the ring.
  void _comet(Paint paint, Offset c, double r, double blur, int pass) {
    final head = phase * math.pi * 2;
    const segments = 26;
    const span = math.pi * 0.85;
    for (var i = 0; i < segments; i++) {
      final t = i / segments;
      final a0 = head - span * (1 - t);
      final a1 = a0 + span / segments * 1.15;
      paint
        ..shader = null
        ..color = _hue(phase + t).withValues(alpha: (t * (pass == 0 ? 0.45 : 1)))
        ..maskFilter = blur == 0
            ? null
            : MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        a1 - a0,
        false,
        paint,
      );
    }
  }

  /// Three evenly spaced arcs chasing each other.
  void _chase(Paint paint, Offset c, double r, double blur, int pass) {
    const arc = math.pi * 0.42;
    for (var i = 0; i < 3; i++) {
      final start = phase * math.pi * 2 + i * math.pi * 2 / 3;
      paint
        ..shader = null
        ..color = _hue(phase + i / 3).withValues(alpha: pass == 0 ? 0.4 : 1)
        ..maskFilter = blur == 0
            ? null
            : MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, arc, false, paint);
    }
  }

  /// A breathing double ring.
  void _pulse(Paint paint, Offset c, double r, double blur, int pass) {
    final breathe = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
    final alpha = pass == 0 ? 0.30 : 0.35 + 0.65 * breathe;
    paint
      ..shader = null
      ..color = _hue(phase).withValues(alpha: alpha)
      ..maskFilter = blur == 0 ? null : MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawCircle(c, r, paint);
    paint
      ..strokeWidth = paint.strokeWidth * 0.55
      ..color = _hue(phase + 0.5).withValues(alpha: alpha * (1 - breathe) + 0.2);
    canvas.drawCircle(c, r * (0.82 + 0.1 * breathe), paint);
  }

  /// A dashed ring whose dashes brighten in sequence.
  void _marquee(Paint paint, RRect rrect, Size size, double blur, int pass) {
    const dash = 9.0;
    const gapCount = 26;
    final metrics = (Path()..addRRect(rrect)).computeMetrics().first;
    final step = metrics.length / gapCount;
    for (var i = 0; i < gapCount; i++) {
      final t = (i / gapCount + phase) % 1.0;
      final alpha = 0.18 + 0.82 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
      paint
        ..shader = null
        ..color = _hue(t).withValues(alpha: pass == 0 ? alpha * 0.4 : alpha)
        ..maskFilter = blur == 0
            ? null
            : MaskFilter.blur(BlurStyle.normal, blur);
      for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
        canvas.drawPath(metric.extractPath(i * step, i * step + dash), paint);
      }
    }
  }

  /// Two counter-rotating arcs.
  void _cross(Paint paint, Offset c, double r, double blur, int pass) {
    const arc = math.pi * 0.5;
    final rect = Rect.fromCircle(center: c, radius: r);
    paint
      ..shader = null
      ..maskFilter = blur == 0 ? null : MaskFilter.blur(BlurStyle.normal, blur);
    paint.color = _hue(phase).withValues(alpha: pass == 0 ? 0.4 : 1);
    canvas.drawArc(rect, phase * math.pi * 2, arc, false, paint);
    paint.color = _hue(phase + 0.5).withValues(alpha: pass == 0 ? 0.4 : 1);
    canvas.drawArc(rect, -phase * math.pi * 2 + math.pi, arc, false, paint);
  }

  /// A brightness wave travelling around the ring.
  void _ripple(Paint paint, RRect rrect, Size size, double blur, int pass) {
    const segments = 48;
    final metrics = (Path()..addRRect(rrect)).computeMetrics().first;
    for (var i = 0; i < segments; i++) {
      final t = i / segments;
      final wave = 0.5 + 0.5 * math.sin((t - phase) * math.pi * 4);
      paint
        ..shader = null
        ..color = _hue(t).withValues(alpha: (0.12 + 0.88 * wave) * (pass == 0 ? 0.4 : 1))
        ..maskFilter = blur == 0
            ? null
            : MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawPath(
        metrics.extractPath(
          t * metrics.length,
          t * metrics.length + metrics.length / segments * 1.2,
        ),
        paint,
      );
    }
  }

  void _drawRing(Canvas canvas, RRect rrect, Paint paint) =>
      canvas.drawRRect(rrect, paint);

  @override
  bool shouldRepaint(_RingPainter old) => true;
}

/// A live, wave-like chart whose stroke colour moves every second.
///
/// Values scroll left as new samples arrive; the painter adds a gentle sine wave on
/// top of the real data so the line always looks alive even on an idle connection.
class LightDanceWaveChart extends StatelessWidget {
  const LightDanceWaveChart({
    super.key,
    required this.values,
    required this.revision,
    required this.height,
    required this.baseColor,
    this.amplitude = 1.0,
    this.active = true,
  });

  final List<double> values;
  final int revision;
  final double height;
  final Color baseColor;

  /// Multiplier for the idle wave (0 disables it).
  final double amplitude;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final dance = LookLightDance.instance;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: dance,
          builder: (context, _) => CustomPaint(
            painter: _WavePainter(
              values: values,
              revision: revision,
              phase: active ? dance.phase : 0,
              slowPhase: active ? dance.slowPhase : 0,
              palette: active ? dance.activeColors : [baseColor],
              colorCycle: active && dance.colorCycle,
              step: active ? dance.currentColor() : baseColor,
              animateWave: active,
              amplitude: amplitude,
              baselineColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.values,
    required this.revision,
    required this.phase,
    required this.slowPhase,
    required this.palette,
    required this.colorCycle,
    required this.step,
    required this.animateWave,
    required this.amplitude,
    required this.baselineColor,
  });

  final List<double> values;
  final int revision;
  final double phase;
  final double slowPhase;
  final List<Color> palette;
  final bool colorCycle;
  final Color step;
  final bool animateWave;
  final double amplitude;
  final Color baselineColor;

  Color _hue(double t) {
    if (!colorCycle || palette.isEmpty) return step;
    return palette[(t.abs() * palette.length).floor() % palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 1.5),
      Offset(size.width, size.height - 1.5),
      Paint()
        ..color = baselineColor.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    final pts = values.length < 2 ? const [0.0, 0.0, 0.0] : values;
    final maxVal = math.max(1024.0, pts.reduce(math.max));
    final stepX = size.width / (pts.length - 1);
    const topPad = 5.0;
    final usableH = size.height - topPad - 2.5;

    final coords = <Offset>[
      for (var i = 0; i < pts.length; i++)
        Offset(
          i * stepX,
          size.height -
              2.5 -
              (pts[i] / maxVal).clamp(0.0, 1.0) * usableH -
              // A travelling sine so the line breathes like a sea wave between samples.
              (animateWave
                  ? math.sin(i * 0.55 + phase * math.pi * 2) *
                        usableH *
                        0.06 *
                        amplitude
                  : 0),
        ),
    ];

    final path = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, size.height - 1.5)
      ..lineTo(coords.first.dx, size.height - 1.5)
      ..close();

    final start = _hue(phase);
    final end = _hue(phase + 0.5);
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [start.withValues(alpha: 0.26), start.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    final strokeShader = LinearGradient(
      colors: [start, end, start],
    ).createShader(Offset.zero & size);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (colorCycle) {
      stroke.shader = strokeShader;
    } else {
      stroke.color = step;
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}

/// A tiny live "equaliser" of dancing bars, for download/upload read-outs where a
/// full ring would be too heavy.
class LightDanceBars extends StatelessWidget {
  const LightDanceBars({
    super.key,
    required this.intensity,
    this.bars = 5,
    this.height = 14,
    this.width = 3.2,
    this.active = true,
  });

  final double intensity;
  final int bars;
  final double height;
  final double width;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return SizedBox(height: height, width: width * bars);
    final dance = LookLightDance.instance;
    return SizedBox(
      height: height,
      width: width * bars + (bars - 1) * 2,
      child: AnimatedBuilder(
        animation: dance,
        builder: (context, _) => CustomPaint(
          painter: _BarsPainter(
            phase: dance.phase,
            colors: dance.activeColors,
            colorCycle: dance.colorCycle,
            step: dance.currentColor(),
            bars: bars,
            width: width,
            intensity: intensity.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.phase,
    required this.colors,
    required this.colorCycle,
    required this.step,
    required this.bars,
    required this.width,
    required this.intensity,
  });

  final double phase;
  final List<Color> colors;
  final bool colorCycle;
  final Color step;
  final int bars;
  final double width;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < bars; i++) {
      final wave = 0.5 + 0.5 * math.sin((phase * 2 + i * 0.7) * math.pi * 2);
      final h = size.height * (0.28 + 0.72 * wave * (0.35 + 0.65 * intensity));
      final color = colorCycle
          ? colors[((phase * colors.length).floor() + i) % colors.length]
          : step;
      final x = i * (width + 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, width, h),
          Radius.circular(width / 2),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
