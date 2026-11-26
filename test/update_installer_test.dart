import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mili_vpn/services/update_installer.dart';
import 'package:mili_vpn/services/updates.dart';

void main() {
  late Directory cache;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('mili-update-test');
  });

  tearDown(() async {
    if (await cache.exists()) await cache.delete(recursive: true);
  });

  const update = AppUpdate(
    version: '2.2.0',
    notes: '',
    pageUrl: 'https://github.com/miladjahani/Milinovpn/releases/tag/v2.2.0',
    apkUrl: 'https://github.com/x/releases/download/v2.2.0/miliconfig-2.2.0-arm64-v8a.apk',
  );

  test('downloads a valid APK and reports progress', () async {
    final bytes = Uint8List(70 * 1024);
    bytes[0] = 0x50;
    bytes[1] = 0x4B;
    final client = MockClient(
      (_) async => http.Response.bytes(bytes, 200, headers: {
        HttpHeaders.contentTypeHeader: 'application/vnd.android.package-archive',
        HttpHeaders.contentLengthHeader: '${bytes.length}',
      }),
    );
    var last = 0.0;
    final file = await UpdateInstaller(
      client,
      cacheDir: () async => cache.path,
    ).download(update, onProgress: (fraction, _, __) => last = fraction);

    expect(await file.length(), bytes.length);
    expect(last, 1.0);
    expect(file.path, endsWith('MiliConfig-2.2.0.apk'));
  });

  test('rejects a non-APK response', () async {
    final client = MockClient(
      (_) async => http.Response(
        '<!doctype html>${List.filled(70 * 1024, 'x').join()}',
        200,
      ),
    );
    await expectLater(
      UpdateInstaller(
        client,
        cacheDir: () async => cache.path,
      ).download(update),
      throwsA(isA<UpdateException>()),
    );
  });

  test('rejects an HTTP error', () async {
    final client = MockClient((_) async => http.Response('no', 503));
    await expectLater(
      UpdateInstaller(
        client,
        cacheDir: () async => cache.path,
      ).download(update),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });
}
