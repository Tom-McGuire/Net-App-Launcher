import 'dart:io';
import '../../core/constants.dart';
import '../../domain/models/dependency_info.dart';
import '../../domain/models/release_info.dart';
import '../../domain/models/suite_app.dart';
import '../services/app_installer_service.dart';
import '../services/app_runner_service.dart';
import '../services/dependency_service.dart';
import '../services/github_service.dart';
import '../services/local_app_registry.dart';

class SuiteRepository {
  final GitHubService _gitHubService;
  final LocalAppRegistry _registry;
  final AppInstallerService _installerService;
  final AppRunnerService _runnerService;
  final DependencyService _dependencyService;

  SuiteRepository({
    GitHubService? gitHubService,
    LocalAppRegistry? registry,
    AppInstallerService? installerService,
    AppRunnerService? runnerService,
    DependencyService? dependencyService,
  })  : _gitHubService = gitHubService ?? GitHubService(),
        _registry = registry ?? LocalAppRegistry(),
        _installerService = installerService ?? AppInstallerService(),
        _runnerService = runnerService ?? AppRunnerService(),
        _dependencyService = dependencyService ?? DependencyService();

  /// Checks whether a newer release of the Launcher itself is published on GitHub.
  Future<ReleaseInfo?> checkLauncherSelfUpdate() async {
    try {
      final release = await _gitHubService.fetchLatestRelease(SuiteConstants.launcherRepoName);
      if (release != null && release.tagName.isNotEmpty && release.tagName != SuiteConstants.currentVersion) {
        return release;
      }
    } catch (_) {}
    return null;
  }

  /// Loads suite applications, discovering which ones are publicly released on GitHub
  /// or installed locally.
  ///
  /// Per design, catalog apps returning 404 (private or unreleased) are hidden
  /// unless [includeUnreleased] is explicitly true.
  Future<List<SuiteApp>> loadSuiteApps({bool includeUnreleased = false}) async {
    final catalog = SuiteConstants.catalog;
    final installedMap = _registry.loadRegistry();

    // Query GitHub releases
    final releases = await _gitHubService.fetchAllPublicReleases(catalog);

    final apps = <SuiteApp>[];

    for (final def in catalog) {
      final release = releases[def.repoName] ?? releases[def.id];
      final installed = installedMap[def.id];
      final isPublic = release != null;

      // Check external CLI dependency if required
      DependencyInfo? depInfo;
      if (def.dependencyId != null && def.dependencyName != null) {
        depInfo = await _dependencyService.checkDependency(
          id: def.dependencyId!,
          name: def.dependencyName!,
          installCommand: def.dependencyInstallCmd ?? '',
        );
      }

      // Determine executable path
      String? exePath = installed?.executablePath;
      if (exePath == null && installed != null) {
        exePath = _registry.findExecutableInDirectory(installed.installPath, def.defaultExecutableName);
      }

      // Check if binary actually exists on disk
      final isInstalledLocally = exePath != null && File(exePath).existsSync();

      // Determine installation & update status
      AppStatus status = AppStatus.notInstalled;
      if (isInstalledLocally) {
        if (release != null && release.tagName != installed?.version) {
          status = AppStatus.updateAvailable;
        } else {
          status = AppStatus.installed;
        }
      } else if (isPublic) {
        status = AppStatus.notInstalled;
      }

      final isRunning = _runnerService.isAppRunning(def.id);

      final app = SuiteApp(
        definition: def,
        status: status,
        isPublic: isPublic,
        installedVersion: isInstalledLocally ? installed?.version : null,
        latestRelease: release,
        executablePath: isInstalledLocally ? exePath : null,
        dependencyInfo: depInfo,
        isRunning: isRunning,
      );

      // Only display tools that are publicly released or locally installed
      if (isPublic || isInstalledLocally || includeUnreleased) {
        apps.add(app);
      }
    }

    return apps;
  }

  /// Installs or updates a suite application.
  Future<String> installApp({
    required SuiteApp app,
    required DownloadProgressCallback onProgress,
    void Function(String message)? onStatusUpdate,
  }) async {
    final release = app.latestRelease;
    if (release == null) {
      throw Exception('Cannot install ${app.name}: No release available');
    }

    return _installerService.installOrUpdateApp(
      appId: app.id,
      defaultExecutableName: app.definition.defaultExecutableName,
      release: release,
      onProgress: onProgress,
      onStatusUpdate: onStatusUpdate,
    );
  }

  /// Launches a suite app.
  Future<Process> launchApp(SuiteApp app, {void Function()? onExited}) async {
    final exe = app.executablePath;
    if (exe == null || !File(exe).existsSync()) {
      throw Exception('Cannot launch ${app.name}: Executable not found');
    }

    return _runnerService.launchApp(
      appId: app.id,
      executablePath: exe,
      onExited: onExited,
    );
  }

  /// Uninstalls an application from local disk.
  void uninstallApp(String appId) {
    _registry.removeInstallation(appId, deleteFiles: true);
  }
}
