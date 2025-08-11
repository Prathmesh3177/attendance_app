import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/person.dart';

class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key});
  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  DateTime selected = DateTime.now();
  List<Person> persons = [];
  Set<int> holidays = {}; // days
  Map<int, Map<int, String>> personLeaves = {}; // pid -> {day: type}

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    persons = await DatabaseHelper.getAllPersons();
    final hol = await DatabaseHelper.getHolidaysForMonth(selected.year, selected.month);
    holidays = hol.map((d) => d.day).toSet();
    personLeaves = await DatabaseHelper.getLeavesForMonth(selected.year, selected.month);
    setState(() {});
  }

  void pickMonth() async {
    final now = selected;
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        selected = DateTime(picked.year, picked.month, 1);
      });
      await loadAll();
    }
  }

  Future<void> toggleHoliday(int day) async {
    final isHol = holidays.contains(day);
    try {
      if (isHol) {
        await DatabaseHelper.removeHoliday(selected.year, selected.month, day);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Holiday removed for ${DateFormat('d MMMM yyyy').format(DateTime(selected.year, selected.month, day))}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await DatabaseHelper.addHoliday(selected.year, selected.month, day);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Holiday added for ${DateFormat('d MMMM yyyy').format(DateTime(selected.year, selected.month, day))}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating holiday: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editPersonDay(Person p, int day) async {
    // Remove unused variable
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Mark status for ${p.name}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, null), 
            child: const Text('Present (default)')
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'L'), 
            child: const Text('Leave (L)')
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'A'), 
            child: const Text('Absent (A)')
          ),
        ],
      ),
    );

    try {
      if (res == null) {
        // means default present -> remove entry if exists
        await DatabaseHelper.removeLeave(p.id!, selected.year, selected.month, day);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${p.name} as Present for ${DateFormat('d MMMM yyyy').format(DateTime(selected.year, selected.month, day))}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await DatabaseHelper.addLeave(p.id!, selected.year, selected.month, day, res);
        final status = res == 'L' ? 'Leave' : 'Absent';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${p.name} as $status for ${DateFormat('d MMMM yyyy').format(DateTime(selected.year, selected.month, day))}'),
            backgroundColor: res == 'L' ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(selected);
    final daysInMonth = DateUtils.getDaysInMonth(selected.year, selected.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Month / Holidays / Leaves')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              Text('Selected: $monthLabel'),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: pickMonth, child: const Text('Pick month')),
            ]),
          ),

          // Holidays section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Holidays for ${DateFormat('MMMM yyyy').format(selected)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${holidays.length} holiday(s)',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(daysInMonth, (i) {
                    final day = i + 1;
                    final isHol = holidays.contains(day);
                    return ChoiceChip(
                      label: Text(
                        day.toString(),
                        style: TextStyle(
                          color: isHol ? Colors.white : Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: isHol,
                      selectedColor: Colors.blue.shade600,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.blue.shade300),
                      onSelected: (_) => toggleHoliday(day),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: persons.length,
              itemBuilder: (context, idx) {
                final p = persons[idx];
                return Card(
                  child: ListTile(
                    title: Text('${p.empCode} - ${p.name} (${p.role})'),
                    subtitle: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: List.generate(daysInMonth, (i) {
                        final day = i + 1;
                        final isHol = holidays.contains(day);
                        final leaveType = personLeaves[p.id]?[day];
                        final weekday = DateTime(selected.year, selected.month, day).weekday;
                        final isWO = (weekday == DateTime.sunday);
                        final label = isHol ? 'H' : (leaveType != null ? leaveType : (isWO ? 'WO' : 'P'));
                        return GestureDetector(
                          onTap: () => editPersonDay(p, day),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(4)),
                            child: Text(label),
                          ),
                        );
                      })),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}