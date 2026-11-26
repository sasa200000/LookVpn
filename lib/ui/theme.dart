import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../models/theme_color.dart';

// LookVPN design system — Material You Expressive surfaces, calm Bento
// composition, dynamic palette and physical spring-like motion.

const kHeroRadius = 28.0;
const kCardRadius = 26.0;
const kSmallCardRadius = 16.0;
const kDialogRadius = 28.0;
const kMenuRadius = 18.0;
const kInputRadius = 16.0;

RoundedSuperellipseBorder roundedShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: side,
);

const kFieldGap = 16.0;
const kRangeDashGap = 12.0;

/// Used when the app-wide motion switch is off. Flutter still pushes the route, but the
/// destination is shown immediately instead of animating a heavy page for ~300ms.
class _NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

PageTransitionsTheme _pageTransitionsFor(String style, bool motionEnabled) {
  final builder = !motionEnabled
      ? const _NoPageTransitionsBuilder()
      : switch (style) {
          'zoom' => const ZoomPageTransitionsBuilder(),
          'slide' => const CupertinoPageTransitionsBuilder(),
          _ => const FadeForwardsPageTransitionsBuilder(),
        };
  return PageTransitionsTheme(
    builders: {for (final platform in TargetPlatform.values) platform: builder},
  );
}

ThemeData buildTheme(
  Brightness brightness,
  ThemeColor color, {
  String fontFamily = 'OpenSans',
  String pageTransition = 'fade',
  bool motionEnabled = true,
}) {
  final isDark = brightness == Brightness.dark;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: color.seed,
    brightness: brightness,
  );

  final neutralDark = Color.alphaBlend(
    color.seed.withValues(alpha: 0.025),
    const Color(0xFF111418),
  );
  final scheme = isDark
      ? baseScheme.copyWith(
          primary: color.seed,
          onPrimary: const Color(0xFF0A1016),
          primaryContainer: Color.alphaBlend(
            color.seed.withValues(alpha: 0.20),
            color.darkCard,
          ),
          onPrimaryContainer: const Color(0xFFF3F6FB),
          secondary: color.accent,
          onSecondary: const Color(0xFF0A1016),
          secondaryContainer: Color.alphaBlend(
            color.accent.withValues(alpha: 0.15),
            color.darkCard,
          ),
          onSecondaryContainer: const Color(0xFFE7ECF4),
          tertiary: Color.alphaBlend(
            color.accent.withValues(alpha: 0.58),
            color.seed.withValues(alpha: 0.42),
          ),
          surface: neutralDark,
          surfaceContainerLowest: Color.alphaBlend(
            Colors.black.withValues(alpha: 0.22),
            neutralDark,
          ),
          surfaceContainerLow: color.darkSurface,
          surfaceContainer: color.darkCard,
          surfaceContainerHigh: Color.alphaBlend(
            color.seed.withValues(alpha: 0.045),
            const Color(0xFF252B35),
          ),
          surfaceContainerHighest: Color.alphaBlend(
            color.seed.withValues(alpha: 0.055),
            const Color(0xFF2D3440),
          ),
          onSurface: const Color(0xFFF3F5F9),
          onSurfaceVariant: const Color(0xFFA9B3C0),
          outline: const Color(0xFF414A58),
          outlineVariant: const Color(0xFF2A313D),
        )
      : baseScheme.copyWith(
          primary: color.seed,
          onPrimary: Colors.white,
          secondary: color.accent,
          tertiary: Color.alphaBlend(
            color.seed.withValues(alpha: 0.55),
            color.accent.withValues(alpha: 0.45),
          ),
          surface: const Color(0xFFF5F6FA),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFEFF2F8),
          surfaceContainer: Colors.white,
          surfaceContainerHigh: Color.alphaBlend(
            color.seed.withValues(alpha: 0.035),
            const Color(0xFFE9EEF5),
          ),
          surfaceContainerHighest: Color.alphaBlend(
            color.seed.withValues(alpha: 0.045),
            const Color(0xFFDFE6F0),
          ),
          onSurface: const Color(0xFF141820),
          onSurfaceVariant: const Color(0xFF5B6676),
          outline: const Color(0xFFC4CDDA),
          outlineVariant: const Color(0xFFE0E6EF),
        );

  final inputDecoration = InputDecorationTheme(
    filled: true,
    fillColor: isDark ? const Color(0xFF232833) : const Color(0xFFEDF1F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kInputRadius),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kInputRadius),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kInputRadius),
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily == 'system' ? null : fontFamily,
    scaffoldBackgroundColor: scheme.surface,
    pageTransitionsTheme: _pageTransitionsFor(pageTransition, motionEnabled),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 60,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
        fontFamily: fontFamily == 'system' ? null : fontFamily,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.outlineVariant,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(roundedShape(14)),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 0,
      shape: roundedShape(20),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
    ),
    cardTheme: CardThemeData(
      shape: roundedShape(
        kCardRadius,
        side: BorderSide(color: scheme.outlineVariant, width: 0.9),
      ),
      color: scheme.surfaceContainer.withValues(alpha: isDark ? 0.88 : 0.96),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: roundedShape(
        kDialogRadius,
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      modalBackgroundColor: scheme.surfaceContainer.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: 0.56),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      shape: roundedShape(
        kMenuRadius,
        side: BorderSide(color: scheme.outlineVariant, width: 0.9),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: roundedShape(kInputRadius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        minimumSize: const Size(44, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: roundedShape(13),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: roundedShape(kInputRadius),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primaryContainer,
      shape: roundedShape(12),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    inputDecorationTheme: inputDecoration,
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: inputDecoration,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.75,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF252B36) : const Color(0xFF1A1F29),
      contentTextStyle: const TextStyle(color: Color(0xFFF2F4F8)),
      shape: roundedShape(14),
    ),
  );
}
