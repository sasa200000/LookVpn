import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/anti_filter.dart';
import '../state/app_state.dart';
import 'expressive.dart';
import 'look_i18n.dart';
import 'prefs.dart';
import 'theme.dart';

/// The anti-filter ladder: which routes the app will try, what each one defeats, and what
/// happened the last time it ran.
///
/// The point of the page is honesty: a user in Iran needs to see that a blocked route was
/// skipped and which one is carrying the tunnel now, instead of watching a spinner and
/// guessing.
class AntiFilterPage extends StatelessWidget {
  const AntiFilterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final enabled = state.antiFilterEnabled;
          final steps = state.antiFilterSteps;
          final current = state.antiFilterRoute;
          return Scaffold(
            appBar: ExpressiveSubpageHeader(
              title: LookLocale.t('دور زدن فیلتر', 'Anti-filter'),
              subtitle: LookLocale.t(
                'نردبان مسیرها: اگر یکی بسته شد، خودکار می‌رود سراغ بعدی',
                'Route ladder: when one is blocked, move to the next by itself',
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 36),
              children: [
                SectionHeader(
                  LookLocale.t('وضعیت', 'Status'),
                  icon: Symbols.shield_rounded,
                ),
                SettingsCard(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Symbols.shield_rounded),
                      title: Text(
                        LookLocale.t('دور زدن فیلتر', 'Anti-filter ladder'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'اتصال را روی چند مسیر مختلف امتحان می‌کند تا یکی از فیلتر رد شود.',
                          'Tries the connection over several routes until one gets through.',
                        ),
                      ),
                      value: enabled,
                      onChanged: state.setAntiFilter,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Symbols.bolt_rounded),
                      title: Text(
                        LookLocale.t('جابه‌جایی خودکار', 'Escalate automatically'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'وقتی روشن است، خودش مسیر را عوض می‌کند. وقتی خاموش است فقط پیشنهاد می‌دهد.',
                          'On: it switches by itself. Off: it only shows which route to try.',
                        ),
                      ),
                      value: state.device.antiFilterEscalate,
                      onChanged: enabled ? state.setAntiFilterEscalate : null,
                    ),
                    ListTile(
                      leading: const Icon(Symbols.refresh_rounded),
                      title: Text(
                        LookLocale.t('شروع دوباره از بالای نردبان', 'Restart the ladder'),
                      ),
                      subtitle: Text(
                        LookLocale.t(
                          'همه مسیرها به حالت «امتحان‌نشده» برمی‌گردند.',
                          'Every route goes back to untried.',
                        ),
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: enabled ? state.resetAntiFilter : null,
                    ),
                  ],
                ),
                if (state.refreshingEndpoints || state.lastEndpointRefresh != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: BentoSurface(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          if (state.refreshingEndpoints)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            BentoIcon(Symbols.dns_rounded, filled: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.refreshingEndpoints
                                  ? LookLocale.t(
                                      'در حال پیدا کردن آی‌پی‌های تازه…',
                                      'Looking for fresh edge addresses…',
                                    )
                                  : LookLocale.t(
                                      'آخرین تازه‌سازی: '
                                      '${state.lastEndpointRefresh!.summary}',
                                      'Last refresh: '
                                      '${state.lastEndpointRefresh!.summary}',
                                    ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SectionHeader(
                  LookLocale.t('مسیرها به ترتیب', 'Routes in order'),
                  icon: Symbols.route_rounded,
                ),
                for (final step in steps)
                  _RouteCard(
                    step: step,
                    current: step.route == current,
                    enabled: enabled,
                    onTap: enabled
                        ? () => state.applyAntiFilterRoute(step.route)
                        : null,
                  ),
                if (steps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      LookLocale.t(
                        'نردبان خاموش است. روشنش کن تا مسیرها ساخته شوند.',
                        'The ladder is off. Turn it on to build the route list.',
                      ),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: Text(
                    LookLocale.t(
                      'این صفحه فقط ترتیب تلاش را عوض می‌کند. کیفیت هر مسیر به شبکه و '
                          'اتصال تو بستگی دارد و هیچ اپلیکیشنی نمی‌تواند تضمین کند که یک '
                          'روش خاص همیشه از فیلتر رد می‌شود.',
                      'This page only changes the order routes are tried in. How well each one '
                          'works depends on your network, and no app can promise that one '
                          'method always gets through.',
                    ),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
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

class _RouteCard extends StatelessWidget {
  final AntiFilterStep step;
  final bool current;
  final bool enabled;
  final VoidCallback? onTap;

  const _RouteCard({
    required this.step,
    required this.current,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, tint, label) = switch (step.result) {
      AntiFilterResult.worked => (
        Symbols.check_circle_rounded,
        scheme.primary,
        LookLocale.t('کار می‌کند', 'Working'),
      ),
      AntiFilterResult.failed => (
        Symbols.cancel_rounded,
        scheme.error,
        LookLocale.t('بسته بود', 'Blocked'),
      ),
      AntiFilterResult.stalled => (
        Symbols.timer_off_rounded,
        scheme.tertiary,
        LookLocale.t('بی‌صدا', 'Silent'),
      ),
      AntiFilterResult.untried => (
        Symbols.radio_button_unchecked_rounded,
        scheme.onSurfaceVariant,
        LookLocale.t('امتحان‌نشده', 'Untried'),
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: BentoSurface(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tint.withValues(alpha: 0.28)),
                    ),
                    child: Icon(icon, size: 20, color: tint, fill: 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                LookLocale.t(step.route.labelFa, step.route.label),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (current) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  LookLocale.t('همین حالا', 'Now'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${step.route.transport} · $label',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: tint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          LookLocale.t(
                            'خنثی می‌کند: ${step.route.defeats}',
                            'Defeats: ${step.route.defeats}',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (step.detail != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            step.detail!,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
