import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String url;
  final String notes;
  UpdateInfo({required this.version, required this.url, required this.notes});
}

class UpdateService {
  static const _versionJsonUrl =
      'https://raw.githubusercontent.com/filippe534/ATR/main/releases/version.json';

  /// Retorna UpdateInfo se há versão nova, null caso contrário.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = data['version'] as String;
      final info = await PackageInfo.fromPlatform();
      final localVersion = info.version;

      if (_isNewer(remoteVersion, localVersion)) {
        return UpdateInfo(
          version: remoteVersion,
          url: data['url'] as String,
          notes: data['notes'] as String? ?? '',
        );
      }
      return null;
    } catch (_) {
      return null; // sem internet ou erro — ignora silenciosamente
    }
  }

  /// Baixa o MSIX e abre o instalador; retorna false se falhar.
  static Future<bool> downloadAndInstall(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return false;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ATR-Setup-update.msix');
      await file.writeAsBytes(response.bodyBytes);

      if (Platform.isWindows) {
        await Process.run(
          'powershell',
          ['-Command', 'Start-Process', '-FilePath', file.path],
          runInShell: false,
        );
      } else {
        await Process.run('open', [file.path]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.parse).toList();
    final l = local.split('.').map(int.parse).toList();
    for (var i = 0; i < r.length && i < l.length; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return r.length > l.length;
  }
}
