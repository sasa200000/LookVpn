import 'xray_config.dart';

/// One rung of the anti-filter ladder: a way of connecting that fails differently from the
/// others, ordered so the cheapest and most direct routes are tried first and the most
/// resilient (and slowest) ones last.
///
/// Iranian filtering is not one wall but several: TLS/SNI inspection on the international
/// gateways, DNS poisoning, protocol fingerprinting (WireGuard, plain VLESS, OpenVPN), and
/// IP-level blocking of Cloudflare edges and VPN ranges. A single protocol is defeated by a
/// single rule. The ladder exists so a blocked rung is skipped automatically instead of
/// leaving the user stranded on a dead connection.
enum AntiFilterRoute {
  /// VLESS over WebSocket + TLS through the deployed worker, untouched. Works where only
  /// DNS is poisoned; dies to SNI inspection of the worker's hostname.
  workerNormal,

  /// The same tunnel with per-packet TLS fragmentation, which splits the ClientHello so a
  /// DPI box cannot match the SNI in one segment.
  workerFragment,

  /// WARP over WireGuard with obfuscation, for when Cloudflare's edge is reachable but
  /// WireGuard's handshake is fingerprinted.
  warpObfuscated,

  /// WARP over MASQUE (CONNECT-IP over HTTP/2 or 3): looks like ordinary HTTPS to the edge.
  masqueObfuscated,

  /// Serverless packet mode: TLS fragmentation plus UDP noise with no worker at all, so
  /// there is no hostname to block.
  serverlessPacket,

  /// Psiphon: its own network of ingress servers, reached directly. Survives Cloudflare
  /// edge blocking because it does not depend on Cloudflare.
  psiphon,

  /// Tor over built-in bridges (snowflake / meek / obfs4 / webtunnel). The slowest rung and
  /// the last resort, but it is the one that keeps working when everything else is blocked.
  tor;

  /// The type this rung connects as.
  ConnectionMode get mode => switch (this) {
    workerNormal || workerFragment => ConnectionMode.worker,
    warpObfuscated => ConnectionMode.warp,
    masqueObfuscated => ConnectionMode.masque,
    serverlessPacket => ConnectionMode.serverless,
    psiphon => ConnectionMode.psiphon,
    tor => ConnectionMode.tor,
  };

  /// Whether this route reaches Cloudflare through the configured clean IPs, and so can be
  /// recovered by refreshing them when they go stale.
  bool get usesCleanIps =>
      this == workerNormal ||
      this == workerFragment ||
      this == serverlessPacket;

  /// The Worker / WARP variant this rung needs, if any.
  ConnectionVariant? get variant => switch (this) {
    workerNormal => ConnectionVariant.normal,
    workerFragment => ConnectionVariant.fragment,
    warpObfuscated => ConnectionVariant.obfuscated,
    _ => null,
  };

  /// The MASQUE variant this rung needs, if any.
  MasqueVariant? get masqueVariant =>
      this == masqueObfuscated ? MasqueVariant.obfuscated : null;

  /// The Serverless mode this rung needs, if any.
  ServerlessMode? get serverlessMode =>
      this == serverlessPacket ? ServerlessMode.packet : null;

  /// English / Persian names for the ladder UI.
  String get label => switch (this) {
    workerNormal => 'Worker · Normal',
    workerFragment => 'Worker · Fragment',
    warpObfuscated => 'WARP · Obfuscated',
    masqueObfuscated => 'MASQUE · Obfuscated',
    serverlessPacket => 'Serverless · Packet',
    psiphon => 'Psiphon',
    tor => 'Tor',
  };

  String get labelFa => switch (this) {
    workerNormal => 'ورکر · عادی',
    workerFragment => 'ورکر · تکه‌تکه',
    warpObfuscated => 'WARP · مبهم',
    masqueObfuscated => 'MASQUE · مبهم',
    serverlessPacket => 'سرورلس · بسته‌ای',
    psiphon => 'سایفون',
    tor => 'تور',
  };

  /// Why this rung defeats a different filter than the one before it.
  String get defeats => switch (this) {
    workerNormal => 'DNS poisoning only',
    workerFragment => 'SNI / ClientHello inspection',
    warpObfuscated => 'WireGuard fingerprinting',
    masqueObfuscated => 'non-HTTP protocol blocking',
    serverlessPacket => 'hostname and Cloudflare edge blocking',
    psiphon => 'everything that needs Cloudflare',
    tor => 'IP-range blocking, as a last resort',
  };

  /// How the rung is reached, in short.
  String get transport => switch (this) {
    workerNormal || workerFragment => 'TLS · WebSocket',
    warpObfuscated => 'WireGuard + obfuscation',
    masqueObfuscated => 'CONNECT-IP · HTTP/2-3',
    serverlessPacket => 'fragmented TLS · UDP noise',
    psiphon => 'Psiphon ingress',
    tor => 'bridged Tor',
  };
}

