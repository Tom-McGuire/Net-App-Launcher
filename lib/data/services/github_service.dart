import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../domain/models/release_info.dart';

class GitHubService {
  final http.Client _client;
  final String owner;
  final String? personalAccessToken;

  GitHubService({
    http.Client? client,
    this.owner = SuiteConstants.defaultGithubOwner,
    this.personalAccessToken,
  }) : _client = client ?? http.Client();

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
    final url = Uri.parse('https://api.github.com/repos/$owner/$repoName/releases/latest');

    try {
      final response = await _client.get(url, headers: _buildHeaders()).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        // Repo is private or has no releases published yet.
        return null;
      } else {
        // Other HTTP status (e.g. 403 Rate Limit)
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
