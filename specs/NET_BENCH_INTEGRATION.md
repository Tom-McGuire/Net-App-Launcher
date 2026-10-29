# Integration Specification: Net-Bench

## App Overview
- **Repository**: `Tom-McGuire/Net-Bench`
- **Location**: `C:\Users\tommc\Projects\net-bench`
- **Purpose**: Bandwidth, jitter, and packet loss benchmarking with integrated iPerf3.

---

## Required Changes

### 1. `pubspec.yaml`
```yaml
dependencies:
  network_suite_shared:
    path: ../network_suite_shared
```

### 2. Standalone Benchmark Target Labels
1. In the Target Host selector, when the user tests against a device:
   - Provide an optional "Device Identity" lookup from `SharedDeviceDatabase.instance.getAllDevices()`.
   - Allows saving benchmark profiles against specific hardware (e.g. "Tom's Gaming Rig - 10G SFP+").

### 3. Standalone Guarantee
Benchmark tests against arbitrary IPs/hostnames work with or without the shared database.
