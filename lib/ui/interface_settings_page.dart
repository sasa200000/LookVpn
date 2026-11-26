import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/theme_color.dart';
import '../state/app_state.dart';
import 'expressive.dart';
import 'light_dance_page.dart';
import 'look_i18n.dart';
import 'prefs.dart';
import 'theme.dart';

/// A dedicated, rich home for appearance and motion settings. The main Settings page links
/// here from a prominent card at the top instead of exposing a few bare rows.
class InterfaceSettingsPage extends StatelessWidget {
  const InterfaceSettingsPage({super.key});

  static const _transitionNames = {
    'fade': ('Fade', 'محو نرم', Symbols.gradient_rounded),
    'zoom': ('Zoom', 'زوم', Symbols.zoom_in_rounded),
    'slide': ('Slide', 'اسلاید', Symbols.swipe_rounded),
  };

  static const _colorNamesFa = {
    'neon': 'نعنایی',
    'ocean': 'آبی اقیانوسی',
    'emerald': 'فیروزه‌ای',
    'violet': 'بنفش ملایم',
    'amber': 'کهربایی',
    'rose': 'صورتی مرجانی',
    'slate': 'خاکستری گرافیتی',
    'indigo': 'نیلی',
    'crimson': 'قرمز یاقوتی',
    'lime': 'لیمویی',
    'sky': 'آبی یخی',
    'sand': 'شنی',
    'plum': 'بنفش سلطنتی',
  };

