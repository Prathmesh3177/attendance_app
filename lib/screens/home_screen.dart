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
                      final count = await importNamesFromCSV('Student');
                      if (count > 0) await load();
                    }),
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
                      if (picked != null) {
                        await exportAttendance(
                            context, DateTime(picked.year, picked.month, 1),persons);
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
