# Integration Specification: TShark-Interface

## App Overview
- **Repository**: `Tom-McGuire/TShark-Interface`
- **Location**: `C:\Users\tommc\Projects\tshark-interface`
- **Purpose**: GUI frontend and live capture engine for Wireshark's TShark CLI.

---

## Required Changes

### 1. `pubspec.yaml`
```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
```

### 2. Dissection & Endpoint Resolution
1. In the TShark live dissection table and endpoint summaries:
   - Resolve MAC addresses using `SharedDeviceDatabase.instance.getDeviceByMac(mac)`.
   - Display friendly device name in place of raw MACs.
2. Provide a context menu option on packet rows: `"Rename Device in Suite"` calling `SharedDeviceDatabase.instance.updateDeviceName(mac, newName)`.

### 3. Standalone Guarantee
TShark process orchestration and live dissection run standalone without requiring the launcher.
