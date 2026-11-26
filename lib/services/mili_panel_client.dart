import 'dart:convert';

import 'package:http/http.dart' as http;

/// Connects the MiliConfig mobile app to a deployed MiliConfig Panel
/// (Cloudflare Workers / Pages) or any Mili subscription / `/ips` endpoint.
class MiliPanelClient {
  final http.Client _http;
  MiliPanelClient([http.Client? client]) : _http = client ?? http.Client();

  /// Normalizes a panel base URL like `my-panel.workers.dev` -> `https://my-panel.workers.dev`.
  static Uri normalizeBaseUri(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw const FormatException('Please enter a Mili Panel or subscription URL.');
    }
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('Invalid URL format.');
    }
    return uri;
  }

  /// Fetches live clean IPs from a Mili Panel `/ips` endpoint.
  Future<List<String>> fetchPanelIps(
    String panelUrl, {
    String? country,
    int count = 12,
  }) async {
    final base = normalizeBaseUri(panelUrl);
    final query = <String, String>{'count': '$count'};
    if (country != null && country.trim().isNotEmpty) {
      query['country'] = country.trim().toUpperCase();
    }
    final target = base.path.endsWith('/ips')
        ? base.replace(queryParameters: query)
        : base.replace(path: '/ips', queryParameters: query);

    final res = await _http.get(target).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Panel /ips returned HTTP ${res.statusCode}');
    }
    final out = <String>[];
    for (final line in res.body.split(RegExp(r'\r?\n'))) {
      final clean = line.split('#').first.trim();
      if (clean.isEmpty) continue;
      // Strip optional :port if present on IPv4
      final host = clean.contains(':') && !clean.startsWith('[')
          ? clean.split(':').first.trim()
          : clean;
      if (host.isNotEmpty && !out.contains(host)) {
        out.add(host);
      }
    }
    return out;
  }

  /// Fetches a Mili subscription URL (plain text or base64) and extracts supported
  /// proxy URIs (`vless://`, `vmess://`, `trojan://`, `ss://`, `socks://`, `http://`, `wg://`).
  Future<List<String>> fetchSubscriptionLinks(String subUrl) async {
    final uri = normalizeBaseUri(subUrl);
    final res = await _http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('Subscription returned HTTP ${res.statusCode}');
    }
    final decoded = _tryDecodeBase64(res.body.trim()) ?? res.body;
    final schemes = const [
      'vless://',
      'vmess://',
      'trojan://',
      'ss://',
      'socks://',
      'socks5://',
      'http://',
      'https://',
      'wg://',
    ];
    final links = <String>[];
    for (final rawLine in decoded.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (schemes.any(lower.startsWith) && !links.contains(line)) {
        links.add(line);
      }
    }
    return links;
  }

  static String? _tryDecodeBase64(String input) {
    if (input.contains('://')) return null;
    final compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 16) return null;
    try {
      final normalized = base64.normalize(compact);
      final bytes = base64Decode(normalized);
      final text = utf8.decode(bytes, allowMalformed: true);
      if (text.contains('://')) return text;
    } catch (_) {}
    return null;
  }
}
