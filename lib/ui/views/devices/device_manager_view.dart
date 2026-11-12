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
import 'create_category_dialog.dart';
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
          decoration: BoxDecoration(
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
                              : AppTheme.textSecondary,
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
                                : AppTheme.textSecondary,
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
                      ...vm.categories.map(
                        (c) => _buildCategoryChip(
                          context,
                          vm,
                          c.key,
                          c.label,
                          c.icon,
                          color: c.color,
                          isCustom: c.isCustom,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Create Custom Category',
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => CreateCategoryDialog(
                                onCreate: vm.createCustomCategory,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.inputFill,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 12, color: AppTheme.primaryAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

        // Contextual Batch Action Bar (when vm.hasSelection)
        if (vm.hasSelection) _buildBatchActionBar(context, vm),

        // Primary Data Workspace (Tier 4) - High-Density Virtualized Data Table
        Expanded(
          child: vm.devices.isEmpty
              ? _buildEmptyState(context, vm)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 1100,
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
    IconData icon, {
    Color? color,
    bool isCustom = false,
  }) {
    final isSelected = vm.selectedCategory == key;
    final accentColor = color ?? AppTheme.primaryAccent;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 13,
          color: isSelected ? accentColor : AppTheme.textSecondary,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            if (isCustom) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => vm.setSelectedCategory(key),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        selectedColor: accentColor.withValues(alpha: 0.25),
        side: BorderSide(
          color: isSelected ? accentColor : AppTheme.border,
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, DeviceManagerViewModel vm) {
    final allSelected = vm.devices.isNotEmpty &&
        vm.devices.every((d) => vm.isMacSelected(d.macAddress));
    final someSelected =
        vm.devices.any((d) => vm.isMacSelected(d.macAddress));
    final bool? masterCheckboxValue =
        allSelected ? true : (someSelected ? null : false);

    return Container(
      color: AppTheme.surfaceHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Multi-Select Master Checkbox
          SizedBox(
            width: 44,
            child: Checkbox(
              tristate: true,
              value: masterCheckboxValue,
              onChanged: (_) {
                if (allSelected) {
                  vm.clearSelection();
                } else {
                  vm.selectAll(vm.devices);
                }
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          // MAC Address
          _buildHeaderColumn('MAC ADDRESS', 'mac', 160, vm),
          // Device Name
          Expanded(child: _buildHeaderColumn('DEVICE NAME', 'name', 0, vm)),
          // Category
          _buildHeaderColumn('CATEGORY', 'type', 140, vm),
          // Vendor
          _buildHeaderColumn('HARDWARE VENDOR', 'vendor', 180, vm),
          // Source App
          SizedBox(
            width: 100,
            child: Text(
              'SOURCE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
          ),
          // Updated
          _buildHeaderColumn('LAST MODIFIED', 'updated_at', 150, vm),
          // Actions
          SizedBox(
            width: 70,
            child: Text(
              'ACTIONS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
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
              color: isSorted ? AppTheme.primaryAccent : AppTheme.textSecondary,
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
    final cat = vm.resolveCategory(device.deviceType);
    final isChecked = vm.isMacSelected(device.macAddress);

    return InkWell(
      onTap: () => vm.selectDevice(device),
      onDoubleTap: () {
        showDialog(
          context: context,
          builder: (_) => EditDeviceDialog(
            device: device,
            onSave: ({
              required String name,
              required String category,
              String? vendor,
              String? notes,
            }) => vm.updateDeviceDetails(
              mac: device.macAddress,
              name: name,
              category: category,
              vendor: vendor,
              notes: notes,
            ),
          ),
        );
      },
      child: Container(
        color: isSelected
            ? AppTheme.primaryAccent.withValues(alpha: 0.15)
            : (isChecked
                ? AppTheme.primaryAccent.withValues(alpha: 0.08)
                : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Row Checkbox
            SizedBox(
              width: 44,
              child: Checkbox(
                value: isChecked,
                onChanged: (_) => vm.toggleSelect(device.macAddress),
                visualDensity: VisualDensity.compact,
              ),
            ),
            // MAC Address (Monospace)
            SizedBox(
              width: 160,
              child: Text(
                device.macAddress,
                style: TextStyle(
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
                    icon: Icon(Icons.edit, size: 13, color: AppTheme.textSecondary),
                    tooltip: 'Edit device details',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EditDeviceDialog(
                          device: device,
                          onSave: ({
                            required String name,
                            required String category,
                            String? vendor,
                            String? notes,
                          }) => vm.updateDeviceDetails(
                            mac: device.macAddress,
                            name: name,
                            category: category,
                            vendor: vendor,
                            notes: notes,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Category Badge with interactive quick-change popup
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: 'Change category for ${device.name}',
                  offset: const Offset(0, 24),
                  onSelected: (newCat) {
                    if (newCat == '__new__') {
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
                            vm.updateDeviceCategory(device.macAddress, id);
                          },
                        ),
                      );
                    } else {
                      vm.updateDeviceCategory(device.macAddress, newCat);
                    }
                  },
                  itemBuilder: (context) => [
                    ...vm.categories.map((c) => PopupMenuItem<String>(
                      value: c.key,
                      height: 32,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 14, color: c.color ?? AppTheme.primaryAccent),
                          const SizedBox(width: 8),
                          Text(c.label, style: const TextStyle(fontSize: 12)),
                          if (c.key == cat.key) ...[
                            const Spacer(),
                            Icon(Icons.check, size: 14, color: AppTheme.primaryAccent),
                          ],
                        ],
                      ),
                    )),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: '__new__',
                      height: 32,
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 14, color: AppTheme.primaryAccent),
                          SizedBox(width: 8),
                          Text('New Category...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (cat.color ?? AppTheme.primaryAccent).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (cat.color ?? AppTheme.primaryAccent).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 12, color: cat.color ?? AppTheme.primaryAccent),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: cat.color ?? AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_drop_down, size: 13, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Hardware Vendor (OUI)
            SizedBox(
              width: 180,
              child: Text(
                device.vendor ?? 'Unknown Hardware',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textPrimary.withValues(alpha: 0.8),
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
                    color: AppTheme.textPrimary.withValues(alpha: 0.6),
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
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            // Actions
            SizedBox(
              width: 70,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 15, color: AppTheme.error),
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
      decoration: BoxDecoration(
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
                  Icon(
                    vm.resolveCategory(selected.deviceType).icon,
                    size: 16,
                    color: vm.resolveCategory(selected.deviceType).color ?? AppTheme.primaryAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${selected.macAddress} • ${selected.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (vm.resolveCategory(selected.deviceType).color ?? AppTheme.primaryAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      vm.resolveCategory(selected.deviceType).label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: vm.resolveCategory(selected.deviceType).color ?? AppTheme.primaryAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Vendor: ${selected.vendor ?? 'Unknown'}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  if (selected.notes != null && selected.notes!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Notes: ${selected.notes}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                  const Spacer(),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.edit, size: 13),
                    label: const Text('Edit Details', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EditDeviceDialog(
                          device: selected,
                          onSave: ({
                            required String name,
                            required String category,
                            String? vendor,
                            String? notes,
                          }) => vm.updateDeviceDetails(
                            mac: selected.macAddress,
                            name: name,
                            category: category,
                            vendor: vendor,
                            notes: notes,
                          ),
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
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 16),
                Text('•', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Cross-Process Database: ${SharedDeviceDatabase.getDefaultDatabasePath()}',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (vm.feedbackMessage != null) ...[
                  Text(
                    vm.feedbackMessage!,
                    style: TextStyle(fontSize: 11, color: AppTheme.success),
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
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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
              Text(
                'Devices discovered by arp-scout or packet-inspector will automatically populate here.\n'
                'You can also manually register devices or import a list from CSV/JSON.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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

  Widget _buildBatchActionBar(BuildContext context, DeviceManagerViewModel vm) {
    final count = vm.selectedMacs.length;
    final label = count == 1 ? '1 device selected' : '$count devices selected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Count Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_box_outlined, size: 14, color: AppTheme.error),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Deselect All Action
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Deselect All', style: TextStyle(fontSize: 12)),
            onPressed: vm.clearSelection,
          ),
          const Spacer(),
          // Delete Selected Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.delete_sweep, size: 16),
            label: Text(
              'Delete Selected ($count)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _confirmBatchDelete(context, vm),
          ),
        ],
      ),
    );
  }

  void _confirmBatchDelete(
    BuildContext context,
    DeviceManagerViewModel vm,
  ) {
    final count = vm.selectedMacs.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Confirm Batch Deletion', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $count devices from the shared database? This action cannot be undone.',
          style: const TextStyle(fontSize: 12, height: 1.4),
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
              vm.deleteSelectedDevices();
            },
            child: const Text('Delete Devices'),
          ),
        ],
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
