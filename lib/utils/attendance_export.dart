import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../db/database_helper.dart';
import '../models/person.dart';

enum ExportScope {
  all,
  staff,
  studentClass,
}

Future<void> exportAttendance(
  BuildContext context,
  DateTime month,
  List<Person> personsLocal, {
  ExportScope scope = ExportScope.all,
  String? studentClass,
}) async {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];
    excel.setDefaultSheet('Attendance');

    final days = DateUtils.getDaysInMonth(month.year, month.month);

    // Prepare filtered data based on scope
    List<Person> data;
    switch (scope) {
      case ExportScope.staff:
        data = personsLocal.where((p) => p.role == 'Staff').toList();
        break;
      case ExportScope.studentClass:
        data = personsLocal
            .where((p) => p.role == 'Student' && (p.studentClass ?? '') == (studentClass ?? ''))
            .toList();
        break;
      case ExportScope.all:
        data = List<Person>.from(personsLocal);
        break;
    }

    // Header with company information
    final totalColumns = 3 + days + 5; // Sl+Code+Name + day cols + totals
    List<String> headerRow1 = List.filled(totalColumns, '');
    headerRow1[0] = 'Company:  Gajanan Vidyalaya Deodhanora Tq Kallam';
    headerRow1[totalColumns - 1] = 'Printed On: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}';
    sheet.appendRow(headerRow1);
    sheet.appendRow(List.filled(totalColumns, ''));
    sheet.appendRow(['Scope: ${scope == ExportScope.all ? 'All' : scope == ExportScope.staff ? 'Staff' : 'Student - ${studentClass ?? ''}'} for ${DateFormat('MMMM yyyy').format(month)}']);
    sheet.appendRow(List.filled(totalColumns, ''));

    Future<void> buildSection(String role) async {
      // Section title row
      final sectionRow = List<String>.filled(totalColumns, '');
      sectionRow[0] = 'Department';
      sectionRow[1] = role;
      sheet.appendRow(sectionRow);
      
      // Create header row
      final header = ['Sl No.', 'Employee/Student Code', 'Name'];
      for (int d = 1; d <= days; d++) {
        final date = DateTime(month.year, month.month, d);
        final dayName = DateFormat('E').format(date).substring(0, 3);
        header.add('$d\n$dayName');
      }
      header.addAll(['Present\n(P)', 'Absent\n(A)', 'Leave\n(L)', 'Holiday\n(H)', 'Week Off\n(WO)']);
      sheet.appendRow(header);

      final list = data.where((p) => p.role == role).toList();
      int sl = 1;
      final hols = await DatabaseHelper.getHolidaysForMonth(month.year, month.month);
      final holSet = hols.map((d) => d.day).toSet();
      final leavesMap = await DatabaseHelper.getLeavesForMonth(month.year, month.month);

      for (var p in list) {
        final row = [sl, p.empCode, p.name];
        int countP = 0, countA = 0, countL = 0, countH = 0, countWO = 0;
        for (int d = 1; d <= days; d++) {
          final weekday = DateTime(month.year, month.month, d).weekday;
          final isWO = weekday == DateTime.sunday;
          if (holSet.contains(d)) {
            row.add('H');
            countH++;
          } else if (leavesMap[p.id]?.containsKey(d) == true) {
            final t = leavesMap[p.id]![d];
            if (t == 'L') { row.add('L'); countL++; }
            else if (t == 'A') { row.add('A'); countA++; }
          } else if (isWO) {
            row.add('WO');
            countWO++;
          } else {
            row.add('P');
            countP++;
          }
        }
        row.addAll([countP, countA, countL, countH, countWO]);
        sheet.appendRow(row);
        sl++;
      }

      sheet.appendRow([]);
    }

    if (scope == ExportScope.all || scope == ExportScope.staff) {
      await buildSection('Staff');
    }

    // Build separate sections per student class
    if (scope == ExportScope.all || scope == ExportScope.studentClass) {
      final studentClasses = (scope == ExportScope.studentClass && (studentClass ?? '').isNotEmpty)
          ? [studentClass!]
          : data
              .where((p) => p.role == 'Student')
              .map((p) => p.studentClass ?? '')
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      for (final cls in studentClasses) {
        // Insert a class header row before building the section
        final classHeader = List<String>.filled(totalColumns, '');
        classHeader[0] = 'Department';
        classHeader[1] = 'Student - $cls';
        sheet.appendRow(classHeader);

        // Header row for table
        final header = ['Sl No.', 'Employee/Student Code', 'Name'];
        for (int d = 1; d <= days; d++) {
          final date = DateTime(month.year, month.month, d);
          final dayName = DateFormat('E').format(date).substring(0, 3);
          header.add('$d\n$dayName');
        }
        header.addAll(['Present\n(P)', 'Absent\n(A)', 'Leave\n(L)', 'Holiday\n(H)', 'Week Off\n(WO)']);
        sheet.appendRow(header);

        int sl = 1;
        final hols = await DatabaseHelper.getHolidaysForMonth(month.year, month.month);
        final holSet = hols.map((d) => d.day).toSet();
        final leavesMap = await DatabaseHelper.getLeavesForMonth(month.year, month.month);

        final list = data
            .where((p) => p.role == 'Student' && (p.studentClass ?? '') == cls)
            .toList();

        for (var p in list) {
          final row = [sl, p.empCode, p.name];
          int countP = 0, countA = 0, countL = 0, countH = 0, countWO = 0;
          for (int d = 1; d <= days; d++) {
            final weekday = DateTime(month.year, month.month, d).weekday;
            final isWO = weekday == DateTime.sunday;
            if (holSet.contains(d)) {
              row.add('H');
              countH++;
            } else if (leavesMap[p.id]?.containsKey(d) == true) {
              final t = leavesMap[p.id]![d];
              if (t == 'L') { row.add('L'); countL++; }
              else if (t == 'A') { row.add('A'); countA++; }
            } else if (isWO) {
              row.add('WO');
              countWO++;
            } else {
              row.add('P');
              countP++;
            }
          }
          row.addAll([countP, countA, countL, countH, countWO]);
          sheet.appendRow(row);
          sl++;
        }

        sheet.appendRow([]);
      }
    }
    
    // Add summary section
    sheet.appendRow([]);
    sheet.appendRow(['SUMMARY - ${DateFormat('MMMM yyyy').format(month)}']);
    sheet.appendRow([]);
    
    List<Person> staffList = data.where((p) => p.role == 'Staff').toList();
    List<Person> studentList = data.where((p) => p.role == 'Student').toList();
    if (scope == ExportScope.staff) {
      studentList = [];
    } else if (scope == ExportScope.studentClass) {
      staffList = [];
      if ((studentClass ?? '').isNotEmpty) {
        studentList = studentList.where((p) => (p.studentClass ?? '') == studentClass).toList();
      }
    }
    
    sheet.appendRow(['Category', 'Count']);
    sheet.appendRow(['Staff', staffList.length.toString()]);
    sheet.appendRow(['Students', studentList.length.toString()]);
    sheet.appendRow(['Total', (staffList.length + studentList.length).toString()]);
    
    // Add holiday information
    final holidays = await DatabaseHelper.getHolidaysForMonth(month.year, month.month);
    if (holidays.isNotEmpty) {
      sheet.appendRow([]);
      sheet.appendRow(['HOLIDAYS IN ${DateFormat('MMMM yyyy').format(month).toUpperCase()}']);
      sheet.appendRow(['Date', 'Day']);
      for (final holiday in holidays) {
        sheet.appendRow([
          DateFormat('dd/MM/yyyy').format(holiday),
          DateFormat('EEEE').format(holiday),
        ]);
      }
    }
    
    // Save the file
    final bytes = excel.encode();
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Failed to generate Excel file')),
        );
      }
      return;
    }

    final fileName = 'attendance_${month.year}_${month.month.toString().padLeft(2, '0')}.xlsx';
    String savedPath = '';
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final candidatePath = '${downloadsDir.path}/$fileName';
        final file = File(candidatePath);
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        savedPath = candidatePath;
      } else {
        throw Exception('downloads_unavailable');
      }
    } catch (_) {
      final docsDir = await getApplicationDocumentsDirectory();
      final candidatePath = '${docsDir.path}/$fileName';
      final file = File(candidatePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      savedPath = candidatePath;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Exported ${DateFormat('MMMM yyyy').format(month)} to:\n$savedPath\n📊 ${data.length} users, ${holidays.length} holidays'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );

    try {
      await OpenFile.open(savedPath);
    } catch (_) {}
}
