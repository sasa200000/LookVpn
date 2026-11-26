import 'dart:io';

import 'package:http/http.dart' as http;

import 'updates.dart';
import 'vpn_channel.dart';

/// Downloads the release APK to the app cache. The actual install is handled by Android's
/// package installer (see VpnChannel.installApk); nothing here needs a third-party plugin.
class UpdateInstaller {
  final http.Client client;

  /// A test seam; production uses the app's native cache directory.
  final Future<String> Function()? cacheDir;
  const UpdateInstaller(this.client, {this.cacheDir});

  /// Downloads [update]'s APK and reports progress as a fraction (0–1). Returns the file.
  Future<File> download(
    AppUpdate update, {
    void Function(double fraction, int received, int total)? onProgress,
  }) async {
    final url = update.apkUrl;
    if (url == null || url.isEmpty) {
      throw const UpdateException(
        'This release has no APK for this phone. Open the release page instead.',
      );
    }

    final base = await (cacheDir?.call() ?? VpnChannel.cacheDir());
    if (base.isEmpty) {
      throw const UpdateException("Couldn't find the app cache directory.");
    }
    final dir = Directory('$base/updates');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/MiliConfig-${update.version}.apk');

    final request = http.Request('GET', Uri.parse(url));
    final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw UpdateException("Can't reach GitHub: $e");
    }
    if (response.statusCode != 200) {
      throw UpdateException('Download failed (HTTP ${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : 0.0,
          received,
          total,
        );
      }
    } catch (e) {
      throw UpdateException('The download was interrupted: $e');
    } finally {
      await sink.close();
    }

    if (received < 64 * 1024) {
      await file.delete();
      throw const UpdateException('The downloaded file is incomplete. Try again.');
    }
    if (!await _isZip(file)) {
      await file.delete();
      throw const UpdateException('GitHub returned a file that is not an APK.');
    }
    return file;
  }

  static Future<bool> _isZip(File file) async {
    final handle = await file.open();
    try {
      final head = await handle.read(2);
      return head.length == 2 && head[0] == 0x50 && head[1] == 0x4B;
    } finally {
      await handle.close();
    }
  }
}
