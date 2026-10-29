import 'dart:io';
import '../../domain/models/dependency_info.dart';

class DependencyService {
  /// Checks whether a required external CLI utility is installed on the host system.
  Future<DependencyInfo> checkDependency({
    required String id,
    required String name,
    required String installCommand,
  }) async {
    final binary = id.toLowerCase();
    String? version;
    bool isInstalled = false;

    try {
      // 1. Check path resolution
      final whichCmd = Platform.isWindows ? 'where.exe' : 'which';
      final pathResult = await Process.run(whichCmd, [binary]);

      if (pathResult.exitCode == 0) {
        isInstalled = true;

        // 2. Query version string
        try {
          final verResult = await Process.run(binary, ['--version']);
          if (verResult.exitCode == 0) {
            final output = verResult.stdout.toString().split('\n').first.trim();
            version = output;
          }
        } catch (_) {
          // Binary exists even if --version is unrecognized
        }
      }
    } catch (_) {
      isInstalled = false;
    }

    return DependencyInfo(
      id: id,
      name: name,
      isInstalled: isInstalled,
      version: version,
      installCommand: installCommand,
    );
  }
}
