import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/theme_color.dart';
import 'theme.dart';

/// Shared Material Expressive / Bento primitives.
///
/// The visual language is intentionally calm: a soft surface-tone gradient, one
/// hairline border, generous 26px radii and a single colour accent per card.
/// Every colour comes from the active [ColorScheme], so changing the user's
/// palette instantly recolours the whole settings surface (including sheets,
/// charts and active states).
const kBentoRadius = 26.0;
const kBentoGap = 12.0;

/// Height of the transparent LookVPN header below the system status bar.
const double kLookHomeHeaderHeight = 58.0;

/// Top inset of the page content of the home shell.
double lookHomeTopInset(BuildContext context) =>
    MediaQuery.paddingOf(context).top + kLookHomeHeaderHeight;

class BentoSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final bool highlight;
  final bool blur;
  final double radius;

  const BentoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
    this.highlight = false,
    this.blur = false,
    this.radius = kBentoRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final tint = accent ?? scheme.primary;
    final border = highlight
        ? tint.withValues(alpha: isLight ? 0.45 : 0.40)
        : scheme.outlineVariant.withValues(alpha: isLight ? 0.85 : 0.68);
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: highlight ? 1.1 : 0.8),
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: highlight
            ? [
                Color.alphaBlend(
                  tint.withValues(alpha: isLight ? 0.10 : 0.16),
                  scheme.surfaceContainer,
                ),
                Color.alphaBlend(
                  tint.withValues(alpha: isLight ? 0.04 : 0.07),
                  scheme.surfaceContainerLow,
                ),
              ]
            : [
                scheme.surfaceContainer.withValues(
                  alpha: isLight ? 0.94 : 0.84,
                ),
                scheme.surfaceContainerLow.withValues(
                  alpha: isLight ? 0.86 : 0.76,
                ),
              ],
      ),
    );

    final content = Padding(padding: padding, child: child);
    final card = DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                overlayColor: WidgetStatePropertyAll(
                  tint.withValues(alpha: 0.07),
                ),
                child: content,
              ),
      ),
    );

    return RepaintBoundary(
      child: blur
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: card,
              ),
            )
          : card,
    );
  }
}

class BentoIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final bool filled;
  final double box;

  const BentoIcon(
    this.icon, {
    super.key,
    this.color,
    this.size = 21,
    this.filled = false,
    this.box = 42,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(box * .34),
        color: Color.alphaBlend(
          tint.withValues(alpha: filled ? 0.26 : 0.13),
          scheme.surfaceContainerHigh,
        ),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Icon(
        icon,
        size: size,
        color: tint,
        fill: filled ? 1 : 0,
        weight: 500,
      ),
    );
  }
}

class BentoSectionLabel extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const BentoSectionLabel(
    this.title, {
    super.key,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 4, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary, weight: 600),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class BentoTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  const BentoTag(
    this.label, {
    super.key,
    this.icon,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: filled ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.24), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: tint, weight: 600),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              height: 1,
              fontWeight: FontWeight.w800,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// A big, tappable bento destination. Use two per row when the titles fit.
class BentoNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  final Widget? trailing;
  final bool featured;

  const BentoNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
    this.trailing,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;
    return BentoSurface(
      onTap: onTap,
      highlight: featured,
      accent: tint,
      padding: EdgeInsets.all(featured ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BentoIcon(icon, color: tint, box: featured ? 46 : 40),
              const Spacer(),
              trailing ??
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
            ],
          ),
          SizedBox(height: featured ? 14 : 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: featured ? 15.5 : 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: featured ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: featured ? 12 : 10.8,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact pill switch rendered as a tiny bento cell. The whole row is the
/// target, so these remain comfortable in a dense two-column layout.
class BentoToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const BentoToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      highlight: value,
      padding: const EdgeInsets.all(13),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(
                icon,
                size: 19,
                box: 37,
                filled: value,
                color: value ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 34,
                height: 20,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: value
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: value
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: value ? scheme.primary : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small accent orb used by settings and dashboard heroes.
class BentoOrb extends StatelessWidget {
  final double size;
  final IconData icon;
  final Color? color;
  final Color? secondary;

  const BentoOrb(
    this.icon, {
    super.key,
    this.size = 64,
    this.color,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    final tint2 = secondary ?? scheme.tertiary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            tint.withValues(alpha: 0.95),
            Color.alphaBlend(tint2.withValues(alpha: 0.75), scheme.surface),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.22),
            blurRadius: size * 0.55,
            spreadRadius: size * 0.04,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: scheme.onPrimary,
        size: size * 0.42,
        fill: 1,
        weight: 500,
      ),
    );
  }
}

/// Theme preview swatches with a live selected ring. Shared by settings and
/// the appearance page so palette changes feel immediate everywhere.
class BentoPalettePicker extends StatelessWidget {
  final ThemeColor selected;
  final ValueChanged<ThemeColor> onChanged;
  final bool showLabels;

  const BentoPalettePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 11,
      runSpacing: 10,
      children: [
        for (final tone in ThemeColor.values)
          Semantics(
            button: true,
            selected: tone == selected,
            label: tone.label,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(tone);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                width: tone == selected ? 40 : 34,
                height: tone == selected ? 40 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tone.accent, tone.seed],
                  ),
                  border: Border.all(
                    color: tone == selected
                        ? scheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: tone == selected
                      ? [
                          BoxShadow(
                            color: tone.seed.withValues(alpha: 0.35),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: tone == selected
                    ? const Icon(Icons.check_rounded, size: 19, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// The modern header for a full-screen settings subpage: compact, blurred and
/// with a large expressive title instead of a generic Material toolbar.
class ExpressiveSubpageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final double height;

  const ExpressiveSubpageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.height = 70,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: height,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleSpacing: 6,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.94),
                  scheme.surface.withValues(alpha: 0.74),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.2,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

/// Surface behind a settings subpage: one or two soft accent fields, built from
/// the active primary/tertiary so it never feels like a fixed green skin.
class ExpressivePageBackdrop extends StatelessWidget {
  final Widget child;

  const ExpressivePageBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            Color.alphaBlend(
              scheme.primary.withValues(alpha: isLight ? 0.035 : 0.055),
              scheme.surface,
            ),
            scheme.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -120,
            end: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: isLight ? 0.07 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -140,
            start: -100,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.tertiary.withValues(alpha: isLight ? 0.05 : 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A slightly larger, expressive search field with a pill shape.
class BentoSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final String value;
  final VoidCallback? onClear;
  final TextEditingController? controller;

  const BentoSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.value = '',
    this.onClear,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 21,
            color: scheme.onSurfaceVariant,
          ),
          suffixIcon: value.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
