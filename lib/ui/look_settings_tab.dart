import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../models/theme_color.dart';
import '../services/vpn_channel.dart';
import '../services/xray_config.dart';
import '../state/app_state.dart';
import 'about_page.dart';
import 'cf_accounts_page.dart';
import 'chain_proxies_page.dart';
import 'dns_page.dart';
import 'engine_page.dart';
import 'exit_locations_page.dart';
import 'expressive.dart';
import 'fragments_page.dart';
import 'config_view_page.dart';
import 'interface_settings_page.dart';
import 'license_page.dart';
import 'log_page.dart';
import 'look_hub_page.dart';
import 'look_i18n.dart';
import 'look_toolbox_page.dart';
import 'noises_page.dart';
import 'per_app_page.dart';
import 'routing_page.dart';
import 'settings_page.dart';
import 'tor_bridges_page.dart';
import 'update_sheet.dart';

/// The central settings destination.
///
/// A calm expressive hero, live palette controls, actual inline quick settings
/// and a bento directory replace the old toolbox/all-settings segmented header.
/// Every control here is real; specialist pages remain reachable with one tap
/// and share the same visual language.
class LookSettingsTab extends StatefulWidget {
  final VoidCallback? onOpenScanner;

  const LookSettingsTab({super.key, this.onOpenScanner});

  @override
  State<LookSettingsTab> createState() => _LookSettingsTabState();
}

