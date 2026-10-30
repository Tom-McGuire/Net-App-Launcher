import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../domain/models/release_info.dart';

class GitHubService {
  static final RegExp _safeIdentifierRegex = RegExp(r'^[A-Za-z0-9_.\-]+$');

  final http.Client _client;
  final String owner;
  String? personalAccessToken;
  bool _isRateLimited = false;

  GitHubService({
    http.Client? client,
    this.owner = SuiteConstants.defaultGithubOwner,
    this.personalAccessToken,
  }) : _client = client ?? http.Client();

  bool get isRateLimited => _isRateLimited;

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

  /// Fetches the latest published release for a specific repository.
  ///
  /// Returns `null` if the repository is private, has no releases, or returns 404,
  /// ensuring only publicly available tools are displayed in the Launcher.
  Future<ReleaseInfo?> fetchLatestRelease(String repoName) async {
    if (!_safeIdentifierRegex.hasMatch(owner) || !_safeIdentifierRegex.hasMatch(repoName)) {
      return null;
    }

    final url = Uri.https('api.github.com', '/repos/$owner/$repoName/releases/latest');

    try {
      final response = await _client.get(url, headers: _buildHeaders()).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        final remaining = response.headers['x-ratelimit-remaining'];
        if (remaining == '0' || response.statusCode == 429 || response.body.toLowerCase().contains('rate limit')) {
          _isRateLimited = true;
        }
        return null;
      } else if (response.statusCode == 404) {
        // Repo is private or has no releases published yet.
        return null;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Discovers releases for all catalog applications.
  /// Returns a map of `appId -> ReleaseInfo`.
  Future<Map<String, ReleaseInfo>> fetchAllPublicReleases(
    List<AppCatalogDefinition> catalog,
  ) async {
    _isRateLimited = false;
    final results = <String, ReleaseInfo>{};

    final futures = catalog.map((app) async {
      final release = await fetchLatestRelease(app.repoName);
      if (release != null) {
        results[app.id] = release;
      }
    });

    await Future.wait(futures);
    return results;
  }
}
