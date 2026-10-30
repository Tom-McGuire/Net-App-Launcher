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
  static const Set<String> _ignoredWindowsBinaries = {
    'unins000.exe',
    'uninstall.exe',
    'crashpad_handler.exe',
    'vc_redist.x64.exe',
    'vc_redist.x86.exe',
  };

  static const Set<String> _ignoredLinuxFiles = {
    'license',
    'readme',
    'changelog',
    'authors',
    'notice',
    'copying',
    'makefile',
    'dockerfile',
    'version',
    'patents',
  };

  final String _baseDir;

  LocalAppRegistry({String? customBaseDir})
      : _baseDir = customBaseDir ?? SharedDeviceDatabase.getDefaultDirectoryPath();

  String get appsDirectory => p.join(_baseDir, 'apps');
  String get registryFilePath => p.join(_baseDir, 'installed_apps.json');

  /// Validates and returns the install folder for a specific [appId].
  String getAppInstallPath(String appId) {
    final sanitizedId = p.basename(appId.trim());
    if (sanitizedId.isEmpty || sanitizedId != appId.trim() || sanitizedId.contains('..')) {
      throw ArgumentError.value(appId, 'appId', 'Invalid application identifier');
    }
    return p.join(appsDirectory, sanitizedId);
  }

  /// Checks whether an executable file or macOS `.app` bundle exists on disk.
  static bool executableExists(String? executablePath) {
    if (executablePath == null || executablePath.trim().isEmpty) return false;
    if (File(executablePath).existsSync()) return true;
    if (Platform.isMacOS &&
        executablePath.toLowerCase().endsWith('.app') &&
        Directory(executablePath).existsSync()) {
      return true;
    }
    return false;
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

    final dir = Directory(_baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

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
      final expectedExe = '$fallbackName.exe'.toLowerCase();

      // 1. Check direct match in root first
      final rootCandidate = File(p.join(dirPath, '$fallbackName.exe'));
      if (rootCandidate.existsSync()) {
        return rootCandidate.path;
      }

      // 2. Check recursive match for exact expected executable name
      final allEntities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in allEntities) {
        if (entity is File && p.basename(entity.path).toLowerCase() == expectedExe) {
          return entity.path;
        }
      }

      // 3. Fallback: Only check top-level .exe files (excluding known helper/uninstaller binaries)
      final topLevelEntities = dir.listSync(recursive: false, followLinks: false);
      for (final entity in topLevelEntities) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.exe') {
          final base = p.basename(entity.path).toLowerCase();
          if (!_ignoredWindowsBinaries.contains(base)) {
            return entity.path;
          }
        }
      }
    } else if (Platform.isMacOS) {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is Directory && entity.path.endsWith('.app')) {
          // Prefer inner Mach-O executable if it matches fallbackName
          final innerExe = File(p.join(entity.path, 'Contents', 'MacOS', fallbackName));
          if (innerExe.existsSync()) {
            return innerExe.path;
          }
          final macosDir = Directory(p.join(entity.path, 'Contents', 'MacOS'));
          if (macosDir.existsSync()) {
            final bins = macosDir.listSync(followLinks: false).whereType<File>().toList();
            if (bins.length == 1) {
              return bins.first.path;
            }
          }
          return entity.path;
        }
      }
    } else {
      // Linux: Look for file matching fallbackName in root or subdirectories
      final rootFile = File(p.join(dirPath, fallbackName));
      if (rootFile.existsSync()) return rootFile.path;

      final allEntities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in allEntities) {
        if (entity is File && p.basename(entity.path) == fallbackName) {
          return entity.path;
        }
      }

      // Fallback: top-level non-hidden file without extension that is not a known text/doc file
      final topEntities = dir.listSync(recursive: false, followLinks: false);
      for (final entity in topEntities) {
        if (entity is File) {
          final base = p.basename(entity.path);
          if (!base.startsWith('.') &&
              !base.contains('.') &&
              !_ignoredLinuxFiles.contains(base.toLowerCase())) {
            return entity.path;
          }
        }
      }
    }

    return null;
  }
}
