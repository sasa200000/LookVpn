import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';
import '../services/local_proxy.dart';
import '../services/my_ip.dart';
import '../services/vpn_channel.dart';
import '../services/xray_config.dart';
import '../state/app_state.dart';
import 'bettbox_widgets.dart';
import 'cf_accounts_page.dart';
import 'chain_proxies_page.dart';
import 'dns_page.dart';
import 'expressive.dart';
import 'format.dart';
import 'fragments_page.dart';
import 'interface_settings_page.dart';
import 'log_page.dart';
import 'look_hub_page.dart';
import 'look_i18n.dart';
import 'noises_page.dart';
import 'per_app_page.dart';
import 'routing_page.dart';
import 'settings_page.dart';
import 'tor_bridges_page.dart';

/// Opens a 92%-height expressive sheet with a rounded, blurred surface.
Future<T?> showBentoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double heightFactor = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    builder: (context) => FractionallySizedBox(
      heightFactor: heightFactor,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: builder(context),
        ),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;

  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 12),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              BentoIcon(icon, filled: true, box: 44),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...actions,
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

// ---------------------------------------------------------------------------
// Speed test
// ---------------------------------------------------------------------------

class _SpeedServer {
  final String name;
  final String description;
  final String downloadUrl;
  final bool supportsUpload;

  const _SpeedServer(
    this.name,
    this.description,
    this.downloadUrl, {
    this.supportsUpload = false,
  });
}

class _SpeedResult {
  final DateTime at;
  final double down;
  final double up;
  final int ping;
  final int jitter;
  final int loss;
  final String server;

  const _SpeedResult({
    required this.at,
    required this.down,
    required this.up,
    required this.ping,
    required this.jitter,
    required this.loss,
    required this.server,
  });

  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'down': down,
    'up': up,
    'ping': ping,
    'jitter': jitter,
    'loss': loss,
    'server': server,
  };

  factory _SpeedResult.fromJson(Map<String, dynamic> json) => _SpeedResult(
    at: DateTime.fromMillisecondsSinceEpoch(
      (json['at'] as num?)?.toInt() ?? 0,
    ),
    down: (json['down'] as num?)?.toDouble() ?? 0,
    up: (json['up'] as num?)?.toDouble() ?? 0,
    ping: (json['ping'] as num?)?.toInt() ?? 0,
    jitter: (json['jitter'] as num?)?.toInt() ?? 0,
    loss: (json['loss'] as num?)?.toInt() ?? 0,
    server: '${json['server'] ?? ''}',
  );
}

Future<void> openSpeedTestSheet(BuildContext context) =>
    showBentoSheet(context: context, builder: (_) => const _SpeedTestSheet());

class _SpeedTestSheet extends StatefulWidget {
  const _SpeedTestSheet();

  @override
  State<_SpeedTestSheet> createState() => _SpeedTestSheetState();
}

class _SpeedTestSheetState extends State<_SpeedTestSheet> {
  static const _servers = [
    _SpeedServer(
      'Cloudflare Edge',
      'Auto · nearest edge',
      'https://speed.cloudflare.com/__down?bytes=15000000',
      supportsUpload: true,
    ),
    _SpeedServer(
      'Hetzner · Nuremberg',
      'Germany · 10 MB',
      'https://speed.hetzner.de/10MB.bin',
    ),
    _SpeedServer(
      'ThinkBroadband · UK',
      'United Kingdom · 10 MB',
      'https://ipv4.download.thinkbroadband.com/10MB.zip',
    ),
  ];

  static const _historyKey = 'dashboard.speed.history.v1';

