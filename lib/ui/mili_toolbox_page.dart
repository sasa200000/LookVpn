import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../services/local_proxy.dart';
import '../services/my_ip.dart';
import '../state/app_state.dart';
import 'bettbox_widgets.dart';
import 'expressive.dart';
import 'format.dart';
import 'mili_i18n.dart';

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Bettbox-style Network Toolbox Hub:
/// 1) Speed Test (real download throughput + latency)
/// 2) Media & AI Unlock Checker (ChatGPT, Claude, YouTube, Netflix, Spotify, GitHub, Cloudflare)
/// 3) IP Lookup (IP, Country, City, ISP, ASN via active tunnel)
/// 4) Local Ping Tool (multi-probe TCP latency + live Bezier chart)
/// 5) DNS Query Tool (live DoH A / AAAA / CNAME / TXT / MX lookup)
class MiliToolboxPage extends StatelessWidget {
  final int initialTool;
  const MiliToolboxPage({super.key, this.initialTool = 0});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 5,
      initialIndex: initialTool.clamp(0, 4),
      child: Scaffold(
        appBar: ExpressiveSubpageHeader(
          title: MiliLocale.t('جعبه‌ابزار شبکه', 'Network Toolbox'),
          subtitle: MiliLocale.t(
            'سرعت، بازگشایی سرویس، آی‌پی، پینگ و DNS',
            'Speed, unlock checks, IP, ping and DNS',
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
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
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
                          icon: const Icon(Symbols.speed_rounded, size: 17),
                          text: MiliLocale.t('تست سرعت', 'Speed'),
                        ),
                        Tab(
                          height: 46,
                          icon: const Icon(Symbols.verified_rounded, size: 17),
                          text: MiliLocale.t('بازگشایی', 'Unlock'),
                        ),
                        Tab(
                          height: 46,
                          icon: const Icon(Symbols.public_rounded, size: 17),
                          text: MiliLocale.t('آی‌پی', 'IP'),
                        ),
                        Tab(
                          height: 46,
                          icon: const Icon(
                            Symbols.network_ping_rounded,
                            size: 17,
                          ),
                          text: MiliLocale.t('پینگ', 'Ping'),
                        ),
                        Tab(
                          height: 46,
                          icon: const Icon(Symbols.dns_rounded, size: 17),
                          text: MiliLocale.t('DNS', 'DNS'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: const [
                    _SpeedTestTool(),
                    _MediaUnlockTool(),
                    _IpLookupTool(),
                    _LocalPingTool(),
                    _DnsQueryTool(),
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

http.Client _clientForState(BuildContext context) {
  final state = AppScope.read(context);
  return state.isConnected ? proxiedClient(LocalProxy.port) : http.Client();
}

// ---------------------------------------------------------------------------
// 1. Real Speed Test Tool
// ---------------------------------------------------------------------------

class _SpeedTestTool extends StatefulWidget {
  const _SpeedTestTool();

  @override
  State<_SpeedTestTool> createState() => _SpeedTestToolState();
}

class _SpeedTestToolState extends State<_SpeedTestTool> {
  bool _running = false;
  double _mbps = 0;
  int? _latencyMs;
  int _downloadedBytes = 0;
  String? _error;
  final List<double> _samples = List<double>.filled(16, 0, growable: true);
  int _rev = 0;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _mbps = 0;
      _latencyMs = null;
      _downloadedBytes = 0;
      _error = null;
      _samples.fillRange(0, _samples.length, 0);
      _rev++;
    });
    final client = _clientForState(context);
    try {
      // 1. Measure HTTP latency
      final pingSw = Stopwatch()..start();
      await client
          .get(Uri.parse('https://speed.cloudflare.com/__down?bytes=0'))
          .timeout(const Duration(seconds: 10));
      pingSw.stop();
      if (mounted) setState(() => _latencyMs = pingSw.elapsedMilliseconds);

      // 2. Measure download throughput (10 MB Cloudflare speed endpoint)
      final req = http.Request(
        'GET',
        Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000'),
      );
      final resp = await client.send(req).timeout(const Duration(seconds: 25));
      final sw = Stopwatch()..start();
      int bytes = 0;
      int lastMarkMs = 0;
      await for (final chunk in resp.stream) {
        if (!mounted || !_running) break;
        bytes += chunk.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - lastMarkMs >= 200 && ms > 0) {
          lastMarkMs = ms;
          final curMbps = (bytes * 8) / (ms * 1000.0);
          _samples.add(curMbps * 1024);
          if (_samples.length > 20) _samples.removeAt(0);
          setState(() {
            _downloadedBytes = bytes;
            _mbps = curMbps;
            _rev++;
          });
        }
      }
      sw.stop();
      if (mounted && sw.elapsedMilliseconds > 0) {
        setState(() {
          _downloadedBytes = bytes;
          _mbps = (bytes * 8) / (sw.elapsedMilliseconds * 1000.0);
          _rev++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BettboxTileCard(
          title: MiliLocale.t('تست سرعت دانلود (Cloudflare)', 'Download Speed Test'),
          icon: Symbols.speed_rounded,
          watermarkIcon: Symbols.speed_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _mbps.toStringAsFixed(1),
                    style: _tabular.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mbps',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (_latencyMs != null)
                    BettboxChip(
                      icon: Symbols.timer_rounded,
                      label: '${_latencyMs} ms',
                      active: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              BettboxLineChart(
                values: List<double>.of(_samples),
                revision: _rev,
                color: scheme.primary,
                height: 70,
              ),
              const SizedBox(height: 12),
              Text(
                MiliLocale.t(
                  'داده دریافت‌شده: ${formatBytes(_downloadedBytes)}',
                  'Downloaded: ${formatBytes(_downloadedBytes)}',
                ),
                style: _tabular.copyWith(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.play_arrow_rounded),
                  label: Text(
                    _running
                        ? MiliLocale.t('در حال اندازه‌گیری…', 'Testing…')
                        : MiliLocale.t('شروع تست سرعت', 'Start Speed Test'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Media & AI Unlock Checker
// ---------------------------------------------------------------------------

class _UnlockTarget {
  final String name;
  final String url;
  const _UnlockTarget(this.name, this.url);
}

class _MediaUnlockTool extends StatefulWidget {
  const _MediaUnlockTool();

  @override
  State<_MediaUnlockTool> createState() => _MediaUnlockToolState();
}

class _MediaUnlockToolState extends State<_MediaUnlockTool> {
  static const _targets = [
    _UnlockTarget('ChatGPT / OpenAI', 'https://chatgpt.com/'),
    _UnlockTarget('Claude AI', 'https://claude.ai/'),
    _UnlockTarget('Google Gemini', 'https://gemini.google.com/'),
    _UnlockTarget('YouTube', 'https://www.youtube.com/generate_204'),
    _UnlockTarget('Netflix', 'https://www.netflix.com/title/80018499'),
    _UnlockTarget('Spotify', 'https://open.spotify.com/'),
    _UnlockTarget('GitHub', 'https://api.github.com/zen'),
    _UnlockTarget('Telegram Web', 'https://web.telegram.org/'),
  ];

  bool _running = false;
  final Map<String, ({bool ok, int ms, String detail})> _results = {};

  Future<void> _checkAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    final client = _clientForState(context);
    try {
      await Future.wait(
        _targets.map((t) async {
          final sw = Stopwatch()..start();
          try {
            final res = await client
                .get(Uri.parse(t.url))
                .timeout(const Duration(seconds: 10));
            sw.stop();
            final ok = res.statusCode >= 200 && res.statusCode < 403;
            if (mounted) {
              setState(() {
                _results[t.name] = (
                  ok: ok,
                  ms: sw.elapsedMilliseconds,
                  detail: 'HTTP ${res.statusCode}',
                );
              });
            }
          } catch (_) {
            sw.stop();
            if (mounted) {
              setState(() {
                _results[t.name] = (
                  ok: false,
                  ms: sw.elapsedMilliseconds,
                  detail: MiliLocale.t('عدم دسترسی', 'Blocked / Timeout'),
                );
              });
            }
          }
        }),
      );
    } finally {
      client.close();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BettboxTileCard(
          title: MiliLocale.t('بررسی بازگشایی سرویس‌ها و هوش مصنوعی', 'Media & AI Unlock Test'),
          icon: Symbols.verified_rounded,
          actions: [
            FilledButton.tonal(
              onPressed: _running ? null : _checkAll,
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(
                _running
                    ? MiliLocale.t('در حال تست…', 'Checking…')
                    : MiliLocale.t('بررسی همه', 'Check All'),
              ),
            ),
          ],
          child: Column(
            children: [
              for (final t in _targets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.surfaceContainerHigh,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_results.containsKey(t.name)) ...[
                          Text(
                            '${_results[t.name]!.ms} ms · ${_results[t.name]!.detail}',
                            style: _tabular.copyWith(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _results[t.name]!.ok
                                ? Symbols.check_circle_rounded
                                : Symbols.cancel_rounded,
                            size: 19,
                            color: _results[t.name]!.ok
                                ? scheme.primary
                                : scheme.error,
                          ),
                        ] else
                          Text(
                            '—',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. IP Lookup & Geolocation Inspector
// ---------------------------------------------------------------------------

class _IpLookupTool extends StatefulWidget {
  const _IpLookupTool();

  @override
  State<_IpLookupTool> createState() => _IpLookupToolState();
}

class _IpLookupToolState extends State<_IpLookupTool> {
  bool _loading = false;
  Map<String, dynamic>? _info;
  String? _error;

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = _clientForState(context);
    try {
      final res = await client
          .get(Uri.parse('https://ipinfo.io/json'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (mounted) setState(() => _info = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cc = '${_info?['country'] ?? ''}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BettboxTileCard(
          title: MiliLocale.t('مشخصات آی‌پی و موقعیت جغرافیایی', 'IP & Geolocation'),
          icon: Symbols.public_rounded,
          watermarkEmoji: cc.isNotEmpty ? countryFlag(cc) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_info != null) ...[
                _KvRow('IP', '${_info!['ip'] ?? '—'}', mono: true),
                _KvRow(
                  MiliLocale.t('کشور', 'Country'),
                  '${countryFlag(cc)} $cc',
                ),
                _KvRow(MiliLocale.t('شهر', 'City'), '${_info!['city'] ?? '—'}'),
                _KvRow(MiliLocale.t('منطقه', 'Region'), '${_info!['region'] ?? '—'}'),
                _KvRow('ISP / ASN', '${_info!['org'] ?? '—'}'),
                _KvRow(MiliLocale.t('منطقه زمانی', 'Timezone'), '${_info!['timezone'] ?? '—'}'),
                const SizedBox(height: 12),
              ] else if (_error != null) ...[
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _lookup,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.search_rounded),
                  label: Text(MiliLocale.t('بررسی آی‌پی فعلی', 'Inspect Current IP')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Local TCP Ping Tool with Live Bezier Sparkline
// ---------------------------------------------------------------------------

class _LocalPingTool extends StatefulWidget {
  const _LocalPingTool();

  @override
  State<_LocalPingTool> createState() => _LocalPingToolState();
}

class _LocalPingToolState extends State<_LocalPingTool> {
  final _hostCtrl = TextEditingController(text: '1.1.1.1');
  final _portCtrl = TextEditingController(text: '443');
  bool _running = false;
  final List<double> _pings = [];
  int _failed = 0;
  int _rev = 0;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _startPing() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 443;
    if (host.isEmpty) return;
    setState(() {
      _running = true;
      _pings.clear();
      _failed = 0;
      _rev++;
    });
    for (int i = 0; i < 10 && _running && mounted; i++) {
      final sw = Stopwatch()..start();
      Socket? s;
      try {
        s = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
        sw.stop();
        if (mounted) {
          setState(() {
            _pings.add(sw.elapsedMilliseconds.toDouble());
            _rev++;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _failed++);
      } finally {
        s?.destroy();
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final avg = _pings.isEmpty
        ? 0
        : (_pings.reduce((a, b) => a + b) / _pings.length).round();
    final minMs = _pings.isEmpty ? 0 : _pings.reduce((a, b) => a < b ? a : b).round();
    final maxMs = _pings.isEmpty ? 0 : _pings.reduce((a, b) => a > b ? a : b).round();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BettboxTileCard(
          title: MiliLocale.t('تست پینگ TCP محلی', 'Local TCP Ping'),
          icon: Symbols.network_ping_rounded,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hostCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: MiliLocale.t('آدرس یا دامنه', 'Host / IP'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: MiliLocale.t('پورت', 'Port'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_pings.isNotEmpty) ...[
                BettboxLineChart(
                  values: List<double>.of(_pings),
                  revision: _rev,
                  color: avg < 180 ? scheme.primary : scheme.tertiary,
                  height: 60,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatMini('Min', '$minMs ms'),
                    _StatMini('Avg', '$avg ms'),
                    _StatMini('Max', '$maxMs ms'),
                    _StatMini('Loss', '$_failed'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? () => setState(() => _running = false) : _startPing,
                  icon: Icon(_running ? Symbols.stop_rounded : Symbols.play_arrow_rounded),
                  label: Text(
                    _running
                        ? MiliLocale.t('توقف', 'Stop')
                        : MiliLocale.t('شروع پینگ (۱۰ بسته)', 'Run 10 Probes'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. DoH DNS Query Tool
// ---------------------------------------------------------------------------

class _DnsQueryTool extends StatefulWidget {
  const _DnsQueryTool();

  @override
  State<_DnsQueryTool> createState() => _DnsQueryToolState();
}

class _DnsQueryToolState extends State<_DnsQueryTool> {
  final _domainCtrl = TextEditingController(text: 'cloudflare.com');
  String _type = 'A';
  bool _loading = false;
  List<String> _answers = const [];
  String? _error;

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    final domain = _domainCtrl.text.trim();
    if (domain.isEmpty) return;
    setState(() {
      _loading = true;
      _answers = const [];
      _error = null;
    });
    final client = _clientForState(context);
    try {
      final uri = Uri.parse(
        'https://cloudflare-dns.com/dns-query?name=${Uri.encodeQueryComponent(domain)}&type=$_type',
      );
      final res = await client
          .get(uri, headers: {'Accept': 'application/dns-json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final ans = ((json['Answer'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => '${e['data']} (TTL ${e['TTL']}s)')
          .toList();
      if (mounted) setState(() => _answers = ans);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BettboxTileCard(
          title: MiliLocale.t('پرس‌وجوی DNS امن (DoH)', 'Encrypted DNS Query (DoH)'),
          icon: Symbols.dns_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _domainCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: MiliLocale.t('نام دامنه', 'Domain'),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in const ['A', 'AAAA', 'CNAME', 'TXT', 'MX'])
                    ChoiceChip(
                      selected: _type == t,
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _query,
                  icon: const Icon(Symbols.search_rounded),
                  label: Text(MiliLocale.t('استعلام رکوردها', 'Query Records')),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
              ],
              if (_answers.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final a in _answers)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      a,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.5,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Symbols.content_copy_rounded, size: 17),
                      onPressed: () => Clipboard.setData(ClipboardData(text: a)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  final String k;
  final String v;
  final bool mono;
  const _KvRow(this.k, this.v, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(k, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: mono ? 'JetBrainsMono' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  const _StatMini(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: _tabular.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
