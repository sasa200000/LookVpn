import 'package:flutter/material.dart';

import 'expressive.dart';
import 'mili_i18n.dart';
import 'prefs.dart';

/// The single routing destination: choose bypass, sanction or block rules.
class RoutingHubPage extends StatelessWidget {
  const RoutingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String>(
      valueListenable: MiliLocale.code,
      builder: (context, _, __) => Scaffold(
        appBar: ExpressiveSubpageHeader(
          title: MiliLocale.t('مسیریابی و قوانین', 'Routing & rules'),
          subtitle: MiliLocale.t(
            'عبور مستقیم، قوانین تحریم و مسدودسازی',
            'Direct routes, sanctions and blocking',
          ),
        ),
        body: ExpressivePageBackdrop(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              BentoSurface(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Column(
                  children: [
                    _RoutingEntry(
                      icon: Icons.alt_route_rounded,
                      color: scheme.primary,
                      title: MiliLocale.t('عبور مستقیم', 'Bypass'),
                      subtitle: MiliLocale.t(
                        'ایران، چین، روسیه، بیت‌تورنت و دامنه‌های دلخواه',
                        'Iran, China, Russia, BitTorrent and custom domains',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoutingPage(
                            title: MiliLocale.t(
                              'مسیریابی و عبور مستقیم',
                              'Routing & bypass',
                            ),
                            group: 'bypass',
                            labels: RoutingPage.bypassLabels,
                            domainHint: 'example.ir, geosite:ir',
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                    _RoutingEntry(
                      icon: Icons.gpp_maybe_rounded,
                      color: scheme.tertiary,
                      title: MiliLocale.t('قوانین تحریم', 'Sanction rules'),
                      subtitle: MiliLocale.t(
                        'ChatGPT، هوش مصنوعی گوگل، مایکروسافت و سرویس‌های ابری',
                        'ChatGPT, Google AIs, Microsoft and cloud services',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoutingPage(
                            title: MiliLocale.t('قوانین تحریم', 'Sanction rules'),
                            group: 'sanctionBypass',
                            labels: RoutingPage.sanctionBypassLabels,
                            domainHint: 'gemini.google.com',
                            help: MiliLocale.t(
                              RoutingPage.sanctionHelpFa,
                              RoutingPage.sanctionHelp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                    _RoutingEntry(
                      icon: Icons.block_rounded,
                      color: scheme.error,
                      title: MiliLocale.t('مسدودسازی', 'Blocking'),
                      subtitle: MiliLocale.t(
                        'تبلیغات، بدافزار، فیشینگ، ماینر و QUIC',
                        'Ads, malware, phishing, miners and QUIC',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoutingPage(
                            title: MiliLocale.t('قوانین مسدودسازی', 'Block rules'),
                            group: 'block',
                            labels: RoutingPage.blockLabels,
                            domainHint: 'ads.example.com',
                            ipHint: '10.10.34.34/24\n2001:4188:2:600:10:10:34:34/112',
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
      ),
    );
  }
}

class _RoutingEntry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoutingEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            BentoIcon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One routing group: its built-in presets (`routing.<group>.presets.<name>`), then its custom
/// domains (`routing.<group>.domains`) and, unless [ipHint] is null, IPs (`routing.<group>.ips`).
class RoutingPage extends StatelessWidget {
  final String title;

  /// "bypass", "sanctionBypass" or "block".
  final String group;
  final Map<String, String> labels;
  final String domainHint;

  /// Null for a group without custom IPs (sanction rules: domains only).
  final String? ipHint;

  /// Shown at the top of the page, or null.
  final String? help;
  const RoutingPage({
    super.key,
    required this.title,
    required this.group,
    required this.labels,
    required this.domainHint,
    this.ipHint,
    this.help,
  });

  /// When the sanction rules apply (see XrayConfigBuilder._antiSanction).
  static const sanctionHelp =
      'These rules only apply to Serverless, WARP and MASQUE connections when Exit node is set to Default.';

  static const sanctionHelpFa =
      'این قوانین فقط در اتصال‌های Serverless، WARP و MASQUE وقتی خروجی روی Default است اعمال می‌شوند.';

  /// Direct connection, resolved with the local DNS.
  static const bypassLabels = {'iran': 'Iran', 'china': 'China', 'russia': 'Russia', 'bittorrent': 'BitTorrent'};

  /// Direct connection, resolved with the anti-sanction DNS.
  static const sanctionBypassLabels = {
    'openAi': 'ChatGPT',
    'googleAi': 'Google AIs',
    'microsoft': 'Microsoft',
    'oracle': 'Oracle',
    'docker': 'Docker',
    'adobe': 'Adobe',
    'epicGames': 'Epic Games',
    'intel': 'Intel',
    'amd': 'AMD',
    'nvidia': 'Nvidia',
    'asus': 'Asus',
    'hp': 'HP',
    'lenovo': 'Lenovo',
  };

  static const blockLabels = {
    'ads': 'Ads',
    'porn': 'Porn',
    'malware': 'Malware',
    'phishing': 'Phishing',
    'cryptominers': 'Cryptominers',
    'quic': 'QUIC',
  };

  static const _faLabels = {
    'iran': 'ایران',
    'china': 'چین',
    'russia': 'روسیه',
    'bittorrent': 'بیت‌تورنت',
    'openAi': 'چت‌جی‌پی‌تی',
    'googleAi': 'هوش مصنوعی گوگل',
    'microsoft': 'مایکروسافت',
    'oracle': 'اوراکل',
    'docker': 'داکر',
    'adobe': 'ادوبی',
    'epicGames': 'اپیک گیمز',
    'intel': 'اینتل',
    'amd': 'AMD',
    'nvidia': 'انویدیا',
    'asus': 'ایسوس',
    'hp': 'اچ‌پی',
    'lenovo': 'لنوو',
    'ads': 'تبلیغات',
    'porn': 'محتوای بزرگسال',
    'malware': 'بدافزار',
    'phishing': 'فیشینگ',
    'cryptominers': 'ماینرهای رمزارز',
    'quic': 'QUIC',
  };

  String _label(String key, String fallback) =>
      MiliLocale.t(_faLabels[key] ?? fallback, fallback);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: MiliLocale.code,
      builder: (context, _, __) => Scaffold(
        appBar: ExpressiveSubpageHeader(
          title: title,
          subtitle: MiliLocale.t(
            'پیش‌تنظیم‌ها و قوانین دستی مسیر مستقیم',
            'Presets and custom direct-route rules',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (help != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(
                  help!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SectionHeader(MiliLocale.t('پیش‌تنظیم‌ها', 'Presets')),
            SettingsCard(
              children: [
                for (final e in labels.entries)
                  SwitchPref(
                    'routing.$group.presets.${e.key}',
                    _label(e.key, e.value),
                    subtitle: e.key == 'quic'
                        ? MiliLocale.t(
                            'VLESS همیشه UDP را مسدود می‌کند؛ این گزینه فقط روی پروتکل‌های دیگر اثر دارد.',
                            'VLESS always blocks UDP, this only applies to other protocols',
                          )
                        : null,
                  ),
              ],
            ),
            SectionHeader(MiliLocale.t('دستی', 'Manual')),
            SettingsCard(
              children: [
                ListPref(
                  'routing.$group.domains',
                  MiliLocale.t('دامنه‌ها', 'Domains'),
                  hint: domainHint,
                  itemValidator: validateDomain,
                ),
                if (ipHint != null)
                  ListPref(
                    'routing.$group.ips',
                    MiliLocale.t('آی‌پی یا CIDR', 'IPs or CIDRs'),
                    hint: ipHint,
                    itemValidator: validateIpOrCidr,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
