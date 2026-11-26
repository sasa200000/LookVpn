import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/vpn_channel.dart';
import '../state/app_state.dart';
import 'expressive.dart';
import 'license_page.dart';
import 'mili_i18n.dart';
import 'mili_logo.dart';
import 'update_sheet.dart';

const miliSourceUrl = 'https://github.com/miladjahani/Milinovpn';
const miliCommunityUrl = 'https://t.me/miliconfig';

/// The one place for app identity, updates, source code, community and license.
/// Keeping these rows out of both the settings hub and the toolbox prevents the
/// old duplicated “About” destinations.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  List<String> _abis = const [];
  String _xray = '';
  String _psiphon = '';
  String _tor = '';
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String version = '';
    List<String> abis = const [];
    String xray = '';
    String psiphon = '';
    String tor = '';
    try {
      final app = await VpnChannel.appInfo();
      version = app.version;
      abis = app.abis;
      final cores = await VpnChannel.versions();
      xray = cores.xray;
      psiphon = cores.psiphon;
      tor = cores.tor;
    } catch (_) {
      // Widget tests and non-Android builds have no native channel.
    }
    if (!mounted) return;
    setState(() {
      _version = version;
      _abis = abis;
      _xray = xray;
      _psiphon = psiphon;
      _tor = tor;
      _loading = false;
    });
  }

  Future<void> _open(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await VpnChannel.openUrl(url)) return;
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      SnackBar(content: Text(MiliLocale.t('لینک کپی شد', 'Link copied'))),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final update = await AppScope.read(context).checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              MiliLocale.t('شما آخرین نسخه را دارید', 'You are up to date'),
            ),
          ),
        );
      } else {
        await showUpdateSheet(context, update);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final version = _version.isEmpty ? '—' : _version;
    final abis = _abis.isEmpty ? '—' : _abis.join(' · ');

    return Scaffold(
      appBar: ExpressiveSubpageHeader(
        title: MiliLocale.t('درباره و بروزرسانی', 'About & updates'),
        subtitle: MiliLocale.t(
          'نسخه، هسته‌ها، کد منبع و مجوز',
          'Version, cores, source and license',
        ),
      ),
      body: ExpressivePageBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            BentoSurface(
              highlight: true,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const MiliShieldLogo(size: 58),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MiliConfig VPN',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          MiliLocale.t(
                            'کلاینت چندپروتکلی و کنترل کلادفلر',
                            'Multi-protocol VPN & Cloudflare control',
                          ),
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            BentoTag(
                              _loading ? '…' : 'v$version',
                              icon: Symbols.tag_rounded,
                              filled: true,
                            ),
                            BentoTag(
                              abis,
                              icon: Symbols.memory_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BentoSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BentoIcon(
                        Symbols.system_update_rounded,
                        filled: true,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MiliLocale.t(
                                'بروزرسانی برنامه',
                                'App updates',
                              ),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              MiliLocale.t(
                                'بررسی و نصب امن نسخه جدید با همان امضای برنامه',
                                'Check and install a signed release in place',
                              ),
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _checking ? null : _checkForUpdate,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Symbols.refresh_rounded, size: 18),
                      label: Text(
                        _checking
                            ? MiliLocale.t('در حال بررسی…', 'Checking…')
                            : MiliLocale.t(
                                'بررسی بروزرسانی',
                                'Check for updates',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BentoSurface(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(
                children: [
                  _AboutRow(
                    icon: Symbols.code_rounded,
                    title: MiliLocale.t('کد منبع', 'Source code'),
                    subtitle: miliSourceUrl,
                    onTap: () => _open(miliSourceUrl),
                  ),
                  _divider(scheme),
                  _AboutRow(
                    icon: Symbols.support_agent_rounded,
                    title: MiliLocale.t('پشتیبانی و جامعه', 'Community & support'),
                    subtitle: '@miliconfig',
                    onTap: () => _open(miliCommunityUrl),
                  ),
                  _divider(scheme),
                  _AboutRow(
                    icon: Symbols.copyright_rounded,
                    title: MiliLocale.t('مجوز متن‌باز', 'Open-source license'),
                    subtitle: 'GNU GPL v3.0',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LicensePageView()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BentoSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.developer_board_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        MiliLocale.t('هسته‌های نصب‌شده', 'Installed cores'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CoreLine(
                    name: 'Xray',
                    value: _xray.isEmpty
                        ? (_loading
                              ? MiliLocale.t('در حال خواندن…', 'Reading…')
                              : MiliLocale.t('در دسترس نیست', 'Unavailable'))
                        : _xray,
                  ),
                  _CoreLine(
                    name: 'Psiphon',
                    value: _psiphon.isEmpty
                        ? (_loading
                              ? MiliLocale.t('در حال خواندن…', 'Reading…')
                              : MiliLocale.t('در دسترس نیست', 'Unavailable'))
                        : _psiphon,
                  ),
                  _CoreLine(
                    name: 'Tor',
                    value: _tor.isEmpty
                        ? (_loading
                              ? MiliLocale.t('در حال خواندن…', 'Reading…')
                              : MiliLocale.t('در دسترس نیست', 'Unavailable'))
                        : _tor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              MiliLocale.t(
                'MiliConfig با احترام به حریم خصوصی، بدون تبلیغات و بدون جمع‌آوری داده ساخته شده است.',
                'MiliConfig is built with respect for privacy, without ads or data collection.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Divider(
    height: 1,
    color: scheme.outlineVariant.withValues(alpha: 0.55),
  );
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AboutRow({
    required this.icon,
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
            Icon(icon, size: 21, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

class _CoreLine extends StatelessWidget {
  final String name;
  final String value;
  const _CoreLine({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
