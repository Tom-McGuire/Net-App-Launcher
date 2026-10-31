import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_app_launcher/data/services/app_installer_service.dart';
import 'package:net_app_launcher/data/services/device_export_service.dart';
import 'package:net_app_launcher/data/services/local_app_registry.dart';
import 'package:net_app_launcher/domain/models/release_info.dart';
import 'package:net_app_launcher/ui/views/launcher_self_update_dialog.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('ReleaseInfo Asset Matching & Semantic Versioning', () {
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

    test('semantic version comparison handles v prefix and prevents downgrades', () {
      final release = ReleaseInfo(
        tagName: 'v1.2.0',
        name: 'Release 1.2.0',
        publishedAt: DateTime.now(),
        body: '',
        assets: const [],
      );

      expect(release.isNewerThan('v1.0.0'), isTrue);
      expect(release.isNewerThan('1.1.9'), isTrue);
      expect(release.isNewerThan('v1.2.0'), isFalse);
      expect(release.isNewerThan('1.2.0'), isFalse);
      expect(release.isNewerThan('v1.3.0'), isFalse);
    });
  });

  group('Security Controls: Installer & URL Validation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sec_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('blocks Zip Slip path traversal entries during extraction', () {
      final archive = Archive();
      final payload = utf8.encode('malicious payload');
      archive.addFile(ArchiveFile('../escaped.exe', payload.length, payload));

      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File(p.join(tempDir.path, 'malicious.zip'));
      zipFile.writeAsBytesSync(zipBytes);

      final destDir = Directory(p.join(tempDir.path, 'target'));
      destDir.createSync(recursive: true);

      expect(
        () => AppInstallerService.extractArchiveSafely(zipFile.path, destDir.path),
        throwsA(isA<SecurityException>()),
      );
      expect(File(p.join(tempDir.path, 'escaped.exe')).existsSync(), isFalse);
    });

    test('verifies SHA-256 checksums accurately', () {
      final file = File(p.join(tempDir.path, 'binary.bin'));
      final content = utf8.encode('verified binary content');
      file.writeAsBytesSync(content);

      final expectedHex = sha256.convert(content).toString();

      expect(AppInstallerService.verifyFileSha256(file.path, expectedHex), isTrue);
      expect(AppInstallerService.verifyFileSha256(file.path, 'sha256:$expectedHex'), isTrue);
      expect(
        AppInstallerService.verifyFileSha256(
          file.path,
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        ),
        isFalse,
      );
    });

    test('enforces HTTPS and trusted GitHub domains for downloads', () {
      expect(
        AppInstallerService.isTrustedDownloadUrl(
          'https://github.com/Tom-McGuire/ARP-Scout/releases/download/v1.0.0/ARP-Scout_windows_x64.zip',
        ),
        isTrue,
      );
      expect(
        AppInstallerService.isTrustedDownloadUrl(
          'https://objects.githubusercontent.com/github-production-release-asset/123',
        ),
        isTrue,
      );
      expect(
        AppInstallerService.isTrustedDownloadUrl(
          'http://github.com/Tom-McGuire/ARP-Scout/releases/download/v1.0.0/app.zip',
        ),
        isFalse,
      );
      expect(
        AppInstallerService.isTrustedDownloadUrl('https://evil.example.com/app.zip'),
        isFalse,
      );
    });

    test('rejects shell metacharacters and non-HTTPS schemes in openUrl validator', () {
      expect(
        LauncherSelfUpdateDialog.isValidExternalHttpsUrl(
          'https://github.com/Tom-McGuire/Net-App-Launcher/releases/tag/v1.0.1',
        ),
        isTrue,
      );
      expect(
        LauncherSelfUpdateDialog.isValidExternalHttpsUrl(
          'https://github.com/Tom-McGuire/Net-App-Launcher & calc.exe',
        ),
        isFalse,
      );
      expect(
        LauncherSelfUpdateDialog.isValidExternalHttpsUrl('javascript:alert(1)'),
        isFalse,
      );
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

    test('rejects path traversal in appId', () {
      expect(() => registry.getAppInstallPath('../outside'), throwsArgumentError);
      expect(() => registry.getAppInstallPath('nested/app'), throwsArgumentError);
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

    test('neutralizes CSV formula injection payloads and round-trips cleanly', () {
      final now = DateTime.now();
      final devices = [
        SharedDevice(
          macAddress: '00:1A:2B:3C:4D:5E',
          name: '=CMD|\' /C calc\'!A0',
          vendor: 'Cisco',
          deviceType: 'switch',
          notes: '@SUM(1+1)',
          sourceApp: 'arp-scout',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csv = DeviceExportService.exportToCsv(devices);
      expect(csv.contains("'=CMD"), isTrue);
      expect(csv.contains("'@SUM"), isTrue);

      final imported = DeviceExportService.importFromCsv(csv);
      expect(imported.length, 1);
      expect(imported.first.name, '=CMD|\' /C calc\'!A0');
      expect(imported.first.notes, '@SUM(1+1)');
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

    test('handles malformed JSON gracefully without throwing', () {
      final imported = DeviceExportService.importFromJson('{not valid json');
      expect(imported, isEmpty);
    });

    test('accurately identifies custom vs default MAC label names', () {
      final now = DateTime.now();
      final custom1 = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: 'Living Room Apple TV',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      );
      final custom2 = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: 'Switch 1',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      );
      final default1 = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: 'Device 00:1A:2B:3C:4D:5E',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      );
      final default2 = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: '00:1A:2B:3C:4D:5E',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      );
      final default3 = SharedDevice(
        macAddress: '00:1A:2B:3C:4D:5E',
        name: 'Unknown Device',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      );

      expect(custom1.hasCustomName, isTrue);
      expect(custom2.hasCustomName, isTrue);
      expect(default1.hasCustomName, isFalse);
      expect(default2.hasCustomName, isFalse);
      expect(default3.hasCustomName, isFalse);
    });

    test('SharedDeviceDatabase filters default-named devices when hideDefaultNamed is true', () {
      final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
      final now = DateTime.now();

      db.upsertDevice(SharedDevice(
        macAddress: '00:11:22:33:44:55',
        name: 'Core Router',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));
      db.upsertDevice(SharedDevice(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        name: 'Device AA:BB:CC:DD:EE:FF',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));

      expect(db.getAllDevices(hideDefaultNamed: false).length, 2);
      final filtered = db.getAllDevices(hideDefaultNamed: true);
      expect(filtered.length, 1);
      expect(filtered.first.name, 'Core Router');
    });
  });
}
