import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:net_app_launcher/data/services/app_installer_service.dart';
import 'package:net_app_launcher/data/services/device_export_service.dart';
import 'package:net_app_launcher/data/services/github_service.dart';
import 'package:net_app_launcher/data/services/local_app_registry.dart';
import 'package:net_app_launcher/domain/models/release_info.dart';
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
}
