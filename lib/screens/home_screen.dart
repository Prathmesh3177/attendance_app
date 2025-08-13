import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/person.dart';
import '../utils/csv_import.dart';
import '../utils/attendance_export.dart';
import 'add_person.dart';
import 'month_screen.dart';
import 'user_details_screen.dart';
import '../widgets/stat_card.dart';
import '../widgets/action_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final staffCount = persons.where((p) => p.role == 'Staff').length;
    final studentCount = persons.where((p) => p.role == 'Student').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: load,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                StatCard(
                    title: 'Total Users',
                    value: persons.length.toString(),
                    icon: Icons.people,
                    color: Colors.indigo),
                const SizedBox(width: 8),
                StatCard(
                    title: 'Staff',
                    value: staffCount.toString(),
                    icon: Icons.work,
                    color: Colors.green),
                const SizedBox(width: 8),
                StatCard(
                    title: 'Students',
                    value: studentCount.toString(),
                    icon: Icons.school,
                    color: Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ActionButton(
                    title: 'Add Staff',
                    icon: Icons.person_add,
                    color: Colors.green,
                    onTap: () async {
                      final added = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AddPersonScreen(role: 'Staff')));
                      if (added == true) await load();
                    }),
                ActionButton(
                    title: 'Add Student',
                    icon: Icons.school,
                    color: Colors.orange,
                    onTap: () async {
                      final added = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AddPersonScreen(role: 'Student')));
                      if (added == true) await load();
                    }),
                ActionButton(
                    title: 'Attendance & Holidays',
                    icon: Icons.calendar_month,
                    color: Colors.blue,
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MonthScreen()));
                      await load();
                    }),
                ActionButton(
                    title: 'Manage Users',
                    icon: Icons.people,
                    color: Colors.purple,
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const UserDetailsScreen()));
                      await load();
                    }),
                ActionButton(
                    title: 'Import Staff CSV',
                    icon: Icons.upload_file,
                    color: Colors.green,
                    onTap: () async {
                      final count = await importNamesFromCSV('Staff');
                      if (count > 0) await load();
                    }),
                ActionButton(
                  title: 'Import Student CSV',
                  icon: Icons.upload_file,
                  color: Colors.orange,
                  onTap: () async {
                    final className = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String selectedClass = '8th'; // default
                        return AlertDialog(
                          title: const Text('Select Class'),
                          content: StatefulBuilder(
                            builder: (context, setState) {
                              return DropdownButtonFormField<String>(
                                value: selectedClass,
                                decoration: const InputDecoration(
                                  labelText: 'Class',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: '8th', child: Text('8th')),
                                  DropdownMenuItem(
                                      value: '9th', child: Text('9th')),
                                  DropdownMenuItem(
                                      value: '10th', child: Text('10th')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => selectedClass = value);
                                  }
                                },
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, selectedClass);
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );

                    if (className != null && className.isNotEmpty) {
                      final count = await importNamesFromCSV('Student',
                          className: className);
                      if (count > 0) await load();
                    }
                  },
                ),


                ActionButton(
                    title: 'Export Excel',
                    icon: Icons.file_download,
                    color: Colors.indigo,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(now.year - 2),
                        lastDate: DateTime(now.year + 2),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked == null) return;

                      // Ask scope
                      final scope = await showDialog<String>(
                        context: context,
                        builder: (context) {
                          String? selectedClass;
                          return AlertDialog(
                            title: const Text('Export Scope'),
                            content: StatefulBuilder(
                              builder: (context, setState) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      title: const Text('All'),
                                      leading: const Icon(Icons.group),
                                      onTap: () => Navigator.pop(context, 'all'),
                                    ),
                                    const Divider(),
                                    ListTile(
                                      title: const Text('Staff only'),
                                      leading: const Icon(Icons.work),
                                      onTap: () => Navigator.pop(context, 'staff'),
                                    ),
                                    const Divider(),
                                    const Text('Student class:'),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: selectedClass,
                                      decoration: const InputDecoration(border: OutlineInputBorder()),
                                      items: const [
                                        DropdownMenuItem(value: '8th', child: Text('8th')),
                                        DropdownMenuItem(value: '9th', child: Text('9th')),
                                        DropdownMenuItem(value: '10th', child: Text('10th')),
                                      ],
                                      onChanged: (v) => setState(() => selectedClass = v),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context, selectedClass == null ? null : 'student:$selectedClass'),
                                        child: const Text('Export Student Class'),
                                      ),
                                    )
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      );

                      if (scope == null) return;

                      final month = DateTime(picked.year, picked.month, 1);
                      if (scope == 'all') {
                        await exportAttendance(context, month, persons);
                      } else if (scope == 'staff') {
                        await exportAttendance(context, month, persons, scope: ExportScope.staff);
                      } else if (scope.startsWith('student:')) {
                        final cls = scope.split(':').last;
                        await exportAttendance(context, month, persons, scope: ExportScope.studentClass, studentClass: cls);
                      }
                    }),
              ],
            ),
            const SizedBox(height: 24),
            persons.isEmpty
                ? Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No users yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600)),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: persons.length,
                    itemBuilder: (context, idx) {
                      final p = persons[idx];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.role == 'Staff'
                                ? Colors.green
                                : Colors.orange,
                            child: Text(
                              p.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(p.name),
                          subtitle: Text('Code: ${p.empCode}'),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: Text(
                                            'Delete ${p.name}?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel')),
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.red),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Delete')),
                                        ],
                                      ));
                              if (confirm == true && p.id != null) {
                                await DatabaseHelper.deletePerson(p.id!);
                                await load();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  )
          ],
        ),
      ),
    );
  }
}
