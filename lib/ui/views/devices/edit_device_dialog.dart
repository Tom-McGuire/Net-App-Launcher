import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import '../../../core/app_theme.dart';

class EditDeviceDialog extends StatefulWidget {
  final SharedDevice device;
  final void Function(String newName) onSave;

  const EditDeviceDialog({
    super.key,
    required this.device,
    required this.onSave,
  });

  @override
  State<EditDeviceDialog> createState() => _EditDeviceDialogState();
}

class _EditDeviceDialogState extends State<EditDeviceDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      widget.onSave(newName);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.edit_note, size: 20, color: AppTheme.primaryAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Rename Device',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 16),

              // Immutable Hardware Identity Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'MAC Address: ',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          widget.device.macAddress,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Hardware Vendor: ',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Expanded(
                          child: Text(
                            widget.device.vendor ?? 'Unknown Hardware',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Name Input (Editable at any point)
              const Text(
                'Friendly Device Name',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g. Core Switch, Tom\'s PC, Living Room TV',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                    onPressed: _submit,
                    child: const Text('Save Name'),
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
