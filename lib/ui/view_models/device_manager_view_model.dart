import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/services/device_export_service.dart';

class DeviceManagerViewModel extends ChangeNotifier {
  final DeviceRepository _repository;
  StreamSubscription<void>? _changeSub;

  DeviceManagerViewModel({DeviceRepository? repository})
      : _repository = repository ?? DeviceRepository() {
    _init();
  }

  List<SharedDevice> _devices = [];
  int _totalCount = 0;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _hideDefaultNamed = true;
  String _sortBy = 'updated_at';
  bool _sortAscending = false;
  SharedDevice? _selectedDevice;
  String? _feedbackMessage;

  List<SharedDevice> get devices => _devices;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get hideDefaultNamed => _hideDefaultNamed;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  SharedDevice? get selectedDevice => _selectedDevice;
  String? get feedbackMessage => _feedbackMessage;

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.init();
      _changeSub = _repository.onDatabaseChanged.listen((_) {
        loadDevices();
      });
      loadDevices();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadDevices() {
    _devices = _repository.getAllDevices(
      query: _searchQuery,
      deviceType: _selectedCategory,
      hideDefaultNamed: _hideDefaultNamed,
      sortBy: _sortBy,
      ascending: _sortAscending,
    );
    _totalCount = _repository.getDeviceCount();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadDevices();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    loadDevices();
  }

  void setHideDefaultNamed(bool hide) {
    if (_hideDefaultNamed != hide) {
      _hideDefaultNamed = hide;
      loadDevices();
    }
  }

  void toggleHideDefaultNamed() {
    setHideDefaultNamed(!_hideDefaultNamed);
  }

  void setSorting(String column) {
    if (_sortBy == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = column;
      _sortAscending = true;
    }
    loadDevices();
  }

  void selectDevice(SharedDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  /// Updates only the friendly name of a device identified by its MAC address.
  /// Can be called at any point per requirements.
  void updateDeviceName(String mac, String newName) {
    if (newName.trim().isEmpty) return;

    _repository.updateDeviceName(mac, newName);
    _feedbackMessage = 'Updated name for $mac';
    loadDevices();

    if (_selectedDevice?.macAddress == SharedDevice.normalizeMac(mac)) {
      _selectedDevice = _repository.getDeviceByMac(mac);
    }
  }

  /// Adds or updates a device record.
  void addDevice({
    required String rawMac,
    required String name,
    String? category,
    String? vendor,
    String? notes,
  }) {
    if (!SharedDevice.isValidMac(rawMac)) {
      _feedbackMessage = 'Invalid MAC address format';
      notifyListeners();
      return;
    }

    final normalizedMac = SharedDevice.normalizeMac(rawMac);
    final resolvedVendor = (vendor != null && vendor.trim().isNotEmpty)
        ? vendor.trim()
        : OuiLookup.lookupVendor(normalizedMac);

    final resolvedCategory = (category != null && category.trim().isNotEmpty)
        ? category.trim()
        : OuiLookup.inferCategory(resolvedVendor, name).key;

    final now = DateTime.now();
    final device = SharedDevice(
      macAddress: normalizedMac,
      name: name.trim().isNotEmpty ? name.trim() : 'Device $normalizedMac',
      vendor: resolvedVendor,
      deviceType: resolvedCategory,
      notes: notes?.trim(),
      sourceApp: 'launcher',
      createdAt: now,
      updatedAt: now,
    );

    _repository.upsertDevice(device);
    _feedbackMessage = 'Device $normalizedMac added';
    loadDevices();
  }

  void deleteDevice(String mac) {
    _repository.deleteDevice(mac);
    if (_selectedDevice?.macAddress == SharedDevice.normalizeMac(mac)) {
      _selectedDevice = null;
    }
    _feedbackMessage = 'Deleted device $mac';
    loadDevices();
  }

  void importFromCsv(String csvContent) {
    try {
      final list = DeviceExportService.importFromCsv(csvContent);
      if (list.isNotEmpty) {
        _repository.importDevices(list);
        _feedbackMessage = 'Successfully imported ${list.length} devices from CSV';
        loadDevices();
      } else {
        _feedbackMessage = 'No valid device records found in CSV';
        notifyListeners();
      }
    } catch (e) {
      _feedbackMessage = 'Failed to parse CSV: $e';
      notifyListeners();
    }
  }

  void importFromJson(String jsonContent) {
    try {
      final list = DeviceExportService.importFromJson(jsonContent);
      if (list.isNotEmpty) {
        _repository.importDevices(list);
        _feedbackMessage = 'Successfully imported ${list.length} devices from JSON';
        loadDevices();
      } else {
        _feedbackMessage = 'No valid device records found in JSON';
        notifyListeners();
      }
    } catch (e) {
      _feedbackMessage = 'Failed to parse JSON: $e';
      notifyListeners();
    }
  }

  void setFeedbackMessage(String message) {
    _feedbackMessage = message;
    notifyListeners();
  }

  String exportCsv() => _repository.exportToCsv();
  String exportJson() => _repository.exportToJson();

  void clearFeedback() {
    _feedbackMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    super.dispose();
  }
}
