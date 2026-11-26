import 'dart:async';
import 'dart:io';

import 'mili_ip_pool.dart';

/// One live TCP latency probe result from MiliConfig's built-in fast scanner.
class MiliScanResult {
  final String ip;
  final String country;
  final int port;
  final int pingMs;

  const MiliScanResult({
    required this.ip,
    required this.country,
    required this.port,
    required this.pingMs,
  });

  String get endpoint => ip.contains(':') ? '[$ip]:$port' : '$ip:$port';
}

/// Fast, reliable native Dart TCP latency scanner that directly tests IPs from
/// MiliConfig's IP pool and Cloudflare/Mili sources without requiring a deployed Worker.
class MiliLiveScanner {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// Probes [entries] concurrently on [port] with [timeout], yielding live progress updates.
  Stream<({int tested, int total, List<MiliScanResult> results})> scan({
    required List<MiliIpEntry> entries,
    int port = 443,
    int concurrency = 16,
    Duration timeout = const Duration(milliseconds: 1400),
    int maxResults = 30,
  }) async* {
    _cancelled = false;
    final total = entries.length;
    final found = <MiliScanResult>[];
    int tested = 0;

    for (var i = 0; i < total && !_cancelled; i += concurrency) {
      final batch = entries.skip(i).take(concurrency).toList();
      final probes = await Future.wait(
        batch.map((entry) => _probeOne(entry, port, timeout)),
      );
      if (_cancelled) break;
      tested += batch.length;
      for (final r in probes) {
        if (r != null) found.add(r);
      }
      found.sort((a, b) => a.pingMs.compareTo(b.pingMs));
      final snapshot = found.take(maxResults).toList(growable: false);
      yield (tested: tested, total: total, results: snapshot);
    }
  }

  Future<MiliScanResult?> _probeOne(
    MiliIpEntry entry,
    int port,
    Duration timeout,
  ) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(entry.ip, port, timeout: timeout);
      sw.stop();
      return MiliScanResult(
        ip: entry.ip,
        country: entry.country,
        port: port,
        pingMs: sw.elapsedMilliseconds.clamp(1, 9999),
      );
    } catch (_) {
      return null;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }
}
