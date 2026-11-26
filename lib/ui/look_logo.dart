import 'package:flutter/material.dart';

/// LookVPN's emblem: the chrome shield holding a rainbow fibre-optic eye.
///
/// The artwork ships as `assets/look/logo.png`, generated from
/// `images/icon/source.jpg` by `scripts/make_look_assets.py`, so the in-app mark and the
/// launcher icon can never drift apart. [primaryColor] and [accentColor] are kept for call
/// sites that used to tint the old painted mark; the rainbow emblem is never recoloured,
/// they only drive the soft halo behind it.
class LookLogo extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? accentColor;

  const LookLogo({
    super.key,
    this.size = 28,
    this.primaryColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final halo = primaryColor ?? scheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              halo.withValues(alpha: 0.18),
              halo.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.04),
          child: Image.asset(
            'assets/look/logo.png',
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
            // A missing asset must never break the shell; fall back to the accent dot.
            errorBuilder: (context, _, __) => Center(
              child: Container(
                width: size * 0.5,
                height: size * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor ?? scheme.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
