# Integration Specification: IP-Setter (IP Profile Switcher)

## App Overview
- **Repository**: `Tom-McGuire/IP-Switcher`
- **Location**: `C:\Users\tommc\Projects\ip-setter` (or `/home/tom-code/projects/ip-setter`)
- **Executable**: `ip_setter`
- **Purpose**: One-click network adapter preset configuration (Static IPv4, DHCP, Gateway, DNS, secondary alias IPs) with live NIC telemetry and rollback.

---

## Integration Details

### 1. Catalog Definition (`lib/core/constants.dart`)
```dart
AppCatalogDefinition(
  id: 'ip-setter',
  name: 'IP Setter',
  repoName: 'IP-Switcher',
  defaultExecutableName: 'ip_setter',
  category: 'Adapter & Config',
  summary: 'One-click network adapter preset switching (Static IPv4, DHCP, Gateway, DNS, alias IPs) with live NIC telemetry and rollback.',
  icon: Icons.tune,
)
```

### 2. Standalone Resilience & Capabilities
- Built with Flutter Desktop and SQLite storage.
- Manages network interface configurations cross-platform (`netsh`/PowerShell on Windows, `networksetup`/`ifconfig` on macOS, `nmcli`/`ip` on Linux).
- Supports pre-mutation configuration snapshots with one-click undo and automated rollback on failure.
- Custom color-coded category filters for field, lab, and staging adapter profiles.
