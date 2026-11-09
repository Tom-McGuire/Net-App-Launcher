import 'dart:async';
import 'package:network_suite_shared/network_suite_shared.dart';
import '../services/device_export_service.dart';

class DeviceRepository {
  final SharedDeviceDatabase _database;

  DeviceRepository({SharedDeviceDatabase? database})
      : _database = database ?? SharedDeviceDatabase.instance;

  Stream<void> get onDatabaseChanged => _database.onDatabaseChanged;

  Future<void> init() async {
    await _database.init();
  }

  List<SharedDevice> getAllDevices({
    String? query,
    String? deviceType,
    bool hideDefaultNamed = false,
    String sortBy = 'updated_at',
    bool ascending = false,
  }) {
    return _database.getAllDevices(
      query: query,
      deviceType: deviceType,
      hideDefaultNamed: hideDefaultNamed,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  SharedDevice? getDeviceByMac(String mac) {
    return _database.getDeviceByMac(mac);
  }

  void upsertDevice(SharedDevice device) {
    _database.upsertDevice(device);
  }

  void updateDeviceName(String mac, String newName) {
    _database.updateDeviceName(mac, newName);
  }

  void updateDeviceDetails(
    String mac, {
    String? name,
    String? deviceType,
    String? vendor,
    String? notes,
  }) {
    _database.updateDeviceDetails(
      mac,
      name: name,
      deviceType: deviceType,
      vendor: vendor,
      notes: notes,
    );
  }

  List<CustomDeviceCategory> getCustomCategories() {
    return _database.getCustomCategories();
  }

  List<UnifiedDeviceCategory> getUnifiedCategories() {
    return _database.getUnifiedCategories();
  }

  void upsertCustomCategory(CustomDeviceCategory category) {
    _database.upsertCustomCategory(category);
  }

  void deleteCustomCategory(String id) {
    _database.deleteCustomCategory(id);
  }

  void deleteDevice(String mac) {
    _database.deleteDevice(mac);
  }

  void deleteDevices(Iterable<String> macAddresses) {
    for (final mac in macAddresses) {
      _database.deleteDevice(mac);
    }
  }

  void importDevices(List<SharedDevice> devices) {
    _database.importBatch(devices);
  }

  int getDeviceCount() => _database.getDeviceCount();

  String exportToCsv() {
    final devices = getAllDevices(sortBy: 'name', ascending: true);
    return DeviceExportService.exportToCsv(devices);
  }

  String exportToJson() {
    final devices = getAllDevices(sortBy: 'name', ascending: true);
    return DeviceExportService.exportToJson(devices);
  }
}
