# Integration Specification: Net-Route-Scout

## App Overview
- **Repository**: `Tom-McGuire/Net-Route-Scout`
- **Location**: `C:\Users\tommc\Projects\route-tracer` (or `/home/tom-code/projects/flutter/route-tracer`)
- **Executable**: `net_route_scout`
- **Purpose**: Visual multi-hop network topology discovery, traceroute mapping, and latency diagnosis with Shared Device Database integration.

---

## Integration Details

### 1. Catalog Definition (`lib/core/constants.dart`)
```dart
AppCatalogDefinition(
  id: 'net-route-scout',
  name: 'Net Route Scout',
  repoName: 'Net-Route-Scout',
  defaultExecutableName: 'net_route_scout',
  category: 'Topology & Routing',
  summary: 'Visual multi-hop network topology discovery and traceroute mapper with shared device identity integration.',
  icon: Icons.hub,
)
```

### 2. Standalone Resilience & Shared Device Database
- Uses `network_suite_shared` to query and update `%LOCALAPPDATA%\NetworkSuite\shared_devices.db`.
- Nodes mapped during traceroute and ARP sweeps automatically look up friendly device names and categories from the shared database.
- Any device edits in Net Route Scout immediately reflect in the Launcher and other suite apps.
