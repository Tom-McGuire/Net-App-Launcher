import 'dart:convert';
import 'dart:io';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:path/path.dart' as p;

class InstalledAppRecord {
  final String appId;
  final String version;
  final String installPath;
  final String? executablePath;
  final DateTime installedAt;

  const InstalledAppRecord({
    required this.appId,
    required this.version,
    required this.installPath,
    this.executablePath,
    required this.installedAt,
  });

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'version': version,
        'install_path': installPath,
        'executable_path': executablePath,
        'installed_at': installedAt.toIso8601String(),
      };

  factory InstalledAppRecord.fromJson(Map<String, dynamic> json) => InstalledAppRecord(
        appId: json['app_id'] as String? ?? '',
        version: json['version'] as String? ?? '',
        installPath: json['install_path'] as String? ?? '',
        executablePath: json['executable_path'] as String?,
        installedAt: DateTime.tryParse(json['installed_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class LocalAppRegistry {
  final String _baseDir;

  LocalAppRegistry({String? customBaseDir})
      : _baseDir = customBaseDir ?? SharedDeviceDatabase.getDefaultDirectoryPath();

  String get appsDirectory => p.join(_baseDir, 'apps');
  String get registryFilePath => p.join(_baseDir, 'installed_apps.json');

  /// Gets the install folder for a specific app id.
  String getAppInstallPath(String appId) {
    return p.join(appsDirectory, appId);
  }

  /// Loads the registry of locally installed applications.
  Map<String, InstalledAppRecord> loadRegistry() {
    final file = File(registryFilePath);
    if (!file.existsSync()) return {};

    try {
      final content = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      final result = <String, InstalledAppRecord>{};

      for (final entry in data.entries) {
        if (entry.value is Map<String, dynamic>) {
          result[entry.key] = InstalledAppRecord.fromJson(entry.value as Map<String, dynamic>);
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Saves or updates an installed application record.
  void recordInstallation(InstalledAppRecord record) {
    final registry = loadRegistry();
    registry[record.appId] = record;

    final dir = Directory(_baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final data = <String, dynamic>{
      for (final e in registry.entries) e.key: e.value.toJson(),
    };

    File(registryFilePath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Removes an app record and optionally deletes its directory from disk.
  void removeInstallation(String appId, {bool deleteFiles = true}) {
    final registry = loadRegistry();
    registry.remove(appId);

    final data = <String, dynamic>{
      for (final e in registry.entries) e.key: e.value.toJson(),
    };

    File(registryFilePath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

    if (deleteFiles) {
      final appDir = Directory(getAppInstallPath(appId));
      if (appDir.existsSync()) {
        try {
          appDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Discovers the primary binary/executable inside an application directory.
  String? findExecutableInDirectory(String dirPath, String fallbackName) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;

    if (Platform.isWindows) {
      final expectedExe = '$fallbackName.exe';

      // 1. Check direct match or recursive match
      final entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.exe') {
          if (p.basename(entity.path).toLowerCase() == expectedExe.toLowerCase()) {
            return entity.path;
          }
        }
      }

      // 2. Any .exe found in the root of the app directory
      for (final entity in entities) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.exe') {
          return entity.path;
        }
      }
    } else if (Platform.isMacOS) {
      final entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is Directory && entity.path.endsWith('.app')) {
          return entity.path;
        }
      }
    } else {
      // Linux: Look for file matching fallbackName
      final file = File(p.join(dirPath, fallbackName));
      if (file.existsSync()) return file.path;

      // Or any non-hidden executable file
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && !p.basename(entity.path).contains('.')) {
          return entity.path;
        }
      }
    }

    return null;
  }
}
