import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_app_launcher/core/constants.dart';
import 'package:net_app_launcher/data/repositories/device_repository.dart';
import 'package:net_app_launcher/domain/models/release_info.dart';
import 'package:net_app_launcher/domain/models/suite_app.dart';
import 'package:net_app_launcher/main.dart';
import 'package:net_app_launcher/ui/view_models/device_manager_view_model.dart';
import 'package:net_app_launcher/ui/view_models/launcher_view_model.dart';
import 'package:net_app_launcher/ui/views/apps/app_card_item.dart';
import 'package:net_app_launcher/ui/views/apps/app_details_dialog.dart';
import 'package:net_app_launcher/ui/views/devices/add_device_dialog.dart';
import 'package:net_app_launcher/ui/views/devices/create_category_dialog.dart';
import 'package:net_app_launcher/ui/views/devices/edit_device_dialog.dart';
import 'package:net_app_launcher/ui/views/launcher_self_update_dialog.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

class MockLauncherViewModel extends LauncherViewModel {
  MockLauncherViewModel() : super();

  @override
  Future<void> loadApps({bool forceRefresh = false}) async {
    // Provide fast deterministic mock data for widget test
  }
}

void main() {
  late SharedDeviceDatabase db;

  setUp(() async {
    db = SharedDeviceDatabase();
    await db.init(dbPath: ':memory:');
  });

  tearDown(() {
    db.close();
  });

  testWidgets('Network Suite Launcher smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final deviceVm = DeviceManagerViewModel(repository: DeviceRepository(database: db));
    final launcherVm = MockLauncherViewModel();

    await tester.pumpWidget(
      NetworkSuiteLauncherApp(
        launcherViewModel: launcherVm,
        deviceManagerViewModel: deviceVm,
      ),
    );
    await tester.pump();

    // Verify top control bar
    expect(find.text('NETWORK SUITE LAUNCHER'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Shared Devices'), findsOneWidget);

    // Switch to Shared Devices tab
    await tester.tap(find.text('Shared Devices'));
    await tester.pump();

    // Verify empty state is displayed initially
    expect(find.text('No Devices in Shared Database'), findsOneWidget);
    expect(find.text('Add Device'), findsOneWidget);

    // Add a device to database
    deviceVm.addDevice(
      rawMac: '00:1A:2B:3C:4D:5E',
      name: 'Core Cisco Switch',
      vendor: 'Cisco Systems, Inc.',
      category: 'switch',
    );
    await tester.pump();

    // Verify device row appears in table
    expect(find.text('00:1A:2B:3C:4D:5E'), findsOneWidget);
    expect(find.text('Core Cisco Switch'), findsOneWidget);

    // Update device name at any point
    deviceVm.updateDeviceName('00:1A:2B:3C:4D:5E', 'Distribution Switch A');
    await tester.pump();

    // Verify updated name
    expect(find.text('Distribution Switch A'), findsOneWidget);

    // Verify 'Hide Unnamed' toggle is on by default
    expect(find.text('Hide Unnamed'), findsOneWidget);
    expect(deviceVm.hideDefaultNamed, isTrue);

    // Add an unnamed scanned device
    deviceVm.addDevice(
      rawMac: '11:22:33:44:55:66',
      name: '', // default name 'Device 11:22:33:44:55:66'
    );
    await tester.pump();

    // Default-named device is hidden by default
    expect(find.text('11:22:33:44:55:66'), findsNothing);

    // Tap 'Hide Unnamed' toggle to show unnamed devices
    await tester.tap(find.text('Hide Unnamed'));
    await tester.pump();
    expect(deviceVm.hideDefaultNamed, isFalse);
    expect(find.text('11:22:33:44:55:66'), findsOneWidget);

    // Tap again to hide them
    await tester.tap(find.text('Hide Unnamed'));
    await tester.pump();
    expect(deviceVm.hideDefaultNamed, isTrue);
    expect(find.text('11:22:33:44:55:66'), findsNothing);

    // Update category of discovered device
    deviceVm.updateDeviceCategory('00:1A:2B:3C:4D:5E', 'server');
    await tester.pump();
    expect(find.text('Server'), findsWidgets);

    // Create custom category and assign to device
    deviceVm.createCustomCategory(
      id: 'firewall',
      label: 'Firewall / UTM',
      iconName: 'security',
    );
    await tester.pump();
    expect(find.text('Firewall / UTM'), findsOneWidget); // In filter chips

    deviceVm.updateDeviceCategory('00:1A:2B:3C:4D:5E', 'firewall');
    await tester.pump();
    expect(find.text('Firewall / UTM'), findsWidgets); // In filter chip and table row
  });

  testWidgets('LauncherSelfUpdateDialog renders release details and update actions', (WidgetTester tester) async {
    final release = ReleaseInfo(
      tagName: 'v0.7.0.Beta',
      name: 'Network Suite Launcher v0.7.0.Beta',
      publishedAt: DateTime(2026, 11, 2, 12, 0),
      body: 'Added Windows Inno Setup installer and automated in-app updater.',
      assets: const [
        ReleaseAsset(
          name: 'NetworkSuiteLauncher_windows_x64_Setup.exe',
          downloadUrl: 'https://github.com/Tom-McGuire/Net-App-Launcher/releases/download/v0.7.0.Beta/NetworkSuiteLauncher_windows_x64_Setup.exe',
          sizeBytes: 15728640,
          contentType: 'application/octet-stream',
        ),
        ReleaseAsset(
          name: 'NetworkSuiteLauncher_linux_amd64.deb',
          downloadUrl: 'https://github.com/Tom-McGuire/Net-App-Launcher/releases/download/v0.7.0.Beta/NetworkSuiteLauncher_linux_amd64.deb',
          sizeBytes: 14680064,
          contentType: 'application/vnd.debian.binary-package',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LauncherSelfUpdateDialog(release: release),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Network Suite Launcher Update'), findsOneWidget);
    expect(find.textContaining('v0.7.0.Beta'), findsWidgets);
    expect(find.textContaining('Added Windows Inno Setup installer'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('View on GitHub'), findsOneWidget);
  });

  testWidgets('AppCardItem renders status, buttons, and handles interaction', (WidgetTester tester) async {
    const def = AppCatalogDefinition(
      id: 'arp-scout',
      name: 'ARP & Subnet Scout',
      repoName: 'ARP-Scout',
      defaultExecutableName: 'arp_scout',
      category: 'Discovery & L2',
      summary: 'L2/L3 active subnet discovery.',
      icon: Icons.radar,
    );

    bool installClicked = false;
    bool launchClicked = false;

    // 1. Not installed state
    final notInstalledApp = SuiteApp(
      definition: def,
      status: AppStatus.notInstalled,
      isPublic: true,
      latestRelease: ReleaseInfo(
        tagName: 'v1.0.0',
        name: 'v1.0.0',
        publishedAt: DateTime.now(),
        body: '',
        assets: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCardItem(
            app: notInstalledApp,
            onInstallOrUpdate: () => installClicked = true,
            onLaunch: () => launchClicked = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ARP & Subnet Scout'), findsOneWidget);
    expect(find.text('L2/L3 active subnet discovery.'), findsOneWidget);
    expect(find.text('Install v1.0.0'), findsOneWidget);

    await tester.tap(find.text('Install v1.0.0'));
    expect(installClicked, isTrue);

    // 2. Installed state
    const installedApp = SuiteApp(
      definition: def,
      status: AppStatus.installed,
      installedVersion: 'v1.0.0',
      executablePath: '/dummy/bin',
      isPublic: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCardItem(
            app: installedApp,
            onInstallOrUpdate: () {},
            onLaunch: () => launchClicked = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Launch'), findsOneWidget);
    await tester.tap(find.text('Launch'));
    expect(launchClicked, isTrue);

    // 3. Downloading state
    const downloadingApp = SuiteApp(
      definition: def,
      status: AppStatus.downloading,
      downloadProgress: 0.65,
      statusMessage: 'Downloading: 65%',
      isPublic: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCardItem(
            app: downloadingApp,
            onInstallOrUpdate: () {},
            onLaunch: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Downloading: 65%'), findsOneWidget);
  });

  testWidgets('AppDetailsDialog renders details and triggers uninstall', (WidgetTester tester) async {
    bool uninstalled = false;
    final release = ReleaseInfo(
      tagName: 'v1.2.0',
      name: 'v1.2.0 Release',
      publishedAt: DateTime(2026, 11, 1),
      body: 'Release notes body content',
      assets: const [],
    );

    final app = SuiteApp(
      definition: const AppCatalogDefinition(
        id: 'packet-inspector',
        name: 'Packet Inspector',
        repoName: 'Packet-Inspector',
        defaultExecutableName: 'packet_inspector',
        category: 'Packet Analysis',
        summary: 'Packet decoder',
        icon: Icons.analytics,
      ),
      status: AppStatus.installed,
      installedVersion: 'v1.2.0',
      executablePath: '/path/packet_inspector',
      latestRelease: release,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDetailsDialog(
            app: app,
            onUninstall: () => uninstalled = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Packet Inspector'), findsOneWidget);
    expect(find.textContaining('Packet-Inspector • Packet Analysis'), findsOneWidget);
    expect(find.text('Release notes body content'), findsOneWidget);
    expect(find.text('Uninstall'), findsOneWidget);

    await tester.tap(find.text('Uninstall'));
    expect(uninstalled, isTrue);
  });

  testWidgets('AddDeviceDialog validates MAC and invokes callback', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? addedMac;
    String? addedName;

    final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
    final vm = DeviceManagerViewModel(repository: DeviceRepository(database: db));

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DeviceManagerViewModel>.value(
          value: vm,
          child: Scaffold(
            body: AddDeviceDialog(
              onAdd: ({required rawMac, required name, category, vendor, notes}) {
                addedMac = rawMac;
                addedName = name;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Register New Device'), findsOneWidget);

    // Try submitting empty -> triggers error
    await tester.tap(find.text('Add to Inventory'));
    await tester.pump();
    expect(find.textContaining('Enter a valid 12-digit hex MAC address'), findsOneWidget);

    // Enter valid MAC and Name
    await tester.enterText(find.byType(TextField).at(0), '00:1A:2B:3C:4D:5E');
    await tester.enterText(find.byType(TextField).at(1), 'Core Gateway');
    await tester.pump();

    await tester.tap(find.text('Add to Inventory'));
    await tester.pump();

    expect(addedMac, '00:1A:2B:3C:4D:5E');
    expect(addedName, 'Core Gateway');
  });

  testWidgets('EditDeviceDialog populates fields and saves changes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? savedName;
    String? savedCategory;

    final now = DateTime.now();
    final device = SharedDevice(
      macAddress: '00:11:22:33:44:55',
      name: 'Server Node',
      deviceType: 'server',
      vendor: 'Dell Inc.',
      notes: 'Rack 2',
      sourceApp: 'launcher',
      createdAt: now,
      updatedAt: now,
    );

    final db = SharedDeviceDatabase(customDb: sqlite3.openInMemory());
    final vm = DeviceManagerViewModel(repository: DeviceRepository(database: db));

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DeviceManagerViewModel>.value(
          value: vm,
          child: Scaffold(
            body: EditDeviceDialog(
              device: device,
              onSave: ({required name, required category, vendor, notes}) {
                savedName = name;
                savedCategory = category;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit Device Details'), findsOneWidget);
    expect(find.text('00:11:22:33:44:55'), findsOneWidget);
    expect(find.text('Server Node'), findsOneWidget);

    // Change name
    await tester.enterText(find.widgetWithText(TextField, 'Server Node'), 'Primary Server');
    await tester.pump();

    await tester.tap(find.text('Save Details'));
    await tester.pump();

    expect(savedName, 'Primary Server');
    expect(savedCategory, 'server');
  });

  testWidgets('CreateCategoryDialog creates custom category', (WidgetTester tester) async {
    String? createdId;
    String? createdLabel;
    String? createdIcon;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateCategoryDialog(
            onCreate: ({required id, required label, iconName = 'devices_other', colorHex}) {
              createdId = id;
              createdLabel = label;
              createdIcon = iconName;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Create Custom Category'), findsOneWidget);

    // Enter label
    await tester.enterText(find.byType(TextField).at(0), 'Access Point');
    await tester.pump();

    await tester.tap(find.text('Create Category'));
    await tester.pump();

    expect(createdId, 'access_point');
    expect(createdLabel, 'Access Point');
    expect(createdIcon, isNotNull);
  });
}
