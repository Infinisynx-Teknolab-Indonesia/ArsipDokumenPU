import 'dart:convert';
import 'dart:io';

/// Menyimpan alamat server & username terakhir (bukan password) di
/// Windows: %APPDATA%\ArsipAdminServer\config.json
/// macOS  : ~/Library/Application Support/ArsipAdminServer/config.json
class ConfigStore {
  static File get _file {
    final String base;
    if (Platform.isMacOS) {
      base = '${Platform.environment['HOME']}/Library/Application Support';
    } else {
      base = Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path;
    }
    final dir = Directory('$base${Platform.pathSeparator}ArsipAdminServer');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}config.json');
  }

  static Map<String, dynamic> read() {
    try {
      final f = _file;
      if (f.existsSync()) return Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map);
    } catch (_) {}
    return {};
  }

  static void write(Map<String, dynamic> data) {
    try {
      _file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }
}
