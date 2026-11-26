import 'dart:convert';

import 'package:http/http.dart' as http;

/// Gluetun's community-maintained Proton VPN server catalog. Proton's public
/// logicals API started requiring account authentication in 2025, so the app
/// uses this public directory for location names and WireGuard public keys.
/// Connecting still requires the user's own official Proton WireGuard config.
const protonServerCatalogUrl =
    'https://raw.githubusercontent.com/qdm12/gluetun-servers/main/pkg/servers/protonvpn.json';

/// The Cloudflare edge that served a Worker or Pages host, read from the
/// `cf-ray` response header and (when available) `/cdn-cgi/trace`.
class CloudflareEdgeResult {
  final String host;
  final String? colo;
  final int? latencyMs;
  final String? error;

  const CloudflareEdgeResult({
    required this.host,
    this.colo,
    this.latencyMs,
    this.error,
  });

  bool get ok => error == null && colo != null && colo!.isNotEmpty;
}

/// Probes [host] directly, so the result describes the Cloudflare edge/colo of
/// the deployment rather than the current tunnel's exit.
Future<CloudflareEdgeResult> probeCloudflareEdge(
  String host, {
  http.Client? client,
}) async {
  final ownClient = client == null;
  final httpClient = client ?? http.Client();
  final watch = Stopwatch()..start();
  try {
    final uri = Uri.https(host, '/cdn-cgi/trace', {
      'mili': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final response = await httpClient
        .get(
          uri,
          headers: const {
            'Accept': 'text/plain',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 9));
    watch.stop();
    final trace = <String, String>{};
    for (final line in response.body.split('\n')) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      trace[line.substring(0, separator).trim()] = line
          .substring(separator + 1)
          .trim();
    }
    final ray = response.headers['cf-ray'] ?? '';
    final colo = trace['colo']?.trim().isNotEmpty == true
        ? trace['colo']!.trim()
        : (ray.contains('-') ? ray.split('-').last.trim() : '');
    if (colo.isEmpty && response.statusCode >= 500) {
      return CloudflareEdgeResult(
        host: host,
        latencyMs: watch.elapsedMilliseconds,
        error: 'HTTP ${response.statusCode}',
      );
    }
    return CloudflareEdgeResult(
      host: host,
      colo: colo.isEmpty ? null : colo.toUpperCase(),
      latencyMs: watch.elapsedMilliseconds,
    );
  } catch (e) {
    return CloudflareEdgeResult(host: host, error: '$e');
  } finally {
    if (ownClient) httpClient.close();
  }
}

/// One Proton VPN WireGuard server from the public directory.
class ProtonLocation {
  final String country;
  final String city;
  final String server;
  final String hostname;
  final String publicKey;
  final bool secureCore;
  final bool portForwarding;

  const ProtonLocation({
    required this.country,
    required this.city,
    required this.server,
    required this.hostname,
    required this.publicKey,
    this.secureCore = false,
    this.portForwarding = false,
  });

  String get label => server.isEmpty ? hostname : server;
  String get place => city.isEmpty ? country : '$country · $city';
}

/// Downloads and parses the public Proton WireGuard location catalog.
Future<List<ProtonLocation>> fetchProtonLocations({
  http.Client? client,
}) async {
  final ownClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(Uri.parse(protonServerCatalogUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}');
    }
    return parseProtonLocations(response.body);
  } finally {
    if (ownClient) httpClient.close();
  }
}

/// Extracts the unique WireGuard servers from Gluetun's Proton JSON.
List<ProtonLocation> parseProtonLocations(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Unexpected Proton server catalog');
  }
  final rawServers = decoded['servers'];
  if (rawServers is! List) {
    throw const FormatException('No Proton servers in catalog');
  }
  final locations = <String, ProtonLocation>{};
  for (final raw in rawServers) {
    if (raw is! Map || raw['vpn'] != 'wireguard') continue;
    final country = '${raw['country'] ?? ''}'.trim();
    final hostname = '${raw['hostname'] ?? ''}'.trim();
    final publicKey = '${raw['wgpubkey'] ?? ''}'.trim();
    if (country.isEmpty || hostname.isEmpty || publicKey.isEmpty) continue;
    locations[hostname] = ProtonLocation(
      country: country,
      city: '${raw['city'] ?? ''}'.trim(),
      server: '${raw['server_name'] ?? ''}'.trim(),
      hostname: hostname,
      publicKey: publicKey,
      secureCore: raw['secure_core'] == true,
      portForwarding: raw['port_forward'] == true,
    );
  }
  final list = locations.values.toList()
    ..sort((a, b) {
      final byCountry = a.country.compareTo(b.country);
      if (byCountry != 0) return byCountry;
      final byCity = a.city.compareTo(b.city);
      if (byCity != 0) return byCity;
      return a.label.compareTo(b.label);
    });
  return list;
}
