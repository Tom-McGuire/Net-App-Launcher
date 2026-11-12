import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../../view_models/device_manager_view_model.dart';
import 'create_category_dialog.dart';

class AddDeviceDialog extends StatefulWidget {
  final void Function({
    required String rawMac,
    required String name,
    String? category,
    String? vendor,
    String? notes,
  }) onAdd;

  const AddDeviceDialog({super.key, required this.onAdd});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _macController = TextEditingController();
  final _nameController = TextEditingController();
  final _vendorController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategoryKey = 'other';
  String? _macError;

  @override
  void initState() {
    super.initState();
    _macController.addListener(_onMacChanged);
  }

  @override
  void dispose() {
    _macController.removeListener(_onMacChanged);
    _macController.dispose();
    _nameController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onMacChanged() {
    final raw = _macController.text;
    final clean = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    if (clean.length >= 6) {
      final detectedVendor = OuiLookup.lookupVendor(clean);
      if (detectedVendor != 'Unknown Vendor' && _vendorController.text.isEmpty) {
        _vendorController.text = detectedVendor;
        _selectedCategoryKey = OuiLookup.inferCategory(detectedVendor).key;
        setState(() {});
      }
    }
  }

  void _submit() {
    final rawMac = _macController.text.trim();
    if (!SharedDevice.isValidMac(rawMac)) {
      setState(() {
        _macError = 'Enter a valid 12-digit hex MAC address (e.g. 00:1A:2B:3C:4D:5E)';
      });
      return;
    }

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Device ${SharedDevice.normalizeMac(rawMac)}';

    widget.onAdd(
      rawMac: rawMac,
      name: name,
      category: _selectedCategoryKey,
      vendor: _vendorController.text.trim().isNotEmpty ? _vendorController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeviceManagerViewModel>();
    final categories = vm.categories;

    // Ensure selectedCategoryKey exists in list
    if (!categories.any((c) => c.key == _selectedCategoryKey) && categories.isNotEmpty) {
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
                    Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Register New Device',
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

                // MAC Address (Permanent hardware identifier)
                const Text(
                  'MAC Address (Permanent Hardware Identity)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _macController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
                  decoration: InputDecoration(
                    hintText: '00:1A:2B:3C:4D:5E or 001A2B3C4D5E',
                    errorText: _macError,
                  ),
                  onChanged: (_) {
                    if (_macError != null) setState(() => _macError = null);
                  },
                ),
                const SizedBox(height: 14),

                // Device Name
                const Text(
                  'Device Friendly Name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Core Switch, Tom\'s PC, Living Room Apple TV',
                  ),
                ),
                const SizedBox(height: 14),

                // Category & Hardware Vendor Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
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
                                child: Text(
                                  '+ Custom',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
                                      size: 14,
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
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategoryKey = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Hardware Vendor
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hardware Vendor (OUI)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _vendorController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Cisco Systems, Apple',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notes
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
                    hintText: 'e.g. Rack 2, Port 12, static configuration',
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
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
                      child: const Text('Add to Inventory'),
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
