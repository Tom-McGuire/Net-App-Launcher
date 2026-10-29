# Integration Specification: Net-Router

## App Overview
- **Repository**: `Tom-McGuire/Net-Router`
- **Location**: `C:\Users\tommc\Projects\net-router`
- **Purpose**: Virtual L3 software router, static route routing table tester, and NAT emulator.

---

## Required Changes

### 1. `pubspec.yaml`
```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
```

### 2. Static ARP & Neighbor Table Integration
1. In the Router Neighbor / ARP Table:
   - For every mapped next-hop MAC, query `SharedDeviceDatabase.instance.getDeviceByMac(mac)`.
   - Display friendly device name (e.g. "Upstream Firewall", "Access Switch 1") next to next-hop entries.
2. In Port Forwarding / NAT Rules:
   - Allow selecting a target hardware interface by friendly name.

### 3. Standalone Guarantee
Router emulation engine operates standalone without requiring the launcher.
