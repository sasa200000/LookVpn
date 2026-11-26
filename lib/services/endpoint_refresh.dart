import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'look_ip_pool.dart';
import 'look_live_scanner.dart';

/// How an automatic endpoint refresh turned out.
class EndpointRefresh {
  /// The addresses that answered, fastest first.
  final List<String> ips;

  /// How many probes were run, summed over the ports tried.
  final int probed;

  /// The ports that produced at least one live address.
  final Set<int> ports;

  const EndpointRefresh({
    required this.ips,
    required this.probed,
    this.ports = const {},
  });

  bool get foundAnything => ips.isNotEmpty;

  /// What the UI and the log should say about it.
  String get summary => foundAnything
      ? '${ips.length} working address(es) from $probed probes'
      : 'none of $probed probes answered';
}

/// Finds working Cloudflare edge addresses when the ones in the settings have stopped working.
///
/// The worker rung's config already load-balances across every configured clean IP and port, so
/// rotating between them is Xray's job, not the app's. What Xray cannot do is notice that the
/// whole set has gone stale: an address Cloudflare retired, or one this ISP has started
/// null-routing, is dead for every address in the set at once, and balancing across dead
/// addresses only fails faster.
///
/// So this does the one thing the balancer cannot: probe the bundled pool from the phone's own
/// network and hand back addresses that answer *here, now*.
class EndpointRefresher {
  final LookLiveScanner _scanner;

  EndpointRefresher({LookLiveScanner? scanner})
    : _scanner = scanner ?? LookLiveScanner();

  /// Stops an in-flight refresh, e.g. because the user disconnected.
  void cancel() => _scanner.cancel();

  /// Probes a random sample of [pool] on [ports] and returns the fastest live addresses.
  ///
  /// The sample is capped because this runs while the user waits for a connection: probing all
  /// 696 bundled addresses takes minutes on a throttled mobile link. A sample finds a working
  /// edge within a second when the network is merely filtering, and returns nothing quickly
  /// when it is not.
  Future<EndpointRefresh> refresh({
    required List<int> ports,
    int sample = 24,
    int keep = 8,
    int seed = 0,
    Duration timeout = const Duration(milliseconds: 1200),
    List<LookIpEntry>? pool,
  }) async {
    final entries = pool ?? (await LookCatalog.loadIpPool()).ips;
    if (entries.isEmpty || ports.isEmpty) {
      return const EndpointRefresh(ips: [], probed: 0);
    }

    // Shuffle a copy so repeated refreshes explore different addresses.
    final candidates = List<LookIpEntry>.of(entries)..shuffle(Random(seed));
    final picked = candidates.take(sample).toList(growable: false);

    final found = <String>[];
    final foundPorts = <int>{};
    final seen = <String>{};
    var probed = 0;

    for (final port in ports) {
      if (found.length >= keep) break;
      var portProbes = 0;
      await for (final update in _scanner.scan(
        entries: picked,
        port: port,
        concurrency: 16,
        timeout: timeout,
        maxResults: keep,
      )) {
        // The scanner's counter is cumulative within one scan, so keep the latest value.
        portProbes = update.tested;
        for (final result in update.results) {
          if (seen.add(result.ip)) {
            found.add(result.ip);
            foundPorts.add(port);
          }
        }
        if (found.length >= keep) break;
      }
      probed += portProbes;
    }

    return EndpointRefresh(
      ips: found.take(keep).toList(growable: false),
      probed: probed,
      ports: foundPorts,
    );
  }

  /// Runs [refresh] on a background isolate so a probe storm never janks the UI thread.
  ///
  /// Falls back to running inline when the isolate fails to start, which happens on a few
  /// restricted Android builds: a slow refresh beats a refresh that never happens.
  Future<EndpointRefresh> refreshOffThread({
    required List<int> ports,
    int sample = 24,
    int keep = 8,
  }) async {
    try {
      return await Isolate.run(
        () => EndpointRefresher().refresh(
          ports: ports,
          sample: sample,
          keep: keep,
        ),
      );
    } catch (_) {
      return refresh(ports: ports, sample: sample, keep: keep);
    }
  }
}
