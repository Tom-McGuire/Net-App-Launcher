import 'dart:io';
import 'local_app_registry.dart';

class AppRunnerService {
  final Map<String, Process> _runningProcesses = {};

  bool isAppRunning(String appId) => _runningProcesses.containsKey(appId);

  /// Launches an application process and tracks its running state.
  Future<Process> launchApp({
    required String appId,
    required String executablePath,
    List<String> arguments = const [],
    void Function()? onExited,
  }) async {
    if (!LocalAppRegistry.executableExists(executablePath)) {
      throw Exception('Target executable does not exist at $executablePath');
    }

    late final Process process;
    if (Platform.isMacOS &&
        executablePath.toLowerCase().endsWith('.app') &&
        Directory(executablePath).existsSync()) {
      process = await Process.start(
        'open',
        ['-W', '-a', executablePath, if (arguments.isNotEmpty) ...['--args', ...arguments]],
        mode: ProcessStartMode.normal,
      );
    } else {
      final file = File(executablePath);
      process = await Process.start(
        executablePath,
        arguments,
        mode: ProcessStartMode.normal,
        workingDirectory: file.parent.path,
      );
    }

    // Drain stdout and stderr streams so child process never blocks on full OS pipes
    process.stdout.drain<void>().catchError((_) {});
    process.stderr.drain<void>().catchError((_) {});

    _runningProcesses[appId] = process;

    // Track exit
    process.exitCode.then((_) {
      _runningProcesses.remove(appId);
      onExited?.call();
    }).catchError((_) {
      _runningProcesses.remove(appId);
      onExited?.call();
    });

    return process;
  }

  /// Terminates a launched process if tracked.
  void terminateApp(String appId) {
    final process = _runningProcesses.remove(appId);
    process?.kill(ProcessSignal.sigterm);
  }
}
