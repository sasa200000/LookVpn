import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../services/chain_proxy.dart';
import '../services/mili_ip_pool.dart';
import '../services/mili_panel_client.dart';
import '../services/my_ip.dart';
import '../state/app_state.dart';
import 'expressive.dart';
import 'mili_i18n.dart';
import 'theme.dart';

/// MiliConfig Hub: brings Mili Panel's bundled Clean IP pool,
/// 1-tap Fragment / WARP OBF / DNS / ECH presets, and live Mili Panel Sync
/// directly into the native Android VPN client.
class MiliHubPage extends StatefulWidget {
  final int initialTab;
  const MiliHubPage({super.key, this.initialTab = 0});

  @override
  State<MiliHubPage> createState() => _MiliHubPageState();
}

class _MiliHubPageState extends State<MiliHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: ExpressiveSubpageHeader(
        title: 'Mili Hub',
        subtitle: MiliLocale.t(
          'مخزن آی‌پی تمیز، پریست‌ها و همگام‌سازی پنل',
          'Clean IP pool, presets and panel sync',
        ),
      ),
      body: ExpressivePageBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabs,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: scheme.onPrimaryContainer,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: [
                      Tab(
                        height: 46,
                        icon: const Icon(Symbols.public_rounded, size: 17),
                        text: MiliLocale.t('آی‌پی تمیز', 'IP Pool'),
                      ),
                      Tab(
                        height: 46,
                        icon: const Icon(Symbols.bolt_rounded, size: 17),
                        text: MiliLocale.t('پریست‌ها', 'Presets'),
                      ),
                      Tab(
                        height: 46,
                        icon: const Icon(
                          Symbols.cloud_sync_rounded,
                          size: 17,
                        ),
                        text: MiliLocale.t('همگام‌سازی', 'Panel Sync'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [_IpPoolTab(), _PresetsTab(), _PanelSyncTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Mili Clean IP Pool + Fixed IP & Random Picker
// ---------------------------------------------------------------------------

class _IpPoolTab extends StatefulWidget {
  const _IpPoolTab();

  @override
  State<_IpPoolTab> createState() => _IpPoolTabState();
}

class _IpPoolTabState extends State<_IpPoolTab> {
  String _selectedCountry = '';
  String _query = '';
  late final Future<MiliIpPoolData> _future = MiliCatalog.loadIpPool();

  void _applyIps(BuildContext context, List<String> ips, String label) {
    if (ips.isEmpty) return;
    final state = AppScope.read(context);
    state.write('vless.cleanIps', ips);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${ips.length} clean IP(s) ($label) to VLESS Clean IPs'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return FutureBuilder<MiliIpPoolData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final filtered = data.byCountry(_selectedCountry).where((e) {
          if (_query.isEmpty) return true;
          return e.ip.contains(_query) ||
              e.country.toLowerCase().contains(_query.toLowerCase());
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Card(
                margin: EdgeInsets.zero,
                shape: roundedShape(
                  kCardRadius,
                  side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Symbols.dns_rounded, color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${data.countries.length} Countries · Clean IP Pool',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              final picks = data.pickRandom(
                                count: 10,
                                countryCode: _selectedCountry,
                              );
                              _applyIps(
                                context,
                                picks,
                                _selectedCountry.isEmpty ? 'Global Random' : _selectedCountry,
                              );
                            },
                            icon: const Icon(Symbols.shuffle_rounded, size: 18),
                            label: const Text('Random 10'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Symbols.search_rounded, size: 20),
                          hintText: 'Filter by IP or country code (e.g. DE, NL, US)…',
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedCountry.isEmpty,
                      label: const Text('All'),
                      onSelected: (_) => setState(() => _selectedCountry = ''),
                    ),
                  ),
                  for (final c in data.countries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _selectedCountry == c.code,
                        label: Text('${countryFlag(c.code)} ${c.code} (${c.count})'),
                        onSelected: (_) => setState(() => _selectedCountry = c.code),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primary.withValues(alpha: 0.14),
                        child: Text(
                          countryFlag(item.country),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      title: Text(
                        item.ip,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('Region: ${item.country} · Tap pin for Fixed IP'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Copy IP',
                            icon: const Icon(Symbols.content_copy_rounded, size: 19),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.ip));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied ${item.ip}')),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Lock as Fixed IP',
                            icon: Icon(
                              Symbols.push_pin_rounded,
                              size: 19,
                              color: scheme.primary,
                            ),
                            onPressed: () =>
                                _applyIps(context, [item.ip], 'Fixed ${item.country}'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Mili Presets (Fragment, WARP OBF LITE/BALANCED/AGGRESSIVE/STEALTH, DNS)
// ---------------------------------------------------------------------------

class _PresetsTab extends StatefulWidget {
  const _PresetsTab();

  @override
  State<_PresetsTab> createState() => _PresetsTabState();
}

class _PresetsTabState extends State<_PresetsTab> {
  late final Future<MiliPresetsBundle> _future = MiliCatalog.loadPresets();

  void _applyFragment(BuildContext context, MiliFragmentPreset p) {
    final state = AppScope.read(context);
    final packets = FragmentPackets.parse(p.packets);
    final frag = Fragment(
      packets: packets,
      lengths: [Range(p.lengthMin, p.lengthMax)],
      delays: [Range(p.intervalMin, p.intervalMax)],
    );
    state.write('fragments', [frag.toJson()]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied fragment preset: ${p.name}')),
    );
  }

  void _applyWarpProfile(BuildContext context, MiliWarpProfile p) {
    final state = AppScope.read(context);
    final noise = UdpNoise(
      type: NoiseType.rand,
      size: Range(p.noiseSizeMin, p.noiseSizeMax),
      count: p.noiseCountMax,
      delay: Range(p.noiseDelayMin, p.noiseDelayMax),
    );
    state.write('udpNoises', [noise.toJson()]);
    state.write('device.mtu', p.mtu);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied WARP obfuscation profile: ${p.name}')),
    );
  }

  void _applyDns(BuildContext context, MiliDnsPreset d) {
    final state = AppScope.read(context);
    if (d.url.startsWith('https://')) {
      state.write('vless.remoteDns', d.url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set Remote DNS to ${d.name}')),
      );
    } else {
      state.write('general.antiSanctionDns', d.url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set Anti-Sanction DNS to ${d.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return FutureBuilder<MiliPresetsBundle>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bundle = snap.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            _SectionLabel(
              icon: Symbols.broken_image_rounded,
              title: 'Mili TCP Fragment Presets',
              color: scheme.primary,
            ),
            for (final f in bundle.fragments)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${f.subtitle}\nPackets: ${f.packets} · Len: ${f.lengthMin}-${f.lengthMax} · Delay: ${f.intervalMin}-${f.intervalMax}ms',
                  ),
                  isThreeLine: true,
                  trailing: FilledButton.tonal(
                    onPressed: () => _applyFragment(context, f),
                    child: const Text('Apply'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _SectionLabel(
              icon: Symbols.graphic_eq_rounded,
              title: 'Mili WARP OBF Profiles',
              color: scheme.secondary,
            ),
            for (final w in bundle.warpProfiles)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${w.subtitle}\nMTU: ${w.mtu} · Noise: ${w.noiseSizeMin}-${w.noiseSizeMax}B × ${w.noiseCountMax}',
                  ),
                  isThreeLine: true,
                  trailing: FilledButton.tonal(
                    onPressed: () => _applyWarpProfile(context, w),
                    child: const Text('Apply'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _SectionLabel(
              icon: Symbols.dns_rounded,
              title: 'Mili DNS & Anti-Sanction Presets',
              color: scheme.primary,
            ),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < bundle.dnsPresets.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      dense: true,
                      title: Text(bundle.dnsPresets[i].name),
                      subtitle: Text(
                        bundle.dnsPresets[i].url,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _applyDns(context, bundle.dnsPresets[i]),
                        child: const Text('Use'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Live Mili Panel Sync (/ips & Subscription Importer)
// ---------------------------------------------------------------------------

class _PanelSyncTab extends StatefulWidget {
  const _PanelSyncTab();

  @override
  State<_PanelSyncTab> createState() => _PanelSyncTabState();
}

class _PanelSyncTabState extends State<_PanelSyncTab> {
  final _panelUrlCtrl = TextEditingController();
  final _subUrlCtrl = TextEditingController();
  final _client = MiliPanelClient();
  bool _busyIps = false;
  bool _busySub = false;
  String? _statusMessage;

  @override
  void dispose() {
    _panelUrlCtrl.dispose();
    _subUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pullIps() async {
    setState(() {
      _busyIps = true;
      _statusMessage = null;
    });
    try {
      final ips = await _client.fetchPanelIps(_panelUrlCtrl.text, count: 12);
      if (!mounted) return;
      if (ips.isEmpty) {
        setState(() => _statusMessage = 'No clean IPs returned from /ips.');
      } else {
        AppScope.read(context).write('vless.cleanIps', ips);
        setState(() => _statusMessage = 'Synced ${ips.length} live clean IPs into VLESS Clean IPs.');
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busyIps = false);
    }
  }

  Future<void> _importSubscription() async {
    setState(() {
      _busySub = true;
      _statusMessage = null;
    });
    try {
      final links = await _client.fetchSubscriptionLinks(_subUrlCtrl.text);
      if (!mounted) return;
      if (links.isEmpty) {
        setState(() => _statusMessage = 'No supported proxy URIs found in subscription.');
      } else {
        final chains = parseChainProxies(links.join('\n'));
        AppScope.read(context).addChains(chains);
        setState(() => _statusMessage = 'Imported ${chains.length} node(s) into Chain Proxies.');
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busySub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        Card(
          shape: roundedShape(
            kCardRadius,
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.cloud_download_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Sync Live Clean IPs from Mili Panel',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your deployed MiliConfig Panel domain to pull fresh clean IPs from its /ips feed directly into VLESS Clean IPs.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _panelUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mili Panel URL',
                    hintText: 'https://your-panel.workers.dev',
                    prefixIcon: Icon(Symbols.link_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busyIps ? null : _pullIps,
                    icon: _busyIps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Symbols.sync_rounded),
                    label: const Text('Pull Live /ips'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          shape: roundedShape(
            kCardRadius,
            side: BorderSide(color: scheme.secondary.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.hub_rounded, color: scheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Import Mili Subscription into Chain Proxies',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste a MiliConfig user subscription URL (plain or base64) to import VLESS, Trojan, Shadowsocks, or WireGuard nodes as Chain Proxies.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subscription URL',
                    hintText: 'https://your-panel.workers.dev/sub/...',
                    prefixIcon: Icon(Symbols.rss_feed_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _busySub ? null : _importSubscription,
                    icon: _busySub
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Symbols.download_rounded),
                    label: const Text('Import Subscription Nodes'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 14),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
