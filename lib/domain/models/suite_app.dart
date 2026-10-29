import '../../core/constants.dart';
import 'dependency_info.dart';
import 'release_info.dart';

enum AppStatus {
  checking,
  notInstalled,
  downloading,
  extracting,
  installed,
  updateAvailable,
  error,
}

class SuiteApp {
  final AppCatalogDefinition definition;
  final AppStatus status;
  final bool isPublic;
  final String? installedVersion;
  final ReleaseInfo? latestRelease;
  final double downloadProgress; // 0.0 to 1.0
  final String? statusMessage;
  final String? executablePath;
  final DependencyInfo? dependencyInfo;
  final bool isRunning;

  const SuiteApp({
    required this.definition,
    this.status = AppStatus.checking,
    this.isPublic = false,
    this.installedVersion,
    this.latestRelease,
    this.downloadProgress = 0.0,
    this.statusMessage,
    this.executablePath,
    this.dependencyInfo,
    this.isRunning = false,
  });

  String get id => definition.id;
  String get name => definition.name;
  String get category => definition.category;
  String get summary => definition.summary;

  bool get canLaunch =>
      (status == AppStatus.installed || status == AppStatus.updateAvailable) &&
      executablePath != null &&
      executablePath!.isNotEmpty;

  bool get hasUpdate => status == AppStatus.updateAvailable;

  SuiteApp copyWith({
    AppCatalogDefinition? definition,
    AppStatus? status,
    bool? isPublic,
    String? installedVersion,
    ReleaseInfo? latestRelease,
    double? downloadProgress,
    String? statusMessage,
    String? executablePath,
    DependencyInfo? dependencyInfo,
    bool? isRunning,
  }) {
    return SuiteApp(
      definition: definition ?? this.definition,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      installedVersion: installedVersion ?? this.installedVersion,
      latestRelease: latestRelease ?? this.latestRelease,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      statusMessage: statusMessage ?? this.statusMessage,
      executablePath: executablePath ?? this.executablePath,
      dependencyInfo: dependencyInfo ?? this.dependencyInfo,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
