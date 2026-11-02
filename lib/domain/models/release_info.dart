import 'dart:io';
import 'package:pub_semver/pub_semver.dart';

class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String contentType;
  final String? digest;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.contentType,
    this.digest,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? '',
      digest: json['digest'] as String?,
    );
  }
}

class ReleaseInfo {
  final String tagName;
  final String name;
  final DateTime publishedAt;
  final String body;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.publishedAt,
    required this.body,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'] as List<dynamic>? ?? [];
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      body: json['body'] as String? ?? '',
      assets: rawAssets
          .whereType<Map<String, dynamic>>()
          .map(ReleaseAsset.fromJson)
          .toList(),
    );
  }

  /// Parses a version tag (e.g. "v1.2.0", "1.2.0", or "v0.5.0.Beta") into a [Version], or null if invalid.
  static Version? tryParseVersion(String rawVersion) {
    var cleaned = rawVersion.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }
    if (cleaned.isEmpty) return null;
    // Normalize e.g. "0.5.0.Beta" -> "0.5.0-Beta" for semver compatibility
    cleaned = cleaned.replaceFirstMapped(
      RegExp(r'^(\d+\.\d+\.\d+)\.([A-Za-z][A-Za-z0-9.\-]*)$'),
      (m) => '${m[1]}-${m[2]}',
    );
    try {
      return Version.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [tagName] represents a newer semantic version than [currentVersion].
  bool isNewerThan(String? currentVersion) {
    if (currentVersion == null || currentVersion.trim().isEmpty) return true;
    if (tagName.trim().isEmpty) return false;

    final remoteVer = tryParseVersion(tagName);
    final localVer = tryParseVersion(currentVersion);

    if (remoteVer != null && localVer != null) {
      return remoteVer > localVer;
    }
    // Fallback if non-semver tags are used
    return tagName.trim() != currentVersion.trim();
  }

  /// Finds the binary asset archive matching the current desktop operating system.
  ReleaseAsset? findAssetForCurrentPlatform() {
    if (Platform.isWindows) {
      // Matches e.g. "ARP-Scout_windows_x64.zip" or any "*windows*.zip"
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) => a!.name.toLowerCase().contains('windows') && a.name.toLowerCase().endsWith('.zip'),
            orElse: () => assets.cast<ReleaseAsset?>().firstWhere(
              (a) => a!.name.toLowerCase().endsWith('.zip') && !a.name.toLowerCase().contains('macos') && !a.name.toLowerCase().contains('linux'),
              orElse: () => null,
            ),
          );
    } else if (Platform.isMacOS) {
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) => a!.name.toLowerCase().contains('macos') && a.name.toLowerCase().endsWith('.zip'),
            orElse: () => null,
          );
    } else if (Platform.isLinux) {
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) =>
                a!.name.toLowerCase().contains('linux') &&
                (a.name.toLowerCase().endsWith('.tar.gz') || a.name.toLowerCase().endsWith('.zip')),
            orElse: () => null,
          );
    }
    return null;
  }

  /// Finds an installer package (e.g. Windows Setup .exe, macOS .dmg, Linux .deb) matching the current platform.
  ReleaseAsset? findInstallerForCurrentPlatform() {
    if (Platform.isWindows) {
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) =>
                a!.name.toLowerCase().contains('setup') &&
                a.name.toLowerCase().endsWith('.exe'),
            orElse: () => assets.cast<ReleaseAsset?>().firstWhere(
              (a) =>
                  a!.name.toLowerCase().endsWith('.exe') &&
                  !a.name.toLowerCase().contains('unins'),
              orElse: () => null,
            ),
          );
    } else if (Platform.isMacOS) {
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) => a!.name.toLowerCase().endsWith('.dmg'),
            orElse: () => null,
          );
    } else if (Platform.isLinux) {
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) => a!.name.toLowerCase().endsWith('.deb'),
            orElse: () => null,
          );
    }
    return null;
  }

  /// Finds the preferred launcher asset for updating the launcher itself.
  /// Prefers installers (.exe setup, .dmg, .deb), falling back to portable archives (.zip, .tar.gz).
  ReleaseAsset? findLauncherAssetForCurrentPlatform() {
    return findInstallerForCurrentPlatform() ?? findAssetForCurrentPlatform();
  }
}
