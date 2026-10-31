import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_app_launcher/data/repositories/device_repository.dart';
import 'package:net_app_launcher/main.dart';
import 'package:net_app_launcher/ui/view_models/device_manager_view_model.dart';
import 'package:net_app_launcher/ui/view_models/launcher_view_model.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

class MockLauncherViewModel extends LauncherViewModel {
  MockLauncherViewModel() : super();

  @override
  Future<void> loadApps() async {
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
  });
}
