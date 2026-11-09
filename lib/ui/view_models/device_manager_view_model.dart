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
  List<UnifiedDeviceCategory> _categories = [];
  List<CustomDeviceCategory> _customCategories = [];
  int _totalCount = 0;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _hideDefaultNamed = true;
  String _sortBy = 'updated_at';
  bool _sortAscending = false;
  SharedDevice? _selectedDevice;
  String? _feedbackMessage;
  final Set<String> _selectedMacs = {};

  List<SharedDevice> get devices => _devices;
  List<UnifiedDeviceCategory> get categories => _categories;
  List<CustomDeviceCategory> get customCategories => _customCategories;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get hideDefaultNamed => _hideDefaultNamed;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  SharedDevice? get selectedDevice => _selectedDevice;
  String? get feedbackMessage => _feedbackMessage;
  Set<String> get selectedMacs => Set.unmodifiable(_selectedMacs);
  bool get hasSelection => _selectedMacs.isNotEmpty;
  bool isMacSelected(String mac) => _selectedMacs.contains(SharedDevice.normalizeMac(mac));

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
    _customCategories = _repository.getCustomCategories();
    _categories = _repository.getUnifiedCategories();
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

  /// Resolves any device category key into a [UnifiedDeviceCategory] with icon and label.
  UnifiedDeviceCategory resolveCategory(String? key) {
    return UnifiedDeviceCategory.resolve(key, customCategories: _customCategories);
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

  /// Updates full device details (name, category/deviceType, vendor, notes).
  void updateDeviceDetails({
    required String mac,
    String? name,
    String? category,
    String? vendor,
    String? notes,
  }) {
    _repository.updateDeviceDetails(
      mac,
      name: name,
      deviceType: category,
      vendor: vendor,
      notes: notes,
    );
    _feedbackMessage = 'Updated details for $mac';
    loadDevices();

    if (_selectedDevice?.macAddress == SharedDevice.normalizeMac(mac)) {
      _selectedDevice = _repository.getDeviceByMac(mac);
    }
  }

  /// Convenience method to quickly assign or change category for a device.
  void updateDeviceCategory(String mac, String newCategory) {
    updateDeviceDetails(mac: mac, category: newCategory);
  }

  /// Creates a new user-defined custom device category.
  void createCustomCategory({
    required String id,
    required String label,
    String iconName = 'devices_other',
    String? colorHex,
  }) {
    final now = DateTime.now();
    final cleanId = id.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final cat = CustomDeviceCategory(
      id: cleanId,
      label: label.trim(),
      iconName: iconName,
      colorHex: colorHex,
      createdAt: now,
      updatedAt: now,
    );
    _repository.upsertCustomCategory(cat);
    _feedbackMessage = 'Created category "${label.trim()}"';
    loadDevices();
  }

  /// Deletes a custom category by id and moves its devices to 'other'.
  void deleteCustomCategory(String id) {
    _repository.deleteCustomCategory(id);
    _feedbackMessage = 'Deleted category $id';
    if (_selectedCategory == id) {
      _selectedCategory = 'all';
    }
    loadDevices();
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

  void toggleSelect(String mac) {
    final normalized = SharedDevice.normalizeMac(mac);
    if (_selectedMacs.contains(normalized)) {
      _selectedMacs.remove(normalized);
    } else {
      _selectedMacs.add(normalized);
    }
    notifyListeners();
  }

  void selectAll(List<SharedDevice> visibleDevices) {
    for (final d in visibleDevices) {
      _selectedMacs.add(SharedDevice.normalizeMac(d.macAddress));
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedMacs.clear();
    notifyListeners();
  }

  void deleteSelectedDevices() {
    if (_selectedMacs.isEmpty) return;
    final count = _selectedMacs.length;
    _repository.deleteDevices(_selectedMacs);
    if (_selectedDevice != null && _selectedMacs.contains(_selectedDevice!.macAddress)) {
      _selectedDevice = null;
    }
    _selectedMacs.clear();
    _feedbackMessage = count == 1 ? 'Deleted 1 device' : 'Deleted $count devices';
    loadDevices();
  }

  void deleteDevice(String mac) {
    final normalized = SharedDevice.normalizeMac(mac);
    _repository.deleteDevice(mac);
    _selectedMacs.remove(normalized);
    if (_selectedDevice?.macAddress == normalized) {
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
