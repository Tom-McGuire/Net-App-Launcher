# Integration Specification: IGMP-Tester

## App Overview
- **Repository**: `Tom-McGuire/IGMP-Tester`
- **Location**: `C:\Users\tommc\Projects\igmp-tester`
- **Purpose**: IGMPv1/v2/v3 multicast group member simulation, query injection, and multicast stream diagnostics.

---

## Required Changes

### 1. `pubspec.yaml`
```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
```

### 2. Querier & Membership Report Identification
1. When receiving IGMP General Queries or Group-Specific Queries:
   - Identify the transmitting Querier router by MAC address via `SharedDeviceDatabase.instance.getDeviceByMac(mac)`.
   - Display friendly device name (e.g., "Core Gateway Router") in the active Querier indicator.
2. In the multicast stream analyzer, label group member interfaces using friendly device names.

### 3. Standalone Guarantee
Raw IGMP socket generation and capture operate with or without the shared device database.
