import 'dart:io';

class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String contentType;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? '',
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
      assets: rawAssets.map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Finds the binary asset archive matching the current desktop operating system.
  ReleaseAsset? findAssetForCurrentPlatform() {
    if (Platform.isWindows) {
      // Matches e.g. "ARP-Scout_windows_x64.zip" or any "*windows*.zip"
      return assets.cast<ReleaseAsset?>().firstWhere(
            (a) => a!.name.toLowerCase().contains('windows') && a.name.toLowerCase().endsWith('.zip'),
            orElse: () => assets.cast<ReleaseAsset?>().firstWhere(
              (a) => a!.name.toLowerCase().endsWith('.zip'),
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
}
