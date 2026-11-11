import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:net_app_launcher/core/constants.dart';
import 'package:net_app_launcher/data/repositories/device_repository.dart';
import 'package:net_app_launcher/data/repositories/suite_repository.dart';
import 'package:net_app_launcher/data/services/app_installer_service.dart';
import 'package:net_app_launcher/data/services/app_runner_service.dart';
import 'package:net_app_launcher/data/services/dependency_service.dart';
import 'package:net_app_launcher/data/services/device_export_service.dart';
import 'package:net_app_launcher/data/services/github_service.dart';
import 'package:net_app_launcher/data/services/local_app_registry.dart';
import 'package:net_app_launcher/domain/models/dependency_info.dart';
import 'package:net_app_launcher/domain/models/network_adapter_option.dart';
import 'package:net_app_launcher/domain/models/release_info.dart';
import 'package:net_app_launcher/domain/models/suite_app.dart';
import 'package:net_app_launcher/ui/view_models/device_manager_view_model.dart';
import 'package:net_app_launcher/ui/view_models/launcher_view_model.dart';
import 'package:net_app_launcher/ui/views/launcher_self_update_dialog.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

class RecordingRunnerService extends AppRunnerService {
  List<String>? lastArguments;

  @override
  Future<Process> launchApp({
    required String appId,
    required String executablePath,
    List<String> arguments = const [],
    void Function()? onExited,
  }) async {
    lastArguments = arguments;
    throw Exception('Simulated test execution');
  }
}

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

    test('matches installer assets and prioritizes installer in findLauncherAssetForCurrentPlatform', () {
      final release = ReleaseInfo(
        tagName: 'v0.7.0.Beta',
        name: 'Release 0.7.0.Beta',
        publishedAt: DateTime.now(),
        body: 'Installer release',
        assets: const [
          ReleaseAsset(
            name: 'NetworkSuiteLauncher_windows_x64.zip',
            downloadUrl: 'https://github.com/.../windows.zip',
            sizeBytes: 15000000,
            contentType: 'application/zip',
          ),
          ReleaseAsset(
            name: 'NetworkSuiteLauncher_windows_x64_Setup.exe',
            downloadUrl: 'https://github.com/.../windows_Setup.exe',
            sizeBytes: 16000000,
            contentType: 'application/octet-stream',
          ),
          ReleaseAsset(
            name: 'NetworkSuiteLauncher_macos.zip',
            downloadUrl: 'https://github.com/.../macos.zip',
            sizeBytes: 14000000,
            contentType: 'application/zip',
          ),
          ReleaseAsset(
            name: 'NetworkSuiteLauncher_macos.dmg',
            downloadUrl: 'https://github.com/.../macos.dmg',
            sizeBytes: 15000000,
            contentType: 'application/octet-stream',
          ),
          ReleaseAsset(
            name: 'NetworkSuiteLauncher_linux_x64.tar.gz',
            downloadUrl: 'https://github.com/.../linux.tar.gz',
            sizeBytes: 13000000,
            contentType: 'application/gzip',
          ),
          ReleaseAsset(
            name: 'NetworkSuiteLauncher_linux_amd64.deb',
            downloadUrl: 'https://github.com/.../linux_amd64.deb',
            sizeBytes: 13500000,
            contentType: 'application/vnd.debian.binary-package',
          ),
        ],
      );

      final installer = release.findInstallerForCurrentPlatform();
      expect(installer, isNotNull);
      final preferred = release.findLauncherAssetForCurrentPlatform();
      expect(preferred, isNotNull);

      if (Platform.isWindows) {
        expect(installer!.name, 'NetworkSuiteLauncher_windows_x64_Setup.exe');
        expect(preferred!.name, 'NetworkSuiteLauncher_windows_x64_Setup.exe');
      } else if (Platform.isMacOS) {
        expect(installer!.name, 'NetworkSuiteLauncher_macos.dmg');
        expect(preferred!.name, 'NetworkSuiteLauncher_macos.dmg');
      } else if (Platform.isLinux) {
        expect(installer!.name, 'NetworkSuiteLauncher_linux_amd64.deb');
        expect(preferred!.name, 'NetworkSuiteLauncher_linux_amd64.deb');
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

  group('GitHubService Caching & Rate Limiting', () {
    late Directory cacheTempDir;

    setUp(() {
      cacheTempDir = Directory.systemTemp.createTempSync('gh_cache_test_');
    });

    tearDown(() {
      try {
        cacheTempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('caches release response and avoids network request within TTL', () async {
      int requestCount = 0;
      final fakeClient = FakeHttpClient((request) async {
        requestCount++;
        final jsonStr = jsonEncode({
          'tag_name': 'v1.0.0',
          'name': 'Release 1.0.0',
          'published_at': '2026-11-01T12:00:00Z',
          'body': 'Initial release notes',
          'assets': [
            {
              'name': 'ARP-Scout_windows_x64.zip',
              'browser_download_url': 'https://github.com/Tom-McGuire/ARP-Scout/releases/download/v1.0.0/app.zip',
              'size': 12345,
              'content_type': 'application/zip',
            }
          ],
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonStr)),
          200,
          headers: {'etag': 'W/"etag-test-123"'},
        );
      });

      final service = GitHubService(
        client: fakeClient,
        customCacheDir: cacheTempDir.path,
        cacheTtl: const Duration(minutes: 15),
      );

      // First call -> hits network
      final release1 = await service.fetchLatestRelease('ARP-Scout');
      expect(release1, isNotNull);
      expect(release1!.tagName, 'v1.0.0');
      expect(requestCount, 1);

      // Second call within TTL -> returns cached without network request
      final release2 = await service.fetchLatestRelease('ARP-Scout');
      expect(release2, isNotNull);
      expect(release2!.tagName, 'v1.0.0');
      expect(requestCount, 1); // requestCount did NOT increment!
    });

    test('sends If-None-Match ETag on forceRefresh and handles HTTP 304 gracefully', () async {
      String? sentIfNoneMatch;
      int requestCount = 0;

      final fakeClient = FakeHttpClient((request) async {
        requestCount++;
        sentIfNoneMatch = request.headers['if-none-match'];

        if (requestCount == 1) {
          final jsonStr = jsonEncode({
            'tag_name': 'v1.0.0',
            'name': 'Release 1.0.0',
            'published_at': '2026-11-01T12:00:00Z',
            'body': 'Initial notes',
            'assets': [],
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonStr)),
            200,
            headers: {'etag': 'W/"etag-test-456"'},
          );
        } else {
          // Second request: return 304 Not Modified
          return http.StreamedResponse(
            const Stream.empty(),
            304,
            headers: {'etag': 'W/"etag-test-456"'},
          );
        }
      });

      final service = GitHubService(
        client: fakeClient,
        customCacheDir: cacheTempDir.path,
      );

      final r1 = await service.fetchLatestRelease('ARP-Scout');
      expect(r1, isNotNull);
      expect(requestCount, 1);
      expect(sentIfNoneMatch, isNull);

      // Force refresh -> should send ETag in If-None-Match header
      final r2 = await service.fetchLatestRelease('ARP-Scout', forceRefresh: true);
      expect(r2, isNotNull);
      expect(r2!.tagName, 'v1.0.0');
      expect(requestCount, 2);
      expect(sentIfNoneMatch, 'W/"etag-test-456"');
    });

    test('detects rate limit, parses reset timestamp, and serves cached data', () async {
      final resetEpochSec = DateTime.now().add(const Duration(minutes: 25)).millisecondsSinceEpoch ~/ 1000;

      int callIndex = 0;
      final fakeClient = FakeHttpClient((request) async {
        callIndex++;
        if (callIndex == 1) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'tag_name': 'v1.0.0',
              'name': 'Release 1.0.0',
              'published_at': '2026-11-01T12:00:00Z',
              'body': '',
              'assets': [],
            }))),
            200,
            headers: {'etag': 'W/"etag-abc"'},
          );
        } else {
          // Rate limited response
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"message":"API rate limit exceeded"}')),
            403,
            headers: {
              'x-ratelimit-remaining': '0',
              'x-ratelimit-reset': resetEpochSec.toString(),
            },
          );
        }
      });

      final service = GitHubService(
        client: fakeClient,
        customCacheDir: cacheTempDir.path,
      );

      // Populate cache
      await service.fetchLatestRelease('ARP-Scout');
      expect(service.isRateLimited, isFalse);

      // Second call encounters rate limit
      final release = await service.fetchLatestRelease('ARP-Scout', forceRefresh: true);
      expect(service.isRateLimited, isTrue);
      expect(service.rateLimitResetTime, isNotNull);
      // Graceful fallback returns cached release!
      expect(release, isNotNull);
      expect(release!.tagName, 'v1.0.0');
    });

    test('persists cache to disk and restores it across instances', () async {
      final fakeClient = FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'tag_name': 'v2.1.0',
            'name': 'Release 2.1.0',
            'published_at': '2026-11-01T12:00:00Z',
            'body': 'Persisted release notes',
            'assets': [],
          }))),
          200,
          headers: {'etag': 'W/"persisted-etag"'},
        );
      });

      final service1 = GitHubService(
        client: fakeClient,
        customCacheDir: cacheTempDir.path,
      );
      await service1.fetchLatestRelease('ARP-Scout');

      // Create a brand new instance pointing to same directory with a client that throws
      final throwingClient = FakeHttpClient((_) => throw StateError('Should not hit network'));
      final service2 = GitHubService(
        client: throwingClient,
        customCacheDir: cacheTempDir.path,
        cacheTtl: const Duration(minutes: 30),
      );

      // Should load from disk cache without throwing
      final restored = await service2.fetchLatestRelease('ARP-Scout');
      expect(restored, isNotNull);
      expect(restored!.tagName, 'v2.1.0');
      expect(service2.cache.containsKey('ARP-Scout'), isTrue);
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

    test('SharedDeviceDatabase supports updating device category and custom categories', () {
      final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
      final now = DateTime.now();

      // 1. Insert a discovered device with default/inferred category
      db.upsertDevice(SharedDevice(
        macAddress: '00:11:22:33:44:55',
        name: 'Device 00:11:22:33:44:55',
        deviceType: 'other',
        sourceApp: 'arp-scout',
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Change category to built-in 'router' and assign friendly name
      db.updateDeviceDetails(
        '00:11:22:33:44:55',
        name: 'Gateway Router',
        deviceType: 'router',
      );

      var updated = db.getDeviceByMac('00:11:22:33:44:55');
      expect(updated, isNotNull);
      expect(updated!.name, 'Gateway Router');
      expect(updated.deviceType, 'router');

      // 3. Create a custom category 'firewall'
      db.upsertCustomCategory(CustomDeviceCategory(
        id: 'firewall',
        label: 'Firewall / UTM',
        iconName: 'security',
        colorHex: '#FF5722',
        createdAt: now,
        updatedAt: now,
      ));

      final customCats = db.getCustomCategories();
      expect(customCats.length, 1);
      expect(customCats.first.id, 'firewall');
      expect(customCats.first.label, 'Firewall / UTM');

      // 4. Assign custom category to the device
      db.updateDeviceDetails(
        '00:11:22:33:44:55',
        deviceType: 'firewall',
      );

      updated = db.getDeviceByMac('00:11:22:33:44:55');
      expect(updated!.deviceType, 'firewall');

      // 5. Test UnifiedDeviceCategory resolution
      final unified = db.getUnifiedCategories();
      expect(unified.any((c) => c.key == 'firewall' && c.isCustom), isTrue);

      // 6. Delete custom category and ensure device falls back to 'other'
      db.deleteCustomCategory('firewall');
      expect(db.getCustomCategories(), isEmpty);
      updated = db.getDeviceByMac('00:11:22:33:44:55');
      expect(updated!.deviceType, 'other');
    });
  });

  group('SuiteApp & DependencyInfo Domain Models', () {
    const sampleDef = AppCatalogDefinition(
      id: 'test-app',
      name: 'Test App',
      repoName: 'Test-App',
      defaultExecutableName: 'test_app',
      category: 'Testing',
      summary: 'A test utility application.',
      icon: Icons.science,
    );

    test('SuiteApp canLaunch, hasUpdate, and copyWith logic', () {
      const app = SuiteApp(
        definition: sampleDef,
        status: AppStatus.notInstalled,
      );

      expect(app.id, 'test-app');
      expect(app.name, 'Test App');
      expect(app.category, 'Testing');
      expect(app.summary, 'A test utility application.');
      expect(app.canLaunch, isFalse);
      expect(app.hasUpdate, isFalse);

      final installedApp = app.copyWith(
        status: AppStatus.installed,
        executablePath: '/usr/bin/test_app',
        installedVersion: 'v1.0.0',
      );
      expect(installedApp.canLaunch, isTrue);
      expect(installedApp.hasUpdate, isFalse);

      final updateApp = installedApp.copyWith(status: AppStatus.updateAvailable);
      expect(updateApp.canLaunch, isTrue);
      expect(updateApp.hasUpdate, isTrue);
    });

    test('DependencyInfo copyWith logic', () {
      const dep = DependencyInfo(
        id: 'tshark',
        name: 'Wireshark / TShark',
        isInstalled: false,
        installCommand: 'winget install -e --id WiresharkFoundation.Wireshark',
      );

      expect(dep.isInstalled, isFalse);
      expect(dep.version, isNull);

      final resolved = dep.copyWith(
        isInstalled: true,
        version: 'TShark (Wireshark) 4.2.0',
      );
      expect(resolved.isInstalled, isTrue);
      expect(resolved.version, 'TShark (Wireshark) 4.2.0');
    });

    test('NetworkAdapterOption model, formatting, and equality', () async {
      const opt1 = NetworkAdapterOption(name: 'eth0', ipAddress: '192.168.1.100');
      const opt2 = NetworkAdapterOption(name: 'eth0', ipAddress: '192.168.1.100');
      const opt3 = NetworkAdapterOption(name: 'wlan0', ipAddress: '10.0.0.50');

      expect(opt1.displayLabel, 'eth0 (192.168.1.100)');
      expect(opt1.toString(), 'eth0 (192.168.1.100)');
      expect(opt1, equals(opt2));
      expect(opt1.hashCode, equals(opt2.hashCode));
      expect(opt1, isNot(equals(opt3)));

      final discovered = await NetworkAdapterOption.discoverAdapters();
      expect(discovered, isA<List<NetworkAdapterOption>>());
    });
  });

  group('LocalAppRegistry Executable Discovery', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('reg_exe_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('finds exact executable matching fallbackName in directory root', () {
      final registry = LocalAppRegistry(customBaseDir: tempDir.path);
      final appDir = Directory(p.join(tempDir.path, 'apps', 'test-app'))..createSync(recursive: true);

      final binaryName = Platform.isWindows ? 'test_app.exe' : 'test_app';
      final binFile = File(p.join(appDir.path, binaryName))..writeAsStringSync('#!/bin/sh\nexit 0');

      final found = registry.findExecutableInDirectory(appDir.path, 'test_app');
      expect(found, isNotNull);
      expect(found, binFile.path);
    });

    test('finds executable in subdirectories while ignoring helper files', () {
      final registry = LocalAppRegistry(customBaseDir: tempDir.path);
      final subDir = Directory(p.join(tempDir.path, 'apps', 'test-app', 'bin'))..createSync(recursive: true);

      File(p.join(tempDir.path, 'apps', 'test-app', 'readme.txt')).writeAsStringSync('docs');
      File(p.join(tempDir.path, 'apps', 'test-app', 'unins000.exe')).writeAsStringSync('uninstaller');

      final binaryName = Platform.isWindows ? 'test_app.exe' : 'test_app';
      final binFile = File(p.join(subDir.path, binaryName))..writeAsStringSync('binary');

      final found = registry.findExecutableInDirectory(p.join(tempDir.path, 'apps', 'test-app'), 'test_app');
      expect(found, isNotNull);
      expect(found, binFile.path);
    });

    test('manages installation records, paths, and deletion', () {
      final registry = LocalAppRegistry(customBaseDir: tempDir.path);

      expect(registry.loadRegistry().containsKey('sample-app'), isFalse);
      expect(registry.getAppInstallPath('sample-app'), contains('sample-app'));

      final appDir = Directory(registry.getAppInstallPath('sample-app'))..createSync(recursive: true);
      final binPath = p.join(appDir.path, 'sample_app');
      File(binPath).writeAsStringSync('executable');

      expect(LocalAppRegistry.executableExists(binPath), isTrue);
      expect(LocalAppRegistry.executableExists('/does/not/exist'), isFalse);
      expect(LocalAppRegistry.executableExists(null), isFalse);

      // Record installation
      registry.recordInstallation(InstalledAppRecord(
        appId: 'sample-app',
        version: 'v2.1.0',
        installPath: appDir.path,
        executablePath: binPath,
        installedAt: DateTime.now(),
      ));

      var records = registry.loadRegistry();
      expect(records.containsKey('sample-app'), isTrue);
      expect(records['sample-app']?.version, 'v2.1.0');

      // Remove installation keeping files
      registry.removeInstallation('sample-app', deleteFiles: false);
      expect(registry.loadRegistry().containsKey('sample-app'), isFalse);
      expect(appDir.existsSync(), isTrue);

      // Record again and remove with deleteFiles: true
      registry.recordInstallation(InstalledAppRecord(
        appId: 'sample-app',
        version: 'v2.1.0',
        installPath: appDir.path,
        executablePath: binPath,
        installedAt: DateTime.now(),
      ));
      registry.removeInstallation('sample-app', deleteFiles: true);
      expect(appDir.existsSync(), isFalse);
    });
  });

  group('AppRunnerService Process Management', () {
    test('reports not running for unknown app and throws for missing binary', () async {
      final runner = AppRunnerService();
      expect(runner.isAppRunning('non-existent'), isFalse);

      expect(
        () => runner.launchApp(appId: 'non-existent', executablePath: '/does/not/exist/bin'),
        throwsA(isA<Exception>()),
      );

      // terminateApp does not throw on unknown appId
      runner.terminateApp('non-existent');
    });
  });

  group('DependencyService CLI Resolution', () {
    test('correctly identifies standard platform binaries or missing commands', () async {
      final depService = DependencyService();

      // Check standard POSIX binary (or 'cmd' on Windows)
      final existingBin = Platform.isWindows ? 'cmd' : 'sh';
      final result = await depService.checkDependency(
        id: existingBin,
        name: 'Shell',
        installCommand: 'builtin',
      );

      expect(result.id, existingBin);
      expect(result.isInstalled, isTrue);

      // Check non-existent command
      final missingResult = await depService.checkDependency(
        id: 'non_existent_command_12345_xyz',
        name: 'Missing Tool',
        installCommand: 'install it',
      );

      expect(missingResult.isInstalled, isFalse);
      expect(missingResult.version, isNull);
    });
  });

  group('SuiteRepository App Status & Lifecycle Coordination', () {
    late Directory tempDir;
    late LocalAppRegistry registry;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('suite_repo_test_');
      registry = LocalAppRegistry(customBaseDir: tempDir.path);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('resolves app statuses correctly between GitHub releases and local disk installations', () async {
      // 1. Simulate an installed app 'arp-scout' at version v1.0.0
      final arpBin = File(p.join(tempDir.path, 'apps', 'arp-scout', Platform.isWindows ? 'arp_scout.exe' : 'arp_scout'))
        ..createSync(recursive: true)
        ..writeAsStringSync('binary');

      registry.recordInstallation(InstalledAppRecord(
        appId: 'arp-scout',
        version: 'v1.0.0',
        installPath: p.dirname(arpBin.path),
        executablePath: arpBin.path,
        installedAt: DateTime.now(),
      ));

      // 2. Mock GitHub responses:
      // - 'ARP-Scout' has a newer release v1.2.0 (triggers updateAvailable)
      // - 'packet-inspector' has v1.0.0 (not installed locally -> notInstalled)
      // - Other repos return 404 (unreleased)
      final fakeClient = FakeHttpClient((request) async {
        if (request.url.path.contains('ARP-Scout')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'tag_name': 'v1.2.0',
              'name': 'v1.2.0 Release',
              'published_at': '2026-11-01T12:00:00Z',
              'body': 'Notes',
              'assets': [],
            }))),
            200,
          );
        } else if (request.url.path.contains('Packet-Inspector')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'tag_name': 'v1.0.0',
              'name': 'v1.0.0 Release',
              'published_at': '2026-11-01T12:00:00Z',
              'body': 'Notes',
              'assets': [],
            }))),
            200,
          );
        }
        return http.StreamedResponse(const Stream.empty(), 404);
      });

      final gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      final repo = SuiteRepository(
        gitHubService: gh,
        registry: registry,
      );

      final apps = await repo.loadSuiteApps(includeUnreleased: false);

      // Only published or installed apps should appear
      expect(apps.any((a) => a.id == 'arp-scout'), isTrue);
      expect(apps.any((a) => a.id == 'packet-inspector'), isTrue);

      final arpApp = apps.firstWhere((a) => a.id == 'arp-scout');
      expect(arpApp.status, AppStatus.updateAvailable);
      expect(arpApp.installedVersion, 'v1.0.0');
      expect(arpApp.latestRelease?.tagName, 'v1.2.0');
      expect(arpApp.canLaunch, isTrue);

      final packetApp = apps.firstWhere((a) => a.id == 'packet-inspector');
      expect(packetApp.status, AppStatus.notInstalled);
      expect(packetApp.canLaunch, isFalse);

      // When includeUnreleased: true, all catalog apps appear
      final allApps = await repo.loadSuiteApps(includeUnreleased: true);
      expect(allApps.length, SuiteConstants.catalog.length);
    });

    test('installApp throws when app has no release, launchApp throws when binary missing', () async {
      final repo = SuiteRepository(registry: registry);

      const unreleasedApp = SuiteApp(
        definition: AppCatalogDefinition(
          id: 'test',
          name: 'Test',
          repoName: 'Test',
          defaultExecutableName: 'test',
          category: 'General',
          summary: 'Summary',
          icon: Icons.science,
        ),
        status: AppStatus.notInstalled,
        latestRelease: null,
      );

      expect(
        () => repo.installApp(app: unreleasedApp, onProgress: (_, _, _) {}),
        throwsA(isA<Exception>()),
      );

      expect(
        () => repo.launchApp(unreleasedApp),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('LauncherViewModel Search, Filter, and Tab State', () {
    late Directory tempDir;
    late LocalAppRegistry registry;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vm_test_');
      registry = LocalAppRegistry(customBaseDir: tempDir.path);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('manages tabs, category filtering, search queries, and cooldown descriptions', () async {
      final fakeClient = FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'tag_name': 'v1.0.0',
            'name': 'v1.0.0',
            'published_at': '2026-11-01T12:00:00Z',
            'body': 'Notes',
            'assets': [],
          }))),
          200,
        );
      });

      final gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      final repo = SuiteRepository(gitHubService: gh, registry: registry);
      final vm = LauncherViewModel(repository: repo);

      await vm.loadApps();

      // Tab switching
      expect(vm.selectedTabIndex, 0);
      vm.switchTab(1);
      expect(vm.selectedTabIndex, 1);
      vm.switchTab(0);

      // Available categories includes 'All'
      expect(vm.availableCategories.contains('All'), isTrue);

      // Filtering by category
      vm.setSelectedCategory('Discovery & L2');
      expect(vm.selectedCategory, 'Discovery & L2');
      for (final a in vm.filteredApps) {
        expect(a.category, 'Discovery & L2');
      }

      vm.setSelectedCategory('All');

      // Search query filtering
      vm.setSearchQuery('packet');
      expect(vm.filteredApps.any((a) => a.name.toLowerCase().contains('packet')), isTrue);
      vm.setSearchQuery('');

      // Toggle unreleased
      final prevCount = vm.apps.length;
      vm.toggleShowUnreleased();
      expect(vm.showUnreleased, isTrue);
      expect(vm.apps.length, greaterThanOrEqualTo(prevCount));
    });

    test('rateLimitResetDescription handles negative, seconds, and minutes formats', () async {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Null case
      var fakeClient = FakeHttpClient((_) async => http.StreamedResponse(const Stream.empty(), 404));
      var gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      var repo = SuiteRepository(gitHubService: gh, registry: registry);
      var vm = LauncherViewModel(repository: repo);
      expect(vm.rateLimitResetDescription, isNull);

      // Momentarily (past reset)
      fakeClient = FakeHttpClient((_) async => http.StreamedResponse(
        Stream.value(utf8.encode('{}')),
        403,
        headers: {
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '${nowEpoch - 10}',
        },
      ));
      gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      repo = SuiteRepository(gitHubService: gh, registry: registry);
      vm = LauncherViewModel(repository: repo);
      await gh.fetchLatestRelease('repo1');
      expect(vm.rateLimitResetDescription, 'Resets momentarily');

      // Seconds (< 60s)
      fakeClient = FakeHttpClient((_) async => http.StreamedResponse(
        Stream.value(utf8.encode('{}')),
        403,
        headers: {
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '${nowEpoch + 45}',
        },
      ));
      gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      repo = SuiteRepository(gitHubService: gh, registry: registry);
      vm = LauncherViewModel(repository: repo);
      await gh.fetchLatestRelease('repo2');
      expect(vm.rateLimitResetDescription, contains('Resets in '));
      expect(vm.rateLimitResetDescription, contains('s (at '));

      // Minutes (> 60s)
      fakeClient = FakeHttpClient((_) async => http.StreamedResponse(
        Stream.value(utf8.encode('{}')),
        403,
        headers: {
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '${nowEpoch + 600}',
        },
      ));
      gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      repo = SuiteRepository(gitHubService: gh, registry: registry);
      vm = LauncherViewModel(repository: repo);
      await gh.fetchLatestRelease('repo3');
      expect(vm.rateLimitResetDescription, contains('Resets in '));
      expect(vm.rateLimitResetDescription, contains('m (at '));
    });

    test('LauncherViewModel installOrUpdate and launch handling', () async {
      final fakeClient = FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'tag_name': 'v1.0.0',
            'name': 'v1.0.0',
            'published_at': '2026-11-01T12:00:00Z',
            'body': '',
            'assets': [],
          }))),
          200,
        );
      });

      final gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      final repo = SuiteRepository(gitHubService: gh, registry: registry);
      final vm = LauncherViewModel(repository: repo);
      await vm.loadApps();

      final app = vm.apps.first;
      // Calling installOrUpdate with no matching asset throws and updates error status
      await vm.installOrUpdate(app);
      expect(vm.errorMessage, contains('No compatible release binary found'));
      final failedApp = vm.apps.firstWhere((a) => a.id == app.id);
      expect(failedApp.status, AppStatus.error);

      // Launching app without valid executable throws and updates error message
      await vm.launch(app);
      expect(vm.errorMessage, isNotNull);
    });

    test('uninstall resets app state and removes unreleased items', () async {
      final fakeClient = FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'tag_name': 'v1.0.0',
            'name': 'v1.0.0',
            'published_at': '2026-11-01T12:00:00Z',
            'body': '',
            'assets': [],
          }))),
          200,
        );
      });

      final gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      final repo = SuiteRepository(gitHubService: gh, registry: registry);
      final vm = LauncherViewModel(repository: repo);

      await vm.loadApps();

      final installedApp = vm.apps.first.copyWith(
        status: AppStatus.installed,
        executablePath: '/dummy/bin',
      );

      vm.uninstall(installedApp);
      final resetApp = vm.apps.firstWhere((a) => a.id == installedApp.id);
      expect(resetApp.status, AppStatus.notInstalled);
      expect(resetApp.executablePath, isNull);
    });

    test('LauncherViewModel manages network adapter selection and passes arguments on launch', () async {
      final fakeClient = FakeHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'tag_name': 'v1.0.0',
            'name': 'v1.0.0',
            'published_at': '2026-11-01T12:00:00Z',
            'body': '',
            'assets': [],
          }))),
          200,
        );
      });

      final recordingRunner = RecordingRunnerService();
      final gh = GitHubService(client: fakeClient, customCacheDir: tempDir.path);
      final repo = SuiteRepository(
        gitHubService: gh,
        registry: registry,
        runnerService: recordingRunner,
      );
      final vm = LauncherViewModel(repository: repo);

      const eth0 = NetworkAdapterOption(name: 'eth0', ipAddress: '192.168.1.10');
      const wlan0 = NetworkAdapterOption(name: 'wlan0', ipAddress: '10.0.0.5');

      // Refresh with mock list
      await vm.refreshAdapters(discoverFn: () async => [eth0, wlan0]);
      expect(vm.adapters.length, 2);
      expect(vm.selectedAdapter, eth0); // Defaults to first

      // User selects wlan0
      vm.setSelectedAdapter(wlan0);
      expect(vm.selectedAdapter, wlan0);

      // Refresh retaining wlan0
      await vm.refreshAdapters(discoverFn: () async => [eth0, wlan0]);
      expect(vm.selectedAdapter, wlan0);

      // Refresh when wlan0 removed falls back to first
      await vm.refreshAdapters(discoverFn: () async => [eth0]);
      expect(vm.selectedAdapter, eth0);

      // User selects App Default (None)
      vm.setSelectedAdapter(null);
      expect(vm.selectedAdapter, isNull);

      // Refresh retains null because user explicitly selected null
      await vm.refreshAdapters(discoverFn: () async => [eth0, wlan0]);
      expect(vm.selectedAdapter, isNull);

      // Verify launch with adapter arguments
      vm.setSelectedAdapter(wlan0);
      final binFile = File(p.join(tempDir.path, 'mock_bin'))..createSync();
      final testApp = SuiteApp(
        definition: SuiteConstants.catalog.first,
        status: AppStatus.installed,
        executablePath: binFile.path,
      );

      await vm.launch(testApp);
      expect(recordingRunner.lastArguments, ['--adapter-ip', '10.0.0.5', '--adapter-name', 'wlan0']);

      // Launch with null adapter passes no arguments
      vm.setSelectedAdapter(null);
      await vm.launch(testApp);
      expect(recordingRunner.lastArguments, isEmpty);
    });
  });

  group('DeviceRepository Direct Operations', () {
    test('initializes, counts, exports, updates and deletes devices', () async {
      final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
      final repo = DeviceRepository(database: db);

      await repo.init();
      expect(repo.getDeviceCount(), 0);

      final now = DateTime.now();
      repo.upsertDevice(SharedDevice(
        macAddress: '00:11:22:33:44:55',
        name: 'Device A',
        deviceType: 'pc',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));

      expect(repo.getDeviceCount(), 1);
      final dev = repo.getDeviceByMac('00:11:22:33:44:55');
      expect(dev, isNotNull);
      expect(dev!.name, 'Device A');

      repo.updateDeviceName('00:11:22:33:44:55', 'Workstation A');
      expect(repo.getDeviceByMac('00:11:22:33:44:55')!.name, 'Workstation A');

      // Export
      final csv = repo.exportToCsv();
      expect(csv.contains('Workstation A'), isTrue);
      final jsonStr = repo.exportToJson();
      expect(jsonStr.contains('Workstation A'), isTrue);

      // Import batch
      repo.importDevices([
        SharedDevice(
          macAddress: 'AA:BB:CC:DD:EE:FF',
          name: 'Device B',
          sourceApp: 'import',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      expect(repo.getDeviceCount(), 2);

      // Delete single
      repo.deleteDevice('00:11:22:33:44:55');
      expect(repo.getDeviceCount(), 1);
      expect(repo.getDeviceByMac('00:11:22:33:44:55'), isNull);

      // Batch Delete
      repo.upsertDevice(SharedDevice(
        macAddress: '11:22:33:44:55:66',
        name: 'Batch 1',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));
      repo.upsertDevice(SharedDevice(
        macAddress: '22:33:44:55:66:77',
        name: 'Batch 2',
        sourceApp: 'test',
        createdAt: now,
        updatedAt: now,
      ));
      expect(repo.getDeviceCount(), 3);

      repo.deleteDevices(['11:22:33:44:55:66', '22:33:44:55:66:77']);
      expect(repo.getDeviceCount(), 1);
      expect(repo.getDeviceByMac('11:22:33:44:55:66'), isNull);
      expect(repo.getDeviceByMac('22:33:44:55:66:77'), isNull);
    });
  });

  group('DeviceManagerViewModel Operations & Workflow', () {
    test('handles sorting, search filtering, device selection, and import/export', () async {
      final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
      final repo = DeviceRepository(database: db);
      final vm = DeviceManagerViewModel(repository: repo);

      // Wait briefly for init to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.totalCount, 0);

      // Add device
      vm.addDevice(
        rawMac: '00:11:22:33:44:55',
        name: 'Office Switch',
        category: 'switch',
        vendor: 'Cisco',
        notes: 'Floor 1',
      );

      expect(vm.devices.length, 1);
      expect(vm.devices.first.name, 'Office Switch');

      // Select device
      vm.selectDevice(vm.devices.first);
      expect(vm.selectedDevice, isNotNull);
      expect(vm.selectedDevice!.macAddress, '00:11:22:33:44:55');

      // Update name & details
      vm.updateDeviceName('00:11:22:33:44:55', 'Core Switch 1');
      expect(vm.devices.first.name, 'Core Switch 1');

      // Search filtering
      vm.setSearchQuery('NonExistent');
      expect(vm.devices.isEmpty, isTrue);
      vm.setSearchQuery('');
      expect(vm.devices.length, 1);

      // Category filtering
      vm.setSelectedCategory('router');
      expect(vm.devices.isEmpty, isTrue);
      vm.setSelectedCategory('switch');
      expect(vm.devices.length, 1);
      vm.setSelectedCategory('all');

      // Sort column and direction
      vm.setSorting('name');
      expect(vm.sortBy, 'name');
      expect(vm.sortAscending, isTrue);
      vm.setSorting('name'); // Toggles ascending
      expect(vm.sortAscending, isFalse);

      // Hide unnamed toggle
      vm.toggleHideDefaultNamed();
      expect(vm.hideDefaultNamed, isFalse);
      vm.toggleHideDefaultNamed();
      expect(vm.hideDefaultNamed, isTrue);

      // Custom categories
      vm.createCustomCategory(
        id: 'nas_storage',
        label: 'NAS Storage',
        iconName: 'storage',
      );
      expect(vm.customCategories.any((c) => c.id == 'nas_storage'), isTrue);

      vm.deleteCustomCategory('nas_storage');
      expect(vm.customCategories.any((c) => c.id == 'nas_storage'), isFalse);

      // Export / Import
      final csv = repo.exportToCsv();
      expect(csv.contains('Core Switch 1'), isTrue);

      final jsonStr = repo.exportToJson();
      expect(jsonStr.contains('Core Switch 1'), isTrue);

      vm.deleteDevice('00:11:22:33:44:55');
      expect(vm.devices.isEmpty, isTrue);

      // Re-import via CSV
      vm.importFromCsv(csv);
      expect(vm.devices.length, 1);

      // Clear selection
      vm.selectDevice(null);
      expect(vm.selectedDevice, isNull);
    });

    test('supports multi-select, toggleSelect, selectAll, clearSelection, and batch delete', () async {
      final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
      final repo = DeviceRepository(database: db);
      final vm = DeviceManagerViewModel(repository: repo);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      vm.addDevice(rawMac: '11:11:11:11:11:11', name: 'Dev 1');
      vm.addDevice(rawMac: '22:22:22:22:22:22', name: 'Dev 2');
      vm.addDevice(rawMac: '33:33:33:33:33:33', name: 'Dev 3');
      expect(vm.devices.length, 3);

      expect(vm.hasSelection, isFalse);
      expect(vm.selectedMacs.isEmpty, isTrue);

      // Toggle single device
      vm.toggleSelect('11:11:11:11:11:11');
      expect(vm.hasSelection, isTrue);
      expect(vm.selectedMacs.length, 1);
      expect(vm.isMacSelected('11:11:11:11:11:11'), isTrue);
      expect(vm.isMacSelected('22:22:22:22:22:22'), isFalse);

      // Toggle off
      vm.toggleSelect('11:11:11:11:11:11');
      expect(vm.hasSelection, isFalse);
      expect(vm.isMacSelected('11:11:11:11:11:11'), isFalse);

      // Select all visible
      vm.selectAll(vm.devices);
      expect(vm.selectedMacs.length, 3);
      expect(vm.isMacSelected('11:11:11:11:11:11'), isTrue);
      expect(vm.isMacSelected('22:22:22:22:22:22'), isTrue);
      expect(vm.isMacSelected('33:33:33:33:33:33'), isTrue);

      // Clear selection
      vm.clearSelection();
      expect(vm.hasSelection, isFalse);
      expect(vm.selectedMacs.isEmpty, isTrue);

      // Select 2 devices and delete
      vm.toggleSelect('11:11:11:11:11:11');
      vm.toggleSelect('22:22:22:22:22:22');
      expect(vm.selectedMacs.length, 2);

      vm.deleteSelectedDevices();
      expect(vm.devices.length, 1);
      expect(vm.devices.first.macAddress, '33:33:33:33:33:33');
      expect(vm.hasSelection, isFalse);
      expect(vm.selectedMacs.isEmpty, isTrue);
      expect(vm.feedbackMessage, 'Deleted 2 devices');

      // Delete when selection is empty does nothing
      vm.deleteSelectedDevices();
      expect(vm.devices.length, 1);
    });
  });
}
