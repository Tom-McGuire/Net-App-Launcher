# Network Suite: Shared Device Library Integration Specification

## 1. Overview & Architecture

The **Network Suite** shares a cross-process, persistent hardware identity database (`shared_devices.db`) managed via SQLite in WAL mode.

### Key Tenets
1. **Hardware-Anchored Identity**: Devices are keyed strictly by **MAC address** (normalized to `XX:XX:XX:XX:XX:XX` uppercase). Volatile properties such as IP addresses are intentionally **NOT stored**, because IP addresses change across subnets, DHCP leases, and network topologies.
2. **Editable Device Names**: The user can assign and update a friendly name (e.g., "Living Room Apple TV", "Tom's Gaming Rig", "Core Switch") at any time from any app.
3. **Zero Launcher Dependency (Standalone Resilience)**: Applications do **NOT** depend on the Launcher being installed or running. If `network_suite_shared` is included in an app, it automatically locates or creates `%LOCALAPPDATA%\NetworkSuite\shared_devices.db` (or OS equivalent) on startup.

---

## 2. Shared Library Setup

Add `network_suite_shared` to the target application's `pubspec.yaml`:

```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
  sqlite3: ^3.7.1
  sqlite3_flutter_libs: ^0.6.0+eol
```

Then run:
```bash
flutter pub get
```

---

## 3. Standard Initialization Pattern

In `main.dart` or during application startup:

```dart
import 'package:network_suite_shared/network_suite_shared.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize shared database.
  // Will create directory and table if launcher is not installed.
  try {
    await SharedDeviceDatabase.instance.init();
  } catch (e) {
    debugPrint('Shared device database fallback: $e');
  }

  runApp(const MyApp());
}
```

---

## 4. Canonical API Operations

### 4.1 Lookup Device by MAC
```dart
final device = SharedDeviceDatabase.instance.getDeviceByMac(hostRecord.macAddress);
if (device != null) {
  // Display friendly custom name instead of raw MAC or default vendor
  print('Device Name: ${device.name}');
}
```

### 4.2 Updating a Device Name at Any Point
```dart
// The user edits a device name in your UI:
SharedDeviceDatabase.instance.updateDeviceName(macAddress, "New Friendly Name");
```

### 4.3 Registering a Discovered Device
```dart
final normalizedMac = SharedDevice.normalizeMac(rawMac);
final vendor = OuiLookup.lookupVendor(normalizedMac);
final category = OuiLookup.inferCategory(vendor, hostname);

final device = SharedDevice(
  macAddress: normalizedMac,
  name: hostname.isNotEmpty ? hostname : 'Device $normalizedMac',
  vendor: vendor,
  deviceType: category.key,
  notes: 'Discovered by arp-scout',
  sourceApp: 'arp-scout',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

SharedDeviceDatabase.instance.upsertDevice(device);
```

### 4.4 Listening for Changes Across Processes
```dart
// Subscribe to database modifications in ViewModels
_subscription = SharedDeviceDatabase.instance.onDatabaseChanged.listen((_) {
  refreshTableOrCache();
});
```

---

## 5. Multi-Process Concurrency & File Locations

- **Windows**: `%LOCALAPPDATA%\NetworkSuite\shared_devices.db`
- **Linux**: `~/.local/share/NetworkSuite/shared_devices.db` (or `$XDG_DATA_HOME/NetworkSuite/shared_devices.db`)
- **macOS**: `~/Library/Application Support/NetworkSuite/shared_devices.db`

Multi-process concurrency is guaranteed by SQLite Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) and a 5,000ms busy timeout. Multiple suite apps can read and write concurrently without file locks or crashes.
