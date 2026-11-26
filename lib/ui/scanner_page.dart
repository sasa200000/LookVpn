import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/look_ip_pool.dart';
import '../services/look_live_scanner.dart';
import '../services/my_ip.dart';
import '../services/scanner_channel.dart';
import '../state/app_state.dart';
import 'cloudflare_scanner_page.dart';
import 'dashboard_tools.dart';
import 'expressive.dart';
import 'look_i18n.dart';

/// UI for the Cloudflare network scanner.
///
/// Scanning logic is unchanged. The presentation is a compact expressive Bento
/// page: one live scanner, two one-tap pool actions, four deep-scan protocols,
/// and the long IP list tucked into a searchable sheet instead of the main view.
class ExpressiveScannerTab extends StatefulWidget {
  const ExpressiveScannerTab({super.key});

  @override
  State<ExpressiveScannerTab> createState() => _ExpressiveScannerTabState();
}

class _ExpressiveScannerTabState extends State<ExpressiveScannerTab> {
  String _selectedCountry = '';
  final _poolFuture = LookCatalog.loadIpPool();
  final _liveScanner = LookLiveScanner();
  StreamSubscription? _scanSub;
  bool _scanning = false;
  int _tested = 0;
  int _total = 0;
  List<LookScanResult> _liveResults = const [];

