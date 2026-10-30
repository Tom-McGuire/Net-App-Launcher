import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../domain/models/release_info.dart';
import 'local_app_registry.dart';

typedef DownloadProgressCallback = void Function(double progress, int bytesReceived, int totalBytes);

class AppInstallerService {
  static const Set<String> _trustedHosts = {
    'github.com',
    'api.github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
    'codeload.github.com',
  };

  final LocalAppRegistry registry;
  final http.Client _client;
  final bool allowUntrustedHosts;

  AppInstallerService({
    LocalAppRegistry? localRegistry,
    http.Client? client,
    this.allowUntrustedHosts = false,
  })  : registry = localRegistry ?? LocalAppRegistry(),
        _client = client ?? http.Client();

  /// Validates that [url] is a well-formed HTTPS URL from a trusted GitHub domain.
  static bool isTrustedDownloadUrl(String url, {bool allowUntrustedHosts = false}) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (allowUntrustedHosts) return true;

    final host = uri.host.toLowerCase();
    if (_trustedHosts.contains(host)) return true;
    if (host.endsWith('.github.com') || host.endsWith('.githubusercontent.com')) {
      return true;
    }
    return false;
  }

  /// Verifies the SHA-256 digest of a downloaded file against [expectedDigest].
  /// Supports `sha256:<hex>` or raw 64-character hex strings.
  static bool verifyFileSha256(String filePath, String expectedDigest) {
    var cleanExpected = expectedDigest.trim().toLowerCase();
    if (cleanExpected.startsWith('sha256:')) {
      cleanExpected = cleanExpected.substring('sha256:'.length).trim();
    }
    if (cleanExpected.isEmpty) return false;

    final bytes = File(filePath).readAsBytesSync();
    final actualDigest = sha256.convert(bytes).toString().toLowerCase();
    return actualDigest == cleanExpected;
  }

  /// Downloads the release asset, verifies integrity, and unpacks it into the target app directory.
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

    if (!isTrustedDownloadUrl(asset.downloadUrl, allowUntrustedHosts: allowUntrustedHosts)) {
      throw SecurityException('Blocked download from untrusted or non-HTTPS URL: ${asset.downloadUrl}');
    }

    final safeAssetName = p.basename(asset.name.trim());
    if (safeAssetName.isEmpty || safeAssetName == '.' || safeAssetName == '..') {
      throw SecurityException('Invalid release asset filename: ${asset.name}');
    }

    onStatusUpdate?.call('Downloading $safeAssetName...');
    final targetDir = registry.getAppInstallPath(appId);
    final tempDir = Directory.systemTemp.createTempSync('net_suite_dl_');
    final tempFilePath = p.join(tempDir.path, safeAssetName);

    try {
      // 1. Stream download
      await _downloadFile(asset.downloadUrl, tempFilePath, onProgress);

      // 2. Integrity & checksum verification
      final downloadedFile = File(tempFilePath);
      if (asset.sizeBytes > 0) {
        final actualSize = downloadedFile.lengthSync();
        if (actualSize != asset.sizeBytes) {
          throw SecurityException(
            'Downloaded file size mismatch (expected ${asset.sizeBytes} bytes, got $actualSize bytes).',
          );
        }
      }

      if (asset.digest != null && asset.digest!.trim().isNotEmpty) {
        onStatusUpdate?.call('Verifying SHA-256 checksum...');
        final isValid = await Isolate.run(
          () => verifyFileSha256(tempFilePath, asset.digest!),
        );
        if (!isValid) {
          throw SecurityException('SHA-256 checksum verification failed for $safeAssetName.');
        }
      }

      // 3. Safe Extraction on background Isolate
      onStatusUpdate?.call('Extracting application bundle...');
      final destinationDir = Directory(targetDir);
      if (destinationDir.existsSync()) {
        try {
          destinationDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      destinationDir.createSync(recursive: true);

      final destPath = destinationDir.path;
      await Isolate.run(() => extractArchiveSafely(tempFilePath, destPath));

      // 4. Locate executable
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

      // 5. Save to local app registry
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

  /// Extracts a `.zip`, `.tar.gz`, or `.tgz` archive into [destinationPath]
  /// while enforcing strict Zip Slip (path traversal) containment checks.
  static void extractArchiveSafely(String archivePath, String destinationPath) {
    final canonicalDest = p.canonicalize(destinationPath);
    final bytes = File(archivePath).readAsBytesSync();
    final lowerPath = archivePath.toLowerCase();

    late final Archive archive;
    if (lowerPath.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
      final tarBytes = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(tarBytes);
    } else {
      throw Exception('Unsupported archive format for $archivePath');
    }

    for (final entry in archive) {
      final entryName = entry.name.replaceAll('\\', '/');

      // Reject absolute paths, drive letters, or parent directory segments immediately
      final segments = p.posix.split(entryName);
      if (p.posix.isAbsolute(entryName) ||
          entryName.contains(':') ||
          segments.contains('..')) {
        throw SecurityException('Archive entry contains forbidden path traversal: ${entry.name}');
      }

      final resolvedPath = p.canonicalize(p.join(canonicalDest, entryName));
      if (!p.isWithin(canonicalDest, resolvedPath) && resolvedPath != canonicalDest) {
        throw SecurityException('Archive entry escapes destination directory: ${entry.name}');
      }

      if (entry.isSymbolicLink) {
        // Ignore symbolic links in release archives to prevent symlink traversal attacks
        continue;
      }

      if (entry.isFile) {
        final outFile = File(resolvedPath);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(resolvedPath).createSync(recursive: true);
      }
    }
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
