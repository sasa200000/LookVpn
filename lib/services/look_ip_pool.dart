import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// One clean IP entry from LookVPN's bundled IP pool.
class LookIpEntry {
  final String ip;
  final String country;

  const LookIpEntry({required this.ip, required this.country});

  factory LookIpEntry.fromJson(Map<String, dynamic> j) => LookIpEntry(
    ip: '${j['ip'] ?? ''}'.trim(),
    country: '${j['country'] ?? ''}'.trim().toUpperCase(),
  );
}

class LookCountryInfo {
  final String code;
  final String name;
  final int count;

  const LookCountryInfo({
    required this.code,
    required this.name,
    required this.count,
  });

  factory LookCountryInfo.fromJson(Map<String, dynamic> j) => LookCountryInfo(
    code: '${j['code'] ?? ''}'.trim().toUpperCase(),
    name: '${j['name'] ?? ''}'.trim(),
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class LookFragmentPreset {
  final String id;
  final String name;
  final String subtitle;
  final String packets;
  final int lengthMin;
  final int lengthMax;
  final int intervalMin;
  final int intervalMax;

  const LookFragmentPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.packets,
    required this.lengthMin,
    required this.lengthMax,
    required this.intervalMin,
    required this.intervalMax,
  });

  factory LookFragmentPreset.fromJson(Map<String, dynamic> j) =>
      LookFragmentPreset(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        packets: '${j['packets'] ?? 'tlshello'}',
        lengthMin: (j['lengthMin'] as num?)?.toInt() ?? 10,
        lengthMax: (j['lengthMax'] as num?)?.toInt() ?? 30,
        intervalMin: (j['intervalMin'] as num?)?.toInt() ?? 10,
        intervalMax: (j['intervalMax'] as num?)?.toInt() ?? 20,
      );
}

class LookWarpProfile {
  final String id;
  final String name;
  final String subtitle;
  final int mtu;
  final int noiseCountMin;
  final int noiseCountMax;
  final int noiseSizeMin;
  final int noiseSizeMax;
  final int noiseDelayMin;
  final int noiseDelayMax;

  const LookWarpProfile({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.mtu,
    required this.noiseCountMin,
    required this.noiseCountMax,
    required this.noiseSizeMin,
    required this.noiseSizeMax,
    required this.noiseDelayMin,
    required this.noiseDelayMax,
  });

  factory LookWarpProfile.fromJson(Map<String, dynamic> j) => LookWarpProfile(
    id: '${j['id'] ?? ''}',
    name: '${j['name'] ?? ''}',
    subtitle: '${j['subtitle'] ?? ''}',
    mtu: (j['mtu'] as num?)?.toInt() ?? 1280,
    noiseCountMin: (j['noiseCountMin'] as num?)?.toInt() ?? 5,
    noiseCountMax: (j['noiseCountMax'] as num?)?.toInt() ?? 10,
    noiseSizeMin: (j['noiseSizeMin'] as num?)?.toInt() ?? 50,
    noiseSizeMax: (j['noiseSizeMax'] as num?)?.toInt() ?? 100,
    noiseDelayMin: (j['noiseDelayMin'] as num?)?.toInt() ?? 10,
    noiseDelayMax: (j['noiseDelayMax'] as num?)?.toInt() ?? 25,
  );
}

class LookDnsPreset {
  final String name;
  final String url;

  const LookDnsPreset({required this.name, required this.url});

  factory LookDnsPreset.fromJson(Map<String, dynamic> j) => LookDnsPreset(
    name: '${j['name'] ?? ''}',
    url: '${j['url'] ?? ''}',
  );
}

class LookPresetsBundle {
  final List<LookFragmentPreset> fragments;
  final List<LookWarpProfile> warpProfiles;
  final List<LookDnsPreset> dnsPresets;
  final List<String> echDomains;

  const LookPresetsBundle({
    required this.fragments,
    required this.warpProfiles,
    required this.dnsPresets,
    required this.echDomains,
  });
}

class LookIpPoolData {
  final List<LookIpEntry> ips;
  final List<LookCountryInfo> countries;

  const LookIpPoolData({required this.ips, required this.countries});

  List<LookIpEntry> byCountry(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return ips;
    final code = countryCode.toUpperCase();
    return ips.where((e) => e.country == code).toList();
  }

  /// Picks [count] random unique IPs (optionally filtered by [countryCode]).
  List<String> pickRandom({int count = 8, String? countryCode, Random? rng}) {
    final pool = byCountry(countryCode).map((e) => e.ip).toList();
    pool.shuffle(rng ?? Random());
    return pool.take(count).toList();
  }
}

/// Loads LookVPN's bundled IP pool and network presets from app assets.
class LookCatalog {
  static LookIpPoolData? _ipCache;
  static LookPresetsBundle? _presetsCache;

  static Future<LookIpPoolData> loadIpPool() async {
    if (_ipCache != null) return _ipCache!;
    final raw = await rootBundle.loadString('assets/look/ip_pool.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final countries = ((map['countries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LookCountryInfo.fromJson)
        .toList();
    final ips = ((map['ips'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LookIpEntry.fromJson)
        .where((e) => e.ip.isNotEmpty)
        .toList();
    return _ipCache = LookIpPoolData(ips: ips, countries: countries);
  }

  static Future<LookPresetsBundle> loadPresets() async {
    if (_presetsCache != null) return _presetsCache!;
    final raw = await rootBundle.loadString('assets/look/presets.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return _presetsCache = LookPresetsBundle(
      fragments: ((map['fragments'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LookFragmentPreset.fromJson)
          .toList(),
      warpProfiles: ((map['warpProfiles'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LookWarpProfile.fromJson)
          .toList(),
      dnsPresets: ((map['dnsPresets'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LookDnsPreset.fromJson)
          .toList(),
      echDomains: ((map['echDomains'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
