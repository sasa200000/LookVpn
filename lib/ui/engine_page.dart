import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_state.dart';
import 'expressive.dart';
import 'mihomo_page.dart';
import 'mili_i18n.dart';

/// One address for choosing the network core. The main connection card and
/// power button use this selection, so switching is a real connection switch.
class EngineSettingsPage extends StatefulWidget {
  const EngineSettingsPage({super.key});

  @override
  State<EngineSettingsPage> createState() => _EngineSettingsPageState();
}

class _EngineSettingsPageState extends State<EngineSettingsPage> {
  bool _switching = false;

  Future<void> _pick(AppState state, String engine) async {
    if (state.engine == engine || _switching) return;
    setState(() => _switching = true);
    await state.setEngine(engine);
    if (mounted) setState(() => _switching = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final xray = state.engine == 'xray';
        return Scaffold(
          appBar: ExpressiveSubpageHeader(
            title: MiliLocale.t('هسته اتصال', 'Connection engine'),
            subtitle: MiliLocale.t(
              'انتخاب Xray یا Mihomo برای اتصال اصلی',
              'Choose Xray or Mihomo for the main connection',
            ),
          ),
          body: ExpressivePageBackdrop(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                BentoSurface(
                  highlight: true,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      BentoIcon(Symbols.memory_rounded, filled: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MiliLocale.t('هسته فعال', 'Active engine'),
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              xray ? 'Xray' : 'Mihomo',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BentoTag(
                        state.isConnected
                            ? MiliLocale.t('متصل', 'Connected')
                            : MiliLocale.t('آماده', 'Ready'),
                        filled: state.isConnected,
                        icon: Symbols.circle_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EngineCard(
                  selected: xray,
                  icon: Symbols.hub_rounded,
                  title: 'Xray',
                  subtitle: MiliLocale.t(
                    'موتور اصلی MiliConfig: Worker، WARP، MASQUE، Serverless، Psiphon، Tor و زنجیره پروکسی',
                    'MiliConfig main core: Worker, WARP, MASQUE, Serverless, Psiphon, Tor and chain proxies',
                  ),
                  tags: const ['VLESS', 'XHTTP', 'WARP', 'MASQUE', 'Tor'],
                  onTap: _switching ? null : () => _pick(state, 'xray'),
                ),
                const SizedBox(height: 10),
                _EngineCard(
                  selected: !xray,
                  icon: Symbols.language_rounded,
                  title: 'Mihomo',
                  subtitle: MiliLocale.t(
                    'موتور Clash.Meta برای اشتراک‌های شخصی؛ مناسب پروکسی‌های Clash و لینک‌های base64',
                    'Clash.Meta core for personal subscriptions; works with Clash proxies and base64 links',
                  ),
                  tags: const ['Clash', 'YAML', 'Subscriptions'],
                  onTap: _switching ? null : () => _pick(state, 'mihomo'),
                ),
                const SizedBox(height: 12),
                if (!xray)
                  BentoSurface(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Symbols.cloud_download_rounded,
                              size: 19,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                MiliLocale.t(
                                  'اشتراک‌های Mihomo',
                                  'Mihomo subscriptions',
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            BentoTag(
                              '${state.mihomoSubscriptions.length}',
                              icon: Symbols.link_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.mihomoSubscriptions.isEmpty
                              ? MiliLocale.t(
                                  'برای اتصال با Mihomo حداقل یک اشتراک اضافه کنید.',
                                  'Add at least one subscription to connect with Mihomo.',
                                )
                              : MiliLocale.t(
                                  'برای مدیریت لینک‌ها و جزئیات اتصال وارد صفحه Mihomo شوید.',
                                  'Open the Mihomo page to manage links and connection details.',
                                ),
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 11),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MihomoPage(),
                              ),
                            ),
                            icon: const Icon(Symbols.tune_rounded, size: 18),
                            label: Text(
                              MiliLocale.t(
                                'مدیریت اشتراک‌های Mihomo',
                                'Manage Mihomo subscriptions',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  MiliLocale.t(
                    'هنگام تغییر هسته، اتصال فعلی قطع می‌شود. هر دو هسته از همان دکمه اتصال و همان کارت وضعیت استفاده می‌کنند.',
                    'Switching cores stops the current connection. Both cores share the same power button and status card.',
                  ),
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EngineCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tags;
  final VoidCallback? onTap;

  const _EngineCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      highlight: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(
                icon,
                filled: selected,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Symbols.check_circle_rounded
                    : Symbols.radio_button_unchecked_rounded,
                size: 21,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags) BentoTag(tag),
            ],
          ),
        ],
      ),
    );
  }
}
