# Integration Specification: Packet-Inspector

## App Overview
- **Repository**: `Tom-McGuire/Packet-Inspector`
- **Location**: `C:\Users\tommc\Projects\packet-inspector`
- **Purpose**: Packet decoder, stream reconstructor, and hex byte inspector.

---

## Required Changes

### 1. `pubspec.yaml`
```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
```

### 2. Startup Hook (`lib/main.dart`)
Initialize `SharedDeviceDatabase.instance.init()` in `main()`.

### 3. Ethernet Dissection & Stream Views
1. When dissecting Ethernet II frames (`Source MAC` and `Destination MAC`):
   - Query `SharedDeviceDatabase.instance.getDeviceByMac(mac)`.
   - If found, format the endpoint header as:
     `Core Switch (00:1A:2B:3C:4D:5E)` rather than raw hex.
2. In the Packet Summary Inspector:
   - Provide a quick context menu action: `"Label Device in Suite..."` on right-clicking a MAC address.
   - When the user enters a new name, call `SharedDeviceDatabase.instance.updateDeviceName(mac, newName)`.

### 4. Standalone Guarantee
If the shared database cannot be opened, the packet inspector falls back to raw MAC display with zero crashes.
