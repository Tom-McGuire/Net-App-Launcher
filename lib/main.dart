import 'dart:async';

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

  // Apply the suite-wide theme before the first frame to avoid a flash.
  AppTheme.applyThemeMode(await SharedDeviceDatabase.instance.getThemeMode());

  runApp(const NetworkSuiteLauncherApp());
}

class NetworkSuiteLauncherApp extends StatefulWidget {
  final LauncherViewModel? launcherViewModel;
  final DeviceManagerViewModel? deviceManagerViewModel;

  /// Source of the suite-wide theme mode. Defaults to the shared database.
  final SharedDeviceDatabase? database;

  const NetworkSuiteLauncherApp({
    super.key,
    this.launcherViewModel,
    this.deviceManagerViewModel,
    this.database,
  });

  @override
  State<NetworkSuiteLauncherApp> createState() =>
      _NetworkSuiteLauncherAppState();
}

class _NetworkSuiteLauncherAppState extends State<NetworkSuiteLauncherApp> {
  late final SharedDeviceDatabase _db;
  StreamSubscription<void>? _dbSub;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? SharedDeviceDatabase.instance;
    _syncTheme();
    // Fires for local writes and for writes made by other suite processes.
    _dbSub = _db.onDatabaseChanged.listen((_) => _syncTheme());
  }

  Future<void> _syncTheme() async {
    final mode = await _db.getThemeMode();
    if (!mounted || mode == AppTheme.themeMode) return;
    setState(() => AppTheme.applyThemeMode(mode));
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedDeviceDatabase>.value(value: _db),
        ChangeNotifierProvider(
          create: (_) => widget.launcherViewModel ?? LauncherViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => widget.deviceManagerViewModel ?? DeviceManagerViewModel(),
        ),
      ],
      child: MaterialApp(
        title: 'Network Suite Launcher',
        debugShowCheckedModeBanner: false,
        themeMode: AppTheme.isDark ? ThemeMode.dark : ThemeMode.light,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        // Re-keying forces every descendant to re-resolve AppTheme.* getters.
        home: KeyedSubtree(
          key: ValueKey(AppTheme.themeMode),
          child: const LauncherMainScreen(),
        ),
      ),
    );
  }
}
