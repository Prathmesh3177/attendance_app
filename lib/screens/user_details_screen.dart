import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/person.dart';
import 'edit_person.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  List<Person> allPersons = [];
  List<Person> filteredPersons = [];
  String searchQuery = '';
  String selectedRole = 'All';
  String selectedClass = 'All';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() => isLoading = true);
    try {
      allPersons = await DatabaseHelper.getAllPersons();
      filterUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void filterUsers() {
    bool matchesSearch(Person p) {
      return p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.empCode.toString().contains(searchQuery);
    }

    filteredPersons = allPersons.where(matchesSearch).toList();
    if (selectedRole != 'All') {
      filteredPersons = filteredPersons.where((p) => p.role == selectedRole).toList();
    }
    if (selectedRole == 'Student' && selectedClass != 'All') {
      filteredPersons = filteredPersons
          .where((p) => (p.studentClass ?? '') == selectedClass)
          .toList();
    }

    int classOrder(String? cls) {
      if (cls == null) return 999;
      final match = RegExp(r'^(\d+)').firstMatch(cls);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? 999;
      }
      return 999;
    }

    filteredPersons.sort((a, b) {
      if (selectedRole == 'Student' && selectedClass == 'All') {
        final ca = classOrder(a.studentClass);
        final cb = classOrder(b.studentClass);
        if (ca != cb) return ca.compareTo(cb);
        return a.empCode.compareTo(b.empCode);
      }
      if (selectedRole == 'Student') {
        return a.empCode.compareTo(b.empCode);
      }
      if (selectedRole == 'Staff') {
        return a.empCode.compareTo(b.empCode);
      }
      // For 'All'
      if (a.role != b.role) return a.role.compareTo(b.role);
      final ca = classOrder(a.studentClass);
      final cb = classOrder(b.studentClass);
      if (ca != cb) return ca.compareTo(cb);
      return a.empCode.compareTo(b.empCode);
    });
  }

  Future<void> deleteUser(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${person.name} (${person.role})?'),
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

    if (confirmed == true) {
      try {
        if (person.id != null) {
          await DatabaseHelper.deletePerson(person.id!);
          await loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${person.role} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Bulk Delete',
            onPressed: () async {
              final role = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Users'),
                  content: const Text('Which users do you want to delete?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Staff'),
                      child: const Text('All Staff'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Student'),
                      child: const Text('All Students'),
                    ),
                  ],
                ),
              );

              if (role == null) return;

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: Text('Delete ALL $role? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final deleted = await DatabaseHelper.deleteAllPersonsByRole(role);
                  await loadUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted $deleted $role'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by name or code',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      filterUsers();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Role Filter
                Row(
                  children: [
                    const Text('Filter by role: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedRole,
                      items: ['All', 'Staff', 'Student'].map((role) {
                        return DropdownMenuItem(value: role, child: Text(role));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedRole = value!;
                          if (selectedRole != 'Student') selectedClass = 'All';
                          filterUsers();
                        });
                      },
                    ),
                  ],
                ),
                if (selectedRole == 'Student') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Class: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedClass,
                        items: [
                          'All',
                          ...allPersons
                              .where((p) => p.role == 'Student' && (p.studentClass ?? '').isNotEmpty)
                              .map((p) => p.studentClass!)
                              .toSet()
                              .toList()
                            ..sort((a, b) {
                              int pa = int.tryParse(RegExp(r'^(\d+)').firstMatch(a)?.group(1) ?? '') ?? 999;
                              int pb = int.tryParse(RegExp(r'^(\d+)').firstMatch(b)?.group(1) ?? '') ?? 999;
                              return pa.compareTo(pb);
                            })
                        ].map((cls) => DropdownMenuItem(value: cls, child: Text(cls == 'All' ? 'All Classes' : cls))).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedClass = value!;
                            filterUsers();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Statistics
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Users',
                    allPersons.length.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Staff',
                    allPersons.where((p) => p.role == 'Staff').length.toString(),
                    Icons.work,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Students',
                    allPersons.where((p) => p.role == 'Student').length.toString(),
                    Icons.school,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          
          // Users List (with grouping for Students by class)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    // Helper to build a single person tile
                    Widget buildTile(Person person) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: person.role == 'Staff' ? Colors.green : Colors.orange,
                            child: Text(
                              person.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Code: ${person.empCode}'),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: person.role == 'Staff' ? Colors.green.shade100 : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      person.role,
                                      style: TextStyle(
                                        color: person.role == 'Staff' ? Colors.green.shade700 : Colors.orange.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (person.role == 'Student' && person.studentClass != null && person.studentClass!.isNotEmpty)
                                    const SizedBox(height: 4),
                                  if (person.role == 'Student' && person.studentClass != null && person.studentClass!.isNotEmpty)
                                    Text('Class: ${person.studentClass}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditPersonScreen(person: person),
                                    ),
                                  );
                                  if (result == true) {
                                    await loadUsers();
                                  }
                                },
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteUser(person),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Build according to role/class selections
                    bool matchesSearch(Person p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()) || p.empCode.toString().contains(searchQuery);

                    if (selectedRole == 'Student' && selectedClass == 'All') {
                      final students = allPersons.where((p) => p.role == 'Student' && matchesSearch(p)).toList();
                      final classes = students
                          .map((p) => p.studentClass ?? '')
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort((a, b) {
                          int pa = int.tryParse(RegExp(r'^(\d+)').firstMatch(a)?.group(1) ?? '') ?? 999;
                          int pb = int.tryParse(RegExp(r'^(\d+)').firstMatch(b)?.group(1) ?? '') ?? 999;
                          return pa.compareTo(pb);
                        });
                      if (classes.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No users found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        );
                      }
                      final List<Widget> grouped = [];
                      for (final cls in classes) {
                        grouped.add(
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text('Class: $cls', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        );
                        final classStudents = students
                            .where((p) => (p.studentClass ?? '') == cls)
                            .toList()
                          ..sort((a, b) => a.empCode.compareTo(b.empCode));
                        grouped.addAll(classStudents.map(buildTile));
                      }
                      return ListView(children: grouped);
                    }

                    if (selectedRole == 'All') {
                      final searchOnly = allPersons.where(matchesSearch).toList();
                      final staff = searchOnly.where((p) => p.role == 'Staff').toList()..sort((a, b) => a.empCode.compareTo(b.empCode));
                      final students = searchOnly.where((p) => p.role == 'Student').toList();
                      final classes = students
                          .map((p) => p.studentClass ?? '')
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort((a, b) {
                          int pa = int.tryParse(RegExp(r'^(\d+)').firstMatch(a)?.group(1) ?? '') ?? 999;
                          int pb = int.tryParse(RegExp(r'^(\d+)').firstMatch(b)?.group(1) ?? '') ?? 999;
                          return pa.compareTo(pb);
                        });

                      if (staff.isEmpty && classes.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No users found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      final List<Widget> children = [];
                      if (staff.isNotEmpty) {
                        children.add(
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text('Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        );
                        children.addAll(staff.map(buildTile));
                      }

                      for (final cls in classes) {
                        children.add(
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text('Student - $cls', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        );
                        final list = students.where((p) => (p.studentClass ?? '') == cls).toList()..sort((a, b) => a.empCode.compareTo(b.empCode));
                        children.addAll(list.map(buildTile));
                      }

                      return ListView(children: children);
                    }

                    // Default flat list (Staff or Student specific class)
                    if (filteredPersons.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No users found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filteredPersons.length,
                      itemBuilder: (context, index) {
                        final person = filteredPersons[index];
                        return buildTile(person);
                      },
                    );
                  }),
          ),
        ],
      ),
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
