import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../data/services/app_installer_service.dart';
import '../../domain/models/release_info.dart';

class LauncherSelfUpdateDialog extends StatefulWidget {
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
  State<LauncherSelfUpdateDialog> createState() => _LauncherSelfUpdateDialogState();
}

class _LauncherSelfUpdateDialogState extends State<LauncherSelfUpdateDialog> {
  bool _isUpdating = false;
  double _progress = 0.0;
  int _bytesReceived = 0;
  int _totalBytes = 0;
  String _status = '';
  String? _errorMessage;
  http.Client? _activeClient;

  @override
  void dispose() {
    _activeClient?.close();
    super.dispose();
  }

  Future<void> _startUpdate(ReleaseAsset asset) async {
    if (!AppInstallerService.isTrustedDownloadUrl(asset.downloadUrl)) {
      setState(() {
        _errorMessage = 'Blocked download from untrusted or non-HTTPS URL: ${asset.downloadUrl}';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _progress = 0.0;
      _bytesReceived = 0;
      _totalBytes = asset.sizeBytes;
      _status = 'Connecting to release asset download...';
      _errorMessage = null;
    });

    final client = http.Client();
    _activeClient = client;

    try {
      final safeName = p.basename(asset.name.trim());
      final tempDir = Directory.systemTemp.createTempSync('launcher_update_');
      final targetFile = File(p.join(tempDir.path, safeName));

      final request = http.Request('GET', Uri.parse(asset.downloadUrl));
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed with HTTP status ${response.statusCode}');
      }

      final total = response.contentLength ?? asset.sizeBytes;
      if (mounted) {
        setState(() {
          _totalBytes = total;
          _status = 'Downloading ${asset.name}...';
        });
      }

      final sink = targetFile.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (mounted) {
          setState(() {
            _bytesReceived = received;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
          });
        }
      }
      await sink.flush();
      await sink.close();

      if (total > 0 && received != total) {
        throw HttpException('Download incomplete: expected $total bytes, received $received bytes');
      }

      if (!mounted) return;

      final lowerName = targetFile.path.toLowerCase();

      if (Platform.isWindows && lowerName.endsWith('.exe')) {
        setState(() {
          _status = 'Launching installer and updating application...';
        });
        // Launch Inno Setup installer silently and restart application
        await Process.start(
          targetFile.path,
          ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
          mode: ProcessStartMode.detached,
        );
        await Future.delayed(const Duration(milliseconds: 600));
        exit(0);
      } else if (Platform.isMacOS && lowerName.endsWith('.dmg')) {
        setState(() {
          _status = 'Opening installer disk image...';
        });
        await Process.run('open', [targetFile.path]);
        if (mounted) {
          setState(() {
            _status = 'Disk image mounted. Drag Network Suite Launcher to your Applications folder.';
            _isUpdating = false;
          });
        }
      } else if (Platform.isLinux && lowerName.endsWith('.deb')) {
        setState(() {
          _status = 'Opening package installer...';
        });
        await Process.run('xdg-open', [targetFile.path]);
        if (mounted) {
          setState(() {
            _status = 'Package opened. Follow system installer prompts to finalize update.';
            _isUpdating = false;
          });
        }
      } else {
        setState(() {
          _status = 'Package downloaded to: ${targetFile.path}';
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Update error: $e';
          _isUpdating = false;
        });
      }
    } finally {
      client.close();
      _activeClient = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferredAsset = widget.release.findLauncherAssetForCurrentPlatform();
    final installerAsset = widget.release.findInstallerForCurrentPlatform();
    final isInstaller = installerAsset != null;
    final activeAsset = installerAsset ?? preferredAsset;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.primaryAccent),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
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
                    child: Icon(
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
                          'Current: ${SuiteConstants.currentVersion}  •  New: ${widget.release.tagName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Consolas',
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isUpdating)
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
                'WHAT\'S NEW IN ${widget.release.tagName} (${dateFormat.format(widget.release.publishedAt)})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.textPrimary.withValues(alpha: 0.7),
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
                      widget.release.body.trim().isNotEmpty
                          ? widget.release.body.trim()
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

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    border: Border.all(color: AppTheme.error),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 11, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Progress bar during update
              if (_isUpdating) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_totalBytes > 0)
                            Text(
                              '${(_progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _totalBytes > 0 ? _progress : null,
                        backgroundColor: AppTheme.surface,
                        color: AppTheme.primaryAccent,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      if (_totalBytes > 0)
                        Text(
                          '${(_bytesReceived / (1024 * 1024)).toStringAsFixed(1)} MB of ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 10,
                            color: AppTheme.textPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              if (!_isUpdating && activeAsset != null) ...[
                Row(
                  children: [
                    Icon(
                      isInstaller ? Icons.verified : Icons.folder_zip,
                      size: 14,
                      color: isInstaller ? AppTheme.success : AppTheme.textPrimary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isInstaller
                            ? 'Installer Asset: ${activeAsset.name} (${(activeAsset.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB)'
                            : 'Archive Asset: ${activeAsset.name} (${(activeAsset.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                          color: isInstaller ? AppTheme.success : AppTheme.textPrimary.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Action buttons
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
                      child: const Text('Later'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 15),
                      label: const Text('View on GitHub'),
                      onPressed: () {
                        final encodedTag = Uri.encodeComponent(widget.release.tagName);
                        final url =
                            'https://github.com/${SuiteConstants.defaultGithubOwner}/${SuiteConstants.launcherRepoName}/releases/tag/$encodedTag';
                        LauncherSelfUpdateDialog.openUrl(url);
                      },
                    ),
                    if (activeAsset != null && activeAsset.downloadUrl.isNotEmpty) ...[
                      if (isInstaller && Platform.isWindows)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: AppTheme.onFilled,
                          ),
                          icon: _isUpdating
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onFilled),
                                )
                              : const Icon(Icons.system_update_alt, size: 16),
                          label: Text(_isUpdating ? 'Updating...' : 'Install & Update'),
                          onPressed: _isUpdating ? null : () => _startUpdate(activeAsset),
                        )
                      else if (isInstaller)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: AppTheme.onFilled,
                          ),
                          icon: _isUpdating
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onFilled),
                                )
                              : const Icon(Icons.download_for_offline, size: 16),
                          label: Text(_isUpdating ? 'Downloading...' : 'Update & Open'),
                          onPressed: _isUpdating ? null : () => _startUpdate(activeAsset),
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.warning,
                            foregroundColor: AppTheme.onFilled,
                          ),
                          icon: const Icon(Icons.download, size: 15),
                          label: Text('Download ${widget.release.tagName}'),
                          onPressed: () {
                            LauncherSelfUpdateDialog.openUrl(activeAsset.downloadUrl);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
