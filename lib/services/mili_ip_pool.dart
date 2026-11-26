import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// One clean IP entry from MiliConfig's bundled IP pool.
class MiliIpEntry {
  final String ip;
  final String country;

  const MiliIpEntry({required this.ip, required this.country});

  factory MiliIpEntry.fromJson(Map<String, dynamic> j) => MiliIpEntry(
    ip: '${j['ip'] ?? ''}'.trim(),
    country: '${j['country'] ?? ''}'.trim().toUpperCase(),
  );
}

class MiliCountryInfo {
  final String code;
  final String name;
  final int count;

  const MiliCountryInfo({
    required this.code,
    required this.name,
    required this.count,
  });

  factory MiliCountryInfo.fromJson(Map<String, dynamic> j) => MiliCountryInfo(
    code: '${j['code'] ?? ''}'.trim().toUpperCase(),
    name: '${j['name'] ?? ''}'.trim(),
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class MiliFragmentPreset {
  final String id;
  final String name;
  final String subtitle;
  final String packets;
  final int lengthMin;
  final int lengthMax;
  final int intervalMin;
  final int intervalMax;

  const MiliFragmentPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.packets,
    required this.lengthMin,
    required this.lengthMax,
    required this.intervalMin,
    required this.intervalMax,
  });

  factory MiliFragmentPreset.fromJson(Map<String, dynamic> j) =>
      MiliFragmentPreset(
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

class MiliWarpProfile {
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

  const MiliWarpProfile({
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

  factory MiliWarpProfile.fromJson(Map<String, dynamic> j) => MiliWarpProfile(
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

class MiliDnsPreset {
  final String name;
  final String url;

  const MiliDnsPreset({required this.name, required this.url});

  factory MiliDnsPreset.fromJson(Map<String, dynamic> j) => MiliDnsPreset(
    name: '${j['name'] ?? ''}',
    url: '${j['url'] ?? ''}',
  );
}

class MiliPresetsBundle {
  final List<MiliFragmentPreset> fragments;
  final List<MiliWarpProfile> warpProfiles;
  final List<MiliDnsPreset> dnsPresets;
  final List<String> echDomains;

  const MiliPresetsBundle({
    required this.fragments,
    required this.warpProfiles,
    required this.dnsPresets,
    required this.echDomains,
  });
}

class MiliIpPoolData {
  final List<MiliIpEntry> ips;
  final List<MiliCountryInfo> countries;

  const MiliIpPoolData({required this.ips, required this.countries});

  List<MiliIpEntry> byCountry(String? countryCode) {
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

/// Loads MiliConfig's bundled IP pool and network presets from app assets.
class MiliCatalog {
  static MiliIpPoolData? _ipCache;
  static MiliPresetsBundle? _presetsCache;

  static Future<MiliIpPoolData> loadIpPool() async {
    if (_ipCache != null) return _ipCache!;
    final raw = await rootBundle.loadString('assets/mili/ip_pool.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final countries = ((map['countries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MiliCountryInfo.fromJson)
        .toList();
    final ips = ((map['ips'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MiliIpEntry.fromJson)
        .where((e) => e.ip.isNotEmpty)
        .toList();
    return _ipCache = MiliIpPoolData(ips: ips, countries: countries);
  }

  static Future<MiliPresetsBundle> loadPresets() async {
    if (_presetsCache != null) return _presetsCache!;
    final raw = await rootBundle.loadString('assets/mili/presets.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return _presetsCache = MiliPresetsBundle(
      fragments: ((map['fragments'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MiliFragmentPreset.fromJson)
          .toList(),
      warpProfiles: ((map['warpProfiles'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MiliWarpProfile.fromJson)
          .toList(),
      dnsPresets: ((map['dnsPresets'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MiliDnsPreset.fromJson)
          .toList(),
      echDomains: ((map['echDomains'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}
