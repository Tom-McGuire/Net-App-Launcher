import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/suite_app.dart';

class AppDetailsDialog extends StatelessWidget {
  final SuiteApp app;

  const AppDetailsDialog({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final release = app.latestRelease;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 550),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(app.definition.icon, size: 24, color: AppTheme.primaryAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${app.definition.repoName} • ${app.category}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (release != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        release.tagName,
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Overview
              Text(
                app.summary,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Release details
              if (release != null) ...[
                Text(
                  'RELEASE NOTES (${dateFormat.format(release.publishedAt)})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        release.body.trim().isNotEmpty
                            ? release.body.trim()
                            : 'No release notes provided for this version.',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Assets (${release.assets.length}): '
                  '${release.assets.map((a) => a.name).join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Consolas',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text(
                      'No published releases found for this repository on GitHub.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
