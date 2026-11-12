import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../../view_models/device_manager_view_model.dart';
import 'create_category_dialog.dart';

class EditDeviceDialog extends StatefulWidget {
  final SharedDevice device;
  final void Function({
    required String name,
    required String category,
    String? vendor,
    String? notes,
  }) onSave;

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
  late TextEditingController _vendorController;
  late TextEditingController _notesController;
  late String _selectedCategoryKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _vendorController = TextEditingController(text: widget.device.vendor ?? '');
    _notesController = TextEditingController(text: widget.device.notes ?? '');
    _selectedCategoryKey = widget.device.deviceType?.trim().toLowerCase() ?? 'other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onSave(
        name: name,
        category: _selectedCategoryKey,
        vendor: _vendorController.text.trim().isNotEmpty
            ? _vendorController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeviceManagerViewModel>();
    final categories = vm.categories;

    // Ensure selectedCategoryKey exists in list or fallback
    final hasCategory = categories.any((c) => c.key == _selectedCategoryKey);
    if (!hasCategory && categories.isNotEmpty) {
      // If category key isn't in unified list, add it dynamically or resolve it
      final resolved = vm.resolveCategory(_selectedCategoryKey);
      if (!categories.any((c) => c.key == resolved.key)) {
        categories.add(resolved);
      }
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.edit_note, size: 20, color: AppTheme.primaryAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Edit Device Details',
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
                const SizedBox(height: 14),

                // Immutable Hardware Identity Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'MAC Address: ',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      Text(
                        widget.device.macAddress,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Source: ${widget.device.sourceApp}',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Name Input
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
                const SizedBox(height: 14),

                // Category Selection & New Category Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Device Category',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('New Category', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => CreateCategoryDialog(
                            onCreate: ({
                              required String id,
                              required String label,
                              String iconName = 'devices_other',
                              String? colorHex,
                            }) {
                              vm.createCustomCategory(
                                id: id,
                                label: label,
                                iconName: iconName,
                                colorHex: colorHex,
                              );
                              setState(() {
                                _selectedCategoryKey = id.trim().toLowerCase();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCategoryKey,
                  decoration: const InputDecoration(),
                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.key,
                      child: Row(
                        children: [
                          Icon(
                            cat.icon,
                            size: 15,
                            color: cat.color ?? AppTheme.primaryAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat.label,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (cat.isCustom) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: (cat.color ?? AppTheme.primaryAccent).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: cat.color ?? AppTheme.primaryAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategoryKey = val);
                  },
                ),
                const SizedBox(height: 14),

                // Hardware Vendor
                const Text(
                  'Hardware Vendor / Manufacturer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _vendorController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Cisco Systems, Inc., Apple, Dell',
                  ),
                ),
                const SizedBox(height: 14),

                // Notes / Location
                const Text(
                  'Notes / Physical Location (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Rack 2, Port 12, Static IP 192.168.1.50',
                  ),
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
                      child: const Text('Save Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
