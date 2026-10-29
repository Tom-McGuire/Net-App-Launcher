import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../domain/models/release_info.dart';
import 'local_app_registry.dart';

typedef DownloadProgressCallback = void Function(double progress, int bytesReceived, int totalBytes);

class AppInstallerService {
  final LocalAppRegistry registry;
  final http.Client _client;

  AppInstallerService({
    LocalAppRegistry? localRegistry,
    http.Client? client,
  })  : registry = localRegistry ?? LocalAppRegistry(),
        _client = client ?? http.Client();

  /// Downloads the release asset and unpacks it into the target app directory.
  Future<String> installOrUpdateApp({
    required String appId,
    required String defaultExecutableName,
    required ReleaseInfo release,
    required DownloadProgressCallback onProgress,
    void Function(String message)? onStatusUpdate,
  }) async {
    final asset = release.findAssetForCurrentPlatform();
    if (asset == null || asset.downloadUrl.isEmpty) {
      throw Exception('No compatible release binary found for current operating system.');
    }

    onStatusUpdate?.call('Downloading ${asset.name}...');
    final targetDir = registry.getAppInstallPath(appId);
    final tempDir = Directory.systemTemp.createTempSync('net_suite_dl_');
    final tempFilePath = p.join(tempDir.path, asset.name);

    try {
      // 1. Stream download
      await _downloadFile(asset.downloadUrl, tempFilePath, onProgress);

      // 2. Extraction
      onStatusUpdate?.call('Extracting application bundle...');
      final destinationDir = Directory(targetDir);
      if (destinationDir.existsSync()) {
        try {
          destinationDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      destinationDir.createSync(recursive: true);

      await _extractArchive(tempFilePath, destinationDir.path);

      // 3. Locate executable
      final exePath = registry.findExecutableInDirectory(destinationDir.path, defaultExecutableName);
      if (exePath == null) {
        throw Exception('Application extracted successfully, but executable could not be identified in $targetDir');
      }

      // On Unix systems, ensure executable permission
      if (!Platform.isWindows) {
        try {
          Process.runSync('chmod', ['+x', exePath]);
        } catch (_) {}
      }

      // 4. Save to local app registry
      registry.recordInstallation(
        InstalledAppRecord(
          appId: appId,
          version: release.tagName,
          installPath: destinationDir.path,
          executablePath: exePath,
          installedAt: DateTime.now(),
        ),
      );

      onStatusUpdate?.call('Installation complete');
      return exePath;
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _downloadFile(
    String url,
    String savePath,
    DownloadProgressCallback onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'NetworkSuiteLauncher/1.0.0';
    final response = await _client.send(request);

    if (response.statusCode >= 400) {
      throw Exception('Failed to download asset: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    var receivedBytes = 0;
    final file = File(savePath);
    final sink = file.openWrite();

    try {
      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
        } else {
          onProgress(0.0, receivedBytes, 0);
        }
      }).asFuture();
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Future<void> _extractArchive(String archivePath, String destinationPath) async {
    final bytes = File(archivePath).readAsBytesSync();

    if (archivePath.toLowerCase().endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = p.join(destinationPath, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }
    } else if (archivePath.toLowerCase().endsWith('.tar.gz') ||
        archivePath.toLowerCase().endsWith('.tgz')) {
      final tarBytes = GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(tarBytes);
      for (final file in archive) {
        final filename = p.join(destinationPath, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(filename).createSync(recursive: true);
        }
      }
    } else {
      throw Exception('Unsupported archive format for $archivePath');
    }
  }
}