/// The outcome of trying one rung.
enum AntiFilterResult {
  /// The tunnel came up and traffic passed.
  worked,

  /// The tunnel never came up (handshake refused, reset, timed out).
  failed,

  /// It connected but no traffic passed, which is what a silently blackholed tunnel looks
  /// like; treated the same as [failed] but reported differently.
  stalled,

  /// Not tried yet.
  untried,
}

/// A rung and what happened when it was tried.
class AntiFilterStep {
  final AntiFilterRoute route;
  final AntiFilterResult result;

  /// What the rung reported, for the log and the UI ("handshake timeout", "no traffic").
  final String? detail;

  const AntiFilterStep(this.route, this.result, {this.detail});

  AntiFilterStep withResult(AntiFilterResult value, {String? detail}) =>
      AntiFilterStep(route, value, detail: detail);
}

/// The anti-filter ladder: which rungs this install can actually use, which one is next, and
/// whether escalation should continue.
///
/// Kept pure (no app state, no IO) so the ordering and the stop conditions can be tested
/// without a device or a network.
class AntiFilterLadder {
  /// Every rung, in the order they are tried.
  static const order = AntiFilterRoute.values;

  /// Rungs that can be used right now, given the connection types [availableModes] reports.
  static List<AntiFilterRoute> usable(List<ConnectionMode> availableModes) => [
    for (final route in order)
      if (availableModes.contains(route.mode)) route,
  ];

  /// How many failures in a row are worth riding out before changing rung. Two, so a single
  /// flaky handshake on a congested mobile network does not tear down a working route.
  static const failuresBeforeEscalating = 2;

  /// The rung after [current]; null when the ladder is exhausted.
  static AntiFilterRoute? after(
    AntiFilterRoute current,
    List<AntiFilterRoute> usable,
  ) {
    final i = usable.indexOf(current);
    if (i < 0) return usable.firstOrNull;
    return i + 1 < usable.length ? usable[i + 1] : null;
  }

  /// The first rung that has not failed yet, which is where a fresh attempt should start.
  static AntiFilterRoute? firstUntried(List<AntiFilterStep> steps) {
    for (final step in steps) {
      if (step.result == AntiFilterResult.untried) return step.route;
    }
    return null;
  }

  /// The best rung so far: the one that worked, or else the first one still worth trying.
  static AntiFilterRoute? best(List<AntiFilterStep> steps) {
    final worked = steps
        .where((s) => s.result == AntiFilterResult.worked)
        .map((s) => s.route)
        .firstOrNull;
    if (worked != null) return worked;
    final untried = firstUntried(steps);
    if (untried != null) return untried;
    // Everything failed: fall back to the most resilient rung rather than nothing, because a
    // slow working tunnel beats a fast dead one.
    return steps.isEmpty ? null : steps.last.route;
  }

  /// Whether a run of [consecutiveFailures] should move to the next rung.
  static bool shouldEscalate(
    int consecutiveFailures, {
    int threshold = failuresBeforeEscalating,
  }) => consecutiveFailures >= threshold;

  /// A fresh ladder where every usable rung starts untried.
  static List<AntiFilterStep> fresh(List<ConnectionMode> availableModes) => [
    for (final route in usable(availableModes)) AntiFilterStep(route, AntiFilterResult.untried),
  ];
}

/// Watches a live connection for the silent failure that filtering produces most often: the
/// tunnel reports itself as up while every packet is dropped.
///
/// Pure policy, no timers: [sample] is fed the byte counters and the elapsed time, and it
/// reports when the connection has gone quiet for long enough to be considered dead.
class StallWatchdog {
  /// Seconds of a connected-but-idle tunnel before it counts as stalled. Long enough to
  /// survive a phone that is simply not doing anything, short enough to be useful.
  final Duration quietAfter;

  /// Traffic must have moved at least this many bytes since the last reset to count as alive.
  final int minimumBytes;

  Duration _quiet = Duration.zero;
  int _lastTotal = -1;

  StallWatchdog({
    this.quietAfter = const Duration(seconds: 45),
    this.minimumBytes = 4096,
  });

  /// Seconds the tunnel has been quiet, for the UI.
  Duration get quiet => _quiet;

  /// Feeds one sample. [totalBytes] is up + down since the session started; [elapsed] is the
  /// time since the previous sample. Returns true when the connection should be considered
  /// stalled and escalated.
  bool sample({required int totalBytes, required Duration elapsed}) {
    if (_lastTotal < 0 || totalBytes > _lastTotal + minimumBytes) {
      _lastTotal = totalBytes;
      _quiet = Duration.zero;
      return false;
    }
    _lastTotal = totalBytes;
    _quiet += elapsed;
    return _quiet >= quietAfter;
  }

  /// Called when a new session starts, so the previous session's counters do not look like
  /// movement.
  void reset() {
    _lastTotal = -1;
    _quiet = Duration.zero;
  }
}
