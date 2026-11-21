import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:path/path.dart' as p;
import '../../core/constants.dart';
import '../../domain/models/release_info.dart';

/// Represents a cached release with its HTTP ETag and retrieval timestamp.
class CachedReleaseEntry {
  final String repoName;
  final String? etag;
  final DateTime cachedAt;
  final Map<String, dynamic> rawJson;
  final ReleaseInfo release;

  CachedReleaseEntry({
    required this.repoName,
    this.etag,
    required this.cachedAt,
    required this.rawJson,
    ReleaseInfo? release,
  }) : release = release ?? ReleaseInfo.fromJson(rawJson);

  Map<String, dynamic> toJson() => {
        'repo_name': repoName,
        'etag': etag,
        'cached_at': cachedAt.toIso8601String(),
        'raw_json': rawJson,
      };

  factory CachedReleaseEntry.fromJson(Map<String, dynamic> json) {
    final raw = (json['raw_json'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CachedReleaseEntry(
      repoName: json['repo_name'] as String? ?? '',
      etag: json['etag'] as String?,
      cachedAt: DateTime.tryParse(json['cached_at'] as String? ?? '') ?? DateTime.now(),
      rawJson: raw,
      release: ReleaseInfo.fromJson(raw),
    );
  }
}

class GitHubService {
  static final RegExp _safeIdentifierRegex = RegExp(r'^[A-Za-z0-9_.\-]+$');

  final http.Client _client;
  final String owner;
  final String? _customCacheDir;
  final Duration cacheTtl;
  String? personalAccessToken;
  bool _isRateLimited = false;
  DateTime? _rateLimitResetTime;
  final Map<String, CachedReleaseEntry> _cache = {};
  final Map<String, String?> _manualPdfCache = {};

  GitHubService({
    http.Client? client,
    this.owner = SuiteConstants.defaultGithubOwner,
    this.personalAccessToken,
    String? customCacheDir,
    this.cacheTtl = const Duration(minutes: 15),
  })  : _client = client ?? http.Client(),
        _customCacheDir = customCacheDir {
    _loadCacheFromDisk();
  }

  bool get isRateLimited => _isRateLimited;
  DateTime? get rateLimitResetTime => _rateLimitResetTime;
  Map<String, CachedReleaseEntry> get cache => Map.unmodifiable(_cache);

  String? get cacheFilePath {
    try {
      final base = _customCacheDir ?? SharedDeviceDatabase.getDefaultDirectoryPath();
      return p.join(base, 'github_releases_cache.json');
    } catch (_) {
      return null;
    }
  }

  void _loadCacheFromDisk() {
    try {
      final path = cacheFilePath;
      if (path == null) return;
      final file = File(path);
      if (!file.existsSync()) return;

      final contents = file.readAsStringSync();
      if (contents.trim().isEmpty) return;

      final Map<String, dynamic> decoded = jsonDecode(contents) as Map<String, dynamic>;
      final entries = decoded['entries'] as Map<String, dynamic>? ?? {};

      for (final entry in entries.entries) {
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          final cachedEntry = CachedReleaseEntry.fromJson(val);
          if (cachedEntry.repoName.isNotEmpty) {
            _cache[cachedEntry.repoName] = cachedEntry;
          }
        }
      }
    } catch (_) {
      // Ignore cache load failure
    }
  }

  void _saveCacheToDisk() {
    try {
      final path = cacheFilePath;
      if (path == null) return;
      final file = File(path);
      file.parent.createSync(recursive: true);

      final data = {
        'version': 1,
        'saved_at': DateTime.now().toIso8601String(),
        'entries': _cache.map((k, v) => MapEntry(k, v.toJson())),
      };
      file.writeAsStringSync(jsonEncode(data), flush: true);
    } catch (_) {
      // Ignore disk writing errors
    }
  }

  void clearCache() {
    _cache.clear();
    _manualPdfCache.clear();
    try {
      final path = cacheFilePath;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    } catch (_) {}
  }

  Map<String, String> _buildHeaders() {
    final headers = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'NetworkSuiteLauncher/1.0.0',
    };
    if (personalAccessToken != null && personalAccessToken!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${personalAccessToken!.trim()}';
    }
    return headers;
  }

  void _checkRateLimitHeaders(http.Response response) {
    final remaining = response.headers['x-ratelimit-remaining'];
    final reset = response.headers['x-ratelimit-reset'];

    if (reset != null) {
      final epochSec = int.tryParse(reset);
      if (epochSec != null) {
        _rateLimitResetTime = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000, isUtc: true).toLocal();
      }
    }

