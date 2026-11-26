import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../models/theme_color.dart';
import '../services/scanner_channel.dart';
import '../services/vpn_channel.dart';
import '../services/xray_config.dart';
import '../state/app_state.dart';
import 'cf_accounts_page.dart';
import 'cloudflare_scanner_page.dart';
import 'dns_page.dart';
import 'expressive.dart';
import 'look_i18n.dart';
import 'fragments_page.dart';
import 'noises_page.dart';
import 'prefs.dart';
import 'routing_page.dart';
import 'update_sheet.dart';

class SettingsPage extends StatefulWidget {
  final bool embedded;
  const SettingsPage({super.key, this.embedded = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _scroll = ScrollController();
  final _workerKey = GlobalKey();
  final _networkKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  static const fingerprints = {
    'chrome': 'Chrome',
    'firefox': 'Firefox',
    'safari': 'Safari',
    'ios': 'iOS',
    'android': 'Android',
    'edge': 'Edge',
    '360': '360',
    'qq': 'QQ',
    'random': 'Random',
    'randomized': 'Randomized',
    'unsafe': 'Unsafe',
  };

  static const routingStrategy = {'AsIs': 'Speed', 'IPIfNonMatch': 'Accuracy'};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;
    final d = state.device;

    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) => Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded
          ? null
          : ExpressiveSubpageHeader(
        title: LookLocale.t('اتصال و شبکه', 'Connection & network'),
        subtitle: LookLocale.t(
          'پروتکل ورکر، WARP، MASQUE، DNS، MTU و داده‌ها',
          'Worker protocol, WARP, MASQUE, DNS, MTU and data',
        ),
        actions: [
          IconButton(
            tooltip: LookLocale.t('بازنشانی تنظیمات', 'Reset settings'),
            icon: const Icon(Symbols.settings_backup_restore_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(LookLocale.t('بازنشانی تنظیمات؟', 'Reset settings?')),
                  content: Text(LookLocale.t(
                    'تنظیمات پروکسی به حالت پیش‌فرض برمی‌گردند. آی‌پی‌های سالم VLESS، اندپوینت‌های WARP/MASQUE و بریج‌های تور حفظ می‌شوند.',
                    'Proxy settings return to their defaults. VLESS Clean IPs, WARP and MASQUE '
                        'endpoints and Tor custom bridges are preserved.',
                  )),
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
              if (ok == true) state.resetSettings();
            },
          ),
        ],
      ),
      body: ExpressivePageBackdrop(
        child: ListView(
        controller: _scroll,
        // Keep the worker/network jump targets mounted just below the fold without
        // eagerly building the whole, very long settings page.
        cacheExtent: 1400,
        padding: const EdgeInsets.only(bottom: 104, top: 6),
        children: [
          SectionHeader(
            LookLocale.t('شبکه و DNS', 'Network & DNS'),
            key: _networkKey,
            icon: Symbols.lan_rounded,
          ),
          const SizedBox(height: 6),
          SettingsCard(
            children: [
              TextPref(
                'general.localDns',
                LookLocale.t('DNS محلی', 'Local DNS'),
                icon: Symbols.home_rounded,
                hint: 'IP, tcp://IP or localhost',
                help: LookLocale.t(
                  'دامنه‌های خروجی و قوانین عبور مستقیم را resolve می‌کند. می‌تواند UDP، TCP یا localhost باشد.',
                  'Resolves outbound domains and bypass routing rules. '
                      'It can be an UDP DNS, TCP DNS or "localhost" to use system DNS.',
                ),
                validator: validateLocalDns,
              ),
              TextPref(
                'general.antiSanctionDns',
                LookLocale.t('DNS ضدتحریم', 'Anti Sanction DNS'),
                icon: Symbols.account_circle_off_rounded,
                help: LookLocale.t(
                  'دامنه‌های تحریمی را برای اتصال مستقیم resolve می‌کند؛ فقط در Serverless، WARP و MASQUE با خروجی Default.',
                  'Resolves the sanctioned domains so they work over a direct connection. '
                      'This only applies to Serverless, WARP and MASQUE connections when Exit node is set to Default. '
                      'It can be UDP DNS, TCP DNS, DoQ or DoH.',
                ),
                validator: validateSanctionDns,
              ),
              SwitchPref(
                'general.enableFakeDns',
                LookLocale.t('DNS فیک', 'Fake DNS'),
                icon: Symbols.dns_rounded,
                subtitle: LookLocale.t('سریع‌تر، اما ممکن است با بعضی برنامه‌ها کار نکند', 'Faster but may not work with some apps'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              SwitchPref(
                'general.enableIpv6',
                'IPv6',
                icon: Symbols.counter_6_rounded,
                subtitle: LookLocale.t('بسته به ISP خود فعال کنید', 'Enable it based on your ISP'),
              ),
              SwitchPref(
                'general.preferIpv6',
                LookLocale.t('ترجیح IPv6', 'Prefer IPv6'),
                icon: Symbols.counter_6_rounded,
                subtitle: LookLocale.t('بسته به ISP خود فعال کنید', 'Enable it based on your ISP'),
              ),
              SwitchPref(
                'device.lanSharing.enabled',
                LookLocale.t('اشتراک در شبکه محلی', 'Share over LAN'),
                icon: Symbols.lan_rounded,
                subtitle: LookLocale.t('پروکسی Socks/HTTP روی پورت ۱۰۸۰۸', 'Share a Socks, HTTP proxy on port 10808'),
              ),
              if (d.lanSharing) ...[
                TextPref(
                  'device.lanSharing.username',
                  LookLocale.t('نام کاربری پروکسی', 'Proxy username'),
                  icon: Symbols.account_circle_rounded,
                  hint: LookLocale.t('اختیاری', 'Optional'),
                  help: LookLocale.t(
                    'برای محدود کردن به دستگاه‌های مطمئن، نام کاربری و رمز بگذارید. برای بدون ورود، هر دو را خالی کنید.',
                    'Recommended to set a username and password to only allow trusted devices. '
                        'Leave both empty for no login.',
                  ),
                  allowEmpty: true,
                  validator: validateProxyUsername,
                ),
                TextPref(
                  'device.lanSharing.password',
                  LookLocale.t('رمز پروکسی', 'Proxy password'),
                  icon: Symbols.password_rounded,
                  hint: LookLocale.t('اختیاری', 'Optional'),
                  help: LookLocale.t('فقط همراه با نام کاربری استفاده می‌شود.', 'Used only together with a username.'),
                  allowEmpty: true,
                  secret: true,
                  validator: validateProxyPassword,
                ),
              ],
              FutureBuilder<bool>(
                future: VpnChannel.supportsAppendHttpProxy,
                builder: (context, snapshot) => snapshot.data == true
                    ? SwitchPref(
                        'device.appendHttpProxy',
                        LookLocale.t('افزودن پروکسی HTTP به VPN', 'Add HTTP proxy to VPN'),
                        icon: Symbols.http_rounded,
                        subtitle: LookLocale.t(
                          'استفاده مستقیم پروکسی برای برنامه‌ها و مرورگرهای پشتیبانی‌شده',
                          'Use proxy directly for supported apps, browsers',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              IntPref(
                'device.mtu',
                LookLocale.t('MTU وی‌پی‌ان', 'VPN MTU'),
                icon: Symbols.straighten_rounded,
                min: 1280,
                max: 9000,
              ),
            ],
          ),

          SectionHeader(
            LookLocale.t(
              'اتصال · ورکر (VLESS / XHTTP / Shadowsocks)',
              'Connection · Worker (VLESS / XHTTP / Shadowsocks)',
            ),
            key: _workerKey,
            icon: Symbols.deployed_code_rounded,
          ),
          SettingsCard(
            children: [
              const _DeploymentTile(),
              ChoicePref(
                'device.connection.workerProtocol',
                LookLocale.t('پروتکل ورکر', 'Worker protocol'),
                {
                  'vless_ws': 'VLESS · WS',
                  'vless_xhttp': 'VLESS · XHTTP (stream-one)',
                  'trojan_ws': 'Trojan · WS',
                  'shadowsocks_ws': 'Shadowsocks · WS (AEAD)',
                },
                icon: Symbols.hub_rounded,
              ),
              ChoicePref(
                'vless.placement',
                LookLocale.t('محل اجرای ورکر', 'Worker placement'),
                {
                  'auto': LookLocale.t('خودکار', 'Auto'),
                  'smart': 'Smart Placement',
                  'targeted': LookLocale.t('منطقه مشخص', 'Targeted region'),
                },
                icon: Symbols.pin_drop_rounded,
              ),
              if (p.vless.placement == 'targeted')
                const _PlacementRegionTile(),
              TextPref(
                'vless.remoteDns.server',
                LookLocale.t('DNS راه دور', 'Remote DNS'),
                icon: Symbols.outbound_rounded,
                help: LookLocale.t(
                  'دامنه‌های خارجی را برای مسیریابی resolve می‌کند؛ DoH یا DNS از نوع TCP.',
                  'Resolves foreign domains for routing and can be a DoH or TCP DNS.',
                ),
                validator: validateRemoteDns,
              ),
              MultiIntPref(
                'vless.ports',
                LookLocale.t('پورت‌ها', 'Ports'),
                XrayConfigBuilder.httpsPorts,
                icon: Symbols.numbers_rounded,
              ),
              ChoicePref(
                'vless.tlsFingerprint',
                LookLocale.t('اثر انگشت TLS', 'TLS Fingerprint'),
                fingerprints,
                icon: Symbols.fingerprint_rounded,
              ),
              if (state.worker != null) const _CustomDomainTile(),
              SwitchPref(
                'vless.customCdn.enabled',
                'Custom CDN',
                icon: Symbols.cloud_rounded,
                subtitle: LookLocale.t(
                  'برای دور زدن محدودیت دامنه فعال کنید',
                  'Enable for domain fronting',
                ),
              ),
              if (p.vless.customCdn.enabled) ...[
                ListPref(
                  'vless.customCdn.addresses',
                  LookLocale.t('آدرس‌های CDN سفارشی', 'Custom CDN addresses'),
                  icon: Symbols.list_arrow_rounded,
                  hint: 'speedtest.net\n151.101.66.219\n2a04:4e42::731',
                  help: LookLocale.t(
                    'همراه با هاست و SNI سفارشی استفاده می‌شود.',
                    'Used with the custom CDN host and SNI together.',
                  ),
                  itemValidator: validateHost,
                ),
                TextPref(
                  'vless.customCdn.host',
                  LookLocale.t('هاست CDN سفارشی', 'Custom CDN host'),
                  icon: Symbols.host_rounded,
                  allowEmpty: true,
                  validator: validateHost,
                ),
                TextPref(
                  'vless.customCdn.sni',
                  LookLocale.t('SNI سفارشی', 'Custom CDN SNI'),
                  icon: Symbols.host_rounded,
                  allowEmpty: true,
                  validator: validateHost,
                ),
              ],
              SwitchPref(
                'vless.ech.enabled',
                LookLocale.t('ECH در TLS', 'TLS ECH'),
                icon: Symbols.encrypted_rounded,
                subtitle: LookLocale.t('SNI واقعی را پنهان می‌کند', 'Hide the real SNI'),
              ),
              if (p.vless.ech.enabled)
                TextPref(
                  'vless.ech.dns',
                  LookLocale.t('سرور DNS برای ECH', 'ECH DNS server'),
                  icon: Symbols.dns_rounded,
                  hint: '8.8.8.8 or https://8.8.8.8/dns-query',
                  help: LookLocale.t(
                    'DNS که تنظیمات ECH از آن گرفته می‌شود؛ IP یا DoH با هاست IP. باید از شبکه شما در دسترس باشد.',
                    'DNS server the ECH config is fetched from, an IP or a DoH with an IP host. '
                        'DNS server should be reachable from your network and not blocked by your ISP.',
                  ),
                  validator: validateEchDns,
                ),
              ListTile(
                leading: const Icon(Symbols.view_week_rounded),
                title: Text(LookLocale.t('فرگمنت TCP', 'TCP Fragments')),
                subtitle: Text(_fragmentSummary(p.fragments)),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FragmentsPage()),
                ),
              ),
              TextPref(
                'vless.upstreamProxy',
                LookLocale.t('پروکسی TCP بالادست', 'Upstream TCP Proxy'),
                icon: Symbols.swap_vert_rounded,
                hint: 'host:port',
                help: LookLocale.t(
                  'یک پروکسی TCP بالادست برای جلوگیری از SNI spoofing تنظیم کنید.',
                  'Setup a upstream TCP proxy like SNI spoofing.',
                ),
                allowEmpty: true,
                validator: validateEndpoint,
              ),
              ListPref(
                'vless.proxyIps',
                LookLocale.t('آی‌پی یا دامنه‌های پروکسی', 'Proxy IPs or domains'),
                icon: Symbols.list_arrow_rounded,
                help: LookLocale.t(
                  'برای اتصال worker به سایت‌های میزبانی‌شده در کلادفلر استفاده می‌شود. برای مقدار پیش‌فرض خالی بگذارید. بهتر است خالی بماند چون IPهای پروکسی منقضی می‌شوند و IPهای پیش‌فرض مرتب به‌روز می‌شوند.',
                  'Used by the worker to connect to Cloudflare-hosted sites. Leave empty for its '
                      'built-in default. It is highly recommended to leave it empty, because Proxy IPs expire frequently '
                      'while the default IPs update regularly.',
                ),
                hint: 'proxyip.example.com\n94.1.2.3\n95.4.5.6:8443\n[2001:db8::1]\n[2001:db8::2]:8443',
                allowEmpty: true,
                itemValidator: validateHostPort,
              ),
              SwitchPref(
                'vless.enableTcpFastOpen',
                'TCP Fast Open',
                icon: Symbols.bolt_rounded,
                subtitle: LookLocale.t('با احتیاط فعال کنید', 'Enable with caution'),
              ),
              TextPref(
                'vless.fallbackUrl',
                LookLocale.t('وب‌سایت جایگزین', 'Fallback website'),
                icon: Symbols.eyeglasses_rounded,
                hint: 'https://example.com',
                help: LookLocale.t(
                  'بازدیدکننده‌هایی که VPN ندارند به‌جای ۴۰۴ این وب‌سایت را می‌بینند.',
                  'Non-VPN visitors to the worker see this website instead of a 404. ',
                ),
                allowEmpty: true,
                validator: validateHttpsUrl,
              ),
              IntPref(
                'vless.speedTestInterval',
                LookLocale.t('فاصله تست سرعت (ثانیه)', 'Speed test interval (s)'),
                icon: Symbols.timer_rounded,
                help: LookLocale.t(
                  'فاصله بین پینگ‌ها برای پیدا کردن خودکار سریع‌ترین سرور.',
                  'Interval between ping attempts to automatically find the fastest server.',
                ),
                min: 10,
                max: 300,
                suffix: ' s',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              ListPref(
                'vless.cleanIps',
                LookLocale.t('آی‌پی یا دامنه سالم', 'Clean IPs or domains'),
                icon: Symbols.list_arrow_rounded,
                hint: 'www.speedtest.net\n104.16.1.1\n2606:4700::6810:84e5',
                help: LookLocale.t(
                  'برای افزایش سرعت، آی‌پی/دامنه سالم کلادفلر بگذارید. حداقل یک IPv4 لازم است.',
                  'Set clean Cloudflare IPs or domains to boost connection speed. '
                      'Include at least one IPv4 address.',
                ),
                itemValidator: validateHost,
                listValidator: validateCleanIps,
              ),
              ListTile(
                leading: const Icon(Symbols.manage_search_rounded),
                title: Text(LookLocale.t('اسکن آی‌پی سالم', 'Scan clean IPs')),
                subtitle: Text(LookLocale.t('آی‌پی‌های سریع برای VLESS', 'Find fast IPs for VLESS')),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CloudflareScannerPage(
                      protocol: ScanProtocol.vless,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(children: [const _CloudflareAccountsTile()]),

          SectionHeader(
            LookLocale.t('اتصال · MASQUE', 'Connection · MASQUE'),
            icon: Symbols.waves_rounded,
          ),
          SettingsCard(
            children: [
              TextPref(
                'masque.remoteDns',
                LookLocale.t('DNS راه دور', 'Remote DNS'),
                icon: Symbols.outbound_rounded,
                hint: '1.1.1.1',
                help: LookLocale.t(
                  'می‌تواند DNS از نوع UDP، TCP یا DoH باشد.',
                  'It can be an UDP DNS, TCP DNS or DoH.',
                ),
                validator: validateTunnelDns,
              ),
              const TextPref(
                'masque.sni',
                'SNI',
                icon: Symbols.host_rounded,
                hint: MasqueSettings.defaultSni,
                validator: validateHost,
              ),
              const ChoicePref('masque.transport', 'Transport', {
                'h2': 'H2 · TCP',
                'h3': 'H3 · QUIC',
              }, icon: Symbols.swap_horiz_rounded),
              if (p.masque.transport == 'h2')
                ChoicePref(
                  'masque.tlsFingerprint',
                  LookLocale.t('اثر انگشت H2', 'H2 Fingerprint'),
                  fingerprints,
                  icon: Symbols.fingerprint_rounded,
                ),
              ListTile(
                leading: const Icon(Symbols.view_week_rounded),
                title: Text(LookLocale.t('فرگمنت TCP در H2', 'H2 TCP Fragments')),
                subtitle: Text(_fragmentSummary(p.masque.fragments)),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FragmentsPage(section: 'masque.'),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Symbols.graphic_eq_rounded),
                title: Text(LookLocale.t('مبهم‌سازی UDP در H3', 'H3 UDP Obfuscation')),
                subtitle: Text(
                  LookLocale.t(
                    '${p.masque.udpNoises.length} نویز',
                    '${p.masque.udpNoises.length} noise${p.masque.udpNoises.length == 1 ? '' : 's'}',
                  ),
                ),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NoisesPage(section: 'masque.'),
                  ),
                ),
              ),
              IntPref(
                'masque.speedTestInterval',
                LookLocale.t('فاصله تست سرعت (ثانیه)', 'Speed test interval (s)'),
                icon: Symbols.timer_rounded,
                help: LookLocale.t(
                  'فاصله بین پینگ‌ها برای پیدا کردن خودکار سریع‌ترین سرور.',
                  'Interval between ping attempts to automatically find the fastest server.',
                ),
                min: 10,
                max: 300,
                suffix: ' s',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              ListPref(
                'masque.endpoints',
                LookLocale.t('نقاط اتصال', 'Endpoints'),
                icon: Symbols.list_arrow_rounded,
                hint: '162.159.198.1:443\n[2606:4700:103::1]:443',
                help: LookLocale.t(
                  'هر نقطه اتصال در یک خط. حداقل دو نقطه IPv4 وارد کنید.',
                  'Each endpoint in a new line. Include at least two IPv4 endpoints.',
                ),
                itemValidator: validateEndpoint,
                listValidator: validateIpv4Endpoints,
              ),
              ListTile(
                leading: const Icon(Symbols.manage_search_rounded),
                title: Text(LookLocale.t('اسکن نقاط اتصال', 'Scan endpoints')),
                subtitle: Text(LookLocale.t('آی‌پی‌های سریع برای MASQUE', 'Find fast IPs for MASQUE')),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CloudflareScannerPage(
                      protocol: p.masque.transport == 'h3'
                          ? ScanProtocol.masqueH3
                          : ScanProtocol.masqueH2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(children: [const _MasqueAccountTile()]),

          SectionHeader(
            LookLocale.t('اتصال · WARP', 'Connection · WARP'),
            icon: Symbols.shield_rounded,
          ),
          SettingsCard(
            children: [
              TextPref(
                'warp.remoteDns',
                LookLocale.t('DNS راه دور', 'Remote DNS'),
                icon: Symbols.outbound_rounded,
                hint: '1.1.1.1',
                help: LookLocale.t(
                  'می‌تواند DNS از نوع UDP، TCP یا DoH باشد.',
                  'It can be a UDP DNS, TCP DNS or DoH.',
                ),
                validator: validateTunnelDns,
              ),
              SwitchPref(
                'warp.enableReservedBytes',
                LookLocale.t('بایت‌های رزروشده', 'Reserved bytes'),
                icon: Symbols.memory_rounded,
                subtitle: LookLocale.t('ممکن است روی بعضی ISPها کمک کند', 'May help on some ISPs'),
              ),
              ListTile(
                leading: const Icon(Symbols.graphic_eq_rounded),
                title: Text(LookLocale.t('مبهم‌سازی UDP', 'UDP Obfuscation')),
                subtitle: Text(
                  LookLocale.t(
                    '${p.udpNoises.length} نویز',
                    '${p.udpNoises.length} noise${p.udpNoises.length == 1 ? '' : 's'}',
                  ),
                ),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const NoisesPage())),
              ),
              IntPref(
                'warp.keepAlive',
                LookLocale.t('فاصله زنده‌نگه‌داشتن (ثانیه)', 'Keep alive interval (s)'),
                icon: Symbols.timer_rounded,
                help: LookLocale.t(
                  'اتصال WARP را زنده نگه می‌دارد. برای غیرفعال کردن ۰ بگذارید.',
                  'Keep WARP connection alive. Set 0 to disable.',
                ),
                min: 0,
                max: 25,
                suffix: ' s',
              ),
              IntPref(
                'warp.speedTestInterval',
                LookLocale.t('فاصله تست سرعت (ثانیه)', 'Speed test interval (s)'),
                icon: Symbols.timer_rounded,
                help: LookLocale.t(
                  'فاصله بین پینگ‌ها برای پیدا کردن خودکار سریع‌ترین سرور.',
                  'Interval between ping attempts to automatically find the fastest server.',
                ),
                min: 10,
                max: 300,
                suffix: ' s',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              ListPref(
                'warp.endpoints',
                LookLocale.t('نقاط اتصال', 'Endpoints'),
                icon: Symbols.list_arrow_rounded,
                hint: 'engage.cloudflareclient.com:2408\n162.159.192.1:2408\n[2606:4700:d0::a29f:c001]:2408',
                help: LookLocale.t(
                  'نقاط اتصال Cloudflare WARP. حداقل دو نقطه IPv4 وارد کنید.',
                  'Cloudflare Warp endpoints. Include at least two IPv4 endpoints.',
                ),
                itemValidator: validateEndpoint,
                listValidator: validateIpv4Endpoints,
              ),
              ListTile(
                leading: const Icon(Symbols.manage_search_rounded),
                title: Text(LookLocale.t('اسکن نقاط اتصال', 'Scan endpoints')),
                subtitle: Text(LookLocale.t('آی‌پی‌های سریع برای WARP', 'Find fast IPs for WARP')),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CloudflareScannerPage(
                      protocol: ScanProtocol.warp,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(children: [const _WarpAccountTile()]),

          SectionHeader(
            LookLocale.t('اتصال · سرورلس', 'Connection · Serverless'),
            icon: Symbols.cloud_off_rounded,
          ),
          SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Symbols.dns_rounded),
                title: Text(LookLocale.t('سرورهای DNS', 'DNS servers')),
                subtitle: Text(LookLocale.t('حالت DNS', 'DNS mode')),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const DnsPage())),
              ),
              SwitchPref(
                'serverless.dnsSettings.fakeSniServers',
                LookLocale.t('سرورهای SNI فیک', 'Fake SNI servers'),
                icon: Symbols.encrypted_rounded,
                subtitle: LookLocale.t('حالت DNS', 'DNS mode'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Symbols.view_week_rounded),
                title: Text(LookLocale.t('فرگمنت TCP', 'TCP Fragments')),
                subtitle: Text(LookLocale.t('حالت بسته', 'Packet mode')),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FragmentsPage(section: 'serverless.'),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Symbols.graphic_eq_rounded),
                title: Text(LookLocale.t('مبهم‌سازی UDP', 'UDP Obfuscation')),
                subtitle: Text(LookLocale.t('حالت بسته', 'Packet mode')),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NoisesPage(section: 'serverless.'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsCard(children: [const _MitmCaTile()]),

          SectionHeader(
            LookLocale.t('داده‌ها (ورود / خروج)', 'Data (Import / Export)'),
            icon: Symbols.import_export_rounded,
          ),
          const SettingsCard(
            children: [
              _ExportSettingsTile(download: false),
              _ImportSettingsTile(),
              _ExportSettingsTile(download: true),
            ],
          ),
        ],
      ),
      ),
    ),
    );
  }
}

/// The prominent entry point for the full appearance, motion and transition studio.
class _InterfaceEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _InterfaceEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 16, 13, 16),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  scheme.primary.withValues(alpha: 0.20),
                  scheme.tertiary.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.38),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: scheme.primary.withValues(alpha: 0.18),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.38),
                    ),
                  ),
                  child: Icon(
                    Symbols.palette_rounded,
                    color: scheme.primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              LookLocale.t(
                                'ظاهر، تم و حرکت',
                                'Appearance, theme & motion',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              LookLocale.t('کامل', 'NEW'),
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        LookLocale.t(
                          'پیش‌نمایش زنده · رنگ‌ها · فونت · انیمیشن · ترنزیشن صفحات',
                          'Live preview · colors · font · motion · page transitions',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Symbols.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Light / dark / follow the OS.
class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder(
      valueListenable: state.themeMode,
      builder: (context, mode, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Symbols.contrast_rounded),
            title: Text(LookLocale.t('حالت نمایش', 'Theme mode')),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(LookLocale.t('سیستم', 'System')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(LookLocale.t('روشن', 'Light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(LookLocale.t('تیره', 'Dark')),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (v) => state.setThemeMode(v.first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme colour picker: a row of colour circles, the selected one checked.
class _ThemeColorTile extends StatelessWidget {
  const _ThemeColorTile();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: state.themeColor,
      builder: (context, selected, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Symbols.palette_rounded),
            title: Text(LookLocale.t('رنگ تم', 'Theme color')),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in ThemeColor.values)
                    Tooltip(
                      message: c.label,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => state.setThemeColor(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.seed,
                            // Ring around the selected colour.
                            border: Border.all(
                              color: c == selected
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: c == selected
                              ? const Icon(
                                  Symbols.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ready-made Cloudflare Worker placement picker. Placement hints use
/// `provider:region`; users should not have to know the format by heart.
class _PlacementRegionTile extends StatelessWidget {
  const _PlacementRegionTile();

  static const _regions = <(String, String, String)>[
    ('gcp', 'us-east4', 'Virginia, US'),
    ('gcp', 'us-central1', 'Iowa, US'),
    ('gcp', 'us-west1', 'Oregon, US'),
    ('gcp', 'europe-west1', 'Belgium, EU'),
    ('gcp', 'europe-west2', 'London, UK'),
    ('gcp', 'europe-west3', 'Frankfurt, DE'),
    ('gcp', 'asia-east1', 'Taiwan'),
    ('gcp', 'asia-southeast1', 'Singapore'),
    ('aws', 'us-east-1', 'N. Virginia, US'),
    ('aws', 'us-west-2', 'Oregon, US'),
    ('aws', 'eu-central-1', 'Frankfurt, DE'),
    ('aws', 'eu-west-1', 'Ireland, EU'),
    ('aws', 'eu-west-3', 'Paris, FR'),
    ('aws', 'ap-southeast-1', 'Singapore'),
    ('aws', 'ap-northeast-1', 'Tokyo, JP'),
    ('azure', 'eastus', 'Virginia, US'),
    ('azure', 'westeurope', 'Netherlands, EU'),
    ('azure', 'southeastasia', 'Singapore'),
  ];

  String? _labelFor(String value) {
    for (final (provider, region, label) in _regions) {
      if (value == '$provider:$region') {
        return '$label · $provider:$region';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = state.readString('vless.placementRegion');
    return ListTile(
      leading: const Icon(Symbols.public_rounded),
      title: Text(LookLocale.t('منطقه اجرای ورکر', 'Placement region')),
      subtitle: Text(
        _labelFor(current) ??
            (current.isEmpty
                ? LookLocale.t('انتخاب منطقه', 'Choose a region')
                : current),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LookLocale.t('منطقه اجرای ورکر', 'Placement region'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LookLocale.t(
                            'ورکر نزدیک‌ترین دیتاسنتر به این منطقه را انتخاب می‌کند. اگر مطمئن نیستید، gcp:us-east4 یا aws:us-east-1 انتخاب امنی است.',
                            'The Worker runs near this cloud region. If unsure, gcp:us-east4 or aws:us-east-1 is a safe default.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          leading: const Icon(Symbols.edit_rounded),
                          title: Text(
                            LookLocale.t('وارد کردن دستی', 'Enter custom region'),
                          ),
                          subtitle: const Text('provider:region'),
                          onTap: () => Navigator.of(context).pop('__custom'),
                        ),
                        const Divider(height: 1),
                        for (final (provider, region, label) in _regions) ...[
                          if (provider == 'gcp' && region == 'us-east4')
                            _PlacementHeader('Google Cloud')
                          else if (provider == 'aws' && region == 'us-east-1')
                            _PlacementHeader('AWS')
                          else if (provider == 'azure' && region == 'eastus')
                            _PlacementHeader('Azure'),
                          ListTile(
                            leading: Icon(
                              current == '$provider:$region'
                                  ? Symbols.radio_button_checked_rounded
                                  : Symbols.radio_button_unchecked_rounded,
                              color: current == '$provider:$region'
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(label),
                            subtitle: Text('$provider:$region'),
                            onTap: () =>
                                Navigator.of(context).pop('$provider:$region'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!context.mounted || picked == null) return;
        if (picked == '__custom') {
          final custom = await showTextInputDialog(
            context,
            title: LookLocale.t('منطقه اجرای ورکر', 'Placement region'),
            initial: current,
            hint: 'gcp:us-east4',
            help: LookLocale.t(
              'منطقه را به شکل provider:region وارد کنید؛ مثلاً gcp:us-east4 یا aws:us-east-1.',
              'Use provider:region, for example gcp:us-east4 or aws:us-east-1.',
            ),
            validator: (v) =>
                RegExp(r'^[a-z0-9-]+:[a-z0-9-]+$').hasMatch(v)
                ? null
                : 'Use provider:region, for example gcp:us-east4',
          );
          if (custom != null) state.write('vless.placementRegion', custom);
          return;
        }
        state.write('vless.placementRegion', picked);
      },
    );
  }
}

class _PlacementHeader extends StatelessWidget {
  final String title;
  const _PlacementHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// App font picker. The selected family is persisted in device.theme.font and applied by
/// buildTheme, so settings, sheets, and pushed routes all use the same typeface.
class _FontTile extends StatelessWidget {
  const _FontTile();

  static const _fonts = {
    'OpenSans': 'Open Sans',
    'JetBrainsMono': 'JetBrains Mono',
    'system': 'System',
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: state.fontFamily,
      builder: (context, selected, _) => ListTile(
        leading: const Icon(Symbols.text_fields_rounded),
        title: Text(LookLocale.t('فونت برنامه', 'App font')),
        subtitle: Text(
          _fonts[selected] ?? _fonts['OpenSans']!,
          style: TextStyle(
            fontFamily: selected == 'system' ? null : selected,
          ),
        ),
        trailing: const Icon(Symbols.chevron_right_rounded),
        onTap: () async {
          final picked = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(LookLocale.t('فونت برنامه', 'App font')),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              content: RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in _fonts.entries)
                      RadioListTile<String>(
                        value: entry.key,
                        title: Text(
                          entry.value,
                          style: TextStyle(
                            fontFamily: entry.key == 'system'
                                ? null
                                : entry.key,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (picked != null) state.setFontFamily(picked);
        },
      ),
    );
  }
}

class _FontScaleTile extends StatelessWidget {
  const _FontScaleTile();

  static const _scales = [0.9, 1.0, 1.1, 1.25, 1.3];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: state.fontScale,
      builder: (context, selected, _) => ListTile(
        leading: const Icon(Symbols.format_size_rounded),
        title: Text(LookLocale.t('اندازه متن', 'Text size')),
        subtitle: Text('${(selected * 100).round()}%'),
        trailing: const Icon(Symbols.chevron_right_rounded),
        onTap: () async {
          final picked = await showDialog<double>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(LookLocale.t('اندازه متن', 'Text size')),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              content: RadioGroup<double>(
                groupValue: selected,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final scale in _scales)
                      RadioListTile<double>(
                        value: scale,
                        title: Text('${(scale * 100).round()}%'),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (picked != null) state.setFontScale(picked);
        },
      ),
    );
  }
}

/// A routing group: the presets on and how many custom entries; opens its page.
class _RulesTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String group;
  final Map<String, String> labels;
  final String domainHint;

  /// Null for a group without custom IPs.
  final String? ipHint;
  final String? help;
  const _RulesTile({
    required this.title,
    required this.icon,
    required this.group,
    required this.labels,
    required this.domainHint,
    this.ipHint,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final enabled = [
      for (final e in labels.entries)
        if (state.readBool('routing.$group.presets.${e.key}')) e.value,
    ];
    final custom =
        state.readList('routing.$group.domains').length +
        (ipHint == null ? 0 : state.readList('routing.$group.ips').length);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        [
          enabled.isEmpty ? 'No presets' : enabled.join(', '),
          if (custom > 0) '$custom custom',
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoutingPage(
            title: title,
            group: group,
            labels: labels,
            domainHint: domainHint,
            ipHint: ipHint,
            help: help,
          ),
        ),
      ),
    );
  }
}

/// Custom domain row: tap to attach a domain while none is set; the trash icon detaches it.
class _CustomDomainTile extends StatefulWidget {
  const _CustomDomainTile();

  @override
  State<_CustomDomainTile> createState() => _CustomDomainTileState();
}

class _CustomDomainTileState extends State<_CustomDomainTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final state = AppScope.read(context);
    final domain = await showTextInputDialog(
      context,
      title: LookLocale.t('افزودن دامنه سفارشی', 'Add custom domain'),
      hint: 'vpn.example.com',
      help: LookLocale.t(
        'دامنه باید روی همان حساب کلادفلر ثبت شده باشد. یک زیردامنه دلخواه که هنوز در کلادفلر نیست اضافه کنید؛ LookVPN رکورد DNS را می‌سازد و به worker اضافه می‌کند.',
        'The domain must be registered on the same Cloudflare account. '
            'Just add a desired subdomain which is not available on Cloudflare yet. '
            'LookVPN creates the DNS record and adds it to the worker.',
      ),
      validator: (v) => isDomain(v)
          ? null
          : LookLocale.t('دامنه نامعتبر است', 'Invalid domain'),
    );
    if (domain == null || !mounted) return;
    await _run(
      () => state.setCustomDomain(domain.toLowerCase()),
      LookLocale.t('دامنه سفارشی اضافه شد', 'Custom domain added'),
    );
  }

  Future<void> _delete() async {
    final state = AppScope.read(context);
    final domain = state.worker!.customDomain ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LookLocale.t('دامنه سفارشی حذف شود؟', 'Delete custom domain?')),
        content: Text(
          LookLocale.t(
            '$domain از worker در کلادفلر جدا می‌شود. کانفیگ‌ها به آدرس workers.dev برمی‌گردند.',
            '$domain will be detached from the worker in Cloudflare. '
                'Configs fall back to the workers.dev address.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LookLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LookLocale.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      state.removeCustomDomain,
      LookLocale.t('دامنه سفارشی حذف شد', 'Custom domain deleted'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domain = AppScope.of(context).worker?.customDomain ?? '';
    return ListTile(
      leading: const Icon(Symbols.host_rounded),
      title: Text(LookLocale.t('دامنه سفارشی', 'Custom domain')),
      subtitle: Text(domain.isEmpty ? LookLocale.t('تنظیم نشده', 'Not set') : domain),
      onTap: _busy || domain.isNotEmpty ? null : _add,
      trailing: _busy
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : domain.isEmpty
          ? null
          : IconButton(
              tooltip: LookLocale.t('حذف دامنه سفارشی', 'Delete custom domain'),
              icon: const Icon(Symbols.delete_outline_rounded),
              onPressed: _delete,
            ),
    );
  }
}

/// Domain Fronting's CA (lookvpn-cert.crt / .key): created on this device on first install, then
/// handed to Android's certificate install (like [_WarpAccountTile]).
class _MitmCaTile extends StatefulWidget {
  const _MitmCaTile();

  @override
  State<_MitmCaTile> createState() => _MitmCaTileState();
}

class _MitmCaTileState extends State<_MitmCaTile> {
  late Future<bool> _created = AppScope.read(context).hasMitmCa();
  bool _busy = false;

  Future<void> _install() async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.verified_user_rounded, size: 36, weight: 600),
        title: Text(LookLocale.t('نصب گواهی', 'Install certificate')),
        content: Text(
          LookLocale.t(
            'گواهی در پوشه Downloads ذخیره می‌شود. آن را در تنظیمات → امنیت → رمزنگاری و اعتبارنامه‌ها → نصب گواهی → گواهی CA نصب کنید.\n\nفایل‌های گواهی LookVPN را هرگز با کسی به اشتراک نگذارید؛ هر کسی که آن‌ها را داشته باشد می‌تواند ترافیک مرورگر شما را شنود کند.',
            'Certificate will be saved to Downloads folder. Install it in Settings → '
                'Security → Encryption & credentials → Install a certificate → CA certificate.\n\n'
                'Never share LookVPN certificate files with anyone. Whoever has them can sniff your '
                'browser traffic.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LookLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LookLocale.t('نصب', 'Install')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await state.installMitmCa();
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(LookLocale.t('ذخیره شد در $saved', 'Saved to $saved')),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            LookLocale.t(
              'گواهی نصب نشد: $e',
              'Could not install the certificate: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _created = state.hasMitmCa();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _created,
      builder: (context, snapshot) {
        final created = snapshot.data ?? false;
        return ListTile(
          leading: const Icon(Symbols.vpn_key_rounded),
          title: Text(LookLocale.t('گواهی MITM', 'MITM certificate')),
          subtitle: Text(
            created
                ? LookLocale.t('ساخته شده', 'Created')
                : LookLocale.t('ساخته نشده', 'Not created'),
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton.tonalIcon(
                  icon: const Icon(Symbols.security_rounded, size: 18),
                  label: Text(LookLocale.t('نصب', 'Install')),
                  onPressed: _install,
                ),
        );
      },
    );
  }
}

/// Shows the registered WARP account and renews it (panel: "Renew Warp Accounts").
class _WarpAccountTile extends StatelessWidget {
  const _WarpAccountTile();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final registered = state.profile.warp.account != null;
    return ListTile(
      leading: const Icon(Symbols.vpn_key_rounded),
      title: Text(LookLocale.t('حساب WARP', 'WARP account')),
      subtitle: Text(
        registered
            ? LookLocale.t('ثبت شده', 'Registered')
            : LookLocale.t('ثبت نشده', 'Not registered'),
      ),
      trailing: state.renewingWarp
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonalIcon(
              icon: const Icon(Symbols.autorenew_rounded, size: 18),
              label: Text(
                registered
                    ? LookLocale.t('تمدید', 'Renew')
                    : LookLocale.t('ثبت', 'Register'),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (registered) {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(LookLocale.t('تمدید حساب WARP', 'Renew WARP account')),
                      content: Text(
                        LookLocale.t(
                          'مطمئن هستید؟ حساب جدید جایگزین حساب فعلی می‌شود.',
                          'Are you sure? A new account replaces the current one.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(LookLocale.t('انصراف', 'Cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(LookLocale.t('تمدید', 'Renew')),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                }
                try {
                  await state.renewWarpAccount();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        LookLocale.t('حساب WARP به‌روز شد', 'WARP account updated'),
                      ),
                    ),
                  );
                } on StateError catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
            ),
    );
  }
}

/// Shows the registered MASQUE account and renews it, like [_WarpAccountTile].
class _MasqueAccountTile extends StatelessWidget {
  const _MasqueAccountTile();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final registered = state.profile.masque.account != null;
    return ListTile(
      leading: const Icon(Symbols.vpn_key_rounded),
      title: Text(LookLocale.t('حساب MASQUE', 'MASQUE account')),
      subtitle: Text(
        registered
            ? LookLocale.t('ثبت شده', 'Registered')
            : LookLocale.t('ثبت نشده', 'Not registered'),
      ),
      trailing: state.renewingMasque
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonalIcon(
              icon: const Icon(Symbols.autorenew_rounded, size: 18),
              label: Text(
                registered
                    ? LookLocale.t('تمدید', 'Renew')
                    : LookLocale.t('ثبت', 'Register'),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (registered) {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(LookLocale.t('تمدید حساب MASQUE', 'Renew MASQUE account')),
                      content: Text(
                        LookLocale.t(
                          'مطمئن هستید؟ حساب جدید جایگزین حساب فعلی می‌شود.',
                          'Are you sure? A new account replaces the current one.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(LookLocale.t('انصراف', 'Cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(LookLocale.t('تمدید', 'Renew')),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                }
                try {
                  await state.renewMasqueAccount();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        LookLocale.t('حساب MASQUE به‌روز شد', 'MASQUE account updated'),
                      ),
                    ),
                  );
                } on StateError catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
            ),
    );
  }
}

/// "1 fragment", "3 fragments", like the noises' subtitles.
String _fragmentSummary(List<Fragment> fragments) =>
    LookLocale.t(
      '${fragments.length} فرگمنت',
      '${fragments.length} fragment${fragments.length == 1 ? '' : 's'}',
    );

/// Which of the selected account's deployments (Workers or Pages) Worker mode connects to; the
/// VLESS settings below are its own. The account is picked in Cloudflare accounts.
class _DeploymentTile extends StatelessWidget {
  const _DeploymentTile();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final s = state.selected;
    if (s == null) {
      return ListTile(
        leading: const Icon(Symbols.deployed_code_rounded),
        title: Text(LookLocale.t('نوع', 'Type')),
        subtitle: Text(
          LookLocale.t(
            'هیچ‌کدام. پایین یک حساب کلادفلر اضافه کنید.',
            'None. Add a Cloudflare account below.',
          ),
        ),
      );
    }
    final key = AppState.deploymentKey(s.account, s.deployment);
    final deploying = state.isDeploying(s.account, s.deployment);
    final error = state.deployErrors[key];
    // Proxy IPs and the fallback website deploy right away; only a failure stays on screen.
    final status = deploying
        ? LookLocale.t('در حال استقرار…', 'Deploying…')
        : s.deployment.pending
        ? (error != null
              ? LookLocale.t('مستقر نشده: $error', 'Not deployed: $error')
              : LookLocale.t('هنوز مستقر نشده', 'Not deployed yet'))
        : null;
    final all = s.account.deployments;
    return ListTile(
      leading: const Icon(Symbols.deployed_code_rounded),
      title: Text(LookLocale.t('نوع', 'Type')),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: s.deployment.type.label),
            if (status != null)
              TextSpan(
                text: '\n$status',
                style: TextStyle(
                  color: deploying ? null : theme.colorScheme.error,
                ),
              ),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: deploying
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : s.deployment.pending
          ? IconButton(
              tooltip: LookLocale.t('استقرار دوباره', 'Deploy again'),
              icon: const Icon(Symbols.refresh_rounded),
              onPressed: () => state.redeploy(s.account, s.deployment.type),
            )
          : null,
      onTap: all.length < 2
          ? null
          : () async {
              final picked = await showDialog<WorkerType>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text(LookLocale.t('نوع', 'Type')),
                  children: [
                    RadioGroup<WorkerType>(
                      groupValue: s.deployment.type,
                      onChanged: (v) => Navigator.of(context).pop(v),
                      child: Column(
                        children: [
                          for (final d in all)
                            RadioListTile<WorkerType>(
                              value: d.type,
                              title: Text(d.type.label),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              final d = picked == null ? null : s.account.deployment(picked);
              if (d != null) state.selectDeployment(s.account, d);
            },
    );
  }
}

/// Opens the Cloudflare accounts (like the WARP account tile in the WARP section).
class _CloudflareAccountsTile extends StatelessWidget {
  const _CloudflareAccountsTile();

  @override
  Widget build(BuildContext context) {
    final account = AppScope.of(context).selected?.account;
    return ListTile(
      leading: const Icon(Symbols.cloud_rounded),
      title: Text(LookLocale.t('حساب‌های کلادفلر', 'Cloudflare accounts')),
      subtitle: account == null
          ? null
          : Text(account.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CfAccountsPage())),
    );
  }
}

const sourceCodeUrl = 'https://github.com/sasa200000/LookVpn';

/// The installed app's version (pubspec.yaml's); opens the cores' versions.
class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: VpnChannel.appInfo().then((i) => i.version).catchError((_) => ''),
      builder: (context, snapshot) => ListTile(
        leading: const Icon(Symbols.info_rounded),
        title: Text(LookLocale.t('نسخه', 'Version')),
        subtitle: Text(snapshot.data ?? '…'),
        trailing: const Icon(Symbols.chevron_right_rounded),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const _VersionsPage())),
      ),
    );
  }
}

/// The cores' versions: Xray, Psiphon and Tor.
class _VersionsPage extends StatelessWidget {
  const _VersionsPage();

  /// The core's module version as its short commit, as Psiphon's own builds record it: Psiphon
  /// no longer tags releases, so it's a pseudo-version (v1.0.11-0.20261005170209-c4a09096ab40 →
  /// Commit c4a0909).
  static String _psiphon(String s) {
    final commit = RegExp(r'-([0-9a-f]{7})[0-9a-f]{5}$')
        .firstMatch(s)
        ?.group(1);
    return commit != null
        ? LookLocale.t('کامیت $commit', 'Commit $commit')
        : s.replaceFirst(RegExp('^v'), '');
  }

  /// "Tor version 0.4.8.17." → 0.4.8.17.
  static String _tor(String s) =>
      RegExp(r'Tor version (\S+?)\.?(\s|$)').firstMatch(s)?.group(1) ??
      s.split('\n').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LookLocale.t('نسخه‌ها', 'Versions'))),
      body: FutureBuilder(
        future: VpnChannel.versions(),
        builder: (context, snapshot) {
          final v = snapshot.data;
          String shown(String Function(String) format, String? raw) =>
              switch (raw) {
                null => snapshot.hasError
                    ? LookLocale.t('نامشخص', 'Unknown')
                    : '…',
                '' => LookLocale.t('نامشخص', 'Unknown'),
                final r => format(r),
              };
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Symbols.widgets_rounded),
                    title: const Text('Xray core · Mod'),
                    subtitle: Text(shown((s) => s, v?.xray)),
                  ),
                  ListTile(
                    leading: const Icon(Symbols.widgets_rounded),
                    title: const Text('Psiphon tunnel core · Mod'),
                    subtitle: Text(shown(_psiphon, v?.psiphon)),
                  ),
                  ListTile(
                    leading: const Icon(Symbols.widgets_rounded),
                    title: const Text('Tor Expert Bundle'),
                    subtitle: Text(shown(_tor, v?.tor)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Checks GitHub for a newer release on request; the APK is downloaded in the browser.
class _UpdateTile extends StatefulWidget {
  const _UpdateTile();

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  Future<void> _check() async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final update = await state.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              LookLocale.t(
                'LookVPN به‌روز است',
                'LookVPN is up to date',
              ),
            ),
          ),
        );
      } else {
        await showUpdateSheet(context, update);
      }
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final update = state.availableUpdate;
    return ListTile(
      leading: const Icon(Symbols.update_rounded),
      title: Text(LookLocale.t('بررسی بروزرسانی', 'Check for updates')),
      subtitle: Text(
        update != null
            ? LookLocale.t(
                'نسخه ${update.version} آماده نصب است',
                'Version ${update.version} is ready',
              )
            : LookLocale.t('آخرین انتشار در GitHub', 'Latest release on GitHub'),
      ),
      trailing: state.checkingUpdate
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : update != null
          ? Badge(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Symbols.system_update_rounded),
            )
          : null,
      onTap: state.checkingUpdate
          ? null
          : update != null
          ? () => showUpdateSheet(context, update)
          : _check,
    );
  }
}

/// Downloads the latest geo assets (geoip.dat, geosite.dat) on request.
class _GeoAssetsTile extends StatefulWidget {
  const _GeoAssetsTile();

  @override
  State<_GeoAssetsTile> createState() => _GeoAssetsTileState();
}

class _GeoAssetsTileState extends State<_GeoAssetsTile> {
  bool _updating = false;

  Future<void> _update() async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _updating = true);
    try {
      await state.updateGeoAssets();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            state.isConnected
                ? 'Geo assets updated. Reconnect to use them.'
                : 'Geo assets updated',
          ),
        ),
      );
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Symbols.update_rounded),
      title: Text(LookLocale.t('بروزرسانی فایل‌های Geo', 'Update Geo assets')),
      subtitle: Text(LookLocale.t('آخرین فایل‌های Chocolate4U', 'Latest Chocolate4U assets')),
      trailing: _updating
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _updating ? null : _update,
    );
  }
}

/// Pretty JSON for display/copy.
String prettyJson(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// Exports the profile (everything but the WARP account) as a JSON file: shared with an
/// app or saved to Downloads. Device settings and the worker are never included.
class _ExportSettingsTile extends StatelessWidget {
  /// Save to Downloads instead of opening the share sheet.
  final bool download;
  const _ExportSettingsTile({required this.download});

  Future<void> _export(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final name =
        'lookvpn-settings-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final content = state.exportSettingsFile();
    try {
      if (download) {
        final where = await VpnChannel.saveFile(name: name, content: content);
        if (where != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(LookLocale.t('ذخیره شد در $where', 'Saved to $where')),
            ),
          );
        }
      } else {
        await VpnChannel.shareFile(
          name: name,
          content: content,
          title: LookLocale.t('اشتراک تنظیمات', 'Share settings'),
        );
      }
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            LookLocale.t(
              'خروجی گرفته نشد: ${e.message}',
              "Couldn't export: ${e.message}",
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(download ? Symbols.download_rounded : Symbols.send_rounded),
    title: Text(
      download
          ? LookLocale.t('خروجی تنظیمات', 'Export settings')
          : LookLocale.t('اشتراک تنظیمات', 'Share settings'),
    ),
    subtitle: Text(
      download
          ? LookLocale.t('ذخیره فایل تنظیمات در Downloads', 'Save settings file to Downloads')
          : LookLocale.t('ارسال فایل تنظیمات به کاربر دیگر', 'Send settings file to other users'),
    ),
    onTap: () => _export(context),
  );
}

/// Loads settings from a file made by "Share settings" or "Download settings".
class _ImportSettingsTile extends StatelessWidget {
  const _ImportSettingsTile();

  Future<void> _import(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final String? text;
    try {
      text = (await VpnChannel.pickFile())?.content;
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            LookLocale.t(
              'فایل خوانده نشد: ${e.message}',
              "Couldn't read the file: ${e.message}",
            ),
          ),
        ),
      );
      return;
    }
    if (text == null || !context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LookLocale.t('تنظیمات وارد شوند؟', 'Import settings?')),
        content: Text(
          LookLocale.t(
            'تنظیمات شما با تنظیمات این فایل جایگزین می‌شود. حساب WARP، worker و تنظیمات این دستگاه (لیست برنامه‌ها، اشتراک LAN، تم و…) حفظ می‌شوند.',
            'Your settings are replaced with the ones in this file. '
                'Your WARP account, worker and this device\'s setup (per-app list, LAN sharing, theme…) stay as they are.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LookLocale.t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LookLocale.t('وارد کردن', 'Import')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      state.importSettingsFile(text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(LookLocale.t('تنظیمات وارد شد', 'Settings imported')),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Symbols.upload_rounded),
    title: Text(LookLocale.t('ورود تنظیمات', 'Import settings')),
    subtitle: Text(LookLocale.t('بارگذاری تنظیمات از فایل', 'Load settings from a file')),
    onTap: () => _import(context),
  );
}


/// Bilingual Persian (RTL) / English (LTR) selector tile.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, lang, _) => ListTile(
        leading: const Icon(Symbols.translate_rounded),
        title: Text(LookLocale.t('زبان برنامه', 'App Language')),
        subtitle: Text(lang == 'fa' ? 'فارسی (راست‌به‌چپ)' : 'English (LTR)'),
        trailing: SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment(value: 'fa', label: Text('فارسی')),
            ButtonSegment(value: 'en', label: Text('EN')),
          ],
          selected: {lang},
          onSelectionChanged: (s) => LookLocale.setLang(s.first),
        ),
      ),
    );
  }
}