  String _colorName(ThemeColor color) =>
      LookLocale.t(_colorNamesFa[color.name] ?? color.label, color.label);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) => ListenableBuilder(
        listenable: Listenable.merge([
          state.themeColor,
          state.themeMode,
          state.fontFamily,
          state.fontScale,
          state.motionEnabled,
          state.pageTransition,
          state.tabTransition,
          state.meshBackground,
        ]),
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final motion = state.motionEnabled.value;
          return Scaffold(
            appBar: ExpressiveSubpageHeader(
              title: LookLocale.t('ظاهر و حرکت', 'Appearance & motion'),
              subtitle: LookLocale.t(
                'رنگ پویا، فونت، انیمیشن و ترنزیشن صفحات',
                'Dynamic color, type, motion and page transitions',
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 32),
              children: [
                SectionHeader(
                  LookLocale.t('پیش‌نمایش زنده', 'Live preview'),
                  icon: Symbols.phone_iphone_rounded,
                ),
                _PreviewCard(state: state, colorName: _colorName),
                SectionHeader(
                  LookLocale.t('تم و رنگ', 'Theme & color'),
                  icon: Symbols.palette_rounded,
                ),
                SettingsCard(
                  children: [
                    _ThemeModePicker(state: state),
                    _AccentPicker(state: state, colorName: _colorName),
                  ],
                ),
                SectionHeader(
                  LookLocale.t('فونت و خوانایی', 'Type & readability'),
                  icon: Symbols.text_fields_rounded,
                ),
                SettingsCard(
                  children: [
                    _FontPicker(state: state),
                    _TextSizePicker(state: state),
                  ],
                ),
                SectionHeader(
                  LookLocale.t('حرکت و ترنزیشن', 'Motion & transitions'),
                  icon: Symbols.animation_rounded,
                ),
                SettingsCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Symbols.motion_photos_on_rounded),
                      title: Text(
                        LookLocale.t('انیمیشن‌های رابط کاربری', 'Interface animations'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'حرکت کارت‌ها، تب‌ها و باز شدن صفحات. خاموش کردن آن مصرف باتری را کم می‌کند.',
                          'Card, tab and page motion. Turning it off reduces battery use.',
                        ),
                      ),
                      value: motion,
                      onChanged: state.setMotionEnabled,
                    ),
                    _TransitionPicker(
                      state: state,
                      enabled: motion,
                      transitionNames: _transitionNames,
                    ),
                    _TabTransitionPicker(state: state, enabled: motion),
                    SwitchListTile(
                      secondary: const Icon(Symbols.blur_on_rounded),
                      title: Text(
                        LookLocale.t('پس‌زمینه مش‌گرادیان', 'Mesh gradient backdrop'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'برای گوشی‌های ضعیف می‌توانید آن را خاموش کنید تا پس‌زمینه ساده و سبک شود.',
                          'Turn it off on slower phones for a flat, lighter background.',
                        ),
                      ),
                      value: state.meshBackground.value,
                      onChanged: state.setMeshBackground,
                    ),
                    ListTile(
                      leading: const Icon(Symbols.play_circle_rounded),
                      title: Text(
                        LookLocale.t('پیش‌نمایش ترنزیشن', 'Preview transition'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'یک صفحه نمونه با ترنزیشن انتخاب‌شده باز کنید.',
                          'Open a sample page with the selected transition.',
                        ),
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _MotionPreviewPage(),
                        ),
                      ),
                    ),
                  ],
                ),
                SectionHeader(
                  LookLocale.t('رقص نور', 'Light dance'),
                  icon: Symbols.auto_awesome_rounded,
                ),
                SettingsCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Symbols.nightlight_round),
                      title: Text(LookLocale.t('رقص نور', 'Light dance')),
                      subtitle: Text(
                        LookLocale.t(
                          'حلقه‌های رنگ‌عوض‌کن دور دکمه اتصال، دانلود، آپلود و پروتکل.',
                          'Colour-cycling rings around connect, download, upload and protocol.',
                        ),
                      ),
                      value: state.lightDance.value.enabled,
                      onChanged: (v) => state.setLightDance(v),
                    ),
                    ListTile(
                      leading: const Icon(Symbols.tune_rounded),
                      title: Text(
                        LookLocale.t('تنظیمات رقص نور', 'Light dance settings'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'شکل، پالت رنگ، سرعت تغییر و پیش‌نمایش زنده',
                          'Shape, palette, colour step and live preview',
                        ),
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LightDancePage(),
                        ),
                      ),
                    ),
                  ],
                ),
                SectionHeader(
                  LookLocale.t('زبان و جهت', 'Language & direction'),
                  icon: Symbols.translate_rounded,
                ),
                SettingsCard(children: [_LanguagePicker(state: state)]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => _resetAppearance(context, state),
                    icon: const Icon(Symbols.restart_alt_rounded, size: 18),
                    label: Text(
                      LookLocale.t(
                        'بازگردانی ظاهر به حالت پیش‌فرض',
                        'Reset appearance to defaults',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Text(
                    LookLocale.t(
                      'این تنظیمات فقط ظاهر و حرکت برنامه را عوض می‌کنند و روی اتصال، ورکر یا مسیریابی اثری ندارند.',
                      'These preferences only change the app appearance and motion; they do not '
                          'affect the VPN connection, worker, or routing.',
                    ),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
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

  Future<void> _resetAppearance(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          LookLocale.t('ظاهر به حالت پیش‌فرض برگردد؟', 'Reset appearance?'),
        ),
        content: Text(
          LookLocale.t(
            'رنگ، حالت تاریک/روشن، فونت، اندازه متن، انیمیشن‌ها، ترنزیشن تب‌ها و صفحات و پس‌زمینه به مقدار اولیه برمی‌گردند. اتصال و تنظیمات ورکر دست نمی‌خورند.',
            'Color, light/dark mode, font, text size, motion, tab/page transitions and '
                'backdrop return to their defaults. Connection and worker settings are untouched.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LookLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LookLocale.t('بازگردانی', 'Reset')),
          ),
        ],
      ),
    );
    if (ok == true) state.resetAppearance();
  }
}

