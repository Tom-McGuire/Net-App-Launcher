# Integration Specification: Net-Services

## App Overview
- **Repository**: `Tom-McGuire/Net-Services`
- **Location**: `C:\Users\tommc\Projects\net-services`
- **Purpose**: DHCP, DNS, and NTP core network servers.

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

### 3. DHCP Server Leases Table
1. When a client requests a DHCP lease via `DHCPDISCOVER` / `DHCPREQUEST`:
   - Inspect client MAC address in `SharedDeviceDatabase.instance.getDeviceByMac(clientMac)`.
   - If present: display the friendly name alongside the leased IP in the Active Leases table!
   - Allow setting a static reservation with friendly name auto-completion.

### 4. Wake-on-LAN (WOL) Integration
1. Add an **"Import from Shared Devices"** button to the Wake-on-LAN tab:
   - Queries `SharedDeviceDatabase.instance.getAllDevices()`.
   - Populates a device picker showing all known devices with their friendly names and categories.
   - Selecting a device immediately fills the target MAC address field!
2. When the user inputs a MAC manually:
   - Check if the MAC matches a known device in the shared database and show the friendly name label.

### 5. Standalone Guarantee
All services (DHCP, DNS, NTP) operate fully even if `shared_devices.db` is empty or the launcher is not installed.
