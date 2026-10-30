import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/suite_app.dart';
import 'app_details_dialog.dart';

class AppCardItem extends StatelessWidget {
  final SuiteApp app;
  final VoidCallback onInstallOrUpdate;
  final VoidCallback onLaunch;
  final VoidCallback? onStop;
  final VoidCallback? onUninstall;

  const AppCardItem({
    super.key,
    required this.app,
    required this.onInstallOrUpdate,
    required this.onLaunch,
    this.onStop,
    this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final release = app.latestRelease;
    final isDownloading = app.status == AppStatus.downloading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon, Title & Category, Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    app.definition.icon,
                    size: 20,
                    color: AppTheme.primaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              app.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(app),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${app.definition.category} • ${app.definition.repoName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View Details & Options',
                  icon: const Icon(Icons.info_outline, size: 16),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AppDetailsDialog(
                        app: app,
                        onUninstall: onUninstall,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Description
            Expanded(
              child: Text(
                app.summary,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Dependency Warning (if any)
            if (app.dependencyInfo != null && !app.dependencyInfo!.isInstalled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Requires ${app.dependencyInfo!.name} (${app.dependencyInfo!.installCommand})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.warning,
                          fontFamily: 'Consolas',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Download Progress Bar
            if (isDownloading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: app.downloadProgress > 0 ? app.downloadProgress : null,
                backgroundColor: AppTheme.surfaceHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 4),
              Text(
                app.statusMessage ?? 'Downloading...',
                style: const TextStyle(fontSize: 10, color: AppTheme.primaryAccent),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Row 3: Action Buttons & Installed Version
            Row(
              children: [
                if (app.installedVersion != null)
                  Text(
                    'Installed: ${app.installedVersion}',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                else if (release != null)
                  Text(
                    'Latest: ${release.tagName}',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                else
                  Text(
                    'Unpublished',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                const Spacer(),

                // Update Button
                if (app.hasUpdate && !isDownloading) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryAccent,
                      side: const BorderSide(color: AppTheme.primaryAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.system_update_alt, size: 14),
                    label: Text(
                      'Update (${release?.tagName ?? ''})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: onInstallOrUpdate,
                  ),
                  const SizedBox(width: 8),
                ],

                // Stop Button (when running)
                if (app.isRunning && onStop != null && !isDownloading) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 14),
                    label: const Text(
                      'Stop',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onStop,
                  ),
                  const SizedBox(width: 8),
                ],

                // Launch or Install Button
                if (app.canLaunch && !isDownloading)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: app.isRunning ? AppTheme.warning : AppTheme.success,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    icon: Icon(
                      app.isRunning ? Icons.restart_alt : Icons.play_arrow,
                      size: 15,
                    ),
                    label: Text(
                      app.isRunning ? 'Running' : 'Launch',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onLaunch,
                  )
                else if (!isDownloading && release != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.download, size: 14),
                    label: Text(
                      'Install ${release.tagName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onInstallOrUpdate,
                  )
                else if (isDownloading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SuiteApp app) {
    Color color;
    String label;
    IconData icon;

    switch (app.status) {
      case AppStatus.installed:
        color = AppTheme.success;
        label = 'Installed';
        icon = Icons.check_circle_outline;
        break;
      case AppStatus.updateAvailable:
        color = AppTheme.warning;
        label = 'Update Available';
        icon = Icons.arrow_circle_up;
        break;
      case AppStatus.downloading:
      case AppStatus.extracting:
        color = AppTheme.primaryAccent;
        label = 'Installing';
        icon = Icons.downloading;
        break;
      case AppStatus.notInstalled:
        color = Colors.grey;
        label = 'Available';
        icon = Icons.cloud_download_outlined;
        break;
      case AppStatus.error:
        color = AppTheme.error;
        label = 'Error';
        icon = Icons.error_outline;
        break;
      case AppStatus.checking:
        color = Colors.grey;
        label = 'Checking';
        icon = Icons.sync;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