class _PreviewCard extends StatelessWidget {
  final AppState state;
  final String Function(ThemeColor) colorName;
  const _PreviewCard({required this.state, required this.colorName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = state.themeColor.value;
    final motion = state.motionEnabled.value;
    final bg = isDark
        ? Color.alphaBlend(color.seed.withValues(alpha: 0.20), color.darkCard)
        : Color.alphaBlend(color.seed.withValues(alpha: 0.10), Colors.white);
    final fg = isDark ? const Color(0xFFF5F7FB) : const Color(0xFF141820);
    final muted = isDark
        ? const Color(0xFFB6C0CE)
        : const Color(0xFF596476);
    final family = state.fontFamily.value == 'system'
        ? null
        : state.fontFamily.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedContainer(
        duration: motion ? const Duration(milliseconds: 240) : Duration.zero,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: Border.all(color: color.seed.withValues(alpha: 0.38)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.seed.withValues(alpha: isDark ? 0.26 : 0.14),
              color.accent.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.seed.withValues(alpha: isDark ? 0.14 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.seed.withValues(alpha: 0.18),
                    border: Border.all(
                      color: color.seed.withValues(alpha: 0.48),
                    ),
                  ),
                  child: Icon(
                    Symbols.shield_rounded,
                    color: color.seed,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'LookVPN',
                  style: TextStyle(
                    fontFamily: family,
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.seed.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.seed.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Text(
                    colorName(color),
                    style: TextStyle(
                      color: fg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              LookLocale.t('اتصال فعال', 'Connected'),
              style: TextStyle(
                fontFamily: family,
                color: fg,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              LookLocale.t('امن، سریع و بدون قطعی', 'Secure, fast and steady'),
              style: TextStyle(fontFamily: family, color: muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _PreviewStat(
                  label: 'PING',
                  value: '18 ms',
                  color: fg,
                  muted: muted,
                  family: family,
                ),
                const SizedBox(width: 22),
                _PreviewStat(
                  label: LookLocale.t('دانلود', 'DOWN'),
                  value: '12.4 MB/s',
                  color: fg,
                  muted: muted,
                  family: family,
                ),
                const SizedBox(width: 22),
                _PreviewStat(
                  label: LookLocale.t('آپلود', 'UP'),
                  value: '1.8 MB/s',
                  color: fg,
                  muted: muted,
                  family: family,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 0.72,
                minHeight: 5,
                color: color.seed,
                backgroundColor: color.seed.withValues(alpha: 0.16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color muted;
  final String? family;
  const _PreviewStat({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
    required this.family,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: family,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  final AppState state;
  const _ThemeModePicker({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = state.motionEnabled.value;
    final selected = state.themeMode.value;
    const options = [
      (
        ThemeMode.system,
        'سیستم',
        'System',
        Symbols.brightness_auto_rounded,
      ),
      (ThemeMode.light, 'روشن', 'Light', Symbols.light_mode_rounded),
      (ThemeMode.dark, 'تیره', 'Dark', Symbols.dark_mode_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Symbols.contrast_rounded),
          title: Text(LookLocale.t('حالت نمایش', 'Appearance mode')),
          subtitle: Text(
            LookLocale.t(
              'هماهنگ با گوشی یا انتخاب دستی روشن و تاریک.',
              'Follow the phone or choose light/dark manually.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              for (final (mode, fa, en, icon) in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => state.setThemeMode(mode),
                      child: AnimatedContainer(
                        duration: motion
                            ? const Duration(milliseconds: 180)
                            : Duration.zero,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected == mode
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHigh.withValues(
                                  alpha: 0.42,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected == mode
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: selected == mode ? 1.4 : 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              icon,
                              size: 21,
                              color: selected == mode
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              LookLocale.t(fa, en),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected == mode
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected == mode
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  final AppState state;
  final String Function(ThemeColor) colorName;
  const _AccentPicker({required this.state, required this.colorName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = state.themeColor.value;
    final motion = state.motionEnabled.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Symbols.palette_rounded),
          title: Text(LookLocale.t('رنگ اصلی', 'Accent color')),
          subtitle: Text(
            LookLocale.t(
              'رنگ دکمه‌ها، لینک‌ها و جزئیات کل برنامه.',
              'Used for buttons, links and highlights across the app.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Wrap(
            spacing: 7,
            runSpacing: 10,
            children: [
              for (final color in ThemeColor.values)
                SizedBox(
                  width: 70,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => state.setThemeColor(color),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: motion
                                ? const Duration(milliseconds: 170)
                                : Duration.zero,
                            width: 44,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color.seed, color.accent],
                              ),
                              border: Border.all(
                                color: selected == color
                                    ? scheme.onSurface
                                    : Colors.transparent,
                                width: 2.4,
                              ),
                              boxShadow: selected == color
                                  ? [
                                      BoxShadow(
                                        color: color.seed.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected == color
                                ? Icon(
                                    Symbols.check_rounded,
                                    size: 19,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              color.seed,
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            colorName(color),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.2,
                              color: selected == color
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight: selected == color
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FontPicker extends StatelessWidget {
  final AppState state;
  const _FontPicker({required this.state});

  static const _fonts = {
    'OpenSans': 'Open Sans',
    'JetBrainsMono': 'JetBrains Mono',
    'system': 'System',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = state.fontFamily.value;
    final motion = state.motionEnabled.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Symbols.text_fields_rounded),
          title: Text(LookLocale.t('فونت برنامه', 'App font')),
          subtitle: Text(
            LookLocale.t(
              'برای خوانایی بهتر یکی از فونت‌های زیر را انتخاب کنید.',
              'Pick the typeface that feels most readable to you.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Column(
            children: [
              for (final entry in _fonts.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => state.setFontFamily(entry.key),
                    child: AnimatedContainer(
                      duration: motion
                          ? const Duration(milliseconds: 170)
                          : Duration.zero,
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: selected == entry.key
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh.withValues(
                                alpha: 0.34,
                              ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected == entry.key
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: selected == entry.key ? 1.3 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontFamily: entry.key == 'system'
                                        ? null
                                        : entry.key,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: selected == entry.key
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'LookVPN 123 · ${LookLocale.t('نمونه متن', 'Sample text')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: entry.key == 'system'
                                        ? null
                                        : entry.key,
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected == entry.key)
                            Icon(
                              Symbols.check_circle_rounded,
                              size: 20,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextSizePicker extends StatefulWidget {
  final AppState state;
  const _TextSizePicker({required this.state});

  @override
  State<_TextSizePicker> createState() => _TextSizePickerState();
}

class _TextSizePickerState extends State<_TextSizePicker> {
  late double _value;
  bool _initialized = false;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = AppScope.of(context).fontScale.value;
    if (!_initialized || !_dragging) {
      _value = current;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Symbols.format_size_rounded),
          title: Text(LookLocale.t('اندازه متن', 'Text size')),
          subtitle: Text(
            LookLocale.t(
              'اندازه متن کل برنامه را کم و زیاد کنید.',
              'Scale text across the whole app.',
            ),
          ),
          trailing: Text(
            '${(_value * 100).round()}%',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: Slider(
            value: _value,
            min: 0.9,
            max: 1.3,
            divisions: 8,
            label: '${(_value * 100).round()}%',
            onChanged: (value) => setState(() {
              _dragging = true;
              _value = value;
            }),
            onChangeEnd: (value) {
              _dragging = false;
              state.setFontScale(value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(_value),
              ),
              child: Text(
                LookLocale.t(
                  'این متن اندازه انتخاب‌شده را نشان می‌دهد.',
                  'This line previews the selected text size.',
                ),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransitionPicker extends StatelessWidget {
  final AppState state;
  final bool enabled;
  final Map<String, (String, String, IconData)> transitionNames;

  const _TransitionPicker({
    required this.state,
    required this.enabled,
    required this.transitionNames,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = state.pageTransition.value;
    final motion = state.motionEnabled.value;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Symbols.swap_horiz_rounded),
              title: Text(
                LookLocale.t('ترنزیشن بین صفحات', 'Page transition'),
              ),
              subtitle: Text(
                LookLocale.t(
                  'نوع حرکت هنگام باز کردن یک صفحه یا بازگشت.',
                  'How pages animate when opening and returning.',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Column(
                children: [
                  for (final item in transitionNames.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => state.setPageTransition(item.key),
                        child: AnimatedContainer(
                          duration: motion
                              ? const Duration(milliseconds: 170)
                              : Duration.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected == item.key
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh.withValues(
                                    alpha: 0.34,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected == item.key
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: selected == item.key ? 1.3 : 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.value.$3,
                                size: 20,
                                color: selected == item.key
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  LookLocale.t(item.value.$2, item.value.$1),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected == item.key
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected == item.key
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (selected == item.key)
                                Icon(
                                  Symbols.check_circle_rounded,
                                  size: 19,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabTransitionPicker extends StatelessWidget {
  final AppState state;
  final bool enabled;
  const _TabTransitionPicker({required this.state, required this.enabled});

  static const _options = [
    ('slide', 'اسلاید نرم', 'Soft slide', Symbols.swap_horiz_rounded),
    ('fade', 'محو', 'Fade', Symbols.blur_on_rounded),
    ('scale', 'بزرگ‌نمایی', 'Scale', Symbols.zoom_out_map_rounded),
    ('lift', 'شناور', 'Lift', Symbols.vertical_align_top_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = state.tabTransition.value;
    final motion = state.motionEnabled.value;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Symbols.view_carousel_rounded),
              title: Text(
                LookLocale.t('ترنزیشن تب‌ها', 'Tab transition'),
              ),
              subtitle: Text(
                LookLocale.t(
                  'حرکت بین داشبورد، اسکنر و تنظیمات را انتخاب کنید.',
                  'Choose how the dashboard, scanner and settings swap in.',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: 2.65,
                children: [
                  for (final option in _options)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => state.setTabTransition(option.$1),
                      child: AnimatedContainer(
                        duration: motion
                            ? const Duration(milliseconds: 170)
                            : Duration.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          color: selected == option.$1
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHigh.withValues(
                                  alpha: 0.34,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected == option.$1
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: selected == option.$1 ? 1.3 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              option.$4,
                              size: 19,
                              color: selected == option.$1
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                LookLocale.t(option.$2, option.$3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected == option.$1
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected == option.$1
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            if (selected == option.$1)
                              Icon(
                                Symbols.check_circle_rounded,
                                size: 18,
                                color: scheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final AppState state;
  const _LanguagePicker({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = LookLocale.code.value;
    final motion = state.motionEnabled.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Symbols.translate_rounded),
          title: Text(LookLocale.t('زبان برنامه', 'App language')),
          subtitle: Text(
            LookLocale.t(
              'فارسی، انگلیسی، عربی، ترکی، روسی و چینی؛ جهت رابط خودکار تنظیم می‌شود.',
              'Persian, English, Arabic, Turkish, Russian and Chinese; layout direction follows automatically.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3.15,
            children: [
              for (final lang in LookLocale.languages)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => LookLocale.setLang(lang.code),
                  child: AnimatedContainer(
                    duration: motion
                        ? const Duration(milliseconds: 180)
                        : Duration.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: current == lang.code
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHigh.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: current == lang.code
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: current == lang.code ? 1.3 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          lang.flag,
                          style: const TextStyle(fontSize: 17),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.native,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: current == lang.code
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                              Text(
                                lang.english,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (current == lang.code)
                          Icon(
                            Symbols.check_circle_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MotionPreviewPage extends StatelessWidget {
  const _MotionPreviewPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: ExpressiveSubpageHeader(
        title: LookLocale.t('پیش‌نمایش حرکت', 'Motion preview'),
        subtitle: LookLocale.t(
          'همان ترنزیشن و فنر انتخاب‌شده',
          'The transition and spring you selected',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.animation_rounded, size: 56, color: scheme.primary),
              const SizedBox(height: 14),
              Text(
                LookLocale.t('ترنزیشن انتخاب‌شده اعمال شد', 'Selected transition applied'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LookLocale.t(
                  'این صفحه با تنظیم فعلی باز و بسته می‌شود.',
                  'This page opens and closes with your current setting.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Symbols.arrow_back_rounded, size: 18),
                label: Text(LookLocale.t('بازگشت', 'Go back')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