  int _livePort = 443;
  int _liveSample = 80;
  int _liveTimeout = 1400;
  int _liveConcurrency = 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = AppScope.read(context).device.scanners['look_live'];
      if (saved == null) return;
      setState(() {
        int? number(String key) =>
            saved[key] is num ? (saved[key] as num).toInt() : null;
        final port = number('port');
        final sample = number('sample');
        final timeout = number('timeout');
        final concurrency = number('concurrency');
        if (port != null) _livePort = port;
        if (sample != null) _liveSample = sample;
        if (timeout != null) _liveTimeout = timeout;
        if (concurrency != null) _liveConcurrency = concurrency;
      });
    });
  }

  @override
  void dispose() {
    _liveScanner.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  void _applyCleanIps(List<String> ips, String label) {
    if (ips.isEmpty) return;
    AppScope.read(context).write('vless.cleanIps', ips);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LookLocale.t(
            '${ips.length} آی‌پی ($label) به‌عنوان آی‌پی تمیز ثبت شد',
            'Set ${ips.length} IP(s) ($label) as Clean IPs',
          ),
        ),
      ),
    );
  }

  void _applyProxyIps(List<String> ips, String label) {
    if (ips.isEmpty) return;
    final formatted = ips
        .map(
          (ip) => ip.contains(':') && !ip.startsWith('[')
              ? '[$ip]:443'
              : (ip.contains(':') ? ip : '$ip:443'),
        )
        .toList();
    AppScope.read(context).write('vless.proxyIps', formatted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LookLocale.t(
            '${formatted.length} آی‌پی ($label) به‌عنوان پروکسی ثبت شد',
            'Set ${formatted.length} IP(s) ($label) as ProxyIPs',
          ),
        ),
      ),
    );
  }

  void _startLiveScan(LookIpPoolData data) {
    _liveScanner.cancel();
    _scanSub?.cancel();
    final state = AppScope.read(context);
    if (state.isReady) {
      state.write('device.scanners.look_live', {
        'port': _livePort,
        'sample': _liveSample,
        'timeout': _liveTimeout,
        'concurrency': _liveConcurrency,
      });
    }
    final pool = List<LookIpEntry>.of(
      data.byCountry(_selectedCountry),
    )..shuffle();
    final sample = (_liveSample <= 0 ? pool : pool.take(_liveSample)).toList();
    setState(() {
      _scanning = true;
      _tested = 0;
      _total = sample.length;
      _liveResults = const [];
    });
    _scanSub = _liveScanner
        .scan(
          entries: sample,
          port: _livePort,
          concurrency: _liveConcurrency,
          timeout: Duration(milliseconds: _liveTimeout),
        )
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              _tested = event.tested;
              _total = event.total;
              _liveResults = event.results;
            });
          },
          onDone: () {
            if (mounted) setState(() => _scanning = false);
          },
          onError: (_) {
            if (mounted) setState(() => _scanning = false);
          },
        );
  }

  void _stopLiveScan() {
    _liveScanner.cancel();
    _scanSub?.cancel();
    setState(() => _scanning = false);
  }

  Future<void> _pickCountry(LookIpPoolData data) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _CountryScanSheet(
        countries: data.countries,
        selected: _selectedCountry,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCountry = picked);
    }
  }

  Future<void> _scannerSettings() async {
    var port = _livePort;
    var sample = _liveSample;
    var timeout = _liveTimeout;
    var concurrency = _liveConcurrency;
    final result = await showDialog<(int, int, int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(LookLocale.t('تنظیمات اسکن زنده', 'Live scan settings')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: port,
                  decoration: InputDecoration(
                    labelText: LookLocale.t('پورت', 'Port'),
                  ),
                  items: const [443, 2053, 2083, 2087, 2096, 8443]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text('$value')),
                      )
                      .toList(),
                  onChanged: (value) =>
                      value == null ? null : update(() => port = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: sample,
                  decoration: InputDecoration(
                    labelText: LookLocale.t('تعداد نمونه', 'Sample size'),
                  ),
                  items: const [40, 80, 160, 0]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 0 ? LookLocale.t('همه', 'All') : '$value',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      value == null ? null : update(() => sample = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: timeout,
                  decoration: InputDecoration(
                    labelText: LookLocale.t('تایم‌اوت (ms)', 'Timeout (ms)'),
                  ),
                  items: const [800, 1400, 2000, 3000]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text('$value')),
                      )
                      .toList(),
                  onChanged: (value) =>
                      value == null ? null : update(() => timeout = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: concurrency,
                  decoration: InputDecoration(
                    labelText: LookLocale.t('همزمانی', 'Concurrency'),
                  ),
                  items: const [8, 16, 32, 48]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text('$value')),
                      )
                      .toList(),
                  onChanged: (value) =>
                      value == null ? null : update(() => concurrency = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LookLocale.t('انصراف', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop((port, sample, timeout, concurrency)),
              child: Text(LookLocale.t('ذخیره', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _livePort = result.$1;
      _liveSample = result.$2;
      _liveTimeout = result.$3;
      _liveConcurrency = result.$4;
    });
  }

  Future<void> _showAllResults() async {
    await showBentoSheet(
      context: context,
      builder: (_) => _LiveResultsSheet(
        results: _liveResults,
        onClean: (ips) => _applyCleanIps(ips, 'Live scan'),
        onProxy: (ips) => _applyProxyIps(ips, 'Live scan'),
      ),
    );
  }

  Future<void> _openPool(LookIpPoolData data) async {
    await showBentoSheet(
      context: context,
      builder: (_) => _PoolSheet(
        data: data,
        onClean: (ips, label) => _applyCleanIps(ips, label),
        onProxy: (ips, label) => _applyProxyIps(ips, label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppScope.of(context);
    final cleanCount = state.vless.cleanIps.length;
    final proxyCount = state.vless.proxyIps.length;

    return FutureBuilder<LookIpPoolData>(
      future: _poolFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final countries = data?.countries.length ?? 0;
        final fastest = _liveResults.isEmpty ? null : _liveResults.first;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            lookHomeTopInset(context) + 8,
            16,
            108,
          ),
          children: [
            BentoSurface(
              highlight: true,
              padding: const EdgeInsets.fromLTRB(17, 17, 15, 16),
              child: Row(
                children: [
                  const BentoOrb(Symbols.radar_rounded, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                LookLocale.t('اسکنر شبکه', 'Network scanner'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            BentoTag(
                              _scanning
                                  ? LookLocale.t('در حال اسکن', 'Scanning')
                                  : LookLocale.t('آماده', 'Ready'),
                              icon: Symbols.circle,
                              filled: _scanning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LookLocale.t(
                            '$countries کشور · انتخاب و تست واقعی TCP',
                            '$countries countries · real TCP probing',
                          ),
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _CountryFilterBar(
              countries: data?.countries ?? const [],
              selected: _selectedCountry,
              disabled: _scanning || data == null,
              onTap: data == null ? null : () => _pickCountry(data),
            ),
            const SizedBox(height: 10),
            _LiveScanCard(
              scanning: _scanning,
              tested: _tested,
              total: _total,
              results: _liveResults,
              fastest: fastest,
              onStart: data == null ? null : () => _startLiveScan(data),
              onStop: _stopLiveScan,
              onSettings: _scanning ? null : _scannerSettings,
              onShowAll: _liveResults.isEmpty ? null : _showAllResults,
              onClean: (ips) => _applyCleanIps(ips, 'Live scan'),
              onProxy: (ips) => _applyProxyIps(ips, 'Live scan'),
            ),
            const SizedBox(height: 4),
            BentoSectionLabel(
              LookLocale.t('آی‌پی تمیز و پروکسی', 'Clean IP & proxy'),
              icon: Symbols.bolt_rounded,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PoolActionCard(
                    icon: Symbols.bolt_rounded,
                    title: LookLocale.t('آی‌پی تمیز', 'Clean IP'),
                    value: '$cleanCount',
                    subtitle: LookLocale.t(
                      'ثبت ۱۰ آی‌پی سریع در پروفایل',
                      'Add 10 fast IPs to your profile',
                    ),
                    color: scheme.primary,
                    enabled: data != null,
                    onTap: data == null
                        ? null
                        : () => _applyCleanIps(
                            data.pickRandom(
                              count: 10,
                              countryCode: _selectedCountry,
                            ),
                            _selectedCountry.isEmpty
                                ? 'Random'
                                : _selectedCountry,
                          ),
                  ),
                ),
                const SizedBox(width: kBentoGap),
                Expanded(
                  child: _PoolActionCard(
                    icon: Symbols.dns_rounded,
                    title: LookLocale.t('پروکسی کلادفلر', 'Cloudflare proxy'),
                    value: '$proxyCount',
                    subtitle: LookLocale.t(
                      'ثبت ۵ پروکسی برای ورکر',
                      'Add 5 Worker proxy IPs',
                    ),
                    color: scheme.tertiary,
                    enabled: data != null,
                    onTap: data == null
                        ? null
                        : () => _applyProxyIps(
                            data.pickRandom(
                              count: 5,
                              countryCode: _selectedCountry,
                            ),
                            _selectedCountry.isEmpty
                                ? 'Random'
                                : _selectedCountry,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            BentoSectionLabel(
              LookLocale.t('اسکن عمیق کلادفلر', 'Cloudflare deep scan'),
              icon: Symbols.radar_rounded,
              trailing: BentoTag(
                LookLocale.t('۴ پروتکل', '4 protocols'),
                icon: Symbols.check_circle_rounded,
              ),
            ),
            _DeepScanCard(
              onOpen: (protocol) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CloudflareScannerPage(protocol: protocol),
                ),
              ),
            ),
            const SizedBox(height: 12),
            BentoSurface(
              padding: const EdgeInsets.all(0),
              onTap: data == null ? null : () => _openPool(data),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    BentoIcon(
                      Symbols.format_list_bulleted_rounded,
                      color: scheme.secondary,
                      filled: true,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LookLocale.t(
                              'مرور مخزن آی‌پی',
                              'Browse the IP pool',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            LookLocale.t(
                              'جستجو، انتخاب کشور و ثبت مستقیم Clean IP / Proxy',
                              'Search, choose a country and apply Clean IP / Proxy directly',
                            ),
                            maxLines: 2,
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
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _ScannerFootnote(
              selectedCountry: _selectedCountry,
              onClearCountry: () => setState(() => _selectedCountry = ''),
            ),
          ],
        );
      },
    );
  }
}

class _LiveScanCard extends StatelessWidget {
  final bool scanning;
  final int tested;
  final int total;
  final List<LookScanResult> results;
  final LookScanResult? fastest;
  final VoidCallback? onStart;
  final VoidCallback onStop;
  final VoidCallback? onSettings;
  final VoidCallback? onShowAll;
  final void Function(List<String>)? onClean;
  final void Function(List<String>)? onProxy;

  const _LiveScanCard({
    required this.scanning,
    required this.tested,
    required this.total,
    required this.results,
    required this.fastest,
    required this.onStart,
    required this.onStop,
    required this.onSettings,
    required this.onShowAll,
    required this.onClean,
    required this.onProxy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : tested / total;
    final average = results.isEmpty
        ? null
        : (results.map((entry) => entry.pingMs).reduce((a, b) => a + b) /
                  results.length)
              .round();
    return BentoSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(
                Symbols.speed_rounded,
                color: scheme.primary,
                filled: scanning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LookLocale.t('اسکن زنده سریع', 'Fast live scan'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      LookLocale.t(
                        'پینگ TCP محلی · بدون نیاز به اتصال',
                        'Local TCP ping · works without a tunnel',
                      ),
                      style: TextStyle(
                        fontSize: 9.8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: LookLocale.t('تنظیمات', 'Settings'),
                onPressed: onSettings,
                icon: const Icon(Symbols.tune_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (scanning || total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  LookLocale.t(
                    'بررسی $tested از $total',
                    'Tested $tested of $total',
                  ),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  LookLocale.t(
                    '${results.length} سالم',
                    '${results.length} alive',
                  ),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ],
          if (results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniStat(
                  label: LookLocale.t('سالم', 'Alive'),
                  value: '${results.length}',
                ),
                const SizedBox(width: 7),
                _MiniStat(
                  label: LookLocale.t('میانگین', 'Average'),
                  value: '${average ?? 0} ms',
                ),
                const SizedBox(width: 7),
                _MiniStat(
                  label: LookLocale.t('سریع‌ترین', 'Fastest'),
                  value: '${fastest?.pingMs ?? 0} ms',
                  highlight: true,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Column(
              children: [
                for (final result in results.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _ResultRow(
                      result: result,
                      onClean: () => onClean?.call([result.ip]),
                      onProxy: () => onProxy?.call([result.ip]),
                    ),
                  ),
              ],
            ),
            if (results.length > 3)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onShowAll,
                  icon: const Icon(Symbols.format_list_bulleted_rounded, size: 17),
                  label: Text(
                    LookLocale.t(
                      'مشاهده همه (${results.length})',
                      'View all (${results.length})',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onClean?.call(
                      results.take(8).map((entry) => entry.ip).toList(),
                    ),
                    icon: const Icon(Symbols.bolt_rounded, size: 17),
                    label: Text(LookLocale.t('۸ آی‌پی تمیز', '8 clean IPs')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => onProxy?.call(
                      results.take(5).map((entry) => entry.ip).toList(),
                    ),
                    icon: const Icon(Symbols.dns_rounded, size: 17),
                    label: Text(LookLocale.t('۵ پروکسی', '5 proxies')),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Symbols.network_ping_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      LookLocale.t(
                        'نمونه‌ای از مخزن را با پینگ واقعی TCP ارزیابی کنید؛ نتایج فقط اینجا نمایش داده می‌شوند.',
                        'Probe a sample from the pool with real TCP. Results stay compact here.',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: scanning ? onStop : onStart,
              icon: Icon(
                scanning ? Symbols.stop_rounded : Symbols.play_arrow_rounded,
                size: 19,
              ),
              label: Text(
                scanning
                    ? LookLocale.t('توقف اسکن', 'Stop scan')
                    : LookLocale.t('شروع اسکن زنده', 'Start live scan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: highlight
                ? scheme.primary.withValues(alpha: 0.24)
                : scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: highlight ? scheme.primary : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final LookScanResult result;
  final VoidCallback onClean;
  final VoidCallback onProxy;

  const _ResultRow({
    required this.result,
    required this.onClean,
    required this.onProxy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pingColor = result.pingMs < 180
        ? scheme.primary
        : result.pingMs < 400
        ? scheme.tertiary
        : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        children: [
          Text(
            countryFlag(result.country),
            style: const TextStyle(fontSize: 17),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              result.ip,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: pingColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${result.pingMs} ms',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: pingColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: LookLocale.t('آی‌پی تمیز', 'Clean IP'),
            onPressed: onClean,
            icon: const Icon(Symbols.bolt_rounded, size: 17),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: LookLocale.t('پروکسی', 'Proxy'),
            onPressed: onProxy,
            icon: const Icon(Symbols.dns_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _PoolActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _PoolActionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      onTap: enabled ? onTap : null,
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(icon, color: color, box: 38, size: 19, filled: true),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeepScanCard extends StatelessWidget {
  final ValueChanged<ScanProtocol> onOpen;

  const _DeepScanCard({required this.onOpen});

  static const _protocols = [
    (
      ScanProtocol.warp,
      'WARP',
      'WireGuard · UDP',
      Symbols.shield_rounded,
    ),
    (
      ScanProtocol.masqueH2,
      'MASQUE H2',
      'HTTP/2 tunnel',
      Symbols.swap_horiz_rounded,
    ),
    (
      ScanProtocol.vless,
      'VLESS',
      'TLS REAL tunnel',
      Symbols.bolt_rounded,
    ),
    (
      ScanProtocol.masqueH3,
      'MASQUE H3',
      'QUIC · UDP',
      Symbols.speed_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  Expanded(
                    child: _ProtocolTile(
                      data: _protocols[row * 2 + column],
                      accent: switch (row * 2 + column) {
                        0 => scheme.primary,
                        1 => scheme.tertiary,
                        2 => scheme.secondary,
                        _ => Color.alphaBlend(
                          scheme.primary.withValues(alpha: 0.55),
                          scheme.tertiary.withValues(alpha: 0.45),
                        ),
                      },
                      onTap: () => onOpen(_protocols[row * 2 + column].$1),
                    ),
                  ),
                  if (column == 0) const SizedBox(width: 9),
                ],
              ],
            ),
            if (row == 0) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _ProtocolTile extends StatelessWidget {
  final (ScanProtocol, String, String, IconData) data;
  final Color accent;
  final VoidCallback onTap;

  const _ProtocolTile({
    required this.data,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.08),
        scheme.surfaceContainerHigh,
      ),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BentoIcon(
                    data.$4,
                    box: 34,
                    size: 17,
                    color: accent,
                    filled: true,
                  ),
                  const Spacer(),
                  Icon(
                    Symbols.north_east_rounded,
                    size: 15,
                    color: accent,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                data.$2,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                data.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryFilterBar extends StatelessWidget {
  final List<LookCountryInfo> countries;
  final String selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _CountryFilterBar({
    required this.countries,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = countries.where((country) => country.code == selected).firstOrNull;
    final label = info == null
        ? LookLocale.t('همه کشورها', 'All countries')
        : '${countryFlag(info.code)}  ${info.name}';
    final detail = info == null
        ? LookLocale.t(
            '${countries.length} کشور · اسکن و انتخاب آی‌پی به تفکیک کشور',
            '${countries.length} countries · scan and pick IPs per country',
          )
        : LookLocale.t(
            '${info.count} آی‌پی در مخزن ${info.code}',
            '${info.count} IPs in the ${info.code} pool',
          );
    return BentoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      onTap: disabled ? null : onTap,
      child: Row(
        children: [
          BentoIcon(
            Symbols.public_rounded,
            color: selected.isEmpty ? scheme.onSurfaceVariant : scheme.primary,
            filled: selected.isNotEmpty,
            box: 38,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
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
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Symbols.chevron_left_rounded
                : Symbols.chevron_right_rounded,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _CountryScanSheet extends StatefulWidget {
  final List<LookCountryInfo> countries;
  final String selected;

  const _CountryScanSheet({
    required this.countries,
    required this.selected,
  });

  @override
  State<_CountryScanSheet> createState() => _CountryScanSheetState();
}

class _CountryScanSheetState extends State<_CountryScanSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(String code) => Navigator.of(context).pop(code);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final filtered = widget.countries.where((country) {
      if (query.isEmpty) return true;
      return country.code.toLowerCase().contains(query) ||
          country.name.toLowerCase().contains(query);
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LookLocale.t('اسکن به تفکیک کشور', 'Scan by country'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              LookLocale.t(
                'کشور را انتخاب کنید؛ اسکن زنده و انتخاب خودکار آی‌پی‌ها روی همان کشور اعمال می‌شود.',
                'Pick a country; the live scan and one-tap IP picks use that pool.',
              ),
              style: TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            BentoSearchField(
              controller: _search,
              value: _query,
              hint: LookLocale.t('جستجوی کشور یا کد…', 'Search country or code…'),
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 9),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length + (query.isEmpty ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (query.isEmpty && index == 0) {
                    return _CountryRow(
                      flag: '🌐',
                      title: LookLocale.t('همه کشورها', 'All countries'),
                      subtitle: LookLocale.t(
                        '${widget.countries.length} کشور · بدون فیلتر',
                        '${widget.countries.length} countries · no filter',
                      ),
                      selected: widget.selected.isEmpty,
                      onTap: () => _pick(''),
                    );
                  }
                  final country =
                      filtered[index - (query.isEmpty ? 1 : 0)];
                  return _CountryRow(
                    flag: countryFlag(country.code),
                    title: country.name,
                    subtitle: '${country.code} · ${country.count} IP',
                    selected: widget.selected == country.code,
                    onTap: () => _pick(country.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _CountryRow({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.78)
          : scheme.surfaceContainerHigh.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Symbols.check_circle_rounded, size: 19, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerFootnote extends StatelessWidget {
  final String selectedCountry;
  final VoidCallback onClearCountry;

  const _ScannerFootnote({
    required this.selectedCountry,
    required this.onClearCountry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
      child: Row(
        children: [
          Icon(
            Symbols.info_rounded,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              selectedCountry.isEmpty
                  ? LookLocale.t(
                      'مخزن و اسکنر بدون تغییر در عملکرد قبلی کار می‌کنند؛ لیست کامل فقط هنگام مرور باز می‌شود.',
                      'The pool and scanners keep their original behavior; the full list opens only when browsing.',
                    )
                  : LookLocale.t(
                      'فیلتر کشور فعال است: $selectedCountry',
                      'Country filter active: $selectedCountry',
                    ),
              style: TextStyle(
                fontSize: 9.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (selectedCountry.isNotEmpty)
            TextButton(
              onPressed: onClearCountry,
              child: Text(LookLocale.t('همه', 'All')),
            ),
        ],
      ),
    );
  }
}

class _LiveResultsSheet extends StatelessWidget {
  final List<LookScanResult> results;
  final ValueChanged<List<String>> onClean;
  final ValueChanged<List<String>> onProxy;

  const _LiveResultsSheet({
    required this.results,
    required this.onClean,
    required this.onProxy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _ScannerSheetHeader(
          title: LookLocale.t('نتایج اسکن زنده', 'Live scan results'),
          subtitle: LookLocale.t(
            '${results.length} آی‌پی سالم',
            '${results.length} alive IPs',
          ),
          icon: Symbols.speed_rounded,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _ResultRow(
                  result: result,
                  onClean: () => onClean([result.ip]),
                  onProxy: () => onProxy([result.ip]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onClean(
                    results.take(8).map((entry) => entry.ip).toList(),
                  ),
                  icon: const Icon(Symbols.bolt_rounded, size: 17),
                  label: Text(LookLocale.t('۸ آی‌پی تمیز', '8 clean IPs')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => onProxy(
                    results.take(5).map((entry) => entry.ip).toList(),
                  ),
                  icon: const Icon(Symbols.dns_rounded, size: 17),
                  label: Text(LookLocale.t('۵ پروکسی', '5 proxies')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PoolSheet extends StatefulWidget {
  final LookIpPoolData data;
  final void Function(List<String> ips, String label) onClean;
  final void Function(List<String> ips, String label) onProxy;

  const _PoolSheet({
    required this.data,
    required this.onClean,
    required this.onProxy,
  });

  @override
  State<_PoolSheet> createState() => _PoolSheetState();
}

class _PoolSheetState extends State<_PoolSheet> {
  String _country = '';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = widget.data
        .byCountry(_country)
        .where(
          (entry) =>
              _query.isEmpty ||
              entry.ip.toLowerCase().contains(_query.toLowerCase()) ||
              entry.country.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        _ScannerSheetHeader(
          title: LookLocale.t('مخزن آی‌پی', 'IP pool'),
          subtitle: LookLocale.t(
            '${widget.data.countries.length} کشور · جستجو و انتخاب آی‌پی',
            '${widget.data.countries.length} countries · search and pick an IP',
          ),
          icon: Symbols.format_list_bulleted_rounded,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Symbols.search_rounded, size: 19),
              hintText: LookLocale.t(
                'جستجوی آی‌پی یا کشور…',
                'Search IP or country…',
              ),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ChoiceChip(
                selected: _country.isEmpty,
                visualDensity: VisualDensity.compact,
                label: Text(
                  LookLocale.t('همه', 'All'),
                ),
                onSelected: (_) => setState(() => _country = ''),
              ),
              for (final country in widget.data.countries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 7),
                  child: ChoiceChip(
                    selected: _country == country.code,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${countryFlag(country.code)} ${country.code} (${country.count})',
                    ),
                    onSelected: (_) =>
                        setState(() => _country = country.code),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: BentoSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        countryFlag(item.country),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.ip,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: LookLocale.t('آی‌پی تمیز', 'Clean IP'),
                        onPressed: () =>
                            widget.onClean([item.ip], item.country),
                        icon: const Icon(Symbols.bolt_rounded, size: 18),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: LookLocale.t('پروکسی', 'Proxy'),
                        onPressed: () =>
                            widget.onProxy([item.ip], item.country),
                        icon: Icon(
                          Symbols.dns_rounded,
                          size: 18,
                          color: scheme.tertiary,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: LookLocale.t('کپی', 'Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: item.ip));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                LookLocale.t(
                                  '${item.ip} کپی شد',
                                  '${item.ip} copied',
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Symbols.content_copy_rounded,
                          size: 17,
                        ),
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
  }
}

class _ScannerSheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ScannerSheetHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 10),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 13),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              BentoIcon(icon, filled: true, box: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Symbols.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
