import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../domain/models/release_info.dart';
import '../../domain/models/suite_app.dart';
import '../../data/repositories/suite_repository.dart';

class LauncherViewModel extends ChangeNotifier {
  final SuiteRepository _repository;

  LauncherViewModel({SuiteRepository? repository})
      : _repository = repository ?? SuiteRepository() {
    loadApps();
  }

  List<SuiteApp> _apps = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _showUnreleased = false;
  String? _activeDownloadingAppId;
  double _activeDownloadProgress = 0.0;
  String? _activeStatusMessage;
  String? _errorMessage;
  int _selectedTabIndex = 0;
  ReleaseInfo? _launcherSelfUpdate;

  List<SuiteApp> get apps => _apps;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool get showUnreleased => _showUnreleased;
  String? get activeDownloadingAppId => _activeDownloadingAppId;
  double get activeDownloadProgress => _activeDownloadProgress;
  String? get activeStatusMessage => _activeStatusMessage;
  String? get errorMessage => _errorMessage;
  int get selectedTabIndex => _selectedTabIndex;
  ReleaseInfo? get launcherSelfUpdate => _launcherSelfUpdate;
  bool get isLauncherUpdateAvailable => _launcherSelfUpdate != null;

  /// Returns filtered list of applications based on search and category filter.
  List<SuiteApp> get filteredApps {
    return _apps.where((app) {
      if (_selectedCategory != null &&
          _selectedCategory != 'All' &&
          app.category != _selectedCategory) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesName = app.name.toLowerCase().contains(q);
        final matchesSummary = app.summary.toLowerCase().contains(q);
        final matchesCategory = app.category.toLowerCase().contains(q);
        if (!matchesName && !matchesSummary && !matchesCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Available categories derived from the catalog.
  List<String> get availableCategories {
    final categories = {'All'};
    for (final def in SuiteConstants.catalog) {
      categories.add(def.category);
    }
    return categories.toList();
  }

  void switchTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleShowUnreleased() {
    _showUnreleased = !_showUnreleased;
    loadApps();
  }

  Future<void> loadApps() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.loadSuiteApps(includeUnreleased: _showUnreleased),
        _repository.checkLauncherSelfUpdate(),
      ]);
      _apps = results[0] as List<SuiteApp>;
      _launcherSelfUpdate = results[1] as ReleaseInfo?;
    } catch (e) {
      _errorMessage = 'Failed to discover suite applications: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> installOrUpdate(SuiteApp app) async {
    if (_activeDownloadingAppId != null) return;

    _activeDownloadingAppId = app.id;
    _activeDownloadProgress = 0.0;
    _activeStatusMessage = 'Initializing download...';
    _errorMessage = null;

    // Update app status locally to downloading
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx != -1) {
      _apps[idx] = app.copyWith(
        status: AppStatus.downloading,
        downloadProgress: 0.0,
        statusMessage: _activeStatusMessage,
      );
      notifyListeners();
    }

    try {
      final exePath = await _repository.installApp(
        app: app,
        onProgress: (progress, received, total) {
          _activeDownloadProgress = progress;
          if (idx != -1) {
            _apps[idx] = _apps[idx].copyWith(
              downloadProgress: progress,
              statusMessage: 'Downloading: ${(progress * 100).toStringAsFixed(0)}%',
            );
            notifyListeners();
          }
        },
        onStatusUpdate: (msg) {
          _activeStatusMessage = msg;
          if (idx != -1) {
            _apps[idx] = _apps[idx].copyWith(statusMessage: msg);
            notifyListeners();
          }
        },
      );

      // Successfully installed
      if (idx != -1) {
        _apps[idx] = _apps[idx].copyWith(
          status: AppStatus.installed,
          installedVersion: app.latestRelease?.tagName,
          executablePath: exePath,
          downloadProgress: 1.0,
          statusMessage: 'Ready to launch',
        );
      }
    } catch (e) {
      _errorMessage = 'Installation of ${app.name} failed: $e';
      if (idx != -1) {
        _apps[idx] = _apps[idx].copyWith(
          status: AppStatus.error,
          statusMessage: e.toString(),
        );
      }
    } finally {
      _activeDownloadingAppId = null;
      _activeDownloadProgress = 0.0;
      _activeStatusMessage = null;
      notifyListeners();
    }
  }

  Future<void> launch(SuiteApp app) async {
    _errorMessage = null;

    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx != -1) {
      _apps[idx] = _apps[idx].copyWith(isRunning: true);
      notifyListeners();
    }

    try {
      await _repository.launchApp(
        app,
        onExited: () {
          final curIdx = _apps.indexWhere((a) => a.id == app.id);
          if (curIdx != -1) {
            _apps[curIdx] = _apps[curIdx].copyWith(isRunning: false);
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to launch ${app.name}: $e';
      if (idx != -1) {
        _apps[idx] = _apps[idx].copyWith(isRunning: false);
      }
      notifyListeners();
    }
  }
}
