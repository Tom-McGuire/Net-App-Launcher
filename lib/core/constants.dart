import 'package:flutter/material.dart';

class SuiteConstants {
  static const String appTitle = 'Network Suite Launcher';
  static const String currentVersion = 'v0.7.3.Beta';
  static const String launcherRepoName = 'Net-App-Launcher';
  static const String defaultGithubOwner = 'Tom-McGuire';

  /// Standard apps storage directory path under %LOCALAPPDATA%\NetworkSuite\apps
  static const String appDirectoryName = 'NetworkSuite';

  /// Known applications in the Network Suite.
  /// All are checked against GitHub Releases API; only publicly released apps
  /// (or locally installed ones) are displayed in the launcher catalogue.
  static const List<AppCatalogDefinition> catalog = [
    AppCatalogDefinition(
      id: 'arp-scout',
      name: 'ARP & Subnet Scout',
      repoName: 'ARP-Scout',
      defaultExecutableName: 'arp_scout',
      category: 'Discovery & L2',
      summary: 'L2/L3 active subnet discovery, ARP table cache auditing, and duplicate IP/MAC conflict triage.',
      icon: Icons.radar,
    ),
    AppCatalogDefinition(
      id: 'packet-inspector',
      name: 'Packet Inspector',
      repoName: 'Packet-Inspector',
      defaultExecutableName: 'packet_inspector',
      category: 'Packet Analysis',
      summary: 'High-density packet decoder, stream reconstructor, and hex byte inspector for PCAP and live traffic.',
      icon: Icons.analytics,
    ),
    AppCatalogDefinition(
      id: 'net-services',
      name: 'Net Services Suite',
      repoName: 'Net-Services',
      defaultExecutableName: 'net_services',
      category: 'Core Services',
      summary: 'Configurable standalone DHCP, DNS, and NTP network servers for isolated lab testing.',
      icon: Icons.dns,
    ),
    AppCatalogDefinition(
      id: 'syslog-server',
      name: 'Syslog Server',
      repoName: 'Syslog-Server',
      defaultExecutableName: 'syslog_server',
      category: 'Monitoring & Logs',
      summary: 'RFC 3164 / 5424 high-speed UDP/TCP syslog collector with structured filtering and SQLite storage.',
      icon: Icons.receipt_long,
    ),
    AppCatalogDefinition(
      id: 'tshark-interface',
      name: 'TShark Interface',
      repoName: 'TShark-Interface',
      defaultExecutableName: 'tshark_interface',
      category: 'Packet Analysis',
      summary: 'Modern GUI capture engine and real-time frontend for Wireshark TShark.',
      icon: Icons.terminal,
      dependencyId: 'tshark',
      dependencyName: 'Wireshark / TShark',
      dependencyInstallCmd: 'winget install -e --id WiresharkFoundation.Wireshark',
    ),
    AppCatalogDefinition(
      id: 'net-bench',
      name: 'Net Bench',
      repoName: 'Net-Bench',
      defaultExecutableName: 'net_bench',
      category: 'Performance',
      summary: 'Bandwidth, latency, and packet loss benchmarking with integrated iPerf3 client/server.',
      icon: Icons.speed,
      dependencyId: 'iperf3',
      dependencyName: 'iPerf3',
      dependencyInstallCmd: 'winget install -e --id ar51an.iPerf3',
    ),
    AppCatalogDefinition(
      id: 'igmp-tester',
      name: 'IGMP Tester',
      repoName: 'IGMP-Tester',
      defaultExecutableName: 'igmp_tester',
      category: 'Multicast & L3',
      summary: 'IGMPv1/v2/v3 multicast group simulation, query injection, and multicast stream diagnostics.',
      icon: Icons.settings_input_antenna,
    ),
    AppCatalogDefinition(
      id: 'net-router',
      name: 'Net Router',
      repoName: 'Net-Router',
      defaultExecutableName: 'net_router',
      category: 'Routing & Forwarding',
      summary: 'Virtual L3 software router, static route routing table tester, and NAT emulator.',
      icon: Icons.alt_route,
    ),
    AppCatalogDefinition(
      id: 'net-route-scout',
      name: 'Net Route Scout',
      repoName: 'Net-Route-Scout',
      defaultExecutableName: 'net_route_scout',
      category: 'Topology & Routing',
      summary: 'Visual multi-hop network topology discovery and traceroute mapper with shared device identity integration.',
      icon: Icons.hub,
    ),
    AppCatalogDefinition(
      id: 'ip-setter',
      name: 'IP Setter',
      repoName: 'IP-Switcher',
      defaultExecutableName: 'ip_setter',
      category: 'Adapter & Config',
      summary: 'One-click network adapter preset switching (Static IPv4, DHCP, Gateway, DNS, alias IPs) with live NIC telemetry and rollback.',
      icon: Icons.tune,
    ),
    AppCatalogDefinition(
      id: 'socket-scout',
      name: 'Socket Scout',
      repoName: 'Socket-Scout',
      defaultExecutableName: 'socket_scout',
      category: 'Discovery & L2',
      summary: 'Switch Port Identifier (LLDP & CDP listener) for mapping physical wall sockets to switch ports, VLANs, and device identities.',
      icon: Icons.lan,
    ),
  ];
}

class AppCatalogDefinition {
  final String id;
  final String name;
  final String repoName;
  final String defaultExecutableName;
  final String category;
  final String summary;
  final IconData icon;
  final String? dependencyId;
  final String? dependencyName;
  final String? dependencyInstallCmd;

  const AppCatalogDefinition({
    required this.id,
    required this.name,
    required this.repoName,
    required this.defaultExecutableName,
    required this.category,
    required this.summary,
    required this.icon,
    this.dependencyId,
    this.dependencyName,
    this.dependencyInstallCmd,
  });
}
