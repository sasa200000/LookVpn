import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mili_vpn/services/exit_location_service.dart';

void main() {
  test('Proton catalog keeps unique WireGuard servers with locations', () {
    final source = jsonEncode({
      'servers': [
        {
          'vpn': 'wireguard',
          'country': 'Netherlands',
          'city': 'Amsterdam',
          'server_name': 'NL#1',
          'hostname': 'nl-01.protonvpn.net',
          'wgpubkey': 'key-one',
          'secure_core': false,
        },
        {
          'vpn': 'openvpn',
          'country': 'Netherlands',
          'city': 'Amsterdam',
          'server_name': 'NL#2',
          'hostname': 'nl-02.protonvpn.net',
        },
        {
          'vpn': 'wireguard',
          'country': 'United States',
          'city': 'New York',
          'server_name': 'US#3',
          'hostname': 'us-03.protonvpn.net',
          'wgpubkey': 'key-three',
          'port_forward': true,
        },
        {
          'vpn': 'wireguard',
          'country': 'Netherlands',
          'city': 'Amsterdam',
          'server_name': 'NL#1',
          'hostname': 'nl-01.protonvpn.net',
          'wgpubkey': 'key-one',
        },
      ],
    });

    final locations = parseProtonLocations(source);

    expect(locations, hasLength(2));
    expect(locations.first.country, 'Netherlands');
    expect(locations.first.hostname, 'nl-01.protonvpn.net');
    expect(locations.last.country, 'United States');
    expect(locations.last.portForwarding, isTrue);
  });
}
