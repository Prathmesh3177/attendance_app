import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../db/database_helper.dart';

// ----------- Decoding helpers -----------
String _decodeUtf16(List<int> bytes, {required bool bigEndian}) {
  final codeUnits = <int>[];
  int i = 0;
  // Skip BOM if present
  if (bytes.length >= 2) {
    if (!bigEndian && bytes[0] == 0xFF && bytes[1] == 0xFE) i = 2;
    if (bigEndian && bytes[0] == 0xFE && bytes[1] == 0xFF) i = 2;
  }
  for (; i + 1 < bytes.length; i += 2) {
    final unit = bigEndian
        ? (bytes[i] << 8) | bytes[i + 1]
        : (bytes[i + 1] << 8) | bytes[i];
    codeUnits.add(unit);
  }
  return String.fromCharCodes(codeUnits);
}

String _decodeBytes(List<int> bytes) {
  if (bytes.length >= 2) {
    final b0 = bytes[0];
    final b1 = bytes[1];
    if (b0 == 0xFF && b1 == 0xFE) {
      return _decodeUtf16(bytes, bigEndian: false);
    }
    if (b0 == 0xFE && b1 == 0xFF) {
      return _decodeUtf16(bytes, bigEndian: true);
    }
  }
  try {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  } catch (_) {
    return const Latin1Codec().decode(bytes, allowInvalid: true);
  }
}

// ----------- Detect the column with names -----------
int _detectNameColumn(List<List<dynamic>> rows) {
  int maxCols = 0;
  for (final r in rows) {
    if (r.length > maxCols) maxCols = r.length;
  }
  if (maxCols == 0) return 0;

  int bestCol = 0;
  int bestScore = -1;

  for (int c = 0; c < maxCols; c++) {
    int nonEmpty = 0;
    int texty = 0;
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (c >= r.length) continue;
      final s = (r[c]?.toString() ?? '').trim();
      if (s.isEmpty) continue;
      nonEmpty++;
      if (RegExp(r'[A-Za-z]').hasMatch(s)) texty++;
    }
    final score = nonEmpty * 2 + texty;
    if (score > bestScore) {
      bestScore = score;
      bestCol = c;
    }
  }
  return bestCol;
}

// ----------- Main Import Function -----------
Future<int> importNamesFromCSV(String role) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'CSV'],
      allowMultiple: false,
      withData: true,
      dialogTitle: 'Select $role CSV (name column will be auto-detected)',
    );

    if (result == null || result.files.isEmpty) return 0; // User cancelled

    final picked = result.files.single;
    String content;

    if (picked.bytes != null) {
      content = _decodeBytes(picked.bytes!);
    } else if (picked.path != null) {
      content = await File(picked.path!).readAsString();
    } else {
      return 0;
    }

    // Strip BOM if present
    content = content.replaceAll('\ufeff', '').trim();

    if (content.isEmpty) return 0;

    // --- Parse CSV ---
    List<List<dynamic>> rows;
    try {
      // First try with comma (default)
      rows = const CsvToListConverter(eol: '\n').convert(content);
    } catch (_) {
      rows = [];
    }

    // If only 1 row detected and content has semicolon
    if ((rows.isEmpty || rows.length == 1) && content.contains(';')) {
      rows = const CsvToListConverter(fieldDelimiter: ';', eol: '\n').convert(content);
    }

    // If still empty, split manually (for plain name lists with no delimiter)
    if (rows.isEmpty || (rows.length == 1 && rows.first.length == 1 && rows.first.first.toString().contains('\n'))) {
      rows = content.split('\n').map((line) => [line.trim()]).toList();
    }

    if (rows.isEmpty) return 0;

    // --- Detect name column ---
    final nameCol = _detectNameColumn(rows);

    // --- Extract names ---
    final raw = rows
        .map((row) => nameCol < row.length ? row[nameCol].toString().trim() : '')
        .where((s) => s.isNotEmpty)
        .toList();

    if (raw.isEmpty) return 0;

    // --- Drop header if it looks like one ---
    final firstLower = raw.first.toLowerCase();
    final hasHeader = firstLower.contains('name') || firstLower == 'student' || firstLower == 'staff';
    final names = (hasHeader ? raw.skip(1) : raw)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    if (names.isEmpty) return 0;

    // --- Save to DB ---
    await DatabaseHelper.insertPersonsBulk(names, role);
    return names.length;
  } catch (e) {
    print('❌ Error importing $role CSV: $e');
    return -1;
  }
}
