import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../models/cf_account.dart';
import '../models/settings.dart';
import '../services/exit_location_service.dart';
import '../services/local_proxy.dart';
import '../services/my_ip.dart';
import '../state/app_state.dart';
import 'chain_proxies_page.dart';
import 'expressive.dart';
import 'mili_i18n.dart';

/// Exit locations for the deployments this app made (Worker / Pages) and a
/// directory of Proton VPN's WireGuard locations.
class ExitLocationsPage extends StatelessWidget {
  const ExitLocationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: ExpressiveSubpageHeader(
          title: MiliLocale.t('لوکیشن‌های خروج', 'Exit locations'),
          subtitle: MiliLocale.t(
            'ورکر، پیجز و لوکیشن‌های پروتون وی‌پی‌ان',
            'Worker, Pages and Proton VPN locations',
          ),
        ),
        body: ExpressivePageBackdrop(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      unselectedLabelColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                      tabs: [
                        Tab(
                          height: 46,
                          icon: const Icon(Symbols.cloud_rounded, size: 17),
                          text: MiliLocale.t('ورکر و پیجز', 'Worker & Pages'),
                        ),
                        Tab(
                          height: 46,
                          icon: const Icon(Symbols.shield_rounded, size: 17),
                          text: 'Proton VPN',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: const [
                    _CloudflareExitTab(),
                    _ProtonLocationsTab(),
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

// ---------------------------------------------------------------------------
// Worker / Pages
// ---------------------------------------------------------------------------

class _CloudflareExitTab extends StatefulWidget {
  const _CloudflareExitTab();

  @override
  State<_CloudflareExitTab> createState() => _CloudflareExitTabState();
}

class _CloudflareExitTabState extends State<_CloudflareExitTab> {
  final Map<String, CloudflareEdgeResult> _results = {};
  final Set<String> _loading = {};
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _probeAll();
    });
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  List<({SavedCfAccount account, Deployment deployment})> get _deployments =>
      AppScope.of(context).deployments;

  Future<void> _probe(String host) async {
    if (_loading.contains(host)) return;
    setState(() => _loading.add(host));
    final result = await probeCloudflareEdge(host, client: _client);
    if (!mounted) return;
    setState(() {
      _results[host] = result;
      _loading.remove(host);
    });
  }

  void _probeAll() {
    for (final entry in _deployments) {
      final host = entry.deployment.host;
      if (!_results.containsKey(host)) unawaited(_probe(host));
    }
  }

  void _copyHost(String host) {
    Clipboard.setData(ClipboardData(text: host));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(MiliLocale.t('آدرس کپی شد', 'Host copied')),
      ),
    );
  }

  void _export() {
    final data = <String, dynamic>{
      for (final entry in _deployments)
        entry.deployment.host: {
          'type': entry.deployment.type.name,
          'name': entry.deployment.name,
          'account': entry.account.label,
          'host': entry.deployment.host,
          'colo': _results[entry.deployment.host]?.colo,
          'latencyMs': _results[entry.deployment.host]?.latencyMs,
          'error': _results[entry.deployment.host]?.error,
        },
    };
    Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          MiliLocale.t(
            'خروجی لوکیشن‌ها کپی شد',
            'Location output copied',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deployments = _deployments;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        BentoSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const BentoIcon(Symbols.travel_explore_rounded, filled: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MiliLocale.t(
                        'لبه کلادفلر deployments',
                        'Cloudflare deployment edge',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      MiliLocale.t(
                        'کولو (colo) واقعی که درخواست Worker یا Pages را پاسخ می‌دهد؛ از هدر cf-ray خوانده می‌شود.',
                        'The real colo serving each Worker or Pages request, read from its cf-ray header.',
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading.isEmpty ? _probeAll : null,
                icon: const Icon(Symbols.refresh_rounded, size: 17),
                label: Text(MiliLocale.t('بررسی همه', 'Probe all')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: MiliLocale.t('کپی خروجی JSON', 'Copy JSON output'),
              onPressed: deployments.isEmpty ? null : _export,
              icon: const Icon(Symbols.content_copy_rounded, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (deployments.isEmpty)
          BentoSurface(
            child: Row(
              children: [
                const BentoIcon(Symbols.cloud_off_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    MiliLocale.t(
                      'هنوز Worker یا Pages ساخته نشده است. از حساب‌های کلادفلر یک deployment بسازید.',
                      'No Worker or Pages deployment yet. Create one from Cloudflare accounts.',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final entry in deployments) ...[
            _DeploymentLocationCard(
              account: entry.account,
              deployment: entry.deployment,
              result: _results[entry.deployment.host],
              loading: _loading.contains(entry.deployment.host),
              onProbe: () => _probe(entry.deployment.host),
              onCopy: () => _copyHost(entry.deployment.host),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

const _coloPlaces = {
  'AMS': 'Amsterdam',
  'ARN': 'Stockholm',
  'ATL': 'Atlanta',
  'BOM': 'Mumbai',
  'BOS': 'Boston',
  'BRU': 'Brussels',
  'CDG': 'Paris',
  'CPH': 'Copenhagen',
  'DEL': 'Delhi',
  'DFW': 'Dallas',
  'DOH': 'Doha',
  'DXB': 'Dubai',
  'FCO': 'Rome',
  'FRA': 'Frankfurt',
  'GRU': 'São Paulo',
  'HKG': 'Hong Kong',
  'IAD': 'Washington',
  'ICN': 'Seoul',
  'IST': 'Istanbul',
  'JFK': 'New York',
  'JNB': 'Johannesburg',
  'KIX': 'Osaka',
  'LAX': 'Los Angeles',
  'LHR': 'London',
  'MAD': 'Madrid',
  'MEL': 'Melbourne',
  'MIA': 'Miami',
  'MXP': 'Milan',
  'NRT': 'Tokyo',
  'ORD': 'Chicago',
  'PRG': 'Prague',
  'RUH': 'Riyadh',
  'SEA': 'Seattle',
  'SIN': 'Singapore',
  'SJC': 'San Jose',
  'SYD': 'Sydney',
  'TLV': 'Tel Aviv',
  'VIE': 'Vienna',
  'WAW': 'Warsaw',
  'YYZ': 'Toronto',
  'ZRH': 'Zurich',
};

String _coloLabel(String code) {
  final place = _coloPlaces[code];
  return place == null ? code : '$code · $place';
}

class _DeploymentLocationCard extends StatelessWidget {
  final SavedCfAccount account;
  final Deployment deployment;
  final CloudflareEdgeResult? result;
  final bool loading;
  final VoidCallback onProbe;
  final VoidCallback onCopy;

  const _DeploymentLocationCard({
    required this.account,
    required this.deployment,
    required this.result,
    required this.loading,
    required this.onProbe,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPages = deployment.type == WorkerType.pages;
    return BentoSurface(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(
                isPages ? Symbols.web_rounded : Symbols.cloud_rounded,
                color: isPages ? scheme.tertiary : scheme.primary,
                box: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isPages ? 'Pages' : 'Worker'} · ${deployment.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.label} · ${deployment.host}',
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
              IconButton(
                tooltip: MiliLocale.t('کپی آدرس', 'Copy host'),
                visualDensity: VisualDensity.compact,
                onPressed: onCopy,
                icon: const Icon(Symbols.content_copy_rounded, size: 17),
              ),
              IconButton(
                tooltip: MiliLocale.t('بررسی لوکیشن', 'Probe location'),
                visualDensity: VisualDensity.compact,
                onPressed: loading ? null : onProbe,
                icon: loading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.my_location_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            Text(
              MiliLocale.t('در حال خواندن لبه کلادفلر…', 'Reading the Cloudflare edge…'),
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            )
          else if (result == null)
            Text(
              MiliLocale.t(
                'برای دیدن کولو و تأخیر، بررسی را بزنید.',
                'Probe to see the colo and latency.',
              ),
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            )
          else if (result!.ok)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                BentoTag(
                  _coloLabel(result!.colo!),
                  icon: Symbols.location_on_rounded,
                  filled: true,
                ),
                if (result!.latencyMs != null)
                  BentoTag(
                    '${result!.latencyMs} ms',
                    icon: Symbols.speed_rounded,
                    color: scheme.tertiary,
                  ),
                BentoTag(
                  isPages ? 'Pages edge' : 'Worker edge',
                  icon: Symbols.cloud_done_rounded,
                  color: scheme.primary,
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Symbols.error_outline_rounded, size: 15, color: scheme.error),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    result!.error ?? MiliLocale.t('بررسی نشد', 'Probe failed'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: onProbe,
                  child: Text(MiliLocale.t('تلاش دوباره', 'Retry')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proton VPN
// ---------------------------------------------------------------------------

class _ProtonLocationsTab extends StatefulWidget {
  const _ProtonLocationsTab();

  @override
  State<_ProtonLocationsTab> createState() => _ProtonLocationsTabState();
}

class _ProtonLocationsTabState extends State<_ProtonLocationsTab> {
  final _search = TextEditingController();
  List<ProtonLocation>? _locations;
  String? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = AppScope.read(context);
    final client = state.isConnected
        ? proxiedClient(LocalProxy.port)
        : http.Client();
    try {
      final locations = await fetchProtonLocations(client: client);
      if (mounted) setState(() => _locations = locations);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ProtonLocation> get _filtered {
    final all = _locations ?? const <ProtonLocation>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (l) =>
              l.country.toLowerCase().contains(q) ||
              l.city.toLowerCase().contains(q) ||
              l.server.toLowerCase().contains(q) ||
              l.hostname.toLowerCase().contains(q),
        )
        .toList();
  }

  void _copy(ProtonLocation location) {
    Clipboard.setData(
      ClipboardData(
        text:
            '${location.place} · ${location.label}\n'
            'Endpoint: ${location.hostname}:51820\n'
            'PublicKey: ${location.publicKey}',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          MiliLocale.t('مشخصات WireGuard کپی شد', 'WireGuard details copied'),
        ),
      ),
    );
  }

  void _export(List<ProtonLocation> locations) {
    final json = const JsonEncoder.withIndent('  ').convert([
      for (final l in locations)
        {
          'country': l.country,
          'city': l.city,
          'server': l.server,
          'hostname': l.hostname,
          'port': 51820,
          'publicKey': l.publicKey,
          'secureCore': l.secureCore,
          'portForwarding': l.portForwarding,
        },
    ]);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          MiliLocale.t(
            'خروجی ${locations.length} لوکیشن کپی شد',
            'Copied ${locations.length} locations',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: filtered.length + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BentoSurface(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BentoIcon(Symbols.shield_rounded, filled: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MiliLocale.t(
                              'کاتالوگ لوکیشن‌های پروتون',
                              'Proton location directory',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            MiliLocale.t(
                              'داده‌ها از کاتالوگ عمومی Gluetun خوانده می‌شوند. API عمومی پروتون از ۲۰۲۵ نیاز به ورود دارد؛ برای اتصال، فایل WireGuard رسمی پروتون را در زنجیره پروکسی وارد کنید.',
                              'Data comes from the public Gluetun catalog. Proton\'s public API has required sign-in since 2025; to connect, import your official Proton WireGuard file under Chain proxies.',
                            ),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ChainProxiesPage(),
                              ),
                            ),
                            icon: const Icon(Symbols.vpn_key_rounded, size: 16),
                            label: Text(
                              MiliLocale.t(
                                'وارد کردن کانفیگ پروتون',
                                'Import Proton config',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(
                          Symbols.search_rounded,
                          size: 20,
                        ),
                        hintText: MiliLocale.t(
                          'جستجوی کشور، شهر یا سرور…',
                          'Search country, city or server…',
                        ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: MiliLocale.t('کپی خروجی', 'Copy output'),
                    onPressed: filtered.isEmpty ? null : () => _export(filtered),
                    icon: const Icon(Symbols.content_copy_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const LinearProgressIndicator(minHeight: 3)
              else if (_error != null)
                BentoSurface(
                  child: Row(
                    children: [
                      Icon(
                        Symbols.cloud_off_rounded,
                        color: scheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          MiliLocale.t(
                            'کاتالوگ دریافت نشد: $_error',
                            'Could not load the catalog: $_error',
                          ),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _load,
                        child: Text(MiliLocale.t('تلاش دوباره', 'Retry')),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: Text(
                    MiliLocale.t(
                      '${filtered.length} لوکیشن WireGuard',
                      '${filtered.length} WireGuard locations',
                    ),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
            ],
          );
        }
        if (index <= 2) return const SizedBox.shrink();
        final location = filtered[index - 3];
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 7, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.public_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${location.place} · ${location.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location.hostname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (location.secureCore)
                  BentoTag(
                    'Secure Core',
                    color: scheme.tertiary,
                  ),
                IconButton(
                  tooltip: MiliLocale.t('کپی WireGuard', 'Copy WireGuard'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copy(location),
                  icon: const Icon(Symbols.content_copy_rounded, size: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
