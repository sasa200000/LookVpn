import 'package:flutter_test/flutter_test.dart';
import 'package:look_vpn/services/anti_filter.dart';
import 'package:look_vpn/services/endpoint_refresh.dart';
import 'package:look_vpn/services/look_ip_pool.dart';
import 'package:look_vpn/services/look_live_scanner.dart';

/// A scanner that answers for a fixed set of addresses, so refresh logic can be tested without
/// opening a socket.
class _FakeScanner extends LookLiveScanner {
  final Set<String> alive;
  final Map<String, int> latency;

  _FakeScanner(this.alive, {this.latency = const {}});

  @override
  Stream<({int tested, int total, List<LookScanResult> results})> scan({
    required List<LookIpEntry> entries,
    int port = 443,
    int concurrency = 16,
    Duration timeout = const Duration(milliseconds: 1400),
    int maxResults = 30,
  }) async* {
    final found = <LookScanResult>[];
    for (final entry in entries) {
      if (alive.contains(entry.ip)) {
        found.add(
          LookScanResult(
            ip: entry.ip,
            country: entry.country,
            port: port,
            pingMs: latency[entry.ip] ?? 100,
          ),
        );
      }
    }
    found.sort((a, b) => a.pingMs.compareTo(b.pingMs));
    yield (tested: entries.length, total: entries.length, results: found);
  }
}

List<LookIpEntry> _pool(List<String> ips) => [
  for (final ip in ips) LookIpEntry(ip: ip, country: 'DE'),
];

void main() {
  group('EndpointRefresher', () {
    test('returns only the addresses that answered, fastest first', () async {
      final refresher = EndpointRefresher(
        scanner: _FakeScanner(
          {'1.1.1.1', '2.2.2.2'},
          latency: {'1.1.1.1': 240, '2.2.2.2': 80},
        ),
      );
      final result = await refresher.refresh(
        ports: const [443],
        sample: 10,
        keep: 8,
        pool: _pool(['1.1.1.1', '2.2.2.2', '3.3.3.3']),
      );
      expect(result.ips, ['2.2.2.2', '1.1.1.1']);
      expect(result.probed, 3);
      expect(result.ports, {443});
      expect(result.foundAnything, isTrue);
    });

    test('reports nothing found instead of throwing when every probe fails', () async {
      final refresher = EndpointRefresher(scanner: _FakeScanner({}));
      final result = await refresher.refresh(
        ports: const [443],
        pool: _pool(['1.1.1.1', '2.2.2.2']),
      );
      expect(result.ips, isEmpty);
      expect(result.foundAnything, isFalse);
      expect(result.summary, contains('none'));
    });

    test('an empty pool or port list short-circuits', () async {
      final refresher = EndpointRefresher(scanner: _FakeScanner({'1.1.1.1'}));
      expect((await refresher.refresh(ports: const [443], pool: const [])).ips,
          isEmpty);
      expect((await refresher.refresh(ports: const [], pool: _pool(['1.1.1.1']))).ips,
          isEmpty);
    });

    test('never returns more addresses than keep', () async {
      final all = [for (var i = 1; i <= 20; i++) '10.0.0.$i'];
      final refresher = EndpointRefresher(scanner: _FakeScanner(all.toSet()));
      final result = await refresher.refresh(
        ports: const [443],
        sample: 20,
        keep: 3,
        pool: _pool(all),
      );
      expect(result.ips.length, 3);
    });

    test('a different seed explores a different sample', () async {
      final all = [for (var i = 1; i <= 200; i++) '10.0.1.$i'];
      final scanner = _FakeScanner(all.toSet());
      final a = await EndpointRefresher(scanner: scanner).refresh(
        ports: const [443],
        sample: 5,
        keep: 5,
        seed: 1,
        pool: _pool(all),
      );
      final b = await EndpointRefresher(scanner: scanner).refresh(
        ports: const [443],
        sample: 5,
        keep: 5,
        seed: 2,
        pool: _pool(all),
      );
      expect(a.ips, isNot(equals(b.ips)));
    });
  });

  group('route capabilities', () {
    test('only the Cloudflare clean-IP routes can be rescued by a refresh', () {
      expect(AntiFilterRoute.workerNormal.usesCleanIps, isTrue);
      expect(AntiFilterRoute.workerFragment.usesCleanIps, isTrue);
      expect(AntiFilterRoute.serverlessPacket.usesCleanIps, isTrue);
      expect(AntiFilterRoute.psiphon.usesCleanIps, isFalse);
      expect(AntiFilterRoute.tor.usesCleanIps, isFalse);
      expect(AntiFilterRoute.warpObfuscated.usesCleanIps, isFalse);
    });
  });
}
