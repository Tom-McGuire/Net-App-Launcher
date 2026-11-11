import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../domain/models/network_adapter_option.dart';
import '../../domain/models/release_info.dart';
import '../../domain/models/suite_app.dart';
import '../../data/repositories/suite_repository.dart';

class LauncherViewModel extends ChangeNotifier {
  final SuiteRepository _repository;

  LauncherViewModel({SuiteRepository? repository})
      : _repository = repository ?? SuiteRepository() {
    loadApps();
    refreshAdapters();
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
  List<NetworkAdapterOption> _adapters = [];
  NetworkAdapterOption? _selectedAdapter;
  bool _hasUserSelectedAdapter = false;

  List<SuiteApp> get apps => _apps;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool get showUnreleased => _showUnreleased;
  String? get activeDownloadingAppId => _activeDownloadingAppId;
  double get activeDownloadProgress => _activeDownloadProgress;
  String? get activeStatusMessage => _activeStatusMessage;
  String? get errorMessage => _errorMessage;
  bool get isRateLimited => _repository.isRateLimited;
  DateTime? get rateLimitResetTime => _repository.rateLimitResetTime;
  List<NetworkAdapterOption> get adapters => _adapters;
  NetworkAdapterOption? get selectedAdapter => _selectedAdapter;

  String? get rateLimitResetDescription {
    final reset = _repository.rateLimitResetTime;
    if (reset == null) return null;
    final diff = reset.difference(DateTime.now());
    final timeStr = DateFormat('h:mm a').format(reset);
    if (diff.isNegative) {
      return 'Resets momentarily';
    } else if (diff.inMinutes > 0) {
      return 'Resets in ${diff.inMinutes + 1}m (at $timeStr)';
    } else {
      return 'Resets in ${diff.inSeconds}s (at $timeStr)';
    }
  }
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

  void setSelectedAdapter(NetworkAdapterOption? adapter) {
    _selectedAdapter = adapter;
    _hasUserSelectedAdapter = true;
    notifyListeners();
  }

  Future<void> refreshAdapters({
    Future<List<NetworkAdapterOption>> Function()? discoverFn,
  }) async {
    final list = await (discoverFn != null
        ? discoverFn()
        : NetworkAdapterOption.discoverAdapters());
    _adapters = list;
    if (_selectedAdapter != null) {
      if (!_adapters.contains(_selectedAdapter)) {
        _selectedAdapter = _adapters.firstOrNull;
      }
    } else if (!_hasUserSelectedAdapter) {
      _selectedAdapter = _adapters.firstOrNull;
    }
    notifyListeners();
  }

  void toggleShowUnreleased() {
    _showUnreleased = !_showUnreleased;
    loadApps();
  }

  Future<void> loadApps({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.loadSuiteApps(
          includeUnreleased: _showUnreleased,
          forceRefresh: forceRefresh,
        ),
        _repository.checkLauncherSelfUpdate(forceRefresh: forceRefresh),
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

    final launchArgs = <String>[
      if (_selectedAdapter != null) ...[
        '--adapter-ip',
        _selectedAdapter!.ipAddress,
        '--adapter-name',
        _selectedAdapter!.name,
      ],
    ];

    try {
      await _repository.launchApp(
        app,
        arguments: launchArgs,
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

  /// Terminates a currently running suite application.
  void stop(SuiteApp app) {
    _repository.terminateApp(app.id);
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx != -1) {
      _apps[idx] = _apps[idx].copyWith(isRunning: false);
      notifyListeners();
    }
  }

  /// Uninstalls a locally installed suite application.
  void uninstall(SuiteApp app) {
    _errorMessage = null;
    try {
      _repository.uninstallApp(app.id);
      final idx = _apps.indexWhere((a) => a.id == app.id);
      if (idx != -1) {
        final updated = _apps[idx];
        if (!updated.isPublic && !_showUnreleased) {
          _apps.removeAt(idx);
        } else {
          _apps[idx] = SuiteApp(
            definition: updated.definition,
            status: AppStatus.notInstalled,
            isPublic: updated.isPublic,
            installedVersion: null,
            latestRelease: updated.latestRelease,
            executablePath: null,
            dependencyInfo: updated.dependencyInfo,
            isRunning: false,
          );
        }
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to uninstall ${app.name}: $e';
      notifyListeners();
    }
  }
}
