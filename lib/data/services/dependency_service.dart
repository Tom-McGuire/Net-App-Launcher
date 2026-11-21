import 'dart:io';
import 'package:network_suite_shared/network_suite_shared.dart';
import '../../domain/models/dependency_info.dart';

class DependencyService {
  DependencyService({CaptureBinaryLocator? captureLocator})
      : _captureLocator = captureLocator ?? CaptureBinaryLocator();

  final CaptureBinaryLocator _captureLocator;

  static CaptureTool? _matchCaptureTool(String binaryId) {
    final normalized = binaryId.trim().toLowerCase();
    for (final tool in CaptureTool.values) {
      if (tool.executableName == normalized) {
        return tool;
      }
    }
    return null;
  }

  /// Checks whether a required external CLI utility is installed on the host system.
  ///
  /// For packet capture binaries (`tshark`, `dumpcap`, `tcpdump`), delegates to
  /// [CaptureBinaryLocator] so standard OS install directories and capture-tool
  /// version flags are handled consistently across platforms.
  Future<DependencyInfo> checkDependency({
    required String id,
    required String name,
    required String installCommand,
  }) async {
    final captureTool = _matchCaptureTool(id);
    if (captureTool != null) {
      final info = await _captureLocator.locateBinary(
        captureTool,
        fetchVersion: true,
      );
      return DependencyInfo(
        id: id,
        name: name,
        isInstalled: info != null,
        version: info?.version,
        installCommand: installCommand,
      );
    }

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

  /// Diagnoses OS packet-capture permissions for [tool] via [CaptureBinaryLocator].
  Future<CapturePermissionResult> checkCapturePermissions(
    CaptureTool tool, {
    String? customPath,
  }) {
    return _captureLocator.checkCapturePermissions(
      tool,
      customPath: customPath,
    );
  }
}
