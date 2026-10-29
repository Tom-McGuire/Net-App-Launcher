class DependencyInfo {
  final String id;
  final String name;
  final bool isInstalled;
  final String? version;
  final String installCommand;

  const DependencyInfo({
    required this.id,
    required this.name,
    required this.isInstalled,
    this.version,
    required this.installCommand,
  });

  DependencyInfo copyWith({
    String? id,
    String? name,
    bool? isInstalled,
    String? version,
    String? installCommand,
  }) {
    return DependencyInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      isInstalled: isInstalled ?? this.isInstalled,
      version: version ?? this.version,
      installCommand: installCommand ?? this.installCommand,
    );
  }
}
