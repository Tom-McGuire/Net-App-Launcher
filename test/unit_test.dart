import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_app_launcher/data/services/device_export_service.dart';
import 'package:net_app_launcher/data/services/local_app_registry.dart';
import 'package:net_app_launcher/domain/models/release_info.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() {
  group('ReleaseInfo Asset Matching', () {
    test('matches Windows zip asset on Windows platform', () {
      final release = ReleaseInfo(
        tagName: 'v1.0.0',
        name: 'Initial Release',
        publishedAt: DateTime.now(),
        body: 'Release notes',
        assets: const [
          ReleaseAsset(
            name: 'ARP-Scout_linux_x64.tar.gz',
            downloadUrl: 'https://github.com/.../linux.tar.gz',
            sizeBytes: 15000000,
            contentType: 'application/gzip',
          ),
          ReleaseAsset(
            name: 'ARP-Scout_windows_x64.zip',
            downloadUrl: 'https://github.com/.../windows.zip',
            sizeBytes: 18000000,
            contentType: 'application/zip',
          ),
          ReleaseAsset(
            name: 'ARP-Scout_macos.zip',
            downloadUrl: 'https://github.com/.../macos.zip',
            sizeBytes: 16000000,
            contentType: 'application/zip',
          ),
        ],
      );

      final asset = release.findAssetForCurrentPlatform();
      expect(asset, isNotNull);
      if (Platform.isWindows) {
        expect(asset!.name, 'ARP-Scout_windows_x64.zip');
      }
    });
  });

  group('LocalAppRegistry', () {
    late Directory tempDir;
    late LocalAppRegistry registry;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('reg_test_');
      registry = LocalAppRegistry(customBaseDir: tempDir.path);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('records and retrieves app installations', () {
      final record = InstalledAppRecord(
        appId: 'arp-scout',
        version: 'v1.0.0',
        installPath: tempDir.path,
        executablePath: '${tempDir.path}/arp_scout.exe',
        installedAt: DateTime.now(),
      );

      registry.recordInstallation(record);

      final loaded = registry.loadRegistry();
      expect(loaded.containsKey('arp-scout'), isTrue);
      expect(loaded['arp-scout']!.version, 'v1.0.0');

      registry.removeInstallation('arp-scout', deleteFiles: false);
      final afterRemove = registry.loadRegistry();
      expect(afterRemove.containsKey('arp-scout'), isFalse);
    });
  });

  group('DeviceExportService', () {
    test('exports to CSV and imports back without volatile IPs', () {
      final now = DateTime.now();
      final devices = [
        SharedDevice(
          macAddress: '00:1A:2B:3C:4D:5E',
          name: 'Core Switch',
          vendor: 'Cisco Systems, Inc.',
          deviceType: 'switch',
          notes: 'Server Room Rack 1',
          sourceApp: 'launcher',
          createdAt: now,
          updatedAt: now,
        ),
        SharedDevice(
          macAddress: 'F0:18:98:11:22:33',
          name: "Tom's MacBook Pro",
          vendor: 'Apple, Inc.',
          deviceType: 'pc',
          sourceApp: 'arp-scout',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csv = DeviceExportService.exportToCsv(devices);
      expect(csv.contains('00:1A:2B:3C:4D:5E'), isTrue);
      expect(csv.contains('Core Switch'), isTrue);
      expect(csv.contains('IP Address'), isFalse); // No IP address column

      final imported = DeviceExportService.importFromCsv(csv);
      expect(imported.length, 2);
      expect(imported.first.macAddress, '00:1A:2B:3C:4D:5E');
      expect(imported.first.name, 'Core Switch');
      expect(imported.first.vendor, 'Cisco Systems, Inc.');
    });

    test('exports to JSON and imports back correctly', () {
      final now = DateTime.now();
      final devices = [
        SharedDevice(
          macAddress: 'B8:27:EB:01:02:03',
          name: 'Pi Hole DNS',
          vendor: 'Raspberry Pi Foundation',
          deviceType: 'iot',
          notes: 'DNS blocker',
          sourceApp: 'net-services',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final jsonStr = DeviceExportService.exportToJson(devices);
      expect(jsonStr.contains('B8:27:EB:01:02:03'), isTrue);
      expect(jsonStr.contains('last_ip'), isFalse); // No IP property

      final imported = DeviceExportService.importFromJson(jsonStr);
      expect(imported.length, 1);
      expect(imported.first.macAddress, 'B8:27:EB:01:02:03');
      expect(imported.first.name, 'Pi Hole DNS');
      expect(imported.first.deviceType, 'iot');
    });
  });
}
