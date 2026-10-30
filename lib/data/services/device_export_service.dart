import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:network_suite_shared/network_suite_shared.dart';

class DeviceExportService {
  static const List<String> _dangerousFormulaPrefixes = ['=', '+', '-', '@', '\t', '\r'];

  /// Prevents Spreadsheet/CSV Formula Injection by escaping leading formula triggers.
  static String sanitizeCsvCell(String value) {
    if (value.isEmpty) return value;
    for (final prefix in _dangerousFormulaPrefixes) {
      if (value.startsWith(prefix)) {
        return "'$value";
      }
    }
    return value;
  }

  /// Restores a cell previously escaped by [sanitizeCsvCell].
  static String unsanitizeCsvCell(String value) {
    if (value.length >= 2 && value.startsWith("'")) {
      final secondChar = value.substring(1);
      for (final prefix in _dangerousFormulaPrefixes) {
        if (secondChar.startsWith(prefix)) {
          return secondChar;
        }
      }
    }
    return value;
  }

  /// Exports a list of devices to CSV formatted string.
  static String exportToCsv(List<SharedDevice> devices) {
    final rows = <List<dynamic>>[
      [
        'MAC Address',
        'Device Name',
        'Vendor',
        'Category',
        'Notes',
        'Source App',
        'Created At',
        'Updated At',
      ],
      ...devices.map(
        (d) => [
          sanitizeCsvCell(d.macAddress),
          sanitizeCsvCell(d.name),
          sanitizeCsvCell(d.vendor ?? ''),
          sanitizeCsvCell(d.deviceType ?? ''),
          sanitizeCsvCell(d.notes ?? ''),
          sanitizeCsvCell(d.sourceApp),
          d.createdAt.toIso8601String(),
          d.updatedAt.toIso8601String(),
        ],
      ),
    ];

    return Csv().encode(rows);
  }

  /// Exports a list of devices to JSON formatted string.
  static String exportToJson(List<SharedDevice> devices) {
    final list = devices.map((d) => d.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Parses CSV content into a list of [SharedDevice] records.
  static List<SharedDevice> importFromCsv(String csvContent) {
    try {
      final rows = Csv().decode(csvContent);
      if (rows.length <= 1) return [];

      final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final macIdx = header.indexOf('mac address');
      final nameIdx = header.indexOf('device name');
      final vendorIdx = header.indexOf('vendor');
      final typeIdx = header.indexOf('category');
      final notesIdx = header.indexOf('notes');

      final devices = <SharedDevice>[];
      final now = DateTime.now();

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final rawMac = unsanitizeCsvCell(
          macIdx != -1 && macIdx < row.length ? row[macIdx].toString() : row[0].toString(),
        );
        final name = unsanitizeCsvCell(
          nameIdx != -1 && nameIdx < row.length
              ? row[nameIdx].toString()
              : (row.length > 1 ? row[1].toString() : 'Imported Device'),
        );

        if (!SharedDevice.isValidMac(rawMac)) continue;

        final vendor = vendorIdx != -1 && vendorIdx < row.length
            ? unsanitizeCsvCell(row[vendorIdx].toString())
            : null;
        final type = typeIdx != -1 && typeIdx < row.length
            ? unsanitizeCsvCell(row[typeIdx].toString())
            : null;
        final notes = notesIdx != -1 && notesIdx < row.length
            ? unsanitizeCsvCell(row[notesIdx].toString())
            : null;

        devices.add(
          SharedDevice(
            macAddress: SharedDevice.normalizeMac(rawMac),
            name: name.trim().isNotEmpty ? name.trim() : 'Imported Device',
            vendor: vendor?.trim().isNotEmpty == true ? vendor!.trim() : OuiLookup.lookupVendor(rawMac),
            deviceType: type?.trim().isNotEmpty == true ? type!.trim() : 'other',
            notes: notes?.trim(),
            sourceApp: 'csv_import',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      return devices;
    } catch (_) {
      return [];
    }
  }

  /// Parses JSON content into a list of [SharedDevice] records.
  static List<SharedDevice> importFromJson(String jsonContent) {
    try {
      final dynamic data = jsonDecode(jsonContent);
      final now = DateTime.now();

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((m) {
              final rawMac = m['mac_address']?.toString() ?? '';
              if (!SharedDevice.isValidMac(rawMac)) return null;
              return SharedDevice(
                macAddress: SharedDevice.normalizeMac(rawMac),
                name: (m['name']?.toString() ?? 'Imported Device').trim(),
                vendor: m['vendor']?.toString(),
                deviceType: m['device_type']?.toString(),
                notes: m['notes']?.toString(),
                sourceApp: (m['source_app']?.toString() ?? 'json_import'),
                createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) ?? now : now,
                updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'].toString()) ?? now : now,
              );
            })
            .whereType<SharedDevice>()
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
