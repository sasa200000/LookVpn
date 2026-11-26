import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/mihomo_profile.dart';
import '../models/settings.dart';
import '../services/vpn_channel.dart';
import '../state/app_state.dart';
import 'expressive.dart';
import 'mili_i18n.dart';

/// Manage the alternate Mihomo core: its own encrypted subscription list,
/// connection status and traffic. The main power button uses the engine chosen
/// in [EngineSettingsPage], so both cores share one connection flow.
class MihomoPage extends StatefulWidget {
  const MihomoPage({super.key});

  @override
  State<MihomoPage> createState() => _MihomoPageState();
}

class _MihomoPageState extends State<MihomoPage> {
  bool _busy = false;

  Future<void> _addSubscription(AppState state) async {
    final url = TextEditingController();
    final name = TextEditingController();
    final result = await showDialog<({String name, String url})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(MiliLocale.t('افزودن اشتراک Mihomo', 'Add Mihomo subscription')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: MiliLocale.t('نام (اختیاری)', 'Name (optional)'),
                prefixIcon: const Icon(Symbols.label_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: MiliLocale.t('آدرس اشتراک', 'Subscription URL'),
                hintText: 'https://…',
                prefixIcon: const Icon(Symbols.link_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MiliLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = url.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop((
                name: name.text.trim().isEmpty
                    ? Uri.tryParse(value)?.host ?? 'Mihomo'
                    : name.text.trim(),
                url: value,
              ));
            },
            child: Text(MiliLocale.t('افزودن', 'Add')),
          ),
        ],
      ),
    );
    url.dispose();
    name.dispose();
    if (result == null) return;
    setState(() => _busy = true);
    await state.saveMihomoSubscriptions([
      ...state.mihomoSubscriptions,
      MihomoSubscription(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: result.name,
        url: result.url,
      ),
    ]);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(AppState state, MihomoSubscription item) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(MiliLocale.t('حذف اشتراک؟', 'Remove subscription?')),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MiliLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MiliLocale.t('حذف', 'Remove')),
          ),
        ],
      ),
    );
    if (remove != true) return;
    setState(() => _busy = true);
    await state.saveMihomoSubscriptions([
      for (final current in state.mihomoSubscriptions)
        if (current.id != item.id) current,
    ]);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggle(AppState state) async {
    HapticFeedback.mediumImpact();
    if (state.engine != 'mihomo') await state.setEngine('mihomo');
    await state.toggle();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final connected = state.isConnected;
        final working = _busy || state.isBusy;
        return Scaffold(
          appBar: ExpressiveSubpageHeader(
            title: 'Mihomo',
            subtitle: MiliLocale.t(
              'هسته جایگزین برای اشتراک‌های Clash / Mihomo',
              'Alternate core for Clash / Mihomo subscriptions',
            ),
          ),
          body: ExpressivePageBackdrop(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                BentoSurface(
                  highlight: connected,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          BentoIcon(
                            connected
                                ? Symbols.shield_rounded
                                : Symbols.dns_rounded,
                            filled: connected,
                            color: connected ? scheme.primary : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connected
                                      ? MiliLocale.t('Mihomo متصل است', 'Mihomo is connected')
                                      : MiliLocale.t('Mihomo آماده است', 'Mihomo is ready'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  switch (state.status) {
                                    VpnStatus.connected => MiliLocale.t(
                                      'ترافیک از هسته Mihomo عبور می‌کند',
                                      'Traffic is routed through Mihomo',
                                    ),
                                    VpnStatus.connecting => MiliLocale.t(
                                      'در حال راه‌اندازی هسته…',
                                      'Starting the core…',
                                    ),
                                    VpnStatus.disconnecting => MiliLocale.t(
                                      'در حال قطع اتصال…',
                                      'Stopping…',
                                    ),
                                    VpnStatus.disconnected => MiliLocale.t(
                                      'برای اتصال، دکمه را بزنید',
                                      'Tap to connect',
                                    ),
                                  },
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.4,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          BentoTag(
                            '${state.mihomoSubscriptions.length} ${MiliLocale.t('اشتراک', 'subs')}',
                            icon: Symbols.link_rounded,
                          ),
                        ],
                      ),
                      if (state.error != null && state.status == VpnStatus.disconnected) ...[
                        const SizedBox(height: 10),
                        Text(
                          state.error!,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: working ? null : () => _toggle(state),
                          icon: Icon(
                            connected || working
                                ? Symbols.stop_circle_rounded
                                : Symbols.power_settings_new_rounded,
                            size: 19,
                          ),
                          label: Text(
                            working
                                ? MiliLocale.t('لطفاً صبر کنید…', 'Please wait…')
                                : connected
                                ? MiliLocale.t('قطع اتصال', 'Disconnect')
                                : MiliLocale.t('اتصال با Mihomo', 'Connect with Mihomo'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        MiliLocale.t('اشتراک‌ها', 'Subscriptions'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _addSubscription(state),
                      icon: const Icon(Symbols.add_rounded, size: 18),
                      label: Text(MiliLocale.t('افزودن', 'Add')),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (state.mihomoSubscriptions.isEmpty)
                  BentoSurface(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.cloud_download_rounded,
                          size: 30,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          MiliLocale.t(
                            'هنوز اشتراکی اضافه نشده است',
                            'No subscriptions yet',
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          MiliLocale.t(
                            'لینک Clash / Mihomo یا اشتراک base64 را وارد کنید؛ خود هسته آن را دانلود و مدیریت می‌کند.',
                            'Paste a Clash / Mihomo or base64 subscription link; the core downloads and manages it itself.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  BentoSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Column(
                      children: [
                        for (final item in state.mihomoSubscriptions)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              leading: const Icon(Symbols.language_rounded),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                Uri.tryParse(item.url)?.host ?? item.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: MiliLocale.t('حذف', 'Remove'),
                                onPressed: _busy ? null : () => _remove(state, item),
                                icon: const Icon(Symbols.delete_rounded, size: 19),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  MiliLocale.t(
                    'هسته Mihomo برای اشتراک‌های شخصی است و از پروتکل‌های Clash پشتیبانی می‌کند. برای WARP، MASQUE و مسیر خروج MiliConfig هسته Xray را انتخاب کنید.',
                    'The Mihomo core is for personal Clash subscriptions. Choose the Xray core for MiliConfig WARP, MASQUE and exit paths.',
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
