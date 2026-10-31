import 'package:flutter/material.dart';
import 'package:network_suite_shared/network_suite_shared.dart';
import '../../../core/app_theme.dart';

class CreateCategoryDialog extends StatefulWidget {
  final void Function({
    required String id,
    required String label,
    String iconName,
    String? colorHex,
  }) onCreate;

  const CreateCategoryDialog({super.key, required this.onCreate});

  @override
  State<CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<CreateCategoryDialog> {
  final _labelController = TextEditingController();
  final _idController = TextEditingController();
  bool _manualId = false;

  String _selectedIconName = 'devices_other';
  String? _selectedColorHex;

  static const List<Map<String, dynamic>> _iconOptions = [
    {'name': 'security', 'label': 'Security / Firewall', 'icon': Icons.security},
    {'name': 'tv', 'label': 'Smart TV', 'icon': Icons.tv},
    {'name': 'gamepad', 'label': 'Gaming / Console', 'icon': Icons.gamepad},
    {'name': 'dns', 'label': 'Server / DNS', 'icon': Icons.dns},
    {'name': 'router', 'label': 'Router / Gateway', 'icon': Icons.router},
    {'name': 'hub', 'label': 'Switch / Hub', 'icon': Icons.hub},
    {'name': 'storage', 'label': 'NAS / Storage', 'icon': Icons.storage},
    {'name': 'print', 'label': 'Printer', 'icon': Icons.print},
    {'name': 'sensors', 'label': 'IoT / Sensor', 'icon': Icons.sensors},
    {'name': 'videocam', 'label': 'IP Camera', 'icon': Icons.videocam},
    {'name': 'developer_board', 'label': 'SBC / Pi', 'icon': Icons.developer_board},
    {'name': 'memory', 'label': 'Chip / CPU', 'icon': Icons.memory},
    {'name': 'speaker', 'label': 'Audio / Speaker', 'icon': Icons.speaker},
    {'name': 'lightbulb', 'label': 'Smart Light', 'icon': Icons.lightbulb},
    {'name': 'power', 'label': 'Smart Plug', 'icon': Icons.power},
    {'name': 'phone_in_talk', 'label': 'VoIP Phone', 'icon': Icons.phone_in_talk},
    {'name': 'lan', 'label': 'Network / Ethernet', 'icon': Icons.lan},
    {'name': 'devices_other', 'label': 'Other Device', 'icon': Icons.devices_other},
  ];

  static const List<String> _colorSwatches = [
    '#00E5FF', // Cyan
    '#00E676', // Green
    '#FFD700', // Gold
    '#FF9100', // Orange
    '#FF5252', // Red
    '#E040FB', // Magenta
    '#7C4DFF', // Purple
    '#448AFF', // Blue
  ];

  @override
  void initState() {
    super.initState();
    _labelController.addListener(() {
      if (!_manualId) {
        final slug = _labelController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        _idController.text = slug;
      }
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    var id = _idController.text.trim();
    if (label.isEmpty) return;
    if (id.isEmpty) {
      id = label.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    }

    widget.onCreate(
      id: id,
      label: label,
      iconName: _selectedIconName,
      colorHex: _selectedColorHex,
    );

    Navigator.of(context).pop();
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.category, size: 20, color: AppTheme.primaryAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Create Custom Category',
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

                // Name / Label Input
                const Text(
                  'Category Name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _labelController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Firewall / UTM, Smart TV, Proxmox Node',
                  ),
                ),
                const SizedBox(height: 14),

                // Key / Slug Input
                const Text(
                  'Identifier (Key / Slug)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _idController,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                  decoration: const InputDecoration(
                    hintText: 'e.g. firewall, smart_tv, proxmox',
                  ),
                  onChanged: (_) => _manualId = true,
                ),
                const SizedBox(height: 14),

                // Icon Picker
                const Text(
                  'Select Icon',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _iconOptions.map((opt) {
                    final name = opt['name'] as String;
                    final icon = opt['icon'] as IconData;
                    final isSel = _selectedIconName == name;

                    return Tooltip(
                      message: opt['label'] as String,
                      child: InkWell(
                        onTap: () => setState(() => _selectedIconName = name),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.primaryAccent.withValues(alpha: 0.25)
                                : AppTheme.inputFill,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSel ? AppTheme.primaryAccent : AppTheme.border,
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: isSel ? AppTheme.primaryAccent : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Optional Color Accent
                const Text(
                  'Accent Color (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ..._colorSwatches.map((hex) {
                      final isSel = _selectedColorHex == hex;
                      final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedColorHex = isSel ? null : hex;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSel
                                ? const Icon(Icons.check, size: 14, color: Colors.black)
                                : null,
                          ),
                        ),
                      );
                    }),
                    if (_selectedColorHex != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedColorHex = null),
                        child: const Text('Clear', style: TextStyle(fontSize: 11)),
                      ),
                  ],
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
                      child: const Text('Create Category'),
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
