import 'dart:io';

class NetworkAdapterOption {
  final String name;
  final String ipAddress;

  const NetworkAdapterOption({
    required this.name,
    required this.ipAddress,
  });

  String get displayLabel => '$name ($ipAddress)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkAdapterOption &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          ipAddress == other.ipAddress;

  @override
  int get hashCode => Object.hash(name, ipAddress);

  @override
  String toString() => displayLabel;

  /// Discovers all active non-loopback IPv4 network interfaces on the host.
  static Future<List<NetworkAdapterOption>> discoverAdapters() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final options = <NetworkAdapterOption>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            options.add(
              NetworkAdapterOption(
                name: iface.name,
                ipAddress: addr.address,
              ),
            );
          }
        }
      }
      return options;
    } catch (_) {
      return const [];
    }
  }
}
