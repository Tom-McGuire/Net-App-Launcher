import 'dart:io';

class AppRunnerService {
  final Map<String, Process> _runningProcesses = {};

  bool isAppRunning(String appId) => _runningProcesses.containsKey(appId);

  /// Launches an application process in detached mode.
  Future<Process> launchApp({
    required String appId,
    required String executablePath,
    List<String> arguments = const [],
    void Function()? onExited,
  }) async {
    final file = File(executablePath);
    if (!file.existsSync()) {
      throw Exception('Target executable does not exist at $executablePath');
    }

    final process = await Process.start(
      executablePath,
      arguments,
      mode: ProcessStartMode.detached,
      workingDirectory: file.parent.path,
    );

    _runningProcesses[appId] = process;

    // Track exit
    process.exitCode.then((code) {
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