class _LookSettingsTabState extends State<LookSettingsTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_SettingsDestination> _destinations(AppState state) => [
    _SettingsDestination(
      icon: Symbols.memory_rounded,
      title: LookLocale.t('هسته اتصال', 'Connection engine'),
      subtitle: LookLocale.t(
        'انتخاب Xray یا Mihomo و مدیریت اشتراک‌های Mihomo',
        'Choose Xray or Mihomo and manage Mihomo subscriptions',
      ),
      keywords: 'engine core xray mihomo clash subscription هسته موتور',
      onTap: (context) => _push(context, const EngineSettingsPage()),
    ),
    _SettingsDestination(
      icon: Symbols.deployed_code_rounded,
      title: LookLocale.t('اتصال و شبکه', 'Connection & network'),
      subtitle: LookLocale.t(
        'پروتکل، پورت، CDN، WARP، MASQUE، DNS و MTU',
        'Protocol, ports, CDN, WARP, MASQUE, DNS and MTU',
      ),
      keywords: 'worker vless xhttp trojan shadowsocks cdn ech port deployment اتصال ورکر',
      onTap: (context) => _openAdvanced(context, const SettingsPage()),
    ),
    _SettingsDestination(
      icon: Symbols.dns_rounded,
      title: LookLocale.t('سرورهای DNS', 'DNS servers'),
      subtitle: LookLocale.t(
        'انتخاب DoH/DoQ، DNS محلی و سرورهای سفارشی',
        'Choose DoH/DoQ, local DNS and custom servers',
      ),
      keywords: 'dns doh doq local servers سرور dns',
      onTap: (context) => _push(context, const DnsPage()),
    ),
    _SettingsDestination(
      icon: Symbols.alt_route_rounded,
      title: LookLocale.t('مسیریابی', 'Routing'),
      subtitle: LookLocale.t(
        'عبور مستقیم ایران، مسدودسازی و قوانین دستی',
        'Iran bypass, ad blocking and manual rules',
      ),
      keywords: 'routing bypass iran block ads rules مسیر ایران',
      onTap: (context) => _push(context, const RoutingHubPage()),
    ),
    _SettingsDestination(
      icon: Symbols.broken_image_rounded,
      title: LookLocale.t('فرگمنت TCP', 'TCP fragments'),
      subtitle: LookLocale.t(
        'تکه‌سازی ClientHello برای عبور از DPI',
        'Split ClientHello to pass deep packet inspection',
      ),
      keywords: 'fragment dpi tls split فرگمنت',
      onTap: (context) => _push(context, const FragmentsPage()),
    ),
    _SettingsDestination(
      icon: Symbols.graphic_eq_rounded,
      title: LookLocale.t('نویز UDP', 'UDP noise'),
      subtitle: LookLocale.t(
        'مبهم‌سازی بسته‌های WARP و MASQUE',
        'Obfuscation for WARP and MASQUE traffic',
      ),
      keywords: 'udp noise warp masque obfuscation نویز',
      onTap: (context) => _push(context, const NoisesPage()),
    ),
    _SettingsDestination(
      icon: Symbols.apps_rounded,
      title: LookLocale.t('تفکیک برنامه‌ها', 'Per-app proxy'),
      subtitle: LookLocale.t(
        'انتخاب برنامه‌های عبوری یا مستثنی',
        'Include or exclude selected Android apps',
      ),
      keywords: 'per app proxy split tunnel برنامه',
      onTap: (context) => _push(context, const PerAppPage()),
    ),
    _SettingsDestination(
      icon: Symbols.link_rounded,
      title: LookLocale.t('زنجیره پروکسی', 'Chain proxies'),
      subtitle: LookLocale.t(
        'ورود از کلیپ‌بورد، QR و فایل WireGuard',
        'Import from clipboard, QR or WireGuard file',
      ),
      keywords: 'chain proxy vless trojan shadowsocks wireguard زنجیره',
      onTap: (context) => _push(context, const ChainProxiesPage()),
    ),
    _SettingsDestination(
      icon: Symbols.travel_explore_rounded,
      title: LookLocale.t('لوکیشن‌های خروج', 'Exit locations'),
      subtitle: LookLocale.t(
        'لبه ورکر و پیجز، و کاتالوگ پروتون VPN',
        'Worker and Pages edge, Proton VPN directory',
      ),
      keywords: 'exit location proton worker pages colo لوکیشن پروتون خروجی',
      onTap: (context) => _push(context, const ExitLocationsPage()),
    ),
    _SettingsDestination(
      icon: Symbols.cloud_rounded,
      title: LookLocale.t('حساب‌های کلادفلر', 'Cloudflare accounts'),
      subtitle: LookLocale.t(
        'مدیریت حساب‌ها، ورکرها و استقرار مجدد',
        'Accounts, Workers and one-tap redeploy',
      ),
      keywords: 'cloudflare worker pages account token deployment حساب',
      onTap: (context) => _push(context, const CfAccountsPage()),
    ),
    _SettingsDestination(
      icon: Symbols.vpn_key_rounded,
      title: LookLocale.t('پل‌های تور', 'Tor bridges'),
      subtitle: LookLocale.t(
        'Snowflake، WebTunnel و پل‌های سفارشی',
        'Snowflake, WebTunnel and custom bridges',
      ),
      keywords: 'tor bridge snowflake webtunnel obfs پل',
      onTap: (context) => _push(context, const TorBridgesPage()),
    ),
    _SettingsDestination(
      icon: Symbols.hub_rounded,
      title: 'Look Hub',
      subtitle: LookLocale.t(
        'مخزن آی‌پی تمیز، پریست‌ها و همگام‌سازی پنل',
        'Clean IP pool, presets and panel sync',
      ),
      keywords: 'look hub ip pool presets panel sync clean cloudflare پنل آی پی',
      onTap: (context) => _push(context, const LookHubPage()),
    ),
    _SettingsDestination(
      icon: Symbols.palette_rounded,
      title: LookLocale.t('ظاهر و حرکت', 'Appearance & motion'),
      subtitle: LookLocale.t(
        'رنگ پویا، فونت، انیمیشن و ترنزیشن صفحات',
        'Dynamic colour, type, motion and page transitions',
      ),
      keywords: 'theme color font motion animation palette appearance ظاهر تم',
      onTap: (context) => _push(context, const InterfaceSettingsPage()),
    ),
  ];

  Future<void> _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _openAdvanced(BuildContext context, Widget page) =>
      _push(context, page);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) {
        final destinations = _destinations(state);
        final query = _query.trim().toLowerCase();
        final filtered = query.isEmpty
            ? destinations
            : destinations.where((destination) {
                final haystack = [
                  destination.title,
                  destination.subtitle,
                  destination.keywords,
                ].join(' ').toLowerCase();
                return haystack.contains(query);
              }).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            lookHomeTopInset(context) + 8,
            16,
            112,
          ),
          children: [
            const _SettingsHero(),
            const SizedBox(height: 14),
            BentoSearchField(
              controller: _search,
              value: _query,
              hint: LookLocale.t(
                'جستجوی تنظیمات، ابزارها و صفحات…',
                'Search settings, tools and pages…',
              ),
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
            if (query.isEmpty) ...[
              const SizedBox(height: 10),
              BentoSectionLabel(
                LookLocale.t('همه تنظیمات', 'All settings'),
                icon: Symbols.grid_view_rounded,
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                child: Text(
                  filtered.isEmpty
                      ? LookLocale.t('نتیجه‌ای پیدا نشد', 'No matching settings')
                      : LookLocale.t(
                          '${filtered.length} نتیجه',
                          '${filtered.length} result(s)',
                        ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _DestinationGrid(destinations: filtered),
            const SizedBox(height: 4),
            BentoSectionLabel(
              LookLocale.t('برنامه', 'App'),
              icon: Symbols.info_rounded,
            ),
            BentoSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  _AppRow(
                    icon: Symbols.info_rounded,
                    title: LookLocale.t('درباره و بروزرسانی', 'About & updates'),
                    subtitle: LookLocale.t(
                      'نسخه، هسته‌ها، کد منبع، پشتیبانی و مجوز',
                      'Version, cores, source, support and license',
                    ),
                    onTap: () => _push(context, const AboutPage()),
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)),
                  _AppRow(
                    icon: Symbols.terminal_rounded,
                    title: LookLocale.t('لاگ زنده', 'Live logs'),
                    subtitle: LookLocale.t(
                      'مشاهده، فیلتر، کپی و پاک‌سازی خروجی هسته',
                      'View, filter, copy and clear core output',
                    ),
                    onTap: () => _push(context, const LogPage()),
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)),
                  _AppRow(
                    icon: Symbols.data_object_rounded,
                    title: LookLocale.t('کانفیگ Xray', 'Xray config'),
                    subtitle: LookLocale.t(
                      'پیش‌نمایش JSON ساخته‌شده برای اتصال',
                      'Preview the generated connection JSON',
                    ),
                    onTap: () => _push(context, const ConfigViewPage()),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: 0.55),
                  ),
                  _AppRow(
                    icon: Symbols.settings_backup_restore_rounded,
                    title: LookLocale.t('بازنشانی تنظیمات', 'Reset settings'),
                    subtitle: LookLocale.t(
                      'بازگردانی تنظیمات پروکسی به پیش‌فرض',
                      'Restore proxy settings to their defaults',
                    ),
                    onTap: () => _confirmReset(context, state),
                    danger: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LookLocale.t('بازنشانی تنظیمات؟', 'Reset settings?')),
        content: Text(
          LookLocale.t(
            'تنظیمات پروکسی به پیش‌فرض برمی‌گردند. آی‌پی‌های سالم، اندپوینت‌های WARP/MASQUE و پل‌های تور حفظ می‌شوند.',
            'Proxy settings return to their defaults. Clean IPs, WARP/MASQUE '
                'endpoints and Tor bridges are preserved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LookLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LookLocale.t('بازنشانی', 'Reset')),
          ),
        ],
      ),
    );
    if (confirmed == true) state.resetSettings();
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final connected = state.isConnected;
    return BentoSurface(
      highlight: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 17),
      child: Row(
        children: [
          const BentoOrb(Symbols.tune_rounded, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        LookLocale.t('مرکز تنظیمات', 'Settings center'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BentoTag(
                      connected
                          ? LookLocale.t('متصل', 'Connected')
                          : LookLocale.t('آماده', 'Ready'),
                      icon: Symbols.circle,
                      filled: connected,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  LookLocale.t(
                    'همه‌چیز برای اتصال، ظاهر و کنترل هسته — بدون شلوغی',
                    'Everything for connection, looks and core control — without the clutter',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final AppState state;
  const _AppearanceCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<ThemeColor>(
      valueListenable: state.themeColor,
      builder: (context, color, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: state.themeMode,
          builder: (context, mode, _) {
            final label = switch (mode) {
              ThemeMode.system => LookLocale.t('سیستم', 'System'),
              ThemeMode.light => LookLocale.t('روشن', 'Light'),
              ThemeMode.dark => LookLocale.t('تیره', 'Dark'),
            };
            return BentoSurface(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BentoIcon(
                        Symbols.palette_rounded,
                        color: scheme.primary,
                        size: 20,
                        box: 38,
                        filled: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LookLocale.t('ظاهر زنده', 'Live appearance'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${color.label} · $label',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: LookLocale.t('استودیوی ظاهر', 'Appearance studio'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InterfaceSettingsPage(),
                          ),
                        ),
                        icon: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Symbols.arrow_back_rounded
                              : Symbols.arrow_forward_rounded,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  BentoPalettePicker(
                    selected: color,
                    onChanged: state.setThemeColor,
                  ),
                  const SizedBox(height: 14),
                  _ThemeModePills(
                    mode: mode,
                    onChanged: state.setThemeMode,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ThemeModePills extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModePills({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (ThemeMode.system, Symbols.brightness_auto_rounded, LookLocale.t('سیستم', 'System')),
      (ThemeMode.light, Symbols.light_mode_rounded, LookLocale.t('روشن', 'Light')),
      (ThemeMode.dark, Symbols.dark_mode_rounded, LookLocale.t('تیره', 'Dark')),
    ];
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          for (final (value, icon, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (value != mode) onChanged(value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: value == mode
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: value == mode
                          ? scheme.primary.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: value == mode
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: value == mode
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
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

class _QuickSettingsGrid extends StatelessWidget {
  final AppState state;
  const _QuickSettingsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final antiDpiOn = state.variant != ConnectionVariant.normal;
    final fakeDns = state.readBool('general.enableFakeDns');
    final ipv6 = state.profile.general.enableIpv6;
    return Column(
      children: [
        BentoSectionLabel(
          LookLocale.t('تنظیمات سریع', 'Quick settings'),
          icon: Symbols.bolt_rounded,
          trailing: BentoTag(
            state.device.appMode == AppMode.vpn ? 'VPN' : LookLocale.t('پروکسی', 'Proxy'),
            icon: Symbols.shield_rounded,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BentoToggle(
                icon: Symbols.security_rounded,
                title: LookLocale.t('ضد DPI', 'Anti-DPI'),
                subtitle: antiDpiOn
                    ? LookLocale.t('فعال', 'Active')
                    : LookLocale.t('عادی', 'Normal'),
                value: antiDpiOn,
                onChanged: state.isBusy
                    ? null
                    : (on) {
                        if (state.mode == ConnectionMode.warp) {
                          state.setVariant(
                            on
                                ? ConnectionVariant.obfuscated
                                : ConnectionVariant.normal,
                          );
                        } else {
                          state.setVariant(
                            on
                                ? ConnectionVariant.fragment
                                : ConnectionVariant.normal,
                          );
                        }
                      },
              ),
            ),
            const SizedBox(width: kBentoGap),
            Expanded(
              child: BentoToggle(
                icon: Symbols.counter_6_rounded,
                title: 'IPv6',
                subtitle: LookLocale.t('شبکه خروجی', 'Outbound network'),
                value: ipv6,
                onChanged: (on) => state.write('general.enableIpv6', on),
              ),
            ),
          ],
        ),
        const SizedBox(height: kBentoGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BentoToggle(
                icon: Symbols.dns_rounded,
                title: LookLocale.t('DNS فیک', 'Fake DNS'),
                subtitle: LookLocale.t('پاسخ سریع محلی', 'Fast local answers'),
                value: fakeDns,
                onChanged: (on) => state.write('general.enableFakeDns', on),
              ),
            ),
            const SizedBox(width: kBentoGap),
            Expanded(
              child: BentoToggle(
                icon: Symbols.vpn_lock_rounded,
                title: LookLocale.t('حالت تونل', 'Tunnel mode'),
                subtitle: state.device.appMode == AppMode.vpn
                    ? LookLocale.t('همه برنامه‌ها', 'All apps')
                    : LookLocale.t('فقط پروکسی', 'Proxy only'),
                value: state.device.appMode == AppMode.vpn,
                onChanged: state.isBusy
                    ? null
                    : (on) => state.setAppMode(
                        on ? AppMode.vpn : AppMode.proxy,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolStrip extends StatelessWidget {
  final VoidCallback? onOpenScanner;
  const _ToolStrip({this.onOpenScanner});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        BentoSectionLabel(
          LookLocale.t('ابزارهای کاربردی', 'Tools'),
          icon: Symbols.construction_rounded,
        ),
        Row(
          children: [
            Expanded(
              child: BentoSurface(
                highlight: true,
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LookToolboxPage()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BentoIcon(
                      Symbols.speed_rounded,
                      box: 42,
                      size: 21,
                      filled: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LookLocale.t('جعبه‌ابزار شبکه', 'Network toolbox'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      LookLocale.t(
                        'سرعت · پینگ · DNS · آی‌پی',
                        'Speed · ping · DNS · IP',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: kBentoGap),
            Expanded(
              child: BentoSurface(
                padding: const EdgeInsets.all(14),
                onTap: onOpenScanner,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BentoIcon(
                      Symbols.radar_rounded,
                      box: 42,
                      size: 21,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LookLocale.t('اسکنر کلادفلر', 'Cloudflare scanner'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      LookLocale.t('Clean IP · Proxy IP', 'Clean IP · Proxy IP'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DestinationGrid extends StatelessWidget {
  final List<_SettingsDestination> destinations;
  const _DestinationGrid({required this.destinations});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 340;
        if (!twoColumns) {
          return Column(
            children: [
              for (final destination in destinations) ...[
                BentoNavTile(
                  icon: destination.icon,
                  title: destination.title,
                  subtitle: destination.subtitle,
                  onTap: () => destination.onTap(context),
                ),
                const SizedBox(height: kBentoGap),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < destinations.length; i += 2) {
          final first = destinations[i];
          final second = i + 1 < destinations.length ? destinations[i + 1] : null;
          rows.add(
            IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: second == null ? 2 : 1,
                  child: BentoNavTile(
                    icon: first.icon,
                    title: first.title,
                    subtitle: first.subtitle,
                    onTap: () => first.onTap(context),
                  ),
                ),
                if (second != null) ...[
                  const SizedBox(width: kBentoGap),
                  Expanded(
                    child: BentoNavTile(
                      icon: second.icon,
                      title: second.title,
                      subtitle: second.subtitle,
                      onTap: () => second.onTap(context),
                    ),
                  ),
                ],
              ],
              ),
            ),
          );
          rows.add(const SizedBox(height: kBentoGap));
        }
        return Column(children: rows);
      },
    );
  }
}

class _UpdateCard extends StatefulWidget {
  final AppState state;
  const _UpdateCard({required this.state});

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  Future<void> _check() async {
    try {
      final update = await widget.state.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LookLocale.t('شما آخرین نسخه را دارید', 'You are up to date'),
            ),
          ),
        );
      } else if (mounted) {
        await showUpdateSheet(context, update);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final update = widget.state.availableUpdate;
    final downloading = widget.state.downloadingUpdate;
    final busy = widget.state.checkingUpdate || downloading;
    return BentoSurface(
      padding: const EdgeInsets.all(16),
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(
                Symbols.system_update_rounded,
                color: scheme.tertiary,
                filled: update != null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update == null
                          ? LookLocale.t('بروزرسانی برنامه', 'App update')
                          : LookLocale.t(
                              'نسخه ${update.version} آماده است',
                              'Version ${update.version} is ready',
                            ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      update == null
                          ? LookLocale.t(
                              'آخرین نسخه را داخل برنامه بررسی و نصب کنید',
                              'Check and install the latest release in-app',
                            )
                          : LookLocale.t(
                              'دانلود و نصب امن با حفظ امضای برنامه',
                              'Secure in-app download with the same signature',
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.8,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: widget.state.updateProgress > 0
                    ? widget.state.updateProgress
                    : null,
                minHeight: 5,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: BentoTag(
                  update != null
                      ? LookLocale.t('بروزرسانی موجود', 'Update available')
                      : LookLocale.t('آخرین نسخه', 'Latest release'),
                  icon: update != null
                      ? Symbols.new_releases_rounded
                      : Symbols.verified_rounded,
                  color: update != null ? scheme.primary : scheme.tertiary,
                ),
              ),
              const Spacer(),
              if (update != null)
                FilledButton.tonalIcon(
                  onPressed: busy
                      ? null
                      : () => showUpdateSheet(context, update),
                  icon: widget.state.checkingUpdate
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.download_rounded, size: 16),
                  label: Text(LookLocale.t('نصب', 'Install')),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: busy ? null : _check,
                  icon: widget.state.checkingUpdate
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.refresh_rounded, size: 16),
                  label: Text(LookLocale.t('بررسی', 'Check')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _AppRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: danger ? scheme.error : scheme.primary,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: danger ? scheme.error : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Symbols.chevron_left_rounded
                  : Symbols.chevron_right_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDestination {
  final IconData icon;
  final String title;
  final String subtitle;
  final String keywords;
  final Future<void> Function(BuildContext context) onTap;

  const _SettingsDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.onTap,
  });
}
