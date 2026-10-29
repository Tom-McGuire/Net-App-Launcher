import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'ui/view_models/device_manager_view_model.dart';
import 'ui/view_models/launcher_view_model.dart';
import 'ui/views/launcher_main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the cross-process SQLite database in standard location
  await SharedDeviceDatabase.instance.init();

  runApp(const NetworkSuiteLauncherApp());
}

class NetworkSuiteLauncherApp extends StatelessWidget {
  final LauncherViewModel? launcherViewModel;
  final DeviceManagerViewModel? deviceManagerViewModel;

  const NetworkSuiteLauncherApp({
    super.key,
    this.launcherViewModel,
    this.deviceManagerViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => launcherViewModel ?? LauncherViewModel()),
        ChangeNotifierProvider(create: (_) => deviceManagerViewModel ?? DeviceManagerViewModel()),
      ],
      child: MaterialApp(
        title: 'Network Suite Launcher',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme(),
        home: const LauncherMainScreen(),
      ),
    );
  }
}
