import 'dart:convert';

import 'package:flutter/services.dart';

import 'vpn_channel.dart';

class MihomoStateEvent {
  final String state;
  final String? error;
  final int connectedAt;
  final String remark;

  const MihomoStateEvent({
    required this.state,
    this.error,
    this.connectedAt = 0,
    this.remark = 'Mihomo',
  });

  bool get connected => state == 'connected';
  bool get connecting => state == 'connecting';
  bool get disconnecting => state == 'disconnecting';

  factory MihomoStateEvent.fromMap(Object? value) {
    final map = (value as Map?)?.cast<Object?, Object?>() ?? const {};
    return MihomoStateEvent(
      state: map['state']?.toString() ?? 'disconnected',
      error: map['error']?.toString(),
      connectedAt: (map['connectedAt'] as num?)?.toInt() ?? 0,
      remark: map['remark']?.toString() ?? 'Mihomo',
    );
  }
}

/// Separate channel from [VpnChannel]: Mihomo does not read or mutate the Xray profile.
class MihomoChannel {
  static const _methods = MethodChannel('lookvpn/mihomo');
  static const _events = EventChannel('lookvpn/mihomoState');

  static Stream<MihomoStateEvent> get states =>
      _events.receiveBroadcastStream().map(
        (event) => MihomoStateEvent.fromMap(event),
      );

  static Future<MihomoStateEvent> status() async =>
      MihomoStateEvent.fromMap(await _methods.invokeMethod<Object?>('status'));

  static Future<void> setup(String config) async {
    final error = await _methods.invokeMethod<String>('setup', {
      'config': config,
    });
    if (error != null && error.isNotEmpty) throw StateError(error);
  }

  static Future<void> start() async {
    final allowed = await VpnChannel.prepare();
    if (!allowed) {
      throw StateError('VPN permission was not granted.');
    }
    await _methods.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    await _methods.invokeMethod<void>('stop');
  }

  static Future<String> proxies() async =>
      await _methods.invokeMethod<String>('proxies') ?? '';

  static Future<String> testGroups(
    List<String> groups, {
    String url = 'https://www.gstatic.com/generate_204',
    int timeout = 5000,
  }) async =>
      await _methods.invokeMethod<String>('testGroups', {
        'groups': groups,
        'url': url,
        'timeout': timeout,
      }) ??
      '';

  static Future<int> testDelay(
    String name, {
    String url = 'https://www.gstatic.com/generate_204',
    int timeout = 5000,
  }) async =>
      await _methods.invokeMethod<int>('testDelay', {
        'name': name,
        'url': url,
        'timeout': timeout,
      }) ??
      -1;

  static Future<void> select(String name, {String group = 'MILI'}) async {
    await _methods.invokeMethod<void>('select', {'group': group, 'name': name});
  }

  static Future<void> refreshProvider(String name) async {
    await _methods.invokeMethod<void>('refreshProvider', {'name': name});
  }

  static Future<MihomoTraffic> traffic() async {
    final raw = await _methods.invokeMethod<String>('traffic') ?? '{}';
    return MihomoTraffic.parse(raw);
  }

  static Future<MihomoTraffic> totalTraffic() async {
    final raw = await _methods.invokeMethod<String>('totalTraffic') ?? '{}';
    return MihomoTraffic.parse(raw);
  }
}

class MihomoTraffic {
  final int up;
  final int down;

  const MihomoTraffic({this.up = 0, this.down = 0});

  factory MihomoTraffic.parse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const MihomoTraffic();
      return MihomoTraffic(
        up: (json['up'] as num?)?.toInt() ?? 0,
        down: (json['down'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const MihomoTraffic();
    }
  }
}
