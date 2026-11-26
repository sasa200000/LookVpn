import 'package:flutter_test/flutter_test.dart';
import 'package:look_vpn/services/anti_filter.dart';
import 'package:look_vpn/services/xray_config.dart';

void main() {
  group('AntiFilterLadder ordering', () {
    test('every rung maps to a connection type and optional variants', () {
      expect(AntiFilterRoute.workerNormal.mode, ConnectionMode.worker);
      expect(AntiFilterRoute.workerNormal.variant, ConnectionVariant.normal);
      expect(AntiFilterRoute.workerFragment.variant, ConnectionVariant.fragment);
      expect(AntiFilterRoute.warpObfuscated.mode, ConnectionMode.warp);
      expect(AntiFilterRoute.warpObfuscated.variant, ConnectionVariant.obfuscated);
      expect(AntiFilterRoute.masqueObfuscated.mode, ConnectionMode.masque);
      expect(AntiFilterRoute.masqueObfuscated.masqueVariant, MasqueVariant.obfuscated);
      expect(
        AntiFilterRoute.serverlessPacket.serverlessMode,
        ServerlessMode.packet,
      );
      expect(AntiFilterRoute.psiphon.mode, ConnectionMode.psiphon);
      expect(AntiFilterRoute.tor.mode, ConnectionMode.tor);
    });

    test('the cheapest routes come first and Tor last', () {
      expect(AntiFilterLadder.order.first, AntiFilterRoute.workerNormal);
      expect(AntiFilterLadder.order.last, AntiFilterRoute.tor);
      final iFragment = AntiFilterLadder.order.indexOf(AntiFilterRoute.workerFragment);
      final iTor = AntiFilterLadder.order.indexOf(AntiFilterRoute.tor);
      expect(iFragment, lessThan(iTor));
    });

    test('rungs are filtered by what this install can use', () {
      final usable = AntiFilterLadder.usable(const [
        ConnectionMode.worker,
        ConnectionMode.psiphon,
        ConnectionMode.tor,
      ]);
      expect(usable, [
        AntiFilterRoute.workerNormal,
        AntiFilterRoute.workerFragment,
        AntiFilterRoute.psiphon,
        AntiFilterRoute.tor,
      ]);
    });

    test('usable() keeps ladder order even when the modes arrive shuffled', () {
      final usable = AntiFilterLadder.usable(const [
        ConnectionMode.tor,
        ConnectionMode.worker,
        ConnectionMode.psiphon,
      ]);
      expect(usable.first, AntiFilterRoute.workerNormal);
      expect(usable.last, AntiFilterRoute.tor);
    });

    test('after() walks the usable rungs and stops at the end', () {
      const usable = [
        AntiFilterRoute.workerNormal,
        AntiFilterRoute.psiphon,
        AntiFilterRoute.tor,
      ];
      expect(AntiFilterLadder.after(AntiFilterRoute.workerNormal, usable),
          AntiFilterRoute.psiphon);
      expect(AntiFilterLadder.after(AntiFilterRoute.psiphon, usable),
          AntiFilterRoute.tor);
      expect(AntiFilterLadder.after(AntiFilterRoute.tor, usable), isNull);
    });

    test('after() on an unknown rung starts at the top', () {
      const usable = [AntiFilterRoute.psiphon, AntiFilterRoute.tor];
      expect(
        AntiFilterLadder.after(AntiFilterRoute.workerNormal, usable),
        AntiFilterRoute.psiphon,
      );
    });
  });

  group('escalation policy', () {
    test('a single failure retries the same rung instead of escalating', () {
      expect(AntiFilterLadder.shouldEscalate(1), isFalse);
    });

    test('two failures in a row move to the next rung', () {
      expect(AntiFilterLadder.shouldEscalate(2), isTrue);
      expect(AntiFilterLadder.shouldEscalate(3), isTrue);
    });

    test('fresh() marks every usable rung untried', () {
      final steps = AntiFilterLadder.fresh(const [
        ConnectionMode.worker,
        ConnectionMode.tor,
      ]);
      expect(steps.length, 3);
      expect(steps.every((s) => s.result == AntiFilterResult.untried), isTrue);
      expect(AntiFilterLadder.firstUntried(steps), AntiFilterRoute.workerNormal);
    });

    test('best() prefers a route that worked over untried ones', () {
      final steps = [
        const AntiFilterStep(AntiFilterRoute.workerNormal, AntiFilterResult.failed),
        const AntiFilterStep(AntiFilterRoute.psiphon, AntiFilterResult.worked),
        const AntiFilterStep(AntiFilterRoute.tor, AntiFilterResult.untried),
      ];
      expect(AntiFilterLadder.best(steps), AntiFilterRoute.psiphon);
    });

    test('best() falls through to the last rung when everything failed', () {
      final steps = [
        const AntiFilterStep(AntiFilterRoute.workerNormal, AntiFilterResult.failed),
        const AntiFilterStep(AntiFilterRoute.tor, AntiFilterResult.failed),
      ];
      expect(AntiFilterLadder.best(steps), AntiFilterRoute.tor);
    });
  });

  group('StallWatchdog', () {
    test('moving bytes keeps the tunnel alive', () {
      final w = StallWatchdog(quietAfter: const Duration(seconds: 10));
      expect(w.sample(totalBytes: 0, elapsed: const Duration(seconds: 2)), isFalse);
      for (var i = 1; i <= 20; i++) {
        expect(
          w.sample(
            totalBytes: i * 100000,
            elapsed: const Duration(seconds: 2),
          ),
          isFalse,
        );
      }
    });

    test('a silent tunnel is reported after quietAfter', () {
      final w = StallWatchdog(quietAfter: const Duration(seconds: 10));
      w.sample(totalBytes: 500000, elapsed: const Duration(seconds: 2));
      var stalled = false;
      for (var i = 0; i < 6 && !stalled; i++) {
        stalled = w.sample(
          totalBytes: 500000,
          elapsed: const Duration(seconds: 2),
        );
      }
      expect(stalled, isTrue);
      expect(w.quiet, greaterThanOrEqualTo(const Duration(seconds: 10)));
    });

    test('a trickle below the threshold still counts as silence', () {
      final w = StallWatchdog(
        quietAfter: const Duration(seconds: 8),
        minimumBytes: 4096,
      );
      w.sample(totalBytes: 100000, elapsed: const Duration(seconds: 2));
      var stalled = false;
      for (var i = 0; i < 6 && !stalled; i++) {
        stalled = w.sample(
          totalBytes: 100500, // 500 bytes every 2 s: keepalives, not traffic
          elapsed: const Duration(seconds: 2),
        );
      }
      expect(stalled, isTrue);
    });

    test('reset() forgets the previous session', () {
      final w = StallWatchdog(quietAfter: const Duration(seconds: 4));
      w.sample(totalBytes: 100000, elapsed: const Duration(seconds: 2));
      w.sample(totalBytes: 100000, elapsed: const Duration(seconds: 2));
      w.reset();
      expect(w.quiet, Duration.zero);
      expect(w.sample(totalBytes: 0, elapsed: const Duration(seconds: 2)), isFalse);
    });
  });
}
