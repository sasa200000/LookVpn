import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_state.dart';
import 'expressive.dart';
import 'look_i18n.dart';
import 'look_light_dance.dart';
import 'prefs.dart';
import 'theme.dart';

/// The light-dance control room: pick the shape, the colour journey, how fast it
/// steps and how fast it travels, and watch the result on a live demo card before
/// leaving the page.
class LightDancePage extends StatelessWidget {
  const LightDancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) => ListenableBuilder(
        listenable: state.lightDance,
        builder: (context, _) {
          final dance = state.lightDance.value;
          return Scaffold(
            appBar: ExpressiveSubpageHeader(
              title: LookLocale.t('رقص نور', 'Light dance'),
              subtitle: LookLocale.t(
                'حلقه‌های رنگی دور دکمه‌ها، سرعت و نمودار زنده',
                'Coloured rings around the controls, metres and live chart',
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 36),
              children: [
                if (!dance.enabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: BentoSurface(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          BentoIcon(Symbols.visibility_off_rounded, filled: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              LookLocale.t(
                                'رقص نور خاموش است؛ برای دیدن پیش‌نمایش روشنش کنید.',
                                'The dance is off — turn it on to see the preview.',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SectionHeader(
                  LookLocale.t('پیش‌نمایش زنده', 'Live preview'),
                  icon: Symbols.animation_rounded,
                ),
                _LivePreview(dance: dance),
                SectionHeader(
                  LookLocale.t('روشن و خاموش', 'On / off'),
                  icon: Symbols.power_settings_new_rounded,
                ),
                SettingsCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Symbols.auto_awesome_rounded),
                      title: Text(LookLocale.t('رقص نور', 'Light dance')),
                      subtitle: Text(
                        LookLocale.t(
                          'حلقه نور دور دکمه اتصال، سرعت دانلود/آپلود، پروتکل و نمودار زنده.',
                          'Rings of light around the connect button, the speed metres, '
                              'the protocol tile and the live chart.',
                        ),
                      ),
                      value: dance.enabled,
                      onChanged: state.setLightDance,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.palette_rounded),
                      title: Text(
                        LookLocale.t('تغییر رنگ هر ثانیه', 'Change colour every second'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'خاموش = یک رنگ ثابت. روشن = رنگ هر ثانیه عوض می‌شود.',
                          'Off = one fixed colour. On = a new colour every step.',
                        ),
                      ),
                      value: dance.colorCycle,
                      onChanged: dance.enabled
                          ? state.setLightDanceColorCycle
                          : null,
                    ),
                  ],
                ),
                SectionHeader(
                  LookLocale.t('شکل رقص', 'Shape'),
                  icon: Symbols.blur_circular_rounded,
                ),
                _StyleGrid(dance: dance, enabled: dance.enabled),
                SectionHeader(
                  LookLocale.t('رنگ‌ها', 'Colours'),
                  icon: Symbols.palette_rounded,
                ),
                _PalettePicker(dance: dance, enabled: dance.enabled),
                if (dance.paletteValue == LightDancePalette.custom)
                  _CustomColors(dance: dance, enabled: dance.enabled),
                SectionHeader(
                  LookLocale.t('سرعت', 'Timing'),
                  icon: Symbols.speed_rounded,
                ),
                SettingsCard(
                  children: [
                    _SliderRow(
                      icon: Symbols.timer_rounded,
                      title: LookLocale.t('گام رنگ', 'Colour step'),
                      value: dance.colorStepSeconds,
                      min: 0.4,
                      max: 4.0,
                      divisions: 18,
                      format: (v) => '${v.toStringAsFixed(1)} s',
                      enabled: dance.enabled && dance.colorCycle,
                      onChanged: state.setLightDanceColorStep,
                    ),
                    _SliderRow(
                      icon: Symbols.rotate_right_rounded,
                      title: LookLocale.t('سرعت چرخش', 'Rotation speed'),
                      value: dance.speedSeconds,
                      min: 0.6,
                      max: 6.0,
                      divisions: 27,
                      format: (v) => '${v.toStringAsFixed(1)} s',
                      enabled: dance.enabled,
                      onChanged: state.setLightDanceSpeed,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Text(
                    LookLocale.t(
                      'رقص نور فقط ظاهر برنامه را عوض می‌کند و روی اتصال، مصرف باتری شبکه یا '
                          'مسیریابی اثری ندارد. اگر باتری برایتان مهم است، آن را خاموش کنید.',
                      'The light dance only changes how the app looks; it has no effect on '
                          'the connection, network battery use or routing. Turn it off if '
                          'battery life matters more.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A mock of the connect card that dances with the real settings.
class _LivePreview extends StatelessWidget {
  final LightDanceConfig dance;
  const _LivePreview({required this.dance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BentoSurface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LightDanceRing(
                  radius: 24,
                  strokeWidth: 2.4,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                    ),
                    child: Icon(
                      Symbols.power_settings_new_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LookLocale.t('متصل', 'Connected'),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        '00:12:34',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                LightDanceBars(intensity: 0.85, active: dance.enabled),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                LightDanceRing(
                  radius: 12,
                  strokeWidth: 1.8,
                  padding: 3,
                  glow: false,
                  child: Icon(
                    Symbols.arrow_downward_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '12.4 Mb/s',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                LightDanceRing(
                  radius: 12,
                  strokeWidth: 1.8,
                  padding: 3,
                  glow: false,
                  style: LightDanceStyle.chase,
                  child: Icon(
                    Symbols.arrow_upward_rounded,
                    size: 15,
                    color: scheme.tertiary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '2.1 Mb/s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // The wave chart uses a fixed sample series so the preview never depends on
            // the live connection.
            LightDanceWaveChart(
              values: const [
                900.0, 1400.0, 700.0, 2100.0, 1600.0, 2600.0, 1200.0,
                3000.0, 1800.0, 2400.0, 1100.0, 2800.0,
              ],
              revision: 0,
              height: 62,
              baseColor: scheme.primary,
              active: dance.enabled,
            ),
            const SizedBox(height: 10),
            LightDanceRing(
              radius: 16,
              strokeWidth: 1.8,
              padding: 4,
              style: LightDanceStyle.ripple,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.alt_route_rounded, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'VLESS · WS · TLS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleGrid extends StatelessWidget {
  final LightDanceConfig dance;
  final bool enabled;
  const _StyleGrid({required this.dance, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final style in LightDanceStyle.values)
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 42) / 2,
              child: GestureDetector(
                onTap: enabled
                    ? () {
                        HapticFeedback.selectionClick();
                        state.setLightDanceStyle(style.name);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kSmallCardRadius),
                    color: dance.style == style.name
                        ? scheme.primary.withValues(alpha: 0.14)
                        : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    border: Border.all(
                      color: dance.style == style.name
                          ? scheme.primary.withValues(alpha: 0.55)
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                      width: dance.style == style.name ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      // A miniature of the style, drawn by the same painter.
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CustomPaint(
                          painter: _MiniStylePainter(
                            style: style,
                            color: dance.style == style.name
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          LookLocale.t(style.labelFa, style.label),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: dance.style == style.name
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A static thumbnail of each style so the list reads at a glance.
class _MiniStylePainter extends CustomPainter {
  _MiniStylePainter({required this.style, required this.color});
  final LightDanceStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Rect.fromCircle(center: c, radius: r);
    switch (style) {
      case LightDanceStyle.orbit:
        canvas.drawCircle(c, r, paint);
      case LightDanceStyle.comet:
        canvas.drawCircle(c, r, paint..color = color.withValues(alpha: 0.25));
        canvas.drawArc(rect, -math.pi / 2, math.pi * 0.9, false, paint..color = color);
      case LightDanceStyle.chase:
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            rect,
            i * math.pi * 2 / 3,
            math.pi * 0.42,
            false,
            paint..color = color.withValues(alpha: 0.45 + i * 0.25),
          );
        }
      case LightDanceStyle.pulse:
        canvas.drawCircle(c, r, paint..color = color.withValues(alpha: 0.4));
        canvas.drawCircle(c, r * 0.72, paint..color = color);
      case LightDanceStyle.marquee:
        final path = Path()..addOval(rect);
        for (final metric in path.computeMetrics()) {
          for (var i = 0; i < 10; i += 2) {
            final start = metric.length * i / 10;
            canvas.drawPath(
              metric.extractPath(start, start + metric.length / 14),
              paint..color = color.withValues(alpha: i % 4 == 0 ? 1 : 0.4),
            );
          }
        }
      case LightDanceStyle.cross:
        canvas.drawArc(rect, 0, math.pi * 0.5, false, paint);
        canvas.drawArc(rect, math.pi, math.pi * 0.5, false,
            paint..color = color.withValues(alpha: 0.5));
      case LightDanceStyle.ripple:
        canvas.drawCircle(c, r, paint..color = color.withValues(alpha: 0.25));
        canvas.drawArc(rect, 0, math.pi * 0.7, false, paint..color = color);
        canvas.drawArc(rect, math.pi, math.pi * 0.4, false,
            paint..color = color.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_MiniStylePainter old) =>
      old.style != style || old.color != color;
}

class _PalettePicker extends StatelessWidget {
  final LightDanceConfig dance;
  final bool enabled;
  const _PalettePicker({required this.dance, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SettingsCard(
        children: [
          for (final palette in LightDancePalette.values)
            RadioListTile<LightDancePalette>(
              value: palette,
              groupValue: dance.paletteValue,
              onChanged: enabled
                  ? (v) => state.setLightDancePalette(v!.name)
                  : null,
              secondary: _PaletteSwatch(palette: palette),
              title: Text(
                LookLocale.t(palette.labelFa, palette.label),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: Text(
                switch (palette) {
                  LightDancePalette.spectrum => LookLocale.t(
                    'چرخ کامل رنگ‌ها؛ پرانرژی‌ترین حالت',
                    'The full hue wheel — the liveliest option',
                  ),
                  LightDancePalette.brand => LookLocale.t(
                    'فقط رنگ‌های انتخاب‌شده در تم برنامه',
                    'Only the colours of the app theme',
                  ),
                  LightDancePalette.canary => LookLocale.t(
                    'زرد قناری، همان رنگ قبل از اتصال',
                    'Canary yellow, the idle colour',
                  ),
                  LightDancePalette.custom => LookLocale.t(
                    'رنگ‌های دلخواه خودتان',
                    'Your own set of colours',
                  ),
                },
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final LightDancePalette palette;
  const _PaletteSwatch({required this.palette});

  @override
  Widget build(BuildContext context) {
    final dance = LookLightDance.instance;
    final colors = switch (palette) {
      LightDancePalette.spectrum => [
          for (var i = 0; i < 6; i++)
            HSVColor.fromAHSV(1, i * 60.0, 0.85, 1).toColor(),
        ],
      LightDancePalette.brand => dance.brandColors,
      LightDancePalette.canary => LookLightDance.canary,
      LightDancePalette.custom => AppScope.read(context)
          .lightDance
          .value
          .colors,
    };
    if (colors.isEmpty) return const Icon(Symbols.palette_rounded);
    return SizedBox(
      width: 42,
      height: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(
          children: [
            for (final c in colors.take(4))
              Expanded(child: ColoredBox(color: c, child: const SizedBox.expand())),
          ],
        ),
      ),
    );
  }
}

/// Pick, add and remove the custom palette's colours.
class _CustomColors extends StatelessWidget {
  final LightDanceConfig dance;
  final bool enabled;
  const _CustomColors({required this.dance, required this.enabled});

  static const _swatches = [
    Color(0xFFFFE100),
    Color(0xFFFFC400),
    Color(0xFF00E5FF),
    Color(0xFF00B0FF),
    Color(0xFF7CFF3D),
    Color(0xFF00E676),
    Color(0xFFFF3DDC),
    Color(0xFFD500F9),
    Color(0xFFFF5252),
    Color(0xFFFF9100),
    Color(0xFFFFFFFF),
    Color(0xFF9E9E9E),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final current = dance.colors;
    final available = _swatches.where((c) => !current.contains(c)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SettingsCard(
        children: [
          ListTile(
            leading: const Icon(Symbols.format_paint_rounded),
            title: Text(
              LookLocale.t('رنگ‌های سفارشی', 'Custom colours'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: Text(
              LookLocale.t(
                'روی یک رنگ بزنید تا حذف شود؛ از ردیف پایین اضافه کنید.',
                'Tap a colour to remove it; add more from the row below.',
              ),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in current)
                  _ColorDot(
                    color: c,
                    selected: true,
                    onTap: enabled && current.length > 1
                        ? () => state.setLightDanceColors(
                            current.where((x) => x != c).toList(),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          if (available.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in available)
                    _ColorDot(
                      color: c,
                      selected: false,
                      onTap: enabled && current.length < 8
                          ? () => state.setLightDanceColors([...current, c])
                          : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  const _ColorDot({required this.color, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
            width: selected ? 2.2 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Symbols.close_rounded,
                size: 16,
                color: color.computeLuminance() > 0.6
                    ? Colors.black54
                    : Colors.white70,
              )
            : null,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
              Text(
                format(value),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
