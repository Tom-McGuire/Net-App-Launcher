import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../../view_models/device_manager_view_model.dart';
import 'add_device_dialog.dart';
import 'edit_device_dialog.dart';

class DeviceManagerView extends StatelessWidget {
  const DeviceManagerView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeviceManagerViewModel>();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Column(
      children: [
        // Filter & Triage Toolbar (Tier 3)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // Search Input
              SizedBox(
                width: 240,
                height: 32,
                child: TextField(
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search MAC, name, vendor...',
                    prefixIcon: const Icon(Icons.search, size: 15),
                    suffixIcon: vm.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () => vm.setSearchQuery(''),
                          )
                        : null,
                  ),
                  onChanged: vm.setSearchQuery,
                ),
              ),
              const SizedBox(width: 8),

              // Toggle: Hide Unnamed Devices (On by default)
              Tooltip(
                message: vm.hideDefaultNamed
                    ? 'Hiding devices with default MAC address labels (Click to show all)'
                    : 'Showing all devices (Click to hide devices with default MAC labels)',
                child: InkWell(
                  onTap: vm.toggleHideDefaultNamed,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: vm.hideDefaultNamed
                          ? AppTheme.primaryAccent.withValues(alpha: 0.15)
                          : AppTheme.inputFill,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: vm.hideDefaultNamed
                            ? AppTheme.primaryAccent.withValues(alpha: 0.6)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          vm.hideDefaultNamed
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 14,
                          color: vm.hideDefaultNamed
                              ? AppTheme.primaryAccent
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Hide Unnamed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: vm.hideDefaultNamed
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: vm.hideDefaultNamed
                                ? AppTheme.primaryAccent
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Category Filter Dropdown / Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip(context, vm, 'all', 'All Devices', Icons.devices),
                      ...DeviceCategory.values.map(
                        (c) => _buildCategoryChip(context, vm, c.key, c.label, c.icon),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Actions: Add Device, Import, Export
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add Device', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddDeviceDialog(
                      onAdd: vm.addDevice,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Import Popup
              PopupMenuButton<String>(
                tooltip: 'Import Devices',
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                onSelected: (val) => _handleImport(context, vm, val),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Import from CSV', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'json',
                    child: Row(
                      children: [
                        Icon(Icons.code, size: 16),
                        SizedBox(width: 8),
                        Text('Import from JSON', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),

              // Export Popup
              PopupMenuButton<String>(
                tooltip: 'Export Devices',
                icon: const Icon(Icons.file_download_outlined, size: 18),
                onSelected: (val) => _handleExport(context, vm, val),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Export to CSV', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'json',
                    child: Row(
                      children: [
                        Icon(Icons.code, size: 16),
                        SizedBox(width: 8),
                        Text('Export to JSON', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Primary Data Workspace (Tier 4) - High-Density Virtualized Data Table
        Expanded(
          child: vm.devices.isEmpty
              ? _buildEmptyState(context, vm)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 1050,
                    child: Column(
                      children: [
                        // Table Header
                        _buildTableHeader(context, vm),
                        const Divider(),

                        // Table Rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: vm.devices.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final device = vm.devices[index];
                              final isSelected = vm.selectedDevice?.macAddress == device.macAddress;

                              return _buildTableRow(
                                context: context,
                                vm: vm,
                                device: device,
                                isSelected: isSelected,
                                dateFormat: dateFormat,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Collapsible Detail Inspector & Persistent Status Bar (Tier 5)
        _buildBottomInspector(context, vm, dateFormat),
      ],
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    DeviceManagerViewModel vm,
    String key,
    String label,
    IconData icon,
  ) {
    final isSelected = vm.selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 13,
          color: isSelected ? AppTheme.primaryAccent : Colors.grey,
        ),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (_) => vm.setSelectedCategory(key),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        selectedColor: AppTheme.primaryAccent.withValues(alpha: 0.25),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryAccent : AppTheme.border,
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, DeviceManagerViewModel vm) {
    return Container(
      color: AppTheme.surfaceHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // MAC Address
          _buildHeaderColumn('MAC ADDRESS', 'mac', 160, vm),
          // Device Name
          Expanded(child: _buildHeaderColumn('DEVICE NAME', 'name', 0, vm)),
          // Category
          _buildHeaderColumn('CATEGORY', 'type', 140, vm),
          // Vendor
          _buildHeaderColumn('HARDWARE VENDOR', 'vendor', 180, vm),
          // Source App
          const SizedBox(
            width: 100,
            child: Text(
              'SOURCE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          // Updated
          _buildHeaderColumn('LAST MODIFIED', 'updated_at', 150, vm),
          // Actions
          const SizedBox(
            width: 70,
            child: Text(
              'ACTIONS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderColumn(
    String label,
    String sortKey,
    double width,
    DeviceManagerViewModel vm,
  ) {
    final isSorted = vm.sortBy == sortKey;
    final widget = InkWell(
      onTap: () => vm.setSorting(sortKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSorted ? AppTheme.primaryAccent : Colors.grey,
            ),
          ),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              vm.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 11,
              color: AppTheme.primaryAccent,
            ),
          ],
        ],
      ),
    );

    if (width > 0) {
      return SizedBox(width: width, child: widget);
    }
    return widget;
  }

  Widget _buildTableRow({
    required BuildContext context,
    required DeviceManagerViewModel vm,
    required SharedDevice device,
    required bool isSelected,
    required DateFormat dateFormat,
  }) {
    final cat = device.category;

    return InkWell(
      onTap: () => vm.selectDevice(device),
      onDoubleTap: () {
        showDialog(
          context: context,
          builder: (_) => EditDeviceDialog(
            device: device,
            onSave: (newName) => vm.updateDeviceName(device.macAddress, newName),
          ),
        );
      },
      child: Container(
        color: isSelected
            ? AppTheme.primaryAccent.withValues(alpha: 0.15)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // MAC Address (Monospace)
            SizedBox(
              width: 160,
              child: Text(
                device.macAddress,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryAccent,
                ),
              ),
            ),

            // Device Name (Clickable / Editable)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 13, color: Colors.grey),
                    tooltip: 'Rename device',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EditDeviceDialog(
                          device: device,
                          onSave: (newName) => vm.updateDeviceName(device.macAddress, newName),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Category Badge
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  Icon(cat.icon, size: 13, color: Colors.grey),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      cat.label,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Hardware Vendor (OUI)
            SizedBox(
              width: 180,
              child: Text(
                device.vendor ?? 'Unknown Hardware',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Source App
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  device.sourceApp,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Last Modified (Monospace)
            SizedBox(
              width: 150,
              child: Text(
                dateFormat.format(device.updatedAt),
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ),

            // Actions
            SizedBox(
              width: 70,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 15, color: AppTheme.error),
                    tooltip: 'Delete Device',
                    onPressed: () {
                      _confirmDelete(context, vm, device);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInspector(
    BuildContext context,
    DeviceManagerViewModel vm,
    DateFormat dateFormat,
  ) {
    final selected = vm.selectedDevice;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Inspector Header & Quick Rename Bar (if selected)
          if (selected != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surfaceHigh,
              child: Row(
                children: [
                  Icon(selected.category.icon, size: 16, color: AppTheme.primaryAccent),
                  const SizedBox(width: 8),
                  Text(
                    '${selected.macAddress} • ${selected.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Vendor: ${selected.vendor ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (selected.notes != null && selected.notes!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Notes: ${selected.notes}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const Spacer(),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.edit, size: 13),
                    label: const Text('Rename Device', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EditDeviceDialog(
                          device: selected,
                          onSave: (newName) => vm.updateDeviceName(selected.macAddress, newName),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 15),
                    onPressed: () => vm.selectDevice(null),
                  ),
                ],
              ),
            ),

          // Persistent Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  vm.hideDefaultNamed
                      ? 'Showing ${vm.devices.length} of ${vm.totalCount} devices (unnamed hidden)'
                      : 'Showing ${vm.devices.length} of ${vm.totalCount} devices',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Text('•', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Cross-Process Database: ${SharedDeviceDatabase.getDefaultDatabasePath()}',
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (vm.feedbackMessage != null) ...[
                  Text(
                    vm.feedbackMessage!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.success),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 12),
                    onPressed: vm.clearFeedback,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DeviceManagerViewModel vm) {
    if (vm.totalCount > 0 && vm.hideDefaultNamed) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_off,
                  size: 56,
                  color: AppTheme.primaryAccent.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No User-Named Devices Found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'There are ${vm.totalCount} devices in the inventory, but they have default MAC labels and "Hide Unnamed" is active.\n'
                  'Toggle off "Hide Unnamed" to view and label scanned devices, or register a new device.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => vm.setHideDefaultNamed(false),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text('Show Unnamed Devices'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AddDeviceDialog(onAdd: vm.addDevice),
                        );
                      },
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add Device'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other,
                size: 56,
                color: AppTheme.primaryAccent.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Devices in Shared Database',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Devices discovered by arp-scout or packet-inspector will automatically populate here.\n'
                'You can also manually register devices or import a list from CSV/JSON.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddDeviceDialog(onAdd: vm.addDevice),
                  );
                },
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add First Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    DeviceManagerViewModel vm,
    SharedDevice device,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device', style: TextStyle(fontSize: 15)),
        content: Text(
          'Are you sure you want to delete ${device.name} (${device.macAddress}) from the shared database?',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              vm.deleteDevice(device.macAddress);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport(
    BuildContext context,
    DeviceManagerViewModel vm,
    String format,
  ) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [format],
      );

      if (picked.isNotEmpty && picked.single.path != null) {
        final file = File(picked.single.path!);
        final content = await file.readAsString();
        if (format == 'csv') {
          vm.importFromCsv(content);
        } else {
          vm.importFromJson(content);
        }
      }
    } catch (e) {
      vm.setFeedbackMessage('Failed to read $format file: $e');
    }
  }

  Future<void> _handleExport(
    BuildContext context,
    DeviceManagerViewModel vm,
    String format,
  ) async {
    try {
      final content = format == 'csv' ? vm.exportCsv() : vm.exportJson();
      final defaultFileName =
          'network_suite_devices_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$format';

      final bytes = Uint8List.fromList(utf8.encode(content));
      final saveUri = await FilePicker.saveFile(
        dialogTitle: 'Export Shared Devices',
        fileName: defaultFileName,
        bytes: bytes,
      );

      if (saveUri != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Devices exported successfully ($format)')),
        );
      }
    } catch (e) {
      vm.setFeedbackMessage('Failed to export $format file: $e');
    }
  }
}
