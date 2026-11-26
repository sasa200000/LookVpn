import 'package:flutter_test/flutter_test.dart';
import 'package:mili_vpn/models/mihomo_profile.dart';

void main() {
  test('subscriptions round-trip through the independent prefs payload', () {
    const items = [
      MihomoSubscription(
        id: 'one',
        name: 'Primary',
        url: 'https://example.com/sub?token=a&format=clash',
      ),
    ];
    final decoded = MihomoSubscription.decodeList(
      MihomoSubscription.encodeList(items),
    );
    expect(decoded, hasLength(1));
    expect(decoded.single.name, 'Primary');
    expect(decoded.single.url, contains('token=a'));
  });

  test('config contains a provider and the selectable aggregation group', () {
    const items = [
      MihomoSubscription(
        id: 'one',
        name: 'Primary',
        url: 'https://example.com/sub',
      ),
    ];
    final yaml = MihomoConfigBuilder.build(items);
    expect(yaml, contains('proxy-providers:'));
    expect(yaml, contains('mili_0:'));
    expect(yaml, contains('use:'));
    expect(yaml, contains('- mili_0'));
    expect(yaml, contains('name: MILI'));
    expect(yaml, contains('MATCH,MILI'));
  });
}
