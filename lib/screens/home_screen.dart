import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/person.dart';
import 'add_person.dart';
import 'month_screen.dart';
import 'user_details_screen.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Person> persons = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    persons = await DatabaseHelper.getAllPersons();
    setState(() {});
  }

   // add at the top

Future<void> exportAttendance(DateTime month) async {
  final excel = Excel.createExcel();
  // Create or get the 'Attendance' sheet and make it default without renaming any internal lists
  final sheet = excel['Attendance'];
  excel.setDefaultSheet('Attendance');

  final days = DateUtils.getDaysInMonth(month.year, month.month);

  // Pull fresh data to avoid stale/empty export
  final personsLocal = await DatabaseHelper.getAllPersons();

  // Header with company information (place Printed On at the far right)
  final totalColumns = 3 + days + 5; // Sl+Code+Name + day cols + totals
  List<String> headerRow1 = List.filled(totalColumns, '');
  headerRow1[0] = 'Company:  Gajanan Vidyalaya Deodhanora Tq Kallam';
  headerRow1[totalColumns - 1] = 'Printed On: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}';
  sheet.appendRow(headerRow1);
  sheet.appendRow(List.filled(totalColumns, ''));

  Future<void> buildSection(String role) async {
    // Section title row like: Department    Staff
    final sectionRow = List<String>.filled(totalColumns, '');
    sectionRow[0] = 'Department';
    sectionRow[1] = role;
    sheet.appendRow(sectionRow);
    
    // Create header row
    final header = ['Sl No.', 'Employee/Student Code', 'Name'];
    for (int d = 1; d <= days; d++) {
      final date = DateTime(month.year, month.month, d);
      final dayName = DateFormat('E').format(date).substring(0, 3); // Mon, Tue, etc.
      header.add('$d\n$dayName');
    }
    header.addAll(['Present\n(P)', 'Absent\n(A)', 'Leave\n(L)', 'Holiday\n(H)', 'Week Off\n(WO)']);
    sheet.appendRow(header);

    final list = personsLocal.where((p) => p.role == role).toList();
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

  await buildSection('Staff');
  await buildSection('Student');
  
  // Add summary section
  sheet.appendRow([]);
  sheet.appendRow(['SUMMARY']);
  sheet.appendRow([]);
  
  final staffList = personsLocal.where((p) => p.role == 'Staff').toList();
  final studentList = personsLocal.where((p) => p.role == 'Student').toList();
  
  sheet.appendRow(['Category', 'Count']);
  sheet.appendRow(['Staff', staffList.length.toString()]);
  sheet.appendRow(['Students', studentList.length.toString()]);
  sheet.appendRow(['Total', persons.length.toString()]);
  
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
  
  // Verify Excel was created properly
  final bytes = excel.encode();
  if (bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Failed to generate Excel file')),
    );
    return;
  }
  print('Excel file generated successfully, size: ${bytes.length} bytes');

  // Auto-save to Downloads (desktop) or app documents as fallback. No file-picker, month-only flow.
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
    // Fallback to app documents if Downloads is unavailable or permission denied
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
      content: Text('✅ Exported ${DateFormat('MMMM yyyy').format(month)} to:\n$savedPath\n📊 ${personsLocal.length} users, ${holidays.length} holidays'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 5),
    ),
  );

  try {
    await OpenFile.open(savedPath);
  } catch (_) {}
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gajanan Attendance System'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(children: [
        // Header with statistics
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  persons.length.toString(),
                  Icons.people,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Staff',
                  persons.where((p) => p.role == 'Staff').length.toString(),
                  Icons.work,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Students',
                  persons.where((p) => p.role == 'Student').length.toString(),
                  Icons.school,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ),
        
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // First row of buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final added = await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const AddPersonScreen(role: 'Staff'))
                        );
                        if (added == true) await load();
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Staff'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final added = await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const AddPersonScreen(role: 'Student'))
                        );
                        if (added == true) await load();
                      },
                      icon: const Icon(Icons.school),
                      label: const Text('Add Student'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Second row of buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const MonthScreen())
                        );
                        await load();
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Attendance & Holidays'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const UserDetailsScreen())
                        );
                        await load();
                      },
                      icon: const Icon(Icons.people),
                      label: const Text('Manage Users'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Third row - Export buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 2),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          await exportAttendance(DateTime(picked.year, picked.month, 1));
                        }
                      },
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: persons.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No users added yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add staff or students to get started',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: persons.length,
                  itemBuilder: (context, idx) {
                    final p = persons[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.role == 'Staff' ? Colors.green : Colors.orange,
                          child: Text(
                            p.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Code: ${p.empCode}'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.role == 'Staff' ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                p.role,
                                style: TextStyle(
                                  color: p.role == 'Staff' ? Colors.green.shade700 : Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: Text('Are you sure you want to delete ${p.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirmed == true && p.id != null) {
                              await DatabaseHelper.deletePerson(p.id!);
                              await load();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${p.role} deleted successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        )
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}