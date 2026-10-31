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

  void deleteDevice(String mac) {
    _database.deleteDevice(mac);
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
