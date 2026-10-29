# Integration Specification: ARP-Scout

## App Overview
- **Repository**: `Tom-McGuire/ARP-Scout`
- **Location**: `C:\Users\tommc\Projects\arp-scout`
- **Purpose**: L2/L3 active subnet scanning, ARP cache inspection, conflict detection.

---

## Required Changes

### 1. `pubspec.yaml`
Add `network_suite_shared` as a local path dependency:
```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
```

### 2. Startup Hook (`lib/main.dart`)
Initialize `SharedDeviceDatabase.instance.init()` inside `main()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SharedDeviceDatabase.instance.init();
  } catch (e) {
    debugPrint('Shared database offline: $e');
  }
  runApp(const ArpScoutApp());
}
```

### 3. Subnet Scan Completion Hook (`lib/data/repositories/arp_repository.dart` or `arp_scout_view_model.dart`)
When active hosts are discovered with valid resolved MAC addresses:
1. Check `SharedDeviceDatabase.instance.getDeviceByMac(host.macAddress)`.
2. If record exists:
   - Decorate `ArpHostRecord` with `customName: device.name`.
   - In the table row, show `device.name` prominently!
3. If user edits the device name in the detail panel or table:
   - Call `SharedDeviceDatabase.instance.updateDeviceName(host.macAddress, newName)`.
   - This immediately reflects across `packet-inspector`, `net-services`, and the `Launcher`.

### 4. Standalone Guarantee
If `shared_devices.db` is not present, `SharedDeviceDatabase.instance.init()` creates it automatically at `%LOCALAPPDATA%\NetworkSuite\shared_devices.db`. If SQLite is inaccessible, wrap calls in `try/catch` so ARP scanning continues unaffected.
