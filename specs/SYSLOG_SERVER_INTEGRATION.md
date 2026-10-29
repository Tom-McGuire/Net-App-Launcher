# Integration Specification: Syslog-Server

## App Overview
- **Repository**: `Tom-McGuire/Syslog-Server`
- **Location**: `C:\Users\tommc\Projects\syslog-server`
- **Purpose**: RFC 3164 / 5424 high-speed syslog collector.

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

### 3. Log Message Dissection & Sender Resolution
1. When syslog messages are received containing a hardware MAC address (common in DHCP snooping, 802.1X, and firewall logs):
   - Highlight detected MAC addresses with an interactive chip.
   - Resolve MAC to friendly name using `SharedDeviceDatabase.instance.getDeviceByMac(mac)`.
2. Allow right-clicking a MAC in any syslog event payload to trigger `"Rename Device"` via `SharedDeviceDatabase.instance.updateDeviceName(mac, newName)`.

### 4. Standalone Guarantee
Syslog receiver sockets bind and persist logs to local SQLite independently of the shared library's state.