    if (remaining == '0' ||
        response.statusCode == 429 ||
        (response.statusCode == 403 &&
            (response.body.toLowerCase().contains('rate limit') || remaining == '0'))) {
      _isRateLimited = true;
    } else if (remaining != null && int.tryParse(remaining) != null && int.parse(remaining) > 0) {
      if (response.statusCode != 403 && response.statusCode != 429) {
        _isRateLimited = false;
      }
    }
  }

  /// Fetches the latest published release for a specific repository.
  ///
  /// Utilizes in-memory and disk caching with [cacheTtl] and conditional requests (HTTP ETag / If-None-Match)
  /// to minimize network calls and conserve the GitHub API 60 req/hr per IP rate limit.
  Future<ReleaseInfo?> fetchLatestRelease(
    String repoName, {
    bool forceRefresh = false,
  }) async {
    if (!_safeIdentifierRegex.hasMatch(owner) || !_safeIdentifierRegex.hasMatch(repoName)) {
      return null;
    }

    final cached = _cache[repoName];
    final now = DateTime.now();

    // 1. Return fresh cached release without making an HTTP request
    if (cached != null && !forceRefresh && now.difference(cached.cachedAt) < cacheTtl) {
      return cached.release;
    }

    // 2. Prepare headers with ETag if available for conditional check (304 Not Modified)
    final headers = _buildHeaders();
    if (cached?.etag != null && cached!.etag!.isNotEmpty) {
      headers['If-None-Match'] = cached.etag!;
    }

    final url = Uri.https('api.github.com', '/repos/$owner/$repoName/releases/latest');

    try {
      final response = await _client.get(url, headers: headers).timeout(
            const Duration(seconds: 8),
          );

      _checkRateLimitHeaders(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final etag = response.headers['etag'];
        final entry = CachedReleaseEntry(
          repoName: repoName,
          etag: etag,
          cachedAt: now,
          rawJson: data,
        );
        _cache[repoName] = entry;
        _saveCacheToDisk();
        return entry.release;
      } else if (response.statusCode == 304) {
        // ETag matched: release content has not changed
        if (cached != null) {
          _cache[repoName] = CachedReleaseEntry(
            repoName: repoName,
            etag: cached.etag,
            cachedAt: now,
            rawJson: cached.rawJson,
            release: cached.release,
          );
          _saveCacheToDisk();
          return cached.release;
        }
        return null;
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        _isRateLimited = true;
        // Graceful degradation: serve cached release data if present
        if (cached != null) {
          return cached.release;
        }
        return null;
      } else if (response.statusCode == 404) {
        // Repo is private or has no releases published yet.
        return null;
      } else {
        return cached?.release;
      }
    } catch (_) {
      return cached?.release;
    }
  }

  /// Discovers releases for all catalog applications.
  /// Returns a map of `appId -> ReleaseInfo`.
  Future<Map<String, ReleaseInfo>> fetchAllPublicReleases(
    List<AppCatalogDefinition> catalog, {
    bool forceRefresh = false,
  }) async {
    final results = <String, ReleaseInfo>{};

    final futures = catalog.map((app) async {
      final release = await fetchLatestRelease(app.repoName, forceRefresh: forceRefresh);
      if (release != null) {
        results[app.id] = release;
      }
    });

    await Future.wait(futures);
    return results;
  }

  static bool _isValidPdfLink(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    return uri.path.toLowerCase().endsWith('.pdf');
  }

  static bool _isPdfResponseContentType(String? contentType) {
    if (contentType == null || contentType.trim().isEmpty) return true;
    final lower = contentType.toLowerCase().split(';').first.trim();
    return lower == 'application/pdf' ||
        lower == 'application/octet-stream' ||
        lower == 'binary/octet-stream';
  }

  /// Resolves a verified PDF manual URL for [app], checking any attached `.pdf`
  /// release asset first and then verifying the repo's candidate manual URL
  /// (`HEAD` 200 + PDF-compatible content-type). Returns `null` if unavailable.
  Future<String?> resolveManualPdfUrl(
    AppCatalogDefinition app, {
    ReleaseInfo? release,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _manualPdfCache.containsKey(app.id)) {
      return _manualPdfCache[app.id];
    }

    final assetUrl = release?.findManualPdfAsset()?.downloadUrl;
    if (_isValidPdfLink(assetUrl)) {
      final resolved = assetUrl!.trim();
      _manualPdfCache[app.id] = resolved;
      return resolved;
    }

    final candidate = app.effectiveManualUrl;
    if (!_isValidPdfLink(candidate)) {
      _manualPdfCache[app.id] = null;
      return null;
    }

    try {
      final uri = Uri.parse(candidate);
      final headers = <String, String>{'User-Agent': 'NetworkSuiteLauncher/1.0'};
      if (personalAccessToken != null && personalAccessToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $personalAccessToken';
      }
      final response = await _client
          .head(uri, headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 &&
          _isPdfResponseContentType(response.headers['content-type'])) {
        _manualPdfCache[app.id] = candidate;
        return candidate;
      }
    } catch (_) {
      // Network/timeout errors leave manual unavailable without blocking app discovery
    }

    _manualPdfCache[app.id] = null;
    return null;
  }

  /// Downloads the raw PDF bytes from [url].
  Future<List<int>> downloadManualBytes(String url) async {
    if (!_isValidPdfLink(url)) {
      throw Exception('Invalid PDF manual URL: $url');
    }
    final uri = Uri.parse(url.trim());
    final headers = <String, String>{'User-Agent': 'NetworkSuiteLauncher/1.0'};
    if (personalAccessToken != null && personalAccessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $personalAccessToken';
    }
    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Failed to download manual (HTTP ${response.statusCode})');
    }
    return response.bodyBytes;
  }
}
