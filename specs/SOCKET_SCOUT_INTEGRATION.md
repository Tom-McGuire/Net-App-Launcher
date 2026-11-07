# Integration Specification: Socket Scout (Switch Port Identifier)

## App Overview
- **Repository**: `Tom-McGuire/Socket-Scout`
- **Location**: `\home\tom-code\projects\flutter\socket-scout`
- **Executable**: `socket_scout` (Windows: `socket_scout.exe`, Linux: `socket_scout`, macOS: `Socket Scout.app`)
- **Purpose**: Switch Port Identifier (LLDP & CDP listener) for capturing L2 discovery beacons, decoding switch chassis ID, port ID, VLANs, system name, and mapping physical wall jacks/sockets to switch infrastructure.

---

## Integration Details

### 1. Catalog Definition (`lib/core/constants.dart`)
```dart
AppCatalogDefinition(
  id: 'socket-scout',
  name: 'Socket Scout',
  repoName: 'Socket-Scout',
  defaultExecutableName: 'socket_scout',
  category: 'Discovery & L2',
  summary: 'Switch Port Identifier (LLDP & CDP listener) for mapping physical wall sockets to switch ports, VLANs, and device identities.',
  icon: Icons.lan,
)
```

### 2. Standalone Resilience & Capabilities
- Built with Flutter Desktop and SQLite database storage (`SwitchDatabaseService`).
- Cross-platform raw packet capture using bundled/detected system capture binaries (`dumpcap`, `tcpdump`, or `tshark`).
- Dissects standard IEEE 802.1AB LLDP (Link Layer Discovery Protocol) and Cisco CDP (Cisco Discovery Protocol) frames directly from live interface streams or PCAP files.
- Integrates with shared network suite databases (`network_suite_shared`) for shared device identity tracking.
