import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../domain/models/release_info.dart';

class LauncherSelfUpdateDialog extends StatelessWidget {
  final ReleaseInfo release;

  const LauncherSelfUpdateDialog({super.key, required this.release});

  /// Validates and opens an external HTTPS URL without invoking a command shell (`cmd.exe`).
  static bool isValidExternalHttpsUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    // Reject control characters or shell metacharacters
    if (RegExp(r'[\r\n\t"&|<>^`]').hasMatch(url)) return false;
    return true;
  }

  static void openUrl(String url) {
    final sanitized = url.trim();
    if (!isValidExternalHttpsUrl(sanitized)) return;

    if (Platform.isWindows) {
      // Avoid cmd.exe (/c start) to prevent shell metacharacter injection
      Process.run('rundll32.exe', ['url.dll,FileProtocolHandler', sanitized]);
    } else if (Platform.isMacOS) {
      Process.run('open', [sanitized]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [sanitized]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = release.findAssetForCurrentPlatform();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.primaryAccent),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.system_update,
                      size: 22,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network Suite Launcher Update',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current: ${SuiteConstants.currentVersion}  •  New: ${release.tagName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Consolas',
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                'WHAT\'S NEW IN ${release.tagName} (${dateFormat.format(release.publishedAt)})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),

              // Changelog container
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
                        fontFamily: 'Consolas',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (asset != null) ...[
                Text(
                  'Recommended Archive: ${asset.name} (${(asset.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_browser, size: 15),
                    label: const Text('View on GitHub'),
                    onPressed: () {
                      final encodedTag = Uri.encodeComponent(release.tagName);
                      final url = 'https://github.com/${SuiteConstants.defaultGithubOwner}/${SuiteConstants.launcherRepoName}/releases/tag/$encodedTag';
                      openUrl(url);
                    },
                  ),
                  if (asset != null && asset.downloadUrl.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.black),
                      icon: const Icon(Icons.download, size: 15),
                      label: Text('Download ${release.tagName}'),
                      onPressed: () {
                        openUrl(asset.downloadUrl);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