  int _server = 0;
  bool _running = false;
  String _stage = '';
  double _down = 0;
  double _up = 0;
  int? _ping;
  int _jitter = 0;
  int _loss = 0;
  String? _error;
  final List<double> _samples = [];
  int _revision = 0;
  List<_SpeedResult> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final history = decoded
          .whereType<Map>()
          .map((item) => _SpeedResult.fromJson(item.cast<String, dynamic>()))
          .toList();
      if (mounted) setState(() => _history = history);
    } catch (_) {
      // A corrupt local history must never block running a fresh test.
    }
  }

  Future<void> _saveResult(_SpeedResult result) async {
    final next = [result, ..._history].take(8).toList();
    setState(() => _history = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _run() async {
    if (_running) return;
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _running = true;
      _stage = LookLocale.t('اندازه‌گیری تأخیر…', 'Measuring latency…');
      _down = 0;
      _up = 0;
      _ping = null;
      _jitter = 0;
      _loss = 0;
      _error = null;
      _samples.clear();
      _revision++;
    });

    final client = state.isConnected
        ? proxiedClient(LocalProxy.port)
        : http.Client();
    try {
      final latencies = <int>[];
      var failures = 0;
      for (var i = 0; i < 8; i++) {
        final stopwatch = Stopwatch()..start();
        try {
          await client
              .get(
                Uri.parse(
                  'https://speed.cloudflare.com/__down?bytes=0&t=${DateTime.now().microsecondsSinceEpoch}',
                ),
                headers: const {'Cache-Control': 'no-store'},
              )
              .timeout(const Duration(seconds: 8));
          stopwatch.stop();
          latencies.add(stopwatch.elapsedMilliseconds);
        } catch (_) {
          failures++;
        }
      }
      if (latencies.isNotEmpty) {
        final ping = latencies.reduce((a, b) => a + b) / latencies.length;
        var jitterTotal = 0.0;
        for (var i = 1; i < latencies.length; i++) {
          jitterTotal += (latencies[i] - latencies[i - 1]).abs();
        }
        if (mounted) {
          setState(() {
            _ping = ping.round();
            _jitter = latencies.length > 1
                ? (jitterTotal / (latencies.length - 1)).round()
                : 0;
            _loss = ((failures / 8) * 100).round();
          });
        }
      } else {
        failures = 8;
      }
      if (!mounted) return;

      setState(() => _stage = LookLocale.t('تست دانلود…', 'Testing download…'));
      final downloadStopwatch = Stopwatch()..start();
      final request = http.Request('GET', Uri.parse(_servers[_server].downloadUrl))
        ..headers['Cache-Control'] = 'no-store';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 32));
      var downloaded = 0;
      var lastSampleAt = 0;
      await for (final chunk in response.stream) {
        if (!mounted || !_running) break;
        downloaded += chunk.length;
        final elapsed = downloadStopwatch.elapsedMilliseconds;
        if (elapsed - lastSampleAt >= 250 && elapsed > 0) {
          lastSampleAt = elapsed;
          final mbps = downloaded * 8 / elapsed / 1000;
          if (mounted) {
            setState(() {
              _down = mbps;
              _samples.add(mbps);
              if (_samples.length > 32) _samples.removeAt(0);
              _revision++;
            });
          }
        }
      }
      downloadStopwatch.stop();
      final finalDown = downloadStopwatch.elapsedMilliseconds <= 0
          ? 0.0
          : downloaded * 8 / downloadStopwatch.elapsedMilliseconds / 1000;
      if (mounted) setState(() => _down = finalDown);

      if (_servers[_server].supportsUpload) {
        if (!mounted) return;
        setState(() => _stage = LookLocale.t('تست آپلود…', 'Testing upload…'));
        final payload = Uint8List(4 * 1024 * 1024);
        final uploadStopwatch = Stopwatch()..start();
        final upload = await client
            .post(
              Uri.parse('https://speed.cloudflare.com/__up'),
              headers: const {'Content-Type': 'application/octet-stream'},
              body: payload,
            )
            .timeout(const Duration(seconds: 30));
        uploadStopwatch.stop();
        if (upload.statusCode < 400 && mounted) {
          setState(() {
            _up =
                payload.length *
                8 /
                uploadStopwatch.elapsedMilliseconds /
                1000;
          });
        }
      }

      if (mounted) {
        final result = _SpeedResult(
          at: DateTime.now(),
          down: _down,
          up: _up,
          ping: _ping ?? 0,
          jitter: _jitter,
          loss: _loss,
          server: _servers[_server].name,
        );
        await _saveResult(result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _running = false;
          _stage = '';
        });
      } else {
        messenger.hideCurrentSnackBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gaugeMax = math.max(100.0, _down * 1.25);
    return Column(
      children: [
        _SheetHeader(
          title: LookLocale.t('تست سرعت شبکه', 'Network speed test'),
          subtitle: LookLocale.t(
            'دانلود، آپلود، پینگ، جیتر و پکت‌لاس واقعی',
            'Real download, upload, ping, jitter and packet loss',
          ),
          icon: Symbols.speed_rounded,
          actions: [
            IconButton(
              tooltip: LookLocale.t('تست دوباره', 'Run again'),
              onPressed: _running ? null : _run,
              icon: const Icon(Symbols.refresh_rounded),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              BentoSurface(
                highlight: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LookLocale.t('سرور تست', 'Test server'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _server,
                                  isDense: true,
                                  isExpanded: true,
                                  borderRadius: BorderRadius.circular(18),
                                  items: [
                                    for (var i = 0; i < _servers.length; i++)
                                      DropdownMenuItem(
                                        value: i,
                                        child: Text(
                                          '${_servers[i].name} · ${_servers[i].description}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                  onChanged: _running
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(() => _server = value);
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_ping != null)
                          BentoTag(
                            '${_ping!} ms',
                            icon: Symbols.network_ping_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 174,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 164,
                            height: 164,
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              tween: Tween(
                                begin: 0,
                                end: (_down / gaugeMax).clamp(0.0, 1.0).toDouble(),
                              ),
                              builder: (context, value, _) =>
                                  CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 10,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    color: scheme.primary,
                                  ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.arrow_downward_rounded,
                                color: scheme.primary,
                                size: 22,
                              ),
                              Text(
                                _down.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -1.5,
                                  color: scheme.onSurface,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                'Mbps',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_stage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _stage,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.error,
                          ),
                        ),
                      ),
                    if (_samples.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      BettboxLineChart(
                        values: List<double>.of(_samples),
                        revision: _revision,
                        color: scheme.primary,
                        height: 54,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            icon: Symbols.arrow_upward_rounded,
                            label: LookLocale.t('آپلود', 'Upload'),
                            value: '${_up.toStringAsFixed(1)} Mbps',
                            color: scheme.tertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Symbols.network_ping_rounded,
                            label: 'Ping',
                            value: '${_ping ?? '—'} ms',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Symbols.show_chart_rounded,
                            label: 'Jitter',
                            value: '$_jitter ms',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Symbols.signal_cellular_off_rounded,
                            label: 'Loss',
                            value: '$_loss%',
                            color: _loss > 0 ? scheme.error : null,
                          ),
                        ),
                      ],
                    ),
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
                              ? LookLocale.t('در حال تست…', 'Testing…')
                              : LookLocale.t('شروع تست سرعت', 'Start speed test'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BentoSectionLabel(
                LookLocale.t('تاریخچه تست‌ها', 'Test history'),
                icon: Symbols.history_rounded,
              ),
              if (_history.isEmpty)
                BentoSurface(
                  child: Row(
                    children: [
                      BentoIcon(
                        Symbols.history_toggle_off_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          LookLocale.t(
                            'هنوز تستی ثبت نشده است. اولین تست را اجرا کنید.',
                            'No test recorded yet. Run your first test.',
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                BentoSurface(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < _history.length; i++) ...[
                        _HistoryRow(result: _history[i]),
                        if (i < _history.length - 1)
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.55),
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color ?? scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _SpeedResult result;
  const _HistoryRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = result.at;
    final stamp =
        '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          BentoIcon(
            Symbols.speed_rounded,
            box: 34,
            size: 17,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.down.toStringAsFixed(1)} ↓ · ${result.up.toStringAsFixed(1)} ↑ Mbps',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '${result.server} · ${result.ping} ms · $stamp',
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Core status
// ---------------------------------------------------------------------------

Future<void> openCoreStatusSheet(
  BuildContext context, {
  VoidCallback? onManageNodes,
}) => showBentoSheet(
  context: context,
  builder: (_) => _CoreStatusSheet(onManageNodes: onManageNodes),
);

class _CoreStatusSheet extends StatefulWidget {
  final VoidCallback? onManageNodes;
  const _CoreStatusSheet({this.onManageNodes});

  @override
  State<_CoreStatusSheet> createState() => _CoreStatusSheetState();
}

class _CoreStatusSheetState extends State<_CoreStatusSheet> {
  Timer? _timer;
  int _ticks = 0;
  ({String xray, String psiphon, String tor})? _versions;
  int? _pssKb;
  double? _cpu;
  int? _lastCpuMs;
  int? _lastCpuAt;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
    _sample();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _ticks++);
      if (_ticks.isEven) _sample();
    });
  }

  Future<void> _loadVersions() async {
    try {
      final versions = await VpnChannel.versions();
      if (mounted) setState(() => _versions = versions);
    } catch (_) {
      // Version display is best-effort; status remains usable.
    }
  }

  Future<void> _sample() async {
    try {
      final stats = await VpnChannel.coreProcessStats();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_lastCpuMs != null && _lastCpuAt != null) {
        final cpuDelta = stats.cpuMs - _lastCpuMs!;
        final timeDelta = now - _lastCpuAt!;
        if (timeDelta > 0 && mounted) {
          setState(
            () => _cpu = (cpuDelta / timeDelta * 100)
                .clamp(0.0, 100.0)
                .toDouble(),
          );
        }
      }
      _lastCpuMs = stats.cpuMs;
      _lastCpuAt = now;
      if (mounted) setState(() => _pssKb = stats.pssKb);
    } catch (_) {
      // Older native builds simply show no process metrics.
    }
  }

  Future<void> _clearLogs() async {
    setState(() => _clearing = true);
    try {
      await Future.wait([VpnChannel.clearLog(), VpnChannel.clearCache()]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LookLocale.t('لاگ‌ها و کش موقت پاک شد', 'Logs and temporary cache cleared'),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _copyStatus(AppState state) async {
    final text = [
      'LookVPN core status',
      'state: ${state.status.name}',
      'mode: ${state.mode.name}',
      'exit: ${state.exitNode.name}',
      'xray: ${_versions?.xray ?? 'unknown'}',
      'uptime: ${_uptime(state)}',
      'ram: ${_ramLabel()}',
      'cpu: ${_cpu == null ? '—' : '${_cpu!.toStringAsFixed(1)}%'}',
      'error: ${state.error ?? 'none'}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LookLocale.t('وضعیت کپی شد', 'Status copied'))),
      );
    }
  }

  String _uptime(AppState state) {
    if (state.connectedAt == null) return '—';
    return formatDuration(DateTime.now().difference(state.connectedAt!));
  }

  String _ramLabel() {
    if (_pssKb == null) return '—';
    return '${(_pssKb! / 1024).toStringAsFixed(1)} MB';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final connected = state.isConnected;
    return Column(
      children: [
        _SheetHeader(
          title: LookLocale.t('وضعیت هسته', 'Core status'),
          subtitle: LookLocale.t(
            'نسخه، منابع، آپتایم و کنترل زنده',
            'Version, resources, uptime and live control',
          ),
          icon: Symbols.memory_rounded,
          actions: [
            IconButton(
              tooltip: LookLocale.t('کپی وضعیت', 'Copy status'),
              onPressed: () => _copyStatus(state),
              icon: const Icon(Symbols.content_copy_rounded, size: 19),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              BentoSurface(
                highlight: connected,
                accent: connected ? scheme.primary : scheme.error,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        BentoOrb(
                          connected
                              ? Symbols.verified_user_rounded
                              : Symbols.shield_rounded,
                          size: 58,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connected
                                    ? LookLocale.t('هسته فعال است', 'Core is running')
                                    : LookLocale.t('هسته متوقف است', 'Core is stopped'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                connected
                                    ? _uptime(state)
                                    : (state.error ??
                                          LookLocale.t(
                                            'برای شروع، اتصال را روشن کنید',
                                            'Start a connection to launch the core',
                                          )),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            icon: Symbols.terminal_rounded,
                            label: 'Xray',
                            value: _versions?.xray.isNotEmpty == true
                                ? _versions!.xray
                                : '—',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Symbols.bolt_rounded,
                            label: 'CPU',
                            value: _cpu == null
                                ? '—'
                                : '${_cpu!.toStringAsFixed(1)}%',
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Symbols.memory_rounded,
                            label: 'RAM',
                            value: _ramLabel(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Metric(
                            icon: Symbols.timer_rounded,
                            label: 'Uptime',
                            value: _uptime(state),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BentoSectionLabel(
                LookLocale.t('کنترل و نگهداری', 'Control & maintenance'),
                icon: Symbols.tune_rounded,
              ),
              BentoSurface(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Column(
                  children: [
                    _CoreAction(
                      icon: Symbols.restart_alt_rounded,
                      title: LookLocale.t('راه‌اندازی مجدد هسته', 'Restart core'),
                      subtitle: LookLocale.t(
                        'قطع و اتصال دوباره با همان تنظیمات',
                        'Reconnect with the same configuration',
                      ),
                      onTap: state.isBusy
                          ? null
                          : () async {
                              await state.reconnect();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      LookLocale.t(
                                        'هسته دوباره راه‌اندازی شد',
                                        'Core restarted',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                    _Divider(),
                    _CoreAction(
                      icon: Symbols.delete_sweep_rounded,
                      title: LookLocale.t('پاک‌سازی لاگ و کش', 'Clear logs & cache'),
                      subtitle: LookLocale.t(
                        'آزادسازی فایل‌های موقت بدون قطع اتصال',
                        'Release temporary files without disconnecting',
                      ),
                      onTap: _clearing ? null : _clearLogs,
                      trailing: _clearing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    _Divider(),
                    _CoreAction(
                      icon: Symbols.terminal_rounded,
                      title: LookLocale.t('لاگ زنده', 'Live logs'),
                      subtitle: LookLocale.t(
                        'فیلتر منبع، کپی و پاک‌سازی خطوط',
                        'Source filters, copy and clear lines',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogPage()),
                      ),
                    ),
                    if (widget.onManageNodes != null) ...[
                      _Divider(),
                      _CoreAction(
                        icon: Symbols.hub_rounded,
                        title: LookLocale.t('مدیریت نودها', 'Manage nodes'),
                        subtitle: LookLocale.t(
                          'انتخاب، تست پینگ و تغییر نود فعال',
                          'Select, ping-test and switch the active node',
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onManageNodes!();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
  );
}

class _CoreAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _CoreAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        child: Row(
          children: [
            BentoIcon(icon, box: 38, size: 19),
            const SizedBox(width: 11),
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
            trailing ??
                Icon(
                  Symbols.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 19,
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IP & DNS inspector
// ---------------------------------------------------------------------------

Future<void> openIpDnsSheet(BuildContext context) => showBentoSheet(
  context: context,
  builder: (_) => const _IpDnsSheet(),
);

class _IpDnsSheet extends StatefulWidget {
  const _IpDnsSheet();

  @override
  State<_IpDnsSheet> createState() => _IpDnsSheetState();
}

class _IpDnsSheetState extends State<_IpDnsSheet> {
  bool _loading = true;
  Map<String, dynamic>? _info;
  String? _ipv6;
  String? _error;
  final Map<String, int?> _pings = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final state = AppScope.read(context);
    final client = state.isConnected
        ? proxiedClient(LocalProxy.port)
        : http.Client();
    try {
      final responses = await Future.wait([
        client
            .get(Uri.parse('https://ipinfo.io/json'))
            .timeout(const Duration(seconds: 14)),
        client
            .get(Uri.parse('https://api64.ipify.org?format=json'))
            .timeout(const Duration(seconds: 10))
            .catchError((_) => http.Response('{}', 200)),
      ]);
      if (responses[0].statusCode == 200) {
        _info = jsonDecode(responses[0].body) as Map<String, dynamic>;
      }
      try {
        final v6 = jsonDecode(responses[1].body) as Map<String, dynamic>;
        final ip = '${v6['ip'] ?? ''}';
        _ipv6 = ip.contains(':') ? ip : null;
      } catch (_) {
        _ipv6 = null;
      }
      await _measureDns(client);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _measureDns(http.Client client) async {
    const targets = {
      'Cloudflare': 'https://cloudflare-dns.com/dns-query',
      'Google': 'https://dns.google/resolve',
      'Quad9': 'https://dns.quad9.net:5053/dns-query',
    };
    for (final entry in targets.entries) {
      final stopwatch = Stopwatch()..start();
      try {
        final response = await client
            .get(
              Uri.parse('${entry.value}?name=example.com&type=A'),
              headers: const {'Accept': 'application/dns-json'},
            )
            .timeout(const Duration(seconds: 6));
        stopwatch.stop();
        _pings[entry.key] = response.statusCode == 200
            ? stopwatch.elapsedMilliseconds
            : null;
      } catch (_) {
        _pings[entry.key] = null;
      }
    }
  }

  Future<void> _copy() async {
    final info = _info ?? const {};
    final text = [
      'IP: ${info['ip'] ?? '—'}',
      'IPv6: ${_ipv6 ?? '—'}',
      'Country: ${info['country'] ?? '—'}',
      'City: ${info['city'] ?? '—'}',
      'Region: ${info['region'] ?? '—'}',
      'ISP / ASN: ${info['org'] ?? '—'}',
      'DNS: ${_dnsAddresses(AppScope.read(context)).join(', ')}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LookLocale.t('اطلاعات کپی شد', 'Details copied'))),
      );
    }
  }

  List<String> _dnsAddresses(AppState state) {
    final addresses = <String>[];
    for (final server in state.profile.serverless.dnsSettings.servers) {
      addresses.addAll(server.addresses);
    }
    final local = state.profile.general.localDns;
    if (local.isNotEmpty && !addresses.contains(local)) {
      addresses.insert(0, local);
    }
    return addresses.isEmpty ? ['System / automatic'] : addresses;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final info = _info ?? const <String, dynamic>{};
    final country = '${info['country'] ?? ''}';
    final dnsServers = _dnsAddresses(state);
    final dnsType = state.profile.serverless.dnsSettings.dnsType.toUpperCase();
    final leakSafe =
        state.profile.serverless.dnsSettings.servers.isNotEmpty &&
        state.profile.general.enableFakeDns;

    return Column(
      children: [
        _SheetHeader(
          title: LookLocale.t('آی‌پی و DNS', 'IP & DNS inspector'),
          subtitle: LookLocale.t(
            'خروجی تونل، موقعیت، ISP و سلامت DNS',
            'Tunnel exit, location, ISP and DNS health',
          ),
          icon: Symbols.public_rounded,
          actions: [
            IconButton(
              tooltip: LookLocale.t('کپی', 'Copy'),
              onPressed: _info == null ? null : _copy,
              icon: const Icon(Symbols.content_copy_rounded, size: 19),
            ),
            IconButton(
              tooltip: LookLocale.t('بروزرسانی', 'Refresh'),
              onPressed: _loading ? null : _refresh,
              icon: _loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.refresh_rounded, size: 20),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              BentoSurface(
                highlight: state.isConnected,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                country.isEmpty
                                    ? LookLocale.t('آی‌پی خروج', 'Exit IP')
                                    : '${countryFlag(country)} ${country.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                '${info['ip'] ?? (_loading ? '…' : '—')}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: scheme.primary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        BentoTag(
                          state.isConnected
                              ? LookLocale.t('از تونل', 'Via tunnel')
                              : LookLocale.t('مستقیم', 'Direct'),
                          icon: state.isConnected
                              ? Symbols.vpn_lock_rounded
                              : Symbols.language_rounded,
                          filled: state.isConnected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _InfoRow(
                      icon: Symbols.location_city_rounded,
                      label: LookLocale.t('شهر / منطقه', 'City / region'),
                      value:
                          '${info['city'] ?? '—'}${info['region'] != null ? ' · ${info['region']}' : ''}',
                    ),
                    _InfoRow(
                      icon: Symbols.router_rounded,
                      label: 'ISP / ASN',
                      value: '${info['org'] ?? '—'}',
                    ),
                    _InfoRow(
                      icon: Symbols.counter_6_rounded,
                      label: 'IPv6',
                      value: _ipv6 ?? LookLocale.t('در دسترس نیست', 'Not available'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(fontSize: 10.5, color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BentoSectionLabel(
                LookLocale.t('سرورهای DNS فعال', 'Active DNS servers'),
                icon: Symbols.dns_rounded,
                trailing: BentoTag(dnsType),
              ),
              BentoSurface(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    for (var i = 0; i < dnsServers.length; i++) ...[
                      Row(
                        children: [
                          BentoIcon(
                            Symbols.dns_rounded,
                            box: 34,
                            size: 16,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dnsServers[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (i < dnsServers.length - 1) const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 13),
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        BentoIcon(
                          leakSafe
                              ? Symbols.verified_user_rounded
                              : Symbols.shield_rounded,
                          box: 34,
                          size: 17,
                          color: leakSafe ? scheme.primary : scheme.tertiary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LookLocale.t('بررسی پیکربندی DNS', 'DNS configuration check'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                leakSafe
                                    ? LookLocale.t(
                                        'DNS رمزنگاری‌شده و Fake DNS فعال است',
                                        'Encrypted DNS and Fake DNS are active',
                                      )
                                    : LookLocale.t(
                                        'برای محافظت بیشتر، DNS رمزنگاری‌شده و Fake DNS را فعال کنید',
                                        'Enable encrypted DNS and Fake DNS for stronger protection',
                                      ),
                                style: TextStyle(
                                  fontSize: 9.8,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        BentoTag(
                          leakSafe
                              ? LookLocale.t('سالم', 'Healthy')
                              : LookLocale.t('بررسی', 'Review'),
                          icon: leakSafe
                              ? Symbols.check_circle_rounded
                              : Symbols.warning_rounded,
                          color: leakSafe ? scheme.primary : scheme.tertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BentoSectionLabel(
                LookLocale.t('پینگ DNS', 'DNS latency'),
                icon: Symbols.network_ping_rounded,
              ),
              Row(
                children: [
                  for (final entry in _pings.entries) ...[
                    Expanded(
                      child: BentoSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Symbols.dns_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.value == null ? '—' : '${entry.value} ms',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: entry.value != null
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (entry.key != _pings.keys.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DnsPage()),
                      ),
                      icon: const Icon(Symbols.dns_rounded, size: 17),
                      label: Text(LookLocale.t('مدیریت DNS', 'Manage DNS')),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _refresh,
                      icon: const Icon(Symbols.refresh_rounded, size: 17),
                      label: Text(LookLocale.t('بروزرسانی', 'Refresh')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Configurable quick settings
// ---------------------------------------------------------------------------

class QuickSettingAction {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool toggle;

  const QuickSettingAction({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.toggle = false,
  });

  String get localizedTitle => switch (id) {
    'dpi' => LookLocale.t(title, 'Anti-DPI'),
    'ipv6' => 'IPv6',
    'fakedns' => LookLocale.t(title, 'Fake DNS'),
    'mode' => LookLocale.t(title, 'Tunnel mode'),
    'routing' => LookLocale.t(title, 'Routing'),
    'dns' => 'DNS',
    'fragment' => LookLocale.t(title, 'Fragment'),
    'noise' => LookLocale.t(title, 'UDP noise'),
    'perapp' => 'Per-App',
    'worker' => 'Worker',
    'lan' => LookLocale.t(title, 'LAN sharing'),
    'chain' => LookLocale.t(title, 'Chain proxies'),
    'cloudflare' => LookLocale.t(title, 'Cloudflare'),
    'tor' => LookLocale.t(title, 'Tor bridges'),
    'hub' => 'Look Hub',
    'logs' => LookLocale.t(title, 'Live logs'),
    'appearance' => LookLocale.t(title, 'Appearance'),
    _ => title,
  };
}

class QuickSettingsStore {
  QuickSettingsStore._();

  static const key = 'dashboard.quick.settings.v1';
  static const defaults = ['dpi', 'ipv6', 'fakedns', 'mode'];
  static final ValueNotifier<List<String>> selected = ValueNotifier(defaults);
  static bool _loaded = false;

  static const actions = <QuickSettingAction>[
    QuickSettingAction(
      id: 'dpi',
      icon: Symbols.security_rounded,
      title: 'ضد DPI',
      subtitle: 'Fragment / WARP OBF',
      toggle: true,
    ),
    QuickSettingAction(
      id: 'ipv6',
      icon: Symbols.counter_6_rounded,
      title: 'IPv6',
      subtitle: 'شبکه خروجی',
      toggle: true,
    ),
    QuickSettingAction(
      id: 'fakedns',
      icon: Symbols.dns_rounded,
      title: 'DNS فیک',
      subtitle: 'پاسخ محلی سریع',
      toggle: true,
    ),
    QuickSettingAction(
      id: 'mode',
      icon: Symbols.vpn_lock_rounded,
      title: 'حالت تونل',
      subtitle: 'VPN / Proxy',
      toggle: true,
    ),
    QuickSettingAction(
      id: 'routing',
      icon: Symbols.alt_route_rounded,
      title: 'مسیریابی',
      subtitle: 'عبور ایران و بلاک',
    ),
    QuickSettingAction(
      id: 'dns',
      icon: Symbols.dns_rounded,
      title: 'DNS',
      subtitle: 'DoH / DoQ',
    ),
    QuickSettingAction(
      id: 'fragment',
      icon: Symbols.broken_image_rounded,
      title: 'فرگمنت',
      subtitle: 'تنظیمات DPI',
    ),
    QuickSettingAction(
      id: 'noise',
      icon: Symbols.graphic_eq_rounded,
      title: 'نویز UDP',
      subtitle: 'WARP / MASQUE',
    ),
    QuickSettingAction(
      id: 'perapp',
      icon: Symbols.apps_rounded,
      title: 'Per-App',
      subtitle: 'تفکیک برنامه‌ها',
    ),
    QuickSettingAction(
      id: 'worker',
      icon: Symbols.deployed_code_rounded,
      title: 'Worker',
      subtitle: 'تنظیمات اتصال',
    ),
    QuickSettingAction(
      id: 'lan',
      icon: Symbols.lan_rounded,
      title: 'شبکه و LAN',
      subtitle: 'اشتراک و پورت‌ها',
    ),
    QuickSettingAction(
      id: 'chain',
      icon: Symbols.link_rounded,
      title: 'زنجیره پروکسی',
      subtitle: 'VLESS / WG / SS',
    ),
    QuickSettingAction(
      id: 'cloudflare',
      icon: Symbols.cloud_rounded,
      title: 'کلادفلر',
      subtitle: 'حساب‌ها و ورکرها',
    ),
    QuickSettingAction(
      id: 'tor',
      icon: Symbols.vpn_key_rounded,
      title: 'پل تور',
      subtitle: 'Snowflake / WebTunnel',
    ),
    QuickSettingAction(
      id: 'hub',
      icon: Symbols.hub_rounded,
      title: 'Look Hub',
      subtitle: 'آی‌پی و پریست',
    ),
    QuickSettingAction(
      id: 'logs',
      icon: Symbols.terminal_rounded,
      title: 'لاگ زنده',
      subtitle: 'خروجی هسته',
    ),
    QuickSettingAction(
      id: 'appearance',
      icon: Symbols.palette_rounded,
      title: 'ظاهر',
      subtitle: 'رنگ و حرکت',
    ),
  ];

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key);
    if (saved != null) {
      selected.value = saved
          .where((id) => actions.any((a) => a.id == id))
          .toList();
    }
  }

  static Future<void> save(List<String> ids) async {
    selected.value = List.unmodifiable(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids);
  }

  static QuickSettingAction? action(String id) {
    for (final action in actions) {
      if (action.id == id) return action;
    }
    return null;
  }
}

Future<void> openQuickSettingsSheet(BuildContext context) => showBentoSheet(
  context: context,
  builder: (_) => const _QuickSettingsSheet(),
);

class _QuickSettingsSheet extends StatefulWidget {
  const _QuickSettingsSheet();

  @override
  State<_QuickSettingsSheet> createState() => _QuickSettingsSheetState();
}

class _QuickSettingsSheetState extends State<_QuickSettingsSheet> {
  @override
  void initState() {
    super.initState();
    QuickSettingsStore.load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: QuickSettingsStore.selected,
      builder: (context, selected, _) {
        final available = QuickSettingsStore.actions
            .where((action) => !selected.contains(action.id))
            .toList();
        return Column(
          children: [
            _SheetHeader(
              title: LookLocale.t('تنظیمات سریع', 'Quick settings'),
              subtitle: LookLocale.t(
                'انتخاب، حذف و مرتب‌سازی کنترل‌های داشبورد',
                'Choose, remove and reorder dashboard controls',
              ),
              icon: Symbols.bolt_rounded,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  BentoSurface(
                    highlight: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Row(
                      children: [
                        BentoIcon(
                          Symbols.dashboard_customize_rounded,
                          filled: true,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            LookLocale.t(
                              'کارت «تنظیمات سریع» داشبورد همین موارد را نشان می‌دهد. برای مرتب‌سازی، دسته را بکشید.',
                              'The dashboard quick-settings card mirrors this list. Drag a row to reorder.',
                            ),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  BentoSectionLabel(
                    LookLocale.t('انتخاب‌شده‌ها', 'Selected'),
                    icon: Symbols.checklist_rounded,
                    trailing: BentoTag('${selected.length}'),
                  ),
                  if (selected.isEmpty)
                    BentoSurface(
                      child: Text(
                        LookLocale.t(
                          'هنوز گزینه‌ای انتخاب نشده است.',
                          'Nothing selected yet.',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: selected.length,
                      onReorder: (oldIndex, newIndex) {
                        final next = List<String>.of(selected);
                        if (newIndex > oldIndex) newIndex--;
                        final moved = next.removeAt(oldIndex);
                        next.insert(newIndex, moved);
                        HapticFeedback.selectionClick();
                        QuickSettingsStore.save(next);
                      },
                      itemBuilder: (context, index) {
                        final action = QuickSettingsStore.action(selected[index]);
                        if (action == null) return const SizedBox.shrink();
                        final value = _toggleValue(state, action.id);
                        return Padding(
                          key: ValueKey('selected-${action.id}'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BentoSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 10,
                                    ),
                                    child: Icon(
                                      Symbols.drag_indicator_rounded,
                                      size: 20,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                BentoIcon(
                                  action.icon,
                                  box: 36,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action.localizedTitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        action.subtitle,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (action.toggle)
                                  Switch(
                                    value: value,
                                    onChanged: (on) =>
                                        _setToggle(state, action.id, on),
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: LookLocale.t('حذف', 'Remove'),
                                  onPressed: () {
                                    final next = List<String>.of(selected)
                                      ..remove(action.id);
                                    QuickSettingsStore.save(next);
                                  },
                                  icon: const Icon(
                                    Symbols.close_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 4),
                  BentoSectionLabel(
                    LookLocale.t('افزودن گزینه', 'Add a control'),
                    icon: Symbols.add_circle_rounded,
                  ),
                  if (available.isEmpty)
                    BentoSurface(
                      child: Text(
                        LookLocale.t(
                          'همه گزینه‌ها به داشبورد اضافه شده‌اند.',
                          'Every control is already on the dashboard.',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final action in available)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BentoSurface(
                          onTap: () {
                            final next = [...selected, action.id];
                            HapticFeedback.selectionClick();
                            QuickSettingsStore.save(next);
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              BentoIcon(
                                action.icon,
                                box: 36,
                                size: 18,
                                color: scheme.tertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action.localizedTitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      action.subtitle,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Symbols.add_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      QuickSettingsStore.save(List.of(QuickSettingsStore.defaults));
                    },
                    icon: const Icon(Symbols.restart_alt_rounded, size: 18),
                    label: Text(
                      LookLocale.t('بازگردانی پیش‌فرض', 'Restore defaults'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _toggleValue(AppState state, String id) => switch (id) {
    'dpi' => state.variant != ConnectionVariant.normal,
    'ipv6' => state.profile.general.enableIpv6,
    'fakedns' => state.readBool('general.enableFakeDns'),
    'mode' => state.device.appMode == AppMode.vpn,
    _ => false,
  };

  void _setToggle(AppState state, String id, bool on) {
    switch (id) {
      case 'dpi':
        if (state.mode == ConnectionMode.warp) {
          state.setVariant(
            on ? ConnectionVariant.obfuscated : ConnectionVariant.normal,
          );
        } else {
          state.setVariant(
            on ? ConnectionVariant.fragment : ConnectionVariant.normal,
          );
        }
        break;
      case 'ipv6':
        state.write('general.enableIpv6', on);
        break;
      case 'fakedns':
        state.write('general.enableFakeDns', on);
        break;
      case 'mode':
        if (!state.isBusy) {
          state.setAppMode(on ? AppMode.vpn : AppMode.proxy);
        }
        break;
    }
  }
}

/// Runs a selected quick control from either the dashboard card or a chip.
Future<void> runQuickSetting(
  BuildContext context,
  String id,
  AppState state,
) async {
  switch (id) {
    case 'dpi':
      final on = state.variant == ConnectionVariant.normal;
      state.setVariant(
        state.mode == ConnectionMode.warp
            ? (on ? ConnectionVariant.obfuscated : ConnectionVariant.normal)
            : (on ? ConnectionVariant.fragment : ConnectionVariant.normal),
      );
      break;
    case 'ipv6':
      state.write('general.enableIpv6', !state.profile.general.enableIpv6);
      break;
    case 'fakedns':
      state.write(
        'general.enableFakeDns',
        !state.readBool('general.enableFakeDns'),
      );
      break;
    case 'mode':
      if (!state.isBusy) {
        state.setAppMode(
          state.device.appMode == AppMode.vpn ? AppMode.proxy : AppMode.vpn,
        );
      }
      break;
    case 'lan':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      break;
    case 'routing':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RoutingHubPage()),
      );
      break;
    case 'dns':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DnsPage()),
      );
      break;
    case 'fragment':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FragmentsPage()),
      );
      break;
    case 'noise':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NoisesPage()),
      );
      break;
    case 'perapp':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PerAppPage()),
      );
      break;
    case 'worker':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      break;
    case 'chain':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChainProxiesPage()),
      );
      break;
    case 'cloudflare':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CfAccountsPage()),
      );
      break;
    case 'tor':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TorBridgesPage()),
      );
      break;
    case 'hub':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LookHubPage()),
      );
      break;
    case 'logs':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LogPage()),
      );
      break;
    case 'appearance':
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InterfaceSettingsPage()),
      );
      break;
  }
}
