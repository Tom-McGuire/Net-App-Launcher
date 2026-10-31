# Network Suite: Shared Device Library Integration Specification

## 1. Overview & Architecture

The **Network Suite** shares a cross-process, persistent hardware identity database (`shared_devices.db`) managed via SQLite in WAL mode.

### Key Tenets
1. **Hardware-Anchored Identity**: Devices are keyed strictly by **MAC address** (normalized to `XX:XX:XX:XX:XX:XX` uppercase). Volatile properties such as IP addresses are intentionally **NOT stored**, because IP addresses change across subnets, DHCP leases, and network topologies.
2. **Editable Device Metadata**: Users can assign and update friendly names, change device categories, specify vendor overrides, and attach notes at any time from any app.
3. **User-Defined Categories & Category Unification**: In addition to the 12 built-in device categories, users can create custom categories (slug `id`, `label`, `icon_name`, optional `color_hex`). A unified resolver merges built-in and custom categories for seamless UI display in dropdowns and filter chips.
4. **Zero Launcher Dependency (Standalone Resilience)**: Applications do **NOT** depend on the Launcher being installed or running. If `network_suite_shared` is included in an app, it automatically locates or creates `%LOCALAPPDATA%\NetworkSuite\shared_devices.db` (or OS equivalent) on startup.

---

## 2. Shared Library Setup

Add `network_suite_shared` to the target application's `pubspec.yaml`:

```yaml
dependencies:
  network_suite_shared:
    git:
      url: https://github.com/Tom-McGuire/network-suite-shared.git
      ref: main
  sqlite3: ^3.7.1
  sqlite3_flutter_libs: ^0.6.0+eol
```

Or for local development:
```yaml
dependencies:
  network_suite_shared:
    path: ../network-suite-shared
```

Then run:
```bash
flutter pub get
```

---

## 3. Database Schema

```sql
CREATE TABLE IF NOT EXISTS shared_devices (
  mac_address TEXT PRIMARY KEY NOT NULL,
  name        TEXT NOT NULL,
  vendor      TEXT,
  device_type TEXT,
  notes       TEXT,
  source_app  TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_shared_name ON shared_devices(name);
CREATE INDEX IF NOT EXISTS idx_shared_vendor ON shared_devices(vendor);
CREATE INDEX IF NOT EXISTS idx_shared_type ON shared_devices(device_type);

CREATE TABLE IF NOT EXISTS custom_device_categories (
  id          TEXT PRIMARY KEY NOT NULL,          -- Slug/key, e.g. "firewall", "smart_tv"
  label       TEXT NOT NULL,                      -- Display name, e.g. "Firewall / UTM", "Smart TV"
  icon_name   TEXT NOT NULL DEFAULT 'devices_other', -- Material icon identifier key
  color_hex   TEXT,                               -- Optional accent color, e.g. "#FF5722"
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_custom_category_label ON custom_device_categories(label);
```

---

## 4. Standard Initialization Pattern

In `main.dart` or during application startup:

```dart
import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize shared database.
  // Will create directory and tables if uninitialized.
  try {
    await SharedDeviceDatabase.instance.init();
  } catch (e) {
    debugPrint('Shared device database fallback: $e');
  }

  runApp(const MyApp());
}
```

---

## 5. Canonical API Operations

### 5.1 Lookup Device by MAC
```dart
final device = SharedDeviceDatabase.instance.getDeviceByMac(hostRecord.macAddress);
if (device != null) {
  // Display friendly custom name instead of raw MAC or default vendor
  print('Device Name: ${device.name}');
}
```

### 5.2 Updating a Device Name
```dart
// The user edits a device name in your UI:
SharedDeviceDatabase.instance.updateDeviceName(macAddress, "New Friendly Name");
```

### 5.3 Full Device Metadata Editing
To update any combination of name, category/device_type, vendor, and notes in a single call:

```dart
SharedDeviceDatabase.instance.updateDeviceDetails(
  macAddress,
  name: "Living Room Apple TV",
  deviceType: "smart_tv",              // Built-in key or custom category slug
  vendor: "Apple, Inc.",
  notes: "Connected via Ethernet to Port 4",
);
```
Any parameter left `null` keeps its existing value unchanged.

### 5.4 Custom Categories Management

#### Creating or Updating a Custom Category
```dart
SharedDeviceDatabase.instance.upsertCustomCategory(
  CustomDeviceCategory(
    id: 'smart_tv',
    label: 'Smart TV',
    iconName: 'tv',
    colorHex: '#2196F3',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
);
```

#### Deleting a Custom Category (Safe Cascade to 'other')
When a custom category is deleted, devices assigned to that category automatically have their `device_type` migrated to `'other'`:
```dart
SharedDeviceDatabase.instance.deleteCustomCategory('smart_tv');
```

#### Listing Custom Categories
```dart
final customCategories = SharedDeviceDatabase.instance.getCustomCategories();
```

### 5.5 Unified Category Resolution (UI Dropdowns & Chips)
`UnifiedDeviceCategory` unifies the 12 built-in `DeviceCategory` enum values with user-created `CustomDeviceCategory` instances:

```dart
// Fetch unified list for category selector dropdowns or filter chips
final categories = SharedDeviceDatabase.instance.getUnifiedCategories();

for (final cat in categories) {
  print('${cat.label} (key: ${cat.key}, isCustom: ${cat.isCustom})');
}

// Resolve category for a specific device:
final customCats = SharedDeviceDatabase.instance.getCustomCategories();
final unifiedCategory = device.getUnifiedCategory(customCats);

// In Flutter Widget:
Icon(unifiedCategory.icon, color: unifiedCategory.color);
Text(unifiedCategory.label);
```

### 5.6 Registering a Discovered Device
```dart
final normalizedMac = SharedDevice.normalizeMac(rawMac);
final vendor = OuiLookup.lookupVendor(normalizedMac);
final category = OuiLookup.inferCategory(vendor, hostname);

final device = SharedDevice(
  macAddress: normalizedMac,
  name: hostname.isNotEmpty ? hostname : 'Device $normalizedMac',
  vendor: vendor != 'Unknown Vendor' ? vendor : null,
  deviceType: category.key,
  notes: 'Discovered by arp-scout',
  sourceApp: 'arp-scout',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

SharedDeviceDatabase.instance.upsertDevice(device);
```

### 5.7 Listening for Changes Across Processes
```dart
// Subscribe to database modifications in ViewModels
_subscription = SharedDeviceDatabase.instance.onDatabaseChanged.listen((_) {
  refreshTableOrCache();
});
```

### 5.8 Querying with Filters & Hiding Auto-Generated Names
```dart
final devices = SharedDeviceDatabase.instance.getAllDevices(
  query: 'cisco',
  deviceType: 'switch',
  sortBy: 'updated_at',
  ascending: false,
  hideDefaultNamed: true, // Only returns devices with user-assigned custom names
);
```

---

## 6. Multi-Process Concurrency & File Locations

- **Windows**: `%LOCALAPPDATA%\NetworkSuite\shared_devices.db`
- **Linux**: `~/.local/share/NetworkSuite/shared_devices.db` (or `$XDG_DATA_HOME/NetworkSuite/shared_devices.db`)
- **macOS**: `~/Library/Application Support/NetworkSuite/shared_devices.db`

Multi-process concurrency is guaranteed by SQLite Write-Ahead Logging (`PRAGMA journal_mode = WAL;`), a 5,000ms busy timeout, and `PRAGMA synchronous = NORMAL;`. Multiple suite apps can read and write concurrently without file locks or crashes.
