import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../view_models/device_manager_view_model.dart';
import '../view_models/launcher_view_model.dart';
import 'apps/apps_dashboard_view.dart';
import 'devices/device_manager_view.dart';
import 'launcher_self_update_dialog.dart';

class LauncherMainScreen extends StatefulWidget {
  const LauncherMainScreen({super.key});

  @override
  State<LauncherMainScreen> createState() => _LauncherMainScreenState();
}

class _LauncherMainScreenState extends State<LauncherMainScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // Graceful desktop exit handler
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final launcherVm = context.watch<LauncherViewModel>();
    final deviceVm = context.watch<DeviceManagerViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Column(
        children: [
          // 1. TOP CONTROL BAR (Tier 1)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                // Suite Logo / Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        size: 20,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Subtitle
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'NETWORK SUITE LAUNCHER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Desktop Store & Shared Device Inventory',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Navigation Tabs
                _buildNavTab(
                  index: 0,
                  label: 'Store',
                  icon: Icons.apps,
                  badgeCount: launcherVm.apps.where((a) => a.hasUpdate).length,
                  badgeColor: AppTheme.warning,
                  isSelected: launcherVm.selectedTabIndex == 0,
                  onTap: () => launcherVm.switchTab(0),
                ),
                const SizedBox(width: 8),
                _buildNavTab(
                  index: 1,
                  label: 'Shared Devices',
                  icon: Icons.devices,
                  badgeCount: deviceVm.totalCount,
                  badgeColor: AppTheme.primaryAccent,
                  isSelected: launcherVm.selectedTabIndex == 1,
                  onTap: () => launcherVm.switchTab(1),
                ),

                const SizedBox(width: 16),

                // Self-Update notification pill (if newer launcher release exists on GitHub)
                if (launcherVm.isLauncherUpdateAvailable) ...[
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => LauncherSelfUpdateDialog(
                          release: launcherVm.launcherSelfUpdate!,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_circle_up, size: 13, color: AppTheme.warning),
                          const SizedBox(width: 5),
                          Text(
                            'Launcher ${launcherVm.launcherSelfUpdate!.tagName} Available',
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Header Info
                const Text(
                  'GitHub: Tom-McGuire',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // 2. GLOBAL ALERT / STATUS BANNER (Conditional - Tier 2)
          if (launcherVm.isRateLimited)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.warning.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GitHub API rate limit reached (60 req/hr per IP). ${launcherVm.rateLimitResetDescription ?? 'Resetting shortly.'} • Serving locally cached releases.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            )
          else if (launcherVm.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.error.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      launcherVm.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),

          // 3 & 4. PRIMARY CONTENT WORKSPACE
          Expanded(
            child: IndexedStack(
              index: launcherVm.selectedTabIndex,
              children: const [
                AppsDashboardView(),
                DeviceManagerView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required String label,
    required IconData icon,
    required int badgeCount,
    required Color badgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppTheme.primaryAccent : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
